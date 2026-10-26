import SwiftUI
import AnyfmtCore

struct GeneralPane: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var settings: AppSettings

    init(model: SettingsModel) {
        self.model = model
        self.settings = model.settings
    }

    var body: some View {
        Form {
            Section {
                LaunchAtLoginRow(model: model.loginItem)
            }

            Section {
                Toggle(isOn: $settings.soundsEnabled) {
                    Text("Play sounds")
                    Text("A soft chime when a conversion finishes.")
                }
                .accessibilityIdentifier("settings.sounds")
                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("Haptic feedback")
                    Text("A light tick on Force Touch trackpads as you move between segments.")
                }
                .accessibilityIdentifier("settings.haptics")
            } header: {
                Text("Feedback")
            }

            if let picker = model.hooks.terminalPicker {
                Section {
                    picker()
                } header: {
                    Text("Actions")
                }
            }

            Section {
                Toggle(isOn: Binding(get: { settings.updateChecksEnabled }, set: { on in
                    settings.updateChecksEnabled = on
                    model.hooks.onUpdateChecksChanged?(on)
                })) {
                    Text("Check for updates automatically")
                    Text(verbatim: model.info.updateLine)
                }
                .accessibilityIdentifier("settings.updateChecks")
                LabeledContent {
                    Button("Check Now") { model.hooks.onCheckForUpdates?() }
                        .disabled(model.hooks.onCheckForUpdates == nil)
                        .accessibilityIdentifier("settings.checkNow")
                } label: {
                    Text("Version \(model.info.version) (\(model.info.build))")
                    Text("Checking now asks the update server once, even with automatic checks off.")
                }
            } header: {
                Text("Updates")
            }
        }
        .formStyle(.grouped)
    }
}
