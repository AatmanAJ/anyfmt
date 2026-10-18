import AppKit
import XCTest
@testable import RadialMenu

/// AppKit only delivers a drop when the destination's last answer accepted it,
/// so hosts read `acceptsCurrentDrop` at mouse-up to know whether one is coming.
@MainActor
final class DropAnswerTests: XCTestCase {
    private func makeView(disabled: Set<Int> = []) -> RadialMenuView {
        let view = RadialMenuView(style: RadialMenuStyle(), materialMode: .painted)
        view.setItems((0..<8).map { RadialItem(id: "i\($0)", title: "Item \($0)", symbolName: "star",
                                               isEnabled: !disabled.contains($0)) }, animated: false)
        return view
    }

    func testSegmentAcceptsHubAndExitDoNot() {
        let view = makeView()
        let c = view.wheelCenter
        XCTAssertFalse(view.acceptsCurrentDrop)
        XCTAssertEqual(view.draggingEntered(FakeDrag(at: NSPoint(x: c.x + 88, y: c.y))), .copy)
        XCTAssertTrue(view.acceptsCurrentDrop, "over a segment")
        XCTAssertEqual(view.draggingUpdated(FakeDrag(at: NSPoint(x: c.x + 5, y: c.y + 5))), [])
        XCTAssertFalse(view.acceptsCurrentDrop, "over the hub")
        _ = view.draggingUpdated(FakeDrag(at: NSPoint(x: c.x + 88, y: c.y)))
        view.draggingExited(nil)
        XCTAssertFalse(view.acceptsCurrentDrop, "left the wheel")
    }

    func testDisabledSegmentDoesNotAccept() {
        let view = makeView(disabled: [2]) // 3 o'clock
        let c = view.wheelCenter
        XCTAssertEqual(view.draggingUpdated(FakeDrag(at: NSPoint(x: c.x + 88, y: c.y))), [])
        XCTAssertFalse(view.acceptsCurrentDrop)
    }

    func testANewShowForgetsTheLastAnswer() {
        let view = makeView()
        let c = view.wheelCenter
        _ = view.draggingUpdated(FakeDrag(at: NSPoint(x: c.x + 88, y: c.y)))
        XCTAssertTrue(view.acceptsCurrentDrop)
        view.prepareForDisplay()
        XCTAssertFalse(view.acceptsCurrentDrop)
    }
}
