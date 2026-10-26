import Combine
import AnyfmtCore
import XCTest
@testable import AnyfmtApp

/// Sync used to have no real source, so "Sync Now" did nothing (audit, phase 2).
@MainActor
final class SettingsSyncSourceTests: XCTestCase {
    private func freshSettings() -> AppSettings {
        let suite = "anyfmt.sync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }

    func testFactorySettingsHaveNothingToSync() {
        let s = freshSettings()
        for ns in SyncNamespace.allCases where ns != .presets {
            XCTAssertNil(SettingsSyncSource.document(ns, from: s), "\(ns) must not overwrite the server with defaults")
        }
    }

    func testRoundTripToAnotherMac() throws {
        let here = freshSettings()
        here.favouriteFormats = ["webp", "png"]
        here.hiddenFormats = ["bmp"]
        here.shownFormats = ["docx"]
        here.hiddenTools = [ToolIDs.collage]
        here.formatDefaults = ["jpg": OptionValues([OptionKey.quality: .int(70)])]
        here.namePattern = "{name} ({format})"
        here.metadataPolicy = .stripPrivate

        let there = freshSettings()
        for ns in [SyncNamespace.favourites, .wheelOrder, .settings] {
            let data = try XCTUnwrap(SettingsSyncSource.document(ns, from: here))
            try SettingsSyncSource.apply(data, to: ns, settings: there)
        }
        XCTAssertEqual(there.favouriteFormats, ["webp", "png"], "order kept")
        XCTAssertEqual(there.hiddenFormats, ["bmp"])
        XCTAssertEqual(there.shownFormats, ["docx"])
        XCTAssertEqual(there.hiddenTools, [ToolIDs.collage])
        XCTAssertEqual(there.formatDefaults["jpg"]?.int(OptionKey.quality, default: 0), 70)
        XCTAssertEqual(there.namePattern, "{name} ({format})")
        XCTAssertEqual(there.metadataPolicy, .stripPrivate)
    }

    func testDocumentsAreStableForChangeDetection() {
        let s = freshSettings()
        s.hiddenFormats = ["tiff", "bmp", "gif"]
        XCTAssertEqual(SettingsSyncSource.document(.wheelOrder, from: s), SettingsSyncSource.document(.wheelOrder, from: s))
    }

    func testChangesMapToNamespaces() {
        let s = freshSettings()
        var seen: [SyncNamespace] = []
        let c = SettingsSyncSource.changes(of: s).sink { seen.append($0) }
        s.favouriteFormats = ["png"]
        s.hiddenTools = [ToolIDs.collage]
        s.namePattern = "x"
        c.cancel()
        XCTAssertEqual(seen, [.favourites, .wheelOrder, .settings])
    }
}
