import XCTest
import AnyfmtCore
@testable import AnyfmtApp

/// Sync: push on change (debounced), pull, conditional PUT, conflicts with
/// a surfaced notice and one-click reversal; nothing when sync is off.
@MainActor
final class SyncEngineTests: MockServerTestCase {
    private func signedInWithSync(policy: [SyncNamespace: SyncSide] = [:]) async throws -> (CloudFixture, MemorySyncSource) {
        try await mock.setUser(plan: "pro")
        let f = try fixture(syncPolicy: policy)
        try await f.signIn()
        let source = MemorySyncSource()
        await f.services.sync.setSource(source)
        f.services.preferences.syncEnabled = true
        f.state.update { $0.syncEnabled = true }
        return (f, source)
    }

    private func serverDoc(_ ns: SyncNamespace) async throws -> [String: Any]? {
        try await mock.items("/__mock/sync").first { $0["namespace"] as? String == ns.rawValue }
    }

    private func items(_ doc: [String: Any]?) -> [String]? {
        (doc?["data"] as? [String: Any])?["items"] as? [String]
    }

    private func localItems(_ source: MemorySyncSource, _ ns: SyncNamespace) -> [String]? {
        (source.json(ns) as? [String: Any])?["items"] as? [String]
    }

    func testPushPullAndDebouncedChanges() async throws {
        let (f, source) = try await signedInWithSync()
        let sync = f.services.sync
        source.set(.favourites, ["items": ["png", "jpg"]])
        source.set(.wheelOrder, ["items": ["image", "video"]])

        // First sync creates both documents (If-None-Match: *).
        try await sync.syncNow()
        var fav = try await serverDoc(.favourites)
        XCTAssertEqual(fav?["version"] as? Int, 1)
        XCTAssertEqual(items(fav), ["png", "jpg"])
        let creates = try await mock.requests().filter { $0["method"] as? String == "PUT" }
        XCTAssertEqual(creates.compactMap { $0["ifNoneMatch"] as? String }, ["*", "*"])

        // Another Mac changes favourites → pull applies it here.
        try await mock.call("POST", "/__mock/sync", ["namespace": "favourites", "data": ["items": ["webp"]], "deviceName": "Studio"])
        try await sync.syncNow()
        XCTAssertEqual(localItems(source, .favourites), ["webp"])
        XCTAssertEqual(source.applied.current, [.favourites])

        // A local change pushes once after the debounce, with If-Match.
        try await mock.clearRequests()
        source.set(.favourites, ["items": ["heic"]])
        await sync.noteLocalChange(.favourites)
        source.set(.favourites, ["items": ["heic", "avif"]])
        await sync.noteLocalChange(.favourites)
        await sync.flush()
        let puts = try await mock.requests().filter { $0["method"] as? String == "PUT" }
        XCTAssertEqual(puts.count, 1, "debounced into one write")
        XCTAssertEqual(puts.first?["ifMatch"] as? String, "\"2\"")
        fav = try await serverDoc(.favourites)
        XCTAssertEqual(fav?["version"] as? Int, 3)
        XCTAssertEqual(items(fav), ["heic", "avif"])

        // Nothing changed: a sync is one cheap index request.
        try await mock.clearRequests()
        try await sync.syncNow()
        let paths = try await mock.requests().compactMap { $0["path"] as? String }
        XCTAssertEqual(paths, ["/v1/sync/documents"])
        let notices = await sync.notices
        XCTAssertTrue(notices.isEmpty)
    }

