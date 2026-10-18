import AppKit
import XCTest
@testable import RadialMenu

@MainActor
private final class Recorder: RadialMenuViewDelegate {
    var activated: [String] = []
    var highlighted: [String?] = []
    var cancels = 0
    var cycles: [Bool] = []
    var optionRequests: [String] = []
    var hasOptions = false

    func radialMenu(_ menu: RadialMenuView, didActivate item: RadialItem) { activated.append(item.id) }
    func radialMenu(_ menu: RadialMenuView, didHighlight item: RadialItem?) { highlighted.append(item?.id) }
    func radialMenuDidCancel(_ menu: RadialMenuView) { cancels += 1 }
    func radialMenu(_ menu: RadialMenuView, didRequestNextMenu forward: Bool) { cycles.append(forward) }
    func radialMenu(_ menu: RadialMenuView, hasOptionsFor item: RadialItem) -> Bool { hasOptions }
    func radialMenu(_ menu: RadialMenuView, didRequestOptionsFor item: RadialItem, anchor: NSRect) {
        optionRequests.append(item.id)
    }
}

@MainActor
final class RadialMenuViewTests: XCTestCase {
    private func items(_ n: Int, disabled: Set<Int> = []) -> [RadialItem] {
        (0..<n).map { RadialItem(id: "i\($0)", title: "Item \($0)", symbolName: "star", isEnabled: !disabled.contains($0)) }
    }

    private func makeView(_ n: Int, disabled: Set<Int> = []) -> (RadialMenuView, Recorder) {
        var style = RadialMenuStyle()
        style.appearanceOverride = .light
        let view = RadialMenuView(style: style, materialMode: .painted)
        let recorder = Recorder()
        view.delegate = recorder
        view.keyboardEnabled = true
        view.setItems(items(n, disabled: disabled), animated: false)
        return (view, recorder)
    }

