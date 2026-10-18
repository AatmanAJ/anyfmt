import CoreGraphics
import XCTest
@testable import RadialMenu

final class RadialLayoutTests: XCTestCase {
    private let config = RadialMenuConfiguration()
    private let full = 2 * CGFloat.pi

    private func point(deg: CGFloat, r: CGFloat) -> CGPoint {
        RadialLayout.point(angle: deg * .pi / 180, radius: r)
    }

    // MARK: Ring split and angles

    func testEmptyLayoutHasNoSlots() {
        let layout = RadialLayout(itemCount: 0, configuration: config)
        XCTAssertTrue(layout.slots.isEmpty)
        XCTAssertEqual(layout.pageCount, 1)
    }

    func testSingleRingAnglesForOneToEight() {
        for n in 1...8 {
            let layout = RadialLayout(itemCount: n, configuration: config)
            XCTAssertEqual(layout.slots.count, n, "n=\(n)")
            XCTAssertFalse(layout.hasOuterRing)
            XCTAssertEqual(layout.innerCount, n)
            let span = full / CGFloat(n)
            for (i, slot) in layout.slots.enumerated() {
                XCTAssertEqual(slot.ring, 0)
                XCTAssertEqual(slot.itemIndex, i)
                XCTAssertEqual(slot.span, span, accuracy: 1e-9, "n=\(n) i=\(i)")
                XCTAssertEqual(slot.midAngle, CGFloat(i) * span, accuracy: 1e-9, "item \(i) centred clockwise from 12")
                if i > 0 { XCTAssertEqual(slot.startAngle, layout.slots[i - 1].endAngle, accuracy: 1e-9, "contiguous") }
            }
            XCTAssertEqual(layout.slots[0].midAngle, 0, accuracy: 1e-9, "first item at 12 o'clock")
            XCTAssertEqual(layout.outerRadius, config.innerRing.outer)
        }
    }

    func testSecondRingForNineToTwenty() {
        for n in 9...20 {
            let layout = RadialLayout(itemCount: n, configuration: config)
            XCTAssertEqual(layout.innerCount, 8, "n=\(n)")
            XCTAssertEqual(layout.outerCount, n - 8, "n=\(n)")
            XCTAssertEqual(layout.pageCount, 1)
            XCTAssertTrue(layout.hasOuterRing)
            XCTAssertEqual(layout.outerRadius, config.outerRing.outer)
            let outer = layout.slots.filter { $0.ring == 1 }
            XCTAssertEqual(outer.count, n - 8)
            for slot in outer {
                XCTAssertEqual(slot.span, full / 12, accuracy: 1e-9, "fixed-width outer wedges")
                XCTAssertEqual(slot.band, config.outerRing)
            }
            // The outer arc is centred on 12 o'clock.
            let first = outer[0].startAngle, last = outer[outer.count - 1].endAngle
            XCTAssertEqual(first, -last, accuracy: 1e-9, "n=\(n)")
            // Items keep their order: inner 0…7, then outer clockwise.
            XCTAssertEqual(layout.slots.compactMap(\.itemIndex), Array(0..<n))
        }
    }

    func testPaginationBeyondTwenty() {
        for n in 21...24 {
            let layout = RadialLayout(itemCount: n, configuration: config)
            XCTAssertTrue(layout.isPaginated, "n=\(n)")
            XCTAssertEqual(layout.pageCount, Int(ceil(Double(n - 8) / 11)))
            XCTAssertEqual(layout.outerCount, 11)
            XCTAssertEqual(layout.slots.filter(\.isPager).count, 1)
            let pager = layout.slots.first(where: \.isPager)
            XCTAssertEqual(pager?.ring, 1)
            XCTAssertEqual(pager?.midAngle ?? 0, 11 * full / 12, accuracy: 1e-9, "pager at 11 o'clock")
        }
        let page1 = RadialLayout(itemCount: 24, configuration: config, page: 1)
        XCTAssertEqual(page1.page, 1)
        XCTAssertEqual(page1.outerCount, 24 - 8 - 11)
        XCTAssertEqual(page1.slots.compactMap(\.itemIndex).filter { $0 >= 8 }, Array(19..<24))
        // Pages wrap both ways.
        XCTAssertEqual(RadialLayout(itemCount: 24, configuration: config, page: 2).page, 0)
        XCTAssertEqual(RadialLayout(itemCount: 24, configuration: config, page: -1).page, 1)
        XCTAssertEqual(page1.page(containing: 3), 0)
        XCTAssertEqual(page1.page(containing: 18), 0)
        XCTAssertEqual(page1.page(containing: 19), 1)
    }

