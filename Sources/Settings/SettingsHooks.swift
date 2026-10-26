import AppKit
import SwiftUI
import AnyfmtCore

/// Pieces of Settings that other lanes own. The app delegate wires these
/// before the window first opens (`SettingsWindowController.hooks = …`).
/// Every hook has a sensible default, so Settings works on its own.
@MainActor
struct SettingsHooks {
    /// Lane I's `AccountSettingsView`. nil shows a calm "cloud is optional" panel.
    var accountPane: (() -> AnyView)?
    /// Lane H's terminal chooser (Terminal / iTerm2 / Ghostty / Warp). nil hides the row.
    var terminalPicker: (() -> AnyView)?
    /// Optional Office / pandoc packs. Re-read whenever the Engines pane appears
    /// or a pack button is pressed, and every second while one is busy.
    var packs: () -> [PackStatus] = { [] }
    /// Bundled engines. Default: the table embedded from Engines/VERSIONS.md.
    var engineVersions: () -> [EngineInfo] = { BundledEngines.all }
    /// "Check Now" in General. nil disables the button.
    var onCheckForUpdates: (() -> Void)?
    /// The update-check opt-in changed (Sparkle starts/stops its updater).
    var onUpdateChecksChanged: ((Bool) -> Void)?
    /// Trigger keys, tap threshold or the drop-ring hotkey changed: the drag
    /// sensor and hotkey registration should reapply the configuration.
    var onTriggerKeysChanged: (() -> Void)?
    /// Finder Return shortcut was switched on or off (installs/removes the tap).
    var onFinderShortcutChanged: ((Bool) -> Void)?

    init(accountPane: (() -> AnyView)? = nil,
         terminalPicker: (() -> AnyView)? = nil,
         packs: @escaping () -> [PackStatus] = { [] },
         engineVersions: @escaping () -> [EngineInfo] = { BundledEngines.all },
         onCheckForUpdates: (() -> Void)? = nil,
         onUpdateChecksChanged: ((Bool) -> Void)? = nil,
         onTriggerKeysChanged: (() -> Void)? = nil,
         onFinderShortcutChanged: ((Bool) -> Void)? = nil) {
        self.accountPane = accountPane
        self.terminalPicker = terminalPicker
        self.packs = packs
        self.engineVersions = engineVersions
        self.onCheckForUpdates = onCheckForUpdates
        self.onUpdateChecksChanged = onUpdateChecksChanged
        self.onTriggerKeysChanged = onTriggerKeysChanged
        self.onFinderShortcutChanged = onFinderShortcutChanged
    }
}

/// An optional, user-downloaded engine pack (never bundled, D-022).
struct PackStatus: Identifiable {
    var id: String
    var name: String
    /// One line: what it adds.
    var summary: String
    var installed: Bool
    /// Installed version, or the version that would be downloaded.
    var version: String
    var downloadBytes: Int64
    /// Where the download comes from, shown verbatim ("github.com").
    var host: String
    var licence: String
    /// 0...1 while downloading/removing; nil when idle.
    var progress: Double?
    var install: @MainActor () -> Void
    var remove: @MainActor () -> Void

    init(id: String, name: String, summary: String, installed: Bool, version: String, downloadBytes: Int64,
         host: String, licence: String, progress: Double? = nil,
         install: @escaping @MainActor () -> Void, remove: @escaping @MainActor () -> Void) {
        self.id = id
        self.name = name
        self.summary = summary
        self.installed = installed
        self.version = version
        self.downloadBytes = downloadBytes
        self.host = host
        self.licence = licence
        self.progress = progress
        self.install = install
        self.remove = remove
    }
}

/// A bundled engine for Settings › Engines and the About credits.
struct EngineInfo: Identifiable, Hashable, Sendable {
    var name: String
    var version: String
    var licence: String
    /// Where it lives in the bundle, e.g. "Contents/Helpers/ffmpeg".
    var location: String
    /// Folder of licence texts inside the bundle's LICENSES (nil = the whole folder).
    var licenceFolder: URL?
    var id: String { name }

    /// Name without notes in parentheses: "libaom (encoder only)" → "libaom".
    var shortName: String { name.components(separatedBy: " (").first ?? name }
}