    private func key(_ code: UInt16, _ chars: String = "", shift: Bool = false) -> NSEvent {
        guard let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: shift ? [.shift] : [],
                                       timestamp: 0, windowNumber: 0, context: nil, characters: chars,
                                       charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)
        else { fatalError("could not make key event") }
        return e
    }

    func testArrowsMoveInAngularOrderAndWrap() {
        let (view, _) = makeView(5)
        XCTAssertNil(view.highlightedItemIndex)
        view.handleKey(key(124)) // →
        XCTAssertEqual(view.highlightedItemIndex, 0)
        view.handleKey(key(124))
        XCTAssertEqual(view.highlightedItemIndex, 1)
        view.handleKey(key(123)) // ←
        view.handleKey(key(123))
        XCTAssertEqual(view.highlightedItemIndex, 4, "wraps counter-clockwise")
        view.handleKey(key(125)) // ↓ (single ring = next)
        XCTAssertEqual(view.highlightedItemIndex, 0)
    }

    func testUpDownSwitchRingsWhenThereAreTwo() {
        let (view, _) = makeView(20)
        view.highlightItem(at: 2)
        view.handleKey(key(126)) // ↑ outward
        guard let outer = view.highlightedItemIndex else { return XCTFail("nothing selected") }
        XCTAssertGreaterThanOrEqual(outer, 8)
        view.handleKey(key(125)) // ↓ inward
        XCTAssertEqual(view.highlightedItemIndex, 2)
    }

    func testReturnActivatesEscapeCancelsTabCycles() {
        let (view, recorder) = makeView(6)
        view.handleKey(key(36))
        XCTAssertTrue(recorder.activated.isEmpty, "nothing selected yet")
        view.highlightItem(at: 3)
        view.handleKey(key(36))
        XCTAssertEqual(recorder.activated, ["i3"])
        view.handleKey(key(76)) // keypad Enter
        XCTAssertEqual(recorder.activated, ["i3", "i3"])
        view.handleKey(key(53))
        XCTAssertEqual(recorder.cancels, 1)
        view.handleKey(key(48, "\t"))
        view.handleKey(key(48, "\t", shift: true))
        XCTAssertEqual(recorder.cycles, [true, false])
    }

    func testNumberKeysJumpToSegments() {
        let (view, recorder) = makeView(24)
        view.handleKey(key(20, "3"))
        XCTAssertEqual(view.highlightedItemIndex, 2)
        view.handleKey(key(25, "9"))
        XCTAssertEqual(view.highlightedItemIndex, 8, "outer ring item")
        XCTAssertTrue(recorder.activated.isEmpty, "digits select, Return applies")
        let (small, _) = makeView(3)
        XCTAssertTrue(small.handleKey(key(23, "5")), "handled (beeps) even when out of range")
        XCTAssertNil(small.highlightedItemIndex)
    }

    func testDisabledItemsDoNotActivate() {
        let (view, recorder) = makeView(4, disabled: [1])
        view.highlightItem(at: 1)
        XCTAssertFalse(view.activateHighlighted())
        XCTAssertTrue(recorder.activated.isEmpty)
    }

    func testPagerFlipsPagesAndHighlightFollowsItems() {
        let (view, _) = makeView(30)
        XCTAssertEqual(view.radialLayout.pageCount, 2)
        view.highlightItem(at: 25) // lives on page 1
        XCTAssertEqual(view.radialLayout.page, 1)
        XCTAssertEqual(view.highlightedItemIndex, 25)
        view.handleKey(key(121)) // Page Down wraps to page 0
        XCTAssertEqual(view.radialLayout.page, 0)
        guard let pager = view.radialLayout.slots.firstIndex(where: \.isPager) else { return XCTFail("no pager") }
        view.setHighlightedSlot(pager, animated: false)
        XCTAssertTrue(view.activateHighlighted())
        XCTAssertEqual(view.radialLayout.page, 1)
    }

    func testPointerHoverUsesAngularHitTesting() {
        let (view, recorder) = makeView(8)
        let c = view.wheelCenter
        view.updateHover(at: NSPoint(x: c.x + 88, y: c.y)) // 3 o'clock = item 2
        XCTAssertEqual(view.highlightedItemIndex, 2)
        view.updateHover(at: NSPoint(x: c.x + 5, y: c.y + 5)) // dead zone
        XCTAssertNil(view.highlightedItemIndex)
        XCTAssertEqual(recorder.highlighted.compactMap { $0 }, ["i2"])
        XCTAssertEqual(view.itemIndex(at: NSPoint(x: c.x, y: c.y - 90)), 4)
        XCTAssertNotNil(view.frameForItem(at: 4))
    }

    func testMorphKeepsHighlightByIdentity() {
        let (view, _) = makeView(6)
        view.highlightItem(at: 4)
        var next = items(6)
        next.insert(RadialItem(id: "new", title: "New", symbolName: "star"), at: 0)
        view.setItems(next, animated: true)
        XCTAssertEqual(view.highlightedItem?.id, "i4")
        XCTAssertEqual(view.items.count, 7)
        view.setItems(items(3), animated: true)
        XCTAssertNil(view.highlightedItem, "item gone")
    }

    func testOptionsRequestedOnRightClick() {
        let (view, recorder) = makeView(6)
        recorder.hasOptions = true
        let c = view.wheelCenter
        guard let event = NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: c.x, y: c.y + 90), modifierFlags: [],
                                             timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1,
                                             pressure: 1) else { return XCTFail("event") }
        view.rightMouseDown(with: event)
        XCTAssertEqual(recorder.optionRequests, ["i0"])
    }

    func testAccessibilityElementPerSegment() {
        let (view, _) = makeView(5)
        view.menuTitle = "Convert"
        XCTAssertEqual(view.accessibilityLabel(), "Convert")
        let children = view.accessibilityChildren() ?? []
        XCTAssertEqual(children.count, 5)
        guard let first = children.first as? RadialSegmentElement else { return XCTFail("element type") }
        XCTAssertEqual(first.accessibilityRole(), .radioButton)
        XCTAssertEqual(first.accessibilityLabel(), "Item 0")
        XCTAssertFalse(first.isAccessibilitySelected())
        view.highlightItem(at: 0)
        XCTAssertTrue(first.isAccessibilitySelected())
        XCTAssertNotEqual(first.accessibilityFrameInParentSpace(), .zero)
    }

    func testEveryHitAreaIsPainted() {
        let (view, _) = makeView(8)
        guard let hit = view.hitTestLayerForTesting else { return XCTFail("no hit layer") }
        XCTAssertGreaterThanOrEqual(hit.fillColor?.alpha ?? 0, 0.005)
        let box = hit.path?.boundingBoxOfPath ?? .zero
        XCTAssertGreaterThanOrEqual(box.width / 2, view.radialLayout.outerRadius)
    }

    func testHitTestPassesThroughOutsideTheDisc() {
        let (view, _) = makeView(8)
        let c = view.wheelCenter
        XCTAssertTrue(view.hitTest(NSPoint(x: c.x + 60, y: c.y)) === view)
        XCTAssertNil(view.hitTest(NSPoint(x: 1, y: 1)), "canvas corners are click-through")
    }

    func testMovementGuardAfterEdgePush() {
        let (view, _) = makeView(8)
        let c = view.wheelCenter
        let start = NSPoint(x: c.x + 88, y: c.y) // pointer started over a segment
        view.movementGuard = start
        view.updateHover(at: start)
        XCTAssertNil(view.highlightedItemIndex, "no accidental selection under a pushed wheel")
        view.updateHover(at: NSPoint(x: start.x + 3, y: start.y))
        XCTAssertNil(view.highlightedItemIndex)
        view.updateHover(at: NSPoint(x: start.x + 12, y: start.y))
        XCTAssertEqual(view.highlightedItemIndex, 2)
        XCTAssertNil(view.movementGuard)
    }

    func testPanelArmsGuardOnlyWhenPushed() {
        let panel = RadialMenuPanel()
        let screen = RadialScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 800), backingScale: 2)
        panel.screensProvider = { [screen] }
        panel.menuView.setItems(items(6), animated: false)
        panel.show(at: CGPoint(x: 500, y: 400), animated: false)
        XCTAssertNil(panel.menuView.movementGuard, "centred on the pointer")
        panel.show(at: CGPoint(x: 995, y: 400), animated: false)
        XCTAssertNotNil(panel.menuView.movementGuard, "pushed in from the right edge")
        panel.dismiss(animated: false)
    }

    func testHighlightBitmapsRenderLazily() {
        let (view, _) = makeView(4)
        view.highlightItem(at: 1, animated: false)
        let image = RadialMenuSnapshot.render(view: view, backdrop: .none, cropToWheel: true, scale: 1)
        let side = ceil(2 * (view.wheelRadius + 22))
        XCTAssertEqual(image.size, CGSize(width: side, height: side))
    }

    func testDropZoneShowsWhenEmpty() {
        let (view, recorder) = makeView(0)
        view.dropZone = RadialDropZone(title: "Drop files")
        XCTAssertTrue(view.isShowingDropZone)
        let c = view.wheelCenter
        guard let click = NSEvent.mouseEvent(with: .leftMouseUp, location: c, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                             context: nil, eventNumber: 0, clickCount: 1, pressure: 0) else { return XCTFail("event") }
        view.mouseUp(with: click)
        XCTAssertEqual(recorder.cancels, 1, "click in the hub dismisses the empty ring")
        view.setItems(items(3), animated: true)
        XCTAssertFalse(view.isShowingDropZone)
    }
}

