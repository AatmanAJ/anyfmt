// DragSense: MIT licence, see LICENSE.
import XCTest
@testable import DragSense

@MainActor
final class StateMachineTests: XCTestCase {
    func testStartsIdleAndStartInstallsWakeUpAndIdleTimer() {
        let h = Harness(start: false)
        XCTAssertEqual(h.sense.state, .idle)
        XCTAssertNil(h.sys.interval)
        h.sense.start()
        XCTAssertTrue(h.sense.isRunning)
        XCTAssertNotNil(h.sys.wakeHandler)
        XCTAssertEqual(h.sys.interval ?? 0, 0.25, accuracy: 1e-9)
        XCTAssertEqual(h.sys.leeway ?? 0, 0.25, accuracy: 1e-9, "idle timer gets generous leeway")
    }

    func testClickWithoutDragStaysIdleAndEmitsNothing() {
        let h = Harness()
        h.mouseDown()
        h.ticks(5)
        h.mouseUp()
        h.ticks(2)
        XCTAssertEqual(h.sense.state, .idle)
        XCTAssertTrue(h.events.isEmpty)
        XCTAssertTrue(h.states.isEmpty)
    }

    func testFileDragBeginsDraggingWithURLs() throws {
        let h = Harness()
        h.beginFileDrag()
        let info = try XCTUnwrap(h.dragBeganInfos.first)
        XCTAssertEqual(info.fileURLs, Harness.sampleURLs)
        XCTAssertEqual(info.changeCount, 51)
        XCTAssertEqual(info.itemCount, 2)
        XCTAssertFalse(info.isPartial)
        XCTAssertTrue(info.pasteboardTypes.contains(DragPasteboardType.fileURL))
        XCTAssertEqual(info.startLocation, CGPoint(x: 400, y: 400))
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        XCTAssertEqual(h.sense.currentDrag, info)
        XCTAssertEqual(h.states, [.dragging(dragID: 51)])
    }

    func testShiftTapOpensConvertWheelAtPointer() throws {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
        guard case .triggerTapped(let trigger, let info, let location)? = h.events.last else {
            return XCTFail("expected triggerTapped, got \(h.events)")
        }
        XCTAssertEqual(trigger, Trigger(id: "convert", key: .shift))
        XCTAssertEqual(info.fileURLs, Harness.sampleURLs)
        XCTAssertEqual(location, h.sys.location)
        XCTAssertEqual(h.states, [.dragging(dragID: 51), .wheelOpen(triggerID: "convert")])
    }

    func testWheelStaysOpenAfterKeyReleaseWhileDragging() {
        let h = Harness()
        h.openWheel()
        for _ in 0..<20 {
            h.move(7, 3)
            h.ticks(10)
        }
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }

    func testMouseUpWithWheelOpenEmitsDragEndedAndAwaitsHost() {
        let h = Harness()
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        guard case .dragEnded(let location)? = h.events.last else { return XCTFail("expected dragEnded") }
        XCTAssertEqual(location, h.sys.location)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"), "waits for the host's verdict")
    }

    func testDropAfterMouseUpGoesDroppedThenIdle() {
        let h = Harness()
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        h.clearRecords()
        h.sense.wheelDidAcceptDrop()
        XCTAssertEqual(h.states, [.dropped, .idle])
        XCTAssertEqual(h.sense.state, .idle)
        XCTAssertNil(h.sense.currentDrag)
        XCTAssertEqual(h.sys.interval ?? 0, 0.25, accuracy: 1e-9, "back to the idle rate")
    }

    func testDropBeforeMouseUpIsSeenStillWorksAndDoesNotRedetect() {
        let h = Harness()
        h.openWheel()
        // performDragOperation can arrive before our poll sees the button go up.
        h.sense.wheelDidAcceptDrop()
        XCTAssertEqual(h.sense.state, .idle)
        h.clearRecords()
        h.ticks(5) // button still reads down for a moment
        h.mouseUp()
        h.ticks(3)
        XCTAssertTrue(h.events.isEmpty, "the finished drag must not be detected again: \(h.events)")
        XCTAssertTrue(h.states.isEmpty)
        XCTAssertEqual(h.sense.state, .idle)
    }