/// The bundled-engine table, embedded from `Engines/VERSIONS.md` so the app
/// can show it without reading the repo. `BundledEnginesTests` fails if the
/// two drift apart.
enum BundledEngines {
    /// The table rows of Engines/VERSIONS.md, verbatim.
    static let versionsTable = #"""
| FFmpeg | 9.0.2 | https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz | GPL-2.0-or-later (as configured with `--enable-gpl`) | `Contents/Helpers/ffmpeg`, `ffprobe`, `Contents/Frameworks/libav*.dylib`, `libsw*.dylib` |
| x264 | stable @ b35605ace3dd | code.videolan.org archive of that commit | GPL-2.0-or-later | statically inside libavcodec |
| x265 | 4.2 | https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.2.tar.gz | GPL-2.0-or-later | statically inside libavcodec |
| libaom (encoder only) | 3.15.2 | https://storage.googleapis.com/aom-releases/libaom-3.15.2.tar.gz | BSD-2-Clause + AOM patent licence | statically inside libavcodec |
| dav1d | 1.5.4 | https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz | BSD-2-Clause | statically inside libavcodec |
| libvpx | 1.17.0 | https://github.com/webmproject/libvpx/archive/refs/tags/v1.17.0.tar.gz | BSD-3-Clause + patent grant | statically inside libavcodec |
| Opus | 1.6.1 | https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz | BSD-3-Clause | statically inside libavcodec |
| libogg | 1.3.6 | https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz | BSD-3-Clause | statically inside libavcodec/libavformat |
| libvorbis | 1.3.7 | https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz | BSD-3-Clause | statically inside libavcodec |
| LAME | 3.100 | https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz | LGPL-2.0-or-later | statically inside libavcodec |
| libwebp | 1.6.0 | https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz | BSD-3-Clause + patent grant | statically inside libavcodec |
| resvg | 0.48.1 | crates.io `resvg` 0.48.1, `cargo install --locked` | Apache-2.0 OR MIT (crate graph: `LICENSES/resvg-0.48.1/CRATES.md`) | `Contents/Helpers/resvg` |
| Sparkle | 2.10.0 | SwiftPM, github.com/sparkle-project/Sparkle tag 2.10.0 | MIT | `Contents/Frameworks/Sparkle.framework` |
"""#

    /// Apple frameworks and system tools anyfmt uses but doesn't redistribute.
    static let systemFrameworks = ["ImageIO", "PDFKit", "AVFoundation", "VideoToolbox", "Vision", "WebKit", "Quick Look", "bsdtar"]

    /// Bundle.main/Contents/Resources/LICENSES (added to the bundle by the build).
    static var licencesFolder: URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("LICENSES", isDirectory: true),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static var all: [EngineInfo] { parse(versionsTable, licences: licencesFolder) }

    /// Parses markdown table rows into engines. Short versions for display:
    /// "stable @ b35605ace3dd" → "stable b35605a"; licence notes in parentheses
    /// are dropped ("GPL-2.0-or-later (as configured…)" → "GPL-2.0-or-later").
    static func parse(_ table: String, licences: URL?) -> [EngineInfo] {
        let folders = licences.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
        return table.split(separator: "\n").compactMap { line -> EngineInfo? in
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            // "| a | b | c | d | e |" → ["", a, b, c, d, e, ""]
            guard cells.count >= 7, !cells[1].isEmpty, cells[1] != "Component", !cells[1].hasPrefix("---") else { return nil }
            let name = cells[1]
            let version = shortVersion(cells[2])
            let licence = cells[4].components(separatedBy: " (").first ?? cells[4]
            let location = cells[5].replacingOccurrences(of: "`", with: "")
            let slug = (name.split(separator: " ").first.map(String.init) ?? name).lowercased()
            let folder = folders.first { $0.lowercased().hasPrefix(slug + "-") }
            return EngineInfo(name: name, version: version, licence: licence, location: location,
                              licenceFolder: folder.flatMap { licences?.appendingPathComponent($0, isDirectory: true) })
        }
    }

    static func shortVersion(_ raw: String) -> String {
        let parts = raw.components(separatedBy: " @ ")
        guard parts.count == 2 else { return raw }
        return "\(parts[0]) \(parts[1].prefix(7))"
    }

    /// Opens the licence folder for one engine, or the whole LICENSES folder.
    /// Without a bundled copy (a dev build), opens the repository's LICENSES.
    @MainActor
    static func revealLicences(_ engine: EngineInfo? = nil) {
        if let folder = engine?.licenceFolder ?? licencesFolder {
            NSWorkspace.shared.open(folder)
        } else if let url = Brand.sourceURL?.appendingPathComponent("tree/main/LICENSES") {
            NSWorkspace.shared.open(url)
        }
    }
}
