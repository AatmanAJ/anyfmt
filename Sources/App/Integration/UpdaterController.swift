import AppKit
import Sparkle
import AnyfmtCore

/// Sparkle 2, strictly opt-in (D-024): the updater isn't even started until the
/// user turns on update checks. No system profiling, no checks on first launch.
@MainActor
final class UpdaterController: NSObject {
    private let controller: SPUStandardUpdaterController
    private(set) var started = false

    override init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }

    /// Applies the user's choice. Called at launch and whenever the setting changes.
    func apply(enabled: Bool) {
        let updater = controller.updater
        if enabled {
            if !started {
                do {
                    try updater.start()
                    started = true
                } catch {
                    Log.app.error("sparkle start failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
            }
            updater.automaticallyChecksForUpdates = true
            updater.sendsSystemProfile = false
        } else if started {
            updater.automaticallyChecksForUpdates = false
        }
    }

    var canCheck: Bool { started && controller.updater.canCheckForUpdates }

    func checkNow() {
        if !started { apply(enabled: true) }
        controller.checkForUpdates(nil)
    }

    /// Host of the appcast, shown in the opt-in copy.
    static var feedHost: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap { URL(string: $0)?.host } ?? "the update server"
    }
}
