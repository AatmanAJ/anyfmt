import AppKit
import SwiftUI
import AnyfmtCore

struct OutputPane: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var settings: AppSettings
    /// Fixed in snapshots so screenshots don't change every day.
    var previewDate = Date()

    init(model: SettingsModel, previewDate: Date = Date()) {
        self.model = model
        self.settings = model.settings
        self.previewDate = previewDate
    }

    private enum Location: Hashable { case beside, folder, choose }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("", selection: locationBinding) {
                        Label { Text("Beside the original") } icon: { Image(systemName: "doc.on.doc") }
                            .tag(Location.beside)
                        if let folder = settings.outputFolderURL {
                            Label { Text(verbatim: FileManager.default.displayName(atPath: folder.path)) } icon: {
                                Image(nsImage: Self.folderIcon(folder))
                            }
                            .tag(Location.folder)
                        }
                        Divider()
                        Text("Choose Folder…").tag(Location.choose)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityIdentifier("output.location")
                } label: {
                    Text("Save converted files")
                    if let folder = settings.outputFolderURL {
                        Text(verbatim: (folder.path as NSString).abbreviatingWithTildeInPath)
                    } else if settings.outputFolderBookmark != nil {
                        // The words carry the problem; the colour only draws the eye.
                        Text("The chosen folder is missing. Files are saved beside the original until you choose another.")
                            .foregroundStyle(Color.anyfmtDanger)
                    } else {
                        Text("Right next to the file you dropped, like Finder’s Duplicate.")
                    }
                }
                Toggle(isOn: $settings.revealInFinder) {
                    Text("Show in Finder when done")
                    Text("Selects the new file in a Finder window.")
                }
                .accessibilityIdentifier("output.reveal")
            } header: {
                Text("Location")
            }

            Section {
                NamingPatternRow(pattern: $settings.namePattern, date: previewDate)
            } header: {
                Text("File names")
            } footer: {
                FootnoteText(text: String(localized: "Files are never overwritten. If the name is taken, a number is added, like Finder does."))
            }

            Section {
                LabeledContent {
                    Picker("", selection: $settings.metadataPolicy) {
                        Text("Keep everything").tag(MetadataPolicy.keep)
                        Text("Remove private details").tag(MetadataPolicy.stripPrivate)
                        Text("Remove all").tag(MetadataPolicy.stripAll)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityIdentifier("output.metadata")
                } label: {
                    Text("In converted copies")
                    Text(verbatim: metadataNote)
                }
                Toggle(isOn: $settings.preserveDates) {
                    Text("Keep the original’s dates")
                    Text("Converted copies get the same created and modified dates. Tool results are dated now.")
                }
                .accessibilityIdentifier("output.preserveDates")
            } header: {
                Text("Metadata")
            }
        }
        .formStyle(.grouped)
    }

    private var metadataNote: String {
        switch settings.metadataPolicy {
        case .keep: String(localized: "Camera, location and author details stay in the copy.")
        case .stripPrivate: String(localized: "Removes location, device and author. Keeps orientation and colour profile.")
        case .stripAll: String(localized: "Removes everything the format allows, including orientation and colour profile.")
        }
    }

    private var locationBinding: Binding<Location> {
        Binding(
            get: { settings.outputFolderURL == nil ? .beside : .folder },
            set: { choice in
                switch choice {
                case .beside: settings.setOutputFolder(nil)
                case .folder: break
                case .choose: chooseFolder()
                }
            }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Converted files will be saved in this folder.")
        panel.directoryURL = settings.outputFolderURL
        let apply: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            settings.setOutputFolder(url)
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: apply)
        } else {
            apply(panel.runModal())
        }
    }

    private static func folderIcon(_ url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

/// Pattern field, token chips and a live example.
struct NamingPatternRow: View {
    @Binding var pattern: String
    let date: Date

    var body: some View {
        LabeledContent {
            TextField("", text: $pattern, prompt: Text(verbatim: "{name}"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: DesignTokens.TypeRamp.body, design: .monospaced))
                .multilineTextAlignment(.leading)
                .frame(width: 200)
                .accessibilityIdentifier("output.namePattern")
        } label: {
            Text("Name pattern")
            Text("For converted files. Tools also add their name, such as “compressed”.")
        }
        LabeledContent {
            HStack(spacing: DesignTokens.Space.xs + 2) {
                ForEach(NamingPreview.tokens) { token in
                    Button {
                        let base = pattern.isEmpty ? "" : pattern
                        let joiner = base.isEmpty || base.hasSuffix(" ") || base.hasSuffix("-") || base.hasSuffix("_") ? "" : " "
                        pattern = base + joiner + token.token
                    } label: {
                        SettingsTokenPill(text: token.token)
                    }
                    .buttonStyle(.plain)
                    .help(Text(verbatim: token.title))
                    .accessibilityLabel(Text("Insert \(token.title)"))
                }
            }
        } label: {
            Text("Insert")
        }
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            HStack(spacing: DesignTokens.Space.s) {
                Image(systemName: "eye")
                    .foregroundStyle(Color.anyfmtSecondaryText)
                    .accessibilityHidden(true)
                Text(verbatim: NamingPreview.line(pattern: pattern, date: date))
                    .font(.system(size: DesignTokens.TypeRamp.body, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("output.namePreview")
            }
            if let issue = NamingPreview.issue(pattern: pattern) {
                StatusBadge(tone: .waiting, text: issue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
