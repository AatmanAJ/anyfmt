import AppKit
import SwiftUI
import HaloCore

/// First-run window: four short screens with progress dots. ← / → move,
/// Return continues, Skip finishes. Closing the window counts as finishing,
/// so it never nags again.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static var hooks = OnboardingHooks()
    private static var instance: OnboardingWindowController?

    static let contentSize = NSSize(width: 720, height: 520)

    /// Shows onboarding (single instance). The app delegate calls this at
    /// launch when `AppSettings.onboardingCompleted` is false.
    static func show(settings: AppSettings = .shared) {
        let controller = instance ?? OnboardingWindowController(model: OnboardingModel(settings: settings, hooks: hooks))
        instance = controller
        controller.loadContent()
        controller.window?.center()
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        controller.window?.makeKeyAndOrderFront(nil)
    }

    let model: OnboardingModel
    var isSnapshot = false
    private var keys: LocalKeyMonitor?
    private var contentLoaded = false

    init(model: OnboardingModel) {
        self.model = model
        let window = HaloWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
                                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = String(localized: "Welcome to \(Brand.name)")
        window.isMovableByWindowBackground = false // the demo drags inside the window
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.identifier = NSUserInterfaceItemIdentifier("onboarding")
        super.init(window: window)
        window.delegate = self
        model.close = { [weak self] in self?.window?.close() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func loadContent() {
        guard let window, !contentLoaded else { return }
        contentLoaded = true
        let root = AnyView(
            OnboardingView(model: model)
                .snapshotActiveAppearance()
                .environment(\.isSnapshot, isSnapshot)
        )
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(Self.contentSize)
        startKeys()
    }

    private func startKeys() {
        guard keys == nil, let window else { return }
        let m = LocalKeyMonitor(window: window, onKeyDown: { [weak self] event in
            self?.handleKey(event) ?? false
        })
        m.start()
        keys = m
    }

    /// ← back, → / Return forward. Ignored while a text field has focus.
    private func handleKey(_ event: NSEvent) -> Bool {
        if window?.firstResponder is NSTextView { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard mods.isEmpty else { return false }
        switch Int(event.keyCode) {
        case 123: // ←
            guard model.page.previous != nil else { return false }
            withAnimation(pageAnimation) { model.goBack() }
            return true
        case 124, 36, 76: // →, Return, Enter
            if model.demo.openKind != nil {
                // Like the real wheel: Return applies the highlighted segment.
                if Int(event.keyCode) != 124, let id = model.demo.highlighted {
                    withAnimation(pageAnimation) { model.demo.select(id) }
                }
                return true
            }
            withAnimation(pageAnimation) { model.goNext() }
            return true
        default:
            return false
        }
    }

    private var pageAnimation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: DesignTokens.Motion.crossfade)
            : .spring(response: 0.38, dampingFraction: 0.86)
    }

    func windowWillClose(_ notification: Notification) {
        keys?.stop()
        keys = nil
        model.demo.stop()
        // Tear the SwiftUI tree down so permission polling stops with it.
        window?.contentView = nil
        contentLoaded = false
        // Already closing: finishing must not close the window again.
        model.close = {}
        if !isSnapshot { model.finish() }
        if Self.instance === self { Self.instance = nil }
    }
}

/// Pages, progress dots and the footer buttons.
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page(model.page)
                    .id(model.page)
                    .transition(transition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 30) // below the transparent title bar
            .clipped()

            footer
        }
        .frame(width: OnboardingWindowController.contentSize.width, height: OnboardingWindowController.contentSize.height)
        .background(background)
        .ignoresSafeArea()
        .toggleStyle(HaloSwitchStyle())
    }

    @ViewBuilder private func page(_ p: OnboardingPage) -> some View {
        switch p {
        case .welcome: OnboardingWelcomePage()
        case .activate: OnboardingActivatePage(model: model, licence: model.licence)
        case .demo: OnboardingDemoPage(demo: model.demo, settings: model.settings, wheelHook: model.hooks.demoWheel)
        case .permissions: OnboardingPermissionsPage(model: model, settings: model.settings)
        case .launch: OnboardingLaunchPage(model: model)
        case .updates: OnboardingUpdatesPage(model: model, settings: model.settings)
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        let inEdge: Edge = model.forward ? .trailing : .leading
        let outEdge: Edge = model.forward ? .leading : .trailing
        return .asymmetric(insertion: .move(edge: inEdge).combined(with: .opacity),
                           removal: .move(edge: outEdge).combined(with: .opacity))
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: DesignTokens.Motion.crossfade) : .spring(response: 0.38, dampingFraction: 0.86)
    }

    private var footer: some View {
        HStack {
            Button("Skip") { model.finish() }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(model.page.isLast ? 0 : 1)
                .disabled(model.page.isLast)
                .accessibilityIdentifier("onboarding.skip")
                .frame(width: 200, alignment: .leading)

            Spacer()
            ProgressDots(count: OnboardingPage.allCases.count, current: model.page.rawValue) { i in
                if let p = OnboardingPage(rawValue: i) { withAnimation(animation) { model.go(to: p) } }
            }
            Spacer()

            HStack(spacing: DesignTokens.Space.s) {
                if model.page.previous != nil {
                    Button("Back") { withAnimation(animation) { model.goBack() } }
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.back")
                }
                Button {
                    withAnimation(animation) { model.goNext() }
                } label: {
                    Text(model.page.isLast ? "Start Using \(Brand.name)" : "Continue")
                        .frame(minWidth: model.page.isLast ? 140 : 84)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.iris)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(model.page.isLast ? "onboarding.finish" : "onboarding.continue")
            }
            .frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, DesignTokens.Space.xl)
        .padding(.top, DesignTokens.Space.s)
        .padding(.bottom, DesignTokens.Space.xl)
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Color.iris.opacity(0.16), Color.iris.opacity(0)],
                           center: UnitPoint(x: 0.5, y: -0.15), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color.mint.opacity(0.08), Color.mint.opacity(0)],
                           center: UnitPoint(x: 1.0, y: 1.1), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

private struct ProgressDots: View {
    let count: Int
    let current: Int
    let go: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.iris : Color.primary.opacity(0.18))
                    .frame(width: i == current ? 20 : 7, height: 7)
                    .contentShape(Rectangle().inset(by: -4))
                    .onTapGesture { go(i) }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
        .accessibilityIdentifier("onboarding.progress")
    }
}
