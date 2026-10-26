import AppKit
import XCTest
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class ActionPerformerTests: XCTestCase {
    private func makePerformer(shelf: FloatShelf? = nil, intakeRoot: URL? = nil) -> ActionPerformer {
        ActionPerformer(preferences: ActionPreferences(defaults: makeTestDefaults()),
                        pasteboard: makeTestPasteboard(),
                        shelf: shelf ?? makeTestShelf(presenter: FakeShelfPresenter()),
                        intake: PromiseIntake(root: intakeRoot ?? FileManager.default.temporaryDirectory
                            .appendingPathComponent("anyfmt-r-\(UUID().uuidString)")),
                        appLookup: { _ in nil }, openTerminal: { _ in },
                        chooseDestination: { _, _, _ in nil }, modifierFlags: { [] })
    }

    func testSupportsTheSixLocalActionsOnly() {
        let performer = makePerformer()
        for spec in ActionCatalog.all {
            XCTAssertEqual(performer.supports(spec.id), spec.id != ActionIDs.shareLink, spec.id.rawValue)
        }
        XCTAssertFalse(performer.supports("nope"))
        XCTAssertEqual(Set(ActionPerformer.localActions), Set(ActionCatalog.local.map(\.id)))
    }

    func testShareLinkIsNotHandledHere() async {
        let outcome = await makePerformer().perform(ActionIDs.shareLink, urls: [URL(fileURLWithPath: "/tmp")], at: .zero)
        XCTAssertEqual(outcome, .failed("This action isn’t available."))
    }

    func testNothingToWorkWith() async {
        let outcome = await makePerformer().perform(ActionIDs.copy, urls: [], at: .zero)
        XCTAssertEqual(outcome, .failed("There’s nothing to work with."))
    }

    func testFloatParksItemsOnTheShelfAtTheDropPoint() async throws {
        let tmp = try TempFolder()
        let file = try tmp.file("a.txt")
        let folder = try tmp.folder("Stuff")
        let presenter = FakeShelfPresenter()
        let shelf = makeTestShelf(presenter: presenter)
        let outcome = await makePerformer(shelf: shelf).perform(ActionIDs.float, urls: [file, folder], at: CGPoint(x: 50, y: 60))
        XCTAssertEqual(outcome, .done(nil))
        XCTAssertEqual(shelf.urls.map(\.lastPathComponent), ["a.txt", "Stuff"])
        XCTAssertEqual(presenter.calls.first, .show(count: 2, near: CGPoint(x: 50, y: 60)))
    }

    func testUniqueKeepsOrderAndDropsSameFile() {
        let a = URL(fileURLWithPath: "/x/a"), b = URL(fileURLWithPath: "/x/b")
        XCTAssertEqual(ActionPerformer.unique([a, b, URL(fileURLWithPath: "/x/./a"), b]), [a, b])
    }

    // MARK: Promise intake paths

    func testReceivedFolderLivesInApplicationSupportUnderTheBrand() {
        let root = PromiseIntake.defaultRoot
        XCTAssertEqual(root.lastPathComponent, "Received")
        XCTAssertEqual(root.deletingLastPathComponent().lastPathComponent, Brand.name)
        XCTAssertEqual(root.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Application Support")
    }

    func testBatchFoldersAreUniqueUUIDFoldersUnderTheRoot() throws {
        let tmp = try TempFolder()
        let intake = PromiseIntake(root: tmp.url.appendingPathComponent("Received"))
        let id = UUID()
        XCTAssertEqual(intake.folder(for: id), intake.root.appendingPathComponent(id.uuidString, isDirectory: true))
        let one = try intake.makeFolder()
        let two = try intake.makeFolder()
        XCTAssertNotEqual(one, two)
        XCTAssertNotNil(UUID(uuidString: one.lastPathComponent))
        XCTAssertTrue(ActionPreferences.directoryExists(one))
        XCTAssertTrue(intake.contains(one.appendingPathComponent("mail.pdf")))
        XCTAssertFalse(intake.contains(tmp.url.appendingPathComponent("elsewhere.pdf")))
        XCTAssertFalse(intake.contains(intake.root), "the root itself isn't a received file")
    }

    func testPurgeRemovesOnlyOldBatchFolders() throws {
        let tmp = try TempFolder()
        let intake = PromiseIntake(root: tmp.url.appendingPathComponent("Received"))
        let old = try intake.makeFolder()
        let fresh = try intake.makeFolder()
        let notOurs = intake.root.appendingPathComponent("Keep Me", isDirectory: true)
        try FileManager.default.createDirectory(at: notOurs, withIntermediateDirectories: true)
        let longAgo = Date().addingTimeInterval(-10 * 24 * 3600)
        try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: notOurs.path)

        XCTAssertEqual(intake.purge(), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: notOurs.path), "only UUID-named batches are ours")
    }

    func testReceivingNoPromisesReturnsNothing() async throws {
        let tmp = try TempFolder()
        let files = try await PromiseIntake(root: tmp.url).receive([])
        XCTAssertEqual(files, [])
    }
}
