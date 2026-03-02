import Foundation
import UIKit

/// Global settings singleton for overriding device tier, quality, and accessibility behavior.
public final class TheseusSettings {

    public static let shared = TheseusSettings()

    public static let settingsDidChangeNotification = Notification.Name("TheseusSettingsDidChange")

    public var tierOverride: DeviceTier? {
        didSet { postChange() }
    }

    public var effectiveTier: DeviceTier {
        tierOverride ?? TheseusCapability.deviceTier
    }

    public var iosVersionOverride: Int? {
        didSet { postChange() }
    }

    public var effectiveIOSVersion: Int {
        iosVersionOverride ?? TheseusCapability.iosMajorVersion
    }

    public var refractionPolicyOverride: RefractionPolicy? {
        didSet { postChange() }
    }

    public var effectiveRefractionPolicy: RefractionPolicy {
        if let override = refractionPolicyOverride {
            return override
        }
        return computeRefractionPolicy()
    }

    public var refractionQualityOverride: RefractionQuality? {
        didSet { postChange() }
    }

    public var effectiveRefractionQuality: RefractionQuality {
        if let override = refractionQualityOverride {
            return override
        }
        return computeRefractionQuality()
    }

    public var respectsReduceMotion: Bool = true {
        didSet { postChange() }
    }

    public var respectsReduceTransparency: Bool = true {
        didSet { postChange() }
    }

    public var areMorphAnimationsEnabled: Bool {
        if respectsReduceMotion && isReduceMotionActive {
            return false
        }
        return true
    }

    public var areBlurEffectsEnabled: Bool {
        if respectsReduceTransparency && isReduceTransparencyActive {
            return false
        }
        return true
    }

    public var forceFallback: Bool = false {
        didSet { postChange() }
    }

    public var shouldUseFallback: Bool {
        if forceFallback { return true }
        if !TheseusCapability.isMetalAvailable { return true }
        if effectiveTier == .tier0 { return true }
        if effectiveRefractionPolicy == .off { return true }
        if !areBlurEffectsEnabled { return true }
        return false
    }

    public var simulateLowPowerMode: Bool? {
        didSet { postChange() }
    }

    public var simulateReduceTransparency: Bool? {
        didSet { postChange() }
    }

    public var simulateReduceMotion: Bool? {
        didSet { postChange() }
    }

    public var isLowPowerModeActive: Bool {
        simulateLowPowerMode ?? TheseusEnvironment.shared.isLowPowerModeEnabled
    }

    public var isReduceTransparencyActive: Bool {
        simulateReduceTransparency ?? TheseusEnvironment.shared.reduceTransparencyEnabled
    }

    public var isReduceMotionActive: Bool {
        simulateReduceMotion ?? TheseusEnvironment.shared.reduceMotionEnabled
    }

    public var isConstrained: Bool {
        isLowPowerModeActive || TheseusEnvironment.shared.thermalState == .serious ||
            TheseusEnvironment.shared.thermalState == .critical
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentDidChange),
            name: TheseusEnvironment.stateDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func environmentDidChange() {
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(
            name: Self.settingsDidChangeNotification,
            object: self
        )
    }

    public func resetToDefaults() {
        tierOverride = nil
        iosVersionOverride = nil
        refractionPolicyOverride = nil
        refractionQualityOverride = nil
        forceFallback = false
        respectsReduceMotion = true
        respectsReduceTransparency = true
        simulateLowPowerMode = nil
        simulateReduceTransparency = nil
        simulateReduceMotion = nil
    }

    private func computeRefractionPolicy() -> RefractionPolicy {
        if isReduceTransparencyActive {
            return .off
        }

        if isConstrained {
            return .cheapApprox
        }

        let tier = effectiveTier
        let ios = effectiveIOSVersion

        switch tier {
        case .tier0:
            return .cheapApprox
        case .tier1:
            return ios >= 17 ? .trueRefraction : .cheapApprox
        case .tier2:
            return ios >= 15 ? .trueRefraction : .cheapApprox
        case .tier3:
            return .trueRefraction
        }
    }

    private func computeRefractionQuality() -> RefractionQuality {
        if isConstrained {
            return .low
        }

        let tier = effectiveTier
        let ios = effectiveIOSVersion

        switch tier {
        case .tier0:
            return .low
        case .tier1:
            return .low
        case .tier2:
            return .medium
        case .tier3:
            return ios >= 17 ? .high : .medium
        }
    }

    public func effectivePolicy(for component: TheseusCapability.ComponentType) -> RefractionPolicy {
        let basePolicy = effectiveRefractionPolicy

        guard basePolicy != .off else { return .off }

        let tier = effectiveTier

        switch (tier, component) {
        case (.tier0, _):
            return .cheapApprox
        case (.tier1, .tabBar):
            return basePolicy
        case (.tier1, _):
            return .cheapApprox
        case (.tier2, .tabBar), (.tier2, .switch):
            return basePolicy
        case (.tier2, _):
            return .cheapApprox
        case (.tier3, _):
            return basePolicy
        }
    }
}
