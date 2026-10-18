// DragSense: MIT licence, see LICENSE.
import Combine
import XCTest
@testable import DragSense

@MainActor
final class DeliveryTests: XCTestCase {
    func testEventStreamDeliversEventsInOrder() async {
        let h = Harness()
        let stream = h.sense.events()
        h.openWheel()
        h.mouseUp()
        h.ticks(1)

        var received: [DragSenseEvent] = []
        for await event in stream {
            received.append(event)
            if received.count == 3 { break }
        }
        XCTAssertEqual(received, h.events)
        guard case .dragBegan = received[0], case .triggerTapped = received[1], case .dragEnded = received[2] else {
            return XCTFail("unexpected order: \(received)")
        }
    }

    func testStateStreamStartsWithCurrentStateAndFollowsTransitions() async {
        let h = Harness()
        let stream = h.sense.stateUpdates()
        h.openWheel()
        h.sense.cancelWheel()

        var received: [DragSenseState] = []
        for await state in stream {
            received.append(state)
            if received.count == 5 { break }
        }
        XCTAssertEqual(received, [.idle, .dragging(dragID: 51), .wheelOpen(triggerID: "convert"), .cancelled, .dragging(dragID: 51)])
    }

    func testStateIsPublishedThroughCombine() {
        let h = Harness()
        var seen: [DragSenseState] = []
        let cancellable = h.sense.$state.sink { seen.append($0) }
        h.openWheel()
        cancellable.cancel()
        XCTAssertEqual(seen, [.idle, .dragging(dragID: 51), .wheelOpen(triggerID: "convert")])
    }

    func testStatePropertyMatchesEachCallbackAsItIsDelivered() {
        let h = Harness()
        var mismatches = 0
        h.sense.onStateChange = { [unowned h] state in
            if h.sense.state != state { mismatches += 1 }
        }
        h.openWheel()
        h.mouseUp()
        h.ticks(1)
        h.sense.wheelDidAcceptDrop()
        XCTAssertEqual(mismatches, 0)
    }

    func testStateDuringDragEndedWithoutWheelIsStillDragging() {
        let h = Harness()
        var stateAtDragEnded: DragSenseState?
        h.onEvent = { [unowned h] event in
            if case .dragEnded = event { stateAtDragEnded = h.sense.state }
        }
        h.beginFileDrag()
        h.mouseUp()
        h.ticks(1)
        XCTAssertEqual(stateAtDragEnded, .dragging(dragID: 51))
        XCTAssertEqual(h.sense.state, .idle)
    }
}

@MainActor
final class DiagnosticsTests: XCTestCase {
    func testLatencyProbeMeasuresFromEarliestReleaseToVisible() throws {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift)
        // Released at most one tick (10 ms) before detection; the wheel takes 12 ms more.
        h.run(0.012)
        h.sense.markWheelVisible()
        let sample = try XCTUnwrap(h.sense.diagnostics.latencySamples.last)
        XCTAssertEqual(sample, 0.022, accuracy: 1e-6)
        h.sense.markWheelVisible() // extra calls are ignored
        XCTAssertEqual(h.sense.diagnostics.latencySamples.count, 1)
    }

    func testSwitchesAreNotMeasuredAndCancelDropsPendingProbe() {
        let h = Harness()
        h.openWheel()
        h.sense.markWheelVisible()
        h.tap(.command) // switch
        h.sense.markWheelVisible()
        XCTAssertEqual(h.sense.diagnostics.latencySamples.count, 1)

        h.sense.cancelWheel()
        h.tap(.shift) // reopen, but cancel before it's shown
        h.sense.cancelWheel()
        h.sense.markWheelVisible()
        XCTAssertEqual(h.sense.diagnostics.latencySamples.count, 1)
    }

    func testLatencySummaryPercentiles() throws {
        let samples = (1...100).map { Double($0) / 1000 }
        let summary = try XCTUnwrap(LatencySummary(samples: samples))
        XCTAssertEqual(summary.count, 100)
        XCTAssertEqual(summary.p50, 0.050, accuracy: 1e-12)
        XCTAssertEqual(summary.p95, 0.095, accuracy: 1e-12)
        XCTAssertEqual(summary.max, 0.100, accuracy: 1e-12)
        XCTAssertEqual(summary.mean, 0.0505, accuracy: 1e-12)
        XCTAssertNil(LatencySummary(samples: []))
    }

    func testLatencyCallbackAndReset() {
        let h = Harness()
        var reported: [TimeInterval] = []
        h.sense.diagnostics.onLatencySample = { reported.append($0) }
        h.openWheel()
        h.sense.markWheelVisible()
        XCTAssertEqual(reported.count, 1)
        XCTAssertNotNil(h.sense.diagnostics.latencySummary())
        h.sense.diagnostics.resetLatencySamples()
        XCTAssertNil(h.sense.diagnostics.latencySummary())
    }

    func testVerboseLoggingDoesNotChangeBehaviour() {
        let h = Harness()
        h.sense.diagnostics.isVerbose = true
        h.openWheel()
        h.tap(.option)
        h.moveTo(CGPoint(x: 10, y: 899))
        h.tap(.command)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
    }
}
