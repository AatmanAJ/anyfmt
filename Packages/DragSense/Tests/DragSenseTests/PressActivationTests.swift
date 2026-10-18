// DragSense: MIT licence, see LICENSE.
import AppKit
import XCTest
@testable import DragSense

/// `.press` activation (the default): the wheel opens when a trigger key goes
/// down mid-drag, so tapping and holding both work.
@MainActor
final class PressActivationTests: XCTestCase {
    private func harness() -> Harness {
        Harness(Harness.configuration { $0.activation = .press })
    }

    func testDefaultIsPress() {
        XCTAssertEqual(DragSenseConfiguration().activation, .press)
    }

    func testKeyDownOpensImmediately() {
        let h = harness()
        h.beginFileDrag()
        h.press(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"], "opens on key-down, no release needed")
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testHoldKeepsWheelOpenAndReleaseDoesNotRefire() {
        let h = harness()
        h.beginFileDrag()
        h.press(.command)
        h.ticks(80) // held 800 ms
        h.release(.command)
        h.ticks(5)
        XCTAssertEqual(h.tappedTriggerIDs, ["tools"])
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
    }

    func testQuickTapStillWorks() {
        let h = harness()
        h.beginFileDrag()
        h.tap(.control, ticksHeld: 5)
        XCTAssertEqual(h.tappedTriggerIDs, ["actions"])
    }

    func testPressingAnotherTriggerSwitches() {
        let h = harness()
        h.beginFileDrag()
        h.press(.shift)
        h.press(.command) // held together: the newest key wins
        XCTAssertEqual(h.tappedTriggerIDs, ["convert", "tools"])
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
    }

    func testKeyHeldBeforeTheDragNeverFires() {
        let h = harness()
        // Finder ⌘-drag (move): ⌘ is down before the drag starts.
        h.sys.flags = .command
        h.beginFileDrag()
        h.ticks(20)
        h.release(.command)
        h.ticks(5)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testKeyDownBeforeTheDragIsDetectedOpensOnceDetected() {
        let h = harness()
        h.mouseDown()
        h.press(.shift) // pressed after mouse-down but before the drag pasteboard changed
        h.move(10)
        h.writeFileDrag()
        h.ticks(5)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"],
                       "a key pressed as the drag starts opens the wheel once the drag is recognised, exactly once")
    }

    func testUnboundModifierIsIgnored() {
        let h = harness()
        h.beginFileDrag()
        h.press(.option)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testActivationRoundTripsThroughCodable() throws {
        var c = DragSenseConfiguration()
        c.activation = .tap
        let decoded = try JSONDecoder().decode(DragSenseConfiguration.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(decoded.activation, .tap)
        let legacy = try JSONDecoder().decode(DragSenseConfiguration.self, from: Data("{}".utf8))
        XCTAssertEqual(legacy.activation, .press, "settings saved before this field default to press")
    }
}
