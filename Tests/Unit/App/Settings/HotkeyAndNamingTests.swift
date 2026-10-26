import XCTest
import AppKit
import Carbon.HIToolbox
import AnyfmtCore
@testable import AnyfmtApp

final class HotkeyTests: XCTestCase {
    func testDefaultIsControlOptionSpaceAndValid() {
        XCTAssertEqual(Hotkey.default.displayString, "⌃⌥Space")
        XCTAssertNil(Hotkey.default.issue)
    }

    func testNeedsCommandOrControl() {
        XCTAssertEqual(Hotkey(keyCode: kVK_Space, modifiers: [.option]).issue, .needsCommandOrControl)
        XCTAssertEqual(Hotkey(keyCode: kVK_ANSI_K, modifiers: [.option, .shift]).issue, .needsCommandOrControl)
        XCTAssertEqual(Hotkey(keyCode: kVK_ANSI_K, modifiers: []).issue, .needsCommandOrControl)
        XCTAssertNil(Hotkey(keyCode: kVK_ANSI_K, modifiers: [.command, .option]).issue)
        XCTAssertNil(Hotkey(keyCode: kVK_ANSI_K, modifiers: [.control, .shift]).issue)
    }

    func testRejectsModifierOnlyAndReservedShortcuts() {
        XCTAssertEqual(Hotkey(keyCode: kVK_Shift, modifiers: [.command]).issue, .modifierOnly)
        guard case .reserved? = Hotkey(keyCode: kVK_Space, modifiers: [.command]).issue else { return XCTFail("⌘Space is Spotlight") }
        guard case .reserved? = Hotkey(keyCode: kVK_ANSI_Q, modifiers: [.command]).issue else { return XCTFail("⌘Q quits") }
        XCTAssertNil(Hotkey(keyCode: kVK_ANSI_Q, modifiers: [.command, .option]).issue)
    }

    func testStorageRoundTripIgnoresIrrelevantFlags() {
        let raw = Int(NSEvent.ModifierFlags([.control, .option, .capsLock, .numericPad]).rawValue)
        let hk = Hotkey(keyCode: kVK_Space, rawModifiers: raw)
        XCTAssertEqual(hk.modifiers, [.control, .option])
        XCTAssertEqual(Hotkey(keyCode: hk.keyCode, rawModifiers: hk.rawModifiers), hk)
        XCTAssertEqual(hk.rawModifiers, Int(NSEvent.ModifierFlags([.control, .option]).rawValue))
    }

    func testDisplayOrderAndKeyNames() {
        XCTAssertEqual(Hotkey(keyCode: kVK_ANSI_K, modifiers: [.command, .shift, .control, .option]).displayString, "⌃⌥⇧⌘K")
        XCTAssertEqual(Hotkey(keyCode: kVK_F5, modifiers: [.control]).displayString, "⌃F5")
        XCTAssertEqual(Hotkey(keyCode: kVK_Return, modifiers: [.command]).displayString, "⌘↩")
    }

    @MainActor
    func testStoredDefaultMatchesHotkeyDefault() throws {
        let (settings, cleanup) = try makeSettings()
        defer { cleanup() }
        XCTAssertEqual(Hotkey(keyCode: settings.dropRingKeyCode, rawModifiers: settings.dropRingModifiers), .default)
    }
}

final class NamingPreviewTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21

    func testDefaultPattern() {
        XCTAssertEqual(NamingPreview.line(pattern: "{name}", date: date), "photo.heic → photo.jpg, then photo 2.jpg")
        XCTAssertEqual(NamingPreview.line(pattern: "", date: date), "photo.heic → photo.jpg, then photo 2.jpg")
    }

    func testTokens() {
        let n = NamingPreview.names(pattern: "{name} ({format}) {date}", date: date)
        XCTAssertEqual(n.first, "photo (JPG) 2026-09-21.jpg")
        XCTAssertEqual(n.second, "photo (JPG) 2026-09-21 2.jpg")
        XCTAssertEqual(NamingPreview.names(pattern: "{name}", input: "clip.mov", target: Formats.mp4, date: date).first, "clip.mp4")
    }

    func testIssues() {
        XCTAssertNil(NamingPreview.issue(pattern: "{name}-{date}"))
        XCTAssertNil(NamingPreview.issue(pattern: ""))
        XCTAssertNotNil(NamingPreview.issue(pattern: "{format}"), "without {name} every file collides")
        XCTAssertNotNil(NamingPreview.issue(pattern: "{name} {size}"), "unknown token")
    }

    func testSlashesNeverBecomeFolders() {
        XCTAssertEqual(NamingPreview.names(pattern: "{name}/x", date: date).first, "photo-x.jpg")
    }
}
