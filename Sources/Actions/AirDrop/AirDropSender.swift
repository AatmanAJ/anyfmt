import AppKit
import AnyfmtCore

/// Sends files with AirDrop from a menu-bar agent.
///
/// An LSUIElement app has no window for the AirDrop picker to attach to, so
/// we make a tiny, clear anchor window at the drop point, activate the app,
/// and hand the anchor to the service from the delegate. Afterwards the anchor
/// closes and, if we took focus from another app (usually Finder) and nothing
/// else has taken it since, focus goes back there.
/// (research/PLATFORM_RESEARCH.md §H: multi-file and folders are supported.)
@MainActor
final class AirDropSender: NSObject, NSSharingServiceDelegate {
    static let shared = AirDropSender()

    private var anchor: NSWindow?
    private var continuation: CheckedContinuation<ActionOutcome, Never>?
    private var previousApp: NSRunningApplication?
    private var anchorPoint: CGPoint = .zero

    /// True when AirDrop exists on this Mac and accepts these items.
    func canSend(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        return service.canPerform(withItems: urls)
    }

    func send(_ urls: [URL], near point: CGPoint) async -> ActionOutcome {
        guard continuation == nil else {
            return .failed(String(localized: "AirDrop is already open."))
        }
        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            return .failed(String(localized: "AirDrop isn’t available on this Mac."))
        }
        guard service.canPerform(withItems: urls) else {
            return .failed(String(localized: "These items can’t be sent with AirDrop."))
        }
        service.delegate = self
        anchorPoint = point
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front

        let anchor = makeAnchor(at: point)
        self.anchor = anchor
        Self.activateApp()
        anchor.makeKeyAndOrderFront(nil)

        return await withCheckedContinuation { c in
            continuation = c
            service.perform(withItems: urls)
        }
    }

    // MARK: NSSharingServiceDelegate

    func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any],
                        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        anchor
    }

    func sharingService(_ sharingService: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect {
        NSRect(x: anchorPoint.x - 1, y: anchorPoint.y - 1, width: 2, height: 2)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(.done(nil))
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError {
            finish(.cancelled)
        } else {
            Log.actions.error("AirDrop failed: \(ns.domain, privacy: .public) \(ns.code)")
            finish(.failed(String(localized: "AirDrop couldn’t send the items.")))
        }
    }

    // MARK: Private

    private func finish(_ outcome: ActionOutcome) {
        anchor?.orderOut(nil)
        anchor = nil
        if let previous = previousApp, !previous.isTerminated,
           NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            Self.activate(previous)
        }
        previousApp = nil
        let c = continuation
        continuation = nil
        c?.resume(returning: outcome)
    }

    /// A clear 2×2 window just below the point. It's fully opaque as a window
    /// (alpha 1) with clear content, because a zero-alpha source window makes
    /// the picker inherit the transparency on recent macOS.
    private func makeAnchor(at point: CGPoint) -> NSWindow {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var p = point
        if let vf = screen?.visibleFrame {
            // Leave room below for the picker.
            p.x = min(max(p.x, vf.minX + 200), vf.maxX - 200)
            p.y = min(max(p.y, vf.minY + 420), vf.maxY - 8)
        }
        let window = AnchorWindow(contentRect: NSRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        return window
    }

    static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    static func activate(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate(from: NSRunningApplication.current, options: [])
        } else {
            app.activate(options: [])
        }
    }
}

/// Borderless windows can't become key by default; the picker needs a key source window.
private final class AnchorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
