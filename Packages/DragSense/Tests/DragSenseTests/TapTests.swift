// DragSense: MIT licence, see LICENSE.
import AppKit
import XCTest
@testable import DragSense

/// Tap vs hold vs chord, thresholds, remapping and switching, end to end.
@MainActor
final class TapTests: XCTestCase {
    func testHoldDoesNotOpenWheel() {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift, ticksHeld: 60) // 600 ms
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testChordDoesNotOpenWheel() {
        let h = Harness()
        h.beginFileDrag()
        h.press(.shift)
        h.press(.command)
        h.release(.command)
        h.release(.shift)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testFinderCommandHeldFromBeforeTheDragIsNeverATap() {
        let h = Harness()
        // ⌘ held before the mouse goes down (a Finder move-drag), released mid-drag.
        h.sys.flags = .command
        h.beginFileDrag()
        h.ticks(5)
        h.release(.command)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testShiftTappedWhileCommandHeldIsAChord() {
        let h = Harness()
        h.beginFileDrag()
        h.press(.command) // Finder: switch to move
        h.ticks(30)
        h.tap(.shift, ticksHeld: 5)
        h.ticks(30)
        h.release(.command)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty, "neither key may fire: \(h.tappedTriggerIDs)")
    }

    func testUnboundModifierJoiningSpoilsTap() {
        let h = Harness()
        h.beginFileDrag()
        h.press(.shift)
        h.press(.option) // not a trigger, but it still makes this a chord
        h.release(.option)
        h.release(.shift)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testTwoKeysFirstSeenInTheSameSampleAreAChord() {
        let h = Harness()
        h.beginFileDrag()
        h.sys.flags = [.shift, .control]
        h.ticks(3)
        h.sys.flags = []
        h.ticks(1)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testSequentialTapsOpenThenSwitch() {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift)
        h.ticks(5)
        h.tap(.command)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert", "tools"])
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "tools"))
    }

    func testUnboundTapDoesNothing() {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.option)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testTapBeforeDragIsDetectedDoesNotCount() {
        let h = Harness()
        h.mouseDown()
        h.tap(.shift) // no drag yet: just a click with a tap
        h.move(10)
        h.writeFileDrag()
        h.ticks(2)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testPressBeforeDetectionReleaseAfterCountsAsTap() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.press(.shift)
        h.writeFileDrag()
        h.ticks(3)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        h.release(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }

    // MARK: Thresholds

    func testTapExactlyAtThresholdCounts() {
        let h = Harness() // threshold 0.35 s = 35 ticks of 10 ms
        h.beginFileDrag()
        h.tap(.shift, ticksHeld: 35)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }

    func testTapJustOverThresholdIsAHold() {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift, ticksHeld: 36)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testOneTickTapIsDetected() {
        let h = Harness()
        h.beginFileDrag()
        h.tap(.shift, ticksHeld: 1)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }

    func testTapEntirelyBetweenTwoSamplesIsInvisible() {
        // Documented limit: a press and release that both land between two
        // polls can't be seen. At 240 Hz that needs a tap under ~4 ms.
        let h = Harness()
        h.beginFileDrag()
        h.sys.flags = .shift
        h.run(h.tick * 0.3)
        h.sys.flags = []
        h.ticks(2)
        XCTAssertTrue(h.tappedTriggerIDs.isEmpty)
    }

    func testLiveThresholdChangeAppliesToNextRelease() {
        let h = Harness()
        h.beginFileDrag()
        h.press(.shift)
        h.ticks(49)
        h.sense.configuration.tapThreshold = 0.6
        h.release(.shift) // held 500 ms: a hold at 0.35, a tap at 0.6
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }

    func testPollKeepsRunningWhilePointerIsStill() {
        let h = Harness()
        h.beginFileDrag()
        let ticksBefore = h.sys.tickCount
        h.run(2) // no movement, no events at all
        XCTAssertGreaterThanOrEqual(h.sys.tickCount - ticksBefore, 199)
        h.tap(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"], "a tap with a motionless pointer is still seen")
    }

    // MARK: Remapping and switching

    func testRemapTriggersLive() {
        let h = Harness()
        h.beginFileDrag()
        h.sense.configuration.triggers = [Trigger(id: "convert", key: .option), Trigger(id: "tools", key: .shift)]
        h.tap(.option)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
        h.tap(.shift)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert", "tools"])
        h.tap(.command)
        XCTAssertEqual(h.tappedTriggerIDs, ["convert", "tools"], "⌘ is no longer bound")
    }

    func testSwitchingTriggersWhileOpenEmitsNewTriggerAndKeepsSession() throws {
        let h = Harness()
        h.openWheel()
        h.tap(.control)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "actions"))
        XCTAssertEqual(h.tappedTriggerIDs, ["convert", "actions"])
        guard case .triggerTapped(_, let info, _)? = h.events.last else { return XCTFail() }
        XCTAssertEqual(info.id, 51, "same drag session")
        XCTAssertEqual(h.dragBeganInfos.count, 1)
    }

