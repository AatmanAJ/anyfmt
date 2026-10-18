import AppKit
import SwiftUI
import HaloCore

/// A brief confirmation near the drop point ("Copied 3 items", "Path copied").
/// Non-activating, click-through, fades out on its own.
@MainActor
enum ToastHUD {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ message: String, systemImage: String = "checkmark.circle.fill", isError: Bool = false,
                     near point: CGPoint = NSEvent.mouseLocation) {
        hideTask?.cancel()
        panel?.orderOut(nil)
        let view = NSHostingView(rootView: ToastView(message: message, systemImage: isError ? "exclamationmark.triangle.fill" : systemImage, isError: isError))
        view.layoutSubtreeIfNeeded()
        let size = view.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = view
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height - 28)
        if let vf = screen?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        p.setFrameOrigin(origin)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; p.animator().alphaValue = 1 }
        NSAccessibility.post(element: view, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        panel = p
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: isError ? 3_500_000_000 : 1_600_000_000)
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; p.animator().alphaValue = 0 }, completionHandler: {
                MainActor.assumeIsolated { p.orderOut(nil) }
            })
        }
    }
}

private struct ToastView: View {
    let message: String
    let systemImage: String
    let isError: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            Image(systemName: systemImage)
                .foregroundStyle(isError ? Color(nsColor: .systemRed) : Color.accentColor)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignTokens.Space.l)
        .padding(.vertical, DesignTokens.Space.m)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .padding(10)
    }
}
