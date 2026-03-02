import UIKit
import QuartzCore

/// Configuration for a single tab bar item.
public struct TheseusTabBarItem {
    public var icon: UIImage?
    public var selectedIcon: UIImage?
    public var title: String?
    public var badge: String?

    public init(icon: UIImage? = nil, selectedIcon: UIImage? = nil, title: String? = nil, badge: String? = nil) {
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.title = title
        self.badge = badge
    }
}

/// A Liquid Glass-styled tab bar with animated selection indicator.
public class TheseusTabBar: UIView {

    public var items: [TheseusTabBarItem] = [] {
        didSet {
            rebuildItemViews()
            setNeedsLayout()
        }
    }

    public var selectedIndex: Int = 0 {
        didSet {
            if selectedIndex != oldValue {
                updateSelection(animated: true)
            }
        }
    }

    public var onItemSelected: ((Int) -> Void)?

    public var selectedTintColor: UIColor = .systemBlue {
        didSet { updateItemColors() }
    }

    public var unselectedTintColor: UIColor = .gray {
        didSet { updateItemColors() }
    }

    public var barHeight: CGFloat = 60 {
        didSet { invalidateIntrinsicContentSize() }
    }

    public var glassTint: UIColor = .clear {
        didSet {
            theseusView?.theme.tintColor = glassTint
        }
    }

    public var glassBlurRadius: CGFloat = 3.0 {
        didSet {
            theseusView?.blur.radius = glassBlurRadius
        }
    }

    public var glassRefractionFactor: CGFloat = 1.45 {
        didSet {
            theseusView?.refraction.intensity = glassRefractionFactor
        }
    }


    private var itemViews: [TabItemView] = []
    private var theseusView: TheseusView?
    private var theseusStretchAnimator: TheseusStretchAnimator?
    private let backgroundView = UIView()
    private let selectionView = UIImageView()

    private let glassScale: CGFloat = 1.35
    private var isDragging: Bool = false
    private var dragStartIndex: Int = 0

    private var lastDragPosition: CGPoint = .zero
    private var lastDragTime: CFTimeInterval = 0
    private var currentDragVelocity: CGPoint = .zero

    private var selectionAnimator: SelectionAnimator?

    private var itemsContainerView: UIView?
    private var selectedOverlayView: UIImageView?
    private var overlayMaskLayer: CAShapeLayer?
    private var invertedMaskLayer: CAShapeLayer?

    private var lensGlowLayer: CAGradientLayer?
    private var tapAnimationToken: Int = 0
    private var pendingTapTargetIndex: Int?


    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear

        addSubview(backgroundView)

        selectionView.contentMode = .scaleToFill
        addSubview(selectionView)