    func testRetappingSameTriggerIsIgnoredByDefault() {
        let h = Harness()
        h.openWheel()
        h.clearRecords()
        h.tap(.shift)
        XCTAssertTrue(h.events.isEmpty)
        XCTAssertTrue(h.states.isEmpty)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testRetapCloseBehaviorClosesAndDragContinues() {
        let h = Harness(Harness.configuration { $0.retapBehavior = .close })
        h.openWheel()
        h.clearRecords()
        h.tap(.shift)
        XCTAssertEqual(h.states, [.cancelled, .dragging(dragID: 51)])
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testRemappedKeyForOpenTriggerCountsAsRetap() {
        let h = Harness()
        h.openWheel() // convert via ⇧
        h.sense.configuration.triggers = [Trigger(id: "convert", key: .option)]
        h.clearRecords()
        h.tap(.option)
        XCTAssertTrue(h.events.isEmpty, "same trigger id, so it's a re-tap")
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testModifierWakeUpPollsImmediately() {
        let h = Harness()
        h.beginFileDrag()
        h.press(.shift)
        h.ticks(3)
        h.sys.flags = []
        h.sys.wake(.modifiersChanged) // a flagsChanged hint, between timer ticks
        XCTAssertEqual(h.tappedTriggerIDs, ["convert"])
    }
}

/// The tap detector on its own.
final class TapDetectorTests: XCTestCase {
    func testTapReportsPressReleaseAndEarliestReleaseTimes() {
        var detector = TapDetector()
        detector.reset(flags: [], at: 0)
        XCTAssertTrue(detector.feed(flags: [], at: 0.01, threshold: 0.35).isEmpty)
        XCTAssertTrue(detector.feed(flags: .shift, at: 0.02, threshold: 0.35).isEmpty)
        XCTAssertTrue(detector.feed(flags: .shift, at: 0.10, threshold: 0.35).isEmpty)
        let taps = detector.feed(flags: [], at: 0.11, threshold: 0.35)
        XCTAssertEqual(taps, [TapDetector.Tap(key: .shift, pressedAt: 0.02, releasedAt: 0.11, earliestRelease: 0.10)])
    }

    func testCapsLockAndNumericPadFlagsAreIgnored() {
        var detector = TapDetector()
        detector.reset(flags: [], at: 0)
        _ = detector.feed(flags: [.capsLock, .numericPad], at: 0.01, threshold: 0.35)
        _ = detector.feed(flags: [.capsLock, .numericPad, .shift], at: 0.02, threshold: 0.35)
        let taps = detector.feed(flags: [.capsLock], at: 0.05, threshold: 0.35)
        XCTAssertEqual(taps.map(\.key), [.shift])
    }

    func testReleaseAndPressInSameSampleAreSequential() {
        var detector = TapDetector()
        detector.reset(flags: [], at: 0)
        _ = detector.feed(flags: .shift, at: 0.01, threshold: 0.35)
        let first = detector.feed(flags: .command, at: 0.05, threshold: 0.35)
        XCTAssertEqual(first.map(\.key), [.shift])
        let second = detector.feed(flags: [], at: 0.09, threshold: 0.35)
        XCTAssertEqual(second.map(\.key), [.command])
    }

    func testResetMarksHeldKeysUnusable() {
        var detector = TapDetector()
        detector.reset(flags: .option, at: 0)
        XCTAssertEqual(detector.heldKeys, [.option])
        XCTAssertTrue(detector.feed(flags: [], at: 0.05, threshold: 0.35).isEmpty)
    }
}
