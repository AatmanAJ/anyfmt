import AppKit
import AnyfmtCore
import SwiftUI

/// An icon shown for a job: a Finder icon or a Quick Look thumbnail. Kept for
/// the model; the board layout leads with the numeral instead of an icon.
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

/// Board 5: a charcoal tile, the big display numeral on the left (percent while
/// running, the size change or time taken when done, a flame warning glyph on
/// failure), the file and a quiet detail line on the right over a cobalt band bar.
struct ProgressCard: View {
    @ObservedObject var model: ProgressCardModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.progressAppearanceOverrides) private var overrides

    private typealias M = ProgressTheme.Metrics
    private typealias T = ProgressTheme.Typography

    private var s: ProgressCardState { model.state }
    private var highContrast: Bool { overrides.increasedContrast ?? (contrast == .increased) }
    private var reduceMotion: Bool { overrides.reduceMotion ?? systemReduceMotion }
    private var flatBands: Bool { highContrast || (overrides.reduceTransparency ?? systemReduceTransparency) }
    private var secondary: Color { ProgressTheme.secondary(scheme, highContrast: highContrast) }

    var body: some View {
        HStack(alignment: s.phase == .failed ? .top : .center, spacing: M.columnGap) {
            ProgressNumeralView(numeral: s.numeral, highContrast: highContrast)
                .frame(width: M.numeralColumn, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                headline
                detailRow.padding(.top, DesignTokens.Component.ProgressCard.rowGap)
                switch s.phase {
                case .failed:
                    failureBody.transition(.opacity)
                case .queued, .running, .succeeded, .cancelled:
                    ProgressBarView(fraction: s.fraction, flat: flatBands, highContrast: highContrast,
                                    animate: !reduceMotion)
                        .frame(height: M.barHeight)
                        .padding(.top, M.barTop)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(M.padding)
        .frame(width: M.cardWidth, alignment: .leading)
        .modifier(ProgressCardChrome(highContrast: highContrast))
        .contentShape(RoundedRectangle(cornerRadius: M.cornerRadius, style: .continuous))
        .onTapGesture { if s.phase == .succeeded { model.onReveal() } }
        .modifier(ProgressAppearTransition(isShown: model.isShown, reduceMotion: reduceMotion))
        .animation(reduceMotion ? ProgressTheme.Timing.fade : ProgressTheme.Timing.state, value: s.phase)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(s.accessibilityLabel)
        .accessibilityAddTraits(s.phase == .succeeded ? .isButton : [])
        .accessibilityHint(s.phase == .succeeded && !s.outputs.isEmpty ? Text("Shows the result in Finder") : Text(""))
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.xs + DesignTokens.Space.xxs) {
            if s.phase == .succeeded {
                // Success is cobalt *and* a check, never colour alone.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: T.statusGlyph, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(ProgressTheme.onAccent, ProgressTheme.accentFill)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
            Text(verbatim: s.headline)
                .font(.system(size: T.headline, weight: .bold))
                .foregroundStyle(ProgressTheme.ink(scheme))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var detailRow: some View {
        HStack(spacing: DesignTokens.Space.s) {
            // Full wording when it fits, then the compact one, then truncate.
            ViewThatFits(in: .horizontal) {
                detailText(s.detail).fixedSize()
                if let short = s.detailShort { detailText(short).fixedSize() }
                detailText(s.detailShort ?? s.detail)
            }
            Spacer(minLength: DesignTokens.Space.xs)
            ZStack { control }
        }
        .frame(minHeight: M.quietButtonHeight)
    }

    private func detailText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: T.detail, weight: .medium))
            .foregroundStyle(secondary)
            .monospacedDigit()
            .lineLimit(1)
            .truncationMode(.middle)
    }

    @ViewBuilder private var control: some View {
        switch s.phase {
        case .queued, .running:
            if s.canCancel {
                Button(String(localized: "Cancel"), action: model.onCancel)
                    .buttonStyle(ProgressQuietButtonStyle())
                    .transition(.opacity)
            }
        case .succeeded:
            // The whole card reveals; the words appear on hover so it says so.
            if !s.outputs.isEmpty, model.isHovered {
                Button(String(localized: "Show in Finder"), action: model.onReveal)
                    .buttonStyle(ProgressQuietButtonStyle(accent: true))
                    .transition(.opacity)
            }
        case .cancelled:
            Button(String(localized: "Close"), action: model.onClose)
                .buttonStyle(ProgressQuietButtonStyle())
        case .failed:
            EmptyView()
        }
    }

    private var failureBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = s.message {
                Text(verbatim: message)
                    .font(.system(size: T.headline))
                    .foregroundStyle(ProgressTheme.ink(scheme))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DesignTokens.Component.ProgressCard.messageTop)
            }
            HStack(spacing: DesignTokens.Space.xs) {
                if s.details != nil {
                    Button(action: model.onCopyDetails) {
                        if model.didCopyDetails {
                            Label(String(localized: "Copied"), systemImage: "checkmark")
                        } else {
                            Text("Copy details")
                        }
                    }
                    .buttonStyle(ProgressQuietButtonStyle(large: true))
                    .help(String(localized: "Copies the versions, the engine’s last output and what was tried, for a bug report"))
                }
                Spacer(minLength: DesignTokens.Space.xs)
                Button(String(localized: "Close"), action: model.onClose)
                    .buttonStyle(ProgressQuietButtonStyle(large: true))
                if s.canRetry {
                    Button(s.retryLabel, action: model.onRetry)
                        .buttonStyle(.anyfmtPrimary)
                }
            }
            .padding(.top, DesignTokens.Component.ProgressCard.actionsTop)
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
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.s) {
            Text(verbatim: model.state.numeral.text ?? "")
                .font(.anyfmtDisplay(ProgressTheme.Typography.summaryNumeral))
                .displayTracking(ProgressTheme.Typography.summaryNumeral)
                .monospacedDigit()
                .foregroundStyle(ProgressTheme.ink(scheme))
            Text(verbatim: model.state.headline)
                .font(.system(size: ProgressTheme.Typography.headline, weight: .bold))
                .foregroundStyle(ProgressTheme.ink(scheme))
            Text(verbatim: model.state.detail)
                .font(.system(size: ProgressTheme.Typography.detail, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ProgressTheme.secondary(scheme, highContrast: highContrast))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ProgressTheme.Metrics.padding)
        .frame(width: ProgressTheme.Metrics.cardWidth, height: ProgressTheme.Metrics.summaryHeight)
        .modifier(ProgressCardChrome(highContrast: highContrast))
        .modifier(ProgressAppearTransition(isShown: model.isShown, reduceMotion: overrides.reduceMotion ?? systemReduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.state.accessibilityLabel)
    }
}

