import AppKit

/// Watches modifier and key presses inside this app's own windows with a
/// *local* NSEvent monitor. Local monitors only see events already addressed
/// to us, so they need no permission (unlike global key monitors or taps).
@MainActor
final class LocalKeyMonitor {
    typealias FlagsHandler = @MainActor (_ keys: Set<TriggerKey>, _ timestamp: TimeInterval, _ event: NSEvent) -> Void
    /// Return true to swallow the key event.
    typealias KeyHandler = @MainActor (_ event: NSEvent) -> Bool

    private var token: Any?
    private let onFlags: FlagsHandler?
    private let onKeyDown: KeyHandler?
    /// Only events for this window are reported (nil = any of our windows).
    weak var window: NSWindow?

    init(window: NSWindow? = nil, onFlags: FlagsHandler? = nil, onKeyDown: KeyHandler? = nil) {
        self.window = window
        self.onFlags = onFlags
        self.onKeyDown = onKeyDown
    }

    var isRunning: Bool { token != nil }

    func start() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            // Local monitors run on the main thread.
            let swallow = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return swallow ? nil : event
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    /// True to swallow the event.
    private func handle(_ event: NSEvent) -> Bool {
        if let window, event.window !== window { return false }
        switch event.type {
        case .flagsChanged:
            onFlags?(TriggerKey.keys(in: event.modifierFlags), event.timestamp, event)
            return false
        case .keyDown:
            return onKeyDown?(event) ?? false
        default:
            return false
        }
    }
}
