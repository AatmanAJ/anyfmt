import XCTest
import os
@testable import AnyfmtApp

/// Every permission path through onboarding (PLAN-PHASE2 §F), with an injected
/// probe so nothing touches real TCC: all granted, all denied, granted while
/// onboarding is open, and revoked afterwards. The app must stay usable in each:
/// the wheel never needs a permission (D-001), only the opt-in Finder shortcut does.
@MainActor
final class OnboardingPermissionPathsTests: CloudOnTestCase {
    /// Grants that can change while the coach is watching.
    private final class Grants: Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: (ax: false, im: false, ae: PermissionStatus.notGranted))
        func set(_ on: Bool) { lock.withLock { $0 = (on, on, on ? .granted : .notGranted) } }
        var ax: Bool { lock.withLock { $0.ax } }
        var im: Bool { lock.withLock { $0.im } }
        var ae: PermissionStatus { lock.withLock { $0.ae } }
    }

    private func make(_ grants: Grants) throws -> (OnboardingModel, PermissionsCoach, AppSettings, () -> Void) {
        let (settings, cleanup) = try makeSettings()
        let (defaults, cleanupDefaults) = try makeDefaults()
        let probe = PermissionProbe(accessibility: { grants.ax }, automation: { grants.ae },
                                    requestAccessibility: {}, requestAutomation: {},
                                    inputMonitoring: { grants.im }, requestInputMonitoring: {})
        let coach = PermissionsCoach(probe: probe, defaults: defaults, interval: .milliseconds(20))
        coach.openLink = { _ in }
        let model = OnboardingModel(settings: settings, loginItem: LaunchAtLogin(service: .fake()), coach: coach,
                                    info: SampleState.info)
        return (model, coach, settings, { cleanup(); cleanupDefaults() })
    }

    private func walkToTheEnd(_ model: OnboardingModel) {
        while !model.page.isLast { model.goNext() }
        XCTAssertEqual(model.page, .activate)
        model.goNext()
    }

    func testAllGranted() async throws {
        let grants = Grants()
        grants.set(true)
        let (model, coach, settings, cleanup) = try make(grants)
        defer { cleanup() }
        await coach.refresh()
        XCTAssertTrue(coach.allGranted)
        model.setFinderShortcut(true)
        walkToTheEnd(model)
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertTrue(settings.finderShortcutEnabled)
    }

    func testAllDeniedStillFinishesAndTheWheelNeedsNothing() async throws {
        let grants = Grants()
        let (model, coach, settings, cleanup) = try make(grants)
        defer { cleanup() }
        await coach.refresh()
        for p in OptionalPermission.allCases { XCTAssertEqual(coach[p], .notGranted, "\(p)") }
        walkToTheEnd(model)
        XCTAssertTrue(settings.onboardingCompleted, "denying everything never blocks onboarding")
        XCTAssertFalse(settings.finderShortcutEnabled, "the opt-in stays off")
        let sense = AppCoordinator.senseConfiguration(settings)
        XCTAssertEqual(sense.triggers.count, 3, "drag detection is configured with no permission at all")
    }

    func testGrantedMidFlowIsDetectedWithoutRestarting() async throws {
        let grants = Grants()
        let (model, coach, _, cleanup) = try make(grants)
        defer { cleanup() }
        model.go(to: .permissions)
        coach.startWatching() // the permissions page does this on appear
        defer { coach.stopWatching() }
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertFalse(coach.allGranted)
        grants.set(true) // the user flips the switches in System Settings
        try await waitUntil { coach.allGranted }
        XCTAssertTrue(coach.allGranted, "picked up live, no restart")
    }

    func testRevokedAfterOnboardingIsNoticed() async throws {
        let grants = Grants()
        grants.set(true)
        let (model, coach, settings, cleanup) = try make(grants)
        defer { cleanup() }
        model.setFinderShortcut(true)
        walkToTheEnd(model)
        await coach.refresh()
        XCTAssertTrue(coach.allGranted)
        grants.set(false) // revoked in System Settings later
        await coach.refresh()
        XCTAssertEqual(coach[.accessibility], .notGranted)
        XCTAssertEqual(coach[.inputMonitoring], .notGranted)
        XCTAssertTrue(settings.finderShortcutEnabled, "the setting is kept, so re-granting brings the shortcut back")
        XCTAssertTrue(settings.onboardingCompleted, "no forced re-onboarding")
    }

    func testOnboardingCanBeReplayed() throws {
        let (model, _, settings, cleanup) = try make(Grants())
        defer { cleanup() }
        model.finish()
        XCTAssertTrue(settings.onboardingCompleted)
        settings.onboardingCompleted = false // what --reset-onboarding and the reset script do
        let again = OnboardingModel(settings: settings, loginItem: LaunchAtLogin(service: .fake()),
                                    coach: PermissionsCoach(probe: .granted), info: SampleState.info)
        XCTAssertEqual(again.page, .welcome)
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
    }
}
