import CoreGraphics
import Foundation

/// A display, in global AppKit coordinates (origin at the bottom-left of the primary screen).
public struct RadialScreen: Equatable, Sendable {
    public var frame: CGRect
    /// Frame minus the menu bar and Dock (`NSScreen.visibleFrame`).
    public var visibleFrame: CGRect
    public var backingScale: CGFloat

    public init(frame: CGRect, visibleFrame: CGRect? = nil, backingScale: CGFloat = 2) {
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
        self.backingScale = backingScale
    }
}

/// Where to centre a wheel so it's never clipped. Pure, so it's unit-tested
/// against every edge, corner and multi-display arrangement.
public enum RadialPlacement {
    /// The screen that contains `point`, else the nearest one.
    public static func screen(for point: CGPoint, in screens: [RadialScreen]) -> RadialScreen? {
        if let hit = screens.first(where: { contains($0.frame, point) }) { return hit }
        return screens.min { distance(point, $0.frame) < distance(point, $1.frame) }
    }

    /// Centre for a wheel of `radius` summoned at `point`: the point itself when it
    /// fits, otherwise pushed inward just enough to clear every edge by `edgeInset`
    /// and stay below the top exclusion band (menu bar / Mission Control drag zone).
    /// The result is snapped to the backing pixel grid so hairlines stay crisp.
    public static func center(for point: CGPoint, radius: CGFloat, screens: [RadialScreen],
                              edgeInset: CGFloat = 8, topExclusion: CGFloat = 24) -> CGPoint {
        guard let screen = screen(for: point, in: screens) else { return point }
        let allowed = allowedRect(on: screen, edgeInset: edgeInset, topExclusion: topExclusion)
        func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
            lo > hi ? (lo + hi) / 2 : min(max(v, lo), hi)
        }
        let x = clamp(point.x, allowed.minX + radius, allowed.maxX - radius)
        let y = clamp(point.y, allowed.minY + radius, allowed.maxY - radius)
        let scale = max(1, screen.backingScale)
        return CGPoint(x: (x * scale).rounded() / scale, y: (y * scale).rounded() / scale)
    }

    /// The region a wheel may occupy on `screen`.
    public static func allowedRect(on screen: RadialScreen, edgeInset: CGFloat, topExclusion: CGFloat) -> CGRect {
        let f = screen.frame
        // Never under the menu bar (visible frame top) or inside the top drag band.
        let top = min(screen.visibleFrame.maxY, f.maxY - topExclusion) - edgeInset
        let bottom = f.minY + edgeInset
        let left = f.minX + edgeInset
        let right = f.maxX - edgeInset
        return CGRect(x: left, y: bottom, width: max(0, right - left), height: max(0, top - bottom))
    }

    /// Frame for a square canvas of `side` centred on `center`.
    public static func frame(side: CGFloat, centeredAt center: CGPoint) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    private static func contains(_ rect: CGRect, _ p: CGPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }

    private static func distance(_ p: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return hypot(dx, dy)
    }
}
