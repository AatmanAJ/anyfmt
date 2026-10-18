import AppKit

/// The accessibility and appearance state the wheel renders for.
public struct RadialAppearance: Equatable, Hashable, Sendable {
    public var isDark: Bool
    public var increaseContrast: Bool
    public var reduceTransparency: Bool
    public var reduceMotion: Bool

    public init(isDark: Bool = false, increaseContrast: Bool = false,
                reduceTransparency: Bool = false, reduceMotion: Bool = false) {
        self.isDark = isDark
        self.increaseContrast = increaseContrast
        self.reduceTransparency = reduceTransparency
        self.reduceMotion = reduceMotion
    }

    public static let light = RadialAppearance()
    public static let dark = RadialAppearance(isDark: true)

    /// Reads the user's current settings (System Settings › Accessibility › Display).
    @MainActor
    public static func system(for appearance: NSAppearance? = nil) -> RadialAppearance {
        let effective = appearance ?? NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        let isDark = effective.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let workspace = NSWorkspace.shared
        return RadialAppearance(isDark: isDark,
                                increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
                                reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                                reduceMotion: workspace.accessibilityDisplayShouldReduceMotion)
    }

    /// The AppKit appearance colours are resolved against.
    @MainActor
    var nsAppearance: NSAppearance {
        let name: NSAppearance.Name
        switch (isDark, increaseContrast) {
        case (false, false): name = .aqua
        case (true, false): name = .darkAqua
        case (false, true): name = .accessibilityHighContrastAqua
        case (true, true): name = .accessibilityHighContrastDarkAqua
        }
        return NSAppearance(named: name) ?? NSAppearance(named: isDark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
    }
}

/// Colours, type and material. Colours may be dynamic (`NSColor(name:dynamicProvider:)`);
/// they're resolved against the wheel's `RadialAppearance`.
public struct RadialMenuStyle {
    public enum Material: String, CaseIterable, Sendable {
        /// `NSVisualEffectView.Material.popover`: bright frosted in light mode, smoky in dark. Default.
        case popover
        /// `.hudWindow`: darker and more see-through.
        case hudWindow

        var visualEffectMaterial: NSVisualEffectView.Material {
            switch self {
            case .popover: .popover
            case .hudWindow: .hudWindow
            }
        }
    }

    /// Hover fill, hub pill highlight, focus ring.
    public var accentColor: NSColor
    /// Fill of badge chips ("Pro").
    public var badgeColor: NSColor
    /// Text on badge chips.
    public var badgeTextColor: NSColor
    public var material: Material
    /// Forces an appearance (gallery, screenshots). Nil follows the system.
    public var appearanceOverride: RadialAppearance?
    /// Draws titles in capitals with a little tracking (format labels).
    public var uppercaseTitleProminence: Bool
    /// A painted, opaque wheel instead of behind-window vibrancy. nil keeps vibrancy.
    public var surface: SurfaceSet?
    /// Hard-edged vertical bands painted on the hovered segment (left → right),
    /// each fading into the next. nil uses the accent as a flat fill. Increased
    /// Contrast and Reduce Transparency always fall back to the flat accent.
    public var highlightBands: [NSColor]?
    /// PostScript name of the face for `.title` labels (format names). nil = system.
    public var titleFontName: String?

    /// Colours of a painted wheel, per appearance.
    public struct Surface {
        public var disc: NSColor
        public var segment: NSColor
        public var hub: NSColor
        public var stroke: NSColor
        public var content: NSColor
        public var secondaryContent: NSColor
        /// Content on the hovered segment (on the bands, or on the accent).
        public var highlightContent: NSColor
        public var pill: NSColor
        public var pillText: NSColor
        public init(disc: NSColor, segment: NSColor, hub: NSColor, stroke: NSColor, content: NSColor,
                    secondaryContent: NSColor, highlightContent: NSColor, pill: NSColor, pillText: NSColor) {
            self.disc = disc
            self.segment = segment
            self.hub = hub
            self.stroke = stroke
            self.content = content
            self.secondaryContent = secondaryContent
            self.highlightContent = highlightContent
            self.pill = pill
            self.pillText = pillText
        }
    }

