import UIKit
import QuartzCore

/// A Liquid Glass-styled toggle switch with smooth thumb animations.
public class TheseusSwitch: UIControl {

    /// Layout dimensions and animation timing for the switch.
    public struct Layout {
        public var trackSize = CGSize(width: 62.0, height: 30.0)
        public var thumbSize = CGSize(width: 38.0, height: 26.0)
        public var thumbInset: CGFloat = 2.5
        public var trackCornerRadius: CGFloat = 15.0
        public var thumbCornerRadius: CGFloat = 13.0
        public var transitionDuration: TimeInterval = 0.22

        public var glassSize = CGSize(width: 52.0, height: 36.0)
        public var glassCornerRadius: CGFloat { glassSize.height / 2.0 }
        public var glassTransitionDuration: TimeInterval = 0.18
        public var glassPadding = CGPoint(x: 6.0, y: 6.0)
        public var glassStretchFactor: CGFloat = 1.05

        public var glassTrackHeight: CGFloat { trackSize.height }
        public var glassTrackCornerRadius: CGFloat { glassTrackHeight / 2.0 }

        public init() {}
    }

    public var layout = Layout()


    public var isOn: Bool {
        get { _isOn }
        set {
            guard _isOn != newValue else { return }
            _isOn = newValue
            visuallyOn = newValue
            updateThumbPosition(animated: false)
            updateTrackColor(animated: false)
        }
    }
    private var _isOn: Bool = false

    public var onValueChanged: ((Bool) -> Void)?

    public var onTintColor: UIColor = UIColor(red: 0.259, green: 0.831, blue: 0.318, alpha: 1.0) {
        didSet {
            if _isOn {
                updateTrackColor(animated: false)
            }
        }
    }

    public var offTintColor: UIColor = UIColor(white: 0.878, alpha: 1.0) {
        didSet {
            if !_isOn {
                updateTrackColor(animated: false)
            }
        }
    }

    public var thumbTintColor: UIColor = .white {
        didSet {
            thumbLayer.backgroundColor = thumbTintColor.cgColor
        }
    }


    private let contentView = UIView()
    private let trackLayer = SimpleLayer()
    private let thumbLayer = SimpleLayer()

    private var visuallyOn: Bool = false

    private var theseusView: TheseusView?
    private var theseusStretchAnimator: TheseusStretchAnimator?

    private var lastPanPosition: CGPoint = .zero
    private var lastPanTime: CFTimeInterval = 0
    private var currentVelocity: CGPoint = .zero

    private var thumbPositionAnimationLink: DisplayLinkDriver.Link?

    private var contentMaskLayer: CAShapeLayer?
    private var glassTrackView: UIView?
    private var glassTrackMaskLayer: CAShapeLayer?

    private let hapticFeedback = HapticManager()

    private var panStartThumbX: CGFloat = 0
    private var isPanning: Bool = false
    private var tapAnimationToken: Int = 0

