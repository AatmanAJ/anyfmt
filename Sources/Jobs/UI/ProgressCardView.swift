import AppKit
import HaloCore
import SwiftUI

/// An icon shown in a card: a Finder icon, or a Quick Look thumbnail (drawn as a little print).
struct ProgressIconImage: Equatable {
    let image: NSImage
    let isThumbnail: Bool
}

/// Root view of every progress panel: the card plus the transparent margin its shadow needs.
struct ProgressCardRoot: View {
    @ObservedObject var model: ProgressCardModel

    var body: some View {
        Group {
            if model.subject == .summary {
                ProgressSummaryCard(model: model)
            } else {
                ProgressCard(model: model)
            }
        }
        .padding(ProgressTheme.Metrics.shadowMargin)
    }
}

// MARK: - The card

struct ProgressCard: View {
    @ObservedObject var model: ProgressCardModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.progressAppearanceOverrides) private var overrides

    private typealias M = ProgressTheme.Metrics
    private typealias T = ProgressTheme.Typography

    private var s: ProgressCardState { model.state }
    private var highContrast: Bool { overrides.increasedContrast ?? (contrast == .increased) }
    private var reduceMotion: Bool { overrides.reduceMotion ?? systemReduceMotion }
    private var secondary: Color { ProgressTheme.secondary(scheme, highContrast: highContrast) }
    private var accent: Color { ProgressTheme.accent(scheme) }

    var body: some View {
        HStack(alignment: .top, spacing: M.iconSpacing) {
            ProgressFileIcon(icons: model.icons, isBatch: s.isBatch, failed: s.phase == .failed)
            VStack(alignment: .leading, spacing: 0) {
                header
                switch s.phase {
                case .failed: failureBody.transition(.opacity)
                case .succeeded: successBody.transition(.opacity)
                case .queued, .running, .cancelled: progressBody.transition(.opacity)
                }
            }
        }
        .padding(.horizontal, M.horizontalPadding)
        .padding(.vertical, M.verticalPadding)
        .frame(width: M.cardWidth, alignment: .leading)
        .modifier(ProgressCardChrome(cornerRadius: M.cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: M.cornerRadius, style: .continuous))
        .onTapGesture { if s.phase == .succeeded { model.onReveal() } }
        .modifier(ProgressAppearTransition(isShown: model.isShown, reduceMotion: reduceMotion))
        .animation(reduceMotion ? ProgressTheme.Timing.fade : ProgressTheme.Timing.state, value: s.phase)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(s.accessibilityLabel)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(s.title)
                .font(.system(size: T.title, weight: .semibold))
                .foregroundStyle(ProgressTheme.ink(scheme))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            ZStack { trailingControl }
                .frame(width: M.controlSize, height: M.controlSize)
        }
        .frame(height: M.controlSize)
    }

    @ViewBuilder private var trailingControl: some View {
        switch s.phase {
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ProgressTheme.success(scheme))
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .accessibilityHidden(true)
        case .cancelled:
            ProgressCircleButton(symbol: "xmark", label: String(localized: "Close"), action: model.onClose)
                .transition(.opacity)
        case .queued, .running:
            if s.canCancel {
                ProgressCircleButton(symbol: "xmark", label: String(localized: "Cancel"), action: model.onCancel)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        case .failed:
            EmptyView()
        }
    }

    private var revealHint: Bool { s.phase == .succeeded && model.isHovered && !s.outputs.isEmpty }

    private var progressBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressBarView(fraction: s.fraction, fill: accent,
                            track: ProgressTheme.track(scheme, highContrast: highContrast),
                            animate: !reduceMotion)
                .frame(height: M.barHeight)
                .padding(.top, M.barTop)
            // Longest wording that fits without truncating anything: full, then
            // the compact ETA, then without the skipped note; last resort, a
            // middle-truncated caption.
            ViewThatFits(in: .horizontal) {
                footer(s.caption, s.trailing, truncates: false)
                if let compact = s.trailingCompact { footer(s.caption, compact, truncates: false) }
                if let short = s.captionShort {
                    footer(short, s.trailing, truncates: false)
                    if let compact = s.trailingCompact { footer(short, compact, truncates: false) }
                }
                footer(s.caption, s.trailingCompact ?? s.trailing, truncates: true)
            }
            .font(.system(size: T.detail))
            .foregroundStyle(secondary)
            .padding(.top, M.footerTop)
        }
    }

    private func footer(_ caption: String, _ trailing: String, truncates: Bool) -> some View {
        HStack(spacing: 6) {
            Text(caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .fixedSize(horizontal: !truncates, vertical: false)
            Spacer(minLength: 6)
            Text(trailing)
                .lineLimit(1)
                .monospacedDigit()
                .fixedSize()
        }
    }

    /// Done: the bar gives way to the new file's name and where it went
    /// ("Show in Finder" while hovered; the whole card is clickable).
    private var successBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.caption)
                .font(.system(size: T.detail, weight: .medium))
                .foregroundStyle(ProgressTheme.ink(scheme).opacity(0.86))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(revealHint ? String(localized: "Show in Finder") : s.trailing)
                .font(.system(size: T.detail))
                .foregroundStyle(revealHint ? accent : secondary)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

    private var failureBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = s.message {
                Text(message)
                    .font(.system(size: T.message))
                    .foregroundStyle(secondary)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
            HStack(spacing: 6) {
                if s.details != nil {
                    Button(model.didCopyDetails ? String(localized: "Copied") : String(localized: "Copy details"),
                           action: model.onCopyDetails)
                        .buttonStyle(ProgressPillButtonStyle(kind: .quiet))
                        .help(String(localized: "Copies technical details for a bug report"))
                }
                Spacer(minLength: 4)
                Button(String(localized: "Close"), action: model.onClose)
                    .buttonStyle(ProgressPillButtonStyle(kind: .quiet))
                if s.canRetry {
                    Button(s.retryLabel, action: model.onRetry)
                        .buttonStyle(ProgressPillButtonStyle(kind: .prominent))
                }
            }
            .padding(.top, 9)
        }
    }
}

