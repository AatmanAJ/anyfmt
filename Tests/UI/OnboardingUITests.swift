import XCTest

/// UI tests need macOS Automation Mode (see BLOCKERS.md). They are run by
/// `make uitest`, not `make test`, so an unattended machine stays green.
final class OnboardingUITests: XCTestCase {
    func testOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-onboarding", "--reset-onboarding"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
    }
}
