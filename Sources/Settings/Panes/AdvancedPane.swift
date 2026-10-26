import AppKit
import SwiftUI
import AnyfmtCore

struct AdvancedPane: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var settings: AppSettings
    @State private var confirmReset = false
    @State private var copied: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: SettingsModel) {
        self.model = model
        self.settings = model.settings
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("", selection: $settings.cpuConcurrency) {
                        Text("Automatic (\(ConcurrencyInfo.automatic))").tag(0)
                        Divider()
                        ForEach(1...ConcurrencyInfo.maximum, id: \.self) { n in
                            Text(verbatim: "\(n)").tag(n)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityIdentifier("advanced.concurrency")
                } label: {
                    Text("Conversions at once")
                    Text("Automatic is your performance cores minus one (\(ConcurrencyInfo.performanceCores) − 1), so the Mac stays responsive. Hardware video encodes run one at a time.")
                }
            } header: {
                Text("Performance")
            }

            Section {
                Toggle(isOn: $settings.verboseLogging) {
                    Text("Detailed logging")
                    Text("Adds each engine step to the system log. Turn it on before reproducing a problem.")
                }
                .accessibilityIdentifier("advanced.verbose")
                LabeledContent {
                    copyButton(id: "log", text: LogsInfo.command(bundleID: model.info.bundleID), title: String(localized: "Copy Command"))
                } label: {
                    Text("Read the log in Terminal")
                    Text(verbatim: LogsInfo.command(bundleID: model.info.bundleID))
                        .font(.system(size: DesignTokens.TypeRamp.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                LabeledContent {
                    Button("Show in Finder") { LogsInfo.revealFolder() }
                        .accessibilityIdentifier("advanced.logsFolder")
                } label: {
                    Text("Logs folder")
                    Text(verbatim: (LogsInfo.folder.path as NSString).abbreviatingWithTildeInPath)
                }
            } header: {
                Text("Logs")
            }

            Section {
                LabeledContent {
                    copyButton(id: "diag", text: diagnostics, title: String(localized: "Copy Diagnostics"))
                        .accessibilityIdentifier("advanced.copyDiagnostics")
                } label: {
                    Text("Diagnostics for a bug report")
                    Text("Versions, macOS, engines and settings. No file names or paths.")
                }
                if let helpers = model.info.helpersURL {
                    let cli = helpers.appendingPathComponent(Brand.cliName)
                    LabeledContent {
                        HStack {
                            CLIInstallButton()
                            copyButton(id: "cli", text: "ln -s '\(cli.path)' /usr/local/bin/\(Brand.cliName)", title: String(localized: "Copy Command"))
                        }
                    } label: {
                        Text("Command-line tool")
                        Text("Link `\(Brand.cliName)` into your PATH to convert from Terminal: `\(Brand.cliName) convert photo.heic --to jpg`.")
                    }
                }
            } header: {
                Text("Troubleshooting")
            }

            Section {
                LabeledContent {
                    Button("Reset All Settings…", role: .destructive) { confirmReset = true }
                        .accessibilityIdentifier("advanced.reset")
                } label: {
                    Text("Reset")
                    Text("Keys, output, formats and every other setting go back to how they were at install.")
                }
            }
        }
        .formStyle(.grouped)
        .alert(Text("Reset all settings?"), isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every setting goes back to its default. Your files, launch at login and System Settings permissions aren’t touched.")
        }
    }

    private var diagnostics: String {
        Diagnostics.report(settings: settings, info: model.info, engines: model.hooks.engineVersions(), packs: model.hooks.packs())
    }

    private func copyButton(id: String, text: @autoclosure @escaping () -> String, title: String) -> some View {
        Button {
            NSPasteboard.general.copyString(text())
            let fade: Animation? = reduceMotion ? nil : .easeOut(duration: DesignTokens.Motion.crossfade)
            withAnimation(fade) { copied = id }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(fade) { if copied == id { copied = nil } }
            }
        } label: {
            if copied == id {
                Label { Text("Copied") } icon: { Image(systemName: "checkmark") }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentText)
            } else {
                Text(verbatim: title)
            }
        }
        .frame(minWidth: 120)
    }
}

/// One click puts `anyfmt` on the PATH (no admin: a writable PATH folder such as
/// /opt/homebrew/bin or ~/.local/bin). Shows where it's installed, or removes it.
private struct CLIInstallButton: View {
    @State private var status = CLIInstaller.status()
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Space.xs) {
            Group {
                switch status {
                case .installed(let link):
                    Button(String(localized: "Remove")) {
                        CLIInstaller.uninstall()
                        status = CLIInstaller.status()
                        failed = false
                        message = nil
                    }
                    .help(String(localized: "Installed at \(link.path)"))
                    .accessibilityLabel(Text("Remove the command-line tool"))
                case .notInstalled, .linkPointsElsewhere:
                    Button(String(localized: "Install")) {
                        do {
                            let link = try CLIInstaller.install()
                            failed = false
                            message = String(localized: "Installed at \(link.path)")
                        } catch {
                            failed = true
                            message = String(localized: "Couldn’t install: \(error.localizedDescription) Use Copy Command and run it in Terminal instead.")
                        }
                        status = CLIInstaller.status()
                    }
                    .help(String(localized: "Links the bundled tool into a folder on your PATH. No password needed."))
                    .accessibilityLabel(Text("Install the command-line tool"))
                }
            }
            .accessibilityIdentifier("advanced.installCLI")
            if let message {
                StatusBadge(tone: failed ? .warning : .good, text: message)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260, alignment: .trailing)
            }
        }
    }
}
