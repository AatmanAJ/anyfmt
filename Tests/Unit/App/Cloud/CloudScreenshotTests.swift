import XCTest
import SwiftUI
import AppKit
import HaloCore
@testable import HaloApp

/// Renders the cloud screens offscreen in light, dark and increased contrast.
/// Always checks they render; writes PNGs to docs/screens/cloud-*.png when
/// run with `TEST_RUNNER_HALO_WRITE_SCREENS=1` (otherwise a temp folder).
@MainActor
final class CloudScreenshotTests: XCTestCase {
    private var outputDir: URL!
    private var fixtures: [CloudFixture] = []

    override func setUp() async throws {
        try await super.setUp()
        if ProcessInfo.processInfo.environment["HALO_WRITE_SCREENS"] == "1" {
            outputDir = MockCloudServerPaths.repoRoot.appendingPathComponent("docs/screens", isDirectory: true)
        } else {
            outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("halo-cloud-screens-\(UUID().uuidString)")
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        fixtures.forEach { $0.tearDown() }
        try await super.tearDown()
    }

    private enum Look: String, CaseIterable {
        case light, dark, contrast
        var appearance: NSAppearance? {
            switch self {
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            // AppKit resolves the accessibility appearances to plain Aqua offscreen;
            // CloudStyle.increasedContrastPreview switches our tokens instead.
            case .contrast: NSAppearance(named: .aqua)
            }
        }
    }

    @discardableResult
    private func render<V: View>(_ view: V, name: String, size: CGSize? = nil, looks: [Look] = [.light, .dark]) throws -> [URL] {
        var written: [URL] = []
        for look in looks {
            guard let appearance = look.appearance else { continue }
            CloudStyle.increasedContrastPreview.withLock { $0 = look == .contrast }
            defer { CloudStyle.increasedContrastPreview.withLock { $0 = false } }
            let root = view
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, look == .dark ? .dark : .light)
            let host = NSHostingView(rootView: root)
            host.appearance = appearance
            let fitting = host.fittingSize
            let frame = CGRect(origin: .zero, size: size ?? CGSize(width: max(fitting.width, 200), height: max(fitting.height, 100)))
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = appearance
            window.backgroundColor = .windowBackgroundColor
            window.contentView = host
            host.frame = frame
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "render", code: 1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 2000, "\(name) rendered something")
            XCTAssertGreaterThan(rep.pixelsWide, 100)
            let url = outputDir.appendingPathComponent("cloud-\(name)-\(look.rawValue).png")
            try png.write(to: url)
            written.append(url)
            window.contentView = nil
        }
        return written
    }

    private func session(signedIn: Bool, plan: Plan = .pro) throws -> CloudSession {
        let f = try CloudFixture.make(server: nil)
        fixtures.append(f)
        if signedIn {
            let features: Set<CloudFeature> = plan == .free ? [.shareLink] : Set(CloudFeature.allCases).subtracting(plan == .pro ? [.shareLinkCustomDomain] : [])
            let quotas = plan == .free
                ? CloudQuotas(shareLinksPerMonth: 5, shareLinksUsed: 2, shareLinkMaxExpiryHours: 72,
                              periodResetsAt: Date(timeIntervalSince1970: 1_793_491_200))
                : .none
            let creds = CloudCredentials(accessToken: "a", refreshToken: "r", accessTokenExpiresAt: Date().addingTimeInterval(3600))
            let account = CloudAccount(userID: "u", email: "aj@example.com", name: nil,
                                       entitlements: CloudEntitlements(isSignedIn: true, plan: plan, features: features, quotas: quotas, customDomains: []))
            f.state.update {
                $0.credentials = creds
                $0.account = account
                $0.syncEnabled = plan != .free
                $0.inboxEnabled = plan != .free
            }
            f.services.session.setInboxFolder(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
        }
        f.services.session.refreshFromState()
        return f.services.session
    }

    func testAccountSettingsScreens() throws {
        try render(AccountSettingsView(session: try session(signedIn: false)), name: "account-signed-out",
                   size: CGSize(width: 520, height: 760), looks: Look.allCases)
        try render(AccountSettingsView(session: try session(signedIn: true, plan: .pro)), name: "account-pro",
                   size: CGSize(width: 520, height: 780), looks: Look.allCases)
        try render(AccountSettingsView(session: try session(signedIn: true, plan: .free)), name: "account-free",
                   size: CGSize(width: 520, height: 640))
    }

    func testProExplainerScreens() throws {
        try render(ProExplainerView(feature: .transcription, serverName: "cloud.example.invalid", onPrimary: {}, onNotNow: {}),
                   name: "pro-explainer", looks: Look.allCases)
        try render(ProExplainerView(feature: .shareLinkCustomDomain, serverName: "cloud.example.invalid", reason: .notInPlan,
                                    onPrimary: {}, onNotNow: {}), name: "pro-explainer-not-in-plan")
    }

    func testShareAndNoticeScreens() throws {
        let free = CloudEntitlements(isSignedIn: true, plan: .free, features: [.shareLink],
                                     quotas: CloudQuotas(shareLinksPerMonth: 5, shareLinksUsed: 2, shareLinkMaxExpiryHours: 72,
                                                         periodResetsAt: Date(timeIntervalSince1970: 1_793_491_200)), customDomains: [])
        try render(ShareLinkOptionsView(entitlements: free, fileCount: 2, serverName: "cloud.example.invalid", onCreate: { _ in }, onCancel: {}),
                   name: "share-options", looks: Look.allCases)
        let team = CloudEntitlements(isSignedIn: true, plan: .team, features: Set(CloudFeature.allCases), quotas: .none,
                                     customDomains: ["files.example.com"])
        try render(ShareLinkOptionsView(entitlements: team, fileCount: 1, serverName: "cloud.example.invalid", onCreate: { _ in }, onCancel: {}),
                   name: "share-options-team")
        try render(UploadNoticeView(serverName: "cloud.example.invalid", fileCount: 1, onContinue: {}, onCancel: {}),
                   name: "upload-notice", looks: Look.allCases)
        try render(HStack(spacing: 12) {
            CloudPlanBadge(plan: .free); CloudPlanBadge(plan: .pro); CloudPlanBadge(plan: .team); CloudProChip()
        }.padding(16), name: "badges", looks: Look.allCases)
    }
}
