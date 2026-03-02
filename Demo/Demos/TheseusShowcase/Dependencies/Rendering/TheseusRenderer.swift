import Metal
import MetalKit
import QuartzCore
import UIKit
import IOSurface

/// Metal-based renderer for liquid glass effects
final class TheseusRenderer: NSObject {

    private weak var metalLayer: CAMetalLayer?
    private weak var sourceView: UIView?

    private let context: MetalContext
    private let texturePool: TexturePool
    private var viewLayerCapture: ViewLayerCapture?
    private var backgroundCaptureDraw: BackgroundCaptureDraw?
    private let blurKernelCalculator: BlurKernelCalculator

    private var displayLink: DisplayLinkDriver.Link?
    private(set) var isRendering: Bool = false

    // Triple buffering: allows CPU to prepare frame N+1 while GPU renders frame N,
    // with frame N-1 as a safety buffer for synchronization timing variance.
    private static let maxFramesInFlight: UInt64 = 3

    // Thread safety: frame counters accessed from render callback (display link thread)
    // and main thread during stop/query operations.
    private let frameCounterLock = NSLock()
    private var _frameCounter: UInt64 = 0
    private var _lastCompletedFrame: UInt64 = 0
    private var currentBufferIndex: Int = 0

    private var frameCounter: UInt64 {
        get { frameCounterLock.withLock { _frameCounter } }
        set { frameCounterLock.withLock { _frameCounter = newValue } }
    }

    private var lastCompletedFrame: UInt64 {
        get { frameCounterLock.withLock { _lastCompletedFrame } }
        set { frameCounterLock.withLock { _lastCompletedFrame = newValue } }
    }

    private var isShuttingDown: Bool = false

    // Thread safety: configuration may be updated from main thread while render loop reads it.
    private let configurationLock = NSLock()
    private var _configuration: TheseusConfiguration = TheseusConfiguration()

    var configuration: TheseusConfiguration {
        get { configurationLock.withLock { _configuration } }
        set { configurationLock.withLock { _configuration = newValue } }
    }

    var continuousUpdate: Bool = false

    private var needsRender: Bool = true

    private var lastViewFrame: CGRect = .zero
    private var lastSourceBounds: CGRect = .zero

    private(set) var currentQuality: QualityLevel
    private(set) var currentRefractionQuality: RefractionQuality

    init?(metalLayer: CAMetalLayer, sourceView: UIView?) {
        guard let context = MetalContext.shared else {
            return nil
        }

        self.context = context
        self.metalLayer = metalLayer
        self.sourceView = sourceView

        self.texturePool = TexturePool(device: context.device)
        self.blurKernelCalculator = BlurKernelCalculator(device: context.device)

        // Use settings for quality levels (access backing store directly before super.init)
        let settings = TheseusSettings.shared
        self.currentQuality = _configuration.quality ?? context.recommendedQuality
        self.currentRefractionQuality = settings.effectiveRefractionQuality

        super.init()
        setupNotifications()
    }

    deinit {
        stopRendering()
    }

    func startRendering() {
        guard !isRendering else { return }

        // Refresh quality settings
        currentRefractionQuality = TheseusSettings.shared.effectiveRefractionQuality

        displayLink = DisplayLinkDriver.shared.add(
            framesPerSecond: .fps(currentRefractionQuality.frameRate)
        ) { [weak self] _ in
            self?.render()
        }
        displayLink?.isPaused = false
        isRendering = true
    }

    func stopRendering() {
        guard isRendering else { return }

        isShuttingDown = true

        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        isRendering = false

        waitForGPUCompletion()

        isShuttingDown = false
    }

    private func waitForGPUCompletion() {
        guard frameCounter > lastCompletedFrame else { return }

        if let flushBuffer = context.commandQueue.makeCommandBuffer() {
            flushBuffer.commit()
            flushBuffer.waitUntilCompleted()
        }
    }

    func setNeedsRender() {
        needsRender = true
    }

