import Foundation
import UIKit

/// Spring physics parameters for the stretch animator.
public struct TheseusStretchConfiguration {
    public var sizeFactor: CGFloat = 0.35
    public var tension: CGFloat = 0.18
    public var friction: CGFloat = 0.88
    public var squishFactor: CGFloat = 0.55
    public var smoothing: CGFloat = 0.45
    public var stretchLimit: CGFloat = 0.45

    public init() {}
}

/// Animates stretch/squish deformations based on drag velocity using spring physics.
public final class TheseusStretchAnimator {

    public var configuration = TheseusStretchConfiguration()

    public var stretchDidChange: ((CGPoint) -> Void)?

    public private(set) var currentStretch: CGPoint = CGPoint(x: 1.0, y: 1.0)

    public private(set) var isActive: Bool = false

    private var targetStretch: CGPoint = CGPoint(x: 1.0, y: 1.0)
    private var smoothedTarget: CGPoint = CGPoint(x: 1.0, y: 1.0)
    private var internalVelocity: CGPoint = .zero
    private var displayLink: DisplayLinkDriver.Link?
    private var interactionActive: Bool = false

    public init(configuration: TheseusStretchConfiguration = .init()) {
        self.configuration = configuration
    }

    deinit {
        cancelAnimation()
    }

    public func beginInteraction() {
        guard TheseusSettings.shared.areMorphAnimationsEnabled else {
            return
        }

        interactionActive = true

        smoothedTarget = currentStretch
        internalVelocity = .zero

        guard displayLink == nil else { return }

        displayLink = DisplayLinkDriver.shared.add(framesPerSecond: .fps(60)) { [weak self] _ in
            self?.tick()
        }
        displayLink?.isPaused = false
        isActive = true

        stretchDidChange?(currentStretch)
    }

    public func endInteraction() {
        interactionActive = false
        targetStretch = CGPoint(x: 1.0, y: 1.0)
    }

    public func cancelAnimation() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        isActive = false
        resetToNeutral()
    }

    public func applyDragVelocity(_ velocity: CGPoint) {
        computeStretchFromVelocity(velocity)
    }

    public func resetToNeutral() {
        targetStretch = CGPoint(x: 1.0, y: 1.0)
        currentStretch = CGPoint(x: 1.0, y: 1.0)
        smoothedTarget = CGPoint(x: 1.0, y: 1.0)
        internalVelocity = .zero
        stretchDidChange?(currentStretch)
    }

    private let stretchPerVelocityUnit: CGFloat = 0.001

    private func computeStretchFromVelocity(_ velocity: CGPoint) {
        let maxVelocity: CGFloat = 4500

        let clampedX = velocity.x.clamped(to: -maxVelocity...maxVelocity)
        let clampedY = velocity.y.clamped(to: -maxVelocity...maxVelocity)

        let factor = configuration.sizeFactor
        let squish = configuration.squishFactor
        let limit = configuration.stretchLimit
        let minStretch = 1.0 - limit
        let maxStretch = 1.0 + limit

        let offsetX = clampedX * stretchPerVelocityUnit * factor
        let offsetY = clampedY * stretchPerVelocityUnit * factor

        let perpendicularContributionX = offsetY * squish
        let perpendicularContributionY = offsetX * squish

        let stretchX = (1.0 + offsetX - perpendicularContributionX).clamped(to: minStretch...maxStretch)
        let stretchY = (1.0 + offsetY - perpendicularContributionY).clamped(to: minStretch...maxStretch)

        targetStretch = CGPoint(x: stretchX, y: stretchY)
    }

    private func tick() {
        let stiffness = configuration.tension
        let damping = configuration.friction

        let displacementX = targetStretch.x - currentStretch.x
        let springForceX = displacementX * stiffness
        internalVelocity.x += springForceX
        internalVelocity.x *= damping
        currentStretch.x += internalVelocity.x

        let displacementY = targetStretch.y - currentStretch.y
        let springForceY = displacementY * stiffness
        internalVelocity.y += springForceY
        internalVelocity.y *= damping
        currentStretch.y += internalVelocity.y

        smoothedTarget = targetStretch

        stretchDidChange?(currentStretch)

        if !interactionActive && hasSettled() {
            completeAnimation()
        }
    }

    private func hasSettled() -> Bool {
        let settlementThreshold: CGFloat = 1.0 / 500.0
        let neutral: CGFloat = 1.0

        let targetAtNeutral = targetStretch.x == neutral && targetStretch.y == neutral
        let stretchNearNeutral = abs(currentStretch.x - neutral) < settlementThreshold &&
                                  abs(currentStretch.y - neutral) < settlementThreshold
        let velocityNearZero = abs(internalVelocity.x) < settlementThreshold &&
                               abs(internalVelocity.y) < settlementThreshold

        return targetAtNeutral && stretchNearNeutral && velocityNearZero
    }

    private func completeAnimation() {
        currentStretch = CGPoint(x: 1.0, y: 1.0)
        smoothedTarget = CGPoint(x: 1.0, y: 1.0)
        internalVelocity = .zero
        stretchDidChange?(currentStretch)

        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        isActive = false
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
