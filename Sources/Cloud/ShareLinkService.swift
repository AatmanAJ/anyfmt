import AppKit
import HaloCore

/// Asks once per server before the first upload ("This uploads to {server}").
/// The app's implementation shows `UploadNoticeView`; tests answer directly.
protocol CloudUploadConsent: Sendable {
    @MainActor func confirmUpload(to serverName: String, fileCount: Int) async -> Bool
}

protocol CloudPasteboardWriting: Sendable {
    @MainActor func copy(_ url: URL)
}

struct CloudSystemPasteboard: CloudPasteboardWriting {
    @MainActor func copy(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.declareTypes([.URL, .string], owner: nil)
        pb.setString(url.absoluteString, forType: .URL)
        pb.setString(url.absoluteString, forType: .string)
    }
}

/// Remembers the per-server notice and asks only the first time.
final class CloudUploadNoticeGate: Sendable {
    private let preferences: CloudPreferences
    private let consent: any CloudUploadConsent

    init(preferences: CloudPreferences, consent: any CloudUploadConsent) {
        self.preferences = preferences
        self.consent = consent
    }

    func needsNotice(for server: URL) -> Bool { !preferences.hasAcknowledgedUploadNotice(for: server) }

    /// True to go ahead. No request has been made when this returns false.
    func confirm(server: URL, fileCount: Int) async -> Bool {
        guard needsNotice(for: server) else { return true }
        let ok = await consent.confirmUpload(to: CloudServerAddress.displayName(for: server), fileCount: fileCount)
        if ok { preferences.acknowledgeUploadNotice(for: server) }
        return ok
    }
}

/// Options the user picks in `ShareLinkOptionsView`.
struct ShareLinkOptions: Sendable, Equatable {
    /// nil = never expires (plan permitting).
    var expiresInHours: Int?
    var password: String?
    var maxDownloads: Int?
    var customDomain: String?
    var title: String?

    static let expiryChoices: [Int?] = [1, 24, 72, 24 * 7, 24 * 30, nil]

    /// Sensible defaults within the plan: a week, or the plan's maximum if shorter.
    static func defaults(for e: CloudEntitlements) -> ShareLinkOptions {
        let week = 24 * 7
        let hours = e.quotas.shareLinkMaxExpiryHours.map { min($0, week) } ?? week
        return ShareLinkOptions(expiresInHours: hours, password: nil, maxDownloads: nil, customDomain: nil, title: nil)
    }

    /// Expiry choices the plan allows.
    static func allowedExpiries(for e: CloudEntitlements) -> [Int?] {
        guard let max = e.quotas.shareLinkMaxExpiryHours else { return expiryChoices }
        return expiryChoices.filter { $0.map { $0 <= max } ?? false }
    }

    /// Brings the options inside the plan's limits (never silently adds a custom domain).
    func clamped(to e: CloudEntitlements) -> ShareLinkOptions {
        var o = self
        if let max = e.quotas.shareLinkMaxExpiryHours {
            o.expiresInHours = Swift.min(o.expiresInHours ?? max, max)
        }
        if let cap = e.quotas.shareLinkMaxDownloads {
            o.maxDownloads = Swift.min(o.maxDownloads ?? cap, cap)
        }
        if let p = o.password, p.isEmpty { o.password = nil }
        if let t = o.title, t.trimmingCharacters(in: .whitespaces).isEmpty { o.title = nil }
        return o
    }

    static func expiryLabel(_ hours: Int?) -> String {
        switch hours {
        case nil: String(localized: "Never")
        case 1: String(localized: "1 hour")
        case 24: String(localized: "1 day")
        case 72: String(localized: "3 days")
        case 168: String(localized: "7 days")
        case 720: String(localized: "30 days")
        case let h?: String(localized: "\(h) hours")
        }
    }
}

enum ShareLinkOutcome: Sendable, Equatable {
    /// The link exists and is on the pasteboard. `remainingLinks` nil = unlimited.
    case created(CloudShareLink, remainingLinks: Int?)
    /// The user declined the upload notice. Nothing was sent.
    case declined
}

