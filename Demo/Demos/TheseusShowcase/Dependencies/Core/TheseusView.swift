import UIKit
import Metal
import QuartzCore

/// A UIView subclass that renders Liquid Glass effects using Metal.
public class TheseusView: UIView {

    public var configuration: TheseusConfiguration = TheseusConfiguration() {
        didSet {
            renderer?.updateConfiguration(configuration)
            fallbackView?.configure(with: configuration)
        }
    }

    public var shape: TheseusShape {
        get { configuration.shape }
        set { configuration.shape = newValue }
    }

    public var blur: TheseusBlur {
        get { configuration.blur }
        set { configuration.blur = newValue }
    }

    public var refraction: TheseusRefraction {
        get { configuration.refraction }
        set { configuration.refraction = newValue }
    }

    public var edgeEffects: TheseusEdgeEffects {
        get { configuration.edgeEffects }
        set { configuration.edgeEffects = newValue }
    }

    public var theme: TheseusTheme {
        get { configuration.theme }
        set { configuration.theme = newValue }
    }

    public var morph: TheseusMorphConfiguration {
        get { configuration.morph }
        set { configuration.morph = newValue }
    }

    public var opacity: CGFloat {
        get { configuration.opacity }
        set { configuration.opacity = newValue }
    }

    public weak var sourceView: UIView? {
        didSet {
            renderer?.updateSourceView(sourceView ?? superview)
        }
    }

    /// When true, captures background continuously during drag gestures for real-time refraction.
    public var continuousUpdate: Bool = false {
        didSet {
            renderer?.continuousUpdate = continuousUpdate
        }
    }

    public var isRendering: Bool {
        renderer?.isRendering ?? false
    }

    public var currentQuality: QualityLevel {
        renderer?.currentQuality ?? .medium
    }

    private var renderer: TheseusRenderer?
    private var fallbackView: VisualEffectFallbackView?
    private var isUsingFallback: Bool = false
    private var metalLayerView: UIView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public convenience init(configuration: TheseusConfiguration) {
        self.init(frame: .zero)
        self.configuration = configuration
    }

    private func commonInit() {
        clipsToBounds = false
        backgroundColor = .clear
        isOpaque = false

        let metalContainer = MetalLayerView()
        metalContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalContainer.frame = bounds
        addSubview(metalContainer)
        metalLayerView = metalContainer

        let metalLayer = metalContainer.metalLayer
        metalLayer.masksToBounds = false
        metalLayer.isOpaque = false
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalLayer.contentsGravity = .center

        metalLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "contentsScale": NSNull()
        ]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsDidChange() {
        updateRenderingMode()
    }

    public var metalLayer: CAMetalLayer? {
        (metalLayerView as? MetalLayerView)?.metalLayer
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if superview != nil {
            updateRenderingMode()
            if !isUsingFallback {
                setupRenderer()
                renderer?.startRendering()
            }
        } else {
            renderer?.stopRendering()
            renderer = nil
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = window, let metalLayer = metalLayer {
            metalLayer.contentsScale = window.screen.scale
            renderer?.setNeedsRender()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        fallbackView?.frame = bounds

        guard let metalLayer = metalLayer else { return }

        let scale = metalLayer.contentsScale
        let paddingX = shape.padding.x * scale
        let paddingY = shape.padding.y * scale
        let drawableSize = CGSize(
            width: bounds.width * scale + paddingX * 2,
            height: bounds.height * scale + paddingY * 2
        )

        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
            renderer?.setNeedsRender()
        }
    }

    public func invalidateBackground() {
        renderer?.setNeedsRender()
    }

    /// Pauses Metal rendering to conserve resources when the view is offscreen or hidden.
    public func pauseRendering() {
        renderer?.stopRendering()
    }

    /// Resumes Metal rendering after a pause.
    public func resumeRendering() {
        renderer?.startRendering()
    }

    public func setBlurRadius(_ radius: CGFloat, animated: Bool = false) {
        blur.radius = radius
    }

    public func setSigma(_ sigma: CGFloat) {
        blur.sigma = sigma
        renderer?.configuration.blur.sigma = sigma
    }

    /// Applies a stretch/squish deformation for spring-based morphing animations.
    public func setMorphScale(_ scale: CGPoint) {
        morph.scale = scale
        renderer?.configuration.morph.scale = scale
        renderer?.setNeedsRender()
    }

    private func setupRenderer() {
        guard renderer == nil, !isUsingFallback else { return }
        guard let metalLayer = metalLayer else { return }

        let effectiveSourceView = sourceView ?? superview
        renderer = TheseusRenderer(
            metalLayer: metalLayer,
            sourceView: effectiveSourceView
        )
        renderer?.configuration = configuration
        renderer?.continuousUpdate = continuousUpdate
    }

    private func updateRenderingMode() {
        let shouldUseFallback = TheseusSettings.shared.shouldUseFallback

        guard shouldUseFallback != isUsingFallback else { return }

        isUsingFallback = shouldUseFallback

        if shouldUseFallback {
            renderer?.stopRendering()
            renderer = nil
            metalLayerView?.isHidden = true

            if fallbackView == nil {
                let fb = VisualEffectFallbackView()
                fb.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                fb.frame = bounds
                insertSubview(fb, at: 0)
                fallbackView = fb
            }
            fallbackView?.isHidden = false
            fallbackView?.configure(with: configuration)
            fallbackView?.updateForTraitCollection(traitCollection)
        } else {
            fallbackView?.isHidden = true

            metalLayerView?.isHidden = false
            setupRenderer()
            renderer?.startRendering()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        fallbackView?.updateForTraitCollection(traitCollection)
    }
}

private class MetalLayerView: UIView {

    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }
}
