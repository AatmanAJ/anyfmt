import AppKit
import SwiftUI
import HaloCore

/// Pieces of onboarding other lanes own. Wired by the app delegate.
@MainActor
struct OnboardingHooks {
    /// Lane B's real `RadialMenuView` for the demo. nil uses `DemoWheelRing`.
    /// The view is drawn centred on the wheel centre; it should honour
    /// `context.highlighted` (the demo does the angular hit test).
    var demoWheel: ((DemoWheelContext) -> AnyView)?
    /// Onboarding finished or was skipped/closed (settings are already saved).
    var onFinish: (() -> Void)?
    /// The update-check opt-in changed (start/stop Sparkle's updater).
    var onUpdateChecksChanged: ((Bool) -> Void)?
    /// The Finder Return shortcut was switched on or off.
    var onFinderShortcutChanged: ((Bool) -> Void)?

    init(demoWheel: ((DemoWheelContext) -> AnyView)? = nil, onFinish: (() -> Void)? = nil,
         onUpdateChecksChanged: ((Bool) -> Void)? = nil, onFinderShortcutChanged: ((Bool) -> Void)? = nil) {
        self.demoWheel = demoWheel
        self.onFinish = onFinish
        self.onUpdateChecksChanged = onUpdateChecksChanged
        self.onFinderShortcutChanged = onFinderShortcutChanged
    }
}

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case demo, permissions, launch, updates

    var id: Int { rawValue }
    /// 1-based, for screenshots and VoiceOver ("Step 2 of 4").
    var number: Int { rawValue + 1 }
    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }
    var previous: OnboardingPage? { OnboardingPage(rawValue: rawValue - 1) }
    var isLast: Bool { next == nil }
}

@MainActor
final class OnboardingModel: ObservableObject {
    let settings: AppSettings
    let loginItem: LaunchAtLogin
    let coach: PermissionsCoach
    let info: AppInfo
    let hooks: OnboardingHooks
    let demo: DemoModel

    @Published var page: OnboardingPage = .demo
    /// Direction of the last page change, for the slide transition.
    @Published private(set) var forward = true
    @Published private(set) var finished = false

    /// Closes the window; set by the controller.
    var close: () -> Void = {}

    init(settings: AppSettings = .shared, loginItem: LaunchAtLogin = .shared, coach: PermissionsCoach = .shared,
         info: AppInfo = .main, hooks: OnboardingHooks = OnboardingHooks()) {
        self.settings = settings
        self.loginItem = loginItem
        self.coach = coach
        self.info = info
        self.hooks = hooks
        self.demo = DemoModel(settings: settings)
    }

    func goNext() {
        guard let n = page.next else { finish(); return }
        forward = true
        page = n
    }

    func goBack() {
        guard let p = page.previous else { return }
        forward = false
        page = p
    }

    func go(to p: OnboardingPage) {
        forward = p.rawValue > page.rawValue
        page = p
    }

    func setUpdateChecks(_ on: Bool) {
        settings.updateChecksEnabled = on
        hooks.onUpdateChecksChanged?(on)
    }

    func setFinderShortcut(_ on: Bool) {
        settings.finderShortcutEnabled = on
        hooks.onFinderShortcutChanged?(on)
    }

    /// Done, skipped or closed: never shown again automatically.
    func finish() {
        guard !finished else { return }
        finished = true
        settings.onboardingCompleted = true
        demo.stop()
        hooks.onFinish?()
        close()
    }
}
