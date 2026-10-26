import XCTest
import AppKit
import AnyfmtCore
@testable import AnyfmtApp

/// Drives the real Settings window offscreen (fully transparent, never key).
@MainActor
final class SettingsWindowTests: XCTestCase {
    private func makeController(pane: SettingsPane? = nil) throws -> (SettingsWindowController, SampleState) {
        let sample = try SampleState()
        let controller = SettingsWindowController(model: sample.model, pane: pane)
        let window = try XCTUnwrap(controller.window)
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        return (controller, sample)
    }

    func testToolbarHasAPerPaneSelectableItemAndPreferenceStyle() throws {
        let (c, sample) = try makeController(pane: .keys)
        defer { c.window?.orderOut(nil); sample.tearDown() }
        c.select(.keys, animate: false)
        let window = try XCTUnwrap(c.window)
        XCTAssertEqual(window.toolbarStyle, .preference)
        let ids = window.toolbar?.items.map(\.itemIdentifier.rawValue)
        XCTAssertEqual(ids, SettingsPane.allCases.map(\.rawValue))
        XCTAssertEqual(window.toolbar?.selectedItemIdentifier?.rawValue, "keys")
        XCTAssertEqual(window.title, SettingsPane.keys.title)
        XCTAssertTrue(window.toolbar?.items.allSatisfy { $0.image != nil } ?? false, "every pane has an SF Symbol")
    }

    func testSwitchingPanesResizesAndRemembersTheLastPane() throws {
        let (c, sample) = try makeController(pane: .general)
        defer { c.window?.orderOut(nil); sample.tearDown() }
        let window = try XCTUnwrap(c.window)
        c.select(.general, animate: false)
        spin(0.3)
        c.select(.general, animate: false)
        let general = window.contentLayoutRect.size

        c.select(.formats, animate: false)
        spin(0.3)
        let formats = window.contentLayoutRect.size
        XCTAssertEqual(formats.width, SettingsPane.formats.width, accuracy: 1)
        XCTAssertEqual(formats.height, SettingsPane.formats.fixedHeight ?? 0, accuracy: 1)
        XCTAssertNotEqual(general, formats)
        XCTAssertEqual(sample.model.lastPane, .formats)

        let reopened = SettingsWindowController(model: sample.model)
        XCTAssertEqual(reopened.pane, .formats, "opens on the last pane used")
    }

    func testWindowGrowsWhenAPaneRevealsMoreRows() throws {
        let (c, sample) = try makeController(pane: .keys)
        defer { c.window?.orderOut(nil); sample.tearDown() }
        let window = try XCTUnwrap(c.window)
        sample.settings.finderShortcutEnabled = false
        c.select(.keys, animate: false)
        spin(0.4)
        c.select(.keys, animate: false)
        spin(0.1)
        let collapsed = window.frame
        sample.settings.finderShortcutEnabled = true // reveals the two permission rows
        spin(0.8)
        let expanded = window.frame
        XCTAssertGreaterThan(expanded.height, collapsed.height + 40)
        XCTAssertEqual(expanded.maxY, collapsed.maxY, accuracy: 1, "top edge stays put")
    }

    func testCommandWClosesTheWindow() throws {
        let (c, sample) = try makeController(pane: .general)
        defer { sample.tearDown() }
        let window = try XCTUnwrap(c.window)
        c.select(.general, animate: false)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                                   windowNumber: window.windowNumber, context: nil, characters: "w",
                                                   charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13))
        XCTAssertTrue(window.performKeyEquivalent(with: event))
        XCTAssertFalse(window.isVisible)
    }

    func testEveryPaneBuilds() throws {
        let (c, sample) = try makeController()
        defer { c.window?.orderOut(nil); sample.tearDown() }
        for pane in SettingsPane.allCases {
            c.select(pane, animate: false)
            spin(0.05)
            XCTAssertEqual(c.pane, pane)
            XCTAssertGreaterThan(c.window?.contentLayoutRect.height ?? 0, 150, pane.rawValue)
        }
    }
}

@MainActor
final class FormatsPaneModelTests: XCTestCase {
    func testDefaultsSchemaFallsBackAndDropsCloudOption() throws {
        let sample = try SampleState()
        defer { sample.tearDown() }
        let model = sample.model
        XCTAssertFalse(model.formatCatalog.isEmpty)
        // Whatever the router knows, the saved defaults never offer "run in the cloud".
        for f in model.formatCatalog {
            XCTAssertFalse(model.defaultsSchema(for: f.id).specs.contains { $0.id == OptionKey.cloud }, f.id.rawValue)
        }
        if model.router.table.rows.isEmpty {
            XCTAssertEqual(model.defaultsSchema(for: Formats.jpg).id, StandardSchemas.imageOpaque.id)
            XCTAssertTrue(model.defaultsSchema(for: Formats.mp4).specs.contains { $0.id == OptionKey.videoQuality })
        }
    }

    func testToolGroupsCoverEveryLocalTool() {
        for tool in ToolCatalog.local {
            XCTAssertEqual(ToolGroup.allCases.filter { $0.contains(tool.id) }.count, 1, tool.id.rawValue)
        }
    }
}
