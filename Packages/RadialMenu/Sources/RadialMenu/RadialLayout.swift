import CoreGraphics
import Foundation

// Angles are "clock" radians: 0 at 12 o'clock, increasing clockwise.
// Points are relative to the wheel centre with y up (AppKit, non-flipped).

/// One drawn segment position.
public struct RadialSlot: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// Index into the menu's item array.
        case item(Int)
        /// "More" segment that flips the outer ring to its next page.
        case pager
    }

    public let content: Content
    /// 0 = inner ring, 1 = outer ring.
    public let ring: Int
    public let startAngle: CGFloat
    public let endAngle: CGFloat
    public let band: RadialRing

    public var midAngle: CGFloat { (startAngle + endAngle) / 2 }
    public var span: CGFloat { endAngle - startAngle }

    public var itemIndex: Int? {
        if case .item(let i) = content { return i }
        return nil
    }

    public var isPager: Bool { content == .pager }

    /// True if `angle` (any range) falls inside this slot, widened by `slack` on both sides.
    public func contains(angle: CGFloat, slack: CGFloat = 0) -> Bool {
        if span + 2 * slack >= 2 * .pi { return true }
        let delta = RadialLayout.normalized(angle - (startAngle - slack))
        return delta < span + 2 * slack
    }
}

/// Result of an angular hit test.
public enum RadialHit: Equatable, Sendable {
    /// Inside the hub dead zone: nothing is selected, a drop cancels.
    case deadZone
    /// Index into `RadialLayout.slots`.
    case slot(Int)
    /// Beyond the wheel.
    case outside
}

/// Pure layout of items into rings and pages. No AppKit, fully unit-testable.
///
/// - Up to `maxPerInnerRing` items: one ring, item 0 centred at 12 o'clock.
/// - Up to inner + outer max: the inner ring is full and the rest sit on a
///   second ring, as a contiguous arc of fixed-width wedges centred on 12 o'clock.
///   The outer ring "fills up" clockwise as a file gains targets.
/// - Beyond that the outer ring is paginated: `maxPerOuterRing - 1` items per
///   page plus a pager segment at 11 o'clock that flips pages (spring-loaded
///   on hover mid-drag, click/keys otherwise). Never an overflow menu.
public struct RadialLayout: Equatable, Sendable {
    public let itemCount: Int
    public let configuration: RadialMenuConfiguration
    public let page: Int
    public let pageCount: Int
    public let innerCount: Int
    /// Items on the outer ring on the current page.
    public let outerCount: Int
    /// Inner ring clockwise from 12 o'clock, then the outer ring clockwise, then the pager.
    /// This is also the keyboard order.
    public let slots: [RadialSlot]

    public var isPaginated: Bool { pageCount > 1 }
    public var hasOuterRing: Bool { slots.contains { $0.ring == 1 } }

    /// Outer edge of the outermost ring drawn (points).
    public var outerRadius: CGFloat {
        hasOuterRing ? configuration.outerRing.outer : configuration.innerRing.outer
    }

    /// Radius that separates the two rings for hit testing.
    var ringBoundary: CGFloat { (configuration.innerRing.outer + configuration.outerRing.inner) / 2 }

    public init(itemCount: Int, configuration: RadialMenuConfiguration = RadialMenuConfiguration(), page: Int = 0) {
        let n = max(0, itemCount)
        let maxInner = max(1, configuration.maxPerInnerRing)
        let maxOuter = max(2, configuration.maxPerOuterRing)
        self.itemCount = n
        self.configuration = configuration

        var slots: [RadialSlot] = []
        let inner = min(n, maxInner)
        let innerSpan = inner > 0 ? 2 * CGFloat.pi / CGFloat(inner) : 0
        for i in 0..<inner {
            let mid = CGFloat(i) * innerSpan
            slots.append(RadialSlot(content: .item(i), ring: 0, startAngle: mid - innerSpan / 2,
                                    endAngle: mid + innerSpan / 2, band: configuration.innerRing))
        }

        let requestedPage = page
        let remaining = n - inner
        let outerSpan = 2 * CGFloat.pi / CGFloat(maxOuter)
        var pageCount = 1
        var currentPage = 0
        var outerCount = 0
        if remaining > 0 && remaining <= maxOuter {
            // Contiguous arc centred on 12 o'clock.
            outerCount = remaining
            let start = -CGFloat(remaining) * outerSpan / 2
            for j in 0..<remaining {
                let a0 = start + CGFloat(j) * outerSpan
                slots.append(RadialSlot(content: .item(inner + j), ring: 1, startAngle: a0,
                                        endAngle: a0 + outerSpan, band: configuration.outerRing))
            }
        } else if remaining > maxOuter {
            let perPage = maxOuter - 1
            pageCount = (remaining + perPage - 1) / perPage
            currentPage = ((requestedPage % pageCount) + pageCount) % pageCount
            let first = inner + currentPage * perPage
            let last = min(n, first + perPage)
            outerCount = last - first
            for (j, index) in (first..<last).enumerated() {
                let mid = CGFloat(j) * outerSpan
                slots.append(RadialSlot(content: .item(index), ring: 1, startAngle: mid - outerSpan / 2,
                                        endAngle: mid + outerSpan / 2, band: configuration.outerRing))
            }
            let pagerMid = CGFloat(maxOuter - 1) * outerSpan
            slots.append(RadialSlot(content: .pager, ring: 1, startAngle: pagerMid - outerSpan / 2,
                                    endAngle: pagerMid + outerSpan / 2, band: configuration.outerRing))
        }

        self.innerCount = inner
        self.outerCount = outerCount
        self.pageCount = pageCount
        self.page = currentPage
        self.slots = slots
    }

