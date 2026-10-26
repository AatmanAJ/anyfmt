import CoreGraphics
import Foundation

/// A band of the wheel between two radii (points).
public struct RadialRing: Equatable, Sendable {
    public var inner: CGFloat
    public var outer: CGFloat
    public init(inner: CGFloat, outer: CGFloat) {
        self.inner = inner
        self.outer = outer
    }
    public var depth: CGFloat { outer - inner }
    public var mid: CGFloat { (inner + outer) / 2 }
}

/// Geometry and motion. Defaults are the anyfmt design tokens (copied here so the
/// package stays standalone); every value can be overridden by the host.
public struct RadialMenuConfiguration: Equatable, Sendable {
    // MARK: Geometry (points)
    public var hubRadius: CGFloat = 40
    /// Inside this radius nothing is selected and a drop cancels.
    public var deadZoneRadius: CGFloat = 34
    public var innerRing = RadialRing(inner: 52, outer: 124)
    public var outerRing = RadialRing(inner: 130, outer: 192)
    public var maxPerInnerRing = 8
    public var maxPerOuterRing = 12
    /// Gap between neighbouring segments. Drawn as a constant-width channel
    /// (this angle measured at the inner ring's mid radius), so edges stay parallel.
    public var gapDegrees: CGFloat = 2
    public var cornerRadius: CGFloat = 8
    public var hoverScale: CGFloat = 1.06
    /// How far the hovered segment reaches outward (points).
    public var hoverLift: CGFloat = 5
    /// Drop/hover tolerance beyond the outermost ring, so a slight overshoot keeps the target.
    public var outerTolerance: CGFloat = 18
    /// Angular hysteresis before hover moves to a neighbour (degrees). Stops flicker on edges.
    /// The sticky rule below usually dominates; this is the floor.
    public var hysteresisDegrees: CGFloat = 1.5
    /// Sticky selection: to leave the highlighted segment the pointer must go this
    /// fraction of the segment's angle past its edge, or `stickyMinimumDegrees`,
    /// whichever is larger (capped at 45 % of the segment so neighbours stay
    /// reachable). Small drift while aiming never changes the target.
    public var stickyFraction: CGFloat = 0.3
    public var stickyMinimumDegrees: CGFloat = 10
    /// Radial slack on the boundary between the inner and outer ring (points).
    public var ringHysteresis: CGFloat = 6
    /// A move to another segment must hold this long before it takes (seconds).
    /// 0 switches at once. Moves into the hub or off the wheel are always immediate.
    public var switchDelay: Double = 0.06
    /// Depth of the "tune" lip on the outer edge of segments that have options (points).
    /// A drop there asks the host to configure instead of run. 0 disables the lip.
    public var lipDepth: CGFloat = 12
    /// Room outside the rim for preset chips (points). 0 disables presets.
    public var presetBand: CGFloat = 0
    public var presetChipHeight: CGFloat = 24
    /// Hover this long on a segment with presets to show its chips (they show at once when locked).
    public var presetDwell: Double = 0.4
    public var thumbnailSize: CGFloat = 56

    // MARK: Type (points)
    public var glyphSize: CGFloat = 18
    public var titleGlyphSize: CGFloat = 14
    public var labelSize: CGFloat = 11.5
    public var compactLabelSize: CGFloat = 9.5
    public var captionSize: CGFloat = 9
    public var badgeSize: CGFloat = 8
    public var hubLabelSize: CGFloat = 10.5

    // MARK: Motion (seconds)
    public var springResponse: Double = 0.25
    public var springDamping: Double = 0.8
    /// Whole open budget; the per-segment stagger shrinks to fit it.
    public var openDuration: Double = 0.15
    public var openStagger: Double = 0.008
    public var closeDuration: Double = 0.11
    public var morphDuration: Double = 0.16
    public var dropConfirmDuration: Double = 0.09
    public var crossfadeDuration: Double = 0.12
    /// Hover this long over the pager segment to flip pages mid-drag.
    public var pagerDwell: Double = 0.5
    /// Hover this long to ask the delegate for an options popover (0 disables).
    public var optionsDwell: Double = 0.6

    // MARK: Window
    /// Minimum distance from a screen edge.
    public var screenEdgeInset: CGFloat = 8
    /// Band at the top of each screen the wheel never enters (menu bar / Mission Control drag zone).
    public var topExclusion: CGFloat = 24
    /// Alpha painted over every hit area. Fully transparent pixels never receive drags.
    public var minimumHitAlpha: CGFloat = 0.01

    public init() {}

    /// Room around the outermost ring for lift, shadow and glow (and preset chips when enabled).
    public var decorationMargin: CGFloat { hoverLift + 26 + presetBand }

    /// Side of the square panel/view that fits the largest wheel this configuration can draw.
    public var canvasSide: CGFloat { ceil((outerRing.outer + decorationMargin) * 2) }

    /// Constant gap width in points.
    var gapWidth: CGFloat { gapDegrees * .pi / 180 * innerRing.mid }

    /// Duration each segment's own open animation runs, and the stagger that fits the budget.
    func openTiming(segmentCount n: Int) -> (stagger: Double, segment: Double) {
        let minimumSegment = min(0.09, openDuration)
        guard n > 1 else { return (0, openDuration) }
        let stagger = min(openStagger, (openDuration - minimumSegment) / Double(n - 1))
        return (max(0, stagger), openDuration - max(0, stagger) * Double(n - 1))
    }

    /// CASpringAnimation parameters for `springResponse`/`springDamping` (mass 1).
    var springStiffness: CGFloat { let w = 2 * .pi / springResponse; return CGFloat(w * w) }
    var springDampingCoefficient: CGFloat { CGFloat(4 * .pi * springDamping / springResponse) }
}
