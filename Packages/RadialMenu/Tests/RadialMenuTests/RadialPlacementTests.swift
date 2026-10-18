import CoreGraphics
import XCTest
@testable import RadialMenu

final class RadialPlacementTests: XCTestCase {
    // A 1512×982 laptop screen with a 37 pt menu bar and a Dock at the bottom.
    private let laptop = RadialScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                      visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875), backingScale: 2)
    private let radius: CGFloat = 129
    private let inset: CGFloat = 8
    private let band: CGFloat = 24

    private func center(_ p: CGPoint, screens: [RadialScreen]? = nil) -> CGPoint {
        RadialPlacement.center(for: p, radius: radius, screens: screens ?? [laptop], edgeInset: inset, topExclusion: band)
    }

    private func assertFits(_ c: CGPoint, on screen: RadialScreen, file: StaticString = #filePath, line: UInt = #line) {
        let allowed = RadialPlacement.allowedRect(on: screen, edgeInset: inset, topExclusion: band)
        XCTAssertGreaterThanOrEqual(c.x - radius, allowed.minX - 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(c.x + radius, allowed.maxX + 0.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(c.y - radius, allowed.minY - 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(c.y + radius, allowed.maxY + 0.5, file: file, line: line)
    }

    func testCentredOnPointWhenItFits() {
        let p = CGPoint(x: 700, y: 500)
        XCTAssertEqual(center(p), p)
    }

    func testPushedInwardAtEveryEdgeAndCorner() {
        let f = laptop.frame
        let points: [CGPoint] = [
            CGPoint(x: f.minX + 2, y: f.midY), CGPoint(x: f.maxX - 2, y: f.midY),
            CGPoint(x: f.midX, y: f.minY + 2), CGPoint(x: f.midX, y: f.maxY - 2),
            CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY),
            CGPoint(x: f.minX, y: f.maxY), CGPoint(x: f.maxX, y: f.maxY),
        ]
        for p in points {
            let c = center(p)
            assertFits(c, on: laptop)
            // Only the axis that would clip moves.
            if p.y == f.midY { XCTAssertEqual(c.y, p.y, "y untouched for side edges") }
            if p.x == f.midX { XCTAssertEqual(c.x, p.x, "x untouched for top/bottom edges") }
        }
    }

    func testTopRespectsMenuBarAndExclusionBand() {
        let c = center(CGPoint(x: 700, y: 975))
        XCTAssertEqual(c.y + radius, laptop.visibleFrame.maxY - inset, accuracy: 0.5)
        // Auto-hidden menu bar: the exclusion band still applies.
        let full = RadialScreen(frame: laptop.frame, visibleFrame: laptop.frame, backingScale: 2)
        let c2 = center(CGPoint(x: 700, y: 980), screens: [full])
        XCTAssertEqual(c2.y + radius, full.frame.maxY - band - inset, accuracy: 0.5)
    }

    func testBottomMayOverlapTheDock() {
        // Only the physical edge limits the bottom (the wheel floats above the Dock).
        let c = center(CGPoint(x: 700, y: 60))
        XCTAssertEqual(c.y - radius, laptop.frame.minY + inset, accuracy: 0.5)
    }

    func testMultiDisplayUsesThePointersScreen() {
        let right = RadialScreen(frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440), backingScale: 1)
        let left = RadialScreen(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), backingScale: 1)
        let above = RadialScreen(frame: CGRect(x: 0, y: 982, width: 1512, height: 982), backingScale: 2)
        let screens = [laptop, right, left, above]
        // Near the inner edge of the right display: pushed right, not left onto the laptop.
        let a = center(CGPoint(x: 1515, y: 300), screens: screens)
        XCTAssertGreaterThanOrEqual(a.x - radius, right.frame.minX + inset - 0.5)
        assertFits(a, on: right)
        // Left display has negative coordinates.
        let b = center(CGPoint(x: -1918, y: 1078), screens: screens)
        assertFits(b, on: left)
        // A display stacked above.
        let c = center(CGPoint(x: 20, y: 990), screens: screens)
        assertFits(c, on: above)
        XCTAssertEqual(RadialPlacement.screen(for: CGPoint(x: 2000, y: 0), in: screens), right)
    }

    func testPointOffEveryScreenUsesNearest() {
        let right = RadialScreen(frame: CGRect(x: 1512, y: 0, width: 1000, height: 800))
        let screens = [laptop, right]
        XCTAssertEqual(RadialPlacement.screen(for: CGPoint(x: 3000, y: 100), in: screens), right)
        assertFits(center(CGPoint(x: 3000, y: 100), screens: screens), on: right)
    }

    func testScreenSmallerThanWheelCentres() {
        let tiny = RadialScreen(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let c = center(CGPoint(x: 10, y: 10), screens: [tiny])
        let allowed = RadialPlacement.allowedRect(on: tiny, edgeInset: inset, topExclusion: band)
        XCTAssertEqual(c.x, allowed.midX, accuracy: 0.5)
        XCTAssertEqual(c.y, allowed.midY, accuracy: 0.5)
    }

    func testSnapsToBackingPixels() {
        let c = center(CGPoint(x: 700.3, y: 500.8))
        XCTAssertEqual(c.x * 2, (c.x * 2).rounded())
        XCTAssertEqual(c.y * 2, (c.y * 2).rounded())
        let oneX = RadialScreen(frame: laptop.frame, visibleFrame: laptop.visibleFrame, backingScale: 1)
        let d = center(CGPoint(x: 700.3, y: 500.8), screens: [oneX])
        XCTAssertEqual(d.x, d.x.rounded())
    }

    func testNoScreensReturnsThePoint() {
        let p = CGPoint(x: 5, y: 5)
        XCTAssertEqual(RadialPlacement.center(for: p, radius: 100, screens: []), p)
    }

    func testFrameIsCentred() {
        let f = RadialPlacement.frame(side: 446, centeredAt: CGPoint(x: 100, y: 200))
        XCTAssertEqual(f.midX, 100)
        XCTAssertEqual(f.midY, 200)
        XCTAssertEqual(f.width, 446)
    }
}
