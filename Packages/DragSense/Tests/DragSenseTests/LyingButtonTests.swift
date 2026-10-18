import AppKit
import XCTest
@testable import DragSense

/// Real hardware (2026-10-18): dragging out of Photos or Mail, the session's
/// button state read "up" within a second while the button was still held, so
/// every such drag ended before a wheel could open. Movement keeps a drag alive.
@MainActor
final class LyingButtonTests: XCTestCase {
    private func ended(_ h: Harness) -> Bool { h.dragEndedCount > 0 }

    func testMovementKeepsTheDragAliveWhileTheButtonReadsUp() {
        let h = Harness(Harness.configuration { $0.activation = .press })
        h.beginFileDrag()
        h.sys.buttons = 0 // the source app makes the reading lie
        for _ in 0..<20 { // 200 ms of movement
            h.move(3)
            h.sys.wake(.mouseDragged)
            h.ticks(1)
        }
        XCTAssertFalse(ended(h), "still dragging")
        h.press(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"], "the wheel can still open")
    }

    func testStillnessAfterAReleaseEndsTheDrag() {
        let h = Harness(Harness.configuration { $0.activation = .press })
        h.beginFileDrag()
        h.move(3)
        h.sys.wake(.mouseDragged)
        h.mouseUp()
        h.ticks(5) // 50 ms: inside the movement grace
        XCTAssertFalse(ended(h))
        h.run(DragSense.dragMovementGrace + 0.05)
        XCTAssertTrue(ended(h), "a real release ends the drag once movement stops")
    }

    func testOutsideADragMovementDoesNotHoldAnything() {
        let h = Harness()
        h.sys.wake(.mouseDragged)
        h.ticks(2)
        XCTAssertTrue(h.dragBeganInfos.isEmpty)
        XCTAssertEqual(h.sense.state, .idle)
    }
}
