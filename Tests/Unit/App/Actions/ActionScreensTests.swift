import AppKit
import XCTest
@testable import HaloApp

/// Renders the actions' screens offscreen. Writes to a temp folder by
/// default; set `HALO_SCREENS_DIR` (via `TEST_RUNNER_HALO_SCREENS_DIR=…` on
/// the xcodebuild command line) to write into docs/screens.
@MainActor
final class ActionScreensTests: XCTestCase {
    func testRendersShelfAndMoveChooser() throws {
        let env = ProcessInfo.processInfo.environment["HALO_SCREENS_DIR"]
        let tmp = try TempFolder("screens")
        let dir = env.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? tmp.url

        let written = try ActionScreens.render(into: dir)

        let names = Set(written.map(\.lastPathComponent))
        XCTAssertEqual(names, ["float-stack-light.png", "float-stack-dark.png", "float-grid-light.png", "float-grid-dark.png",
                               "float-empty-light.png", "float-empty-dark.png", "move-chooser.png", "move-chooser-dark.png"])
        for url in written {
            let image = NSImage(contentsOf: url)
            XCTAssertNotNil(image, url.lastPathComponent)
            XCTAssertGreaterThan(image?.size.width ?? 0, 200)
        }
    }

    func testCardSizes() {
        XCTAssertEqual(ShelfCardView.size(mode: .collapsed, count: 5), ShelfCardView.collapsedSize)
        let grid = ShelfCardView.size(mode: .expanded, count: 5)
        XCTAssertEqual(grid.width, 3 * 84 + 2 * 6 + 2 * 14)
        XCTAssertEqual(grid.height, 40 + 2 * 96 + 6 + 14)
        let tall = ShelfCardView.size(mode: .expanded, count: 30)
        XCTAssertEqual(tall.height, 40 + 3 * 96 + 2 * 6 + 14, "more than three rows scroll")
        XCTAssertEqual(ShelfGridView.columns(for: 2), 2)
    }
}
