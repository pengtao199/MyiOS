import UIKit

/// How background content is captured for refraction effects.
public enum CaptureMethod {
    case surfaceBased
    case layerRendering
}

/// Light or dark appearance settings with optional color tint.
public struct TheseusTheme {
    public var isDark: Bool
    public var tintColor: UIColor
    public var tintOpacity: CGFloat

    public init(
        isDark: Bool = false,
        tintColor: UIColor = .clear,
        tintOpacity: CGFloat = 1.0
    ) {
        self.isDark = isDark
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
    }

    public static let light = TheseusTheme(isDark: false)
    public static let dark = TheseusTheme(isDark: true)
}

/// Controls how edge refraction is rendered.
public enum RefractionMode {
    case disabled
    case approximate
    case precise
}

/// Quality level for refraction rendering, affects GPU performance.
public enum RefractionFidelity: Int {
    case low = 0
    case medium = 1
    case high = 2
}

/// Edge refraction settings that create the Liquid Glass light-bending effect.
public struct TheseusRefraction {
    public var mode: RefractionMode
    public var edgeWidth: CGFloat
    public var intensity: CGFloat
    public var dispersion: CGFloat
    public var fidelity: RefractionFidelity
    public var reflective: Bool

    public init(
        mode: RefractionMode = .precise,
        edgeWidth: CGFloat = 15.0,
        intensity: CGFloat = 1.45,
        dispersion: CGFloat = 4.0,
        fidelity: RefractionFidelity = .high,
        reflective: Bool = false
    ) {
        self.mode = mode
        self.edgeWidth = edgeWidth
        self.intensity = intensity
        self.dispersion = dispersion
        self.fidelity = fidelity
        self.reflective = reflective
    }

    public static let disabled = TheseusRefraction(mode: .disabled, intensity: 0)
    public static let subtle = TheseusRefraction(edgeWidth: 10, intensity: 1.2, dispersion: 2.0)
    public static let standard = TheseusRefraction()
    public static let pronounced = TheseusRefraction(edgeWidth: 20, intensity: 1.8, dispersion: 6.0)
}

/// Gaussian blur settings for the frosted glass background.
public struct TheseusBlur {
    public var radius: CGFloat
    public var sigma: CGFloat?
    public var vibrancy: CGFloat
    public var luminance: CGFloat

    private static let sigmaToRadiusRatio: CGFloat = 0.3

    public init(
        radius: CGFloat = 1.0,
        sigma: CGFloat? = nil,
        vibrancy: CGFloat = 1.0,
        luminance: CGFloat = 1.0
    ) {
        self.radius = radius
        self.sigma = sigma
        self.vibrancy = vibrancy
        self.luminance = luminance
    }

    public var effectiveSigma: CGFloat {
        sigma ?? (radius * Self.sigmaToRadiusRatio)
    }

    public static let none = TheseusBlur(radius: 0)
    public static let light = TheseusBlur(radius: 0.5)
    public static let standard = TheseusBlur()
    public static let heavy = TheseusBlur(radius: 2.0)
}

/// Rim lighting and specular glare settings for depth and dimensionality.
public struct TheseusEdgeEffects {
    public var rimRange: CGFloat
    public var rimGlow: CGFloat
    public var rimHardness: CGFloat

    public var glareRange: CGFloat
    public var glareIntensity: CGFloat
    public var glareFocus: CGFloat
    public var glareConvergence: CGFloat
    public var lightAngle: CGFloat
    public var oppositeFalloff: CGFloat
    public var farColor: UIColor
    public var nearColor: UIColor

    public init(
        rimRange: CGFloat = 45.0,
        rimGlow: CGFloat = 0.5,
        rimHardness: CGFloat = 12.0,
        glareRange: CGFloat = 450.0,
        glareIntensity: CGFloat = 1.0,
        glareFocus: CGFloat = 0.55,
        glareConvergence: CGFloat = 0.75,
        lightAngle: CGFloat = .pi * 0.3,
        oppositeFalloff: CGFloat = 0.6,
        farColor: UIColor = UIColor(white: 0.0, alpha: 0.7),
        nearColor: UIColor = UIColor(white: 1.0, alpha: 0.7)
    ) {
        self.rimRange = rimRange
        self.rimGlow = rimGlow
        self.rimHardness = rimHardness
        self.glareRange = glareRange
        self.glareIntensity = glareIntensity
        self.glareFocus = glareFocus
        self.glareConvergence = glareConvergence
        self.lightAngle = lightAngle
        self.oppositeFalloff = oppositeFalloff
        self.farColor = farColor
        self.nearColor = nearColor
    }