    public struct SurfaceSet {
        public var light: Surface
        public var dark: Surface
        public init(light: Surface, dark: Surface) {
            self.light = light
            self.dark = dark
        }
    }

    public init(accentColor: NSColor = RadialMenuStyle.defaultAccent,
                badgeColor: NSColor = RadialMenuStyle.defaultBadge,
                badgeTextColor: NSColor = NSColor(srgbRed: 0.11, green: 0.105, blue: 0.133, alpha: 1),
                material: Material = .popover,
                appearanceOverride: RadialAppearance? = nil,
                uppercaseTitleProminence: Bool = true) {
        self.accentColor = accentColor
        self.badgeColor = badgeColor
        self.badgeTextColor = badgeTextColor
        self.material = material
        self.appearanceOverride = appearanceOverride
        self.uppercaseTitleProminence = uppercaseTitleProminence
    }

    /// Violet accent: #6E56F8 light, #8B78FF dark.
    public static var defaultAccent: NSColor {
        dynamic(light: NSColor(srgbHex: 0x6E56F8), dark: NSColor(srgbHex: 0x8B78FF))
    }

    /// Gold chip: #C28A00 light, #F5C451 dark.
    public static var defaultBadge: NSColor {
        dynamic(light: NSColor(srgbHex: 0xC28A00), dark: NSColor(srgbHex: 0xF5C451))
    }

