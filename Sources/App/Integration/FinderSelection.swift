import AppKit
import ApplicationServices
import AnyfmtCore

/// Reads the current Finder selection via Apple Events (needs the user's
/// Automation consent for Finder; D-004). Never prompts unless `ask` is true.
enum FinderSelection {
    static let finderBundleID = "com.apple.finder"

    enum Permission { case granted, denied, notDetermined, finderNotRunning }

    static func permission(ask: Bool) -> Permission {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first != nil else {
            return .finderNotRunning
        }
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        guard let desc = target.aeDesc else { return .denied }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        case OSStatus(procNotFound): return .finderNotRunning
        default: return .denied
        }
    }

    /// File URLs of the Finder selection, or [] if nothing is selected / not permitted.
    /// Runs the script off the main thread; Apple Events can take a moment.
    static func read(ask: Bool = true) async -> [URL] {
        guard permission(ask: ask) == .granted else { return [] }
        return await Task.detached(priority: .userInitiated) { () -> [URL] in
            let source = """
            tell application "Finder"
              set out to {}
              repeat with i in (get selection)
                set end of out to POSIX path of (i as alias)
              end repeat
              return out
            end tell
            """
            var error: NSDictionary?
            guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
                Log.app.error("finder selection failed: \(String(describing: error), privacy: .public)")
                return []
            }
            guard result.numberOfItems > 0 else { return [] }
            return (1...result.numberOfItems).compactMap { result.atIndex($0)?.stringValue }.map { URL(fileURLWithPath: $0) }
        }.value
    }
}