@MainActor
final class RadialMenuPanelTests: XCTestCase {
    func testPanelFollowsTheOverlayRecipe() {
        let panel = RadialMenuPanel()
        XCTAssertEqual(panel.level, .popUpMenu)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.styleMask.contains(.borderless) || panel.styleMask == [.nonactivatingPanel])
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.canBecomeKey, "never key during drags")
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.isOpaque)
        panel.allowsKeyboard = true
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.menuView.keyboardEnabled)
        XCTAssertTrue(panel.menuView.registeredDraggedTypes.contains(.fileURL), "registered before ordering in")
        XCTAssertTrue(RadialMenuPanel.defaultDraggedTypes.count > 1, "promises too")
    }

    func testPanelPositionsInsideInjectedScreens() {
        let panel = RadialMenuPanel()
        let screen = RadialScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 800), backingScale: 2)
        panel.screensProvider = { [screen] }
        panel.menuView.setItems((0..<6).map { RadialItem(id: "\($0)", title: "\($0)") }, animated: false)
        panel.show(at: CGPoint(x: 990, y: 790), animated: false)
        let c = panel.wheelCenterOnScreen
        XCTAssertLessThanOrEqual(c.x + panel.menuView.wheelRadius, 1000 - 8 + 0.5)
        XCTAssertLessThanOrEqual(c.y + panel.menuView.wheelRadius, 800 - 24 - 8 + 0.5)
        panel.dismiss(animated: false)
        XCTAssertFalse(panel.isVisible)
    }
}

@MainActor
final class RadialMenuSnapshotTests: XCTestCase {
    func testSnapshotHasRequestedSizeAndContent() throws {
        let items = (0..<8).map { RadialItem(id: "\($0)", title: "JPG", symbolName: "photo", prominence: .title) }
        let size = CGSize(width: 300, height: 300)
        let image = RadialMenuSnapshot.render(items: items, appearance: .dark, hoveredIndex: 2, size: size,
                                              hub: RadialHubContent(idleText: "2.4 MB"), backdrop: .none, scale: 2)
        XCTAssertEqual(image.size, size)
        let data = try XCTUnwrap(RadialMenuSnapshot.pngData(image))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, 600)
        XCTAssertEqual(rep.pixelsHigh, 600)
        // Corner transparent (no backdrop), a segment opaque-ish.
        XCTAssertLessThan(rep.colorAt(x: 2, y: 2)?.alphaComponent ?? 1, 0.05)
        let ringPixel = rep.colorAt(x: 300, y: 300 - Int(88 * 2 * (300.0 / RadialMenuConfiguration().canvasSide)))
        XCTAssertGreaterThan(ringPixel?.alphaComponent ?? 0, 0.5)
    }

    func testEveryAppearanceAndCountRenders() {
        let appearances: [RadialAppearance] = [
            .light, .dark, RadialAppearance(increaseContrast: true), RadialAppearance(isDark: true, reduceTransparency: true),
            RadialAppearance(reduceMotion: true),
        ]
        for a in appearances {
            for n in [1, 2, 7, 13, 24] {
                let items = (0..<n).map { RadialItem(id: "\($0)", title: "T\($0)", symbolName: "doc") }
                let image = RadialMenuSnapshot.render(items: items, appearance: a, hoveredIndex: n / 2, scale: 1)
                XCTAssertGreaterThan(image.size.width, 0)
                XCTAssertNotNil(RadialMenuSnapshot.pngData(image))
            }
        }
    }
}
