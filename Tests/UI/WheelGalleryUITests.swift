import XCTest

/// Needs macOS Automation Mode (BLOCKERS.md B-003). The offscreen gallery renders run
/// in `make test` (make gallery); this checks the live, interactive gallery window.
@MainActor
final class WheelGalleryUITests: XCTestCase {
    func testGalleryRendersOffscreenSet() throws {
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("gallery-\(UUID().uuidString)")
        let app = XCUIApplication()
        app.launchArguments = ["--render-gallery", out.path]
        app.launch()
        let deadline = Date().addingTimeInterval(20)
        while app.state != .notRunning && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: out.appendingPathComponent("gallery").path)) ?? []
        XCTAssertGreaterThan(files.count, 100)
    }
}
