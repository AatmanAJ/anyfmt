import XCTest
import ServiceManagement
import os
@testable import HaloApp

/// Thread-safe flag for probes called off the main thread.
private final class Flag: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    var value: Bool {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

private final class Counter: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: 0)
    func bump() { lock.withLock { $0 += 1 } }
    var value: Int { lock.withLock { $0 } }
}

@MainActor
final class PermissionsCoachTests: XCTestCase {
    func testRefreshReadsBothPermissions() async throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let ax = Flag(), ae = Flag(), im = Flag()
        let probe = PermissionProbe(accessibility: { ax.value }, automation: { ae.value ? .granted : .notGranted },
                                    requestAccessibility: {}, requestAutomation: {},
                                    inputMonitoring: { im.value }, requestInputMonitoring: {})
        let coach = PermissionsCoach(probe: probe, defaults: defaults)
        XCTAssertEqual(coach[.accessibility], .unknown)
        await coach.refresh()
        XCTAssertEqual(coach[.accessibility], .notGranted)
        XCTAssertEqual(coach[.inputMonitoring], .notGranted)
        XCTAssertEqual(coach[.automationFinder], .notGranted)
        XCTAssertFalse(coach.allGranted)

        ax.value = true
        ae.value = true
        await coach.refresh()
        XCTAssertFalse(coach.allGranted, "the Return shortcut also needs Input Monitoring")
        im.value = true
        await coach.refresh()
        XCTAssertEqual(coach[.accessibility], .granted)
        XCTAssertEqual(coach[.inputMonitoring], .granted)
        XCTAssertEqual(coach[.automationFinder], .granted)
        XCTAssertTrue(coach.allGranted)
    }

    /// A grant made in System Settings shows up without restarting: polling picks it up.
    func testPollingDetectsALiveGrant() async throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let ax = Flag()
        let probe = PermissionProbe(accessibility: { ax.value }, automation: { .notGranted },
                                    requestAccessibility: {}, requestAutomation: {})
        let coach = PermissionsCoach(probe: probe, defaults: defaults, interval: .milliseconds(20))
        coach.startWatching()
        coach.startWatching()
        XCTAssertEqual(coach.watcherCount, 2)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(coach[.accessibility], .notGranted)
        ax.value = true
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(coach[.accessibility], .granted)
        coach.stopWatching()
        coach.stopWatching()
        coach.stopWatching()
        XCTAssertEqual(coach.watcherCount, 0)
    }

    func testFirstGrantPromptsThenDeepLinks() async throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let axPrompts = Counter()
        let probe = PermissionProbe(accessibility: { false }, automation: { .notGranted },
                                    requestAccessibility: { axPrompts.bump() }, requestAutomation: {})
        let coach = PermissionsCoach(probe: probe, defaults: defaults)
        var opened: [String] = []
        coach.openLink = { opened.append($0) }

        coach.grant(.accessibility)
        XCTAssertEqual(axPrompts.value, 1, "first time: macOS's own prompt")
        XCTAssertTrue(opened.isEmpty)
        XCTAssertTrue(coach.hasAsked(.accessibility))

        coach.grant(.accessibility)
        XCTAssertEqual(axPrompts.value, 1)
        XCTAssertEqual(opened, [SystemSettingsLink.accessibility], "then straight to the exact pane")
    }

    func testDeniedAutomationOpensThePane() async throws {
        let (defaults, cleanup) = try makeDefaults()
        defer { cleanup() }
        let asked = Counter()
        let probe = PermissionProbe(accessibility: { false }, automation: { .notGranted },
                                    requestAccessibility: {}, requestAutomation: { asked.bump() })
        let coach = PermissionsCoach(probe: probe, defaults: defaults)
        var opened: [String] = []
        coach.openLink = { opened.append($0) }
        coach.grant(.automationFinder)
        for _ in 0..<50 where opened.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(asked.value, 1)
        XCTAssertEqual(opened, [SystemSettingsLink.automation])
    }

    func testDeepLinksPointAtPrivacyPanes() {
        XCTAssertTrue(OptionalPermission.accessibility.settingsLink.hasSuffix("?Privacy_Accessibility"))
        XCTAssertTrue(OptionalPermission.automationFinder.settingsLink.hasSuffix("?Privacy_Automation"))
        XCTAssertTrue(OptionalPermission.allCases.allSatisfy { $0.settingsLink.hasPrefix("x-apple.systempreferences:com.apple.preference.security") })
    }
}

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testRegisterAndUnregisterReReadStatus() {
        let model = LaunchAtLogin(service: .fake(.notRegistered))
        XCTAssertFalse(model.isRequested)
        model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertTrue(model.isRequested)
        XCTAssertNil(model.statusNote)
        model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
    }

    func testRequiresApprovalCountsAsOnAndExplains() {
        let model = LaunchAtLogin(service: .fake(.requiresApproval))
        XCTAssertTrue(model.isRequested)
        XCTAssertNotNil(model.statusNote)
    }

    func testFailureIsExplainedAndStatusStillReRead() {
        struct Nope: Error {}
        let service = LoginItemService(status: { .notRegistered }, register: { throw Nope() },
                                       unregister: {}, openSystemSettings: {})
        let model = LaunchAtLogin(service: service)
        model.setEnabled(true)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(model.statusNote, model.lastError)
    }

    func testStatusChangedElsewhereIsPickedUpOnRefresh() {
        let state = Flag()
        let service = LoginItemService(status: { state.value ? .enabled : .notRegistered }, register: {},
                                       unregister: {}, openSystemSettings: {})
        let model = LaunchAtLogin(service: service)
        XCTAssertEqual(model.status, .notRegistered)
        state.value = true // the user switched it on in System Settings
        model.refresh()
        XCTAssertEqual(model.status, .enabled)
    }
}