// MARK: - Pieces

/// The big figure: Inter Display Black, tight tracking, tabular digits.
struct ProgressNumeralView: View {
    let numeral: ProgressCardState.Numeral
    let highContrast: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            switch numeral {
            case .text(let text, let tone):
                Text(verbatim: text)
                    .font(.anyfmtDisplay(ProgressTheme.Typography.numeral))
                    .displayTracking(ProgressTheme.Typography.numeral)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(tone == .dim ? ProgressTheme.dimNumeral(scheme, highContrast: highContrast)
                                                  : ProgressTheme.ink(scheme))
            case .glyph(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: ProgressTheme.Typography.glyph, weight: .bold))
                    .foregroundStyle(ProgressTheme.danger(scheme))
                    .padding(.top, DesignTokens.Space.xxs)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The cobalt band bar (`Band.cobalt`); flat cobalt with an outline under
/// Increased Contrast or Reduce Transparency.
struct ProgressBarView: View {
    let fraction: Double
    let flat: Bool
    let highContrast: Bool
    let animate: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let f = CGFloat(min(1, max(0, fraction.isFinite ? fraction : 0)))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ProgressTheme.track(scheme, highContrast: highContrast))
                fill
                    .frame(width: f > 0 ? max(geo.size.height, geo.size.width * f) : 0)
                    .clipShape(Capsule())
            }
            .overlay {
                if highContrast {
                    Capsule().strokeBorder(ProgressTheme.ink(scheme), lineWidth: DesignTokens.Shape.hairline)
                }
            }
        }
        .animation(animate ? ProgressTheme.Timing.bar : nil, value: fraction)
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(ProgressCardState.percent(fraction)))
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var fill: some View {
        if flat {
            Color(hex: DesignTokens.Band.cobaltFlat)
        } else {
            BandGradient(bands: DesignTokens.Band.cobalt)
        }
    }
}

