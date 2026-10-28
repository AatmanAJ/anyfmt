import AppKit
import XCTest
@testable import RadialMenu

@MainActor
private final class AimHost: RadialMenuViewDelegate {
    var options: Set<String> = []
    var presets: [String: [RadialPreset]] = [:]
    var drops: [RadialDropTarget] = []
    var locks: [Bool] = []
    var tunes: [String] = []
    func radialMenu(_ menu: RadialMenuView, hasOptionsFor item: RadialItem) -> Bool { options.contains(item.id) }
    func radialMenu(_ menu: RadialMenuView, presetsFor item: RadialItem) -> [RadialPreset] { presets[item.id] ?? [] }
    func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem, target: RadialDropTarget) -> Bool {
        drops.append(target)
        return true
    }
    func radialMenu(_ menu: RadialMenuView, didChangeLock locked: Bool) { locks.append(locked) }
    func radialMenu(_ menu: RadialMenuView, didRequestTuneFor item: RadialItem) { tunes.append(item.id) }
}

/// Aiming mid-drag: sticky selection, lock, tune lip, preset chips (PLAN-PHASE2 §B).
@MainActor
final class AimTests: XCTestCase {
    private func make(_ edit: (inout RadialMenuConfiguration) -> Void = { _ in }) -> (RadialMenuView, AimHost) {
        var config = RadialMenuConfiguration()
        config.presetBand = 44
        edit(&config)
        let view = RadialMenuView(configuration: config, style: RadialMenuStyle(), materialMode: .painted)
        let host = AimHost()
        view.delegate = host
        view.tuneModifier = nil // tests can't hold ⌥; the modifier path is covered by finalDropTarget below
        view.setItems((0..<8).map { RadialItem(id: "i\($0)", title: "Item \($0)", symbolName: "star") }, animated: false)
        return (view, host)
    }

    /// Point at a clock angle (degrees) and radius from the centre, in view coordinates.
    private func at(_ view: RadialMenuView, deg: CGFloat, r: CGFloat) -> NSPoint {
        let p = RadialLayout.point(angle: deg * .pi / 180, radius: r)
        return NSPoint(x: view.wheelCenter.x + p.x, y: view.wheelCenter.y + p.y)
    }

    private var ringMid: CGFloat { RadialMenuConfiguration().innerRing.mid }

    func testFirstHoverIsImmediateButSwitchingWaits() {
        let (view, _) = make()
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        XCTAssertEqual(view.highlightedItemIndex, 0, "nothing selected yet: immediate")
        view.updateHover(at: at(view, deg: 45, r: ringMid))
        XCTAssertEqual(view.highlightedItemIndex, 0, "a new wedge must hold for switchDelay")
        view.commitPendingSwitchForTesting()
        XCTAssertEqual(view.highlightedItemIndex, 1)
    }

