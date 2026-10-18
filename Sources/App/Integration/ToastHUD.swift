import AppKit
import SwiftUI
import HaloCore

/// A brief confirmation near the drop point ("Copied 3 items", "Path copied"),
/// in the progress cards' language: a charcoal pill (or tile, when it wraps),
/// an icon and plain words; errors carry a flame warning glyph and stay longer.
/// Non-activating, click-through, leaves on its own.
@MainActor
enum ToastHUD {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ message: String, systemImage: String = "checkmark.circle.fill", isError: Bool = false,
                     near point: CGPoint = NSEvent.mouseLocation) {
        let t = DesignTokens.Component.Toast.self
        hideTask?.cancel()
        panel?.orderOut(nil)
        let kind: ToastContent.Kind = isError ? .error : (systemImage == "checkmark.circle.fill" ? .success : .info)
        let content = ToastContent(message: message, systemImage: systemImage, kind: kind)
        let view = NSHostingView(rootView: ToastView(content: content, increasedContrast: nil)
            .padding(DesignTokens.Component.ProgressCard.shadowMargin))
        view.layoutSubtreeIfNeeded()
        let size = view.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        // The view casts the one floating shadow itself.
        p.hasShadow = false
        p.level = .popUpMenu
        p.ignoresMouseEvents = true
        p.animationBehavior = .none
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = view
        // On the screen the drop happened on, just under the pointer, kept inside it.
        let margin = DesignTokens.Component.ProgressCard.shadowMargin
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height - t.gapBelowPointer + margin)
        if let vf = screen?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + t.screenInset - margin), vf.maxX - size.width + margin - t.screenInset)
            origin.y = min(max(origin.y, vf.minY + t.screenInset - margin), vf.maxY - size.height + margin - t.screenInset)
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let rest = NSRect(origin: origin, size: size)
        // Glide in from a touch higher (towards the pointer); Reduce Motion: fade only.
        p.setFrame(reduceMotion ? rest : rest.offsetBy(dx: 0, dy: DesignTokens.Space.s), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? DesignTokens.Curve.reducedCrossfade : DesignTokens.Curve.glide.duration
            ctx.timingFunction = curve(DesignTokens.Curve.glide)
            p.animator().alphaValue = 1
            if !reduceMotion { p.animator().setFrame(rest, display: true) }
        }
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                             userInfo: [.announcement: content.spoken,
                                        .priority: (isError ? NSAccessibilityPriorityLevel.high : .medium).rawValue])
        panel = p
        hideTask = Task { @MainActor in
            let seconds = isError ? t.errorDuration : t.successDuration
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = reduceMotion ? DesignTokens.Curve.reducedCrossfade : DesignTokens.Curve.exit.duration
                ctx.timingFunction = curve(DesignTokens.Curve.exit)
                p.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated { p.orderOut(nil) }
            })
        }
    }

    private static func curve(_ c: (c1: CGPoint, c2: CGPoint, duration: Double)) -> CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: Float(c.c1.x), Float(c.c1.y), Float(c.c2.x), Float(c.c2.y))
    }
}

/// What a toast says. Kind picks the glyph's colour; the glyph itself always
/// differs too (check, symbol, warning), so meaning never rides on colour.
struct ToastContent: Equatable {
    enum Kind: Equatable { case success, info, error }

    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var kind: Kind = .success

    init(message: String, systemImage: String = "checkmark.circle.fill", kind: Kind = .success) {
        self.message = message
        self.kind = kind
        self.systemImage = kind == .error ? "exclamationmark.triangle.fill" : systemImage
    }

    var spoken: String { kind == .error ? String(localized: "Error: \(message)") : message }
}

/// The toast itself: one line in a charcoal pill; longer messages wrap into a
/// charcoal tile (the two radii only).
struct ToastView: View {
    let content: ToastContent
    /// Forced by renders; nil follows the system.
    var increasedContrast: Bool?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias T = DesignTokens.Component.Toast

    var body: some View {
        Group {
            if fitsOnOneLine {
                row(lines: 1).background(chrome(Capsule()))
            } else {
                row(lines: 3).frame(width: T.maxWidth, alignment: .leading)
                    .background(chrome(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.spoken)
    }

    /// Measured, not guessed: a pill only when the words fit on one line.
    private var fitsOnOneLine: Bool {
        let font = NSFont.systemFont(ofSize: T.textSize, weight: .semibold)
        let text = (content.message as NSString).size(withAttributes: [.font: font]).width
        return text + T.glyphSize * 1.4 + T.iconSpacing + 2 * T.horizontalPadding <= T.maxWidth
    }

    private var highContrast: Bool { increasedContrast ?? (contrast == .increased) }

    private func color(_ pair: (light: Int, dark: Int)) -> Color {
        Color(hex: scheme == .dark ? pair.dark : pair.light)
    }

    private var glyphColor: Color {
        switch content.kind {
        case .success, .info: color(DesignTokens.Semantic.accentPrimaryText)
        case .error: color(DesignTokens.Palette.danger)
        }
    }

    private func row(lines: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: T.iconSpacing) {
            Image(systemName: content.systemImage)
                .font(.system(size: T.glyphSize, weight: .semibold))
                .foregroundStyle(glyphColor)
                .accessibilityHidden(true)
            Text(verbatim: content.message)
                .font(.system(size: T.textSize, weight: .semibold))
                .foregroundStyle(color(DesignTokens.Semantic.textPrimary))
                .lineLimit(lines)
                .fixedSize(horizontal: lines == 1, vertical: lines > 1)
        }
        .padding(.horizontal, T.horizontalPadding)
        .padding(.vertical, T.verticalPadding)
    }

    private func chrome<S: InsettableShape>(_ shape: S) -> some View {
        let e = DesignTokens.Component.Elevation.self
        return shape.fill(color(DesignTokens.Semantic.tile))
            .overlay {
                if highContrast {
                    shape.strokeBorder(color(DesignTokens.Semantic.textPrimary).opacity(0.7), lineWidth: DesignTokens.Shape.hairline)
                } else if scheme == .light {
                    shape.strokeBorder(color(DesignTokens.Semantic.hairline), lineWidth: DesignTokens.Shape.hairline)
                }
            }
            .shadow(color: .black.opacity(scheme == .dark ? e.floatOpacityDark : e.floatOpacityLight),
                    radius: e.floatRadius, x: 0, y: e.floatOffsetY)
    }
}
