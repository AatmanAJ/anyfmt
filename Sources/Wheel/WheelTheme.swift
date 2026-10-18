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
        return c
    }

    public static var style: RadialMenuStyle {
        let p = DesignTokens.Palette.self
        return RadialMenuStyle(
            accentColor: RadialMenuStyle.dynamic(light: NSColor(srgbHex: p.iris.light), dark: NSColor(srgbHex: p.iris.dark)),
            badgeColor: RadialMenuStyle.dynamic(light: NSColor(srgbHex: p.proGold.light), dark: NSColor(srgbHex: p.proGold.dark)),
            badgeTextColor: NSColor(srgbHex: p.ink.light),
            material: .popover)
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
