import SwiftUI
import HaloCore

/// The one-time "This uploads to {server}" note, shown the first time a
/// cloud action runs against a server (BUILD.md §2). A display headline,
/// one plain sentence, the server in a tile, Cancel and a blue Continue pill.
struct UploadNoticeView: View {
    let serverName: String
    let fileCount: Int
    let onContinue: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp
    private typealias T = DesignTokens.Component.Cloud

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            DisplayText(String(localized: "This uploads", comment: "Upload notice headline"), size: T.headlineCompact)
                .foregroundStyle(CloudStyle.ink)
                .accessibilityAddTraits(.isHeader)
            Text(fileCount == 1
                 ? String(localized: "The file leaves this Mac to be processed or shared. You’ll only see this once for this server.")
                 : String(localized: "The files leave this Mac to be processed or shared. You’ll only see this once for this server."))
                .font(.system(size: TypeRamp.body))
                .foregroundStyle(CloudStyle.mist)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.s) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(CloudStyle.irisText)
                    .accessibilityHidden(true)
                Text(verbatim: serverName)
                    .font(.system(size: TypeRamp.body, weight: .semibold))
                    .foregroundStyle(CloudStyle.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .cloudTile(highContrast: CloudStyle.isHighContrast(contrast))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Uploads to \(serverName)"))
            HStack(spacing: Space.s) {
                Spacer()
                Button(String(localized: "Cancel"), action: onCancel)
                    .buttonStyle(.haloQuiet)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Continue"), action: onContinue)
                    .buttonStyle(.haloPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: T.noticeWidth)
        .background(CloudStyle.window)
        .accessibilityElement(children: .contain)
    }
}