/// The Control wheel's "Share link" action (BUILD.md §9b). Takes files the
/// app already converted if the user picked a convert-then-share target.
final class ShareLinkService: Sendable {
    private let state: CloudState
    private let client: CloudAPIClient
    private let auth: CloudAuth
    private let uploader: CloudUploader
    private let notice: CloudUploadNoticeGate
    private let pasteboard: any CloudPasteboardWriting

    init(state: CloudState, client: CloudAPIClient, auth: CloudAuth, uploader: CloudUploader,
         notice: CloudUploadNoticeGate, pasteboard: any CloudPasteboardWriting = CloudSystemPasteboard()) {
        self.state = state
        self.client = client
        self.auth = auth
        self.uploader = uploader
        self.notice = notice
        self.pasteboard = pasteboard
    }

    /// Uploads `files`, creates one link for all of them, copies it.
    /// - Throws: `.signedOut` / `.notEntitled` before any request; server
    ///   errors as `CloudError`; `CancellationError` when cancelled.
    func share(files: [URL], options: ShareLinkOptions, progress: (@Sendable (Double) -> Void)? = nil) async throws -> ShareLinkOutcome {
        let snap = state.snapshot
        guard snap.isSignedIn else { throw CloudError.signedOut }
        guard !files.isEmpty else { throw CloudError.fileUnreadable("") }
        let cached = snap.entitlements
        guard cached.can(.shareLink) else { throw CloudError.notEntitled(.shareLink) }
        if options.customDomain != nil, !cached.can(.shareLinkCustomDomain) {
            throw CloudError.notEntitled(.shareLinkCustomDomain)
        }
        guard await notice.confirm(server: snap.server, fileCount: files.count) else { return .declined }

        // Fresh quota before uploading anything (part of this user action).
        let entitlements = (try await auth.refreshAccount(trigger: .user)).entitlements
        guard entitlements.can(.shareLink) else { throw CloudError.notEntitled(.shareLink) }
        if options.customDomain != nil, !entitlements.can(.shareLinkCustomDomain) {
            throw CloudError.notEntitled(.shareLinkCustomDomain)
        }
        if let left = entitlements.remainingShareLinks, left == 0 {
            throw CloudError.quotaExceeded(
                message: String(localized: "This month’s share links are used up. They renew at the start of next month."),
                resetsAt: entitlements.quotas.periodResetsAt)
        }
        let chosen = options.clamped(to: entitlements)

        let sizes = files.map { Double((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let total = max(1, sizes.reduce(0, +))
        var before = 0.0
        var uploadIDs: [String] = []
        for (file, size) in zip(files, sizes) {
            let start = before
            let upload = try await uploader.upload(file, purpose: .share, trigger: .user) { p in
                progress?(0.95 * (start + p * size) / total)
            }
            uploadIDs.append(upload.id)
            before += size
        }

        let link = try await client.createLink(CloudShareLinkCreate(
            uploadIds: uploadIDs, title: chosen.title, expiresInHours: chosen.expiresInHours,
            password: chosen.password, maxDownloads: chosen.maxDownloads, customDomain: chosen.customDomain))
        await pasteboard.copy(link.url)
        progress?(1)

        let updated = entitlements.recordingShareLink()
        state.update { s in
            guard var account = s.account else { return }
            account.entitlements = updated
            s.account = account
        }
        Log.cloud.info("share link created for \(files.count) file(s)")
        return .created(link, remainingLinks: updated.remainingShareLinks)
    }

    func links() async throws -> [CloudShareLink] {
        guard state.snapshot.isSignedIn else { throw CloudError.signedOut }
        return try await client.links()
    }

    func revoke(_ link: CloudShareLink) async throws {
        guard state.snapshot.isSignedIn else { throw CloudError.signedOut }
        try await client.revokeLink(link.id)
    }
}
