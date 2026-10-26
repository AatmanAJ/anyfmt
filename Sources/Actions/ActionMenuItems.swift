import AppKit
import SwiftUI
import AnyfmtCore

/// Action settings for the Settings window (the Settings lane embeds this in
/// a `Form` section): which terminal the Terminal action opens, and the Move
/// action's recent folders.
///
///     Section(String(localized: "Actions")) { ActionMenuItems() }
public struct ActionMenuItems: View {
    @ObservedObject private var preferences: ActionPreferences
    private let installed: [InstalledTerminal]

    public init(preferences: ActionPreferences = .shared) {
        self.preferences = preferences
        self.installed = TerminalLauncher.installed(lookup: TerminalLauncher.systemLookup)
    }

    /// For previews and tests.
    init(preferences: ActionPreferences, installed: [InstalledTerminal]) {
        self.preferences = preferences
        self.installed = installed
    }

    /// The selection shown: the saved choice if installed, else Terminal.
    private var selection: Binding<String> {
        Binding(
            get: {
                let saved = preferences.terminalBundleID
                return installed.contains { $0.app.bundleID == saved } ? saved : TerminalApp.terminal.bundleID
            },
            set: { preferences.terminalBundleID = $0 })
    }

    public var body: some View {
        Picker(selection: selection) {
            ForEach(installed) { terminal in
                Label {
                    Text(verbatim: terminal.app.name)
                } icon: {
                    Image(nsImage: Self.icon(for: terminal.appURL))
                }
                .tag(terminal.app.bundleID)
            }
        } label: {
            Text("Open Terminal action in")
            Text(terminalNote)
        }
        .help(String(localized: "The app the Terminal action opens at the folder you drop."))

        LabeledContent {
            Button(String(localized: "Clear")) { preferences.clearRecentFolders() }
                .disabled(preferences.recentFolders.isEmpty)
        } label: {
            Text("Recent Move folders")
            Text(recentsNote)
        }
    }

    private var terminalNote: String {
        if selection.wrappedValue == TerminalApp.ghostty.bundleID {
            return String(localized: "Ghostty opens a new tab. Set macos-dock-drop-behavior = new-window in Ghostty for a window.")
        }
        return String(localized: "Opens at the dropped folder, or at a file’s folder.")
    }

    private var recentsNote: String {
        let n = preferences.recentFolders.count
        switch n {
        case 0: return String(localized: "None yet. Folders you move things to appear in the Move menu.")
        case 1: return String(localized: "1 folder in the Move menu")
        default: return String(localized: "\(n) folders in the Move menu")
        }
    }

    private static func icon(for appURL: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
