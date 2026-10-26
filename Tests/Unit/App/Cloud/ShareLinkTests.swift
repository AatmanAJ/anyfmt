import XCTest
import CryptoKit
import AnyfmtCore
@testable import AnyfmtApp

/// Share links end to end: per-server upload notice, resumable chunked
/// upload with an injected mid-chunk failure, SHA-256 verify, link options,
/// pasteboard, plan gating and quota.
@MainActor
final class ShareLinkTests: MockServerTestCase {
    func testShareLinkResumesAfterInjectedFailure() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture(chunkSize: 64 * 1024)
        try await f.signIn()
        let file = try f.makeFile("holiday.mov", bytes: 200_000)
        // The second chunk's connection drops after 10 000 bytes reach the server.
        try await mock.addFault(method: "PUT", pathPrefix: "/v1/uploads/", skip: 1, mode: "truncate", keepBytes: 10_000)
        try await mock.clearRequests()
        let fractions = CloudLocked<[Double]>([])

        let outcome = try await f.services.shareLinks.share(
            files: [file], options: ShareLinkOptions(expiresInHours: 24, password: "hunter22", maxDownloads: 3),
            progress: { p in fractions.withLock { $0.append(p) } })

        guard case .created(let link, let remaining) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertNil(remaining, "Pro: unlimited")
        XCTAssertEqual(f.pasteboard.copied.current, [link.url])
        XCTAssertTrue(link.hasPassword)
        XCTAssertEqual(link.maxDownloads, 3)
        XCTAssertEqual(link.files.map(\.name), ["holiday.mov"])
        XCTAssertEqual(link.files.first?.size, 200_000)
        XCTAssertNotNil(link.expiresAt)

        let log = try await mock.requests()
        let puts = log.filter { $0["method"] as? String == "PUT" }
        let heads = log.filter { $0["method"] as? String == "HEAD" }
        XCTAssertEqual(heads.count, 1, "asked the server for its offset once")
        let ranges = puts.compactMap { $0["contentRange"] as? String }
        XCTAssertEqual(ranges, [
            "bytes 0-65535/200000",
            "bytes 65536-131071/200000",   // dropped after 10 000 bytes
            "bytes 75536-141071/200000",   // resumed from the server's offset, mid-chunk
            "bytes 141072-199999/200000",
        ])
        let uploads = try await mock.items("/__mock/uploads")
        let expected = CloudHash.hex(SHA256.hash(data: try Data(contentsOf: file)))
        XCTAssertEqual(uploads.first?["status"] as? String, "complete")
        XCTAssertEqual(uploads.first?["sha256"] as? String, expected)
        XCTAssertEqual(f.consent.asked.current.count, 1, "first upload to this server asks once")

        let values = fractions.current
        XCTAssertEqual(values.last, 1)
        XCTAssertEqual(values, values.sorted(), "progress never goes backwards")