    func updateSourceView(_ view: UIView?) {
        sourceView = view
        viewLayerCapture?.invalidate()
        backgroundCaptureDraw?.invalidate()
        setNeedsRender()
    }

    private func getViewLayerCapture() -> ViewLayerCapture? {
        if viewLayerCapture == nil {
            viewLayerCapture = ViewLayerCapture(device: context.device)
        }
        return viewLayerCapture
    }

    private func getBackgroundCaptureDraw() -> BackgroundCaptureDraw? {
        if backgroundCaptureDraw == nil {
            backgroundCaptureDraw = BackgroundCaptureDraw(device: context.device)
        }
        return backgroundCaptureDraw
    }

    func updateConfiguration(_ config: TheseusConfiguration) {
        configuration = config
        currentQuality = config.quality ?? context.recommendedQuality
        blurKernelCalculator.invalidateCache()
        setNeedsRender()
    }

    private func render() {
        guard !isShuttingDown else { return }
        guard shouldRender() else { return }

        let framesInFlight = frameCounter - lastCompletedFrame
        guard framesInFlight < Self.maxFramesInFlight else { return }

        guard let metalLayer = metalLayer,
              let drawable = metalLayer.nextDrawable() else {
            return
        }

        frameCounter += 1
        let thisFrameValue = frameCounter

        autoreleasepool {
            performRender(to: drawable, frameValue: thisFrameValue)
        }

        needsRender = false
        currentBufferIndex = Int(thisFrameValue % Self.maxFramesInFlight)
    }

    private func shouldRender() -> Bool {
        if continuousUpdate { return true }

        if needsRender { return true }

        if let layer = metalLayer {
            let currentFrame = layer.frame
            if currentFrame != lastViewFrame {
                lastViewFrame = currentFrame
                return true
            }
        }

        if let source = sourceView {
            let currentBounds = source.bounds
            if currentBounds != lastSourceBounds {
                lastSourceBounds = currentBounds
                return true
            }
        }

        return false
    }

    private func performRender(to drawable: CAMetalDrawable, frameValue: UInt64) {
        guard let metalLayer = metalLayer,
              let sourceView = sourceView else {
            return
        }

        let viewFrame = metalLayer.frame
        let captureRegion = calculateCaptureRegion(viewFrame: viewFrame, in: sourceView)

        // Use refraction quality for render scale (controlled by settings)
        let renderScale = currentRefractionQuality.renderScale

        let sourceTexture: MTLTexture
        var capturedSurface: IOSurface? = nil

        switch configuration.captureMethod {
        case .surfaceBased:
            guard let capture = getViewLayerCapture(),
                  let captureResult = capture.captureTexture(
                    from: sourceView,
                    region: captureRegion,
                    scale: renderScale,
                    excludedViews: []
                  ) else {
                return
            }
            sourceTexture = captureResult.texture
            capturedSurface = captureResult.surface

        case .layerRendering:
            guard let captureDraw = getBackgroundCaptureDraw(),
                  let texture = captureDraw.captureTexture(
                    from: sourceView,
                    region: captureRegion,
                    scale: renderScale,
                    excludedViews: []
                  ) else {
                return
            }
            sourceTexture = texture
        }

        let effectiveRadius = configuration.effectiveBlurRadius(for: currentQuality)
        let effectiveSigma = Float(configuration.effectiveSigma)

        guard let weightsBuffer = blurKernelCalculator.weightsBuffer(
            radius: effectiveRadius,
            sigma: effectiveSigma
        ) else {
            return
        }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            return
        }

        let textureWidth = sourceTexture.width
        let textureHeight = sourceTexture.height

        guard let intermediateTexture1 = texturePool.checkout(width: textureWidth, height: textureHeight),
              let intermediateTexture2 = texturePool.checkout(width: textureWidth, height: textureHeight) else {
            return
        }

        var blurUniforms = GaussianBlurParams(
            texelSize: SIMD2<Float>(1.0 / Float(textureWidth), 1.0 / Float(textureHeight)),
            blurRadius: Int32(effectiveRadius),
            padding: 0
        )

