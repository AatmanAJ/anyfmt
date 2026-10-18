import AppKit
import HaloCore

/// One place for the app delegate to reach the UI lane's windows.
///
///     // applicationDidFinishLaunching
///     if AppShellUI.handleLaunchArguments() { return }   // screenshot render / UI-test flags
///     AppShellUI.showOnboardingIfNeeded()
///     // menu items
///     AppShellUI.showSettings()      AppShellUI.showAbout()
@MainActor
enum AppShellUI {
    static func showSettings(_ pane: SettingsPane? = nil) { SettingsWindowController.show(pane) }

    static func showAbout() { AboutWindowController.show() }

    /// First launch: onboarding. Never again once finished, skipped or closed.
    static func showOnboardingIfNeeded(settings: AppSettings = .shared) {
        guard !settings.onboardingCompleted else { return }
        OnboardingWindowController.show(settings: settings)
    }

    /// Handles UI-lane launch arguments. Returns true when the app should quit
    /// afterwards (a screenshot render).
    ///
    /// - `--render-ui-screens <dir>`: offscreen screenshots (D-025), then quit.
    /// - `--reset-onboarding`: marks onboarding as not done (UI tests).
    /// - `--show-onboarding`: shows onboarding now (UI tests).
    @discardableResult
    static func handleLaunchArguments(_ args: [String] = ProcessInfo.processInfo.arguments,
                                      settings: AppSettings = .shared) -> Bool {
        if let i = args.firstIndex(of: "--render-ui-screens") {
            let dir = args.indices.contains(i + 1) ? URL(fileURLWithPath: args[i + 1], isDirectory: true)
                : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/screens")
            do {
                let files = try UIScreenshots.renderAll(to: dir)
                Log.settings.info("rendered \(files.count) UI screenshots into \(dir.path, privacy: .public)")
            } catch {
                Log.settings.error("UI screenshots failed: \(String(describing: error), privacy: .public)")
            }
            return true
        }
        if args.contains("--unregister-login-item") {
            // scripts/reset-first-run.sh: SMAppService items can only be removed by the app itself.
            try? LoginItemService.live.unregister()
            return true
        }
        if args.contains("--reset-onboarding") { settings.onboardingCompleted = false }
        if args.contains("--show-onboarding") { OnboardingWindowController.show(settings: settings) }
        return false
    }
}
