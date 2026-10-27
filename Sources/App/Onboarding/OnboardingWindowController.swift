import AppKit
import SwiftUI
import AnyfmtCore

/// First-run window: four short screens with progress dots. ← / → move,
/// Return continues, Skip finishes. Closing the window counts as finishing,
/// so it never nags again.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static var hooks = OnboardingHooks()
    private static var instance: OnboardingWindowController?

    static let contentSize = NSSize(width: DesignTokens.Component.Onboarding.windowWidth,
                                    height: DesignTokens.Component.Onboarding.windowHeight)

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
        let window = AnyfmtWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
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
        OnboardingMotion.page(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
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

/// Page motion: the `glide` curve, or a short crossfade under Reduce Motion.
enum OnboardingMotion {
    static func page(reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: DesignTokens.Curve.reducedCrossfade) }
        let g = DesignTokens.Curve.glide
        return .timingCurve(g.c1.x, g.c1.y, g.c2.x, g.c2.y, duration: g.duration)
    }

    static func snap(reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: DesignTokens.Curve.reducedCrossfade) }
        let s = DesignTokens.Curve.snap
        return .timingCurve(s.c1.x, s.c1.y, s.c2.x, s.c2.y, duration: s.duration)
    }
}

/// The one banded gradient a page may carry, as a full-height column on the right.
enum OnboardingSpotlight: Equatable {
    case none, heat, cobalt

    init(_ page: OnboardingPage) {
        switch page {
        case .welcome: self = .heat
        case .permissions: self = .cobalt
        case .demo, .launch, .updates, .activate: self = .none
        }
    }

    var width: CGFloat {
        switch self {
        case .none: 0
        case .heat: DesignTokens.Component.Onboarding.heatColumn
        case .cobalt: DesignTokens.Component.Onboarding.cobaltColumn
        }
    }
}

/// Full-bleed pages: the page column on the left, the footer under it, and the
/// page's band column (if any) running the full height on the right.
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        let spotlight = OnboardingSpotlight(model.page)
        ZStack(alignment: .topLeading) {
            Color.anyfmtWindow

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                band(spotlight)
                    .frame(width: spotlight.width)
                    .clipped()
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    page(model.page)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .id(model.page)
                        .transition(transition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, T.top)
                .padding(.bottom, DesignTokens.Space.m)
                .padding(.horizontal, T.margin)
                .clipped()

                footer
            }
            .padding(.trailing, spotlight.width)
        }
        .frame(width: OnboardingWindowController.contentSize.width, height: OnboardingWindowController.contentSize.height)
        .foregroundStyle(Color.anyfmtInk)
        .ignoresSafeArea()
        .toggleStyle(AnyfmtSwitchStyle())
        .animation(animation, value: spotlight)
    }

    @ViewBuilder private func band(_ s: OnboardingSpotlight) -> some View {
        switch s {
        case .none: Color.clear
        case .heat: BandGradient(bands: DesignTokens.Band.heat, flat: DesignTokens.Band.heatFlat).id(s)
                .transition(.opacity)
        case .cobalt: BandGradient(bands: T.cobaltBands, flat: DesignTokens.Band.heatFlat).id(s)
                .transition(.opacity)
        }
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

    private var animation: Animation { OnboardingMotion.page(reduceMotion: reduceMotion) }

    /// Skip (quiet, bottom left), progress, then Back and the one blue pill.
    private var footer: some View {
        HStack(spacing: DesignTokens.Space.l) {
            Button(String(localized: "Skip")) { model.finish() }
                .buttonStyle(.anyfmtQuiet)
                .opacity(model.page.isLast ? 0 : 1)
                .disabled(model.page.isLast)
                .accessibilityIdentifier("onboarding.skip")
                .padding(.leading, -DesignTokens.Space.s) // align the text, not the hit area, with the page edge

            Spacer(minLength: DesignTokens.Space.s)
            ProgressDots(count: OnboardingPage.visible.count, current: model.page.rawValue, reduceMotion: reduceMotion) { i in
                if let p = OnboardingPage(rawValue: i) { withAnimation(animation) { model.go(to: p) } }
            }
            Spacer(minLength: DesignTokens.Space.s)

            HStack(spacing: DesignTokens.Space.xs) {
                if model.page.previous != nil {
                    Button(String(localized: "Back")) { withAnimation(animation) { model.goBack() } }
                        .buttonStyle(AnyfmtPillButtonStyle(kind: .quiet, large: true))
                        .accessibilityIdentifier("onboarding.back")
                }
                Button {
                    withAnimation(animation) { model.goNext() }
                } label: {
                    Text(model.page.isLast ? "Start Using \(Brand.name)" : "Continue")
                }
                .buttonStyle(AnyfmtPillButtonStyle(kind: .primary, large: true))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(model.page.isLast ? "onboarding.finish" : "onboarding.continue")
            }
        }
        .padding(.horizontal, T.margin)
        .padding(.top, DesignTokens.Space.m)
        .padding(.bottom, DesignTokens.Space.xl + DesignTokens.Space.xs)
    }
}

/// Step dots: the current one is cobalt and wider (shape carries the state too).
private struct ProgressDots: View {
    let count: Int
    let current: Int
    let reduceMotion: Bool
    let go: (Int) -> Void

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        HStack(spacing: T.dotSpacing) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.iris : Color.token(T.dotRest))
                    .frame(width: i == current ? T.dotCurrentWidth : T.dotSize, height: T.dotSize)
                    .contentShape(Rectangle().inset(by: -DesignTokens.Space.xs))
                    .onTapGesture { go(i) }
                    .animation(OnboardingMotion.page(reduceMotion: reduceMotion), value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(current + 1) of \(count)"))
        .accessibilityIdentifier("onboarding.progress")
    }
}