// MARK: - "+3 more"

struct ProgressSummaryCard: View {
    @ObservedObject var model: ProgressCardModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.progressAppearanceOverrides) private var overrides

    var body: some View {
        let highContrast = overrides.increasedContrast ?? (contrast == .increased)
        let secondary = ProgressTheme.secondary(scheme, highContrast: highContrast)
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondary)
            Text(model.state.title)
                .font(.system(size: ProgressTheme.Typography.detail, weight: .semibold))
                .foregroundStyle(ProgressTheme.ink(scheme))
            Spacer(minLength: 4)
            Text(model.state.trailing)
                .font(.system(size: ProgressTheme.Typography.detail))
                .monospacedDigit()
                .foregroundStyle(secondary)
        }
        .padding(.horizontal, ProgressTheme.Metrics.horizontalPadding)
        .frame(width: ProgressTheme.Metrics.cardWidth, height: 30)
        .modifier(ProgressCardChrome(cornerRadius: DesignTokens.Radius.medium))
        .modifier(ProgressAppearTransition(isShown: model.isShown, reduceMotion: overrides.reduceMotion ?? systemReduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.state.accessibilityLabel)
    }
}

// MARK: - Pieces

struct ProgressFileIcon: View {
    let icons: [ProgressIconImage]
    let isBatch: Bool
    let failed: Bool
    @Environment(\.colorScheme) private var scheme

    private let size = ProgressTheme.Metrics.iconSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if isBatch, icons.count > 1 {
                    // A small fanned stack: back items tilt away.
                    ForEach(Array(icons.prefix(3).enumerated()).reversed(), id: \.offset) { i, icon in
                        single(icon, side: size - 8)
                            .rotationEffect(.degrees(Double(i) * -8), anchor: .bottom)
                            .offset(x: CGFloat(i) * -2, y: CGFloat(i) * -1.5)
                            .opacity(1 - Double(i) * 0.12)
                    }
                } else if let icon = icons.first {
                    single(icon, side: size)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(ProgressTheme.secondary(scheme, highContrast: false))
                }
            }
            .frame(width: size, height: size)
            if failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, ProgressTheme.danger(scheme))
                    .background(Circle().fill(ProgressTheme.solidSurface(scheme)).padding(-1.5))
                    .offset(x: 3, y: 3)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func single(_ icon: ProgressIconImage, side: CGFloat) -> some View {
        if icon.isThumbnail {
            Image(nsImage: icon.image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(1.5)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white))
                .shadow(color: .black.opacity(0.22), radius: 1.2, x: 0, y: 0.6)
                .frame(width: side - 4, height: side - 4)
        } else {
            Image(nsImage: icon.image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
        }
    }
}

struct ProgressBarView: View {
    let fraction: Double
    let fill: Color
    let track: Color
    let animate: Bool