        encodeBlurPass(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: intermediateTexture1,
            uniforms: &blurUniforms,
            weightsBuffer: weightsBuffer,
            isHorizontal: false
        )

        encodeBlurPass(
            commandBuffer: commandBuffer,
            sourceTexture: intermediateTexture1,
            destinationTexture: intermediateTexture2,
            uniforms: &blurUniforms,
            weightsBuffer: weightsBuffer,
            isHorizontal: true
        )

        let outputSize = SIMD2<Float>(Float(drawable.texture.width), Float(drawable.texture.height))
        encodeInnerShadowPass(
            commandBuffer: commandBuffer,
            sourceTexture: intermediateTexture2,
            destinationTexture: intermediateTexture1,
            viewSize: outputSize
        )

        encodeRefractionCompositePass(
            commandBuffer: commandBuffer,
            blurredTexture: intermediateTexture1,
            originalSourceTexture: sourceTexture,
            destinationTexture: drawable.texture,
            viewSize: outputSize
        )

        commandBuffer.encodeSignalEvent(context.sharedEvent, value: frameValue)

        commandBuffer.present(drawable)

        context.sharedEvent.notify(
            context.eventListener,
            atValue: frameValue
        ) { [weak self] _, value in
            guard let self = self else { return }

            self.lastCompletedFrame = value

            self.texturePool.checkin(intermediateTexture1)
            self.texturePool.checkin(intermediateTexture2)

            if let surface = capturedSurface {
                self.getViewLayerCapture()?.recycleSurface(surface)
            }
        }

