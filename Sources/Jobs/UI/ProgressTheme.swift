import AppKit
import HaloCore
import SwiftUI

/// Progress-card metrics, type, colour and motion, all derived from `DesignTokens`.
/// Namespaced so nothing here collides with other lanes' helpers in the app module.
enum ProgressTheme {
    enum Metrics {
        /// Reference card ≈ 260 × 70 pt; ours is a little wider so a file name,
        /// the percentage and the ETA share one line without truncating.
        static let cardWidth: CGFloat = 288
        static let horizontalPadding = DesignTokens.Space.m
        static let verticalPadding = DesignTokens.Space.m - 1
        static let iconSize: CGFloat = 36
        static let iconSpacing = DesignTokens.Space.m - 2
        static let cornerRadius = DesignTokens.Radius.large
        static let barHeight: CGFloat = 5
        static let barTop: CGFloat = 7
        static let footerTop: CGFloat = 6
        static let controlSize: CGFloat = 18
        /// Gap between stacked cards.
        static let stackSpacing = DesignTokens.Space.s
        /// Transparent margin around each card inside its panel, for the soft shadow.
        static let shadowMargin: CGFloat = 22
        /// Keep cards this far inside the screen's visible frame.
        static let edgeInset = DesignTokens.Space.m
        /// The newest card's top edge sits this far below the drop point, so the
        /// pointer isn't left resting on it (which would pause auto-close).
        static let anchorGap: CGFloat = 26
        static let maxVisibleCards = 5
        static let buttonHeight: CGFloat = 22
    }

    enum Typography {
        static let title = DesignTokens.TypeRamp.body                 // 13
        static let detail = DesignTokens.TypeRamp.caption + 0.5       // 11
        static let message = DesignTokens.TypeRamp.label - 0.5        // 11.5
        static let button = DesignTokens.TypeRamp.caption + 0.5       // 11
    }

    enum Timing {
        static let autoClose: TimeInterval = 1.6
        static let hoverResume: TimeInterval = 1.0
        static let copiedFeedback: TimeInterval = 1.4
        static let restack: TimeInterval = 0.26
        /// Panel ordered out after this; `disappear` finishes inside it.
        static let dismiss: TimeInterval = DesignTokens.Motion.close + 0.07
        static let appear = Animation.spring(response: 0.34, dampingFraction: 0.8)
        static let disappear = Animation.easeIn(duration: DesignTokens.Motion.close + 0.03)
        static let fade = Animation.easeOut(duration: DesignTokens.Motion.crossfade + 0.03)
        static let state = Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let bar = Animation.linear(duration: 0.12)
    }

    // MARK: Colour

    static func color(_ pair: (light: Int, dark: Int), _ scheme: ColorScheme) -> Color {
        let hex = scheme == .dark ? pair.dark : pair.light
        return Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                     blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    static func accent(_ s: ColorScheme) -> Color { color(DesignTokens.Palette.iris, s) }
    static func success(_ s: ColorScheme) -> Color { color(DesignTokens.Palette.success, s) }
    static func danger(_ s: ColorScheme) -> Color { color(DesignTokens.Palette.danger, s) }
    static func ink(_ s: ColorScheme) -> Color { color(DesignTokens.Palette.ink, s) }

    static func secondary(_ s: ColorScheme, highContrast: Bool) -> Color {
        highContrast ? ink(s).opacity(0.86) : color(DesignTokens.Palette.mist, s)
    }

    static func track(_ s: ColorScheme, highContrast: Bool) -> Color {
        ink(s).opacity(highContrast ? 0.28 : (s == .dark ? 0.16 : 0.10))
    }

    static func hairline(_ s: ColorScheme, highContrast: Bool) -> Color {
        if highContrast { return ink(s).opacity(0.55) }
        return s == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    /// Fill used when transparency is reduced (and as the vibrancy's tint).
    static func solidSurface(_ s: ColorScheme) -> Color {
        s == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.17, opacity: 1)
            : Color(.sRGB, red: 0.985, green: 0.985, blue: 0.99, opacity: 1)
    }
}

/// How a card paints its background.
enum ProgressCardSurface: Equatable {
    /// Behind-window vibrancy (the real thing, on screen).
    case vibrancy
    /// A translucent fill approximating the material, for offscreen renders
    /// (`ImageRenderer` can't draw AppKit visual-effect views).
    case translucent
}

/// Accessibility settings a render can force (the system values are read-only).
struct ProgressAppearanceOverrides: Equatable {
    var increasedContrast: Bool?
    var reduceTransparency: Bool?
    var reduceMotion: Bool?
}

private struct ProgressCardSurfaceKey: EnvironmentKey {
    static let defaultValue = ProgressCardSurface.vibrancy
}

private struct ProgressAppearanceOverridesKey: EnvironmentKey {
    static let defaultValue = ProgressAppearanceOverrides()
}

extension EnvironmentValues {
    var progressCardSurface: ProgressCardSurface {
        get { self[ProgressCardSurfaceKey.self] }
        set { self[ProgressCardSurfaceKey.self] = newValue }
    }

    var progressAppearanceOverrides: ProgressAppearanceOverrides {
        get { self[ProgressAppearanceOverridesKey.self] }
        set { self[ProgressAppearanceOverridesKey.self] = newValue }
    }
}
