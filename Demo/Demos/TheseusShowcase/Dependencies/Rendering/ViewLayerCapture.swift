import Metal
import MetalKit
import UIKit
import IOSurface
import CoreVideo

/// Result of a background capture operation
struct CaptureResult {
    let texture: MTLTexture
    let surface: IOSurface
}

/// Pool for reusing IOSurface objects with automatic lifecycle management
private final class SurfacePool {
    private var cache: [SurfaceDimensions: SurfaceEntry] = [:]
    private let lock = NSLock()
    private let maxSurfacesPerSize = 5

    struct SurfaceDimensions: Hashable {
        let width: Int
        let height: Int
    }

    struct SurfaceEntry {
        var available: [IOSurface]
        var inUse: Int
    }

    /// Request a surface of the given dimensions, creating if needed
    func requestSurface(dimensions: SurfaceDimensions) -> IOSurface? {
        lock.lock()
        defer { lock.unlock() }

        if var entry = cache[dimensions], !entry.available.isEmpty {
            let surface = entry.available.removeLast()
            entry.inUse += 1
            cache[dimensions] = entry
            return surface
        }

        return makeSurface(dimensions: dimensions)
    }

    /// Return a surface to the cache for reuse
    func returnSurface(_ surface: IOSurface) {
        lock.lock()
        defer { lock.unlock() }

        let dims = SurfaceDimensions(
            width: IOSurfaceGetWidth(surface),
            height: IOSurfaceGetHeight(surface)
        )

        var entry = cache[dims] ?? SurfaceEntry(available: [], inUse: 0)

        // Only keep if under limit
        guard entry.available.count < maxSurfacesPerSize else {
            return
        }

        entry.available.append(surface)
        if entry.inUse > 0 { entry.inUse -= 1 }
        cache[dims] = entry
    }

    /// Clear all cached surfaces
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    private func makeSurface(dimensions: SurfaceDimensions) -> IOSurface? {
        // Metal textures require 16-byte row alignment for optimal performance
        let rowAlignment = 16
        // BGRA format: 4 bytes per pixel (8 bits each for B, G, R, A)
        let bytesPerPixel = 4
        // Round up to next multiple of rowAlignment
        let bytesPerRow = ((dimensions.width * bytesPerPixel) + rowAlignment - 1) & ~(rowAlignment - 1)

        let props: [IOSurfacePropertyKey: Any] = [
            .width: dimensions.width,
            .height: dimensions.height,
            .bytesPerElement: bytesPerPixel,
            .bytesPerRow: bytesPerRow,
            .allocSize: bytesPerRow * dimensions.height,
            .pixelFormat: kCVPixelFormatType_32BGRA
        ]
        return IOSurfaceCreate(props as CFDictionary)
    }
}

/// Captures view layer content using IOSurface for efficient rendering
final class ViewLayerCapture {

    private let device: MTLDevice
    private let surfacePool = SurfacePool()

    init(device: MTLDevice) {
        self.device = device
    }

    deinit {
        invalidate()
    }

    func captureTexture(
        from sourceView: UIView,
        region: CGRect,
        scale: CGFloat = 1.0,
        excludedViews: [UIView] = []
    ) -> CaptureResult? {
        // Temporarily hide excluded views
        let previousVisibility = excludedViews.map { $0.isHidden }
        excludedViews.forEach { $0.isHidden = true }

        defer {
            for (view, wasHidden) in zip(excludedViews, previousVisibility) {
                view.isHidden = wasHidden
            }
        }

        // Calculate pixel dimensions
        let screenScale = sourceView.window?.screen.scale ?? UIScreen.main.scale
        let renderScale = screenScale * scale

        guard region.width > 0 && region.height > 0 else { return nil }

        let pixelWidth = Int(ceil(region.width * renderScale))
        let pixelHeight = Int(ceil(region.height * renderScale))

        guard pixelWidth > 0 && pixelHeight > 0 else { return nil }

        let dims = SurfacePool.SurfaceDimensions(width: pixelWidth, height: pixelHeight)
        guard let surface = surfacePool.requestSurface(dimensions: dims) else {
            return nil
        }

        // Lock surface for CPU access
        guard IOSurfaceLock(surface, [], nil) == 0 else {
            surfacePool.returnSurface(surface)
            return nil
        }

        defer {
            IOSurfaceUnlock(surface, [], nil)
        }

        // Set up drawing context
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let baseAddress = IOSurfaceGetBaseAddress(surface)

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(
            data: baseAddress,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            surfacePool.returnSurface(surface)
            return nil
        }

        // Clear and configure transform
        ctx.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: renderScale, y: -renderScale)
        ctx.translateBy(x: -region.origin.x, y: -region.origin.y)

        // Render source view
        sourceView.layer.render(in: ctx)

        // Create Metal texture from surface
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        texDesc.usage = [.shaderRead]
        texDesc.storageMode = .shared

        guard let texture = device.makeTexture(
            descriptor: texDesc,
            iosurface: surface,
            plane: 0
        ) else {
            surfacePool.returnSurface(surface)
            return nil
        }

        return CaptureResult(texture: texture, surface: surface)
    }

    /// Return a surface to the cache after use
    func recycleSurface(_ surface: IOSurface) {
        surfacePool.returnSurface(surface)
    }

    /// Invalidate all cached resources
    func invalidate() {
        surfacePool.clearCache()
    }
}
