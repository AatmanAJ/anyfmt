import AppKit
import XCTest
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class ClipboardActionTests: XCTestCase {
    // MARK: Copy Path formatting

    func testSinglePathIsPlainPOSIX() {
        let u = URL(fileURLWithPath: "/Users/me/Desktop/report.pdf")
        XCTAssertEqual(PathFormatter.posixPaths([u]), "/Users/me/Desktop/report.pdf")
    }

    func testMultiplePathsAreNewlineSeparatedWithNoTrailingNewline() {
        let urls = ["/a/one.txt", "/a/two.txt", "/b/three"].map { URL(fileURLWithPath: $0) }
        let text = PathFormatter.posixPaths(urls)
        XCTAssertEqual(text, "/a/one.txt\n/a/two.txt\n/b/three")
        XCTAssertFalse(text.hasSuffix("\n"))
    }

    func testSpacesAndUnicodeAreKeptVerbatim() {
        let urls = [URL(fileURLWithPath: "/Users/me/My Files/Café ✨ 写真.jpg"),
                    URL(fileURLWithPath: "/tmp/naïve résumé.docx")]
        XCTAssertEqual(PathFormatter.posixPaths(urls), "/Users/me/My Files/Café ✨ 写真.jpg\n/tmp/naïve résumé.docx")
    }

    func testFolderHasNoTrailingSlashAndDotsAreStandardized() {
        let folder = URL(fileURLWithPath: "/Users/me/Projects/", isDirectory: true)
        XCTAssertEqual(PathFormatter.posixPath(folder), "/Users/me/Projects")
        XCTAssertEqual(PathFormatter.posixPath(URL(fileURLWithPath: "/Users/me/a/../b.txt")), "/Users/me/b.txt")
    }

    func testShellQuoting() {
        XCTAssertEqual(PathFormatter.shellQuote("/usr/local/bin"), "/usr/local/bin")
        XCTAssertEqual(PathFormatter.shellQuote("/tmp/a b"), "'/tmp/a b'")
        XCTAssertEqual(PathFormatter.shellQuote("/tmp/it's"), "'/tmp/it'\\''s'")
        XCTAssertEqual(PathFormatter.shellQuote("/tmp/$HOME;rm"), "'/tmp/$HOME;rm'")
        XCTAssertEqual(PathFormatter.shellQuote("/tmp/Café"), "'/tmp/Café'")
        XCTAssertEqual(PathFormatter.shellQuote(""), "''")
    }

    func testShellEscapedPathsAreSpaceSeparated() {
        let urls = [URL(fileURLWithPath: "/a/plain.txt"), URL(fileURLWithPath: "/a/with space.txt")]
        XCTAssertEqual(PathFormatter.shellEscapedPaths(urls), "/a/plain.txt '/a/with space.txt'")
    }

    // MARK: Copy (files on an injected pasteboard)

    func testCopyWritesFileURLsAndAPlainTextFallback() throws {
        let tmp = try TempFolder()
        let a = try tmp.file("one.txt")
        let b = try tmp.folder("Folder With Space")
        let pb = makeTestPasteboard()
        defer { pb.releaseGlobally() }

        XCTAssertTrue(FileClipboard.copyFiles([a, b], to: pb))

        let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(urls?.map(\.standardizedFileURL.path), [a.path, b.path])
        XCTAssertEqual(pb.pasteboardItems?.count, 2)
        XCTAssertEqual(pb.string(forType: .string), "\(a.path)\n\(b.path)")
    }

    func testCopyNothingFails() {
        let pb = makeTestPasteboard()
        defer { pb.releaseGlobally() }
        XCTAssertFalse(FileClipboard.copyFiles([], to: pb))
    }

    func testCopyActionThroughPerformer() async throws {
        let tmp = try TempFolder()
        let a = try tmp.file("photo.jpg")
        let pb = makeTestPasteboard()
        defer { pb.releaseGlobally() }
        let performer = makePerformer(pasteboard: pb)

        let outcome = await performer.perform(ActionIDs.copy, urls: [a, a], at: .zero)

        XCTAssertEqual(outcome, .done("Copied “photo.jpg”"))
        let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertEqual(urls?.count, 1, "the same file twice is copied once")
    }

    func testCopyPathActionPlainAndOptionVariant() async throws {
        let tmp = try TempFolder()
        let a = try tmp.file("a b.txt")
        let c = try tmp.file("c.txt")
        let pb = makeTestPasteboard()
        defer { pb.releaseGlobally() }

        final class Flags { var value: NSEvent.ModifierFlags = [] }
        let flags = Flags()
        let performer = makePerformer(pasteboard: pb, modifiers: { flags.value })
        let plain = await performer.perform(ActionIDs.copyPath, urls: [a, c], at: .zero)
        XCTAssertEqual(plain, .done("Copied 2 paths"))
        XCTAssertEqual(pb.string(forType: .string), "\(a.path)\n\(c.path)")

        flags.value = [.option]
        _ = await performer.perform(ActionIDs.copyPath, urls: [a, c], at: .zero)
        XCTAssertEqual(pb.string(forType: .string), "'\(a.path)' \(c.path)")
    }

    private func makePerformer(pasteboard: NSPasteboard,
                               modifiers: @escaping @MainActor () -> NSEvent.ModifierFlags = { [] }) -> ActionPerformer {
        let presenter = FakeShelfPresenter()
        return ActionPerformer(preferences: ActionPreferences(defaults: makeTestDefaults()),
                               pasteboard: pasteboard,
                               shelf: makeTestShelf(presenter: presenter),
                               intake: PromiseIntake(root: FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-r-\(UUID().uuidString)")),
                               appLookup: { _ in nil },
                               openTerminal: { _ in },
                               chooseDestination: { _, _, _ in nil },
                               modifierFlags: modifiers)
    }
}
