import AppKit
import AnyfmtCore

/// Zero-permission way to open the wheel for a Finder selection: the
/// "Open in <name> Wheel" item in Finder's Services menu (D-004). Users can
/// bind it to any shortcut in System Settings › Keyboard › Shortcuts › Services.
@MainActor
final class ServicesProvider: NSObject {
    var onFiles: (@MainActor ([URL]) -> Void)?

    /// Selector name must match `NSMessage` in Info.plist (project.yml).
    @objc func openWheelForFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = (pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else {
            error.pointee = String(localized: "No files were selected.") as NSString
            return
        }
        onFiles?(urls)
    }

    static func register(_ provider: ServicesProvider) {
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
    }
}
