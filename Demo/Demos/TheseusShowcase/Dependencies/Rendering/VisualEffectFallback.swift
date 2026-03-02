import UIKit

/// Fallback glass rendering using UIVisualEffectView for devices without Metal
/// or when using cheapApprox refraction policy
public final class VisualEffectFallbackView: UIView {

    // MARK: - Public Properties

    /// Corner radius of the glass effect
    public var cornerRadius: CGFloat = 16 {
        didSet {
            layer.cornerRadius = cornerRadius
            blurView.layer.cornerRadius = cornerRadius
            rimLayer.cornerRadius = cornerRadius
            updateRimPath()
        }
    }

    /// Tint color for the glass
    public var glassTintColor: UIColor = UIColor(white: 1.0, alpha: 0.1) {
        didSet {
            tintOverlay.backgroundColor = glassTintColor
        }
    }

    /// Shadow opacity
    public var shadowOpacity: Float = 0.15 {
        didSet {
            layer.shadowOpacity = shadowOpacity
        }
    }

    /// Shadow radius
    public var shadowRadius: CGFloat = 12 {
        didSet {
            layer.shadowRadius = shadowRadius
        }
    }

    /// Rim highlight intensity (0-1)
    public var rimIntensity: CGFloat = 0.6 {
        didSet {
            updateRimGradient()
        }
    }

    /// Inner shadow intensity (0-1)
    public var innerShadowIntensity: CGFloat = 0.3 {
        didSet {
            updateInnerShadow()
        }
    }

    // MARK: - Private Views

    private let blurView: UIVisualEffectView
    private let tintOverlay = UIView()
    private let rimLayer = CAGradientLayer()
    private let rimMaskLayer = CAShapeLayer()
    private let innerShadowLayer = CALayer()
    private let innerShadowMaskLayer = CAShapeLayer()

    // MARK: - Initialization

    public init() {
        // Use a light blur for glass effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        blurView = UIVisualEffectView(effect: blurEffect)

        super.init(frame: .zero)
        setupLayers()
    }

    public required init?(coder: NSCoder) {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        blurView = UIVisualEffectView(effect: blurEffect)

        super.init(coder: coder)
        setupLayers()
    }

    // MARK: - Setup

    private func setupLayers() {
        clipsToBounds = false
        layer.masksToBounds = false

        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // Blur background - reduce alpha for transparency
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = cornerRadius
        blurView.alpha = 0.7  // More transparent by default
        addSubview(blurView)

        // Tint overlay
        tintOverlay.backgroundColor = glassTintColor
        tintOverlay.clipsToBounds = true
        tintOverlay.layer.cornerRadius = cornerRadius
        addSubview(tintOverlay)

        // Rim highlight (gradient stroke)
        rimLayer.type = .conic
        rimLayer.startPoint = CGPoint(x: 0.5, y: 0)
        rimLayer.endPoint = CGPoint(x: 0.5, y: 1)
        rimLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        rimMaskLayer.fillColor = nil
        rimMaskLayer.lineWidth = 1.5
        rimLayer.mask = rimMaskLayer
        layer.addSublayer(rimLayer)

        // Inner shadow
        innerShadowLayer.shadowColor = UIColor.black.cgColor
        innerShadowLayer.shadowOpacity = Float(innerShadowIntensity)
        innerShadowLayer.shadowRadius = 6
        innerShadowLayer.shadowOffset = CGSize(width: 0, height: 2)
        innerShadowMaskLayer.fillRule = .evenOdd
        innerShadowLayer.mask = innerShadowMaskLayer
        layer.addSublayer(innerShadowLayer)

        updateRimGradient()
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()

        blurView.frame = bounds
        tintOverlay.frame = bounds
        rimLayer.frame = bounds
        innerShadowLayer.frame = bounds

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath

        updateRimPath()
        updateInnerShadow()
    }

    // MARK: - Updates

    private func updateRimGradient() {
        let highlightColor = UIColor(white: 1.0, alpha: rimIntensity)
        let shadowColor = UIColor(white: 0.0, alpha: rimIntensity * 0.5)
        let transparent = UIColor.clear

        rimLayer.colors = [
            highlightColor.cgColor,
            transparent.cgColor,
            shadowColor.cgColor,
            transparent.cgColor,
            highlightColor.cgColor
        ]
    }

    private func updateRimPath() {
        let inset: CGFloat = 0.75 // half of stroke width
        let rect = bounds.insetBy(dx: inset, dy: inset)
        rimMaskLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius - inset).cgPath
    }

    private func updateInnerShadow() {
        // Create an inner shadow by using a larger outer path and the view bounds as cutout
        let outerRect = bounds.insetBy(dx: -20, dy: -20)
        let outerPath = UIBezierPath(rect: outerRect)
        let innerPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        outerPath.append(innerPath.reversing())

        innerShadowMaskLayer.path = outerPath.cgPath
        innerShadowLayer.shadowPath = innerPath.cgPath
        innerShadowLayer.shadowOpacity = Float(innerShadowIntensity)
    }

    // MARK: - Public Methods

    /// Update blur style based on trait collection
    public func updateForTraitCollection(_ traitCollection: UITraitCollection) {
        let style: UIBlurEffect.Style
        if traitCollection.userInterfaceStyle == .dark {
            style = .systemUltraThinMaterialDark
        } else {
            style = .systemUltraThinMaterialLight
        }
        blurView.effect = UIBlurEffect(style: style)
    }

    /// Configure from TheseusConfiguration
    public func configure(with config: TheseusConfiguration) {
        cornerRadius = config.shape.cornerRadius
        glassTintColor = config.theme.tintColor.withAlphaComponent(0.05)

        // Apply opacity - keep blur subtle for see-through effect
        let opacity = config.opacity
        blurView.alpha = opacity * 0.6  // Reduced for transparency
        tintOverlay.alpha = opacity * 0.15
        rimLayer.opacity = Float(opacity * 0.8)
        innerShadowLayer.opacity = Float(opacity * 0.3)
    }
}

// MARK: - Integration with TheseusSettings

extension VisualEffectFallbackView {

    /// Whether fallback should be used based on current settings
    public static var shouldUseFallback: Bool {
        let settings = TheseusSettings.shared

        // Use fallback if refraction policy is off or cheapApprox
        if settings.effectiveRefractionPolicy != .trueRefraction {
            return true
        }

        // Use fallback if Metal is not available
        if !TheseusCapability.isMetalAvailable {
            return true
        }

        // Use fallback for tier0 devices
        if settings.effectiveTier == .tier0 {
            return true
        }

        return false
    }
}
