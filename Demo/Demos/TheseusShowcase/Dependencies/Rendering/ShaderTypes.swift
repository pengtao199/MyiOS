import simd

/// Parameters for Gaussian blur passes
/// Memory layout must match the struct in TheseusShaders.metal
struct GaussianBlurParams {
    var texelSize: SIMD2<Float>   // 1.0 / textureSize
    var blurRadius: Int32         // Number of samples per direction
    var padding: Int32 = 0        // Alignment padding to 16 bytes
}

/// Parameters for blend/composite pass (final output with corner radius)
/// Memory layout must match the struct in TheseusShaders.metal
struct BlendPassParams {
    var viewSize: SIMD2<Float>    // View size in pixels (8 bytes, aligned to 8)
    var cornerRadius: Float       // Corner radius in pixels (4 bytes)
    var opacity: Float            // Overall opacity (0.0 - 1.0) (4 bytes)
    var shapePadding: SIMD2<Float> // Inset from edges in pixels (8 bytes)
}   // Total: 24 bytes

/// Vertex data for full-screen quad rendering
/// Memory layout must match the struct in TheseusShaders.metal
struct QuadVertex {
    var position: SIMD2<Float>    // Clip-space position (-1 to 1)
    var texCoord: SIMD2<Float>    // Texture coordinates (0 to 1)
}

/// Parameters for glass rendering pass
/// Memory layout must match the struct in TheseusShaders.metal
struct GlassParams {
    var viewSize: SIMD2<Float>    // View size in pixels (8 bytes)
    var cornerRadius: Float       // Corner radius in pixels (4 bytes)
    var opacity: Float            // Overall opacity (4 bytes)
    var edgeWidth: Float          // Refraction edge thickness (4 bytes)
    var iorFactor: Float          // Index of refraction factor (4 bytes)
    var rimRange: Float           // Rim glow effect range (4 bytes)
    var rimGlow: Float            // Rim glow intensity multiplier (4 bytes)
    var rimCurve: Float           // Rim glow curve exponent (4 bytes)
    // Specular/glare parameters
    var specularRange: Float      // Specular effect range (4 bytes)
    var specularIntensity: Float  // Specular intensity multiplier (4 bytes)
    var specularFocus: Float      // Specular focus/sharpness (4 bytes)
    var specularConvergence: Float // Specular convergence (4 bytes)
    var lightAngle: Float         // Light source angle in radians (4 bytes)
    var oppositeFalloff: Float    // Factor for opposite side falloff (4 bytes)
    // Chromatic and tint
    var chromaticSpread: Float    // Chromatic aberration spread (4 bytes)
    var mirrorMode: Float = 0     // Effect mode: 0.0 = lens, 1.0 = mirror (4 bytes)
    var stretchScale: SIMD2<Float> // Morph/stretch scale (8 bytes)
    var shapePadding: SIMD2<Float> // Inset from edges in pixels (8 bytes)
    var tint: SIMD4<Float>        // Tint color RGBA (16 bytes)
    var farSpecularColor: SIMD4<Float>   // Specular color on far side RGBA (16 bytes)
    var nearSpecularColor: SIMD4<Float>  // Specular color on near side RGBA (16 bytes)
}   // Total: 128 bytes

/// Parameters for inner shadow pass
/// Memory layout must match the struct in TheseusShaders.metal
struct ShadowParams {
    var viewSize: SIMD2<Float>      // View size in pixels (8 bytes)
    var cornerRadius: Float         // Corner radius in pixels (4 bytes)
    var padding1: Float = 0         // Alignment padding (4 bytes)
    var shapePadding: SIMD2<Float>  // Inset from edges in pixels (8 bytes)
    var stretchScale: SIMD2<Float>  // Morph/stretch scale (8 bytes)
}   // Total: 32 bytes

