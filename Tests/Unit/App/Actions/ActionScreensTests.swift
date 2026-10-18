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
                               "float-empty-light.png", "float-empty-dark.png", "float-drop-light.png", "float-drop-dark.png",
                               "move-chooser.png", "move-chooser-dark.png"])
        for url in written {
            let image = NSImage(contentsOf: url)
            XCTAssertNotNil(image, url.lastPathComponent)
            XCTAssertGreaterThan(image?.size.width ?? 0, 200)
        }
    }

    func testShelfPlacementStaysOnScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let vf = screen.visibleFrame
        let size = ShelfCardView.collapsedSize
        // Centred on the drop point when there's room.
        let mid = CGPoint(x: vf.midX, y: vf.midY)
        let centred = ShelfWindowPresenter.initialCardFrame(size: size, near: mid, savedOrigin: nil)
        XCTAssertEqual(centred.midX, mid.x, accuracy: 0.5)
        XCTAssertEqual(centred.midY, mid.y, accuracy: 0.5)
        // Pushed inward at a corner.
        let corner = ShelfWindowPresenter.initialCardFrame(size: size, near: CGPoint(x: vf.maxX - 2, y: vf.maxY - 2), savedOrigin: nil)
        XCTAssertTrue(vf.contains(corner), "\(corner) inside \(vf)")
        // A saved position off every screen falls back to the default spot.
        let lost = ShelfWindowPresenter.initialCardFrame(size: size, near: nil, savedOrigin: CGPoint(x: -99_999, y: -99_999))
        XCTAssertTrue(NSScreen.screens.contains { $0.visibleFrame.contains(lost) })
        // A saved position on screen is honoured.
        let saved = CGPoint(x: vf.minX + 40, y: vf.minY + 60)
        XCTAssertEqual(ShelfWindowPresenter.initialCardFrame(size: size, near: nil, savedOrigin: saved).origin, saved)
    }

    func testClampKeepsTheInset() {
        let vf = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let r = ShelfWindowPresenter.clamp(CGRect(x: 990, y: -50, width: 100, height: 100), to: vf, inset: 8)
        XCTAssertEqual(r, CGRect(x: 892, y: 8, width: 100, height: 100))
    }

    func testMoveDestinationLocations() {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        XCTAssertEqual(MoveDestination.location(of: home.appendingPathComponent("Desktop")), "Home")
        XCTAssertEqual(MoveDestination.location(of: home.appendingPathComponent("Code/halo")), "~/Code")
        XCTAssertEqual(MoveDestination.location(of: URL(fileURLWithPath: "/Volumes/Backup/Photos")), "Backup")
        XCTAssertEqual(MoveDestination.location(of: URL(fileURLWithPath: "/opt/stuff")), "/opt")
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
