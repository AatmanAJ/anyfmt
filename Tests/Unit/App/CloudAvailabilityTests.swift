import XCTest
import AnyfmtCore
@testable import AnyfmtApp

/// Suites written for the cloud service run with it switched on; v1 ships with it off (D-045).
class CloudOnTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        Brand.cloudAvailable = true
    }

    override func tearDown() {
        Brand.cloudAvailable = false
        super.tearDown()
    }
}

/// v1: no cloud surface is reachable.
@MainActor
final class CloudAvailabilityTests: XCTestCase {
    func testV1ShipsWithTheCloudOff() {
        XCTAssertFalse(Brand.cloudAvailable)
    }

    func testOnboardingEndsOnUpdatesWithoutTheProPage() {
        XCTAssertEqual(OnboardingPage.visible, [.welcome, .demo, .permissions, .launch, .updates])
        XCTAssertTrue(OnboardingPage.updates.isLast)
        XCTAssertNil(OnboardingPage.updates.next)
    }

    func testSettingsHasNoAccountPane() {
        XCTAssertFalse(SettingsPane.visible.contains(.account))
        XCTAssertEqual(SettingsPane.visible.count, SettingsPane.allCases.count - 1)
    }

    func testTheCloudSwitchBringsItAllBack() {
        Brand.cloudAvailable = true
        defer { Brand.cloudAvailable = false }
        XCTAssertEqual(OnboardingPage.visible, OnboardingPage.allCases)
        XCTAssertEqual(SettingsPane.visible, SettingsPane.allCases)
    }
}

@MainActor
final class CloudOffWheelTests: XCTestCase {
    func testTheWheelOffersNoCloudEntries() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wheel-v1-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        var prefs = WheelPreferences.standard
        prefs.showCloudItems = true   // the switch wins over the preference
        let actions = WheelTestTable.provider.entries(for: WheelInput(urls: [dir]), kind: .actions, preferences: prefs)
        XCTAssertFalse(actions.isEmpty)
        XCTAssertFalse(actions.contains(where: CloudSegments.isCloud), "no share link or other Pro action in v1")
        XCTAssertEqual(actions.count, ActionCatalog.all.filter { $0.cloudFeature == nil }.count)
    }
}
