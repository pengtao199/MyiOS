import UIKit
import QuartzCore

/// A Liquid Glass-styled slider with spring-based morphing animations.
public final class TheseusSlider: UIControl {

    /// Layout and animation parameters for the slider.
    public struct Layout {
        public var trackHeight: CGFloat = 5.0
        public var trackMargin: CGFloat = 14.0
        public var internalMargin: CGFloat = 6.0
        public var dotSize: CGFloat = 3.5
        public var knobSize: CGSize = CGSize(width: 36.0, height: 22.0)
        public var edgeFactor: CGFloat { knobSize.width / 4.0 }

        public var expandScale: CGFloat = 1.4
        public var transitionDuration: TimeInterval = 0.18
        public var glassPadding: CGPoint = CGPoint(x: 0.0, y: 0.0)

        public var viscosityForward: CGFloat = 0.6
        public var viscosityBackward: CGFloat { 1.0 - viscosityForward }
        public var snapThreshold: CGFloat = 0.6

        public init() {}
    }

    public var layout = Layout()


    public var minimumValue: CGFloat = 0.0 {
        didSet {
            if minimumValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var maximumValue: CGFloat = 1.0 {
        didSet {
            if maximumValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var startValue: CGFloat = 0.0 {
        didSet {
            if startValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var lowerBoundValue: CGFloat = 0.0 {
        didSet {
            if lowerBoundValue != oldValue {
                setNeedsLayout()
            }
        }
    }

    public private(set) var value: CGFloat = 0.0

    public var positionsCount: Int = 0 {
        didSet {
            if positionsCount != oldValue {
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    public var disableSnapToPositions: Bool = false

    public var markPositions: Bool = true {
        didSet {
            if markPositions != oldValue {
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    public var dotSize: CGFloat {
        get { layout.dotSize }
        set {
            if layout.dotSize != newValue {
                layout.dotSize = newValue
                updatePositionDots()
                setNeedsLayout()
            }
        }
    }

    public var backColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet {
            updateColors()
        }
    }

    public var trackColor: UIColor = UIColor(white: 0.4, alpha: 1.0) {
        didSet {
            updateColors()
        }
    }

    public var lowerBoundTrackColor: UIColor? {
        didSet {
            updateColors()
        }
    }

    public var lineSize: CGFloat {
        get { layout.trackHeight }
        set {
            if layout.trackHeight != newValue {
                layout.trackHeight = newValue
                setNeedsLayout()
            }
        }
    }

    public var trackCornerRadius: CGFloat = 2.5 {
        didSet {
            if trackCornerRadius != oldValue {
                setNeedsLayout()
            }
        }
    }

    public var knobSize: CGSize {
        get { layout.knobSize }
        set {
            if layout.knobSize != newValue {
                layout.knobSize = newValue
                updateKnobImage()
                cachedMetrics = nil
                setNeedsLayout()
            }
        }
    }

    public var knobColor: UIColor = .white {
        didSet {
            if knobColor != oldValue {
                updateKnobImage()
            }
        }
    }

    public var limitValueChangedToLatestState: Bool = false

    public private(set) var knobStartedDragging: Bool = false

    public var onInteractionBegan: (() -> Void)?

    public var onInteractionEnded: (() -> Void)?


    private let trackBackgroundLayer = SimpleLayer()
    private let trackForegroundLayer = SimpleLayer()
    private let knobContainerView = UIView()
    private let knobImageView = UIImageView()
    private var positionDotLayers: [SimpleLayer] = []

    private var knobTouchStart: CGFloat = 0
    private var knobTouchCenterStart: CGFloat = 0
    private var _isTracking: Bool = false

    private var discreteCurrentPosition: Int = 0

    private enum AnimationState {
        case idle
        case tracking
        case animatingShow
        case animatingHide
    }

    private var animationState: AnimationState = .idle

    private var theseusCenterX: CGFloat = 0

    private var scaleVelocity: CGFloat = 0
    private var springScaleCurrent: CGFloat = 1.0
    private var springScaleTarget: CGFloat = 1.0

    private let showTension: CGFloat = 0.58
    private let showFriction: CGFloat = 0.62

    private var hideAnimationStartTime: CFTimeInterval = 0
    private var hideAnimationStartPosition: CGFloat = 0
    private var hideAnimationTargetPosition: CGFloat = 0
    private let hideAnimationDuration: CFTimeInterval = 0.25

    private var showAnimationStartTime: CFTimeInterval = 0
    private let showAnimationDuration: CFTimeInterval = 0.25

    private var displayLink: DisplayLinkDriver.Link?

    private var needsFrameUpdate: Bool = false

    private var originalLineSize: CGFloat = 5.0
    private var stretchedLineSize: CGFloat = 5.0
    private let maxStretchFactor: CGFloat = 0.3
    private let stretchDistance: CGFloat = 100.0  // pixels of overshoot for max stretch

    private struct LayoutMetrics {
        let edgeMargin: CGFloat
        let totalLength: CGFloat
        let trackPadding: CGFloat
        let sideLength: CGFloat
        let knobImageSize: CGSize

        var isValid: Bool { totalLength > 0 && knobImageSize.width > 0 }
    }
    private var cachedMetrics: LayoutMetrics?

    private let hapticManager = HapticManager()

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = self
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    private var theseusView: TheseusView?
    private var theseusStretchAnimator: TheseusStretchAnimator?

    private var lastPanPosition: CGPoint = .zero
    private var lastPanTime: CFTimeInterval = 0
    private var currentVelocity: CGPoint = .zero

    public override var isTracking: Bool {
        _isTracking
    }


    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        originalLineSize = layout.trackHeight
        stretchedLineSize = layout.trackHeight

        setupLayers()
        setupGestureRecognizers()
        updateKnobImage()
    }

    deinit {
        theseusStretchAnimator?.cancelAnimation()
        stopDisplayLink()
    }


    private func setupLayers() {
        layer.addSublayer(trackBackgroundLayer)
        layer.addSublayer(trackForegroundLayer)

        knobContainerView.isUserInteractionEnabled = false
        knobContainerView.addSubview(knobImageView)
        addSubview(knobContainerView)

        updateColors()
    }

    private func setupGestureRecognizers() {
        addGestureRecognizer(panGestureRecognizer)
    }

    private func updateKnobImage() {
        let image = generateDefaultKnobImage(size: layout.knobSize, color: knobColor)
        knobImageView.image = image
        knobImageView.frame = CGRect(origin: .zero, size: image.size)
        cachedMetrics = nil
    }

    private func generateDefaultKnobImage(size: CGSize, color: UIColor) -> UIImage {
        let shadowPadding: CGFloat = 2.0
        let imageSize = CGSize(
            width: size.width + shadowPadding * 2,
            height: size.height + shadowPadding * 2
        )
        let cornerRadius = size.height / 2.0

        return UIGraphicsImageRenderer(size: imageSize).image { ctx in
            let context = ctx.cgContext

            context.setShadow(
                offset: .zero,
                blur: 2.0,
                color: UIColor(white: 0, alpha: 0.15).cgColor
            )
            context.setFillColor(color.cgColor)

            let knobRect = CGRect(
                x: shadowPadding,
                y: shadowPadding,
                width: size.width,
                height: size.height
            )
            let path = UIBezierPath(roundedRect: knobRect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    private func updateColors() {
        trackBackgroundLayer.backgroundColor = backColor.cgColor
        trackForegroundLayer.backgroundColor = trackColor.cgColor
    }

    private func updatePositionDots() {
        for dotLayer in positionDotLayers {
            dotLayer.removeFromSuperlayer()
        }
        positionDotLayers.removeAll()

        guard positionsCount > 1 else { return }

        for i in 0..<positionsCount {
            if !markPositions && i != 0 && i != positionsCount - 1 {
                continue
            }

            let outerDot = SimpleLayer()
            let innerDot = SimpleLayer()
            outerDot.addSublayer(innerDot)

            layer.insertSublayer(outerDot, below: knobContainerView.layer)
            positionDotLayers.append(outerDot)
        }
    }


    public override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }

        if cachedMetrics == nil || cachedMetrics!.sideLength != bounds.height {
            updateLayoutMetrics()
        }

        guard animationState == .idle else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        layoutTrack()
        layoutKnob()
        layoutPositionDots()

        CATransaction.commit()
    }

    private func updateLayoutMetrics() {
        let knobImageSize = knobImageView.image?.size ?? layout.knobSize
        let edgeMargin = knobImageSize.width / 2.0
        let totalLength = bounds.width - edgeMargin * 2

        cachedMetrics = LayoutMetrics(
            edgeMargin: edgeMargin,
            totalLength: totalLength,
            trackPadding: 2.0,
            sideLength: bounds.height,
            knobImageSize: knobImageSize
        )
    }

    private func layoutTrack() {
        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let trackPadding = metrics.trackPadding
        let sideLength = metrics.sideLength

        let backFrame = CGRect(
            x: trackPadding,
            y: (sideLength - layout.trackHeight) / 2,
            width: bounds.width - trackPadding * 2,
            height: layout.trackHeight
        )

        trackBackgroundLayer.frame = backFrame
        trackBackgroundLayer.cornerRadius = trackCornerRadius

        let knobCenterPosition = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: metrics.knobImageSize.width)

        let track = computeTrackFillExtent(
            handlePosition: knobCenterPosition,
            containerWidth: bounds.width,
            marginInset: metrics.edgeMargin,
            innerPadding: trackPadding
        )

        let trackFrame = CGRect(
            x: trackPadding,
            y: (sideLength - layout.trackHeight) / 2,
            width: track,
            height: layout.trackHeight
        )

        trackForegroundLayer.frame = trackFrame
        trackForegroundLayer.cornerRadius = trackCornerRadius
    }

    private func layoutKnob() {
        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let knobCenterPosition = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: metrics.knobImageSize.width)

        let knobFrame = CGRect(
            x: knobCenterPosition - metrics.knobImageSize.width / 2,
            y: (metrics.sideLength - metrics.knobImageSize.height) / 2,
            width: metrics.knobImageSize.width,
            height: metrics.knobImageSize.height
        )

        knobContainerView.frame = knobFrame
        knobImageView.center = CGPoint(x: knobFrame.width / 2, y: knobFrame.height / 2)
    }

    private func layoutPositionDots() {
        guard positionsCount > 1 else { return }

        if cachedMetrics == nil || !(cachedMetrics?.isValid ?? false) {
            updateLayoutMetrics()
        }

        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let dotOffset: CGFloat = 4.0
        let trackCenterY = metrics.sideLength / 2
        let trackBottom = trackCenterY + layout.trackHeight / 2

        var dotIndex = 0
        for i in 0..<positionsCount {
            if !markPositions && i != 0 && i != positionsCount - 1 {
                continue
            }

            guard dotIndex < positionDotLayers.count else { break }
            let outerDot = positionDotLayers[dotIndex]
            dotIndex += 1

            let inset: CGFloat = 1.5
            let outerSize = layout.dotSize + inset * 2

            let dotCenterPosition = metrics.edgeMargin + metrics.totalLength / CGFloat(positionsCount - 1) * CGFloat(i)

            let dotY = trackBottom + dotOffset

            let dotRect = CGRect(
                x: dotCenterPosition - outerSize / 2,
                y: dotY,
                width: outerSize,
                height: outerSize
            )

            outerDot.frame = dotRect
            outerDot.cornerRadius = outerSize / 2
            outerDot.backgroundColor = UIColor.clear.cgColor

            if let innerDot = outerDot.sublayers?.first as? SimpleLayer {
                let innerRect = CGRect(x: inset, y: inset, width: layout.dotSize, height: layout.dotSize)
                innerDot.frame = innerRect
                innerDot.cornerRadius = layout.dotSize / 2
                innerDot.backgroundColor = backColor.cgColor
            }
        }
    }


    private func hermiteInterpolation(_ input: CGFloat) -> CGFloat {
        let clamped = min(max(input, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func biasedQuinticEase(_ normalizedInput: CGFloat, inflectionPoint: CGFloat) -> CGFloat {
        if normalizedInput <= 0 { return 0 }
        if normalizedInput >= 1 { return 1 }

        if normalizedInput < inflectionPoint {
            let scaledProgress = normalizedInput / inflectionPoint
            let quinticValue = scaledProgress * scaledProgress * scaledProgress * scaledProgress * scaledProgress
            return quinticValue * 0.5
        }

        let remainingProgress = (normalizedInput - inflectionPoint) / (1.0 - inflectionPoint)
        let inverseQuintic = 1.0 - pow(1.0 - remainingProgress, 5)
        return 0.5 + inverseQuintic * 0.5
    }

    private func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func computeTrackFillExtent(
        handlePosition: CGFloat,
        containerWidth: CGFloat,
        marginInset: CGFloat,
        innerPadding: CGFloat
    ) -> CGFloat {
        let transitionZone = layout.edgeFactor
        let leadingBoundary = marginInset + transitionZone
        let trailingBoundary = containerWidth - marginInset - transitionZone

        let fillTerminus: CGFloat = {
            if handlePosition <= marginInset {
                return innerPadding
            }
            if handlePosition >= containerWidth - marginInset {
                return containerWidth - innerPadding
            }
            if handlePosition < leadingBoundary {
                let ratio = (handlePosition - marginInset) / transitionZone
                let blendedExtent = leadingBoundary - innerPadding
                return innerPadding + hermiteInterpolation(ratio) * blendedExtent
            }
            if handlePosition > trailingBoundary {
                let ratio = (handlePosition - trailingBoundary) / transitionZone
                let remainingExtent = containerWidth - innerPadding - trailingBoundary
                return trailingBoundary + hermiteInterpolation(ratio) * remainingExtent
            }
            return handlePosition
        }()

        return max(0, fillTerminus - innerPadding)
    }

    // Handles zero-crossing sliders (e.g., -10 to +10) where the center represents zero.
    // Positive values map from center to right edge; negative values map from center to left edge.
    // Each half of the track uses its own proportional scaling based on the edge value magnitude.
    private func centerPositionForValue(_ value: CGFloat, totalLength: CGFloat, knobSize: CGFloat) -> CGFloat {
        if minimumValue < 0 {
            let knob = knobSize

            if abs(minimumValue) > 1.0 && Int(value) == 0 {
                return totalLength / 2
            } else if abs(value) < 0.01 {
                return totalLength / 2
            } else {
                let edgeValue = value > 0 ? maximumValue : minimumValue
                if value > 0 {
                    return ((totalLength + knob) / 2) + ((totalLength - knob) / 2) * abs(value / edgeValue)
                } else {
                    return ((totalLength - knob) / 2) * abs((edgeValue - self.value) / edgeValue)
                }
            }
        }

        let position = totalLength / (maximumValue - minimumValue) * (abs(minimumValue) + value)
        return position
    }

    private func valueForCenterPosition(_ position: CGFloat, totalLength: CGFloat, knobSize: CGFloat) -> CGFloat {
        var value: CGFloat = 0

        if minimumValue < 0 {
            let knob = knobSize

            if position < (totalLength - knob) / 2 {
                let edgeValue = minimumValue
                value = edgeValue + position / ((totalLength - knob) / 2) * abs(edgeValue)
            } else if position >= (totalLength - knob) / 2 && position <= (totalLength + knob) / 2 {
                value = 0
            } else if position > (totalLength + knob) / 2 {
                value = (position - ((totalLength + knob) / 2)) / ((totalLength - knob) / 2) * maximumValue
            }
        } else {
            value = minimumValue + position / totalLength * (maximumValue - minimumValue)
        }

        return min(max(value, minimumValue), maximumValue)
    }

    private func knobCenterFromTheseus(_ theseusCenterX: CGFloat) -> CGFloat {
        return theseusCenterX
    }

    private func valueFromKnobCenter(_ knobCenterX: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        let normalizedPos = knobCenterX - metrics.edgeMargin
        return valueForCenterPosition(normalizedPos, totalLength: metrics.totalLength, knobSize: metrics.knobImageSize.width)
    }

    private func knobCenterFromValue(_ value: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        let normalizedPos = centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: metrics.knobImageSize.width)
        return metrics.edgeMargin + normalizedPos
    }


    public func setValue(_ newValue: CGFloat, animated: Bool = false) {
        var clampedValue = max(minimumValue, min(maximumValue, newValue))
        if lowerBoundValue > .ulpOfOne {
            clampedValue = max(lowerBoundValue, clampedValue)
        }

        value = clampedValue
        if _isTracking == false {
            setNeedsLayout()
        }
    }

    public func increase() {
        setValue(min(maximumValue, value + 1))
        sendActions(for: .valueChanged)
    }

    public func increaseBy(_ delta: CGFloat) {
        setValue(min(maximumValue, value + delta))
        sendActions(for: .valueChanged)
    }

    public func decrease() {
        setValue(max(minimumValue, value - 1))
        sendActions(for: .valueChanged)
    }

    public func decreaseBy(_ delta: CGFloat) {
        setValue(max(minimumValue, value - delta))
        sendActions(for: .valueChanged)
    }


    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        let knobHitArea = knobContainerView.frame.insetBy(dx: -10, dy: -10)
        guard knobHitArea.contains(location) else {
            return false
        }

        handleBeginTracking(location)
        return true
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        return handleContinueTracking(location)
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        handleEndTracking()
    }

    public override func cancelTracking(with event: UIEvent?) {
        handleCancelTracking()
    }

    private func handleBeginTracking(_ location: CGPoint) {
        _isTracking = true
        knobStartedDragging = false

        knobTouchCenterStart = knobContainerView.center.x
        knobTouchStart = location.x

        originalLineSize = layout.trackHeight
        stretchedLineSize = layout.trackHeight

        if positionsCount > 1 {
            let normalizedValue = (value - minimumValue) / (maximumValue - minimumValue)
            discreteCurrentPosition = Int(round(normalizedValue * CGFloat(positionsCount - 1)))
        }

        resetVelocityTracking(at: location)

        maybeCancelParentScrollView(superview, depth: 0)

        showTheseus()
    }

    private func handleContinueTracking(_ location: CGPoint) -> Bool {
        let delta = abs(location.x - knobTouchStart)
        if delta > 1.0 && !knobStartedDragging {
            knobStartedDragging = true
            onInteractionBegan?()

            if animationState == .animatingShow {
                finalizeShowAnimation()
            }
        }

        updateVelocity(at: location)

        guard let metrics = cachedMetrics, metrics.isValid else { return true }

        let edgeMargin = metrics.edgeMargin
        let totalLength = metrics.totalLength
        let knobImageSize = metrics.knobImageSize

        var newCenterX = knobTouchCenterStart - knobTouchStart + location.x

        let minX = edgeMargin
        let maxX = edgeMargin + totalLength
        let overshoot = max(minX - newCenterX, newCenterX - maxX, 0)

        if overshoot > 0 {
            let stretchProgress = min(overshoot / stretchDistance, 1.0)
            let stretchFactor = 1.0 - (stretchProgress * maxStretchFactor)
            stretchedLineSize = originalLineSize * stretchFactor
            updateTrackLineSize(stretchedLineSize)
        } else if stretchedLineSize != originalLineSize {
            stretchedLineSize = originalLineSize
            updateTrackLineSize(stretchedLineSize)
        }

        newCenterX = max(edgeMargin, min(newCenterX, edgeMargin + totalLength))

        let normalizedPosition = newCenterX - edgeMargin

        let previousValue = value

        // Discrete snapping with viscosity: the knob visually lags behind touch using a biased
        // quintic ease curve. The bias (viscosityForward/Backward) controls how much resistance
        // the user feels when dragging toward each direction. Once easedDragRatio exceeds
        // snapThreshold, discreteCurrentPosition updates to the new segment, resetting the origin.
        if positionsCount > 1 && !disableSnapToPositions {
            let segmentLength = totalLength / CGFloat(positionsCount - 1)
            let snapOrigin = CGFloat(discreteCurrentPosition) * segmentLength

            let touchOffset = normalizedPosition - snapOrigin
            let moveSign: CGFloat = touchOffset >= 0 ? 1.0 : -1.0
            let dragRatio = min(abs(touchOffset) / segmentLength, 1.0)

            let easeBias = moveSign > 0 ? layout.viscosityForward : layout.viscosityBackward
            let easedDragRatio = biasedQuinticEase(dragRatio, inflectionPoint: easeBias)

            let dampedPosition = snapOrigin + moveSign * easedDragRatio * segmentLength
            theseusCenterX = edgeMargin + dampedPosition

            if easedDragRatio >= layout.snapThreshold {
                let candidateIndex = discreteCurrentPosition + Int(moveSign)
                let minAllowedIndex = lowerBoundValue > 0 ? Int(lowerBoundValue) : 0
                let clampedIndex = max(minAllowedIndex, min(positionsCount - 1, candidateIndex))

                if clampedIndex != discreteCurrentPosition {
                    discreteCurrentPosition = clampedIndex
                    let computedValue = minimumValue + (maximumValue - minimumValue) * CGFloat(clampedIndex) / CGFloat(positionsCount - 1)
                    setValue(computedValue)
                    triggerHapticFeedback()
                }
            }
        } else {
            if lowerBoundValue > 0 {
                let lowerBoundNormalized = lowerBoundValue * totalLength
                let clampedNormalized = max(normalizedPosition, lowerBoundNormalized)
                theseusCenterX = edgeMargin + clampedNormalized
            } else {
                theseusCenterX = newCenterX
            }

            let normalizedPos = theseusCenterX - edgeMargin
            setValue(valueForCenterPosition(normalizedPos, totalLength: totalLength, knobSize: knobImageSize.width))

            if previousValue != value && !disableSnapToPositions {
                let shouldTriggerHaptic = value == minimumValue ||
                    value == maximumValue ||
                    (minimumValue != startValue && value == startValue)

                if shouldTriggerHaptic {
                    triggerHapticFeedback()
                }
            }
        }

        theseusStretchAnimator?.applyDragVelocity(currentVelocity)

        needsFrameUpdate = true

        if !limitValueChangedToLatestState {
            sendActions(for: .valueChanged)
        }

        return true
    }

    private func handleEndTracking() {
        var finalKnobFrame = knobContainerView.frame

        if positionsCount > 1 && !disableSnapToPositions {
            guard let metrics = cachedMetrics, metrics.isValid else { return }
            let finalKnobCenterX = metrics.edgeMargin + CGFloat(discreteCurrentPosition) * metrics.totalLength / CGFloat(positionsCount - 1)
            finalKnobFrame = CGRect(
                x: finalKnobCenterX - metrics.knobImageSize.width / 2,
                y: (bounds.height - metrics.knobImageSize.height) / 2,
                width: metrics.knobImageSize.width,
                height: metrics.knobImageSize.height
            )
        }

        restoreTrackLineSize(animated: true)

        _isTracking = false

        sendActions(for: .valueChanged)
        setNeedsLayout()

        onInteractionEnded?()

        hideTheseus(animated: true, targetKnobFrame: finalKnobFrame)
    }

    private func handleCancelTracking() {
        restoreTrackLineSize(animated: true)

        _isTracking = false
        setNeedsLayout()
        onInteractionEnded?()

        hideTheseus(animated: true)
    }

    private func resetVelocityTracking(at point: CGPoint) {
        lastPanPosition = point
        lastPanTime = CACurrentMediaTime()
        currentVelocity = .zero
    }

    private func updateVelocity(at point: CGPoint) {
        let currentTime = CACurrentMediaTime()
        let dt = currentTime - lastPanTime

        if dt > (1.0 / 120.0) {
            currentVelocity = CGPoint(
                x: (point.x - lastPanPosition.x) / dt,
                y: (point.y - lastPanPosition.y) / dt
            )
        }

        lastPanPosition = point
        lastPanTime = currentTime
    }

    private func updateTrackLineSize(_ newSize: CGFloat) {
        guard let metrics = cachedMetrics, metrics.isValid else { return }

        let trackPadding = metrics.trackPadding
        let sideLength = metrics.sideLength

        let backFrame = CGRect(
            x: trackPadding,
            y: (sideLength - newSize) / 2,
            width: bounds.width - trackPadding * 2,
            height: newSize
        )
        trackBackgroundLayer.frame = backFrame
        trackBackgroundLayer.cornerRadius = newSize / 2

        let knobCenterPosition = metrics.edgeMargin + centerPositionForValue(value, totalLength: metrics.totalLength, knobSize: metrics.knobImageSize.width)
        let track = computeTrackFillExtent(
            handlePosition: knobCenterPosition,
            containerWidth: bounds.width,
            marginInset: metrics.edgeMargin,
            innerPadding: trackPadding
        )

        let trackFrame = CGRect(
            x: trackPadding,
            y: (sideLength - newSize) / 2,
            width: track,
            height: newSize
        )
        trackForegroundLayer.frame = trackFrame
        trackForegroundLayer.cornerRadius = newSize / 2
    }

    private func restoreTrackLineSize(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
                self.updateTrackLineSize(self.originalLineSize)
            }
        } else {
            updateTrackLineSize(originalLineSize)
        }
        stretchedLineSize = originalLineSize
    }


    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
            self?.displayLinkTick()
        }
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
    }

    private func displayLinkTick() {
        guard let metrics = cachedMetrics, metrics.isValid else { return }

        switch animationState {
        case .idle:
            stopDisplayLink()

        case .tracking:
            guard needsFrameUpdate else { return }
            updateAllFramesFromTheseus(metrics: metrics)
            needsFrameUpdate = false

        case .animatingShow:
            updateShowAnimation()
            updateAllFramesFromTheseus(metrics: metrics)

        case .animatingHide:
            updateHideAnimation()
            updateAllFramesFromTheseus(metrics: metrics)
        }
    }


    private func updateKnobFrameDirect(knobCenterX: CGFloat, metrics: LayoutMetrics) {
        let sideLength = metrics.sideLength
        let knobImageSize = metrics.knobImageSize

        let knobFrame = CGRect(
            x: knobCenterX - knobImageSize.width / 2,
            y: (sideLength - knobImageSize.height) / 2,
            width: knobImageSize.width,
            height: knobImageSize.height
        )

        knobContainerView.frame = knobFrame
        knobImageView.center = CGPoint(x: knobFrame.width / 2, y: knobFrame.height / 2)
    }

    private func updateTrackFramesDirect(knobCenterX: CGFloat, metrics: LayoutMetrics) {
        let edgeMargin = metrics.edgeMargin
        let trackPadding = metrics.trackPadding
        let sideLength = metrics.sideLength

        let track = computeTrackFillExtent(
            handlePosition: knobCenterX,
            containerWidth: bounds.width,
            marginInset: edgeMargin,
            innerPadding: trackPadding
        )

        let currentSize = _isTracking ? stretchedLineSize : layout.trackHeight

        let backFrame = CGRect(
            x: trackPadding,
            y: (sideLength - currentSize) / 2,
            width: bounds.width - trackPadding * 2,
            height: currentSize
        )
        trackBackgroundLayer.frame = backFrame
        trackBackgroundLayer.cornerRadius = currentSize / 2

        let trackFrame = CGRect(
            x: trackPadding,
            y: (sideLength - currentSize) / 2,
            width: track,
            height: currentSize
        )
        trackForegroundLayer.frame = trackFrame
        trackForegroundLayer.cornerRadius = currentSize / 2
    }

    private func updateTheseusFrameDirect(knobCenterX: CGFloat, metrics: LayoutMetrics) {
        guard let glass = theseusView,
              let container = theseusContainer else { return }

        let sideLength = metrics.sideLength
        let knobImageSize = metrics.knobImageSize

        let knobFrame = CGRect(
            x: knobCenterX - knobImageSize.width / 2,
            y: (sideLength - knobImageSize.height) / 2,
            width: knobImageSize.width,
            height: knobImageSize.height
        )

        let targetFrame = theseusFrame(for: knobFrame)
        let targetFrameInContainer = convert(targetFrame, to: container)

        glass.frame = targetFrameInContainer
    }

    private func updateAllFramesFromTheseus(metrics: LayoutMetrics) {
        let clampedCenterX = max(metrics.edgeMargin, min(theseusCenterX, metrics.edgeMargin + metrics.totalLength))

        let knobCenterX = knobCenterFromTheseus(clampedCenterX)

        updateKnobFrameDirect(knobCenterX: knobCenterX, metrics: metrics)
        updateTrackFramesDirect(knobCenterX: knobCenterX, metrics: metrics)
        updateTheseusFrameDirect(knobCenterX: knobCenterX, metrics: metrics)
    }


    private func updateShowAnimation() {
        let elapsed = CACurrentMediaTime() - showAnimationStartTime
        let progress = min(1.0, CGFloat(elapsed / showAnimationDuration))
        let easedProgress = easeInOutQuad(progress)

        let currentAlpha = easedProgress

        let scaleForce = (springScaleTarget - springScaleCurrent) * showTension
        scaleVelocity += scaleForce
        scaleVelocity *= showFriction
        springScaleCurrent += scaleVelocity

        if let glass = theseusView {
            glass.layer.transform = CATransform3DMakeScale(springScaleCurrent, springScaleCurrent, 1.0)
            glass.alpha = currentAlpha
        }

        let timeDone = progress >= 1.0
        let scaleSettled = abs(springScaleCurrent - springScaleTarget) < 0.002 && abs(scaleVelocity) < 0.002

        if timeDone && scaleSettled {
            finalizeShowAnimation()
        }
    }

    private func finalizeShowAnimation() {
        if let glass = theseusView {
            glass.layer.transform = CATransform3DIdentity
            glass.alpha = 1.0
        }

        springScaleCurrent = 1.0
        scaleVelocity = 0

        animationState = .tracking
    }

    private func updateHideAnimation() {
        guard theseusView != nil else {
            finalizeHideAnimation()
            return
        }

        let elapsed = CACurrentMediaTime() - hideAnimationStartTime
        let progress = min(1.0, CGFloat(elapsed / hideAnimationDuration))
        let easedProgress = easeInOutQuad(progress)

        theseusCenterX = hideAnimationStartPosition + (hideAnimationTargetPosition - hideAnimationStartPosition) * easedProgress

        let currentAlpha = 1.0 - easedProgress

        let currentScale = 1.0 + (springScaleTarget - 1.0) * easedProgress

        if let glass = theseusView {
            glass.layer.transform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
            glass.alpha = currentAlpha
        }

        knobImageView.alpha = 1.0 - currentAlpha

        if progress >= 1.0 {
            finalizeHideAnimation()
        }
    }

    private func finalizeHideAnimation() {
        if let glass = theseusView {
            glass.pauseRendering()
            glass.removeFromSuperview()
        }
        theseusView = nil
        theseusStretchAnimator = nil

        knobImageView.alpha = 1.0

        scaleVelocity = 0
        springScaleCurrent = 1.0

        animationState = .idle
        stopDisplayLink()
    }

    private func triggerHapticFeedback() {
        hapticManager.impact(.light)
    }

    private func maybeCancelParentScrollView(_ view: UIView?, depth: Int) {
        guard depth <= 5, let view = view else { return }

        if let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = false
            scrollView.isScrollEnabled = true
        } else {
            maybeCancelParentScrollView(view.superview, depth: depth + 1)
        }
    }


    private var theseusContainer: UIView? {
        theseusSourceView?.superview
    }

    private var theseusSourceView: UIView? {
        if let rootView = window?.rootViewController?.view {
            return rootView
        }
        let currentSize = frame.size
        var current = superview
        var depth = 0
        let maxDepth = 5
        while let view = current, depth < maxDepth {
            let viewSize = view.frame.size
            if viewSize.width > currentSize.width && viewSize.height > currentSize.height {
                return view
            }
            current = view.superview
            depth += 1
        }
        return superview
    }

    private func setupTheseusIfNeeded() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        var config = TheseusConfiguration()
        config.refraction.edgeWidth = 8
        config.shape.padding = CGPoint(x: 10, y: 10)
        config.capturePadding = layout.glassPadding
        config.shape.cornerRadius = layout.knobSize.height * layout.expandScale / 2.0
        config.blur.radius = 2.0
        config.captureMethod = .layerRendering  // More reliable for background capture

        let glass = TheseusView(configuration: config)
        glass.sourceView = sourceView
        glass.isHidden = true
        container.addSubview(glass)
        theseusView = glass

        var stretchConfig = TheseusStretchConfiguration()
        stretchConfig.tension = 0.06
        stretchConfig.friction = 0.85
        stretchConfig.sizeFactor = 0.5
        stretchConfig.squishFactor = 0.7
        stretchConfig.stretchLimit = 0.15

        let stretchAnimator = TheseusStretchAnimator(configuration: stretchConfig)
        stretchAnimator.stretchDidChange = { [weak glass] scale in
            glass?.setMorphScale(scale)
        }
        theseusStretchAnimator = stretchAnimator
    }

    private func theseusFrame(for knobFrame: CGRect) -> CGRect {
        let expandedSize = CGSize(
            width: layout.knobSize.width * layout.expandScale,
            height: layout.knobSize.height * layout.expandScale
        )
        return CGRect(
            x: knobFrame.midX - expandedSize.width / 2,
            y: knobFrame.midY - expandedSize.height / 2,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }

    private func showTheseus() {
        if animationState == .animatingHide {
            finalizeHideAnimation()
        }

        knobImageView.layer.removeAllAnimations()

        setupTheseusIfNeeded()
        guard let glass = theseusView,
              let container = theseusContainer else { return }

        if let sourceView = theseusSourceView, sourceView.bounds.width > 0 {
            glass.sourceView = sourceView
        }
        glass.continuousUpdate = true
        glass.invalidateBackground()

        theseusCenterX = knobContainerView.center.x

        let knobFrame = knobContainerView.frame
        let targetFrame = theseusFrame(for: knobFrame)
        let targetFrameInContainer = convert(targetFrame, to: container)

        glass.frame = targetFrameInContainer
        glass.shape.cornerRadius = targetFrame.height / 2.0

        let scaleX = knobFrame.width / targetFrame.width
        springScaleCurrent = scaleX
        springScaleTarget = 1.0
        scaleVelocity = 0

        showAnimationStartTime = CACurrentMediaTime()

        glass.layer.transform = CATransform3DMakeScale(scaleX, scaleX, 1.0)
        glass.alpha = 0
        glass.isHidden = false

        knobImageView.alpha = 0

        animationState = .animatingShow
        startDisplayLink()

        theseusStretchAnimator?.beginInteraction()
    }

    private func hideTheseus(animated: Bool, targetKnobFrame: CGRect? = nil) {
        if animationState == .animatingShow {
            finalizeShowAnimation()
        }

        guard theseusView != nil else {
            knobImageView.alpha = 1.0
            animationState = .idle
            return
        }

        theseusView?.continuousUpdate = false

        theseusStretchAnimator?.endInteraction()

        let knobFrame = targetKnobFrame ?? knobContainerView.frame
        let targetFrame = theseusFrame(for: knobFrame)

        if !animated {
            finalizeHideAnimation()
            return
        }

        hideAnimationStartTime = CACurrentMediaTime()
        hideAnimationStartPosition = theseusCenterX
        hideAnimationTargetPosition = knobFrame.midX
        springScaleTarget = knobFrame.width / targetFrame.width

        animationState = .animatingHide
        if displayLink == nil {
            startDisplayLink()
        }
    }

    public override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil && animationState != .idle {
            finalizeHideAnimation()
        }
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44.0)
    }
}


extension TheseusSlider: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return true
        }

        let location = gestureRecognizer.location(in: self)
        let knobHitArea = knobContainerView.frame.insetBy(dx: -10, dy: -10)
        guard knobHitArea.contains(location) else {
            return false
        }
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: self)

            if abs(velocity.x) > abs(velocity.y) {
                return true
            } else {
                return false
            }
        }

        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return false
        }
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false
    }
}
