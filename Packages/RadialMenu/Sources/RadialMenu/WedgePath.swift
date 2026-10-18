import CoreGraphics
import Foundation

/// Builds rounded annular-sector paths with a FIXED element structure
/// (move, 2 corner curves + 4 arc cubics per edge, 2 lines, close), whatever
/// the span. Core Animation can only interpolate paths with matching
/// structure, so this is what lets hover lifts and wheel switches morph
/// smoothly instead of popping.
enum WedgePath {
    struct Spec: Equatable {
        var start: CGFloat
        var end: CGFloat
        var inner: CGFloat
        var outer: CGFloat
        /// Constant-width channel between neighbours (points).
        var gap: CGFloat
        var corner: CGFloat
        /// Shrinks the shape uniformly (for inner hairline strokes).
        var inset: CGFloat = 0
    }

    private static let arcPieces = 4
    /// Cubic handle factor for the corner fillets (quarter-circle ≈ 0.552).
    private static let k: CGFloat = 0.552

    static func path(_ s: Spec, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let outerR = max(0.5, s.outer - s.inset)
        let innerR = max(0.25, min(outerR - 0.25, s.inner + s.inset))
        let half = max(0, s.gap / 2 + s.inset)
        var a0 = s.start, a1 = s.end
        if a1 < a0 { swap(&a0, &a1) }
        let mid = (a0 + a1) / 2

        // Angular extents where the side channels meet each circle.
        func extent(_ r: CGFloat) -> (CGFloat, CGFloat) {
            let d = half < r ? asin(half / r) : .pi / 2
            let lo = a0 + d, hi = a1 - d
            return lo <= hi ? (lo, hi) : (mid, mid)
        }
        let (o0, o1) = extent(outerR)
        var (i0, i1) = extent(innerR)
        if o0 == o1 { (i0, i1) = (mid, mid) }

        let depth = max(0, outerR - innerR)
        let outerArc = (o1 - o0) * outerR
        let innerArc = (i1 - i0) * innerR
        let co = max(0, min(s.corner, outerArc * 0.4, depth * 0.4))
        let ci = max(0, min(s.corner * 0.75, innerArc * 0.4, depth * 0.4))

        func p(_ a: CGFloat, _ r: CGFloat) -> CGPoint {
            CGPoint(x: center.x + r * sin(a), y: center.y + r * cos(a))
        }
        func along(_ point: CGPoint, _ a: CGFloat, _ distance: CGFloat) -> CGPoint {
            CGPoint(x: point.x + distance * sin(a), y: point.y + distance * cos(a))
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        func arc(from t0: CGFloat, to t1: CGFloat, radius r: CGFloat) {
            let delta = (t1 - t0) / CGFloat(arcPieces)
            let h = 4.0 / 3.0 * tan(delta / 4) * r
            for n in 0..<arcPieces {
                let s0 = t0 + CGFloat(n) * delta, s1 = s0 + delta
                let p0 = p(s0, r), p3 = p(s1, r)
                let c1 = CGPoint(x: p0.x + h * cos(s0), y: p0.y - h * sin(s0))
                let c2 = CGPoint(x: p3.x - h * cos(s1), y: p3.y + h * sin(s1))
                path.addCurve(to: p3, control1: c1, control2: c2)
            }
        }

        // Corner points where each side channel meets each circle.
        let cOS = p(o0, outerR), cOE = p(o1, outerR)
        let cIS = p(i0, innerR), cIE = p(i1, innerR)
        // Side-line direction is the ray direction of its edge angle.
        let aStart = startSideDirection(a0, cIS, cOS)
        let aEnd = startSideDirection(a1, cIE, cOE)

        let sideStartOuter = along(cOS, aStart + .pi, co)
        let arcStartOuter = o0 + co / outerR
        let arcEndOuter = o1 - co / outerR
        let sideEndOuter = along(cOE, aEnd + .pi, co)
        let sideEndInner = along(cIE, aEnd, ci)
        let arcEndInner = i1 - ci / innerR
        let arcStartInner = i0 + ci / innerR
        let sideStartInner = along(cIS, aStart, ci)

        path.move(to: sideStartOuter)
        let bOS = p(arcStartOuter, outerR)
        path.addCurve(to: bOS, control1: lerp(sideStartOuter, cOS, k), control2: lerp(bOS, cOS, k))
        arc(from: arcStartOuter, to: arcEndOuter, radius: outerR)
        let bOE = p(arcEndOuter, outerR)
        path.addCurve(to: sideEndOuter, control1: lerp(bOE, cOE, k), control2: lerp(sideEndOuter, cOE, k))
        path.addLine(to: sideEndInner)
        let bIE = p(arcEndInner, innerR)
        path.addCurve(to: bIE, control1: lerp(sideEndInner, cIE, k), control2: lerp(bIE, cIE, k))
        arc(from: arcEndInner, to: arcStartInner, radius: innerR)
        let bIS = p(arcStartInner, innerR)
        path.addCurve(to: sideStartInner, control1: lerp(bIS, cIS, k), control2: lerp(sideStartInner, cIS, k))
        path.closeSubpath()
        return path
    }

    /// Direction (clock angle) of the straight side running from the inner to the
    /// outer corner. Equals the edge's ray angle unless the shape degenerated.
    private static func startSideDirection(_ edge: CGFloat, _ inner: CGPoint, _ outer: CGPoint) -> CGFloat {
        let dx = outer.x - inner.x, dy = outer.y - inner.y
        if hypot(dx, dy) < 1e-6 { return edge }
        return atan2(dx, dy)
    }

    /// True when a spec covers the whole circle (a single-item ring).
    static func isFullRing(_ s: Spec) -> Bool { abs(s.end - s.start) >= 2 * .pi - 1e-4 }

    /// Outline of a full ring as two circles (no seam), for strokes of single-item rings.
    static func ringOutline(_ s: Spec, center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let outer = max(0.5, s.outer - s.inset), inner = max(0.25, s.inner + s.inset)
        path.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
        path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        return path
    }

    /// A plain circle (hub).
    static func circle(radius: CGFloat, center: CGPoint) -> CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
               transform: nil)
    }
}
