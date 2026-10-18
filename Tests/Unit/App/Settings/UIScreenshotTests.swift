import XCTest
import AppKit
@testable import HaloApp

/// Renders every Settings pane, onboarding screen and About offscreen (D-025).
/// By default into a temp folder (checks nothing crashes and every image has
/// content). To refresh docs/screens:
///
///     TEST_RUNNER_HALO_WRITE_SCREENS=1 xcodebuild … test -only-testing:AppTests/UIScreenshotTests
@MainActor
final class UIScreenshotTests: XCTestCase {
    private var outputDirectory: URL {
        if ProcessInfo.processInfo.environment["HALO_WRITE_SCREENS"] == "1" {
            // Tests/Unit/App/Settings/<this file> → repo root
            return URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("docs/screens", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("halo-screens-\(UUID().uuidString)", isDirectory: true)
    }

    func testRendersEveryScreen() throws {
        let dir = outputDirectory
        let files = try UIScreenshots.renderAll(to: dir)
        let appearances = UIScreenshots.Appearance.allCases.count
        let expected = (SettingsPane.allCases.count + 1 + OnboardingPage.allCases.count + 2 + 1 + 1) * appearances
        XCTAssertEqual(files.count, expected)
        for url in files {
            let image = try XCTUnwrap(NSImage(contentsOf: url), url.lastPathComponent)
            XCTAssertGreaterThan(image.size.width, 300, url.lastPathComponent)
            XCTAssertGreaterThan(image.size.height, 200, url.lastPathComponent)
        }
    }
}
