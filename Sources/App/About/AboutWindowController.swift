import AppKit
import SwiftUI
import HaloCore

/// About window: icon, version, the open-source promise, engine credits.
@MainActor
final class AboutWindowController: NSWindowController, NSWindowDelegate {
    private static var instance: AboutWindowController?

    static func show() {
        let controller = instance ?? AboutWindowController(info: .main, engines: SettingsWindowController.hooks.engineVersions())
        instance = controller
        controller.loadContent()
        if controller.window?.isVisible == false { controller.window?.center() }
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        controller.window?.makeKeyAndOrderFront(nil)
    }

    static let contentSize = NSSize(width: 420, height: 580)

    let info: AppInfo
    let engines: [EngineInfo]
    var isSnapshot = false
    private var contentLoaded = false

    init(info: AppInfo, engines: [EngineInfo]) {
        self.info = info
        self.engines = engines
        let window = HaloWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
                                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = String(localized: "About \(Brand.name)")
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.identifier = NSUserInterfaceItemIdentifier("about")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func loadContent() {
        guard let window, !contentLoaded else { return }
        contentLoaded = true
        let host = NSHostingView(rootView: AnyView(
            AboutView(info: info, engines: engines)
                .snapshotActiveAppearance()
                .environment(\.isSnapshot, isSnapshot)
        ))
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(Self.contentSize)
    }
}

struct AboutView: View {
    let info: AppInfo
    let engines: [EngineInfo]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DesignTokens.Space.m) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 112, height: 112)
                    .shadow(color: Color.iris.opacity(0.25), radius: 18, y: 8)
                    .accessibilityHidden(true)
                VStack(spacing: 3) {
                    Text(verbatim: Brand.name)
                        .font(.system(size: DesignTokens.TypeRamp.display, weight: .bold))
                    Text("Version \(info.version) (\(info.build))")
                        .font(.system(size: DesignTokens.TypeRamp.label))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                VStack(spacing: DesignTokens.Space.xs) {
                    Text("Free and open source (AGPL-3.0). You can read every line.")
                        .font(.system(size: DesignTokens.TypeRamp.body))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = Brand.sourceURL {
                        Link(destination: url) {
                            Text(verbatim: url.host.map { $0 + url.path } ?? url.absoluteString)
                                .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                        }
                        .foregroundStyle(Color.accentText)
                        .accessibilityIdentifier("about.source")
                    }
                }
                .padding(.horizontal, DesignTokens.Space.xl)
            }
            .padding(.top, 44)
            .padding(.bottom, DesignTokens.Space.l)

            credits

            VStack(spacing: DesignTokens.Space.s) {
                Button("Licences…") { BundledEngines.revealLicences() }
                    .controlSize(.regular)
                    .accessibilityIdentifier("about.licences")
                Text("Copyright © 2026 the \(Brand.name) contributors.")
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DesignTokens.Space.l)
        }
        .frame(width: AboutWindowController.contentSize.width, height: AboutWindowController.contentSize.height)
        .ignoresSafeArea()
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                RadialGradient(colors: [Color.iris.opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 0.05),
                               startRadius: 0, endRadius: 260)
            }
            .ignoresSafeArea()
        )
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Built with")
                .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, DesignTokens.Space.m)
                .padding(.top, DesignTokens.Space.m)
                .padding(.bottom, DesignTokens.Space.xs)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(engines) { e in
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: e.shortName)
                                .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                                .lineLimit(1)
                            Text(verbatim: e.version)
                                .font(.system(size: DesignTokens.TypeRamp.label).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer(minLength: DesignTokens.Space.s)
                            Text(verbatim: e.licence)
                                .font(.system(size: DesignTokens.TypeRamp.caption))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .help(Text(verbatim: e.licence))
                        }
                    }
                    Text("And macOS’s \(BundledEngines.systemFrameworks.joined(separator: ", ")).")
                        .font(.system(size: DesignTokens.TypeRamp.caption))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
                .padding(.horizontal, DesignTokens.Space.m)
                .padding(.bottom, DesignTokens.Space.m)
            }
            // Fade the last rows so it reads as scrollable.
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.85),
                                         .init(color: .black.opacity(0), location: 1)],
                                 startPoint: .top, endPoint: .bottom))
        }
        .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
        .padding(.horizontal, DesignTokens.Space.xl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Credits"))
    }
}
