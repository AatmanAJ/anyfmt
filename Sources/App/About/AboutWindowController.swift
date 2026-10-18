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

    static let contentSize = NSSize(width: DesignTokens.Component.Onboarding.aboutWidth,
                                    height: DesignTokens.Component.Onboarding.aboutHeight)

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

/// A record sleeve: a strip of the heat band across the top (the one
/// spotlight), then the name set big at the top left, the open-source line, and
/// the engine credits in a charcoal tile.
struct AboutView: View {
    let info: AppInfo
    let engines: [EngineInfo]

    private typealias T = DesignTokens.Component.Onboarding
    private var margin: CGFloat { DesignTokens.Space.xxl }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pale end on the left so the window buttons stay legible over it.
            BandGradient(bands: DesignTokens.Band.heat.reversed(), flat: DesignTokens.Band.heatFlat)
                .frame(height: T.aboutBand)
                .padding(.horizontal, -margin) // full bleed
                .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: DesignTokens.Space.l) {
                Text(verbatim: Brand.name.localizedUppercase)
                    .font(.haloDisplay(DesignTokens.Typeface.Size.displayXL))
                    .displayTracking(DesignTokens.Typeface.Size.displayXL)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: T.aboutIcon, height: T.aboutIcon)
                    .accessibilityHidden(true)
            }
            .padding(.top, DesignTokens.Space.xl)

            Text("Version \(info.version) (\(info.build))")
                .font(.system(size: DesignTokens.TypeRamp.body).monospacedDigit())
                .foregroundStyle(Color.haloSecondaryText)
                .textSelection(.enabled)
                .padding(.top, DesignTokens.Space.xxs)

            VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                Text("Free and open source (AGPL-3.0). You can read every line.")
                    .font(.system(size: DesignTokens.TypeRamp.title))
                    .fixedSize(horizontal: false, vertical: true)
                if let url = Brand.sourceURL {
                    Link(destination: url) {
                        Text(verbatim: url.host.map { $0 + url.path } ?? url.absoluteString)
                            .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentText)
                    .accessibilityIdentifier("about.source")
                }
            }
            .padding(.top, DesignTokens.Space.l)

            credits
                .padding(.top, DesignTokens.Space.l)

            HStack(alignment: .center) {
                Button("Licences…") { BundledEngines.revealLicences() }
                    .buttonStyle(.haloSecondary)
                    .accessibilityIdentifier("about.licences")
                Spacer(minLength: DesignTokens.Space.s)
                Text("Copyright © 2026 the \(Brand.name) contributors.")
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(Color.haloSecondaryText)
            }
            .padding(.vertical, DesignTokens.Space.l)
        }
        .padding(.horizontal, margin)
        .frame(width: AboutWindowController.contentSize.width, height: AboutWindowController.contentSize.height, alignment: .top)
        .foregroundStyle(Color.haloInk)
        .ignoresSafeArea()
        .haloWindowBackground()
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Built with")
                .font(.haloDisplay(DesignTokens.Component.Onboarding.tagSize))
                .displayTracking(DesignTokens.Component.Onboarding.tagSize)
                .textCase(.uppercase)
                .padding(.horizontal, DesignTokens.Space.l)
                .padding(.top, DesignTokens.Space.l)
                .padding(.bottom, DesignTokens.Space.s)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xs + 1) {
                    ForEach(engines) { e in
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: e.shortName)
                                .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
                                .lineLimit(1)
                            Text(verbatim: e.version)
                                .font(.system(size: DesignTokens.TypeRamp.label).monospacedDigit())
                                .foregroundStyle(Color.haloSecondaryText)
                            Spacer(minLength: DesignTokens.Space.s)
                            Text(verbatim: e.licence)
                                .font(.system(size: DesignTokens.TypeRamp.caption))
                                .foregroundStyle(Color.haloSecondaryText)
                                .lineLimit(1)
                                .help(Text(verbatim: e.licence))
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("And macOS’s \(BundledEngines.systemFrameworks.joined(separator: ", ")).")
                        .font(.system(size: DesignTokens.TypeRamp.caption))
                        .foregroundStyle(Color.haloSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DesignTokens.Space.xs)
                }
                .padding(.horizontal, DesignTokens.Space.l)
                .padding(.bottom, DesignTokens.Space.l)
            }
            // Fade the last rows so it reads as scrollable.
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.85),
                                         .init(color: .black.opacity(0), location: 1)],
                                 startPoint: .top, endPoint: .bottom))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.haloTile))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Credits"))
    }
}
