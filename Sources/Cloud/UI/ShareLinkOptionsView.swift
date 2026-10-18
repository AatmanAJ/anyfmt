import SwiftUI
import HaloCore

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

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp

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
    private var passwordTooShort: Bool { usePassword && password.count < 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.s) {
                Image(systemName: "link.icloud")
                    .font(.system(size: 20))
                    .foregroundStyle(CloudStyle.iris)
                    .accessibilityHidden(true)
                Text(fileCount == 1 ? String(localized: "Share 1 file") : String(localized: "Share \(fileCount) files"))
                    .font(.system(size: TypeRamp.title, weight: .semibold))
            }
            .padding([.horizontal, .top], Space.xl)

            Form {
                Picker(String(localized: "Expires"), selection: $options.expiresInHours) {
                    ForEach(expiries, id: \.self) { hours in
                        Text(ShareLinkOptions.expiryLabel(hours)).tag(hours)
                    }
                }
                Toggle(String(localized: "Require a password"), isOn: $usePassword.animation(.easeOut(duration: DesignTokens.Motion.crossfade)))
                if usePassword {
                    SecureField(String(localized: "Password"), text: $password, prompt: Text("At least 4 characters"))
                }
                Toggle(String(localized: "Limit downloads"), isOn: $limitDownloads.animation(.easeOut(duration: DesignTokens.Motion.crossfade)))
                if limitDownloads {
                    Stepper(value: $downloads, in: 1...downloadCap) {
                        Text(downloads == 1 ? String(localized: "1 download") : String(localized: "\(downloads) downloads"))
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

            VStack(alignment: .leading, spacing: Space.xs) {
                Label(String(localized: "Uploads to \(serverName). The link is copied when it’s ready."), systemImage: "icloud.and.arrow.up")
                if let usage = entitlements.usageLine {
                    Label(usage, systemImage: "chart.bar")
                }
            }
            .font(.system(size: TypeRamp.caption + 1))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Space.xl)

            HStack {
                Spacer()
                Button(String(localized: "Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Create Link")) {
                    var o = options
                    o.password = usePassword ? password : nil
                    o.maxDownloads = limitDownloads ? downloads : nil
                    onCreate(o.clamped(to: entitlements))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(passwordTooShort)
            }
            .padding(Space.xl)
        }
        .frame(width: 420)
    }
}
