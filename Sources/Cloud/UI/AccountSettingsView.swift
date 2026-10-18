import SwiftUI
import AppKit
import HaloCore

/// Settings › Account. Calm and optional: the app is complete without it.
/// The Settings lane hosts this view as a tab with `CloudServices.shared.session`.
struct AccountSettingsView: View {
    @ObservedObject var session: CloudSession
    @State private var serverText = ""
    @State private var code = ""
    @State private var showCodeField = false

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp

    var body: some View {
        Form {
            accountSection
            syncSection
            inboxSection
            serverSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, idealWidth: 520)
        .onAppear { serverText = session.serverURL.absoluteString }
        .onChange(of: session.serverURL) { serverText = $0.absoluteString }
    }

    // MARK: Account

    @ViewBuilder private var accountSection: some View {
        Section {
            switch session.status {
            case .signedOut:
                signedOutHeader
                HStack {
                    Spacer()
                    Button(String(localized: "Sign In…")) { session.signIn() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint(Text("Opens \(session.serverDisplayName) in your browser"))
                }
            case .waitingForBrowser, .signingIn:
                waitingRow
            case .signedIn:
                signedInRows
            }
            if let error = session.lastError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: TypeRamp.body))
                    .foregroundStyle(CloudStyle.danger)
            }
        } header: {
            Text("Account")
        }
    }

    private var signedOutHeader: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: "icloud")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(CloudStyle.iris)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("\(Brand.name) Cloud is optional")
                    .font(.system(size: TypeRamp.title, weight: .semibold))
                Text("Share links, cloud conversion, sync and an inbox for files from your phone. Everything that runs on your Mac stays free and works offline.")
                    .font(.system(size: TypeRamp.body))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Signing in opens \(session.serverDisplayName) in your browser and emails you a link.")
                    .font(.system(size: TypeRamp.caption + 1))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }

    private var waitingRow: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                ProgressView().controlSize(.small)
                Text(session.status == .signingIn ? String(localized: "Signing in…") : String(localized: "Finish signing in in your browser…"))
                    .font(.system(size: TypeRamp.body))
                Spacer()
                Button(String(localized: "Cancel")) { session.cancelSignIn() }
            }
            .accessibilityElement(children: .combine)
            if session.status == .waitingForBrowser {
                if showCodeField {
                    HStack {
                        TextField(String(localized: "Code from the sign-in page"), text: $code)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(submitCode)
                        Button(String(localized: "Continue"), action: submitCode)
                            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button(String(localized: "Opened the link on another device?")) { showCodeField = true }
                        .buttonStyle(.link)
                        .font(.system(size: TypeRamp.caption + 1))
                }
            }
        }
    }

    private func submitCode() {
        let value = code
        code = ""
        Task { await session.completeSignIn(code: value) }
    }

    @ViewBuilder private var signedInRows: some View {
        LabeledContent(String(localized: "Signed in as")) {
            Text(session.email ?? "—").textSelection(.enabled)
        }
        LabeledContent(String(localized: "Plan")) {
            CloudPlanBadge(plan: session.plan)
        }
        if let usage = session.entitlements.usageLine {
            LabeledContent(String(localized: "Usage")) {
                HStack(spacing: Space.s) {
                    Text(usage).foregroundStyle(.secondary)
                    Button {
                        Task { await session.refreshAccount() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(session.isRefreshing)
                    .help(Text("Refresh"))
                    .accessibilityLabel(Text("Refresh usage"))
                }
            }
        }
        HStack {
            Spacer()
            Button(String(localized: "Sign Out")) { Task { await session.signOut() } }
        }
    }

    // MARK: Sync

    private var syncSection: some View {
        Section {
            Toggle(isOn: Binding(get: { session.syncEnabled }, set: { session.setSyncEnabled($0) })) {
                featureLabel(String(localized: "Sync across your Macs"),
                             detail: String(localized: "Favourites, wheel order, presets, recipes and settings."),
                             feature: .sync)
            }
            .disabled(!session.entitlements.can(.sync))
            if session.syncEnabled && session.entitlements.can(.sync) {
                HStack {
                    Text(lastSyncedText).foregroundStyle(.secondary).font(.system(size: TypeRamp.body))
                    Spacer()
                    Button(String(localized: "Sync Now")) { Task { await session.syncNow() } }
                }
                ForEach(session.syncNotices) { notice in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Label(notice.message, systemImage: "arrow.triangle.branch")
                            .font(.system(size: TypeRamp.body))
                        HStack {
                            Spacer()
                            Button(notice.kept == .server ? String(localized: "Use This Mac’s Version") : String(localized: "Use the Other Version")) {
                                Task { await session.resolveSyncNotice(notice, keep: notice.kept == .server ? .local : .server) }
                            }
                            Button(String(localized: "OK")) { Task { await session.dismissSyncNotice(notice) } }
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        } header: {
            Text("Sync")
        }
    }

    private var lastSyncedText: String {
        guard let date = session.lastSyncedAt else { return String(localized: "Not synced yet") }
        return String(localized: "Last synced \(date.formatted(.relative(presentation: .named)))")
    }

    // MARK: Inbox

    private var inboxSection: some View {
        Section {
            Toggle(isOn: Binding(get: { session.inboxEnabled }, set: { session.setInboxEnabled($0) })) {
                featureLabel(String(localized: "Receive files from your phone or browser"),
                             detail: String(localized: "New files are saved to the folder below, then removed from the server."),
                             feature: .inbox)
            }
            .disabled(!session.entitlements.can(.inbox))
            if session.inboxEnabled && session.entitlements.can(.inbox) {
                LabeledContent(String(localized: "Save to")) {
                    HStack(spacing: Space.s) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: session.inboxFolder.path))
                            .resizable().frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        Text(abbreviated(session.inboxFolder))
                            .lineLimit(1).truncationMode(.middle)
                        Button(String(localized: "Choose…"), action: chooseInboxFolder)
                    }
                }
                HStack {
                    Text(String(localized: "Checks every \(CloudConfig.inboxDefaultIntervalMinutes) minutes while \(Brand.name) is running."))
                        .font(.system(size: TypeRamp.caption + 1)).foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "Check Now")) { Task { await session.checkInboxNow() } }
                }
            }
        } header: {
            Text("Inbox")
        }
    }

    private func chooseInboxFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = session.inboxFolder
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK, let url = panel.url { session.setInboxFolder(url) }
    }

    private func abbreviated(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: Server

    private var serverSection: some View {
        Section {
            TextField(String(localized: "Server URL"), text: $serverText, prompt: Text(CloudConfig.defaultServer.absoluteString))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit { session.setServer(serverText) }
            HStack(spacing: Space.s) {
                Button(String(localized: "Validate")) { Task { await session.validateServer(serverText) } }
                    .disabled(serverText.trimmingCharacters(in: .whitespaces).isEmpty || session.serverCheck == .checking)
                serverCheckView
                Spacer()
                if serverTextDiffers {
                    Button(String(localized: "Use This Server")) { session.setServer(serverText) }
                }
                Button(String(localized: "Reset to Default")) {
                    session.resetServerToDefault()
                    serverText = CloudConfig.defaultServer.absoluteString
                }
                .disabled(session.isDefaultServer && !serverTextDiffers)
            }
            Text("Self-hosting? Point \(Brand.name) at your own server. Each server keeps its own sign-in.")
                .font(.system(size: TypeRamp.caption + 1))
                .foregroundStyle(.secondary)
        } header: {
            Text("Server")
        }
    }

    private var serverTextDiffers: Bool {
        guard case .success(let url) = CloudServerAddress.parse(serverText) else { return false }
        return !CloudServerAddress.isSame(url, session.serverURL)
    }

    @ViewBuilder private var serverCheckView: some View {
        switch session.serverCheck {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .ok(let name):
            Label(name, systemImage: "checkmark.circle.fill")
                .foregroundStyle(CloudStyle.success)
                .font(.system(size: TypeRamp.body))
                .lineLimit(1)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(CloudStyle.danger)
                .font(.system(size: TypeRamp.body))
                .lineLimit(2)
        }
    }

    // MARK: Helpers

    private func featureLabel(_ title: String, detail: String, feature: CloudFeature) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(spacing: Space.s) {
                Text(title)
                if !session.entitlements.can(feature) { CloudProChip() }
            }
            Text(detail)
                .font(.system(size: TypeRamp.caption + 1))
                .foregroundStyle(.secondary)
        }
    }
}