        updateAppearanceForCurrentMode()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }

    deinit {
        theseusStretchAnimator?.cancelAnimation()
    }


    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: barHeight)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = bounds
        backgroundView.layer.cornerRadius = bounds.height / 2
        backgroundView.clipsToBounds = true

        itemsContainerView?.frame = bounds

        guard !bounds.isEmpty, !items.isEmpty else { return }

        layoutItemViews()
        updateSelectionViewFrame(animated: false)

        if !isDragging {
            updateTheseusFrame(animated: false)
        }
    }

    private func layoutItemViews() {
        let itemCount = CGFloat(itemViews.count)
        guard itemCount > 0 else { return }

        let itemWidth = bounds.width / itemCount
        let itemHeight = bounds.height

        for (index, itemView) in itemViews.enumerated() {
            let x = CGFloat(index) * itemWidth
            itemView.frame = CGRect(x: x, y: 0, width: itemWidth, height: itemHeight)
        }
    }


    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateAppearanceForCurrentMode()
            }
        }
    }

    private func updateAppearanceForCurrentMode() {
        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }

        backgroundView.backgroundColor = isDark
            ? UIColor.black.withAlphaComponent(0.3)
            : UIColor.white.withAlphaComponent(0.6)

        if #available(iOS 13.0, *) {
            selectionView.tintColor = UIColor.label.withAlphaComponent(0.05)
        } else {
            selectionView.tintColor = UIColor.black.withAlphaComponent(0.05)
        }

        updateSelectionViewImage()

        setupLensGlowLayer()
    }

    private func setupLensGlowLayer() {
        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }

        if isDark {
            if lensGlowLayer == nil {
                let glow = CAGradientLayer()
                glow.type = .axial
                glow.colors = [
                    UIColor.clear.cgColor,
                    UIColor.white.withAlphaComponent(0.06).cgColor,  // Subtle glow
                    UIColor.clear.cgColor
                ]
                glow.locations = [0.0, 0.5, 1.0]  // Bright in center, fades to edges
                glow.startPoint = CGPoint(x: 0, y: 0.5)  // Left edge
                glow.endPoint = CGPoint(x: 1, y: 0.5)    // Right edge
                glow.isHidden = true
                backgroundView.layer.addSublayer(glow)
                lensGlowLayer = glow
            }
        } else {
            lensGlowLayer?.removeFromSuperlayer()
            lensGlowLayer = nil
        }
    }

    private func updateLensGlowPosition(centerX: CGFloat, lensWidth: CGFloat) {
        guard let glow = lensGlowLayer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let glowWidth = lensWidth * 4
        let height = bounds.height

        glow.frame = CGRect(
            x: centerX - glowWidth / 2,
            y: 0,
            width: glowWidth,
            height: height
        )

        CATransaction.commit()
    }


    private func updateSelectionViewImage() {
        let height: CGFloat = min(barHeight * 0.75, 46)
        selectionView.image = generatePillImage(height: height)
    }

    private func generatePillImage(height: CGFloat) -> UIImage? {
        let radius = height / 2
        let size = CGSize(width: height, height: height)

        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            UIColor.white.setFill()
            path.fill()
        }

        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius),
            resizingMode: .stretch
        ).withRenderingMode(.alwaysTemplate)
    }

    private func updateSelectionViewFrame(animated: Bool) {
        guard selectedIndex >= 0, selectedIndex < itemViews.count else { return }

        let itemFrame = itemViews[selectedIndex].frame
        let frame = selectionFrame(for: itemFrame)

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.75) {
                self.selectionView.frame = frame
            }
        } else {
            selectionView.frame = frame
        }
    }

    private func selectionFrame(for itemFrame: CGRect) -> CGRect {
        let height: CGFloat = min(itemFrame.height * 0.75, 46)
        let width: CGFloat = min(itemFrame.width * 0.82, 76)  // Pill shape (wider than tall)
        return CGRect(
            x: itemFrame.midX - width / 2,
            y: itemFrame.midY - height / 2,
            width: width,
            height: height
        )
    }


    private func rebuildItemViews() {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()

        if itemsContainerView == nil {
            let container = UIView()
            container.backgroundColor = .clear
            container.isUserInteractionEnabled = false
            addSubview(container)
            itemsContainerView = container
        }

        guard let container = itemsContainerView else { return }

        for (index, item) in items.enumerated() {
            let itemView = TabItemView()
            itemView.configure(with: item, isSelected: index == selectedIndex)
            itemView.tintColor = index == selectedIndex ? selectedTintColor : unselectedTintColor
            container.addSubview(itemView)
            itemViews.append(itemView)
        }

        if let glassView = theseusView {
            insertSubview(glassView, aboveSubview: selectionView)
        }
        bringSubviewToFront(container)
        sendSubviewToBack(selectionView)
        sendSubviewToBack(backgroundView)

        updateSelectionViewImage()
    }

    private func updateItemColors() {
        for (index, itemView) in itemViews.enumerated() {
            let isSelected = index == selectedIndex
            itemView.tintColor = isSelected ? selectedTintColor : unselectedTintColor
            itemView.updateSelection(isSelected: isSelected, animated: false)
        }
    }


    private func updateSelection(animated: Bool) {
        for (index, itemView) in itemViews.enumerated() {
            let isSelected = index == selectedIndex
            itemView.updateSelection(isSelected: isSelected, animated: animated)
            itemView.tintColor = isSelected ? selectedTintColor : unselectedTintColor
        }

        updateSelectionViewFrame(animated: animated)
        updateTheseusFrame(animated: animated)
    }

    private func updateTheseusFrame(animated: Bool) {
        guard selectedIndex >= 0, selectedIndex < itemViews.count else { return }

        let selectedItemView = itemViews[selectedIndex]
        let itemFrame = selectedItemView.frame
        let glassFrame = glassFrame(for: itemFrame)
        let convertedFrame = convertToTheseusContainer(glassFrame)

        guard let glassView = theseusView else { return }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.8) {
                glassView.frame = convertedFrame
                glassView.shape.cornerRadius = glassFrame.height / 2
            }
        } else {
            glassView.frame = convertedFrame
            glassView.shape.cornerRadius = glassFrame.height / 2
        }
    }

    private func glassFrame(for itemFrame: CGRect) -> CGRect {
        let baseHeight: CGFloat = min(itemFrame.height * 0.75, 46)
        let baseWidth: CGFloat = min(itemFrame.width * 0.82, 76)

        let scaledWidth = baseWidth * glassScale
        let scaledHeight = baseHeight * glassScale

        return CGRect(
            x: itemFrame.midX - scaledWidth / 2,
            y: itemFrame.midY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
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

    private func convertFromTheseusContainer(_ frame: CGRect) -> CGRect {
        guard let container = theseusContainer else { return frame }
        return container.convert(frame, to: self)
    }

    private func setupTheseus() {
        guard theseusView == nil else { return }
        guard let container = theseusContainer,
              let sourceView = theseusSourceView else { return }

        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }

        var config = TheseusConfiguration()
        config.capturePadding = CGPoint(x: 9, y: 9)
        config.shape.padding = CGPoint(x: 15, y: 15)
        config.captureMethod = TheseusCapability.isDeviceSupported ? .layerRendering : .surfaceBased

        if isDark {
            config.edgeEffects.rimGlow = 0.0
            config.edgeEffects.glareIntensity = 0.0
            config.edgeEffects.nearColor = .clear
            config.edgeEffects.farColor = .clear
        }

        let glassView = TheseusView(configuration: config)
        glassView.sourceView = sourceView
        glassView.isHidden = true  // Hidden by default, shown during drag
        glassView.alpha = 0

        container.addSubview(glassView)
        theseusView = glassView

        var stretchConfig = TheseusStretchConfiguration()
        stretchConfig.tension = 0.05
        stretchConfig.friction = 0.96
        stretchConfig.sizeFactor = 0.2
        stretchConfig.squishFactor = 0.5
        stretchConfig.stretchLimit = 0.1
        stretchConfig.smoothing = 0.92

        let stretchAnimator = TheseusStretchAnimator(configuration: stretchConfig)
        stretchAnimator.stretchDidChange = { [weak glassView] stretch in
            glassView?.setMorphScale(stretch)
        }
        theseusStretchAnimator = stretchAnimator
    }

    private func showTheseus() {
        setupTheseus()

        guard let glassView = theseusView,
              let container = theseusContainer else { return }

        if glassView.superview !== container {
            glassView.removeFromSuperview()
            container.addSubview(glassView)
        }

        if let sourceView = theseusSourceView, sourceView.bounds.width > 0 {
            glassView.sourceView = sourceView
        }
        glassView.continuousUpdate = true
        glassView.invalidateBackground()

        if selectedIndex >= 0, selectedIndex < itemViews.count {
            let itemFrame = itemViews[selectedIndex].frame
            let glassFrame = glassFrame(for: itemFrame)
            glassView.frame = convertToTheseusContainer(glassFrame)
            glassView.shape.cornerRadius = glassView.frame.height / 2
        }

        glassView.isHidden = false
        glassView.alpha = 0  // Reset alpha before animation

        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }
        if isDark, selectedIndex >= 0, selectedIndex < itemViews.count {
            let itemFrame = itemViews[selectedIndex].frame
            let lensFrame = glassFrame(for: itemFrame)
            updateLensGlowPosition(centerX: lensFrame.midX, lensWidth: lensFrame.width)
            lensGlowLayer?.isHidden = false
        }

        UIView.animate(withDuration: 0.2) {
            self.selectionView.alpha = 0
            glassView.alpha = 1
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            self.updateBackgroundForLiftedState(isLifted: true)
        }

        theseusStretchAnimator?.beginInteraction()
    }

    private func hideTheseus() {
        theseusStretchAnimator?.endInteraction()

        lensGlowLayer?.isHidden = true

        guard let glassView = theseusView else {
            selectionView.alpha = 1
            transform = .identity
            return
        }

        glassView.continuousUpdate = false

        UIView.animate(withDuration: 0.2) {
            self.selectionView.alpha = 1
            glassView.alpha = 0
            self.transform = .identity
            self.updateBackgroundForLiftedState(isLifted: false)
        } completion: { _ in
            glassView.isHidden = true
        }
    }

    private func updateBackgroundForLiftedState(isLifted: Bool) {
        let isDark: Bool
        if #available(iOS 13.0, *) {
            isDark = traitCollection.userInterfaceStyle == .dark
        } else {
            isDark = false
        }

        if isLifted {
            backgroundView.backgroundColor = isDark
                ? UIColor.black.withAlphaComponent(0.4)
                : UIColor.white.withAlphaComponent(0.75)
        } else {
            backgroundView.backgroundColor = isDark
                ? UIColor.black.withAlphaComponent(0.3)
                : UIColor.white.withAlphaComponent(0.6)
        }
    }


    private func createSelectedOverlayImage() -> UIImage? {
        guard !bounds.isEmpty, !itemViews.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))

            for itemView in itemViews {
                let itemFrame = itemView.frame
                let scale: CGFloat = 1.25

                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: itemFrame.midX, y: itemFrame.midY)
                ctx.cgContext.scaleBy(x: scale, y: scale)
                ctx.cgContext.translateBy(x: -itemFrame.width / 2.0, y: -itemFrame.height / 2.0)

                let originalTint = itemView.tintColor
                itemView.tintColor = selectedTintColor
                itemView.layer.render(in: ctx.cgContext)
                itemView.tintColor = originalTint

                ctx.cgContext.restoreGState()
            }
        }
        return image
    }

    private func setupIconTintingOverlay() {
        guard let overlayImage = createSelectedOverlayImage() else { return }

        let overlayView = UIImageView(image: overlayImage)
        overlayView.frame = bounds
        addSubview(overlayView)
        selectedOverlayView = overlayView

        let maskLayer = CAShapeLayer()
        if let glassView = theseusView {
            let maskFrame = convertFromTheseusContainer(glassView.frame)
            let cornerRadius = maskFrame.height * 0.5
            maskLayer.path = UIBezierPath(roundedRect: maskFrame, cornerRadius: cornerRadius).cgPath
        }
        overlayView.layer.mask = maskLayer
        overlayMaskLayer = maskLayer

        let invertedMask = CAShapeLayer()
        invertedMask.fillRule = .evenOdd
        if let glassView = theseusView {
            let maskFrame = convertFromTheseusContainer(glassView.frame)
            let cornerRadius = maskFrame.height * 0.5
            let invertedPath = UIBezierPath(rect: bounds)
            invertedPath.append(UIBezierPath(roundedRect: maskFrame, cornerRadius: cornerRadius))
            invertedMask.path = invertedPath.cgPath
        }
        itemsContainerView?.layer.mask = invertedMask
        invertedMaskLayer = invertedMask

        bringSubviewToFront(overlayView)
    }

    private func updateIconTintingMasks(for glassFrame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let cornerRadius = glassFrame.height * 0.5

        if let maskLayer = overlayMaskLayer {
            maskLayer.path = UIBezierPath(roundedRect: glassFrame, cornerRadius: cornerRadius).cgPath
        }

        if let invertedMask = invertedMaskLayer {
            let invertedPath = UIBezierPath(rect: bounds)
            invertedPath.append(UIBezierPath(roundedRect: glassFrame, cornerRadius: cornerRadius))
            invertedMask.path = invertedPath.cgPath
        }

        CATransaction.commit()
    }

    private func cleanupIconTintingOverlay() {
        if let overlay = selectedOverlayView {
            UIView.animate(withDuration: 0.15, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        }
        selectedOverlayView = nil
        overlayMaskLayer = nil

        itemsContainerView?.layer.mask = nil
        invertedMaskLayer = nil
    }

    private func makeSelectionAnimatorIfNeeded() {
        guard selectionAnimator == nil else { return }
        selectionAnimator = SelectionAnimator()
        selectionAnimator?.onFrameChanged = { [weak self] frame in
            self?.theseusView?.frame = frame
            if let localFrame = self?.convertFromTheseusContainer(frame) {
                self?.theseusView?.shape.cornerRadius = localFrame.height / 2
                self?.updateIconTintingMasks(for: localFrame)
            }
        }
    }

    private func adaptiveTapDuration(from currentFrame: CGRect, to targetFrame: CGRect) -> CFTimeInterval {
        let horizontalDistance = abs(targetFrame.midX - currentFrame.midX)
        let itemWidth = max(bounds.width / CGFloat(max(itemViews.count, 1)), 1)
        let hopCount = min(horizontalDistance / itemWidth, CGFloat(max(itemViews.count - 1, 1)))

        let baseDuration: CGFloat = 0.24
        let perHopDuration: CGFloat = 0.06
        let duration = baseDuration + (hopCount * perHopDuration)

        return CFTimeInterval(min(max(duration, 0.22), 0.5))
    }


    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)

        for (index, itemView) in itemViews.enumerated() {
            if itemView.frame.contains(location) {
                if index != selectedIndex || pendingTapTargetIndex != nil {
                    guard pendingTapTargetIndex != index else { break }

                    showTheseus()
                    setupIconTintingOverlay()
                    makeSelectionAnimatorIfNeeded()

                    if let glassView = theseusView {
                        selectionAnimator?.setCurrentFrame(glassView.frame)
                    }

                    let targetFrame = glassFrame(for: itemViews[index].frame)
                    let targetContainerFrame = convertToTheseusContainer(targetFrame)

                    tapAnimationToken += 1
                    let currentToken = tapAnimationToken
                    pendingTapTargetIndex = index

                    let currentGlassFrame = theseusView?.frame ?? targetContainerFrame
                    let duration = adaptiveTapDuration(from: currentGlassFrame, to: targetContainerFrame)

                    selectionAnimator?.animateTo(
                        targetContainerFrame,
                        duration: duration
                    ) { [weak self] in
                        guard let self else { return }
                        guard currentToken == self.tapAnimationToken else { return }

                        self.selectedIndex = index
                        self.onItemSelected?(index)
                        self.hideTheseus()
                        self.cleanupIconTintingOverlay()
                        self.pendingTapTargetIndex = nil
                    }
                    updateLensGlowPosition(centerX: targetFrame.midX, lensWidth: targetFrame.width)

                    let currentVisualMidX = convertFromTheseusContainer(currentGlassFrame).midX
                    let velocityX = (itemViews[index].frame.midX - currentVisualMidX) * 8
                    theseusStretchAnimator?.applyDragVelocity(CGPoint(x: velocityX, y: 0))
                }
                break
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            tapAnimationToken += 1
            pendingTapTargetIndex = nil

            isDragging = true
            dragStartIndex = selectedIndex
            lastDragPosition = location
            lastDragTime = CACurrentMediaTime()
            currentDragVelocity = .zero

            showTheseus()
            setupIconTintingOverlay()

            makeSelectionAnimatorIfNeeded()
            selectionAnimator?.cancelCurrentAnimation()
            if let glassView = theseusView {
                selectionAnimator?.setCurrentFrame(glassView.frame)
            }

        case .changed:
            let currentTime = CACurrentMediaTime()
            let dt = currentTime - lastDragTime
            if dt > (1.0 / 120.0) {
                currentDragVelocity = CGPoint(
                    x: (location.x - lastDragPosition.x) / dt,
                    y: (location.y - lastDragPosition.y) / dt
                )
            }
            lastDragPosition = location
            lastDragTime = currentTime

            theseusStretchAnimator?.applyDragVelocity(currentDragVelocity)

            if let targetFrame = calculateInterpolatedFrame(for: location) {
                let containerFrame = convertToTheseusContainer(targetFrame)
                selectionAnimator?.animateTo(containerFrame)

                updateLensGlowPosition(centerX: targetFrame.midX, lensWidth: targetFrame.width)
            }

        case .ended, .cancelled:
            isDragging = false

            let closestIndex = findClosestItemIndex(to: location)
            if closestIndex != selectedIndex {
                selectedIndex = closestIndex
                onItemSelected?(closestIndex)
            }

            updateSelectionViewFrame(animated: true)

            hideTheseus()
            cleanupIconTintingOverlay()

        default:
            break
        }
    }

    private func findClosestItemIndex(to point: CGPoint) -> Int {
        var closestIndex = 0
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for (index, itemView) in itemViews.enumerated() {
            let distance = abs(point.x - itemView.frame.midX)
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }

        return closestIndex
    }

    private func calculateInterpolatedFrame(for point: CGPoint) -> CGRect? {
        guard itemViews.count >= 2 else {
            return itemViews.first.map { glassFrame(for: $0.frame) }
        }

        let sortedViews = itemViews.sorted { $0.frame.midX < $1.frame.midX }
        let minX = sortedViews.first!.frame.midX
        let maxX = sortedViews.last!.frame.midX
        let clampedX = max(minX, min(maxX, point.x))

        for i in 0..<sortedViews.count - 1 {
            let left = sortedViews[i].frame
            let right = sortedViews[i + 1].frame

            if clampedX >= left.midX && clampedX <= right.midX {
                let t = (clampedX - left.midX) / (right.midX - left.midX)
                let interpolatedCenterX = left.midX + (right.midX - left.midX) * t

                let baseFrame = glassFrame(for: left)
                return CGRect(
                    x: interpolatedCenterX - baseFrame.width / 2,
                    y: baseFrame.origin.y,
                    width: baseFrame.width,
                    height: baseFrame.height
                )
            }
        }

        let closestIndex = findClosestItemIndex(to: point)
        return glassFrame(for: itemViews[closestIndex].frame)
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        theseusView?.sourceView = theseusSourceView
    }
}