        // Second share to the same server: no notice again.
        _ = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions(expiresInHours: 1))
        XCTAssertEqual(f.consent.asked.current.count, 1)
    }

    func testUploadResumesAcrossAttemptsFromLedger() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture(chunkSize: 64 * 1024)
        try await f.signIn()
        let file = try f.makeFile("big.bin", bytes: 150_000)
        // Every PUT after the first fails: the attempt gives up after its retries.
        try await mock.addFault(method: "PUT", pathPrefix: "/v1/uploads/", skip: 1, times: 100, mode: "status", status: 503)
        do { _ = try await f.services.uploader.upload(file, purpose: .share); XCTFail("should have given up") } catch {}
        try await mock.clearFaults()
        try await mock.clearRequests()

        // "Next launch": a new uploader with the same ledger directory picks up where the server is.
        let uploader = CloudUploader(client: f.services.client, state: f.state,
                                     ledger: CloudUploadLedger(directory: f.directory.appendingPathComponent("ledger")),
                                     chunkSize: 64 * 1024, retry: CloudRetryPolicy(maxAttempts: 2, baseDelay: .milliseconds(5)))
        let upload = try await uploader.upload(file, purpose: .share)
        XCTAssertTrue(upload.isComplete)
        let log = try await mock.requests()
        XCTAssertEqual(log.first?["method"] as? String, "GET", "asks for the existing upload's status first")
        let ranges = log.compactMap { $0["contentRange"] as? String }
        XCTAssertEqual(ranges.first, "bytes 65536-131071/150000", "didn't resend the first chunk")
        let posts = try await mock.requestCount("POST", prefix: "/v1/uploads")
        XCTAssertEqual(posts, 1, "only the complete call, no new upload")
    }

    func testDecliningTheNoticeSendsNothing() async throws {
        try await mock.setUser(plan: "pro")
        let consent = ScriptedConsent(answer: false)
        let f = try fixture(consent: consent)
        try await f.signIn()
        try await mock.clearRequests()
        let file = try f.makeFile("a.txt", text: "hello")
        let outcome = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions())
        XCTAssertEqual(outcome, .declined)
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
        XCTAssertTrue(f.pasteboard.copied.current.isEmpty)
        XCTAssertFalse(f.services.preferences.hasAcknowledgedUploadNotice(for: mock.baseURL))
    }

    func testMultipleFilesShareOneLink() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let a = try f.makeFile("a.png", bytes: 1000)
        let b = try f.makeFile("b.pdf", bytes: 70_000)
        let empty = try f.makeFile("empty.txt", text: "")
        guard case .created(let link, _) = try await f.services.shareLinks.share(files: [a, b, empty], options: ShareLinkOptions()) else {
            return XCTFail()
        }
        XCTAssertEqual(link.files.map(\.name), ["a.png", "b.pdf", "empty.txt"])
        let links = try await f.services.shareLinks.links()
        XCTAssertEqual(links.map(\.id), [link.id])
        try await f.services.shareLinks.revoke(link)
        let after = try await f.services.shareLinks.links()
        XCTAssertTrue(after.isEmpty)
    }

    // MARK: Entitlement gating

    func testFreePlanCannotCreateCustomDomainLinks() async throws {
        try await mock.setUser(plan: "free")
        let f = try fixture()
        try await f.signIn()
        try await mock.clearRequests()
        let file = try f.makeFile("a.txt", text: "x")
        do {
            _ = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions(customDomain: "files.example.com"))
            XCTFail("custom domain allowed on free")
        } catch CloudError.notEntitled(let feature) {
            XCTAssertEqual(feature, .shareLinkCustomDomain)
        }
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0, "refused before uploading anything")
    }

    func testTeamPlanCustomDomainLink() async throws {
        try await mock.setUser(plan: "team", customDomains: ["files.example.com"])
        let f = try fixture()
        try await f.signIn()
        let file = try f.makeFile("a.txt", text: "x")
        guard case .created(let link, _) = try await f.services.shareLinks.share(
            files: [file], options: ShareLinkOptions(expiresInHours: nil, customDomain: "files.example.com")) else { return XCTFail() }
        XCTAssertEqual(link.url.host, "files.example.com")
        XCTAssertEqual(link.customDomain, "files.example.com")
        XCTAssertNil(link.expiresAt, "never expires on Team")
    }

    func testFreePlanQuotaAndExpiryClamp() async throws {
        try await mock.setUser(plan: "free", linksUsed: 3)
        let f = try fixture()
        try await f.signIn()
        let file = try f.makeFile("a.txt", text: "x")
        // Asks for "never"; the free plan allows 72 h, so the options are clamped instead of failing.
        guard case .created(let link, let remaining) = try await f.services.shareLinks.share(
            files: [file], options: ShareLinkOptions(expiresInHours: nil)) else { return XCTFail() }
        XCTAssertEqual(remaining, 1)
        let hours = try XCTUnwrap(link.expiresAt).timeIntervalSince(link.createdAt) / 3600
        XCTAssertEqual(hours, 72, accuracy: 0.1)
        XCTAssertEqual(f.services.entitlements.remainingShareLinks, 1, "local count updated without another request")

        _ = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions(expiresInHours: 24))
        try await mock.clearRequests()
        do {
            _ = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions(expiresInHours: 24))
            XCTFail("quota should be used up")
        } catch CloudError.quotaExceeded(let message, let resets) {
            XCTAssertFalse(message.isEmpty)
            XCTAssertNotNil(resets)
        }
        let paths = try await mock.requests().compactMap { $0["path"] as? String }
        XCTAssertEqual(paths, ["/v1/me"], "checked the quota, uploaded nothing")
    }

    func testFreePlanCannotRunProFeatures() async throws {
        try await mock.setUser(plan: "free")
        let f = try fixture()
        try await f.signIn()
        try await mock.clearRequests()
        let file = try f.makeFile("talk.m4a", bytes: 1000)
        for op in [CloudJobOperation.transcribe(), .upscale(), .removeBackgroundHQ,
                   .convert(target: Formats.mp4, options: OptionValues())] {
            let job = f.services.makeCloudJob(input: file, operation: op)
            do { _ = try await job.run(context: try f.jobContext()); XCTFail("\(op)") } catch CloudError.notEntitled(let feature) {
                XCTAssertEqual(feature, op.feature)
            }
        }
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testStaleCacheIsRefreshedBeforeSharing() async throws {
        try await mock.setUser(plan: "team", customDomains: ["files.example.com"])
        let f = try fixture()
        try await f.signIn()
        // Downgraded on the server; the client still has "team" cached.
        try await mock.setUser(plan: "pro")
        XCTAssertTrue(f.services.entitlements.can(.shareLinkCustomDomain))
        try await mock.clearRequests()
        let file = try f.makeFile("a.txt", text: "x")
        do {
            _ = try await f.services.shareLinks.share(files: [file], options: ShareLinkOptions(customDomain: "files.example.com"))
            XCTFail("stale entitlement used")
        } catch CloudError.notEntitled(let feature) {
            XCTAssertEqual(feature, .shareLinkCustomDomain)
        }
        XCTAssertEqual(f.services.entitlements.plan, .pro, "the share flow refreshed /v1/me first")
        let paths = try await mock.requests().compactMap { $0["path"] as? String }
        XCTAssertEqual(paths, ["/v1/me"])
    }

    func testServerEnforcesPlanToo() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let file = try f.makeFile("a.txt", text: "x")
        let upload = try await f.services.uploader.upload(file, purpose: .share)
        // Straight to the client, skipping the service's own check.
        do {
            _ = try await f.services.client.createLink(CloudShareLinkCreate(
                uploadIds: [upload.id], title: nil, expiresInHours: 1, password: nil, maxDownloads: nil, customDomain: "x.example.com"))
            XCTFail("server allowed a custom domain on pro")
        } catch CloudError.notEntitled(let feature) {
            XCTAssertEqual(feature, .shareLinkCustomDomain)
        }
    }

    func testOptionsDefaultsAndLabels() {
        let free = CloudEntitlements(isSignedIn: true, plan: .free, features: [.shareLink],
                                     quotas: CloudQuotas(shareLinksPerMonth: 5, shareLinksUsed: 2, shareLinkMaxExpiryHours: 72), customDomains: [])
        XCTAssertEqual(ShareLinkOptions.defaults(for: free).expiresInHours, 72)
        XCTAssertEqual(ShareLinkOptions.allowedExpiries(for: free), [1, 24, 72])
        let pro = CloudEntitlements(isSignedIn: true, plan: .pro, features: [.shareLink], quotas: .none, customDomains: [])
        XCTAssertEqual(ShareLinkOptions.defaults(for: pro).expiresInHours, 168)
        XCTAssertEqual(ShareLinkOptions.allowedExpiries(for: pro).count, 6)
        XCTAssertEqual(ShareLinkOptions(expiresInHours: nil).clamped(to: free).expiresInHours, 72)
        XCTAssertNil(ShareLinkOptions(password: "").clamped(to: pro).password)
        XCTAssertEqual(ShareLinkOptions.expiryLabel(nil), "Never")
        XCTAssertEqual(free.usageLine?.hasPrefix("3 of 5"), true)
        XCTAssertEqual(pro.usageLine, "Unlimited share links")
    }
}