    func testCancelAfterMouseUpGoesCancelledThenIdle() {
        let h = Harness()
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        h.clearRecords()
        h.sense.cancelWheel()
        XCTAssertEqual(h.states, [.cancelled, .idle])
    }

    func testCancelWhileButtonDownReturnsToDraggingAndRetapReopens() {
        let h = Harness()
        h.openWheel()
        h.clearRecords()
        h.sense.cancelWheel()
        XCTAssertEqual(h.states, [.cancelled, .dragging(dragID: 51)])
        h.tap(.command)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
        XCTAssertEqual(h.tappedTriggerIDs, ["tools"])
    }

    func testUnresolvedWheelAutoCancelsAfterTimeout() {
        let h = Harness(Harness.configuration { $0.dropResolutionTimeout = 0.5 })
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        h.clearRecords()
        h.run(0.45)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
        h.run(0.1)
        XCTAssertEqual(h.states, [.cancelled, .idle])
    }

    func testMouseUpWithoutWheelEndsDragToIdle() {
        let h = Harness()
        h.beginFileDrag()
        h.clearRecords()
        h.mouseUp()
        h.ticks(1)
        XCTAssertEqual(h.dragEndedCount, 1)
        XCTAssertEqual(h.states, [.idle])
        XCTAssertNil(h.sense.currentDrag)
    }

    func testDropAndCancelIgnoredWhenNoWheelIsOpen() {
        let h = Harness()
        h.beginFileDrag()
        h.clearRecords()
        h.sense.wheelDidAcceptDrop()
        h.sense.cancelWheel()
        XCTAssertTrue(h.states.isEmpty)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testMissedMouseUpRecoveryFromButtonState() {
        let h = Harness()
        h.openWheel()
        // No mouse-up event is ever delivered; only the device state changes
        // (as after Mission Control or a Space switch mid-drag).
        h.sys.buttons = 0
        h.ticks(1)
        XCTAssertEqual(h.dragEndedCount, 1)
        h.sense.cancelWheel()
        XCTAssertEqual(h.sense.state, .idle)
        // And the next drag works normally.
        h.clearRecords()
        h.openWheel(.control)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "actions"))
    }

    func testNewPressWhileAwaitingVerdictCancelsOldSessionAndTracksNewDrag() {
        let h = Harness()
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        h.clearRecords()
        h.beginFileDrag()
        XCTAssertEqual(h.states, [.cancelled, .idle, .dragging(dragID: 52)])
        XCTAssertEqual(h.dragBeganInfos.count, 1)
    }

    func testReentrantCancelFromEventHandlerKeepsOrder() {
        let h = Harness()
        h.onEvent = { [unowned h] event in
            if case .dragEnded = event { h.sense.cancelWheel() }
        }
        h.openWheel()
        h.clearRecords()
        h.mouseUp()
        h.ticks(1)
        XCTAssertEqual(h.dragEndedCount, 1)
        XCTAssertEqual(h.states, [.cancelled, .idle])
    }

    func testStopCancelsOpenWheelAndTimer() {
        let h = Harness()
        h.openWheel()
        h.clearRecords()
        h.sense.stop()
        XCTAssertEqual(h.states, [.cancelled, .idle])
        XCTAssertFalse(h.sense.isRunning)
        XCTAssertNil(h.sys.interval, "timer cancelled")
        XCTAssertNil(h.sys.wakeHandler, "monitors removed")
        let ticksBefore = h.sys.tickCount
        h.run(1)
        XCTAssertEqual(h.sys.tickCount, ticksBefore)
    }

    func testRestartAfterStopWorks() {
        let h = Harness()
        h.sense.stop()
        h.sense.start()
        h.openWheel()
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testDragAlreadyInProgressAtStartIsNotPickedUp() {
        let h = Harness(start: false)
        h.sys.buttons = 1
        h.writeFileDrag()
        h.sense.start()
        h.run(0.5)
        h.tap(.shift)
        XCTAssertTrue(h.events.isEmpty)
        XCTAssertEqual(h.sense.state, .idle)
    }
}
