import SwiftUI
import AnyfmtCore

/// Expiry, password and download limit for a new share link (custom domain
/// only when the plan includes it). The quota line is informational, never
/// a prompt to upgrade.
struct ShareLinkOptionsView: View {
    let entitlements: CloudEntitlements
    let fileCount: Int
    let serverName: String
    let onCreate: (ShareLinkOptions) -> Void
    let onCancel: () -> Void

    @State private var options: ShareLinkOptions
    @State private var usePassword = false
    @State private var password = ""
    @State private var limitDownloads = false
    @State private var downloads = 10
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp
    private typealias T = DesignTokens.Component.Cloud

    init(entitlements: CloudEntitlements, fileCount: Int, serverName: String,
         initial: ShareLinkOptions? = nil,
         onCreate: @escaping (ShareLinkOptions) -> Void, onCancel: @escaping () -> Void) {
        self.entitlements = entitlements
        self.fileCount = fileCount
        self.serverName = serverName
        self.onCreate = onCreate
        self.onCancel = onCancel
        _options = State(initialValue: initial ?? .defaults(for: entitlements))
    }

    private var expiries: [Int?] { ShareLinkOptions.allowedExpiries(for: entitlements) }
    private var downloadCap: Int { entitlements.quotas.shareLinkMaxDownloads ?? 1000 }
    static let minimumPasswordLength = 4
    private var passwordTooShort: Bool { usePassword && password.count < Self.minimumPasswordLength }
    private var reveal: Animation? { reduceMotion ? nil : .easeOut(duration: DesignTokens.Motion.crossfade) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .top) {
                    DisplayText(fileCount == 1 ? String(localized: "Share 1 file") : String(localized: "Share \(fileCount) files"),
                                size: T.headlineCompact)
                        .foregroundStyle(CloudStyle.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    CloudPlanBadge(plan: entitlements.plan)
                }
                Text("Anyone with the link can download. Choose how long it lasts.")
                    .font(.system(size: TypeRamp.body))
                    .foregroundStyle(CloudStyle.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], Space.xl)

            Form {
                Picker(String(localized: "Expires"), selection: $options.expiresInHours) {
                    ForEach(expiries, id: \.self) { hours in
                        Text(ShareLinkOptions.expiryLabel(hours)).tag(hours)
                    }
                }
                Toggle(String(localized: "Require a password"), isOn: $usePassword.animation(reveal))
                if usePassword {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        SecureField(String(localized: "Password"), text: $password, prompt: Text("At least 4 characters"))
                        if passwordTooShort && !password.isEmpty {
                            CloudStatusLine(text: String(localized: "Use at least 4 characters so the link stays private."),
                                            tone: .error, size: TypeRamp.label)
                        }
                    }
                }
                Toggle(String(localized: "Limit downloads"), isOn: $limitDownloads.animation(reveal))
                if limitDownloads {
                    Stepper(value: $downloads, in: 1...downloadCap) {
                        Text(downloads == 1 ? String(localized: "1 download") : String(localized: "\(downloads) downloads"))
                            .monospacedDigit()
                    }
                }
                if entitlements.can(.shareLinkCustomDomain), !entitlements.customDomains.isEmpty {
                    Picker(String(localized: "Domain"), selection: $options.customDomain) {
                        Text(serverName).tag(String?.none)
                        ForEach(entitlements.customDomains, id: \.self) { domain in
                            Text(domain).tag(String?.some(domain))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .toggleStyle(AnyfmtSwitchStyle())

            VStack(alignment: .leading, spacing: Space.xs) {
                Label(String(localized: "Uploads to \(serverName). The link is copied when it’s ready."), systemImage: "icloud.and.arrow.up")
                if let usage = entitlements.usageLine {
                    Label(usage, systemImage: "chart.bar")
                }
            }
            .font(.system(size: TypeRamp.label))
            .foregroundStyle(CloudStyle.mist)
            .padding(.horizontal, Space.xl)

            HStack(spacing: Space.s) {
                Spacer()
                Button(String(localized: "Cancel"), action: onCancel)
                    .buttonStyle(.anyfmtQuiet)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Create Link")) {
                    var o = options
                    o.password = usePassword ? password : nil
                    o.maxDownloads = limitDownloads ? downloads : nil
                    onCreate(o.clamped(to: entitlements))
                }
                .buttonStyle(.anyfmtPrimary)
                .keyboardShortcut(.defaultAction)
                .disabled(passwordTooShort)
                .accessibilityHint(passwordTooShort ? Text("Add a password of at least 4 characters first") : Text("Uploads and copies the link"))
            }
            .padding(Space.xl)
        }
        .frame(width: T.shareWidth)
        .background(CloudStyle.window)
    }
}
