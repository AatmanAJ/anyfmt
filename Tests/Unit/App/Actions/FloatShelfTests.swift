import AppKit
import XCTest
@testable import AnyfmtApp

@MainActor
final class FloatShelfModelTests: XCTestCase {
    private func u(_ name: String) -> URL { URL(fileURLWithPath: "/shelf/\(name)") }

    func testAddKeepsArrivalOrderAndStackShowsNewestOnTop() {
        var model = ShelfModel()
        model.add([u("a"), u("b")])
        model.add([u("c"), u("d")])
        XCTAssertEqual(model.items.map(\.name), ["a", "b", "c", "d"])
        XCTAssertEqual(model.stack.map(\.name), ["d", "c", "b"], "newest first, at most three drawn")
        XCTAssertEqual(model.count, 4)
    }

    func testDuplicatesAreRaisedNotReAdded() {
        var model = ShelfModel()
        model.add([u("a"), u("b"), u("c")])
        let original = model.items[0].id
        let change = model.add([u("a"), URL(fileURLWithPath: "/shelf/./a"), u("e"), u("e")])
        XCTAssertEqual(change.added.map(\.name), ["e"])
        XCTAssertEqual(change.raised.map(\.name), ["a"])
        XCTAssertEqual(model.items.map(\.name), ["b", "c", "a", "e"])
        XCTAssertEqual(model.items[2].id, original, "a raised item keeps its identity (and its pose)")
    }