    func testEveryItemIsReachableOnSomePage() {
        for n in 1...60 {
            let first = RadialLayout(itemCount: n, configuration: config)
            var seen = Set<Int>()
            for p in 0..<first.pageCount {
                seen.formUnion(RadialLayout(itemCount: n, configuration: config, page: p).slots.compactMap(\.itemIndex))
            }
            XCTAssertEqual(seen, Set(0..<n), "n=\(n)")
        }
    }

    // MARK: Hit testing

    func testAngularHitTestingCoversWholeWedge() {
        let layout = RadialLayout(itemCount: 8, configuration: config)
        // Middle of the band, 1° either side of each boundary.
        for i in 0..<8 {
            let mid = CGFloat(i) * 45
            XCTAssertEqual(layout.hitTest(point(deg: mid, r: 88)), .slot(i))
            XCTAssertEqual(layout.hitTest(point(deg: mid + 21, r: 60)), .slot(i), "near the gap, near the hub")
            XCTAssertEqual(layout.hitTest(point(deg: mid - 21, r: 130)), .slot(i), "slight overshoot still hits")
        }
        // Between the dead zone and the ring the wedge still wins (generous targeting).
        XCTAssertEqual(layout.hitTest(point(deg: 90, r: 45)), .slot(2))
    }

    func testWrapAroundAtTwelveOClock() {
        let layout = RadialLayout(itemCount: 8, configuration: config)
        XCTAssertEqual(layout.hitTest(point(deg: 359, r: 90)), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: 1, r: 90)), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: -22, r: 90)), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: -23, r: 90)), .slot(7))
        XCTAssertEqual(layout.hitTest(point(deg: 23, r: 90)), .slot(1))
        let five = RadialLayout(itemCount: 5, configuration: config)
        XCTAssertEqual(five.hitTest(point(deg: 325, r: 90)), .slot(0))
        XCTAssertEqual(five.hitTest(point(deg: 323, r: 90)), .slot(4))
    }

    func testDeadZoneAndOutside() {
        let layout = RadialLayout(itemCount: 6, configuration: config)
        XCTAssertEqual(layout.hitTest(.zero), .deadZone)
        XCTAssertEqual(layout.hitTest(point(deg: 10, r: config.deadZoneRadius - 0.5)), .deadZone)
        XCTAssertEqual(layout.hitTest(point(deg: 10, r: config.deadZoneRadius + 0.5)), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: 10, r: config.innerRing.outer + config.outerTolerance + 1)), .outside)
        let empty = RadialLayout(itemCount: 0, configuration: config)
        XCTAssertEqual(empty.hitTest(point(deg: 0, r: 80)), .deadZone)
        XCTAssertEqual(empty.hitTest(point(deg: 0, r: 400)), .outside)
    }

    func testRingChosenByRadiusWithInnerFallbackUnderPartialArc() {
        let layout = RadialLayout(itemCount: 12, configuration: config) // 4 outer items around 12 o'clock
        guard case .slot(let top) = layout.hitTest(point(deg: 5, r: 160)) else { return XCTFail("expected a slot") }
        XCTAssertEqual(layout.slots[top].ring, 1)
        XCTAssertEqual(layout.slots[top].itemIndex, 10)
        // Bottom of the outer band has no outer slot: the inner wedge below wins.
        guard case .slot(let bottom) = layout.hitTest(point(deg: 180, r: 160)) else { return XCTFail("expected a slot") }
        XCTAssertEqual(layout.slots[bottom].ring, 0)
        XCTAssertEqual(layout.slots[bottom].itemIndex, 4)
        // Overshoot beyond the outer ring keeps the outer target.
        XCTAssertEqual(layout.hitTest(point(deg: 5, r: config.outerRing.outer + 10)), .slot(top))
        XCTAssertEqual(layout.hitTest(point(deg: 5, r: config.outerRing.outer + config.outerTolerance + 2)), .outside)
    }

    func testHysteresisKeepsCurrentNearEdges() {
        let layout = RadialLayout(itemCount: 8, configuration: config)
        // Slot 0 spans ±22.5°. 23° is in slot 1, but while slot 0 is hovered it's
        // sticky: max(30 % of 45°, 10°) = 13.5° past the edge, so up to 36°.
        XCTAssertEqual(layout.hitTest(point(deg: 23, r: 90)), .slot(1))
        XCTAssertEqual(layout.hitTest(point(deg: 23, r: 90), current: 0), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: 35, r: 90), current: 0), .slot(0))
        XCTAssertEqual(layout.hitTest(point(deg: 37, r: 90), current: 0), .slot(1))
        XCTAssertEqual(layout.hitTest(point(deg: -35, r: 90), current: 0), .slot(0), "both edges")
        // Radial hysteresis between rings.
        let two = RadialLayout(itemCount: 16, configuration: config)
        let boundary = (config.innerRing.outer + config.outerRing.inner) / 2
        guard case .slot(let outer) = two.hitTest(point(deg: 0, r: boundary + 1)) else { return XCTFail("slot") }
        XCTAssertEqual(two.slots[outer].ring, 1)
        XCTAssertEqual(two.hitTest(point(deg: 0, r: boundary - 1), current: outer), .slot(outer))
        XCTAssertEqual(two.hitTest(point(deg: 0, r: boundary - 5), current: outer), .slot(outer), "±6 pt ring slack")
        guard case .slot(let inner) = two.hitTest(point(deg: 0, r: boundary - 7), current: outer) else { return XCTFail("slot") }
        XCTAssertEqual(two.slots[inner].ring, 0)
    }

    func testStickySlackRule() {
        let eight = RadialLayout(itemCount: 8, configuration: config)
        XCTAssertEqual(eight.stickySlack(for: eight.slots[0]) * 180 / .pi, 13.5, accuracy: 0.01, "30 % of a 45° wedge")
        var small = config
        small.maxPerInnerRing = 8
        let twenty = RadialLayout(itemCount: 20, configuration: small)
        for slot in twenty.slots {
            let slack = twenty.stickySlack(for: slot)
            XCTAssertGreaterThanOrEqual(slack * 180 / .pi, min(10, 0.45 * slot.span * 180 / .pi) - 0.001, "10° floor")
            XCTAssertLessThanOrEqual(slack, 0.45 * slot.span + 1e-9, "neighbours stay reachable")
        }
    }

    func testAngleHelpers() {
        XCTAssertEqual(RadialLayout.clockAngle(of: CGPoint(x: 0, y: 1)), 0, accuracy: 1e-9)
        XCTAssertEqual(RadialLayout.clockAngle(of: CGPoint(x: 1, y: 0)), .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(RadialLayout.clockAngle(of: CGPoint(x: 0, y: -1)), .pi, accuracy: 1e-9)
        XCTAssertEqual(RadialLayout.clockAngle(of: CGPoint(x: -1, y: 0)), 3 * .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(RadialLayout.normalized(-0.5), full - 0.5, accuracy: 1e-9)
        XCTAssertEqual(RadialLayout.normalized(full + 0.25), 0.25, accuracy: 1e-9)
    }

    // MARK: Keyboard order

    func testKeyboardStepWrapsInAngularOrder() {
        let layout = RadialLayout(itemCount: 5, configuration: config)
        XCTAssertEqual(layout.step(from: nil, by: 1), 0)
        XCTAssertEqual(layout.step(from: nil, by: -1), 4)
        XCTAssertEqual(layout.step(from: 0, by: 1), 1)
        XCTAssertEqual(layout.step(from: 4, by: 1), 0)
        XCTAssertEqual(layout.step(from: 0, by: -1), 4)
        // Slot order is clockwise: mid angles strictly increase on each ring.
        let big = RadialLayout(itemCount: 20, configuration: config)
        for ring in 0...1 {
            let mids = big.slots.filter { $0.ring == ring }.map(\.midAngle)
            XCTAssertEqual(mids, mids.sorted(), "ring \(ring)")
        }
    }

    func testAcrossRingPicksNearestAngle() {
        let layout = RadialLayout(itemCount: 20, configuration: config)
        // Inner slot 2 (90°) ↔ outer slot nearest 90°.
        guard let outer = layout.acrossRing(from: 2) else { return XCTFail("nil") }
        XCTAssertEqual(layout.slots[outer].ring, 1)
        XCTAssertEqual(layout.slots[outer].midAngle, .pi / 2, accuracy: 0.3)
        XCTAssertEqual(layout.acrossRing(from: outer), 2)
        let single = RadialLayout(itemCount: 4, configuration: config)
        XCTAssertEqual(single.acrossRing(from: 1), 1, "one ring: stays")
    }

    // MARK: Geometry

    func testWedgePathsShareOneStructureSoTheyMorph() {
        func elements(_ path: CGPath) -> [CGPathElementType] {
            var out: [CGPathElementType] = []
            path.applyWithBlock { out.append($0.pointee.type) }
            return out
        }
        let specs = [
            WedgePath.Spec(start: 0, end: .pi / 4, inner: 52, outer: 124, gap: 3, corner: 8),
            WedgePath.Spec(start: -1, end: 2, inner: 130, outer: 192, gap: 3, corner: 8),
            WedgePath.Spec(start: 0.3, end: 0.3, inner: 52, outer: 124, gap: 3, corner: 8),   // sliver
            WedgePath.Spec(start: -.pi, end: .pi, inner: 52, outer: 124, gap: 0, corner: 0),  // full ring
            WedgePath.Spec(start: 0, end: 0.05, inner: 52, outer: 124, gap: 3, corner: 8),    // degenerate
        ]
        let reference = elements(WedgePath.path(specs[0], center: .zero))
        for s in specs {
            let p = WedgePath.path(s, center: CGPoint(x: 10, y: 10))
            XCTAssertEqual(elements(p), reference)
            XCTAssertFalse(p.boundingBoxOfPath.isNull)
        }
    }

    func testWedgeStaysInsideItsBand() {
        let spec = WedgePath.Spec(start: 0, end: .pi / 4, inner: 52, outer: 124, gap: 3, corner: 8)
        let box = WedgePath.path(spec, center: .zero).boundingBoxOfPath
        XCTAssertLessThanOrEqual(box.maxY, 124.5)
        XCTAssertGreaterThanOrEqual(box.minX, 0) // first wedge sits right of 12 o'clock (gap)
    }

    func testOpenAnimationFitsTheBudget() {
        for n in 1...24 {
            let t = config.openTiming(segmentCount: n)
            let total = t.stagger * Double(n - 1) + t.segment
            XCTAssertLessThanOrEqual(total, config.openDuration + 1e-9, "n=\(n)")
            XCTAssertLessThan(total, 0.18)
            XCTAssertGreaterThan(t.segment, 0.05)
        }
        XCTAssertEqual(config.openTiming(segmentCount: 8).stagger, 0.008, accuracy: 1e-9)
    }

    func testSpringParametersMatchResponseAndDamping() {
        // ω = 2π / response; stiffness = ω², damping = 2ζω (mass 1).
        let omega = 2 * Double.pi / config.springResponse
        XCTAssertEqual(Double(config.springStiffness), omega * omega, accuracy: 1e-6)
        XCTAssertEqual(Double(config.springDampingCoefficient), 2 * config.springDamping * omega, accuracy: 1e-6)
    }
}