    var body: some View {
        let f = CGFloat(min(1, max(0, fraction.isFinite ? fraction : 0)))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(LinearGradient(colors: [fill.opacity(0.82), fill], startPoint: .leading, endPoint: .trailing))
                    .frame(width: f > 0 ? max(geo.size.height, geo.size.width * f) : 0)
            }
        }
        .animation(animate ? ProgressTheme.Timing.bar : nil, value: fraction)
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(ProgressCardState.percent(fraction)))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct ProgressCircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        let ink = ProgressTheme.ink(scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(ink.opacity(hovering ? 0.85 : 0.55))
                .frame(width: ProgressTheme.Metrics.controlSize, height: ProgressTheme.Metrics.controlSize)
                .background(Circle().fill(ink.opacity(hovering ? 0.15 : 0.075)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(Text(label))
        .help(label)
    }
}

struct ProgressPillButtonStyle: ButtonStyle {
    enum Kind { case quiet, prominent }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        PillLabel(configuration: configuration, kind: kind)
    }

    private struct PillLabel: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            let ink = ProgressTheme.ink(scheme)
            configuration.label
                .font(.system(size: ProgressTheme.Typography.button, weight: .medium))
                .foregroundStyle(kind == .prominent ? Color.white : ink.opacity(0.88))
                .padding(.horizontal, 10)
                .frame(height: ProgressTheme.Metrics.buttonHeight)
                .background(Capsule().fill(kind == .prominent ? ProgressTheme.accent(scheme)
                    : ink.opacity(scheme == .dark ? 0.14 : 0.075)))
                .contentShape(Capsule())
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// Background, hairline and shadow shared by every card.
struct ProgressCardChrome: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.progressAppearanceOverrides) private var overrides
    @Environment(\.progressCardSurface) private var surface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let reduce = overrides.reduceTransparency ?? systemReduceTransparency
        let highContrast = overrides.increasedContrast ?? (contrast == .increased)
        return content
            .background(background(reduce: reduce).clipShape(shape))
            .overlay(shape.strokeBorder(ProgressTheme.hairline(scheme, highContrast: highContrast),
                                        lineWidth: highContrast ? 1 : 0.5))
            .background(
                // Shadow from an opaque twin so a translucent surface doesn't show it through.
                shape.fill(Color.black)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.18), radius: 14, x: 0, y: 7)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.08), radius: 1, x: 0, y: 0.5)
                    .mask(ProgressOutsideMask(cornerRadius: cornerRadius).padding(-ProgressTheme.Metrics.shadowMargin))
            )
    }

    @ViewBuilder private func background(reduce: Bool) -> some View {
        if reduce {
            ProgressTheme.solidSurface(scheme)
        } else {
            switch surface {
            case .vibrancy:
                ZStack {
                    ProgressVibrancy(cornerRadius: cornerRadius)
                    ProgressTheme.solidSurface(scheme).opacity(scheme == .dark ? 0.22 : 0.38)
                }
            case .translucent:
                ProgressTheme.solidSurface(scheme).opacity(scheme == .dark ? 0.86 : 0.84)
            }
        }
    }
}

/// Everything except the card's own shape, so its shadow never darkens the card
/// itself. Above the card the shadow stops inside the stack gap, which keeps the
/// neighbouring card's pixels fully clear (and so clickable) where panels overlap.
private struct ProgressOutsideMask: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let m = ProgressTheme.Metrics.shadowMargin
                let above = ProgressTheme.Metrics.stackSpacing - 1
                p.addRect(CGRect(x: 0, y: m - above, width: geo.size.width, height: geo.size.height - (m - above)))
                let inner = CGRect(x: m, y: m, width: geo.size.width - 2 * m, height: geo.size.height - 2 * m)
                p.addPath(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: inner))
            }
            .fill(style: FillStyle(eoFill: true))
        }
    }
}

/// Springs in from the drop point (above) and tucks back up towards it on the
/// way out, quickly enough to finish before the panel is ordered out. Reduce
/// Motion: fades only.
struct ProgressAppearTransition: ViewModifier {
    let isShown: Bool
    let reduceMotion: Bool

    private var animation: Animation {
        if reduceMotion { return ProgressTheme.Timing.fade }
        return isShown ? ProgressTheme.Timing.appear : ProgressTheme.Timing.disappear
    }

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.92, anchor: .top)
            .offset(y: isShown || reduceMotion ? 0 : -8)
            .animation(animation, value: isShown)
    }
}

/// Behind-window vibrancy with rounded corners (an AppKit view ignores SwiftUI clipping,
/// so the corners come from `maskImage`).
struct ProgressVibrancy: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        v.maskImage = Self.mask(radius: cornerRadius)
        return v
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    static func mask(radius: CGFloat) -> NSImage {
        // Continuous corners reach ≈ 1.53 × radius along each edge.
        let cap = (radius * 1.6).rounded(.up)
        let edge = cap * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            let path = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(path)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cap, left: cap, bottom: cap, right: cap)
        image.resizingMode = .stretch
        return image
    }
}
