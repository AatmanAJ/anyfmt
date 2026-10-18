import AppKit
import XCTest
@testable import DragSense

/// ⌥ tap while the wheel is open = lock the highlighted segment (PLAN-PHASE2 §B).
@MainActor
final class LockKeyTests: XCTestCase {
    private var lockEvents: (Harness) -> Int = { h in
        h.events.filter { if case .lockKeyTapped = $0 { return true } else { return false } }.count
    }

    func testOptionTapWithWheelOpenReportsLock() {
        let h = Harness(Harness.configuration { $0.activation = .press })
        h.beginFileDrag()
        h.press(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
        h.release(.shift)
        h.tap(.option, ticksHeld: 5)
        XCTAssertEqual(lockEvents(h), 1)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"], "⌥ never opens or switches a wheel")
        h.tap(.option, ticksHeld: 5)
        XCTAssertEqual(lockEvents(h), 2, "second tap toggles back (host side)")
    }

    func testOptionTapWithoutWheelIsIgnored() {
        let h = Harness(Harness.configuration { $0.activation = .press })
        h.beginFileDrag()
        h.tap(.option, ticksHeld: 5)
        XCTAssertEqual(lockEvents(h), 0)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testHoldingOptionIsNotALockTap() {
        let h = Harness(Harness.configuration { $0.activation = .press })
        h.openWheel()
        h.press(.option)
        h.ticks(80) // 0.8 s: a hold, e.g. ⌥ held for the drop
        h.release(.option)
        XCTAssertEqual(lockEvents(h), 0)
    }

    func testLockKeyThatIsATriggerStaysATrigger() {
        let h = Harness(Harness.configuration {
            $0.activation = .press
            $0.triggers = [Trigger(id: "convert", key: .option)]
        })
        h.beginFileDrag()
        h.press(.option)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
        h.release(.option)
        XCTAssertEqual(lockEvents(h), 0)
    }

    func testTapModeReportsLockToo() {
        let h = Harness()
        h.openWheel()
        h.tap(.option, ticksHeld: 5)
        XCTAssertEqual(lockEvents(h), 1)
    }

    func testDisabledLockKey() {
        let h = Harness(Harness.configuration { $0.lockKey = nil })
        h.openWheel()
        h.tap(.option, ticksHeld: 5)
        XCTAssertEqual(lockEvents(h), 0)
    }

    func testConfigurationCodingKeepsLockKey() throws {
        var c = DragSenseConfiguration.default
        c.lockKey = .control
        let back = try JSONDecoder().decode(DragSenseConfiguration.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(back.lockKey, .control)
        c.lockKey = nil
        let none = try JSONDecoder().decode(DragSenseConfiguration.self, from: JSONEncoder().encode(c))
        XCTAssertNil(none.lockKey, "an explicit nil survives")
        let old = try JSONDecoder().decode(DragSenseConfiguration.self, from: Data("{}".utf8))
        XCTAssertEqual(old.lockKey, .option, "old saved settings get the default")
    }
}
