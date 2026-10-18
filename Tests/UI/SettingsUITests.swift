import XCTest

/// Needs macOS Automation Mode (BLOCKERS.md B-003). Run with `make uitest`.
@MainActor
final class SettingsUITests: XCTestCase {
    func testSettingsPanesOpen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--no-onboarding", "--show-settings"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        for pane in ["General", "Keys", "Output", "Formats", "Engines", "Account", "Advanced"] {
            let button = window.toolbars.buttons[pane]
            XCTAssertTrue(button.waitForExistence(timeout: 2), "toolbar item \(pane)")
            button.click()
        }
        window.toolbars.buttons["Keys"].click()
        XCTAssertTrue(window.staticTexts["Convert"].waitForExistence(timeout: 2))
    }
}
