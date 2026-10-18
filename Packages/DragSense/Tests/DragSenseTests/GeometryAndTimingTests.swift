// DragSense: MIT licence, see LICENSE.
import XCTest
@testable import DragSense

@MainActor
final class GeometryTests: XCTestCase {
    func testTapInTopBandDoesNotOpenWheel() {
        let h = Harness()
        h.beginFileDrag()
        h.moveTo(CGPoint(x: 700, y: 890)) // 10 pt below the top of a 900 pt screen
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        h.moveTo(CGPoint(x: 700, y: 870))
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testTopBandIsPerScreen() {
        let h = Harness()
        // A second display above the main one: its top edge is at y = 900 + 1080.
        h.sys.screenList = [
            ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), topInset: 24),
            ScreenInfo(frame: CGRect(x: 0, y: 900, width: 1920, height: 1080), topInset: 0),
        ]
        h.beginFileDrag()
        h.moveTo(CGPoint(x: 500, y: 950)) // near the bottom of the upper screen: fine
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
        h.sense.cancelWheel()
        h.moveTo(CGPoint(x: 500, y: 1970)) // top band of the upper screen
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testTopBandGrowsToMenuBarOrNotchInset() {
        let h = Harness()
        h.sys.screenList = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), topInset: 38)]
        h.beginFileDrag()
        h.moveTo(CGPoint(x: 700, y: 950)) // 32 pt from the top: inside a 38 pt notch band
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testZeroHeightDisablesTopBand() {
        let h = Harness(Harness.configuration { $0.topExclusionHeight = 0 })
        h.beginFileDrag()
        h.moveTo(CGPoint(x: 700, y: 899))
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testSwitchingIsAllowedInTopBandOnceOpen() {
        let h = Harness()
        h.openWheel()
        h.moveTo(CGPoint(x: 700, y: 895))
        h.tap(.command)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
    }
}

@MainActor
final class TimingTests: XCTestCase {
    func testPollRateSwitchesBetweenIdleAndActive() {
        let h = Harness()
        XCTAssertEqual(h.sys.interval ?? 0, 0.25, accuracy: 1e-9)
        h.mouseDown()
        XCTAssertEqual(h.sys.interval ?? 0, 0.01, accuracy: 1e-9, "mouse-down wake-up switches to the active rate at once")
        XCTAssertLessThanOrEqual(h.sys.leeway ?? 1, 0.0005)
        h.mouseUp()
        h.ticks(1)
        XCTAssertEqual(h.sys.interval ?? 0, 0.25, accuracy: 1e-9)
    }

    func testDefaultActiveRateIs240Hz() {
        let h = Harness(DragSenseConfiguration(triggers: Harness.triggers))
        h.mouseDown()
        XCTAssertEqual(h.sys.interval ?? 0, 1.0 / 240.0, accuracy: 1e-9)
    }

    func testLivePollRateChangeReschedules() {
        let h = Harness()
        h.sense.configuration.idlePollInterval = 0.5
        XCTAssertEqual(h.sys.interval ?? 0, 0.5, accuracy: 1e-9)
        h.mouseDown()
        h.sense.configuration.activePollRate = 200
        XCTAssertEqual(h.sys.interval ?? 0, 0.005, accuracy: 1e-9)
    }

    func testMouseDraggedWakeUpCoversMissedMouseDown() {
        let h = Harness()
        h.sys.buttons = 1
        h.move(10)
        h.writeFileDrag()
        h.sys.wake(.mouseDragged)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testDragMovedOnlyWhileWheelOpenAndThrottled() {
        let h = Harness(Harness.configuration { $0.dragMovedInterval = 0.05 })
        h.beginFileDrag()
        for _ in 0..<10 { h.move(5); h.ticks(1) }
        XCTAssertTrue(h.movedPoints.isEmpty, "no move events with the wheel closed")
        h.tap(.shift)
        for _ in 0..<20 { h.move(5); h.ticks(1) } // 200 ms of movement, one tick each
        XCTAssertEqual(h.movedPoints.count, 4, "one per 50 ms")
        let before = h.movedPoints.count
        h.ticks(20) // still pointer: nothing
        XCTAssertEqual(h.movedPoints.count, before)
        h.mouseUp()
        h.ticks(1)
        h.move(30)
        h.ticks(10)
        XCTAssertEqual(h.movedPoints.count, before, "no move events once the button is up")
    }

    func testIdleTimerKeepsRefreshingBaseline() {
        let h = Harness()
        h.sys.types = [DragPasteboardType.fileURL] // would count if the baseline were stale
        for _ in 0..<5 {
            h.sys.changeCount += 3
            h.run(0.25)
        }
        // A press now must compare against the latest count, not the one at start().
        h.mouseDown()
        h.move(10)
        h.ticks(5)
        XCTAssertEqual(h.sense.state, .idle)
    }
}
