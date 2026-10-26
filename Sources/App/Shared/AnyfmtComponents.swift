import AppKit
import AnyfmtCore
import SwiftUI

// Shared phase 2 components (PLAN-PHASE2 §2). Every surface builds from these:
// blue pill = primary, orange pill = secondary, quiet = text button; charcoal
// tiles; heavy uppercase display type; big numerals for stats.

/// Pill buttons. Primary: cobalt with white text (5.0:1). Secondary: orange with
/// black text (9.6:1). Quiet: no fill. Disabled lowers opacity *and* keeps the
/// label, so state never rides on colour alone.
struct AnyfmtPillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind = .primary
    var large = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let c = DesignTokens.Component.Pill.self
        configuration.label
            .font(.system(size: DesignTokens.TypeRamp.body, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .quiet ? DesignTokens.Space.s : c.horizontalPadding)
            .frame(minHeight: large ? c.largeHeight : c.height)
            .background { if let fill { Capsule().fill(fill) } }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: DesignTokens.Curve.snap.duration), value: configuration.isPressed)
    }

    private var fill: Color? {
        switch kind {
        case .primary: Color(hex: DesignTokens.Primitive.cobalt500)
        case .secondary: Color(hex: DesignTokens.Primitive.orange500)
        case .quiet: nil
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: Color(hex: DesignTokens.Semantic.onAccentPrimary)
        case .secondary: Color(hex: DesignTokens.Semantic.onAccentSecondary)
        case .quiet: Color.anyfmtSecondaryText
        }
    }
}

extension ButtonStyle where Self == AnyfmtPillButtonStyle {
    static var anyfmtPrimary: AnyfmtPillButtonStyle { AnyfmtPillButtonStyle(kind: .primary) }
    static var anyfmtSecondary: AnyfmtPillButtonStyle { AnyfmtPillButtonStyle(kind: .secondary) }
    static var anyfmtQuiet: AnyfmtPillButtonStyle { AnyfmtPillButtonStyle(kind: .quiet) }
}

extension View {
    /// A charcoal bento tile (one radius: `Shape.tile`).
    func anyfmtTile(padding: CGFloat = DesignTokens.Component.Tile.padding) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.anyfmtTile))
    }

    /// The window surface: near-black in dark (the hero), white in light.
    func anyfmtWindowBackground() -> some View {
        background(Color.anyfmtWindow.ignoresSafeArea())
    }
}

/// Heavy, tightly tracked, uppercase display words: format names, headlines.
struct DisplayText: View {
    let text: String
    var size: CGFloat = DesignTokens.Typeface.Size.displayL
    var uppercase = true

    init(_ text: String, size: CGFloat = DesignTokens.Typeface.Size.displayL, uppercase: Bool = true) {
        self.text = text
        self.size = size
        self.uppercase = uppercase
    }

    var body: some View {
        Text(verbatim: uppercase ? text.localizedUppercase : text)
            .font(.anyfmtDisplay(size))
            .displayTracking(size)
            .foregroundStyle(Color.anyfmtInk)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }
}

/// A big numeral with a caption. `hero` puts it on the heat band with black text.
struct StatNumeral: View {
    let value: String
    let caption: String
    var hero = false
    var size: CGFloat = DesignTokens.Component.Stat.valueSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Text(verbatim: value)
                .font(.anyfmtDisplay(size))
                .displayTracking(size)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(verbatim: caption)
                .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                .opacity(hero ? 0.85 : 1)
                .foregroundStyle(hero ? Color(hex: DesignTokens.Primitive.ink1000) : Color.anyfmtSecondaryText)
        }
        .foregroundStyle(hero ? Color(hex: DesignTokens.Primitive.ink1000) : Color.anyfmtInk)
        .padding(DesignTokens.Component.Tile.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if hero {
                BandGradient(bands: Array(DesignTokens.Band.heat.dropLast(2)), flat: DesignTokens.Band.heatFlat)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.anyfmtTile)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The named motion curves (DesignTokens.Curve) as SwiftUI animations.
/// `reduceMotion` swaps any of them for the short crossfade.
enum AnyfmtMotion {
    case snap, glide, settle, exit

    func animation(reduceMotion: Bool = false) -> Animation {
        if reduceMotion { return .easeOut(duration: DesignTokens.Curve.reducedCrossfade) }
        let c: (c1: CGPoint, c2: CGPoint, duration: Double)
        switch self {
        case .snap: c = DesignTokens.Curve.snap
        case .glide: c = DesignTokens.Curve.glide
        case .settle: c = DesignTokens.Curve.settle
        case .exit: c = DesignTokens.Curve.exit
        }
        return .timingCurve(c.c1.x, c.c1.y, c.c2.x, c.c2.y, duration: c.duration)
    }
}
