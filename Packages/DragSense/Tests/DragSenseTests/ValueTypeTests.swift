// DragSense: MIT licence, see LICENSE.
import AppKit
import Carbon
import XCTest
@testable import DragSense

final class ConfigurationTests: XCTestCase {
    func testDefaults() {
        let config = DragSenseConfiguration()
        XCTAssertEqual(config.tapThreshold, 0.35)
        XCTAssertEqual(config.idlePollInterval, 0.25)
        XCTAssertEqual(config.activePollRate, 240)
        XCTAssertTrue(config.requireFileTypes)
        XCTAssertEqual(config.topExclusionHeight, 24)
        XCTAssertEqual(config.minimumDragDistance, 3)
        XCTAssertEqual(config.retapBehavior, .ignore)
        XCTAssertEqual(config.triggers, [Trigger(id: "primary", key: .shift)])
    }

    func testValidationClampsEveryRangeAndReplacesNaN() {
        var config = DragSenseConfiguration()
        config.tapThreshold = 0.01
        config.idlePollInterval = 60
        config.activePollRate = .nan
        config.topExclusionHeight = -5
        config.minimumDragDistance = 500
        config.pasteboardReadTimeout = 0
        config.dropResolutionTimeout = 99
        config.dragMovedInterval = -1
        let v = config.validated()
        XCTAssertEqual(v.tapThreshold, 0.15)
        XCTAssertEqual(v.idlePollInterval, 2)
        XCTAssertEqual(v.activePollRate, 240)
        XCTAssertEqual(v.topExclusionHeight, 0)
        XCTAssertEqual(v.minimumDragDistance, 50)
        XCTAssertEqual(v.pasteboardReadTimeout, 0.05)
        XCTAssertEqual(v.dropResolutionTimeout, 10)
        XCTAssertEqual(v.dragMovedInterval, 0)
        config.tapThreshold = 2
        XCTAssertEqual(config.validated().tapThreshold, 0.8)
    }

    func testDuplicateTriggerKeysAndIDsAreDroppedFirstWins() {
        let config = DragSenseConfiguration(triggers: [
            Trigger(id: "convert", key: .shift),
            Trigger(id: "tools", key: .shift),   // same key
            Trigger(id: "convert", key: .control), // same id
            Trigger(id: "actions", key: .control),
        ]).validated()
        XCTAssertEqual(config.triggers, [Trigger(id: "convert", key: .shift), Trigger(id: "actions", key: .control)])
        XCTAssertEqual(config.trigger(for: .control)?.id, "actions")
        XCTAssertNil(config.trigger(for: .command))
    }

    @MainActor
    func testDragSenseValidatesConfigurationOnSet() {
        let h = Harness()
        h.sense.configuration.tapThreshold = 5
        XCTAssertEqual(h.sense.configuration.tapThreshold, 0.8)
    }

    func testCodableRoundTripAndMissingKeysUseDefaults() throws {
        var config = DragSenseConfiguration(triggers: Harness.triggers)
        config.tapThreshold = 0.5
        config.retapBehavior = .close
        let data = try JSONEncoder().encode(config)
        XCTAssertEqual(try JSONDecoder().decode(DragSenseConfiguration.self, from: data), config)

        let partial = Data(#"{"tapThreshold": 0.2, "triggers": [{"id": "x", "key": "option"}]}"#.utf8)
        let decoded = try JSONDecoder().decode(DragSenseConfiguration.self, from: partial)
        XCTAssertEqual(decoded.tapThreshold, 0.2)
        XCTAssertEqual(decoded.triggers, [Trigger(id: "x", key: .option)])
        XCTAssertEqual(decoded.activePollRate, 240)
        XCTAssertEqual(decoded.retapBehavior, .ignore)
    }
}

final class ModifierKeyTests: XCTestCase {
    func testFlagsRoundTrip() {
        for key in ModifierKey.allCases {
            XCTAssertEqual(ModifierKey(flag: key.flag), key)
        }
        XCTAssertNil(ModifierKey(flag: [.shift, .command]))
        XCTAssertNil(ModifierKey(flag: .capsLock))
        XCTAssertEqual(ModifierKey.keys(in: [.shift, .control, .capsLock]), [.shift, .control])
    }

    func testSymbolsInAppleOrder() {
        XCTAssertEqual(ModifierKey.shift.symbol, "⇧")
        XCTAssertEqual(ModifierKey.command.symbol, "⌘")
        XCTAssertEqual(ModifierKey.control.symbol, "⌃")
        XCTAssertEqual(ModifierKey.option.symbol, "⌥")
        XCTAssertEqual(ModifierKey.function.symbol, "fn")
        XCTAssertEqual(ModifierKey.symbols(for: [.command, .shift, .option, .control]), "⌃⌥⇧⌘")
    }

    func testRawValuesAreStableForPersistence() {
        XCTAssertEqual(ModifierKey.allCases.map(\.rawValue), ["shift", "command", "control", "option", "function"])
    }
}

@MainActor
final class GlobalHotKeyTests: XCTestCase {
    private let space = UInt32(kVK_Space)

    func testShortcutNeedsCommandOrControl() {
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [.option])), .needsCommandOrControl)
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [.option, .shift])), .needsCommandOrControl)
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [])), .needsCommandOrControl)
        XCTAssertNil(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [.control, .option])))
        XCTAssertNil(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [.command, .shift])))
    }

    func testFunctionModifierAndModifierKeyCodesAreRejected() {
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: space, modifiers: [.control, .function])), .functionModifierUnsupported)
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: UInt32(kVK_Shift), modifiers: [.command])), .keyIsModifier(UInt32(kVK_Shift)))
        XCTAssertEqual(GlobalHotKey.validationError(for: .init(keyCode: UInt32(kVK_Function), modifiers: [.command])), .keyIsModifier(UInt32(kVK_Function)))
        XCTAssertThrowsError(try GlobalHotKey.validate(.init(keyCode: space, modifiers: [.option])))
    }

    func testRegisterRefusesInvalidShortcutWithoutTouchingCarbon() {
        let hotKey = GlobalHotKey(shortcut: .init(keyCode: space, modifiers: [.option])) {}
        XCTAssertThrowsError(try hotKey.register()) { error in
            XCTAssertEqual(error as? GlobalHotKey.RegistrationError, .invalid(.needsCommandOrControl))
        }
        XCTAssertFalse(hotKey.isRegistered)
    }

    func testCarbonModifierMapping() {
        let all = GlobalHotKey.Shortcut(keyCode: space, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(all.carbonModifiers, UInt32(cmdKey | shiftKey | optionKey | controlKey))
        XCTAssertEqual(GlobalHotKey.Shortcut(keyCode: space, modifiers: [.control]).carbonModifiers, UInt32(controlKey))
        XCTAssertEqual(GlobalHotKey.Shortcut(keyCode: space, modifiers: [.control, .option]).modifierSymbols, "⌃⌥")
    }

    func testShortcutIsCodable() throws {
        let shortcut = GlobalHotKey.Shortcut(keyCode: space, modifiers: [.control, .option])
        let data = try JSONEncoder().encode(shortcut)
        XCTAssertEqual(try JSONDecoder().decode(GlobalHotKey.Shortcut.self, from: data), shortcut)
    }
}
