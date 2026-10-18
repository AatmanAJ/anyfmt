import XCTest
@testable import HaloApp

@MainActor
final class AppSmokeTests: XCTestCase {
    func testRunsAsAgentUnderTests() {
        XCTAssertTrue(AppDelegate.isRunningTests)
    }
}
