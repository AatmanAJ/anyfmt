import XCTest
@testable import AnyfmtApp

@MainActor
final class AppSmokeTests: XCTestCase {
    func testRunsAsAgentUnderTests() {
        XCTAssertTrue(AppDelegate.isRunningTests)
    }
}
