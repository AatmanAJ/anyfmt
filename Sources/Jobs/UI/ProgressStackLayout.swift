import AppKit
import CoreGraphics

/// A display's full and usable frames (AppKit screen coordinates, y up).
struct ProgressScreen: Equatable {
    let frame: CGRect
    /// Excludes the menu bar and Dock.
    let visibleFrame: CGRect

    @MainActor
    static func system() -> [ProgressScreen] {
        NSScreen.screens.map { ProgressScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }
}

/// Where stacked progress cards go. Pure geometry, unit-tested.
///
/// The newest card is centred horizontally on the drop point with its top edge
/// `gap` below it; older cards stack downward with `spacing` between them. The
/// whole column is then pushed fully inside the visible frame of the display
/// the point is on (bottom first, then top, so the newest card always wins).
enum ProgressStackLayout {
    /// The display containing `point`, else the nearest one.
    static func screen(for point: CGPoint, in screens: [ProgressScreen]) -> ProgressScreen? {
        if let hit = screens.first(where: { $0.frame.contains(point) }) { return hit }
        return screens.min { distance(point, $0.frame) < distance(point, $1.frame) }
    }

    /// Card rects, newest (index 0) on top.
    static func frames(sizes: [CGSize], anchor: CGPoint, visible: CGRect, spacing: CGFloat,
                       inset: CGFloat, gap: CGFloat) -> [CGRect] {
        guard !sizes.isEmpty else { return [] }
        let bounds = visible.insetBy(dx: inset, dy: inset)
        let width = sizes.map(\.width).max() ?? 0
        let total = sizes.map(\.height).reduce(0, +) + spacing * CGFloat(sizes.count - 1)

        var top = anchor.y - gap
        if top - total < bounds.minY { top = bounds.minY + total }
        if top > bounds.maxY { top = bounds.maxY }

        var x = anchor.x - width / 2
        if width >= bounds.width {
            x = bounds.minX
        } else {
            x = min(max(x, bounds.minX), bounds.maxX - width)
        }

        var rects: [CGRect] = []
        var y = top
        for s in sizes {
            y -= s.height
            rects.append(CGRect(x: (x + (width - s.width) / 2).rounded(), y: y.rounded(), width: s.width, height: s.height))
            y -= spacing
        }
        return rects
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
