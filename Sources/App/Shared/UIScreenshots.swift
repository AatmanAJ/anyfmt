import AppKit
import ServiceManagement
import SwiftUI
import AnyfmtCore

/// Offscreen screenshots of Settings, onboarding and About for docs/screens
/// (D-025: no Automation Mode needed). Windows are ordered in fully
/// transparent so nothing flashes on screen, then drawn with `cacheDisplay`.
/// Vibrancy doesn't render offscreen; everything else does.
///
/// Used by `UIScreenshotTests` and, once wired, `anyfmt --render-ui-screens <dir>`.
@MainActor
enum UIScreenshots {
    enum Appearance: String, CaseIterable {
        case light, dark
        var nsAppearance: NSAppearance? { NSAppearance(named: self == .light ? .aqua : .darkAqua) }
    }

    enum RenderError: Error { case noDefaults, captureFailed(String) }

    /// Everything, both appearances. Returns the files written.
    @discardableResult
    static func renderAll(to dir: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [URL] = []
        out += try renderSettings(to: dir)
        out += try renderOnboarding(to: dir)
        out += try renderAbout(to: dir)
        out += try renderOptionsGallery(to: dir)
        return out
    }

    // MARK: OptionsForm gallery (every control kind, regular + compact)

    static func renderOptionsGallery(to dir: URL) throws -> [URL] {
        var out: [URL] = []
        for appearance in Appearance.allCases {
            let window = AnyfmtWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 700),
                                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = String(localized: "Options")
            window.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: OptionsGallery()
                .snapshotActiveAppearance()
                .environment(\.isSnapshot, true))
            window.contentView = host
            window.setContentSize(host.fittingSize)
            prepare(window, appearance)
            settle(0.35)
            window.setContentSize(host.fittingSize)
            settle(0.15)
            out.append(try write(window, to: dir.appendingPathComponent("options-form-\(appearance.rawValue).png")))
            window.orderOut(nil)
        }
        return out
    }

    // MARK: Settings

    static func renderSettings(to dir: URL, panes: [SettingsPane] = SettingsPane.allCases) throws -> [URL] {
        var out: [URL] = []
        for appearance in Appearance.allCases {
            let sample = try SampleState()
            defer { sample.tearDown() }
            let controller = SettingsWindowController(model: sample.model, pane: panes.first ?? .general)
            controller.isSnapshot = true
            guard let window = controller.window else { continue }
            prepare(window, appearance)
            for pane in panes {
                controller.select(pane, animate: false)
                settle(0.35)
                controller.select(pane, animate: false)
                settle(0.15)
                out.append(try write(window, to: dir.appendingPathComponent("settings-\(pane.rawValue)-\(appearance.rawValue).png")))
                if pane == .formats {
                    sample.model.formatsTab = .tools
                    settle(0.35)
                    out.append(try write(window, to: dir.appendingPathComponent("settings-formats-tools-\(appearance.rawValue).png")))
                    sample.model.formatsTab = .formats
                }
            }
            window.orderOut(nil)
        }
        return out
    }

    // MARK: Onboarding

    /// Every onboarding step, light and dark, into `<dir>/onboarding/` (PLAN-PHASE2 §F).
    static func renderOnboarding(to root: URL) throws -> [URL] {
        let dir = root.appendingPathComponent("onboarding", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [URL] = []
        for appearance in Appearance.allCases {
            let suffix = appearance == .light ? "" : "-dark"
            for page in OnboardingPage.allCases {
                let sample = try SampleState()
                defer { sample.tearDown() }
                let controller = OnboardingWindowController(model: sample.onboardingModel(page: page))
                controller.isSnapshot = true
                guard let window = controller.window else { continue }
                prepare(window, appearance)
                controller.loadContent()
                settle(0.4)
                out.append(try write(window, to: dir.appendingPathComponent("onboarding-\(page.number)\(suffix).png")))
                if page == .demo {
                    for (staging, name) in [(DemoModel.Staging.wheel(.convert), "wheel"), (.done, "done")] {
                        controller.model.demo.stage(staging)
                        settle(0.45)
                        out.append(try write(window, to: dir.appendingPathComponent("onboarding-\(page.number)-\(name)\(suffix).png")))
                    }
                }
                window.orderOut(nil)
            }
        }
        return out
    }

    // MARK: About

    static func renderAbout(to dir: URL) throws -> [URL] {
        var out: [URL] = []
        for appearance in Appearance.allCases {
            let controller = AboutWindowController(info: SampleState.info, engines: BundledEngines.all)
            controller.isSnapshot = true
            guard let window = controller.window else { continue }
            prepare(window, appearance)
            controller.loadContent()
            settle(0.3)
            let name = appearance == .light ? "about.png" : "about-dark.png"
            out.append(try write(window, to: dir.appendingPathComponent(name)))
            window.orderOut(nil)
        }
        return out
    }

    // MARK: Plumbing

    private static func prepare(_ window: NSWindow, _ appearance: Appearance) {
        window.appearance = appearance.nsAppearance
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
    }

    /// Lets SwiftUI lay out and AppKit display.
    static func settle(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// PNG of the whole window, title bar and toolbar included.
    static func capture(_ window: NSWindow) -> NSBitmapImageRep? {
        guard let content = window.contentView else { return nil }
        let frameView = content.superview ?? content
        frameView.layoutSubtreeIfNeeded()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return nil }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        return rep
    }

    private static func write(_ window: NSWindow, to url: URL) throws -> URL {
        // No focus rings or selected text in screenshots.
        window.makeFirstResponder(nil)
        settle(0.05)
        guard let rep = capture(window), let png = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.captureFailed(url.lastPathComponent)
        }
        try png.write(to: url, options: .atomic)
        return url
    }
}

