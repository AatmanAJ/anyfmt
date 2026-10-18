import AppKit
import HaloCore
import SwiftUI

/// Paste a Pro licence key, see what's active, or remove it. Used by onboarding's
/// last (optional) page and by Settings › Account. A key only feeds the cloud
/// entitlements; nothing local ever depends on it (BUILD.md §9b, D-040).
@MainActor
final class LicenceActivationModel: ObservableObject {
    private let store: LicenceStore
    @Published var keyText = ""
    @Published private(set) var message: String?
    @Published private(set) var isError = false
    @Published private(set) var status: LicenceVerification?
    private var observer: UUID?

    init(store: LicenceStore = CloudIntegration.licences) {
        self.store = store
        status = store.status
        observer = store.observe { [weak self] store in
            let status = store.status
            Task { @MainActor in self?.status = status }
        }
    }

    deinit {
        if let observer { store.removeObserver(observer) }
    }

    var hasKey: Bool { status != nil }
    var canActivate: Bool { !keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func activate() {
        do {
            let licence = try store.activate(keyText)
            keyText = ""
            isError = false
            message = LicenceVerification.valid(licence).message
        } catch let e as LicenceActivationError {
            isError = true
            message = e.message
        } catch {
            isError = true
            message = error.localizedDescription
        }
        status = store.status
    }

    func deactivate() {
        do {
            try store.deactivate()
            isError = false
            message = String(localized: "Licence removed from this Mac. Everything local keeps working.",
                             comment: "Shown after removing a Pro licence key")
        } catch {
            isError = true
            message = error.localizedDescription
        }
        status = store.status
    }

    /// Paste from the clipboard (keys are long).
    func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) { keyText = s }
    }
}

struct LicenceActivationView: View {
    @ObservedObject var model: LicenceActivationModel
    /// Compact (onboarding) hides the remove button and the status row title.
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            if let status = model.status {
                HStack(spacing: DesignTokens.Space.s) {
                    Image(systemName: status.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(status.isValid ? Color.accentColor : CloudStyle.danger)
                        .accessibilityHidden(true)
                    Text(verbatim: status.message)
                        .font(.system(size: DesignTokens.TypeRamp.body))
                    Spacer()
                    if !compact {
                        Button(String(localized: "Remove Licence…", comment: "Settings › Account button")) { model.deactivate() }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: DesignTokens.Space.s) {
                TextField(String(localized: "HALO1-…", comment: "Placeholder for the licence key field"), text: $model.keyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: DesignTokens.TypeRamp.body, design: .monospaced))
                    .onSubmit { if model.canActivate { model.activate() } }
                    .accessibilityLabel(Text("Licence key", comment: "VoiceOver label of the licence key field"))
                Button(String(localized: "Paste", comment: "Pastes a licence key from the clipboard")) { model.pasteFromClipboard() }
                Button(String(localized: "Activate", comment: "Activates a pasted licence key")) { model.activate() }
                    .disabled(!model.canActivate)
            }
            if let message = model.message {
                Label {
                    Text(verbatim: message)
                } icon: {
                    Image(systemName: model.isError ? "exclamationmark.circle" : "checkmark.circle")
                }
                .font(.system(size: DesignTokens.TypeRamp.caption))
                .foregroundStyle(model.isError ? CloudStyle.danger : Color.secondary)
            }
            Text("Keys are checked on this Mac, offline. A key only unlocks cloud features; every local conversion, tool and action is free without one.",
                 comment: "Explains what a licence key does")
                .font(.system(size: DesignTokens.TypeRamp.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
