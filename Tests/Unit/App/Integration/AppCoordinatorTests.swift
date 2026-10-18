import XCTest
import DragSense
import HaloCore
@testable import HaloApp

/// Settings must drive behaviour, not just persist (the wiring the UI relies on).
@MainActor
final class AppCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: AppSettings!

    override func setUp() {
        super.setUp()
        let suite = "halo.coordinator.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        settings = AppSettings(defaults: defaults)
    }

    func testTriggerKeysAndThresholdReachTheSensor() {
        settings.convertKey = "option"
        settings.toolsKey = "shift"
        settings.tapThreshold = 0.5
        let c = AppCoordinator.senseConfiguration(settings)
        XCTAssertEqual(c.triggers.map(\.id), ["convert", "tools", "actions"])
        XCTAssertEqual(c.triggers.map(\.key), [.option, .shift, .control])
        XCTAssertEqual(c.tapThreshold, 0.5, accuracy: 0.0001)
    }

    func testFormatPreferencesReachTheWheel() {
        settings.favouriteFormats = ["webp"]
        settings.hiddenFormats = ["bmp"]
        settings.shownFormats = ["docx"]
        settings.hiddenTools = [ToolIDs.collage]
        let p = AppCoordinator.wheelPreferences(settings)
        XCTAssertEqual(p.favouriteFormats, ["webp"])
        XCTAssertEqual(p.hiddenFormats, ["bmp"])
        XCTAssertEqual(p.shownFormats, ["docx"], "opt-in routes can be switched on")
        XCTAssertEqual(p.hiddenTools, [ToolIDs.collage])
    }

    func testConcurrencyOverride() {
        XCTAssertEqual(AppCoordinator.limits(for: settings).cpu, ConcurrencyLimits.system.cpu, "0 = automatic")
        settings.cpuConcurrency = 2
        XCTAssertEqual(AppCoordinator.limits(for: settings).cpu, 2)
    }

    func testShownFormatsPersistAndReset() {
        settings.shownFormats = ["docx", "epub"]
        XCTAssertEqual(AppSettings(defaults: defaults).shownFormats, ["docx", "epub"])
        settings.resetAll()
        XCTAssertEqual(settings.shownFormats, [])
    }

    func testOutputPolicySnapshot() {
        settings.metadataPolicy = .stripPrivate
        settings.namePattern = "{name} ({format})"
        settings.revealInFinder = false
        let p = settings.outputPolicy
        XCTAssertEqual(p.metadata, .stripPrivate)
        XCTAssertEqual(p.namePattern, "{name} ({format})")
        XCTAssertFalse(p.revealInFinder)
        XCTAssertEqual(p.location, .besideOriginal)
    }
}