        commandBuffer.commit()
    }

    private func encodeBlurPass(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        uniforms: inout GaussianBlurParams,
        weightsBuffer: MTLBuffer,
        isHorizontal: Bool
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        guard let pipelineState = isHorizontal ? context.horizontalBlurPipelineState : context.verticalBlurPipelineState else {
            encoder.endEncoding()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(context.quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
        encoder.setFragmentBuffer(weightsBuffer, offset: 0, index: 1)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func encodeInnerShadowPass(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        viewSize: SIMD2<Float>
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let scale = metalLayer?.contentsScale ?? 1
        let innerShadowPadding = SIMD2<Float>(
            Float(configuration.shape.padding.x * scale),
            Float(configuration.shape.padding.y * scale)
        )

        var innerShadowUniforms = ShadowParams(
            viewSize: viewSize,
            cornerRadius: Float(configuration.shape.cornerRadius * scale),
            padding1: 0,
            shapePadding: innerShadowPadding,
            stretchScale: SIMD2<Float>(
                Float(configuration.morph.scale.x),
                Float(configuration.morph.scale.y)
            )
        )

        encoder.setRenderPipelineState(context.innerShadowPipelineState)
        encoder.setVertexBuffer(context.quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentBytes(&innerShadowUniforms, length: MemoryLayout<ShadowParams>.size, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func encodeRefractionCompositePass(
        commandBuffer: MTLCommandBuffer,
        blurredTexture: MTLTexture,
        originalSourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        viewSize: SIMD2<Float>
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        let scale = metalLayer?.contentsScale ?? 1
        let refractionPadding = SIMD2<Float>(
            Float(configuration.shape.padding.x * scale),
            Float(configuration.shape.padding.y * scale)
        )

        var tintR: CGFloat = 0, tintG: CGFloat = 0, tintB: CGFloat = 0, tintA: CGFloat = 0
        configuration.theme.tintColor.getRed(&tintR, green: &tintG, blue: &tintB, alpha: &tintA)

        var specFarR: CGFloat = 0, specFarG: CGFloat = 0, specFarB: CGFloat = 0, specFarA: CGFloat = 0
        configuration.edgeEffects.farColor.getRed(&specFarR, green: &specFarG, blue: &specFarB, alpha: &specFarA)

        var specNearR: CGFloat = 0, specNearG: CGFloat = 0, specNearB: CGFloat = 0, specNearA: CGFloat = 0
        configuration.edgeEffects.nearColor.getRed(&specNearR, green: &specNearG, blue: &specNearB, alpha: &specNearA)

        var refractionUniforms = GlassParams(
            viewSize: viewSize,
            cornerRadius: Float(configuration.shape.cornerRadius * scale),
            opacity: Float(configuration.opacity),
            edgeWidth: Float(configuration.refraction.edgeWidth * scale),
            iorFactor: Float(configuration.refraction.intensity),
            rimRange: Float(configuration.edgeEffects.rimRange),
            rimGlow: Float(configuration.edgeEffects.rimGlow),
            rimCurve: Float(configuration.edgeEffects.rimHardness),
            specularRange: Float(configuration.edgeEffects.glareRange),
            specularIntensity: Float(configuration.edgeEffects.glareIntensity),
            specularFocus: Float(configuration.edgeEffects.glareFocus),
            specularConvergence: Float(configuration.edgeEffects.glareConvergence),
            lightAngle: Float(configuration.edgeEffects.lightAngle),
            oppositeFalloff: Float(configuration.edgeEffects.oppositeFalloff),
            chromaticSpread: Float(configuration.refraction.dispersion),
            mirrorMode: configuration.refraction.reflective ? 1.0 : 0.0,
            stretchScale: SIMD2<Float>(
                Float(configuration.morph.scale.x),
                Float(configuration.morph.scale.y)
            ),
            shapePadding: refractionPadding,
            tint: SIMD4<Float>(Float(tintR), Float(tintG), Float(tintB), Float(tintA)),
            farSpecularColor: SIMD4<Float>(Float(specFarR), Float(specFarG), Float(specFarB), Float(specFarA)),
            nearSpecularColor: SIMD4<Float>(Float(specNearR), Float(specNearG), Float(specNearB), Float(specNearA))
        )

        encoder.setRenderPipelineState(context.refractionCompositePipelineState)
        encoder.setVertexBuffer(context.quadVertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(blurredTexture, index: 0)
        encoder.setFragmentTexture(originalSourceTexture, index: 1)
        encoder.setFragmentBytes(&refractionUniforms, length: MemoryLayout<GlassParams>.size, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    private func calculateCaptureRegion(viewFrame: CGRect, in sourceView: UIView) -> CGRect {
        guard let metalLayer = metalLayer,
              let superlayer = metalLayer.superlayer else {
            let padding = configuration.effectiveCapturePadding
            return viewFrame.insetBy(dx: -padding.x, dy: -padding.y)
        }

        var frameInSource = viewFrame

        if let superviewLayer = superlayer.delegate as? UIView {
            frameInSource = superviewLayer.convert(viewFrame, to: sourceView)
        } else {
            var currentLayer: CALayer? = superlayer
            while let layer = currentLayer {
                if let view = layer.delegate as? UIView {
                    let layerFrameInView = layer.convert(viewFrame, to: view.layer)
                    frameInSource = view.convert(layerFrameInView, to: sourceView)
                    break
                }
                currentLayer = layer.superlayer
            }
        }

        let padding = configuration.effectiveCapturePadding
        return frameInSource.insetBy(dx: -padding.x, dy: -padding.y)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Observe settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleSettingsChange() {
        let settings = TheseusSettings.shared
        currentRefractionQuality = settings.effectiveRefractionQuality

        updateDisplayLinkFrameRate()

        setNeedsRender()
    }

    private func updateDisplayLinkFrameRate() {
        guard let link = displayLink else { return }

        let targetFPS = currentRefractionQuality.frameRate
        link.preferredFramesPerSecond = targetFPS
    }

    @objc private func handleMemoryWarning() {
        texturePool.drain()
        viewLayerCapture?.invalidate()
        backgroundCaptureDraw?.invalidate()
        blurKernelCalculator.invalidateCache()
    }

    @objc private func handleAppWillResignActive() {
        stopRendering()
        texturePool.trimExcess()
    }

    @objc private func handleAppDidBecomeActive() {
        if metalLayer?.superlayer != nil {
            startRendering()
        }
    }
}