    func testSymlinkedSpellingsAreTheSameItem() throws {
        let tmp = try TempFolder()
        let file = try tmp.file("doc.txt")
        let link = tmp.url.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tmp.url)
        var model = ShelfModel()
        model.add([file, link.appendingPathComponent("doc.txt")])
        XCTAssertEqual(model.count, 1)
    }

    func testRemoveByIDAndURLAndAll() {
        var model = ShelfModel()
        model.add([u("a"), u("b"), u("c")])
        let b = model.items[1].id
        XCTAssertEqual(model.remove(ids: [b]).removed.map(\.name), ["b"])
        XCTAssertEqual(model.remove(urls: [u("c")]).removed.map(\.name), ["c"])
        XCTAssertEqual(model.items.map(\.name), ["a"])
        XCTAssertEqual(model.removeAll().removed.map(\.name), ["a"])
        XCTAssertTrue(model.isEmpty)
        XCTAssertTrue(model.remove(ids: [UUID()]).isEmpty)
    }

    func testRefreshDropsMissingAndFollowsMoves() {
        var model = ShelfModel()
        model.add([u("keep"), u("gone"), u("moved")])
        let change = model.refresh { item in
            switch item.name {
            case "gone": return nil
            case "moved": return (URL(fileURLWithPath: "/elsewhere/renamed"), nil)
            default: return (item.url, nil)
            }
        }
        XCTAssertEqual(change.removed.map(\.name), ["gone"])
        XCTAssertEqual(change.relocated.map(\.name), ["renamed"])
        XCTAssertEqual(model.items.map(\.url.path), ["/shelf/keep", "/elsewhere/renamed"])
    }

    func testRefreshCollapsesItemsThatBecameTheSameFile() {
        var model = ShelfModel()
        model.add([u("x"), u("y")])
        let change = model.refresh { _ in (URL(fileURLWithPath: "/shelf/x"), nil) }
        XCTAssertEqual(model.items.map(\.name), ["x"])
        XCTAssertEqual(change.removed.count, 1)
    }

    func testPoseIsStableAndWithinBounds() {
        for _ in 0..<200 {
            let id = UUID()
            let pose = ShelfPose.pose(for: id)
            XCTAssertEqual(pose, ShelfPose.pose(for: id))
            XCTAssertLessThanOrEqual(abs(pose.angle), ShelfPose.maxAngle + 1e-9)
            XCTAssertLessThanOrEqual(abs(pose.dx), ShelfPose.maxOffset + 1e-9)
            XCTAssertLessThanOrEqual(abs(pose.dy), ShelfPose.maxOffset + 1e-9)
        }
        let a = ShelfPose.pose(for: UUID(uuidString: "00000000-0000-4000-8000-000000000000")!)
        let b = ShelfPose.pose(for: UUID(uuidString: "FFFFFFFF-0000-4000-8000-000000000000")!)
        XCTAssertNotEqual(a.angle, b.angle, "different items lie differently")
    }

    func testGridNamesBreakBetweenWordsOrBeforeTheExtension() {
        let font = NSFont.systemFont(ofSize: 11)
        let width: CGFloat = 70
        func lines(_ s: String) -> [String] { ShelfNameLayout.lines(for: s, font: font, width: width).components(separatedBy: "\n") }
        XCTAssertEqual(lines("a.png"), ["a.png"])
        let golden = lines("Golden Hour Bay.jpg")
        XCTAssertEqual(golden.count, 2)
        XCTAssertFalse(golden.joined().contains("…"), "two words-wrapped lines, nothing cut")
        XCTAssertFalse(golden[0].hasSuffix(" ") || golden[1].hasPrefix(" "))
        let long = lines("Quarterly Planning Review Final Version Approved.pdf")
        XCTAssertEqual(long.count, 2)
        XCTAssertTrue(long[1].hasSuffix(".pdf"), "the extension survives truncation")
        for line in long { XCTAssertLessThanOrEqual(ShelfNameLayout.measure(line, font), width) }
        let word = lines("Supercalifragilisticexpialidocious.mov")
        XCTAssertTrue(word.allSatisfy { ShelfNameLayout.measure($0, font) <= width })
        XCTAssertTrue(word.joined().hasSuffix(".mov"))
        XCTAssertFalse(lines("Interview.mov").joined().contains("…"), "a short name splits before its extension, untruncated")
    }

    // MARK: Presence (auto-dismiss)

    func testPresenceShowsOnFirstAddAndHidesWhenEmptied() {
        var presence = ShelfPresence()
        var model = ShelfModel()
        model.add([u("a")])
        XCTAssertEqual(presence.itemsAdded(model), .show)
        model.add([u("b")])
        XCTAssertEqual(presence.itemsAdded(model), .none)
        model.remove(urls: [u("a")])
        XCTAssertEqual(presence.itemsRemoved(model), .none)
        model.remove(urls: [u("b")])
        XCTAssertEqual(presence.itemsRemoved(model), .hide)
        XCTAssertFalse(presence.isVisible)
    }

    func testEmptyShelfOpenedByToggleStaysUntilUsed() {
        var presence = ShelfPresence()
        var model = ShelfModel()
        XCTAssertEqual(presence.toggle(model), .show)
        XCTAssertTrue(presence.isHeldOpenEmpty)
        XCTAssertEqual(presence.itemsRemoved(model), .none, "an empty shelf opened on purpose doesn't vanish")
        model.add([u("a")])
        XCTAssertEqual(presence.itemsAdded(model), .none)
        model.removeAll()
        XCTAssertEqual(presence.itemsRemoved(model), .hide, "once used and emptied, it dismisses itself")
    }

    func testToggleHidesWithItemsAndShowsThemAgain() {
        var presence = ShelfPresence()
        var model = ShelfModel()
        model.add([u("a")])
        _ = presence.itemsAdded(model)
        XCTAssertEqual(presence.toggle(model), .hide)
        XCTAssertEqual(presence.toggle(model), .show)
        XCTAssertFalse(presence.isHeldOpenEmpty)
    }
}

@MainActor
final class FloatShelfControllerTests: XCTestCase {
    private func u(_ name: String) -> URL { URL(fileURLWithPath: "/shelf/\(name)") }

