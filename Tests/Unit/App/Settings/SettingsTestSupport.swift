import XCTest
@testable import HaloApp

/// AppSettings on a throwaway, suite-named UserDefaults.
@MainActor
func makeSettings(file: StaticString = #filePath, line: UInt = #line) throws -> (AppSettings, () -> Void) {
    let (defaults, cleanup) = try makeDefaults(file: file, line: line)
    return (AppSettings(defaults: defaults), cleanup)
}

func makeDefaults(file: StaticString = #filePath, line: UInt = #line) throws -> (UserDefaults, () -> Void) {
    let name = "dev.aiwithaj.halo.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name), file: file, line: line)
    return (defaults, { defaults.removePersistentDomain(forName: name) })
}

extension PermissionProbe {
    static let granted = PermissionProbe(accessibility: { true }, automation: { .granted },
                                         requestAccessibility: {}, requestAutomation: {})
}

/// Lets SwiftUI/AppKit settle.
@MainActor
func spin(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}
