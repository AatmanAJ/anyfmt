import XCTest
import HaloCore
@testable import HaloApp

/// Inbox: items sent from a phone/browser are downloaded into the chosen
/// folder with collision-safe, sanitised names, verified and acknowledged.
@MainActor
final class InboxServiceTests: MockServerTestCase {
    /// Turning the inbox on starts the poller, which checks once straight away.
    /// Manual tests use a long interval and wait for that first (empty) check.
    private func signedInWithInbox(interval: Duration = .seconds(3600)) async throws -> (CloudFixture, URL) {
        try await mock.setUser(plan: "pro")
        let f = try fixture(inboxInterval: interval)
        try await f.signIn()
        let folder = f.directory.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        f.services.session.setInboxFolder(folder)
        f.services.session.setInboxEnabled(true)
        try await waitUntil("first automatic check") { await f.services.inbox.lastCheck != nil }
        return (f, folder)
    }

    func testDownloadsIntoFolderCollisionSafeAndAcks() async throws {
        let (f, folder) = try await signedInWithInbox()
        let existing = folder.appendingPathComponent("photo.jpg")
        try Data("already here".utf8).write(to: existing)
        try await mock.call("POST", "/__mock/inbox", ["name": "photo.jpg", "content": "from phone"])
        try await mock.call("POST", "/__mock/inbox", ["name": "../../evil.txt", "content": "nope", "source": "browser"])
        try await mock.call("POST", "/__mock/inbox", ["name": ".hidden", "content": "dot"])

        let placed = try await f.services.inbox.checkNow()

        XCTAssertEqual(placed.map(\.lastPathComponent), ["photo 2.jpg", "evil.txt", "hidden"])
        for url in placed {
            XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, folder.standardizedFileURL, "stayed inside the folder")
        }
        XCTAssertEqual(try String(contentsOf: placed[0], encoding: .utf8), "from phone")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "already here", "never overwrites")
        let server = try await mock.items("/__mock/inbox")
        XCTAssertEqual(server.compactMap { $0["status"] as? String }, ["delivered", "delivered", "delivered"])
        let acks = try await mock.requestCount("POST", prefix: "/v1/inbox/")
        XCTAssertEqual(acks, 3)

        // Nothing pending now.
        let again = try await f.services.inbox.checkNow()
        XCTAssertEqual(again, [])
    }

    func testPollerPicksUpNewItemsWhileEnabled() async throws {
        let (f, folder) = try await signedInWithInbox(interval: .milliseconds(40))
        await f.services.inbox.refreshSchedule()
        let polling = await f.services.inbox.isPolling
        XCTAssertTrue(polling)
        try await mock.call("POST", "/__mock/inbox", ["name": "scan.pdf", "content": "%PDF-1.4"])
        try await waitUntil("file delivered by the poller") {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent("scan.pdf").path)
        }
        // Turning it off stops polling and requests.
        f.services.session.setInboxEnabled(false)
        try await waitUntil("poller stopped") { !(await f.services.inbox.isPolling) }
        try await mock.clearRequests()
        try await Task.sleep(for: .milliseconds(200))
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testDisabledInboxMakesNoRequests() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        try await mock.call("POST", "/__mock/inbox", ["name": "a.txt", "content": "x"])
        try await mock.clearRequests()
        let placed = try await f.services.inbox.checkNow()
        await f.services.inbox.refreshSchedule()
        XCTAssertEqual(placed, [])
        try await Task.sleep(for: .milliseconds(150))
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testCorruptDownloadIsNotSavedOrAcked() async throws {
        let (f, folder) = try await signedInWithInbox()
        try await mock.call("POST", "/__mock/inbox", ["name": "a.txt", "content": "x"])
        // Fail the download once: the item stays pending and is fetched next time.
        try await mock.addFault(method: "GET", pathPrefix: "/v1/files/", mode: "status", status: 500)
        await XCTAssertThrowsAsync(try await f.services.inbox.checkNow())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
        let pending = try await mock.items("/__mock/inbox")
        XCTAssertEqual(pending.first?["status"] as? String, "pending")
        let placed = try await f.services.inbox.checkNow()
        XCTAssertEqual(placed.map(\.lastPathComponent), ["a.txt"])
    }

    func testFileNameSanitising() {
        XCTAssertEqual(CloudFileName.sanitize("../../etc/passwd"), "passwd")
        XCTAssertEqual(CloudFileName.sanitize("a/b:c.txt"), "c.txt")
        XCTAssertEqual(CloudFileName.sanitize("...hidden"), "hidden")
        XCTAssertEqual(CloudFileName.sanitize("bad\u{0}name\n.txt"), "badname.txt")
        XCTAssertEqual(CloudFileName.sanitize("   "), "Untitled")
        XCTAssertEqual(CloudFileName.sanitize(String(repeating: "x", count: 500)).count, 200)
        XCTAssertEqual(CloudFileName.split("archive.tar.gz").ext, "tar.gz")
        XCTAssertEqual(CloudFileName.split("photo.jpg").base, "photo")
        XCTAssertEqual(CloudFileName.split("README").ext, "")
    }
}
