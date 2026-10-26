import XCTest
@testable import AnyfmtApp

/// Renders every progress-card state into docs/screens/progress-*.png
/// (the repo convention: `make test` refreshes screenshots so regressions show in review).
@MainActor
final class ProgressGalleryTests: XCTestCase {
    private var screensDirectory: URL {
        // Tests/Unit/App/JobsUI/<file> → repo root
        var u = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { u.deleteLastPathComponent() }
        return u.appendingPathComponent("docs/screens", isDirectory: true)
    }

    func testRenderProgressCardScreens() throws {
        let written = try ProgressCardGallery.render(into: screensDirectory)
        XCTAssertEqual(written.count, ProgressCardGallery.scenes().count + ProgressCardGallery.toastScenes().count)
        for url in written {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size, 3_000, "\(url.lastPathComponent) looks empty")
            let image = try XCTUnwrap(NSImage(contentsOf: url))
            XCTAssertGreaterThan(image.size.width, 300)
        }
    }
}