private class TabItemView: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let stackView = UIStackView()

    private var item: TheseusTabBarItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(with item: TheseusTabBarItem, isSelected: Bool) {
        self.item = item
        iconImageView.image = (isSelected ? item.selectedIcon : item.icon) ?? item.icon
        iconImageView.image = iconImageView.image?.withRenderingMode(.alwaysTemplate)
        titleLabel.text = item.title
        titleLabel.isHidden = item.title == nil
    }

    func updateSelection(isSelected: Bool, animated: Bool) {
        guard let item = item else { return }
        let newIcon = (isSelected ? item.selectedIcon : item.icon) ?? item.icon
        iconImageView.image = newIcon?.withRenderingMode(.alwaysTemplate)

        if animated {
            UIView.animate(withDuration: 0.2) {
                self.iconImageView.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            }
        } else {
            iconImageView.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    override var tintColor: UIColor! {
        didSet {
            iconImageView.tintColor = tintColor
            titleLabel.textColor = tintColor
        }
    }
}


private class SelectionAnimator {
    enum Mode {
        case interactive
        case timed
    }

    var onFrameChanged: ((CGRect) -> Void)?

    private var displayLink: DisplayLinkDriver.Link?
    private var currentFrame: CGRect = .zero
    private var targetFrame: CGRect = .zero
    private var startFrame: CGRect = .zero
    private var mode: Mode = .interactive
    private var animationDuration: CFTimeInterval = 0.25
    private var animationElapsed: CFTimeInterval = 0
    private var completion: (() -> Void)?
    private var previousTimestamp: CFTimeInterval?

    private let smoothingFactor: CGFloat = 0.22

    func animateTo(_ frame: CGRect) {
        cancelCompletion()
        mode = .interactive
        targetFrame = frame
        startDisplayLinkIfNeeded()
    }

    func animateTo(_ frame: CGRect, duration: CFTimeInterval, completion: (() -> Void)?) {
        mode = .timed
        startFrame = currentFrame
        targetFrame = frame
        animationDuration = min(max(duration, 0.15), 0.7)
        animationElapsed = 0
        previousTimestamp = nil
        self.completion = completion
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        if displayLink == nil {
            displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] timestamp in
                self?.update(timestamp: timestamp)
            }
        }
        displayLink?.isPaused = false
    }

    private func update(timestamp: CFTimeInterval) {
        switch mode {
        case .interactive:
            updateInteractive()
        case .timed:
            updateTimed(timestamp: timestamp)
        }
    }

    private func updateInteractive() {
        currentFrame.origin.x += (targetFrame.origin.x - currentFrame.origin.x) * smoothingFactor
        currentFrame.origin.y = targetFrame.origin.y
        currentFrame.size = targetFrame.size

        onFrameChanged?(currentFrame)

        if abs(targetFrame.origin.x - currentFrame.origin.x) < 0.5 {
            currentFrame = targetFrame
            onFrameChanged?(currentFrame)
            stopDisplayLink()
        }
    }

    private func updateTimed(timestamp: CFTimeInterval) {
        let deltaTime: CFTimeInterval
        if let previousTimestamp {
            deltaTime = max(0, min(0.05, timestamp - previousTimestamp))
        } else {
            deltaTime = 1.0 / 60.0
        }
        previousTimestamp = timestamp

        animationElapsed += deltaTime
        let progress = min(max(animationElapsed / animationDuration, 0), 1)
        let easedProgress = easeOutCubic(progress)
        currentFrame = interpolate(from: startFrame, to: targetFrame, progress: easedProgress)
        onFrameChanged?(currentFrame)

        if progress >= 1 {
            currentFrame = targetFrame
            onFrameChanged?(currentFrame)
            stopDisplayLink()
            let completed = completion
            cancelCompletion()
            completed?()
        }
    }

    private func interpolate(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: from.origin.x + (to.origin.x - from.origin.x) * progress,
            y: from.origin.y + (to.origin.y - from.origin.y) * progress,
            width: from.width + (to.width - from.width) * progress,
            height: from.height + (to.height - from.height) * progress
        )
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        1 - pow(1 - value, 3)
    }

    private func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = nil
    }

    private func cancelCompletion() {
        completion = nil
    }

    func cancelCurrentAnimation() {
        mode = .interactive
        stopDisplayLink()
        cancelCompletion()
    }

    func setCurrentFrame(_ frame: CGRect) {
        currentFrame = frame
        startFrame = frame
        targetFrame = frame
        previousTimestamp = nil
    }
}
