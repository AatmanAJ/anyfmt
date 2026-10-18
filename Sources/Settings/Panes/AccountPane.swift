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
                    VStack(spacing: DesignTokens.Space.m) {
                        Image(systemName: "icloud")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Color.accentText)
                            .padding(.top, DesignTokens.Space.s)
                        Text("Cloud features are optional")
                            .font(.system(size: DesignTokens.TypeRamp.title, weight: .semibold))
                        Text("Every conversion, tool and action runs on your Mac, free, with no account. Sign-in for share links and sync will appear here when it’s available.")
                            .font(.system(size: DesignTokens.TypeRamp.body))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 420)
                            .padding(.bottom, DesignTokens.Space.s)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
        }
    }
}
