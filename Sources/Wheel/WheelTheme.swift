import AppKit
import HaloCore
import RadialMenu

/// Bridges Halo's design tokens into the standalone RadialMenu package.
public enum WheelTheme {
    public static var configuration: RadialMenuConfiguration {
        var c = RadialMenuConfiguration()
        let w = DesignTokens.Wheel.self, m = DesignTokens.Motion.self
        c.hubRadius = w.hubRadius
        c.deadZoneRadius = w.hubDeadZone
        c.innerRing = RadialRing(inner: w.ringInner, outer: w.ringOuter)
        c.outerRing = RadialRing(inner: w.secondRingInner, outer: w.secondRingOuter)
        c.maxPerInnerRing = w.maxPerInnerRing
        c.maxPerOuterRing = w.maxPerOuterRing
        c.gapDegrees = w.segmentGapDegrees
        c.cornerRadius = w.segmentCornerRadius
        c.hoverScale = w.hoverScale
        c.hoverLift = w.hoverLift
        c.thumbnailSize = w.thumbnailSize
        c.glyphSize = w.glyphSize
        c.labelSize = w.labelSize
        c.compactLabelSize = w.toolLabelSize
        c.captionSize = DesignTokens.TypeRamp.micro
        c.badgeSize = DesignTokens.TypeRamp.micro - 1
        c.hubLabelSize = DesignTokens.TypeRamp.caption
        c.springResponse = m.hoverResponse
        c.springDamping = m.hoverDamping
        c.openDuration = m.openTotal
        c.openStagger = m.openStaggerPerSegment
        c.closeDuration = m.close
        c.morphDuration = m.morph
        c.dropConfirmDuration = m.dropConfirm
        c.crossfadeDuration = m.crossfade
        c.screenEdgeInset = w.screenEdgeInset
        c.topExclusion = w.topExclusion
        c.minimumHitAlpha = w.minimumHitAlpha
        // Configuring happens after the drop (tune lip / ⌥), never by hovering mid-drag (D-038).
        c.optionsDwell = 0
        c.presetBand = 46
        // Format names are the segment's hero (D-042).
        c.labelSize = DesignTokens.Wheel.titleLabelSize
        return c
    }

    /// The approved phase 2 look (D-042): a painted near-black disc with charcoal
    /// wedges (no vibrancy), heavy uppercase format names in Inter Display, the
    /// heat band on the hovered segment with black text, cobalt for the lock,
    /// the lip, chips and the hub pill. Pro marks in orange with black text.
    public static var style: RadialMenuStyle {
        let p = DesignTokens.Primitive.self
        let dyn = { (light: Int, dark: Int) in RadialMenuStyle.dynamic(light: NSColor(srgbHex: light), dark: NSColor(srgbHex: dark)) }
        var style = RadialMenuStyle(
            accentColor: NSColor(srgbHex: p.cobalt500),
            badgeColor: dyn(DesignTokens.Palette.proGold.light, DesignTokens.Palette.proGold.dark),
            badgeTextColor: dyn(p.paper0, p.ink1000),
            material: .popover)
        let dark = RadialMenuStyle.Surface(
            disc: NSColor(srgbHex: p.ink950), segment: NSColor(srgbHex: p.ink800), hub: NSColor(srgbHex: p.ink900),
            stroke: NSColor(srgbHex: p.ink700), content: NSColor(srgbHex: p.paper0), secondaryContent: NSColor(srgbHex: p.ink400),
            highlightContent: NSColor(srgbHex: p.ink1000), pill: NSColor(srgbHex: p.ink900), pillText: NSColor(srgbHex: p.paper0))
        let light = RadialMenuStyle.Surface(
            disc: NSColor(srgbHex: p.paper50), segment: NSColor(srgbHex: p.paper0), hub: NSColor(srgbHex: p.paper50),
            stroke: NSColor(srgbHex: p.paper100), content: NSColor(srgbHex: p.ink950), secondaryContent: NSColor(srgbHex: p.ink300),
            highlightContent: NSColor(srgbHex: p.ink1000), pill: NSColor(srgbHex: p.ink950), pillText: NSColor(srgbHex: p.paper0))
        style.surface = RadialMenuStyle.SurfaceSet(light: light, dark: dark)
        style.highlightBands = DesignTokens.Band.heat.dropLast(2).map { NSColor(srgbHex: $0) }
        HaloFonts.registerBundled()
        style.titleFontName = DesignTokens.Typeface.displayBlack
        return style
    }

    public static var strings: RadialMenuStrings {
        var s = RadialMenuStrings()
        s.morePages = String(localized: "More", comment: "Wheel segment that shows the next page of targets")
        s.morePagesHint = String(localized: "Shows the next page of options", comment: "VoiceOver hint of the More segment")
        s.pageFormat = String(localized: "Page %d of %d", comment: "VoiceOver announcement when the wheel flips pages")
        s.menuHint = String(localized: "Arrow keys move, Return chooses, Escape cancels, Tab switches wheels",
                            comment: "VoiceOver help for the wheel")
        return s
    }
}
