import XCTest
import DragSense
import HaloCore
@testable import RadialMenu
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

    /// Real hardware: the poll sees the button go up before AppKit delivers the
    /// drop. Hiding the wheel then lost every drop.
    func testMouseUpOverTheWheelDoesNotCancelBeforeTheDrop() {
        let coordinator = AppCoordinator(settings: settings)
        defer { coordinator.wheel.hide(animated: false) }
        let point = CGPoint(x: 400, y: 400)
        coordinator.wheel.show(kind: .actions, urls: [URL(fileURLWithPath: "/tmp/a.jpg")], at: point)
        coordinator.wheel.menuView.acceptsCurrentDrop = true // released on a segment
        coordinator.handle(.dragEnded(location: point))
        XCTAssertTrue(coordinator.wheel.isVisible)
        XCTAssertNotNil(coordinator.wheel.kind, "still waiting for performDragOperation")
        coordinator.wheel.menuView.acceptsCurrentDrop = false // the drag left the wheel
        let far = CGPoint(x: coordinator.wheel.panel.frame.maxX + 300, y: point.y)
        coordinator.handle(.dragEnded(location: far))
        XCTAssertNil(coordinator.wheel.kind, "a release with no drop coming closes it")
    }

    /// ⌥ tap mid-drag (DragSense.lockKeyTapped) locks the highlighted segment.
    func testLockKeyTapLocksTheHighlightedSegment() {
        let coordinator = AppCoordinator(settings: settings)
        defer { coordinator.wheel.hide(animated: false) }
        coordinator.wheel.show(kind: .actions, urls: [URL(fileURLWithPath: "/tmp/a.jpg")], at: CGPoint(x: 400, y: 400))
        coordinator.handle(.lockKeyTapped(location: .zero))
        XCTAssertFalse(coordinator.wheel.menuView.isLocked, "nothing highlighted yet")
        coordinator.wheel.menuView.highlightItem(at: 1, animated: false)
        coordinator.handle(.lockKeyTapped(location: .zero))
        XCTAssertTrue(coordinator.wheel.menuView.isLocked)
        coordinator.handle(.lockKeyTapped(location: .zero))
        XCTAssertFalse(coordinator.wheel.menuView.isLocked, "a second tap unlocks")
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
