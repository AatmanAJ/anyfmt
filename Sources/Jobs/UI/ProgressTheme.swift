import AppKit
import HaloCore
import SwiftUI

/// Progress-card metrics, type, colour and motion, all from `DesignTokens`
/// (component tokens in `DesignTokens+Jobs.swift`). Namespaced so nothing here
/// collides with other areas' helpers in the app module.
enum ProgressTheme {
    private typealias C = DesignTokens.Component.ProgressCard

    enum Metrics {
        static let cardWidth = C.width
        static let padding = C.padding
        static let numeralColumn = C.numeralColumn
        static let columnGap = C.columnGap
        static let barHeight = C.barHeight
        static let barTop = C.barTop
        static let cornerRadius = DesignTokens.Shape.tile
        /// Gap between stacked cards.
        static let stackSpacing = C.stackSpacing
        /// Transparent margin around each card inside its panel, for its shadow.
        static let shadowMargin = C.shadowMargin
        /// Keep cards this far inside the screen's visible frame.
        static let edgeInset = C.edgeInset
        static let anchorGap = C.anchorGap
        static let maxVisibleCards = C.maxVisible
        static let summaryHeight = C.summaryHeight
        static let quietButtonHeight = C.quietButtonHeight
    }

    enum Typography {
        static let numeral = C.numeralSize
        static let glyph = C.glyphSize
        static let headline = C.headlineSize
        static let detail = C.detailSize
        static let statusGlyph = C.statusGlyphSize
        static let summaryNumeral = C.summaryNumeralSize
    }

    enum Timing {
        static let autoClose: TimeInterval = 1.6
        static let hoverResume: TimeInterval = 1.0
        static let copiedFeedback: TimeInterval = 1.4
        /// Sliding to a new slot in the stack.
        static let restack = DesignTokens.Curve.glide.duration + 0.04
        /// Panel ordered out after this; `disappear` finishes inside it.
        static let dismiss = DesignTokens.Curve.exit.duration + 0.06
        /// Cards in: glide. Out: exit. Presses: snap. Reduce Motion: a short crossfade.
        static let appear = curve(DesignTokens.Curve.glide)
        static let disappear = curve(DesignTokens.Curve.exit)
        static let press = curve(DesignTokens.Curve.snap)
        static let state = curve(DesignTokens.Curve.glide)
        static let fade = Animation.easeOut(duration: DesignTokens.Curve.reducedCrossfade)
        static let bar = Animation.linear(duration: DesignTokens.Curve.snap.duration)
        /// VoiceOver hears progress at most every quarter, and no more often than this.
        static let spokenProgressInterval: TimeInterval = 8

        static func curve(_ c: (c1: CGPoint, c2: CGPoint, duration: Double)) -> Animation {
            .timingCurve(Double(c.c1.x), Double(c.c1.y), Double(c.c2.x), Double(c.c2.y), duration: c.duration)
        }

        static func caCurve(_ c: (c1: CGPoint, c2: CGPoint, duration: Double)) -> CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: Float(c.c1.x), Float(c.c1.y), Float(c.c2.x), Float(c.c2.y))
        }
    }

    // MARK: Colour
    //
    // Resolved from the SwiftUI colour scheme (not the window's appearance) so
    // offscreen renders of either appearance come out right.

    static func color(_ pair: (light: Int, dark: Int), _ scheme: ColorScheme) -> Color {
        Color(hex: scheme == .dark ? pair.dark : pair.light)
    }

    static func tile(_ s: ColorScheme) -> Color { color(DesignTokens.Semantic.tile, s) }
    static func ink(_ s: ColorScheme) -> Color { color(DesignTokens.Semantic.textPrimary, s) }
    /// Cobalt as a small glyph or text (AA on either tile).
    static func accentText(_ s: ColorScheme) -> Color { color(DesignTokens.Semantic.accentPrimaryText, s) }
    /// Cobalt as a fill (behind white).
    static var accentFill: Color { Color(hex: DesignTokens.Primitive.cobalt500) }
    /// Errors: flame on charcoal, ember on light (both AA as text). Always with an icon + words.
    static func danger(_ s: ColorScheme) -> Color { color(DesignTokens.Palette.danger, s) }
    static var onAccent: Color { Color(hex: DesignTokens.Semantic.onAccentPrimary) }

    static func secondary(_ s: ColorScheme, highContrast: Bool) -> Color {
        highContrast ? ink(s) : color(DesignTokens.Semantic.textSecondary, s)
    }

    /// The dimmed display grey: only ever at numeral sizes.
    static func dimNumeral(_ s: ColorScheme, highContrast: Bool) -> Color {
        // Dark: the semantic dim grey (3.2:1 on charcoal, large type). Light: its
        // `textDimDisplay` (#9A9A9A) is only 2.5:1 on the #F2F2F2 tile, so use ink500 (4.6:1).
        highContrast ? secondary(s, highContrast: false)
            : color((light: DesignTokens.Primitive.ink500, dark: DesignTokens.Semantic.textDimDisplay.dark), s)
    }

    /// The empty part of the bar.
    static func track(_ s: ColorScheme, highContrast: Bool) -> Color {
        // Charcoal-on-charcoal in dark (the board), a hairline grey on the light tile.
        highContrast ? color(DesignTokens.Semantic.textSecondary, s).opacity(0.5)
            : color((light: DesignTokens.Semantic.hairline.light, dark: DesignTokens.Semantic.raised.dark), s)
    }

    /// The tile's edge: a hairline in light (so #F2F2F2 reads on a white desktop),
    /// none on dark; a full-strength line with Increased Contrast.
    static func edge(_ s: ColorScheme, highContrast: Bool) -> Color? {
        if highContrast { return ink(s).opacity(0.7) }
        return s == .light ? color(DesignTokens.Semantic.hairline, s) : nil
    }

    static func shadowOpacity(_ s: ColorScheme) -> Double {
        s == .dark ? DesignTokens.Component.Elevation.floatOpacityDark : DesignTokens.Component.Elevation.floatOpacityLight
    }
}

/// Accessibility settings a render can force (the system values are read-only).
struct ProgressAppearanceOverrides: Equatable {
    var increasedContrast: Bool?
    var reduceTransparency: Bool?
    var reduceMotion: Bool?
}

private struct ProgressAppearanceOverridesKey: EnvironmentKey {
    static let defaultValue = ProgressAppearanceOverrides()
}

extension EnvironmentValues {
    var progressAppearanceOverrides: ProgressAppearanceOverrides {
        get { self[ProgressAppearanceOverridesKey.self] }
        set { self[ProgressAppearanceOverridesKey.self] = newValue }
    }
}
