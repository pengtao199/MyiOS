import Metal
import Foundation

/// A cache for reusing Metal textures to reduce allocation overhead
final class TexturePool {

    private let device: MTLDevice
    private var availableTextures: [TextureDimensions: [MTLTexture]] = [:]
    private let lock = NSLock()
    private let maxPooledPerDimension = 5

    struct TextureDimensions: Hashable {
        let width: Int
        let height: Int
        let format: MTLPixelFormat
    }

    init(device: MTLDevice) {
        self.device = device
    }

    /// Get a texture matching the specification, creating if needed
    func checkout(width: Int, height: Int, format: MTLPixelFormat = .bgra8Unorm) -> MTLTexture? {
        lock.lock()
        defer { lock.unlock() }

        let dims = TextureDimensions(width: width, height: height, format: format)

        if var pooled = availableTextures[dims], !pooled.isEmpty {
            let texture = pooled.removeLast()
            availableTextures[dims] = pooled
            return texture
        }

        return createTexture(dimensions: dims)
    }

    /// Return a texture to the pool for reuse
    func checkin(_ texture: MTLTexture) {
        lock.lock()
        defer { lock.unlock() }

        let dims = TextureDimensions(
            width: texture.width,
            height: texture.height,
            format: texture.pixelFormat
        )

        guard (availableTextures[dims]?.count ?? 0) < maxPooledPerDimension else {
            return
        }

        availableTextures[dims, default: []].append(texture)
    }

    /// Clear all pooled textures
    func drain() {
        lock.lock()
        defer { lock.unlock() }
        availableTextures.removeAll()
    }

    /// Trim pool to reduce memory usage
    func trimExcess() {
        lock.lock()
        defer { lock.unlock() }

        for dims in availableTextures.keys {
            if let textures = availableTextures[dims], textures.count > 1 {
                availableTextures[dims] = Array(textures.suffix(1))
            }
        }
    }

    /// Statistics about the texture pool state
    struct PoolStatistics {
        let pooledCount: Int
        let dimensionVariants: Int
    }

    var statistics: PoolStatistics {
        lock.lock()
        defer { lock.unlock() }

        let count = availableTextures.values.reduce(0) { $0 + $1.count }
        return PoolStatistics(pooledCount: count, dimensionVariants: availableTextures.count)
    }

    private func createTexture(dimensions dims: TextureDimensions) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: dims.format,
            width: dims.width,
            height: dims.height,
            mipmapped: false
        )

        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]

        return device.makeTexture(descriptor: descriptor)
    }

}
