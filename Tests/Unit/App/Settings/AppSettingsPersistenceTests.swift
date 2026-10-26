import XCTest
import AppKit
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class AppSettingsPersistenceTests: XCTestCase {
    func testDefaults() throws {
        let (s, cleanup) = try makeSettings()
        defer { cleanup() }
        XCTAssertTrue(s.soundsEnabled)
        XCTAssertFalse(s.updateChecksEnabled, "update checks are opt-in (D-024)")
        XCTAssertFalse(s.finderShortcutEnabled, "Finder shortcut is opt-in (D-004)")
        XCTAssertEqual(s.convertKey, "shift")
        XCTAssertEqual(s.toolsKey, "command")
        XCTAssertEqual(s.actionsKey, "control")
        XCTAssertEqual(s.tapThreshold, 0.35, accuracy: 0.0001)
        XCTAssertEqual(s.namePattern, "{name}")
        XCTAssertEqual(s.metadataPolicy, .keep)
        XCTAssertEqual(s.cpuConcurrency, 0)
        XCTAssertNil(s.outputFolderURL)
    }

    func testRoundTripThroughUserDefaults() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let a = AppSettings(defaults: defaults)
        a.soundsEnabled = false
        a.hapticsEnabled = false
        a.updateChecksEnabled = true
        a.onboardingCompleted = true
        a.convertKey = "option"
        a.tapThreshold = 0.5
        a.finderShortcutEnabled = true
        a.dropRingKeyCode = 40
        a.dropRingModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        a.dropRingHotKeyEnabled = false
        a.namePattern = "{name} {date}"
        a.metadataPolicy = .stripPrivate
        a.preserveDates = false
        a.revealInFinder = false
        a.favouriteFormats = [Formats.webp, Formats.jpg]
        a.hiddenFormats = [Formats.bmp]
        a.hiddenTools = [ToolIDs.readCodes]
        a.formatDefaults = [Formats.jpg: OptionValues([OptionKey.quality: .int(72)])]
        a.cpuConcurrency = 3
        a.verboseLogging = true
        a.setOutputFolder(FileManager.default.temporaryDirectory)

        let b = AppSettings(defaults: defaults)
        XCTAssertFalse(b.soundsEnabled)
        XCTAssertFalse(b.hapticsEnabled)
        XCTAssertTrue(b.updateChecksEnabled)
        XCTAssertTrue(b.onboardingCompleted)
        XCTAssertEqual(b.convertKey, "option")
        XCTAssertEqual(b.tapThreshold, 0.5, accuracy: 0.0001)
        XCTAssertTrue(b.finderShortcutEnabled)
        XCTAssertEqual(b.dropRingKeyCode, 40)
        XCTAssertEqual(Hotkey(keyCode: b.dropRingKeyCode, rawModifiers: b.dropRingModifiers).modifiers, [.command, .shift])
        XCTAssertFalse(b.dropRingHotKeyEnabled)
        XCTAssertEqual(b.namePattern, "{name} {date}")
        XCTAssertEqual(b.metadataPolicy, .stripPrivate)
        XCTAssertFalse(b.preserveDates)
        XCTAssertFalse(b.revealInFinder)
        XCTAssertEqual(b.favouriteFormats, [Formats.webp, Formats.jpg], "favourite order is kept")
        XCTAssertEqual(b.hiddenFormats, [Formats.bmp])
        XCTAssertEqual(b.hiddenTools, [ToolIDs.readCodes])
        XCTAssertEqual(b.defaultOptions(for: Formats.jpg).int(OptionKey.quality, default: 0), 72)
        XCTAssertEqual(b.cpuConcurrency, 3)
        XCTAssertTrue(b.verboseLogging)
        XCTAssertEqual(b.outputFolderURL?.standardizedFileURL.path, FileManager.default.temporaryDirectory.standardizedFileURL.path)
        if case .folder = b.outputPolicy.location {} else { XCTFail("output policy should use the folder") }
    }

    func testResetRestoresFactorySettingsButKeepsOnboardingState() throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let s = AppSettings(defaults: defaults)
        s.onboardingCompleted = true
        s.convertKey = "function"
        s.updateChecksEnabled = true
        s.favouriteFormats = [Formats.png]
        s.formatDefaults = [Formats.png: OptionValues([OptionKey.maxDimension: .int(100)])]
        s.setOutputFolder(FileManager.default.temporaryDirectory)

        s.resetAll()
        XCTAssertTrue(s.onboardingCompleted)
        XCTAssertEqual(s.convertKey, "shift")
        XCTAssertFalse(s.updateChecksEnabled)
        XCTAssertTrue(s.favouriteFormats.isEmpty)
        XCTAssertTrue(s.formatDefaults.isEmpty)
        XCTAssertNil(s.outputFolderBookmark)

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.convertKey, "shift")
        XCTAssertTrue(reloaded.onboardingCompleted)
    }

    func testSettingsModelResetNotifiesHooks() throws {
        let (s, cleanup) = try makeSettings()
        defer { cleanup() }
        var keys = 0
        var updates: [Bool] = []
        let model = SettingsModel(settings: s, hooks: SettingsHooks(onUpdateChecksChanged: { updates.append($0) },
                                                                     onTriggerKeysChanged: { keys += 1 }),
                                  loginItem: LaunchAtLogin(service: .fake()), coach: PermissionsCoach(probe: .granted))
        s.updateChecksEnabled = true
        model.resetAll()
        XCTAssertEqual(keys, 1)
        XCTAssertEqual(updates, [false])
    }

    func testFormatDefaultsStoreOnlyChangedValues() throws {
        let (s, cleanup) = try makeSettings()
        defer { cleanup() }
        let schema = StandardSchemas.imageLossy
        let edited = schema.defaults.merging(OptionValues([OptionKey.quality: .int(60)]))
        let diff = OptionsFormLogic.nonDefault(edited, schema: schema)
        s.formatDefaults[Formats.heic] = diff
        XCTAssertEqual(s.formatDefaults[Formats.heic]?.values.keys.sorted(), [OptionKey.quality])
    }

    func testLastPaneIsRemembered() throws {
        let (s, cleanup) = try makeSettings()
        defer { cleanup() }
        let model = SettingsModel(settings: s, loginItem: LaunchAtLogin(service: .fake()), coach: PermissionsCoach(probe: .granted))
        XCTAssertEqual(model.lastPane, .general)
        model.lastPane = .engines
        let again = SettingsModel(settings: s, loginItem: LaunchAtLogin(service: .fake()), coach: PermissionsCoach(probe: .granted))
        XCTAssertEqual(again.lastPane, .engines)
    }
}
