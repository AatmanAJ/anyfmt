import XCTest
import AppKit
@testable import HaloApp

final class TriggerAssignmentTests: XCTestCase {
    func testAssigningAUsedKeySwapsTheTwoWheels() {
        var t = TriggerAssignment.default
        t.assign(.command, to: .convert)
        XCTAssertEqual(t[.convert], .command)
        XCTAssertEqual(t[.tools], .shift, "Tools takes Convert's old key")
        XCTAssertEqual(t[.actions], .control)

        t.assign(.option, to: .actions)
        XCTAssertEqual(t[.actions], .option, "a free key needs no swap")
        XCTAssertEqual(Set(TriggerRole.allCases.map { t[$0] }).count, 3)
    }

    func testAssigningTheSameKeyIsANoOp() {
        var t = TriggerAssignment.default
        t.assign(.shift, to: .convert)
        XCTAssertEqual(t, .default)
    }

    func testDuplicatesFromStorageAreRepaired() {
        let t = TriggerAssignment(convert: .shift, tools: .shift, actions: .shift)
        XCTAssertEqual(Set(TriggerRole.allCases.map { t[$0] }).count, 3)
        XCTAssertEqual(t[.convert], .shift)
        XCTAssertEqual(t[.tools], .command)
        XCTAssertEqual(t[.actions], .control)
    }

    func testRoleLookupAndParsing() {
        let t = TriggerAssignment.default
        XCTAssertEqual(t.role(for: .control), .actions)
        XCTAssertNil(t.role(for: .option))
        XCTAssertEqual(TriggerKey.parse("COMMAND", fallback: .shift), .command)
        XCTAssertEqual(TriggerKey.parse("hyper", fallback: .shift), .shift)
        XCTAssertEqual(TriggerKey.keys(in: [.shift, .command, .capsLock]), [.shift, .command])
    }

    @MainActor
    func testSettingsModelAssignWritesSettingsAndCallsHook() throws {
        let (settings, cleanup) = try makeSettings()
        defer { cleanup() }
        var calls = 0
        let model = SettingsModel(settings: settings, hooks: SettingsHooks(onTriggerKeysChanged: { calls += 1 }),
                                  loginItem: LaunchAtLogin(service: .fake()), coach: PermissionsCoach(probe: .granted))
        model.assign(.control, to: .convert)
        XCTAssertEqual(settings.convertKey, "control")
        XCTAssertEqual(settings.actionsKey, "shift")
        XCTAssertEqual(settings.toolsKey, "command")
        XCTAssertEqual(calls, 1)
    }
}

final class ModifierTapDetectorTests: XCTestCase {
    private var d = ModifierTapDetector(threshold: 0.35)

    override func setUp() { d = ModifierTapDetector(threshold: 0.35) }

    func testQuickPressAndReleaseIsATap() {
        XCTAssertNil(d.flagsChanged(to: [.shift], at: 10.0))
        XCTAssertEqual(d.pendingKey, .shift)
        guard case .tap(.shift, let duration)? = d.flagsChanged(to: [], at: 10.2) else { return XCTFail("expected tap") }
        XCTAssertEqual(duration, 0.2, accuracy: 0.0001)
    }

    func testLongPressIsAHold() {
        _ = d.flagsChanged(to: [.command], at: 1.0)
        guard case .held(.command, let duration)? = d.flagsChanged(to: [], at: 1.5) else { return XCTFail("expected hold") }
        XCTAssertEqual(duration, 0.5, accuracy: 0.0001)
    }

    func testThresholdIsExclusive() {
        _ = d.flagsChanged(to: [.shift], at: 0)
        if case .tap = d.flagsChanged(to: [], at: 0.35) { XCTFail("0.35 s is not < 0.35 s") }
    }

    func testSecondModifierSpoilsTheTap() {
        _ = d.flagsChanged(to: [.shift], at: 0)
        _ = d.flagsChanged(to: [.shift, .command], at: 0.05)
        XCTAssertNil(d.pendingKey)
        XCTAssertNil(d.flagsChanged(to: [.command], at: 0.08), "still holding a key")
        XCTAssertEqual(d.flagsChanged(to: [], at: 0.1), .chord([.shift, .command]))
    }

    func testPressingTwoAtOnceIsAChord() {
        _ = d.flagsChanged(to: [.option, .command], at: 0)
        XCTAssertEqual(d.flagsChanged(to: [], at: 0.1), .chord([.option, .command]))
    }

    func testRegularKeySpoilsTheTap() {
        _ = d.flagsChanged(to: [.command], at: 0)
        d.otherKeyPressed() // ⌘C
        XCTAssertEqual(d.flagsChanged(to: [], at: 0.1), .chord([.command]))
    }

    func testDetectorResetsBetweenPresses() {
        _ = d.flagsChanged(to: [.shift, .control], at: 0)
        _ = d.flagsChanged(to: [], at: 0.1)
        _ = d.flagsChanged(to: [.control], at: 1.0)
        XCTAssertEqual(d.flagsChanged(to: [], at: 1.1).map(\.isTap), true)
    }

    func testOtherKeyWithNothingHeldDoesNothing() {
        d.otherKeyPressed()
        _ = d.flagsChanged(to: [.shift], at: 0)
        XCTAssertEqual(d.flagsChanged(to: [], at: 0.1).map(\.isTap), true)
    }

    func testThresholdChangeAppliesToNextPress() {
        d.threshold = 0.8
        _ = d.flagsChanged(to: [.shift], at: 0)
        XCTAssertEqual(d.flagsChanged(to: [], at: 0.6).map(\.isTap), true)
    }
}

@MainActor
final class TapTesterTests: XCTestCase {
    func testReportsTapHoldAndChord() {
        let t = TapTester(threshold: 0.3)
        XCTAssertEqual(t.result, .idle)
        t.flags([.shift], 0)
        XCTAssertEqual(t.result, .pressing(.shift))
        t.flags([], 0.125)
        XCTAssertEqual(t.result, .tap(.shift, 0.125))
        t.flags([.control], 1)
        t.flags([], 1.5)
        XCTAssertEqual(t.result, .held(.control, 0.5))
        t.flags([.control, .option], 2)
        t.flags([], 2.1)
        XCTAssertEqual(t.result, .chord([.control, .option]))
    }
}

extension ModifierTapDetector.Outcome {
    var isTap: Bool {
        if case .tap = self { return true }
        return false
    }
}
