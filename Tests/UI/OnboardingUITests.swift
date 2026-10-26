import XCTest

/// UI tests need macOS Automation Mode (see BLOCKERS.md B-003). They are run by
/// `make uitest`, not `make test`, so an unattended machine stays green.
///
/// Walks the whole first run: welcome → demo → permissions → launch at login →
/// updates → optional activation → finish. A screenshot of every step is attached
/// to the result bundle, and written to $ANYFMT_UI_SHOTS (e.g. docs/screens/onboarding/ui)
/// when that's set.
@MainActor
final class OnboardingUITests: XCTestCase {
    private let steps = ["welcome", "demo", "permissions", "launch", "updates", "activate"]

    func testOnboardingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-onboarding", "--reset-onboarding"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        for (i, step) in steps.enumerated() {
            snapshot(window, name: "\(i + 1)-\(step)")
            if step == "activate" {
                XCTAssertTrue(app.buttons["onboarding.signIn"].exists, "sign-in offered")
                XCTAssertFalse(app.buttons["onboarding.skip"].isEnabled, "on the last page, Start Using is the skip")
                let finish = app.buttons["onboarding.finish"]
                XCTAssertTrue(finish.waitForExistence(timeout: 2))
                finish.click()
            } else {
                let next = app.buttons["onboarding.continue"]
                XCTAssertTrue(next.waitForExistence(timeout: 2), "Continue on \(step)")
                next.click()
            }
        }
        XCTAssertTrue(window.waitForNonExistence(timeout: 3), "finishing closes onboarding")
    }

    func testSkipFromTheFirstPage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--show-onboarding", "--reset-onboarding"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 3))
    }

    private func snapshot(_ window: XCUIElement, name: String) {
        let shot = window.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "onboarding-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["ANYFMT_UI_SHOTS"] {
            let url = URL(fileURLWithPath: dir, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: url.appendingPathComponent("onboarding-\(name).png"))
        }
    }
}