    func testSwitchAfterTheDelayPasses() async throws {
        let (view, _) = make()
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        view.updateHover(at: at(view, deg: 45, r: ringMid))
        // The switch fires from a timer after switchDelay; wait for it (CI runners can be slow).
        for _ in 0..<40 where view.highlightedItemIndex != 1 {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(view.highlightedItemIndex, 1, "the delay re-checks without another drag event")
    }

    func testBriefWobbleNeverSwitches() {
        let (view, _) = make()
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        view.updateHover(at: at(view, deg: 45, r: ringMid))
        view.updateHover(at: at(view, deg: 5, r: ringMid))
        view.commitPendingSwitchForTesting()
        XCTAssertEqual(view.highlightedItemIndex, 0, "came back before the delay: no switch")
    }

    func testLockHoldsTheSelectionEverywhere() {
        let (view, host) = make()
        view.updateHover(at: at(view, deg: 90, r: ringMid))
        XCTAssertEqual(view.highlightedItemIndex, 2)
        view.toggleLock()
        XCTAssertTrue(view.isLocked)
        XCTAssertEqual(host.locks, [true])
        view.updateHover(at: at(view, deg: 200, r: ringMid))
        view.commitPendingSwitchForTesting()
        view.updateHover(at: view.wheelCenter) // the hub
        XCTAssertEqual(view.highlightedItemIndex, 2, "locked: drift and the hub don't change it")
        XCTAssertEqual(view.draggingUpdated(FakeDrag(at: view.wheelCenter)), .copy, "a drop in the hub lands on the lock")
        XCTAssertTrue(view.performDragOperation(FakeDrag(at: view.wheelCenter)))
        XCTAssertEqual(host.drops, [.item("i2")])
        view.toggleLock()
        XCTAssertEqual(host.locks, [true, false])
    }

    func testLockNeedsASelectionAndClearsOnNewItems() {
        let (view, host) = make()
        view.toggleLock()
        XCTAssertFalse(view.isLocked, "nothing highlighted: nothing to lock")
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        view.setLocked(true)
        view.setItems((0..<5).map { RadialItem(id: "n\($0)", title: "N\($0)", symbolName: "star") }, animated: false)
        XCTAssertFalse(view.isLocked)
        XCTAssertEqual(host.locks, [true, false])
    }

    func testTuneLipOnlyForItemsWithOptions() {
        let (view, host) = make()
        host.options = ["i0"]
        let outer = RadialMenuConfiguration().innerRing.outer
        view.updateHover(at: at(view, deg: 0, r: outer + 4)) // lifted outer edge
        XCTAssertEqual(view.highlightedItemIndex, 0)
        XCTAssertEqual(view.draggingUpdated(FakeDrag(at: at(view, deg: 0, r: outer + 4))), .copy)
        XCTAssertEqual(view.dropTarget, .tune("i0"))
        _ = view.draggingUpdated(FakeDrag(at: at(view, deg: 0, r: ringMid)))
        XCTAssertEqual(view.dropTarget, .item("i0"), "the body runs")
        host.options = []
        _ = view.draggingUpdated(FakeDrag(at: at(view, deg: 0, r: outer + 4)))
        XCTAssertEqual(view.dropTarget, .item("i0"), "no options: no lip")
    }

    func testPresetChipsShowOnLockAndTakeTheDrop() throws {
        let (view, host) = make()
        host.presets["i2"] = [RadialPreset(id: "small", title: "Small"), RadialPreset(id: "smooth", title: "Smooth"),
                              RadialPreset(id: "last", title: "Last used"), RadialPreset(id: "extra", title: "Extra")]
        view.updateHover(at: at(view, deg: 90, r: ringMid))
        view.setLocked(true)
        XCTAssertEqual(view.chipTitlesForTesting, ["Small", "Smooth", "Last used"], "at most three")
        let frames = view.chipFramesForTesting
        for f in frames {
            XCTAssertTrue(view.bounds.contains(f), "chips stay inside the canvas")
            XCTAssertGreaterThan(hypot(f.midX - view.wheelCenter.x, f.midY - view.wheelCenter.y),
                                 RadialMenuConfiguration().innerRing.outer, "outside the rim")
        }
        for (a, b) in zip(frames, frames.dropFirst()) { XCTAssertFalse(a.intersects(b), "chips don't overlap") }
        let chip = NSPoint(x: frames[1].midX, y: frames[1].midY)
        XCTAssertEqual(view.draggingUpdated(FakeDrag(at: chip)), .copy)
        XCTAssertEqual(view.dropTarget, .preset(item: "i2", preset: "smooth"))
        XCTAssertTrue(view.performDragOperation(FakeDrag(at: chip)))
        XCTAssertEqual(host.drops, [.preset(item: "i2", preset: "smooth")])
    }

    func testChipsAppearAfterTheDwell() async throws {
        let (view, host) = make { $0.presetDwell = 0.05 }
        host.presets["i0"] = [RadialPreset(id: "a", title: "A")]
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        XCTAssertTrue(view.chipTitlesForTesting.isEmpty)
        for _ in 0..<40 where view.chipTitlesForTesting.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(view.chipTitlesForTesting, ["A"])
        // The way out to the chip keeps the segment selected.
        let f = try XCTUnwrap(view.chipFramesForTesting.first)
        let between = NSPoint(x: (f.midX + view.wheelCenter.x) / 2 + (f.midX - view.wheelCenter.x) * 0.35,
                              y: (f.midY + view.wheelCenter.y) / 2 + (f.midY - view.wheelCenter.y) * 0.35)
        view.updateHover(at: between)
        XCTAssertEqual(view.highlightedItemIndex, 0)
    }

    func testNoPresetBandNoChips() {
        let (view, host) = make { $0.presetBand = 0 }
        host.presets["i0"] = [RadialPreset(id: "a", title: "A")]
        view.updateHover(at: at(view, deg: 0, r: ringMid))
        view.setLocked(true)
        XCTAssertTrue(view.chipTitlesForTesting.isEmpty)
    }

    func testKeyboardSpaceLocksOptionReturnTunes() throws {
        let (view, host) = make()
        host.options = ["i0"]
        view.keyboardEnabled = true
        view.highlightItem(at: 0, animated: false)
        let space = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                   context: nil, characters: " ", charactersIgnoringModifiers: " ",
                                                   isARepeat: false, keyCode: 49))
        XCTAssertTrue(view.handleKey(space))
        XCTAssertTrue(view.isLocked)
        let optReturn = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option], timestamp: 0,
                                                       windowNumber: 0, context: nil, characters: "\r",
                                                       charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertTrue(view.handleKey(optReturn))
        XCTAssertEqual(host.tunes, ["i0"])
    }
}