    func testConflictKeepsServerAndOffersThisMacsVersion() async throws {
        let (f, source) = try await signedInWithSync()
        let sync = f.services.sync
        source.set(.presets, ["items": ["a"]])
        try await sync.syncNow()                    // v1 = a

        // Both sides change before the next sync.
        try await mock.call("POST", "/__mock/sync", ["namespace": "presets", "data": ["items": ["server"]], "deviceName": "Studio"])
        source.set(.presets, ["items": ["local"]])
        try await sync.syncNow()

        XCTAssertEqual(localItems(source, .presets), ["server"], "default policy keeps the server copy")
        let notices = await sync.notices
        let notice = try XCTUnwrap(notices.first)
        XCTAssertEqual(notice.namespace, .presets)
        XCTAssertEqual(notice.kept, .server)
        XCTAssertEqual(notice.otherDevice, "Studio")
        XCTAssertTrue(notice.message.contains("Studio"))

        // One click: use this Mac's version after all.
        try await sync.resolve(notice.id, keep: .local)
        XCTAssertEqual(localItems(source, .presets), ["local"])
        let doc = try await serverDoc(.presets)
        XCTAssertEqual(items(doc), ["local"])
        XCTAssertEqual(doc?["version"] as? Int, 3)
        let after = await sync.notices
        XCTAssertTrue(after.isEmpty)
    }

    func testConflictOnPushUsesThe409Body() async throws {
        let (f, source) = try await signedInWithSync(policy: [.settings: .local])
        let sync = f.services.sync
        source.set(.settings, ["items": ["v1"]])
        try await sync.syncNow()
        try await mock.call("POST", "/__mock/sync", ["namespace": "settings", "data": ["items": ["theirs"]]])
        try await mock.clearRequests()

        source.set(.settings, ["items": ["mine"]])
        await sync.noteLocalChange(.settings)
        await sync.flush()

        // PUT If-Match "1" → 409 with the current doc → policy keeps local → PUT If-Match "2".
        let puts = try await mock.requests().filter { $0["method"] as? String == "PUT" }
        XCTAssertEqual(puts.map { "\($0["ifMatch"] ?? "") \($0["status"] ?? "")" }, ["\"1\" 409", "\"2\" 200"])
        let gets = try await mock.requestCount("GET")
        XCTAssertEqual(gets, 0, "no extra round trip to read the server copy")
        let doc = try await serverDoc(.settings)
        XCTAssertEqual(items(doc), ["mine"])
        let notices = await sync.notices
        XCTAssertEqual(notices.first?.kept, .local)
        let other = try JSONSerialization.jsonObject(with: try XCTUnwrap(notices.first?.otherVersion)) as? [String: Any]
        XCTAssertEqual(other?["items"] as? [String], ["theirs"])
    }

    func testFirstSyncOnASecondMacTakesTheServerCopy() async throws {
        try await mock.setUser(plan: "pro")
        try await mock.call("POST", "/__mock/sync", ["namespace": "recipes", "data": ["items": ["from-first-mac"]]])
        let (f, source) = try await signedInWithSync()
        try await f.services.sync.syncNow()
        XCTAssertEqual(localItems(source, .recipes), ["from-first-mac"])
        let notices = await f.services.sync.notices
        XCTAssertTrue(notices.isEmpty, "nothing local to conflict with")
    }

    func testSyncOffMeansNoRequests() async throws {
        let (f, source) = try await signedInWithSync()
        f.services.session.setSyncEnabled(false)
        try await mock.clearRequests()
        source.set(.favourites, ["items": ["x"]])
        try await f.services.sync.syncNow()
        await f.services.sync.noteLocalChange(.favourites)
        await f.services.sync.flush()
        try await Task.sleep(for: .milliseconds(100))
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testFreePlanDoesNotSync() async throws {
        try await mock.setUser(plan: "free")
        let f = try fixture()
        try await f.signIn()
        let source = MemorySyncSource()
        source.set(.favourites, ["items": ["x"]])
        await f.services.sync.setSource(source)
        f.state.update { $0.syncEnabled = true }
        try await mock.clearRequests()
        try await f.services.sync.syncNow()
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testCanonicalHashIgnoresKeyOrder() throws {
        let a = try CloudJSON(data: Data(#"{"b":1,"a":[1,2,{"y":true,"x":null}]}"#.utf8))
        let b = try CloudJSON(data: Data(#"{"a":[1,2,{"x":null,"y":true}],"b":1}"#.utf8))
        XCTAssertEqual(a.canonicalHash(), b.canonicalHash())
        let c = try CloudJSON(data: Data(#"{"a":[2,1,{"x":null,"y":true}],"b":1}"#.utf8))
        XCTAssertNotEqual(a.canonicalHash(), c.canonicalHash(), "array order matters (wheel order)")
    }
}
