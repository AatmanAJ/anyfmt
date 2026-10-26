import AppKit
import XCTest
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class MoveActionTests: XCTestCase {
    // MARK: Collision naming, never overwrite

    func testMoveIntoEmptyFolderKeepsName() throws {
        let tmp = try TempFolder()
        let src = try tmp.file("from/photo.jpg", contents: "new")
        let dest = try tmp.folder("to")

        let report = FileMover().move([src], into: dest)

        XCTAssertEqual(report.moved.map(\.destination.lastPathComponent), ["photo.jpg"])
        XCTAssertFalse(report.moved[0].wasRenamed)
        XCTAssertEqual(tmp.read("to/photo.jpg"), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
    }

    func testCollisionsGetFinderStyleNamesAndNothingIsOverwritten() throws {
        let tmp = try TempFolder()
        try tmp.file("to/photo.jpg", contents: "old-1")
        try tmp.file("to/photo 2.jpg", contents: "old-2")
        let src = try tmp.file("from/photo.jpg", contents: "new")
        let dest = tmp.url.appendingPathComponent("to")

        let report = FileMover().move([src], into: dest)

        XCTAssertEqual(report.moved.first?.destination.lastPathComponent, "photo 3.jpg")
        XCTAssertTrue(report.moved.first?.wasRenamed ?? false)
        XCTAssertEqual(tmp.read("to/photo.jpg"), "old-1")
        XCTAssertEqual(tmp.read("to/photo 2.jpg"), "old-2")
        XCTAssertEqual(tmp.read("to/photo 3.jpg"), "new")
    }

    func testFolderPackageCompoundAndDotfileCollisions() throws {
        let tmp = try TempFolder()
        try tmp.folder("to/Project")
        try tmp.file("to/Project/keep.txt", contents: "keep")
        try tmp.file("to/archive.tar.gz")
        try tmp.file("to/.zshrc")
        try tmp.file("to/Makefile")
        let folder = try tmp.folder("from/Project")
        try tmp.file("from/Project/inner.txt", contents: "inner")
        let tarball = try tmp.file("from/archive.tar.gz")
        let dot = try tmp.file("from/.zshrc")
        let make = try tmp.file("from/Makefile")
        let dest = tmp.url.appendingPathComponent("to")

        let report = FileMover().move([folder, tarball, dot, make], into: dest)

        XCTAssertEqual(report.failures, [])
        XCTAssertEqual(Set(report.moved.map(\.destination.lastPathComponent)),
                       ["Project 2", "archive 2.tar.gz", ".zshrc 2", "Makefile 2"])
        XCTAssertEqual(tmp.read("to/Project/keep.txt"), "keep", "the existing folder is untouched")
        XCTAssertEqual(tmp.read("to/Project 2/inner.txt"), "inner")
        XCTAssertNil(tmp.read("to/Project/inner.txt"), "folders are never merged")
    }

    func testNameParts() {
        func parts(_ name: String, dir: Bool = false, pkg: Bool = false) -> String {
            let p = FileMover.nameParts(of: URL(fileURLWithPath: "/x/\(name)"), isDirectory: dir, isPackage: pkg)
            return "\(p.base)|\(p.ext)"
        }
        XCTAssertEqual(parts("photo.jpg"), "photo|jpg")
        XCTAssertEqual(parts("Report.v2.final.docx"), "Report.v2.final|docx")
        XCTAssertEqual(parts("a.tar.gz"), "a|tar.gz")
        XCTAssertEqual(parts("Makefile"), "Makefile|")
        XCTAssertEqual(parts(".zshrc"), ".zshrc|")
        XCTAssertEqual(parts("my.folder", dir: true), "my.folder|")
        XCTAssertEqual(parts("Tool.app", dir: true, pkg: true), "Tool|app")
    }

    func testMovesFromSeveralFoldersAndReportsAlreadyThere() throws {
        let tmp = try TempFolder()
        let a = try tmp.file("one/a.txt")
        let b = try tmp.file("two/b.txt")
        let here = try tmp.file("dest/here.txt")
        let dest = tmp.url.appendingPathComponent("dest")

        let report = FileMover().move([a, b, here], into: dest)

        XCTAssertEqual(report.moved.map(\.destination.lastPathComponent), ["a.txt", "b.txt"])
        XCTAssertEqual(report.alreadyThere, [here])
        XCTAssertEqual(tmp.names(in: "dest"), ["a.txt", "b.txt", "here.txt"])
        XCTAssertEqual(tmp.names(in: "one"), [])
    }

    func testCrossVolumePathCopiesThenRemovesAndNeverOverwrites() throws {
        let tmp = try TempFolder()
        try tmp.file("to/movie.mov", contents: "existing")
        let src = try tmp.file("from/movie.mov", contents: "moving")
        let folder = try tmp.folder("from/Album")
        try tmp.file("from/Album/1.jpg", contents: "one")
        let dest = tmp.url.appendingPathComponent("to")

        let report = FileMover(simulateCrossVolume: true).move([src, folder], into: dest)

        XCTAssertEqual(report.failures, [])
        XCTAssertEqual(report.moved.map(\.destination.lastPathComponent), ["movie 2.mov", "Album"])
        XCTAssertEqual(tmp.read("to/movie.mov"), "existing")
        XCTAssertEqual(tmp.read("to/movie 2.mov"), "moving")
        XCTAssertEqual(tmp.read("to/Album/1.jpg"), "one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(tmp.names(in: "to").contains { $0.hasPrefix(".") }, "no staging leftovers")
    }

    // MARK: Refusals

    func testRefusesMovingAFolderIntoItselfOrItsSubfolder() throws {
        let tmp = try TempFolder()
        let folder = try tmp.folder("Work")
        let inner = try tmp.folder("Work/Inner/Deeper")
        let file = try tmp.file("loose.txt")
        let mover = FileMover()

        XCTAssertEqual(mover.check([folder], into: folder), .intoItself("Work"))
        XCTAssertEqual(mover.check([file, folder], into: inner), .intoItself("Work"))
        XCTAssertEqual(mover.check([folder], into: inner)?.message, "“Work” can’t be moved into itself.")

        let report = mover.move([file, folder], into: inner)
        XCTAssertTrue(report.moved.isEmpty, "a refused move touches nothing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }

    func testRefusalThroughSymlinkedPath() throws {
        let tmp = try TempFolder()
        let folder = try tmp.folder("Real")
        try tmp.folder("Real/Sub")
        let link = tmp.url.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        XCTAssertEqual(FileMover().check([folder], into: link.appendingPathComponent("Sub")), .intoItself("Real"))
    }

    func testMovingASymlinkIntoItsTargetIsAllowed() throws {
        let tmp = try TempFolder()
        let folder = try tmp.folder("Target")
        let link = tmp.url.appendingPathComponent("Shortcut")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        XCTAssertNil(FileMover().check([link], into: folder))
        let report = FileMover().move([link], into: folder)
        XCTAssertEqual(report.moved.count, 1)
        let moved = folder.appendingPathComponent("Shortcut").path
        XCTAssertNotNil(try? FileManager.default.destinationOfSymbolicLink(atPath: moved), "moved as a link")
    }

    func testMissingOrNonFolderDestination() throws {
        let tmp = try TempFolder()
        let file = try tmp.file("a.txt")
        XCTAssertEqual(FileMover().check([file], into: tmp.url.appendingPathComponent("nope")), .destinationMissing("nope"))
        XCTAssertEqual(FileMover().check([file], into: file), .destinationNotFolder("a.txt"))
        XCTAssertEqual(FileMover().check([], into: tmp.url), .nothingToMove)
    }

    // MARK: Through the performer

    func testMoveActionUsesChooserRecordsRecentAndReports() async throws {
        let tmp = try TempFolder()
        let a = try tmp.file("in/a.txt")
        let b = try tmp.file("in/b.txt")
        try tmp.file("out/b.txt", contents: "keep")
        let out = tmp.url.appendingPathComponent("out")
        let prefs = ActionPreferences(defaults: makeTestDefaults())
        var offered: [URL] = []
        let performer = makePerformer(prefs: prefs) { _, recents, _ in offered = recents; return out }

        let outcome = await performer.perform(ActionIDs.move, urls: [a, b], at: CGPoint(x: 10, y: 10))

        XCTAssertEqual(outcome, .done("Moved 2 items to “out” (1 renamed to avoid replacing)"))
        XCTAssertEqual(tmp.names(in: "out"), ["a.txt", "b 2.txt", "b.txt"])
        XCTAssertEqual(tmp.read("out/b.txt"), "keep")
        XCTAssertEqual(offered, [])
        XCTAssertEqual(prefs.recentFolders.map(\.path), [out.path])
    }

    func testMoveActionCancelAndRefusal() async throws {
        let tmp = try TempFolder()
        let folder = try tmp.folder("Box")
        let inner = try tmp.folder("Box/Inside")

        let cancelled = await makePerformer { _, _, _ in nil }.perform(ActionIDs.move, urls: [folder], at: .zero)
        XCTAssertEqual(cancelled, .cancelled)

        let refused = await makePerformer { _, _, _ in inner }.perform(ActionIDs.move, urls: [folder], at: .zero)
        XCTAssertEqual(refused, .failed("“Box” can’t be moved into itself."))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inner.path))
    }

    func testMoveOutcomeMessages() {
        let dest = URL(fileURLWithPath: "/Users/me/Documents", isDirectory: true)
        let one = MovedItem(source: URL(fileURLWithPath: "/a/x.png"), destination: URL(fileURLWithPath: "/Users/me/Documents/x.png"))
        let renamed = MovedItem(source: URL(fileURLWithPath: "/a/y.png"), destination: URL(fileURLWithPath: "/Users/me/Documents/y 2.png"))
        let fail = MoveFailure(item: URL(fileURLWithPath: "/a/z.png"), message: "You don’t have permission to move “z.png”.")

        XCTAssertEqual(ActionPerformer.outcome(of: MoveReport(moved: [one]), destination: dest), .done("Moved “x.png” to “Documents”"))
        XCTAssertEqual(ActionPerformer.outcome(of: MoveReport(moved: [renamed]), destination: dest), .done("Moved to “Documents” as “y 2.png”"))
        XCTAssertEqual(ActionPerformer.outcome(of: MoveReport(alreadyThere: [one.source]), destination: dest), .done("Already in “Documents”"))
        XCTAssertEqual(ActionPerformer.outcome(of: MoveReport(failures: [fail]), destination: dest), .failed(fail.message))
        XCTAssertEqual(ActionPerformer.outcome(of: MoveReport(moved: [one], failures: [fail]), destination: dest),
                       .failed("Moved 1 of 2 items. \(fail.message)"))
    }

    // MARK: Chooser candidates

    func testChooserHidesCurrentFolderAndFoldersInsideTheMovedItems() throws {
        let tmp = try TempFolder()
        let docs = try tmp.folder("Documents")
        let box = try tmp.folder("Box")
        let inBox = try tmp.folder("Box/Sub")
        let other = try tmp.folder("Other")
        let file = try tmp.file("Documents/a.txt")

        XCTAssertEqual(MoveChooser.candidates(recents: [docs, other, inBox], items: [file]).map(\.lastPathComponent),
                       ["Other", "Sub"], "the folder the file is already in is hidden")
        XCTAssertEqual(MoveChooser.candidates(recents: [docs, inBox, box, other], items: [box]).map(\.lastPathComponent),
                       ["Documents", "Other"], "a folder's own subfolders (and itself) are hidden")
    }

    private func makePerformer(prefs: ActionPreferences? = nil,
                               choose: @escaping @MainActor ([URL], [URL], CGPoint) async -> URL?) -> ActionPerformer {
        ActionPerformer(preferences: prefs ?? ActionPreferences(defaults: makeTestDefaults()),
                        pasteboard: makeTestPasteboard(),
                        shelf: makeTestShelf(presenter: FakeShelfPresenter()),
                        intake: PromiseIntake(root: FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-r-\(UUID().uuidString)")),
                        appLookup: { _ in nil },
                        openTerminal: { _ in },
                        chooseDestination: choose,
                        modifierFlags: { [] })
    }
}