/// Text-only buttons for Cancel, Show in Finder, Copy details and Close: no
/// fill at rest, a raised capsule on hover and press. `large` matches the pill height.
struct ProgressQuietButtonStyle: ButtonStyle {
    var accent = false
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        QuietLabel(configuration: configuration, accent: accent, large: large)
    }

    private struct QuietLabel: View {
        let configuration: ButtonStyleConfiguration
        let accent: Bool
        let large: Bool
        @Environment(\.colorScheme) private var scheme
        @Environment(\.colorSchemeContrast) private var contrast
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.progressAppearanceOverrides) private var overrides
        @State private var hovering = false

        var body: some View {
            let highContrast = overrides.increasedContrast ?? (contrast == .increased)
            let base = accent ? ProgressTheme.accentText(scheme) : ProgressTheme.secondary(scheme, highContrast: highContrast)
            let lit = hovering || configuration.isPressed
            configuration.label
                .font(.system(size: large ? DesignTokens.Typeface.Size.body : DesignTokens.Typeface.Size.label, weight: .bold))
                .foregroundStyle(lit && !accent ? ProgressTheme.ink(scheme) : base)
                .padding(.horizontal, DesignTokens.Space.s)
                .frame(height: large ? DesignTokens.Component.Pill.height : ProgressTheme.Metrics.quietButtonHeight)
                .background(Capsule().fill(ProgressTheme.color(DesignTokens.Semantic.raised, scheme)).opacity(lit ? 1 : 0))
                .overlay {
                    if highContrast { Capsule().strokeBorder(base, lineWidth: DesignTokens.Shape.hairline) }
                }
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .animation(ProgressTheme.Timing.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// The charcoal tile, its edge (light mode / Increased Contrast) and the one
/// floating shadow. Solid by design: no material, so Reduce Transparency needs
/// nothing extra.
struct ProgressCardChrome: ViewModifier {
    let highContrast: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: ProgressTheme.Metrics.cornerRadius, style: .continuous)
        let e = DesignTokens.Component.Elevation.self
        return content
            .background(shape.fill(ProgressTheme.tile(scheme)))
            .overlay {
                if let edge = ProgressTheme.edge(scheme, highContrast: highContrast) {
                    shape.strokeBorder(edge, lineWidth: DesignTokens.Shape.hairline)
                }
            }
            .background(
                // Cast from an opaque twin and masked to outside the card and below
                // the stack gap, so the card above stays fully clickable.
                shape.fill(Color.black)
                    .shadow(color: .black.opacity(ProgressTheme.shadowOpacity(scheme)), radius: e.floatRadius, x: 0, y: e.floatOffsetY)
                    .mask(ProgressOutsideMask().padding(-ProgressTheme.Metrics.shadowMargin))
            )
    }
}

/// Everything except the card's own shape, so its shadow never darkens the card
/// itself. Above the card the shadow stops inside the stack gap, which keeps the
/// neighbouring card's pixels fully clear (and so clickable) where panels overlap.
private struct ProgressOutsideMask: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let m = ProgressTheme.Metrics.shadowMargin
                let above = ProgressTheme.Metrics.stackSpacing - 1
                p.addRect(CGRect(x: 0, y: m - above, width: geo.size.width, height: geo.size.height - (m - above)))
                let inner = CGRect(x: m, y: m, width: geo.size.width - 2 * m, height: geo.size.height - 2 * m)
                p.addPath(RoundedRectangle(cornerRadius: ProgressTheme.Metrics.cornerRadius, style: .continuous).path(in: inner))
            }
            .fill(style: FillStyle(eoFill: true))
        }
    }
}

/// Glides in from the drop point (above) and tucks back up towards it on the
/// way out, quickly enough to finish before the panel is ordered out. Reduce
/// Motion: a crossfade only.
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
            .offset(y: isShown || reduceMotion ? 0 : -DesignTokens.Space.s)
            .animation(animation, value: isShown)
    }
}
