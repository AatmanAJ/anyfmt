import AppKit
import SwiftUI
import HaloCore

/// AppKit glue for the cloud sheets. The app is a menu-bar agent with no
/// main window, so each sheet is a small titled panel brought to the front.
@MainActor
enum CloudPanels {
    private static var open: [ObjectIdentifier: NSPanel] = [:]
    private static var closers: [ObjectIdentifier: CloudPanelCloser] = [:]

    /// Shows `content` in a floating panel. `onClose` runs when the user closes it with the title-bar button.
    @discardableResult
    static func present<Content: View>(_ content: Content, title: String, onClose: (() -> Void)? = nil) -> NSPanel {
        let host = NSHostingController(rootView: content)
        let panel = NSPanel(contentViewController: host)
        panel.styleMask = [.titled, .closable, .fullSizeContentView]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.title = title
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .alertPanel
        let closer = CloudPanelCloser(onClose: onClose)
        panel.delegate = closer
        let id = ObjectIdentifier(panel)
        open[id] = panel
        closers[id] = closer
        closer.cleanup = { open[id] = nil; closers[id] = nil }
        panel.center()
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        panel.makeKeyAndOrderFront(nil)
        return panel
    }

    static func dismiss(_ panel: NSPanel) {
        (panel.delegate as? CloudPanelCloser)?.onClose = nil
        panel.close()
    }

    /// Tapping a Pro segment that isn't available: the calm explainer.
    static func showProExplainer(for feature: CloudFeature, services: CloudServices = .shared) {
        let session = services.session
        let reason: ProExplainerView.Reason = session.isSignedIn ? .notInPlan : .signedOut
        var panelRef: NSPanel?
        let view = ProExplainerView(feature: feature, serverName: session.serverDisplayName, reason: reason,
            onPrimary: {
                if let panelRef { dismiss(panelRef) }
                if reason == .signedOut {
                    session.signIn()
                } else {
                    // Keeps a self-host's path prefix (https://example.com/halo/account/plan).
                    NSWorkspace.shared.open(session.serverURL.appendingPathComponent("account/plan"))
                }
            },
            onNotNow: { if let panelRef { dismiss(panelRef) } })
        panelRef = present(view, title: CloudCopy.title(for: feature))
    }

    /// Asks for share-link options; nil if the user cancels.
    static func askShareLinkOptions(fileCount: Int, services: CloudServices = .shared) async -> ShareLinkOptions? {
        let session = services.session
        return await withCheckedContinuation { (c: CheckedContinuation<ShareLinkOptions?, Never>) in
            let once = CloudOnce(c)
            var panelRef: NSPanel?
            let view = ShareLinkOptionsView(
                entitlements: session.entitlements, fileCount: fileCount, serverName: session.serverDisplayName,
                onCreate: { o in if let p = panelRef { dismiss(p) }; once.resume(o) },
                onCancel: { if let p = panelRef { dismiss(p) }; once.resume(nil) })
            panelRef = present(view, title: String(localized: "Share link"), onClose: { once.resume(nil) })
        }
    }

    /// The whole Control-wheel "Share link" action: explainer if needed,
    /// options, upload, link copied. Returns the outcome for the caller's toast.
    static func runShareLink(files: [URL], services: CloudServices = .shared,
                             progress: (@Sendable (Double) -> Void)? = nil) async throws -> ShareLinkOutcome? {
        let entitlements = services.entitlements
        guard entitlements.can(.shareLink) else {
            showProExplainer(for: .shareLink, services: services)
            return nil
        }
        guard let options = await askShareLinkOptions(fileCount: files.count, services: services) else { return nil }
        return try await services.shareLinks.share(files: files, options: options, progress: progress)
    }
}

/// The live `CloudUploadConsent`: `UploadNoticeView` in a panel.
struct CloudPanelConsent: CloudUploadConsent {
    @MainActor func confirmUpload(to serverName: String, fileCount: Int) async -> Bool {
        await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            let once = CloudOnce(c)
            var panelRef: NSPanel?
            let view = UploadNoticeView(serverName: serverName, fileCount: fileCount,
                onContinue: { if let p = panelRef { CloudPanels.dismiss(p) }; once.resume(true) },
                onCancel: { if let p = panelRef { CloudPanels.dismiss(p) }; once.resume(false) })
            panelRef = CloudPanels.present(view, title: String(localized: "Upload"), onClose: { once.resume(false) })
        }
    }
}

/// Resumes a continuation exactly once, whichever button (or the close box) wins.
@MainActor
final class CloudOnce<T: Sendable> {
    private var continuation: CheckedContinuation<T, Never>?
    init(_ c: CheckedContinuation<T, Never>) { continuation = c }
    func resume(_ value: T) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

@MainActor
final class CloudPanelCloser: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    var cleanup: (() -> Void)?
    init(onClose: (() -> Void)?) { self.onClose = onClose }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
        cleanup?()
        cleanup = nil
    }
}