/// Deterministic sample state for screenshots: a throwaway defaults suite,
/// fake login item and permission probes (nothing touches TCC or launchd).
@MainActor
struct SampleState {
    let suiteName: String
    let defaults: UserDefaults
    let settings: AppSettings
    let model: SettingsModel
    let coach: PermissionsCoach
    let loginItem: LaunchAtLogin

    static let info = AppInfo(version: "1.0", build: "100", bundleID: Brand.bundleID, updateHost: nil,
                              helpersURL: URL(fileURLWithPath: "/Applications/\(Brand.name).app/Contents/Helpers"))

    init() throws {
        suiteName = "\(Brand.bundleID).screenshots.\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else { throw UIScreenshots.RenderError.noDefaults }
        defaults = d
        settings = AppSettings(defaults: d)
        settings.favouriteFormats = [Formats.jpg, Formats.png, Formats.webp, Formats.pdf]
        settings.hiddenFormats = [Formats.bmp, Formats.tga]
        settings.formatDefaults = [Formats.jpg: OptionValues([OptionKey.quality: .int(82)])]
        settings.finderShortcutEnabled = true
        settings.namePattern = "{name}"
        settings.hiddenTools = [ToolIDs.readCodes]
        let probe = PermissionProbe(accessibility: { true }, automation: { .notGranted },
                                    requestAccessibility: {}, requestAutomation: {},
                                    inputMonitoring: { false }, requestInputMonitoring: {})
        coach = PermissionsCoach(probe: probe, defaults: d)
        loginItem = LaunchAtLogin(service: .fake(.enabled))
        let hooks = SettingsHooks(packs: { SampleState.packs }, onCheckForUpdates: {})
        model = SettingsModel(settings: settings, hooks: hooks, loginItem: loginItem, coach: coach, info: Self.info)
    }

    func onboardingModel(page: OnboardingPage) -> OnboardingModel {
        let m = OnboardingModel(settings: settings, loginItem: LaunchAtLogin(service: .fake(.notRegistered)), coach: coach,
                                info: Self.info, hooks: OnboardingHooks())
        m.page = page
        return m
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    static var packs: [PackStatus] {
        [
            PackStatus(id: "office", name: String(localized: "Office pack"),
                       summary: String(localized: "Pixel-perfect Word, PowerPoint and Excel to PDF, using LibreOffice."),
                       installed: false, version: "26.8", downloadBytes: 312_000_000, host: "download.documentfoundation.org",
                       licence: "MPL-2.0", install: {}, remove: {}),
            PackStatus(id: "pandoc", name: String(localized: "pandoc pack"),
                       summary: String(localized: "pandoc’s document conversions, for the highest-fidelity DOCX, EPUB and ODT."),
                       installed: true, version: "3.12.1", downloadBytes: 192_000_000, host: "github.com",
                       licence: "GPL-2.0-or-later", install: {}, remove: {}),
        ]
    }
}
