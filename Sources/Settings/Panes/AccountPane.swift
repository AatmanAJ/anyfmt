import SwiftUI
import HaloCore

/// Lane I's account view when wired; otherwise a calm note. Never an upsell:
/// nothing local depends on an account (BUILD.md §9b).
struct AccountPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        if let pane = model.hooks.accountPane {
            pane()
        } else {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
                        DisplayText(String(localized: "Cloud is optional"),
                                    size: DesignTokens.Component.Settings.headlineSize)
                            .accessibilityAddTraits(.isHeader)
                        Text("Every conversion, tool and action runs on your Mac, free, with no account. Sign-in for share links and sync will appear here when it’s available.")
                            .font(.system(size: DesignTokens.TypeRamp.body))
                            .foregroundStyle(Color.haloSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        StatusBadge(tone: .good, text: String(localized: "Everything local works offline"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DesignTokens.Space.s)
                }
            }
            .formStyle(.grouped)
        }
    }
}