    private var thumbMinX: CGFloat { layout.thumbInset }
    private var thumbMaxX: CGFloat { bounds.width - layout.thumbSize.width - layout.thumbInset }
    private var thumbOffX: CGFloat { thumbMinX }
    private var thumbOnX: CGFloat { thumbMaxX }


    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupGestures()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupGestures()
    }

    deinit {
        thumbPositionAnimationLink?.invalidate()
        theseusStretchAnimator?.cancelAnimation()
    }

    private func setupLayers() {
        contentView.isUserInteractionEnabled = false
        addSubview(contentView)

        trackLayer.backgroundColor = offTintColor.cgColor
        trackLayer.cornerRadius = layout.trackCornerRadius
        contentView.layer.addSublayer(trackLayer)

        thumbLayer.backgroundColor = thumbTintColor.cgColor
        thumbLayer.cornerRadius = layout.thumbCornerRadius
        thumbLayer.shadowColor = UIColor.black.cgColor
        thumbLayer.shadowOffset = CGSize(width: 0, height: 2)
        thumbLayer.shadowOpacity = 0.2
        thumbLayer.shadowRadius = 4
        contentView.layer.addSublayer(thumbLayer)
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }


    public override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0 && bounds.height > 0 else { return }

        contentView.frame = bounds
        trackLayer.frame = bounds

        let thumbY = (bounds.height - layout.thumbSize.height) / 2.0
        let thumbX = _isOn ? thumbOnX : thumbOffX
        thumbLayer.frame = CGRect(x: thumbX, y: thumbY, width: layout.thumbSize.width, height: layout.thumbSize.height)
    }

    public override var intrinsicContentSize: CGSize {
        layout.trackSize
    }


    public func setOn(_ on: Bool, animated: Bool) {
        guard _isOn != on else { return }
        _isOn = on
        visuallyOn = on
        updateThumbPosition(animated: animated)
        updateTrackColor(animated: animated)
    }


    private func updateThumbPosition(animated: Bool) {
        guard bounds.width > 0 && bounds.height > 0 else { return }

        let targetX = _isOn ? thumbOnX : thumbOffX
        let thumbY = (bounds.height - layout.thumbSize.height) / 2.0
        let newFrame = CGRect(x: targetX, y: thumbY, width: layout.thumbSize.width, height: layout.thumbSize.height)

        if animated {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = thumbLayer.position
            animation.toValue = CGPoint(x: newFrame.midX, y: newFrame.midY)
            animation.duration = layout.transitionDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .backwards
            thumbLayer.add(animation, forKey: "position")
        }

        thumbLayer.frame = newFrame
    }

    private func updateTrackColor(animated: Bool) {
        let targetColor = visuallyOn ? onTintColor.cgColor : offTintColor.cgColor

        if animated {
            let animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.fromValue = trackLayer.backgroundColor
            animation.toValue = targetColor
            animation.duration = layout.transitionDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .backwards
            trackLayer.add(animation, forKey: "backgroundColor")
        }

        trackLayer.backgroundColor = targetColor
        updateGlassTrackColor(animated: animated)
    }

    private func setThumbX(_ x: CGFloat, animated: Bool = false) {
        setThumbXInternal(x, animated: animated, allowsFeedback: true)
    }

    private func setThumbXInternal(_ x: CGFloat, animated: Bool, allowsFeedback: Bool) {
        guard bounds.width > 0 && bounds.height > 0 else { return }

        let clampedX = max(thumbMinX, min(thumbMaxX, x))
        let thumbY = (bounds.height - layout.thumbSize.height) / 2.0
        let newFrame = CGRect(x: clampedX, y: thumbY, width: layout.thumbSize.width, height: layout.thumbSize.height)

        if animated {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = thumbLayer.position
            animation.toValue = CGPoint(x: newFrame.midX, y: newFrame.midY)
            animation.duration = layout.transitionDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .backwards
            thumbLayer.add(animation, forKey: "position")
        }

        thumbLayer.frame = newFrame

        guard allowsFeedback else { return }

        if clampedX <= thumbMinX && visuallyOn {
            visuallyOn = false
            updateTrackColor(animated: true)
            hapticFeedback.impact(.light)
        } else if clampedX >= thumbMaxX && !visuallyOn {
            visuallyOn = true
            updateTrackColor(animated: true)
            hapticFeedback.impact(.light)
        }
    }

    // Glass stretches wider as thumb approaches either edge, creating a subtle "squeeze" effect.
    // normalizedDistance is 0 at center, 1 at edges; multiplier interpolates from 1.0 to glassStretchFactor.
    private func glassWidthMultiplier(for thumbX: CGFloat) -> CGFloat {
        guard thumbMaxX > thumbMinX else { return 1.0 }
        let centerX = (thumbMinX + thumbMaxX) / 2.0
        let maxDistance = (thumbMaxX - thumbMinX) / 2.0
        let normalizedDistance = abs(thumbX - centerX) / maxDistance
        return 1.0 + (layout.glassStretchFactor - 1.0) * normalizedDistance
    }

    private func glassFrame(for thumbFrame: CGRect) -> CGRect {
        let widthMultiplier = glassWidthMultiplier(for: thumbFrame.origin.x)
        let dynamicWidth = layout.glassSize.width * widthMultiplier
        return CGRect(
            x: thumbFrame.midX - dynamicWidth / 2,
            y: thumbFrame.midY - layout.glassSize.height / 2,
            width: dynamicWidth,
            height: layout.glassSize.height
        )
    }


    private func setupGlassTrackIfNeeded() {
        guard glassTrackView == nil else { return }

        let trackView = UIView()
        trackView.backgroundColor = visuallyOn ? onTintColor : offTintColor
        trackView.layer.cornerRadius = layout.glassTrackCornerRadius
        trackView.isHidden = true
        trackView.isUserInteractionEnabled = false

        contentView.addSubview(trackView)
        contentView.sendSubviewToBack(trackView)

        glassTrackView = trackView
    }

    private func updateGlassTrackFrame() {
        guard let trackView = glassTrackView else { return }

        let trackHeight = layout.glassTrackHeight
        let trackFrame = CGRect(
            x: -layout.glassPadding.x / 2.0,
            y: (contentView.bounds.height - trackHeight) / 2.0,
            width: contentView.bounds.width + layout.glassPadding.x,
            height: trackHeight
        )
        trackView.frame = trackFrame
    }

    private func updateGlassTrackColor(animated: Bool) {
        guard let trackView = glassTrackView else { return }

        let targetColor = visuallyOn ? onTintColor : offTintColor

        if animated {
            UIView.animate(withDuration: layout.transitionDuration) {
                trackView.backgroundColor = targetColor
            }
        } else {
            trackView.backgroundColor = targetColor
        }
    }


    private func updateContentMask(cutoutFrame: CGRect?, cornerRadius: CGFloat) {
        guard let cutoutFrame = cutoutFrame else {
            trackLayer.mask = nil
            contentMaskLayer = nil
            return
        }

        let maskLayer: CAShapeLayer
        if let existing = contentMaskLayer {
            maskLayer = existing
        } else {
            maskLayer = CAShapeLayer()
            maskLayer.fillRule = .evenOdd
            maskLayer.fillColor = UIColor.black.cgColor
            contentMaskLayer = maskLayer
            trackLayer.mask = maskLayer
        }

        let path = UIBezierPath(rect: contentView.bounds)
        let cutoutPath = UIBezierPath(roundedRect: cutoutFrame, cornerRadius: cornerRadius)
        path.append(cutoutPath)

        maskLayer.path = path.cgPath
    }

    private func updateGlassTrackMask(visibleFrame: CGRect?, cornerRadius: CGFloat) {
        guard let trackView = glassTrackView else { return }

        guard let visibleFrame = visibleFrame else {
            trackView.layer.mask = nil
            glassTrackMaskLayer = nil
            trackView.isHidden = true
            return
        }

        trackView.isHidden = false

        let maskLayer: CAShapeLayer
        if let existing = glassTrackMaskLayer {
            maskLayer = existing
        } else {
            maskLayer = CAShapeLayer()
            maskLayer.fillColor = UIColor.black.cgColor
            glassTrackMaskLayer = maskLayer
            trackView.layer.mask = maskLayer
        }

        let localFrame = trackView.convert(visibleFrame, from: self)
        let path = UIBezierPath(roundedRect: localFrame, cornerRadius: cornerRadius)
        maskLayer.path = path.cgPath
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

    private var theseusContainer: UIView? {
        theseusSourceView?.superview
    }

    private func convertToTheseusContainer(_ frame: CGRect) -> CGRect {
        guard let container = theseusContainer else { return frame }
        return convert(frame, to: container)
    }

    private func setupTheseusIfNeeded() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        var config = TheseusConfiguration()
        config.refraction.edgeWidth = 7
        config.refraction.intensity = 1.15        // Balanced - visible but less green
        config.shape.padding = CGPoint(x: 10, y: 10)
        config.capturePadding = layout.glassPadding
        config.shape.cornerRadius = layout.glassCornerRadius

        // Moderate blur
        config.blur.radius = 2.5

        // Visible rim glow for iridescence
        config.edgeEffects.rimGlow = 0.6
        config.edgeEffects.glareIntensity = 1.0
        config.edgeEffects.rimRange = 50.0
        config.edgeEffects.nearColor = .clear
        config.edgeEffects.farColor = .clear

        // Use more reliable capture method
        config.captureMethod = .layerRendering

        let glass = TheseusView(configuration: config)
        glass.sourceView = sourceView
        glass.isHidden = true
        container.addSubview(glass)
        theseusView = glass

        let stretchAnimator = TheseusStretchAnimator()
        stretchAnimator.stretchDidChange = { [weak glass] scale in
            glass?.setMorphScale(scale)
        }
        theseusStretchAnimator = stretchAnimator
    }

    private func showTheseus() {
        setupTheseusIfNeeded()
        guard let glass = theseusView else { return }

        if let sourceView = theseusSourceView, sourceView.bounds.width > 0 {
            glass.sourceView = sourceView
        }
        glass.continuousUpdate = true
        glass.invalidateBackground()

        setupGlassTrackIfNeeded()
        updateGlassTrackFrame()

        let thumbFrameLocal = thumbLayer.frame
        let targetFrameLocal = glassFrame(for: thumbFrameLocal)
        let targetFrameInContainer = convertToTheseusContainer(targetFrameLocal)

        glass.frame = targetFrameInContainer
        glass.shape.cornerRadius = layout.glassCornerRadius

        let scaleX = thumbFrameLocal.width / targetFrameLocal.width
        let scaleY = thumbFrameLocal.height / targetFrameLocal.height
        glass.layer.transform = CATransform3DMakeScale(scaleX, scaleY, 1.0)

        glass.alpha = 0
        glass.isHidden = false

        updateContentMask(cutoutFrame: thumbFrameLocal, cornerRadius: thumbFrameLocal.height / 2.0)
        updateGlassTrackMask(visibleFrame: thumbFrameLocal, cornerRadius: thumbFrameLocal.height / 2.0)

        let transition = LayoutTransition.animated(duration: layout.glassTransitionDuration, curve: .easeInOut)
        transition.updateTransformScale(layer: glass.layer, scale: CGPoint(x: 1.0, y: 1.0))
        transition.updateAlpha(layer: glass.layer, alpha: 1.0)
        transition.updateAlpha(layer: thumbLayer, alpha: 0.0)

        updateContentMask(cutoutFrame: targetFrameLocal, cornerRadius: layout.glassCornerRadius)
        updateGlassTrackMask(visibleFrame: targetFrameLocal, cornerRadius: layout.glassCornerRadius)

        theseusStretchAnimator?.beginInteraction()
    }

    private func hideTheseus(toThumbFrame targetThumbFrameLocal: CGRect, animated: Bool, completion: (() -> Void)? = nil) {
        guard let glass = theseusView else {
            completion?()
            return
        }

        glass.continuousUpdate = false

        let stretchAnimator = theseusStretchAnimator
        let trackView = glassTrackView
        let trackMaskLayer = glassTrackMaskLayer
        let maskLayer = contentMaskLayer

        theseusView = nil
        theseusStretchAnimator = nil
        glassTrackView = nil
        glassTrackMaskLayer = nil
        contentMaskLayer = nil

        stretchAnimator?.endInteraction()

        let transition: LayoutTransition = animated
            ? .animated(duration: layout.glassTransitionDuration, curve: .easeInOut)
            : .immediate

        let finalFrameLocal = glassFrame(for: targetThumbFrameLocal)
        let finalFrameInContainer = convertToTheseusContainer(finalFrameLocal)
        transition.updateFrame(view: glass, frame: finalFrameInContainer)

        let scaleX = targetThumbFrameLocal.width / finalFrameLocal.width
        let scaleY = targetThumbFrameLocal.height / finalFrameLocal.height
        transition.updateTransformScale(layer: glass.layer, scale: CGPoint(x: scaleX, y: scaleY)) { [weak self] _ in
            stretchAnimator?.cancelAnimation()
            glass.layer.transform = CATransform3DIdentity
            glass.pauseRendering()
            glass.removeFromSuperview()

            if self?.trackLayer.mask === maskLayer {
                self?.trackLayer.mask = nil
            }

            trackView?.layer.mask = nil
            trackView?.removeFromSuperview()
            completion?()
        }
        transition.updateAlpha(layer: glass.layer, alpha: 0.0)

        if let trackView = trackView, let trackMaskLayer = trackMaskLayer {
            let localFrame = trackView.convert(targetThumbFrameLocal, from: self)
            let path = UIBezierPath(roundedRect: localFrame, cornerRadius: targetThumbFrameLocal.height / 2.0)
            trackMaskLayer.path = path.cgPath
        }

        if let maskLayer = maskLayer {
            let path = UIBezierPath(rect: contentView.bounds)
            let cutoutPath = UIBezierPath(roundedRect: targetThumbFrameLocal, cornerRadius: targetThumbFrameLocal.height / 2.0)
            path.append(cutoutPath)
            maskLayer.path = path.cgPath
        }

        transition.updateAlpha(layer: thumbLayer, alpha: 1.0)
    }

    private func updateTheseusFrame() {
        guard let glass = theseusView else { return }

        let frameLocal = glassFrame(for: thumbLayer.frame)
        let frameInContainer = convertToTheseusContainer(frameLocal)

        glass.frame = frameInContainer

        updateContentMask(cutoutFrame: frameLocal, cornerRadius: glass.shape.cornerRadius)
        updateGlassTrackMask(visibleFrame: frameLocal, cornerRadius: glass.shape.cornerRadius)
    }

    private func cancelThumbPositionAnimation() {
        thumbPositionAnimationLink?.invalidate()
        thumbPositionAnimationLink = nil
    }

    private func animateThumbForTap(to targetX: CGFloat, duration: CFTimeInterval, completion: (() -> Void)? = nil) {
        cancelThumbPositionAnimation()

        let startX = thumbLayer.frame.origin.x
        let clampedTargetX = max(thumbMinX, min(thumbMaxX, targetX))
        var elapsed: CFTimeInterval = 0
        var previousTimestamp: CFTimeInterval?
        let safeDuration = min(max(duration, 0.18), 0.4)

        thumbPositionAnimationLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] timestamp in
            guard let self else { return }

            let deltaTime: CFTimeInterval
            if let previousTimestamp {
                deltaTime = max(0, min(0.05, timestamp - previousTimestamp))
            } else {
                deltaTime = 1.0 / 60.0
            }
            previousTimestamp = timestamp
            elapsed += deltaTime

            let progress = min(max(elapsed / safeDuration, 0), 1)
            let easedProgress = 1 - pow(1 - CGFloat(progress), 3)
            let currentX = startX + (clampedTargetX - startX) * easedProgress

            self.setThumbXInternal(currentX, animated: false, allowsFeedback: false)
            self.updateTheseusFrame()

            let normalizedDirection = clampedTargetX >= startX ? 1.0 : -1.0
            let impulse = CGFloat(420.0 * (1.0 - progress)) * normalizedDirection
            self.theseusStretchAnimator?.applyDragVelocity(CGPoint(x: impulse, y: 0))

            if progress >= 1 {
                self.setThumbXInternal(clampedTargetX, animated: false, allowsFeedback: false)
                self.updateTheseusFrame()
                self.cancelThumbPositionAnimation()
                completion?()
            }
        }
    }


    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        guard !isPanning else { return }

        tapAnimationToken += 1
        let animationToken = tapAnimationToken
        cancelThumbPositionAnimation()
        showTheseus()

        let newValue = !_isOn
        visuallyOn = newValue
        updateTrackColor(animated: true)

        let targetX = newValue ? thumbOnX : thumbOffX
        let thumbY = (bounds.height - layout.thumbSize.height) / 2.0
        let finalThumbFrame = CGRect(x: targetX, y: thumbY, width: layout.thumbSize.width, height: layout.thumbSize.height)

        animateThumbForTap(to: targetX, duration: layout.transitionDuration + 0.08) { [weak self] in
            guard let self else { return }
            guard animationToken == self.tapAnimationToken else { return }
            self._isOn = newValue
            self.hideTheseus(toThumbFrame: finalThumbFrame, animated: true)
            self.hapticFeedback.impact(.light)
            self.onValueChanged?(newValue)
            self.sendActions(for: .valueChanged)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let currentTime = CACurrentMediaTime()

        switch gesture.state {
        case .began:
            tapAnimationToken += 1
            cancelThumbPositionAnimation()
            isPanning = true
            panStartThumbX = thumbLayer.frame.origin.x
            lastPanPosition = gesture.location(in: self)
            lastPanTime = currentTime
            showTheseus()

        case .changed:
            let newThumbX = panStartThumbX + translation.x
            setThumbX(newThumbX)
            updateTheseusFrame()

            let currentPosition = gesture.location(in: self)
            let dt = currentTime - lastPanTime
            if dt > (1.0 / 120.0) {
                currentVelocity = CGPoint(
                    x: (currentPosition.x - lastPanPosition.x) / dt,
                    y: (currentPosition.y - lastPanPosition.y) / dt
                )
                theseusStretchAnimator?.applyDragVelocity(currentVelocity)
            }
            lastPanPosition = currentPosition
            lastPanTime = currentTime

        case .ended, .cancelled:
            isPanning = false

            let currentThumbX = thumbLayer.frame.origin.x
            let shouldBeOn = currentThumbX > (thumbMinX + thumbMaxX) / 2.0

            if shouldBeOn != _isOn {
                _isOn = shouldBeOn
                hapticFeedback.impact(.light)
                onValueChanged?(shouldBeOn)
                sendActions(for: .valueChanged)
            }

            visuallyOn = _isOn
            updateTrackColor(animated: true)

            let targetX = _isOn ? thumbOnX : thumbOffX
            let thumbY = (bounds.height - layout.thumbSize.height) / 2.0
            let finalThumbFrame = CGRect(x: targetX, y: thumbY, width: layout.thumbSize.width, height: layout.thumbSize.height)

            setThumbX(targetX, animated: true)
            hideTheseus(toThumbFrame: finalThumbFrame, animated: true)

        default:
            break
        }
    }
}