    /// Index into `slots` for an item, if it's visible on this page.
    public func slotIndex(forItem item: Int) -> Int? {
        slots.firstIndex { $0.itemIndex == item }
    }

    /// The page that shows `item` (0 for inner-ring items).
    public func page(containing item: Int) -> Int {
        guard isPaginated, item >= innerCount else { return 0 }
        return (item - innerCount) / max(1, configuration.maxPerOuterRing - 1)
    }

    // MARK: Hit testing

    /// Angular hit test. The whole wedge (gaps included) is the target; the ring is
    /// chosen by radius. Where the outer ring has no slot (a partial arc), the inner
    /// ring's wedge at that angle wins, so overshooting the inner ring still hits.
    /// `current` (a slot index) adds hysteresis so hover doesn't flicker on edges.
    public func hitTest(_ point: CGPoint, current: Int? = nil) -> RadialHit {
        let distance = hypot(point.x, point.y)
        if distance < configuration.deadZoneRadius { return .deadZone }
        guard !slots.isEmpty else {
            return distance <= configuration.innerRing.outer + configuration.outerTolerance ? .deadZone : .outside
        }
        if distance > outerRadius + configuration.outerTolerance { return .outside }
        let angle = RadialLayout.clockAngle(of: point)

        var boundary = ringBoundary
        if let current, slots.indices.contains(current) {
            boundary += slots[current].ring == 1 ? -configuration.ringHysteresis : configuration.ringHysteresis
        }
        let ring = hasOuterRing && distance >= boundary ? 1 : 0

        if let current, slots.indices.contains(current), slots[current].ring == ring,
           slots[current].contains(angle: angle, slack: stickySlack(for: slots[current])) {
            return .slot(current)
        }
        if let index = slots.firstIndex(where: { $0.ring == ring && $0.contains(angle: angle) }) {
            return .slot(index)
        }
        if ring == 1, let index = slots.firstIndex(where: { $0.ring == 0 && $0.contains(angle: angle) }) {
            return .slot(index)
        }
        return .outside
    }

    /// How far past its edges the highlighted segment keeps the pointer (radians).
    /// max(stickyFraction × width, stickyMinimumDegrees, hysteresisDegrees), never more than 45 % of the width.
    public func stickySlack(for slot: RadialSlot) -> CGFloat {
        let width = slot.span
        let wanted = max(configuration.stickyFraction * width,
                         configuration.stickyMinimumDegrees * .pi / 180,
                         configuration.hysteresisDegrees * .pi / 180)
        return min(wanted, 0.45 * width)
    }

    // MARK: Keyboard order

    /// Next/previous slot in angular (keyboard) order, wrapping. `nil` start = first/last.
    public func step(from current: Int?, by delta: Int) -> Int? {
        guard !slots.isEmpty else { return nil }
        guard let current, slots.indices.contains(current) else { return delta >= 0 ? 0 : slots.count - 1 }
        let count = slots.count
        return ((current + delta) % count + count) % count
    }

    /// The slot on the other ring nearest in angle (Up/Down arrows). Same slot if there's one ring.
    public func acrossRing(from current: Int?) -> Int? {
        guard let current, slots.indices.contains(current) else { return slots.isEmpty ? nil : 0 }
        let from = slots[current]
        let target = from.ring == 0 ? 1 : 0
        let candidates = slots.indices.filter { slots[$0].ring == target }
        guard !candidates.isEmpty else { return current }
        return candidates.min { a, b in
            RadialLayout.angularDistance(slots[a].midAngle, from.midAngle)
                < RadialLayout.angularDistance(slots[b].midAngle, from.midAngle)
        }
    }

    // MARK: Geometry helpers

    /// Where a segment's glyph + label sit (relative to the centre).
    public func contentCenter(of slot: RadialSlot) -> CGPoint {
        let r = slot.band.mid + (slot.ring == 0 ? 2 : 1)
        // Very wide single wedges look better with their content at the top.
        return RadialLayout.point(angle: slot.midAngle, radius: r)
    }

    /// Room for content inside a slot (width, height), conservative.
    public func contentSize(of slot: RadialSlot) -> CGSize {
        let span = min(slot.span, .pi)
        let chordAtInner = 2 * slot.band.inner * sin(span / 2)
        let chordAtMid = 2 * slot.band.mid * sin(span / 2)
        let width = max(24, min(chordAtMid - 10, (chordAtInner + chordAtMid) / 2 + 4))
        let height = slot.band.depth - 12
        return CGSize(width: min(width, slot.band.depth * 1.6), height: height)
    }

    /// Axis-aligned bounds of a slot's wedge (relative to the centre).
    public func bounds(of slot: RadialSlot) -> CGRect {
        var points: [CGPoint] = []
        let steps = 12
        for k in 0...steps {
            let a = slot.startAngle + slot.span * CGFloat(k) / CGFloat(steps)
            points.append(RadialLayout.point(angle: a, radius: slot.band.outer))
            points.append(RadialLayout.point(angle: a, radius: slot.band.inner))
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func clockAngle(of point: CGPoint) -> CGFloat {
        normalized(atan2(point.x, point.y))
    }

    public static func point(angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: radius * sin(angle), y: radius * cos(angle))
    }

    /// Maps any angle to [0, 2π).
    public static func normalized(_ angle: CGFloat) -> CGFloat {
        let full = 2 * CGFloat.pi
        let r = angle.truncatingRemainder(dividingBy: full)
        return r < 0 ? r + full : r
    }

    static func angularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let d = normalized(a - b)
        return min(d, 2 * .pi - d)
    }
}