    public static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}

public extension NSColor {
    convenience init(srgbHex hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Every colour the wheel draws with, resolved for one appearance. Internal.
struct RadialPalette {
    let appearance: RadialAppearance
    /// Painted under the tint when there's no live vibrancy (snapshots, Reduce Transparency).
    var material: CGColor
    /// Over the material at rest.
    var restFill: CGColor
    var hubFill: CGColor
    var stroke: CGColor
    let strokeWidth: CGFloat
    let rim: CGColor
    let rimWidth: CGFloat
    var content: NSColor
    var secondaryContent: NSColor
    let disabledContent: NSColor
    let highlightFill: CGColor
    let confirmFill: CGColor
    var highlightStroke: CGColor
    var highlightContent: NSColor
    let disabledHighlightFill: CGColor
    let shadowColor: CGColor
    var shadowOpacity: Float
    let shadowRadius: CGFloat
    let glowColor: CGColor
    var glowOpacity: Float
    var pillFill: CGColor
    var pillText: NSColor
    let pillHighlightFill: CGColor
    let badgeFill: NSColor
    let badgeText: NSColor
    let accent: NSColor
    let dropZoneStroke: CGColor
    let hitFill: CGColor
    /// Resolved hover bands (nil = flat `highlightFill`).
    var highlightBands: [CGColor]?
    var titleFontName: String?

    @MainActor
    init(style: RadialMenuStyle, appearance a: RadialAppearance, hitAlpha: CGFloat) {
        appearance = a
        func resolve(_ color: NSColor) -> NSColor {
            var out = color
            a.nsAppearance.performAsCurrentDrawingAppearance {
                out = color.usingColorSpace(.sRGB) ?? color
            }
            return out
        }
        let accent = resolve(style.accentColor)
        self.accent = accent
        let ink = NSColor(srgbHex: 0x1C1B22)
        let snow = NSColor(srgbHex: 0xF4F3F8)
        let white = NSColor.white
        let black = NSColor.black
        let opaque = a.reduceTransparency

        if a.isDark {
            material = NSColor(srgbRed: 0.15, green: 0.145, blue: 0.18, alpha: opaque ? 1 : 0.9).cgColor
            restFill = (a.increaseContrast ? black.withAlphaComponent(0.4) : white.withAlphaComponent(0.055)).cgColor
            hubFill = (a.increaseContrast ? black.withAlphaComponent(0.5) : white.withAlphaComponent(0.085)).cgColor
            stroke = white.withAlphaComponent(a.increaseContrast ? 0.75 : 0.13).cgColor
            strokeWidth = a.increaseContrast ? 1.25 : 0.5
            rim = black.withAlphaComponent(a.increaseContrast ? 0.9 : 0.5).cgColor
            content = a.increaseContrast ? white : snow.withAlphaComponent(0.93)
            secondaryContent = NSColor(srgbHex: a.increaseContrast ? 0xDAD8E3 : 0xA19FAD)
            disabledContent = white.withAlphaComponent(a.increaseContrast ? 0.5 : 0.28)
            shadowColor = black.cgColor
            shadowOpacity = 0.32
            shadowRadius = 8
            glowOpacity = a.increaseContrast ? 0.25 : 0.55
            pillFill = black.withAlphaComponent(a.increaseContrast ? 0.95 : 0.62).cgColor
            disabledHighlightFill = white.withAlphaComponent(0.14).cgColor
        } else {
            material = NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: opaque ? 1 : 0.86).cgColor
            restFill = white.withAlphaComponent(a.increaseContrast ? 0.88 : 0.36).cgColor
            hubFill = white.withAlphaComponent(a.increaseContrast ? 0.92 : 0.5).cgColor
            stroke = (a.increaseContrast ? ink.withAlphaComponent(0.7) : white.withAlphaComponent(0.85)).cgColor
            strokeWidth = a.increaseContrast ? 1.25 : 0.5
            rim = black.withAlphaComponent(a.increaseContrast ? 0.75 : 0.09).cgColor
            content = a.increaseContrast ? ink : ink.withAlphaComponent(0.9)
            secondaryContent = NSColor(srgbHex: a.increaseContrast ? 0x3E3C47 : 0x6B6977)
            disabledContent = ink.withAlphaComponent(a.increaseContrast ? 0.5 : 0.3)
            shadowColor = NSColor(srgbHex: 0x1C1B33).cgColor
            shadowOpacity = 0.13
            shadowRadius = 8
            glowOpacity = a.increaseContrast ? 0.2 : 0.42
            pillFill = ink.withAlphaComponent(a.increaseContrast ? 1 : 0.8).cgColor
            disabledHighlightFill = ink.withAlphaComponent(0.1).cgColor
        }
        rimWidth = a.increaseContrast ? 1 : 0.5
        let accentCG = accent.cgColor
        highlightFill = (a.increaseContrast ? (accent.blended(withFraction: 0.18, of: black) ?? accent) : accent).cgColor
        confirmFill = (accent.blended(withFraction: 0.3, of: white) ?? accent).cgColor
        highlightStroke = white.withAlphaComponent(a.increaseContrast ? 0.9 : 0.28).cgColor
        highlightContent = white
        glowColor = accentCG
        pillText = white
        pillHighlightFill = highlightFill
        badgeFill = resolve(style.badgeColor)
        badgeText = resolve(style.badgeTextColor)
        dropZoneStroke = (a.isDark ? white.withAlphaComponent(0.45) : ink.withAlphaComponent(0.35)).cgColor
        hitFill = NSColor(white: a.isDark ? 0 : 1, alpha: max(0.005, hitAlpha)).cgColor

        if let set = style.surface {
            let sf = a.isDark ? set.dark : set.light
            material = resolve(sf.disc).cgColor
            restFill = resolve(sf.segment).cgColor
            hubFill = resolve(sf.hub).cgColor
            stroke = resolve(a.increaseContrast ? sf.content.withAlphaComponent(0.7) : sf.stroke).cgColor
            content = resolve(sf.content)
            secondaryContent = resolve(sf.secondaryContent)
            pillFill = resolve(sf.pill).cgColor
            pillText = resolve(sf.pillText)
            // A painted surface sits flat: no glow, one quiet shadow.
            glowOpacity = 0
            shadowOpacity = min(shadowOpacity, 0.22)
            highlightStroke = accent.cgColor
        }
        let banded = !(a.increaseContrast || a.reduceTransparency) && (style.highlightBands?.count ?? 0) > 1
        highlightBands = banded ? style.highlightBands?.map { resolve($0).cgColor } : nil
        if let set = style.surface {
            let sf = a.isDark ? set.dark : set.light
            // On the bands the surface's highlight colour (dark text); on a flat accent, white.
            highlightContent = banded ? resolve(sf.highlightContent) : white
        }
        titleFontName = style.titleFontName
    }
}