    func testFirstAddPresentsAtTheDropPointThenUpdates() {
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter)
        shelf.add(urls: [u("a"), u("b")], near: CGPoint(x: 300, y: 400))
        shelf.add(urls: [u("c")], near: CGPoint(x: 1, y: 1))
        XCTAssertEqual(presenter.calls, [.show(count: 2, near: CGPoint(x: 300, y: 400)),
                                         .update(count: 3, added: 1, removed: 0, raised: 0)])
        XCTAssertTrue(shelf.isVisible)
        XCTAssertEqual(shelf.count, 3)
    }

    func testRemovingTheLastItemDismisses() {
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter)
        shelf.add(urls: [u("a"), u("b")])
        presenter.reset()
        let ids = Set(shelf.model.items.map(\.id))
        shelf.handle(.remove([ids.first!]))
        XCTAssertTrue(shelf.isVisible)
        shelf.handle(.remove(ids))
        XCTAssertEqual(presenter.calls.last, .hide)
        XCTAssertFalse(shelf.isVisible)
    }

    func testClearOnAnEmptyHeldOpenShelfCloses() {
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter)
        shelf.toggle()
        XCTAssertEqual(presenter.calls, [.show(count: 0, near: nil)])
        shelf.handle(.clear)
        XCTAssertEqual(presenter.calls.last, .hide)
        XCTAssertFalse(shelf.isVisible)
    }

    func testDragOutRules() {
        XCTAssertTrue(FloatShelf.shouldRemoveAfterDrag(operation: .copy, keepOnShelf: false), "plain drag-out removes")
        XCTAssertTrue(FloatShelf.shouldRemoveAfterDrag(operation: .move, keepOnShelf: false))
        XCTAssertFalse(FloatShelf.shouldRemoveAfterDrag(operation: .copy, keepOnShelf: true), "Option keeps it")
        XCTAssertTrue(FloatShelf.shouldRemoveAfterDrag(operation: .move, keepOnShelf: true), "a moved file can't stay")
        XCTAssertFalse(FloatShelf.shouldRemoveAfterDrag(operation: [], keepOnShelf: false), "a cancelled drag keeps it")
    }

    func testDragEndedRemovesTheDraggedItems() {
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter)
        shelf.add(urls: [u("a"), u("b")])
        let a = shelf.model.items[0].id
        shelf.handle(.dragEnded([a], operation: .copy, keepOnShelf: true))
        XCTAssertEqual(shelf.count, 2)
        shelf.handle(.dragEnded([a], operation: .copy, keepOnShelf: false))
        XCTAssertEqual(shelf.urls.map(\.lastPathComponent), ["b"])
    }

    func testRefreshPrunesDeletedFilesAndDismisses() throws {
        let tmp = try TempFolder()
        let file = try tmp.file("temp.txt")
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter, locate: FloatShelf.locateOnDisk)
        shelf.add(urls: [file])
        try FileManager.default.removeItem(at: file)
        shelf.handle(.hovered)
        XCTAssertEqual(shelf.count, 0)
        XCTAssertEqual(presenter.calls.last, .hide)
    }

    func testBookmarksFollowARename() throws {
        let tmp = try TempFolder()
        let file = try tmp.file("draft.txt")
        var item = ShelfItem(url: file, bookmark: FloatShelf.bookmark(file))
        let renamed = tmp.url.appendingPathComponent("final.txt")
        try FileManager.default.moveItem(at: file, to: renamed)
        let found = FloatShelf.locateOnDisk(item)
        XCTAssertEqual(found?.url.resolvingSymlinksInPath().path, renamed.path)
        item = ShelfItem(url: renamed)
        try FileManager.default.removeItem(at: renamed)
        XCTAssertNil(FloatShelf.locateOnDisk(item))
        XCTAssertTrue(FloatShelf.isInTrash(URL(fileURLWithPath: "/Users/me/.Trash/x.png")))
    }

    func testMovedCommandSavesThePosition() {
        let presenter = FakeShelfPresenter()
        let defaults = makeTestDefaults()
        let shelf = makeTestShelf(presenter: presenter, defaults: defaults)
        shelf.add(urls: [u("a")])
        shelf.handle(.moved)
        XCTAssertEqual(ActionPreferences(defaults: defaults).shelfOrigin, CGPoint(x: 100, y: 200))
    }

    func testSummaryStrings() throws {
        let tmp = try TempFolder()
        let a = try tmp.file("a.png"), b = try tmp.file("b.jpg"), d = try tmp.folder("Dir")
        let m = try tmp.file("m.mov"), p = try tmp.file("p.pdf"), t = try tmp.file("t.txt")
        XCTAssertEqual(ShelfSummary.kinds(for: [a, b]), "2 images")
        XCTAssertEqual(ShelfSummary.kinds(for: [a, b, d]), "2 images, 1 folder")
        XCTAssertEqual(ShelfSummary.kinds(for: [a, m, p]), "1 image, 1 video, 1 PDF")
        XCTAssertEqual(ShelfSummary.kinds(for: [a, b, m, p, d, t]), "2 images, 1 video, +3 more")
    }
}
