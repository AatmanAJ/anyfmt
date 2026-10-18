import AppKit
import HaloCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    /// True while hosted by XCTest: skip global monitors, onboarding, windows.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let launch = LaunchOptions()
    private(set) var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard !Self.isRunningTests else { return }
        if let dir = launch.renderGallery {
            renderGallery(into: dir)
            exit(0)
        }
        let c = AppCoordinator(launch: launch)
        c.start()
        coordinator = c
        AppShell.install(on: c, launch: launch)
        launch.writePerfReport()
        if launch.quitAfterReady { NSApp.terminate(nil) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == Brand.urlScheme {
            if !CloudIntegration.handleCallback(url) { Log.app.info("unhandled URL \(url.absoluteString, privacy: .public)") }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    /// `make gallery`: every wheel state, progress card and action screen, offscreen.
    private func renderGallery(into dir: URL) {
        do {
            let wheels = try WheelGallery.renderAll(to: dir.appendingPathComponent("gallery"), scale: 1)
            let cards = try ProgressCardGallery.render(into: dir)
            let actions = try ActionScreens.render(into: dir)
            let total = wheels.count + cards.count + actions.count + AppShell.renderScreens(into: dir)
            FileHandle.standardError.write(Data("rendered \(total) images into \(dir.path)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("gallery failed: \(error)\n".utf8))
            exit(1)
        }
    }
}

/// Settings, About and onboarding presenters. Filled in when the UI lane lands.
@MainActor
enum AppShell {
    static func install(on coordinator: AppCoordinator, launch: LaunchOptions) {
        coordinator.setMenuPresenters(settings: {}, about: { NSApp.orderFrontStandardAboutPanel(nil) }, onboarding: {})
    }

    static func renderScreens(into dir: URL) -> Int { 0 }
}
