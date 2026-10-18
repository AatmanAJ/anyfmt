import AppKit
import HaloCore

/// Optional engine packs in Settings › Engines (D-022). Halo never downloads them:
/// "Get…" opens the official download in the browser, then the user picks the
/// downloaded file, which is verified against its pinned SHA-256 before install.
@MainActor
enum PackCatalog {
    private struct Entry {
        let id: String
        let spec: PackSpec
        let summary: String
        let licence: String
        let approxBytes: Int64
    }

    private static let entries: [Entry] = [
        Entry(id: "office", spec: OfficePack.spec,
              summary: String(localized: "Faithful PowerPoint, Keynote, legacy Office and OpenDocument conversions (LibreOffice)."),
              licence: "MPL-2.0", approxBytes: 360_000_000),
        Entry(id: "pandoc", spec: PandocPack.spec,
              summary: String(localized: "pandoc’s document conversions for DOCX, ODT and EPUB."),
              licence: "GPL-2.0-or-later", approxBytes: 42_313_957),
    ]

    static func statuses() -> [PackStatus] {
        entries.map { e in
            let installer = PackInstaller(spec: e.spec)
            let installed = FileManager.default.fileExists(atPath: installer.installedURL.path)
            return PackStatus(id: e.id, name: e.spec.name, summary: e.summary, installed: installed,
                              version: e.spec.version, downloadBytes: e.approxBytes,
                              host: e.spec.downloadURL?.host ?? "", licence: e.licence,
                              install: { install(e) }, remove: { remove(e) })
        }
    }

    private static func install(_ e: Entry) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Install \(e.spec.name) \(e.spec.version)")
        alert.informativeText = String(localized: "Your browser will download the official file from \(e.spec.downloadURL?.host ?? "its website"). When it’s done, choose the downloaded file here. \(Brand.name) checks it against the official checksum before installing. Nothing is sent anywhere.")
        alert.addButton(withTitle: String(localized: "Open Download Page"))
        alert.addButton(withTitle: String(localized: "I Already Have It…"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = e.spec.downloadURL { NSWorkspace.shared.open(url) }
            chooseFile(for: e)
        case .alertSecondButtonReturn:
            chooseFile(for: e)
        default:
            break
        }
    }

    private static func chooseFile(for e: Entry) {
        let panel = NSOpenPanel()
        panel.message = String(localized: "Choose the downloaded \(e.spec.name) file")
        panel.prompt = String(localized: "Verify & Install")
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let file = panel.url else { return }
        Task { @MainActor in
            do {
                _ = try await PackInstaller(spec: e.spec).install(from: file)
                Router.invalidateLive()
                Task.detached(priority: .utility) { Router.warmLive() }
                ToastHUD.show(String(localized: "\(e.spec.name) installed. New conversions are available."))
            } catch {
                ToastHUD.show(error.localizedDescription, isError: true)
            }
        }
    }

    private static func remove(_ e: Entry) {
        do {
            try PackInstaller(spec: e.spec).uninstall()
            Router.invalidateLive()
            Task.detached(priority: .utility) { Router.warmLive() }
            ToastHUD.show(String(localized: "\(e.spec.name) removed."))
        } catch {
            ToastHUD.show(error.localizedDescription, isError: true)
        }
    }
}
