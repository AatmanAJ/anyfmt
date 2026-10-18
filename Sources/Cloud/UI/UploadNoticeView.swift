import SwiftUI
import HaloCore

/// The one-line "This uploads to {server}" note, shown the first time a
/// cloud action runs against a server (BUILD.md §2).
struct UploadNoticeView: View {
    let serverName: String
    let fileCount: Int
    let onContinue: () -> Void
    let onCancel: () -> Void

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CloudStyle.iris)
                    .accessibilityHidden(true)
                Text("This uploads to \(serverName).")
                    .font(.system(size: TypeRamp.title, weight: .semibold))
            }
            Text(fileCount == 1
                 ? String(localized: "The file leaves this Mac to be processed or shared. You’ll only see this once for this server.")
                 : String(localized: "The files leave this Mac to be processed or shared. You’ll only see this once for this server."))
                .font(.system(size: TypeRamp.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(String(localized: "Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Continue"), action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Space.xl)
        .frame(width: 380)
        .accessibilityElement(children: .contain)
    }
}
