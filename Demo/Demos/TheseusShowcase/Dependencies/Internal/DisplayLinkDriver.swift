import UIKit
import QuartzCore

/// A shared display link driver that allows multiple clients to subscribe to frame callbacks
/// without creating multiple CADisplayLink instances.
public final class DisplayLinkDriver {

    /// Singleton instance
    public static let shared = DisplayLinkDriver()

    /// Frame rate options
    public enum FramesPerSecond {
        case fps(Int)
        case max

        /// Get preferred frames per second value
        var preferredFPS: Int {
            switch self {
            case .fps(let fps):
                return fps
            case .max:
                return 60
            }
        }
    }

    /// A link representing a subscription to display link updates
    public final class Link {
        fileprivate let id: UUID
        fileprivate weak var driver: DisplayLinkDriver?
        fileprivate let callback: (CFTimeInterval) -> Void

        /// Whether the link is paused
        public var isPaused: Bool {
            get { _isPaused }
            set {
                _isPaused = newValue
                driver?.updateDisplayLinkState()
            }
        }
        private var _isPaused: Bool = false

        /// Preferred frames per second (updates the shared display link)
        /// Note: This affects all links using the shared display link
        public var preferredFramesPerSecond: Int {
            get { _preferredFramesPerSecond }
            set {
                _preferredFramesPerSecond = newValue
                driver?.updateFrameRate(newValue)
            }
        }
        private var _preferredFramesPerSecond: Int = 60

        fileprivate init(id: UUID, driver: DisplayLinkDriver, callback: @escaping (CFTimeInterval) -> Void) {
            self.id = id
            self.driver = driver
            self.callback = callback
        }

        deinit {
            invalidate()
        }

        /// Invalidate this link and remove it from the driver
        public func invalidate() {
            driver?.removeLink(self)
        }
    }

    private var displayLink: CADisplayLink?
    private var links: [UUID: Link] = [:]
    private let lock = NSLock()

    private init() {}

    /// Add a callback to be invoked on each frame
    /// - Parameters:
    ///   - framesPerSecond: Target frame rate
    ///   - callback: Callback invoked with timestamp on each frame
    /// - Returns: A Link object that can be used to pause/invalidate the subscription
    public func add(
        framesPerSecond: FramesPerSecond = .max,
        _ callback: @escaping (CFTimeInterval) -> Void
    ) -> Link {
        lock.lock()
        defer { lock.unlock() }

        let id = UUID()
        let link = Link(id: id, driver: self, callback: callback)
        links[id] = link

        ensureDisplayLinkExists(framesPerSecond: framesPerSecond)
        updateDisplayLinkState()

        return link
    }

    private func removeLink(_ link: Link) {
        lock.lock()
        defer { lock.unlock() }

        links.removeValue(forKey: link.id)
        updateDisplayLinkState()
    }

    private func ensureDisplayLinkExists(framesPerSecond: FramesPerSecond = .max) {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))

        // Set preferred frame rate based on iOS version
        if #available(iOS 15.0, *) {
            let fps = Float(framesPerSecond.preferredFPS)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
        } else {
            // For iOS 13-14, use preferredFramesPerSecond (deprecated but necessary)
            link.preferredFramesPerSecond = framesPerSecond.preferredFPS
        }

        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func updateDisplayLinkState() {
        let hasActiveLinks = links.values.contains { !$0.isPaused }
        displayLink?.isPaused = !hasActiveLinks

        if links.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    fileprivate func updateFrameRate(_ fps: Int) {
        guard let link = displayLink else { return }

        if #available(iOS 15.0, *) {
            let fpsFloat = Float(fps)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: fpsFloat, maximum: fpsFloat, preferred: fpsFloat)
        } else {
            link.preferredFramesPerSecond = fps
        }
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        // Lock to safely copy links array, then unlock before iterating.
        // This prevents deadlock if a callback modifies the links dictionary.
        lock.lock()
        let activeLinks = links.values.filter { !$0.isPaused }
        lock.unlock()

        let timestamp = displayLink.timestamp
        for link in activeLinks {
            link.callback(timestamp)
        }
    }
}
