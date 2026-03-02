import Metal
import UIKit

/// Singleton Metal context managing device, command queue, and pipeline states
final class MetalContext {

    static let shared: MetalContext? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MetalContext: cannot MTLCreateSystemDefaultDevice")
            return nil
        }
        return MetalContext(device: device)
    }()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary

    private(set) var horizontalBlurPipelineState: MTLRenderPipelineState!
    private(set) var verticalBlurPipelineState: MTLRenderPipelineState!
    private(set) var compositePipelineState: MTLRenderPipelineState!
    private(set) var refractionCompositePipelineState: MTLRenderPipelineState!
    private(set) var innerShadowPipelineState: MTLRenderPipelineState!

    private(set) var quadVertexBuffer: MTLBuffer!

    let recommendedQuality: QualityLevel

    let sharedEvent: MTLSharedEvent
    let eventListener: MTLSharedEventListener
    private let eventNotificationQueue: DispatchQueue

    private init?(device: MTLDevice) {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        // Find the shader bundle within the SPM module bundle
        guard let library = MetalContext.loadMetalLibrary(device: device) else {
            print("MetalContext: cannot load Metal library")
            return nil
        }
        self.library = library

        self.recommendedQuality = Self.detectQualityLevel(device: device)

        guard let sharedEvent = device.makeSharedEvent() else {
            print("MetalContext: cannot makeSharedEvent")
            return nil
        }
        self.sharedEvent = sharedEvent

        self.eventNotificationQueue = DispatchQueue(
            label: "com.theseus.sync",
            qos: .userInitiated
        )
        self.eventListener = MTLSharedEventListener(
            dispatchQueue: self.eventNotificationQueue
        )

        do {
            try setupPipelineStates()
            setupQuadVertexBuffer()
        } catch {
            print("MetalContext: Failed to setup pipeline states: \(error)")
            return nil
        }
    }

    private static func loadMetalLibrary(device: MTLDevice) -> MTLLibrary? {
        let bundle = Bundle.main

        if let libraryURL = bundle.url(forResource: "default", withExtension: "metallib") {
            do {
                return try device.makeLibrary(URL: libraryURL)
            } catch {
                print("MetalContext: Failed to load metallib from URL: \(error)")
            }
        }

        do {
            return try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            print("MetalContext: Failed to make default library from bundle: \(error)")
        }

        // Fallback: try framework-style default library lookup.
        if let defaultLibrary = device.makeDefaultLibrary() {
            return defaultLibrary
        }

        // Last fallback: scan app bundle resources for metallib files.
        if let resourcePath = bundle.resourcePath {
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(atPath: resourcePath) {
                while let filename = enumerator.nextObject() as? String {
                    if filename.hasSuffix(".metallib") {
                        let fullPath = (resourcePath as NSString).appendingPathComponent(filename)
                        do {
                            return try device.makeLibrary(filepath: fullPath)
                        } catch {
                            print("MetalContext: Failed to load metallib at \(fullPath): \(error)")
                        }
                    }
                }
            }
        }

        return nil
    }

    private func setupPipelineStates() throws {
        let vertexFunction = library.makeFunction(name: "vertexPassthrough")
        let horizontalBlurFunction = library.makeFunction(name: "gaussianBlurHorizontal")
        let verticalBlurFunction = library.makeFunction(name: "gaussianBlurVertical")
        let compositeFunction = library.makeFunction(name: "blendPassFragment")

        let blurPipelineDescriptor = MTLRenderPipelineDescriptor()
        blurPipelineDescriptor.vertexFunction = vertexFunction
        blurPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        blurPipelineDescriptor.fragmentFunction = horizontalBlurFunction
        horizontalBlurPipelineState = try device.makeRenderPipelineState(descriptor: blurPipelineDescriptor)

        blurPipelineDescriptor.fragmentFunction = verticalBlurFunction
        verticalBlurPipelineState = try device.makeRenderPipelineState(descriptor: blurPipelineDescriptor)

        let compositePipelineDescriptor = MTLRenderPipelineDescriptor()
        compositePipelineDescriptor.vertexFunction = vertexFunction
        compositePipelineDescriptor.fragmentFunction = compositeFunction
        compositePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        compositePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        compositePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        compositePipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        compositePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        compositePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        compositePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        compositePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        compositePipelineState = try device.makeRenderPipelineState(descriptor: compositePipelineDescriptor)

        let refractionCompositeFunction = library.makeFunction(name: "glassRenderFragment")

        let refractionPipelineDescriptor = MTLRenderPipelineDescriptor()
        refractionPipelineDescriptor.vertexFunction = vertexFunction
        refractionPipelineDescriptor.fragmentFunction = refractionCompositeFunction
        refractionPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        refractionPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        refractionPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        refractionPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        refractionPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        refractionPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        refractionPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        refractionPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        refractionCompositePipelineState = try device.makeRenderPipelineState(descriptor: refractionPipelineDescriptor)

        let innerShadowFunction = library.makeFunction(name: "shadowPassFragment")

        let innerShadowDescriptor = MTLRenderPipelineDescriptor()
        innerShadowDescriptor.vertexFunction = vertexFunction
        innerShadowDescriptor.fragmentFunction = innerShadowFunction
        innerShadowDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        innerShadowDescriptor.colorAttachments[0].isBlendingEnabled = false

        innerShadowPipelineState = try device.makeRenderPipelineState(descriptor: innerShadowDescriptor)
    }

    private func setupQuadVertexBuffer() {
        let vertices: [QuadVertex] = [
            QuadVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1)), // bottom-left
            QuadVertex(position: SIMD2<Float>( 1, -1), texCoord: SIMD2<Float>(1, 1)), // bottom-right
            QuadVertex(position: SIMD2<Float>(-1,  1), texCoord: SIMD2<Float>(0, 0)), // top-left
            QuadVertex(position: SIMD2<Float>( 1,  1), texCoord: SIMD2<Float>(1, 0)), // top-right
        ]

        quadVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<QuadVertex>.stride * vertices.count,
            options: .storageModeShared
        )
    }

    private static func detectQualityLevel(device: MTLDevice) -> QualityLevel {
        if device.supportsFamily(.apple7) {
            return .ultra  // A14 Bionic and later (iPhone 12+)
        } else if device.supportsFamily(.apple5) {
            return .high   // A12 Bionic and later (iPhone XS+)
        } else if device.supportsFamily(.apple4) {
            return .medium // A11 (iPhone 8/X)
        } else if device.supportsFamily(.apple3) {
            return .medium // A9/A10 (iPhone 6s/7)
        }
        // Fallback for unknown GPU families (e.g., future devices or simulators)
        return .high
    }
}