    public static let subtle = TheseusEdgeEffects(rimGlow: 0.3, glareIntensity: 0.5)
    public static let standard = TheseusEdgeEffects()
    public static let dramatic = TheseusEdgeEffects(rimGlow: 0.8, glareIntensity: 1.5)
}

/// Corner radius and padding for the Liquid Glass shape.
public struct TheseusShape {
    public var cornerRadius: CGFloat
    public var padding: CGPoint

    public init(
        cornerRadius: CGFloat = 18.0,
        padding: CGPoint = .zero
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    public static let pill = TheseusShape(cornerRadius: 9999)
    public static let rounded = TheseusShape(cornerRadius: 12)
    public static let card = TheseusShape(cornerRadius: 20)
}

/// Spring physics parameters for stretch/squish morphing animations during gestures.
public struct TheseusMorphConfiguration {
    public var scale: CGPoint
    public var sizeFactor: CGFloat
    public var tension: CGFloat
    public var friction: CGFloat
    public var squish: CGFloat
    public var smoothing: CGFloat

    public init(
        scale: CGPoint = CGPoint(x: 1.0, y: 1.0),
        sizeFactor: CGFloat = 0.35,
        tension: CGFloat = 0.18,
        friction: CGFloat = 0.88,
        squish: CGFloat = 0.55,
        smoothing: CGFloat = 0.45
    ) {
        self.scale = scale
        self.sizeFactor = sizeFactor
        self.tension = tension
        self.friction = friction
        self.squish = squish
        self.smoothing = smoothing
    }

    public static let `default` = TheseusMorphConfiguration()
    public static let subtle = TheseusMorphConfiguration(sizeFactor: 0.2, tension: 0.1)
    public static let bouncy = TheseusMorphConfiguration(tension: 0.25, friction: 0.8)
}

/// Complete configuration for a Liquid Glass view, combining all visual and animation settings.
public struct TheseusConfiguration {

    public var theme: TheseusTheme

    public var refraction: TheseusRefraction

    public var blur: TheseusBlur

    public var edgeEffects: TheseusEdgeEffects

    public var shape: TheseusShape

    public var morph: TheseusMorphConfiguration

    public var quality: QualityLevel?

    public var opacity: CGFloat

    public var capturePadding: CGPoint?

    public var captureMethod: CaptureMethod

    public init(
        theme: TheseusTheme = .light,
        refraction: TheseusRefraction = .standard,
        blur: TheseusBlur = .standard,
        edgeEffects: TheseusEdgeEffects = .standard,
        shape: TheseusShape = TheseusShape(),
        morph: TheseusMorphConfiguration = .default,
        quality: QualityLevel? = nil,
        opacity: CGFloat = 1.0,
        capturePadding: CGPoint? = nil,
        captureMethod: CaptureMethod = .surfaceBased
    ) {
        self.theme = theme
        self.refraction = refraction
        self.blur = blur
        self.edgeEffects = edgeEffects
        self.shape = shape
        self.morph = morph
        self.quality = quality
        self.opacity = opacity
        self.capturePadding = capturePadding
        self.captureMethod = captureMethod
    }

    public var effectiveSigma: CGFloat {
        blur.effectiveSigma
    }

    private static let capturePaddingMultiplier: CGFloat = 1.2

    public var effectiveCapturePadding: CGPoint {
        let defaultPadding = blur.radius * Self.capturePaddingMultiplier
        return CGPoint(
            x: (capturePadding?.x ?? defaultPadding) + shape.padding.x,
            y: (capturePadding?.y ?? defaultPadding) + shape.padding.y
        )
    }

    public func effectiveBlurRadius(for quality: QualityLevel) -> Int {
        min(Int(blur.radius), quality.maxBlurRadius)
    }
}
