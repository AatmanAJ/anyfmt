import AppKit
import HaloCore
import RadialMenu
import SwiftUI

/// Debug gallery of every wheel: each file kind × wheel, every appearance mode,
/// every segment count 1–24 and the special states (drop ring, pages, Pro,
/// multi-file). `renderAll` writes PNGs offscreen (`--render-gallery <dir>`,
/// `make gallery`); `showWindow` opens an interactive window (hidden menu item,
/// Option held).
@MainActor
public enum WheelGallery {
    /// Appearance modes rendered, with their file-name tag.
    static let appearances: [(tag: String, appearance: RadialAppearance)] = [
        ("light", .light),
        ("dark", .dark),
        ("contrast", RadialAppearance(increaseContrast: true)),
        ("contrast-dark", RadialAppearance(isDark: true, increaseContrast: true)),
        ("opaque", RadialAppearance(reduceTransparency: true)),
        ("opaque-dark", RadialAppearance(isDark: true, reduceTransparency: true)),
        ("reduced-motion", RadialAppearance(reduceMotion: true)),
    ]

    struct Case {
        let name: String
        let items: [RadialItem]
        let appearance: RadialAppearance
        let hovered: Int?
        let hub: RadialHubContent
        var page = 0
        var dropZone: RadialDropZone?
    }

    /// Every gallery image, in a stable order.
    static func cases() -> [Case] {
        var out: [Case] = []
        let provider = WheelGalleryData.provider
        let cloud = CloudSegments() // signed out: Pro segments show their chip
        let prefs = WheelPreferences.standard
        let basic = appearances.prefix(2)

        // 1. Every file kind × convert/tools, light and dark, second segment hovered.
        for sample in WheelGalleryData.samples {
            let input = WheelGalleryData.input(for: sample)
            let hub = WheelGalleryData.hub(for: sample)
            for kind in [WheelKind.convert, .tools] {
                let resolved = provider.resolve(input, kind: kind, preferences: prefs)
                var hubContent = hub
                if let note = resolved.note { hubContent.idleText = note }
                let items = WheelContentProvider.items(for: resolved.entries, cloud: cloud)
                let tag = resolved.kind == kind ? (kind == .convert ? "" : "-\(kind.rawValue)") : "-\(kind.rawValue)-fallback"
                for (name, appearance) in basic {
                    out.append(Case(name: "wheel-\(sample.name)\(tag)-\(name)-\(items.count)", items: items,
                                    appearance: appearance, hovered: items.count > 1 ? 1 : 0, hub: hubContent))
                }
            }
        }
        // Actions are the same for every file.
        let image = WheelGalleryData.samples[0]
        let actions = WheelContentProvider.items(
            for: provider.entries(for: WheelGalleryData.input(for: image), kind: .actions, preferences: prefs), cloud: cloud)
        for (name, appearance) in basic {
            out.append(Case(name: "wheel-actions-\(name)-\(actions.count)", items: actions, appearance: appearance,
                            hovered: 2, hub: WheelGalleryData.hub(for: image)))
        }

        // 2. Every appearance mode on the image convert wheel.
        let imageItems = WheelContentProvider.items(
            for: provider.entries(for: WheelGalleryData.input(for: image), kind: .convert, preferences: prefs), cloud: cloud)
        for (name, appearance) in appearances {
            out.append(Case(name: "wheel-appearance-\(name)", items: imageItems, appearance: appearance, hovered: 2,
                            hub: WheelGalleryData.hub(for: image)))
        }

        // 3. Every segment count 1–24, hovered half-way round.
        for n in 1...24 {
            for (name, appearance) in basic {
                out.append(Case(name: String(format: "wheel-count-%@-%02d", name, n), items: WheelGalleryData.countItems(n),
                                appearance: appearance, hovered: n / 2, hub: WheelGalleryData.hub(for: image)))
            }
        }

        // 4. Special states.
        let zone = RadialDropZone(title: String(localized: "Drop files", comment: "Hub text of the empty drop ring"),
                                  image: RadialItem.symbol("arrow.down.to.line"))
        for (name, appearance) in basic {
            out.append(Case(name: "wheel-state-dropring-\(name)", items: [], appearance: appearance, hovered: nil,
                            hub: RadialHubContent(), dropZone: zone))
            out.append(Case(name: "wheel-state-page2-\(name)", items: WheelGalleryData.countItems(30), appearance: appearance,
                            hovered: 20, hub: WheelGalleryData.hub(for: image), page: 1))
            out.append(Case(name: "wheel-state-idle-\(name)", items: imageItems, appearance: appearance, hovered: nil,
                            hub: WheelGalleryData.hub(for: image)))
        }
        let tools = WheelContentProvider.items(
            for: provider.entries(for: WheelGalleryData.input(for: image), kind: .tools, preferences: prefs), cloud: cloud)
        if let pro = tools.firstIndex(where: { $0.badge != nil }) {
            out.append(Case(name: "wheel-state-pro-hover-light", items: tools, appearance: .light, hovered: pro,
                            hub: WheelGalleryData.hub(for: image)))
        }
        var disabled = imageItems
        if disabled.count > 3 { disabled[3].isEnabled = false }
        out.append(Case(name: "wheel-state-disabled-hover-light", items: disabled, appearance: .light, hovered: 3,
                        hub: WheelGalleryData.hub(for: image)))
        return out
    }

    static func image(for c: Case, scale: CGFloat = 2) -> NSImage {
        RadialMenuSnapshot.render(items: c.items, configuration: WheelTheme.configuration, style: WheelTheme.style,
                                  appearance: c.appearance, hoveredIndex: c.hovered, hub: c.hub, page: c.page,
                                  dropZone: c.dropZone, strings: WheelTheme.strings, backdrop: .wallpaper,
                                  cropToWheel: true, scale: scale)
    }

    /// Writes every gallery PNG into `directory` (created if needed). Returns the files written.
    @discardableResult
    public static func renderAll(to directory: URL, scale: CGFloat = 2) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written: [URL] = []
        for c in cases() {
            guard let data = RadialMenuSnapshot.pngData(image(for: c, scale: scale)) else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: c.name])
            }
            let url = directory.appendingPathComponent(c.name).appendingPathExtension("png")
            try data.write(to: url, options: .atomic)
            written.append(url)
        }
        Log.wheel.info("gallery: wrote \(written.count) images to \(directory.path, privacy: .public)")
        return written
    }

    // MARK: Window

    private static var window: NSWindow?

    /// Opens (or brings forward) the interactive gallery window.
    public static func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = String(localized: "Wheel Gallery", comment: "Debug window title")
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: WheelGalleryView())
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Interactive view

private struct WheelGalleryView: View {
    @State private var sampleIndex = 0
    @State private var kind = WheelKind.convert
    @State private var appearanceIndex = 0
    @State private var useCount = false
    @State private var count = 8.0
    @State private var hovered = 1
    @State private var material = RadialMenuStyle.Material.popover

    private var sample: WheelGalleryData.Sample { WheelGalleryData.samples[sampleIndex] }

    private var items: [RadialItem] {
        if useCount { return WheelGalleryData.countItems(Int(count)) }
        let resolved = WheelGalleryData.provider.resolve(WheelGalleryData.input(for: sample), kind: kind, preferences: .standard)
        return WheelContentProvider.items(for: resolved.entries, cloud: CloudSegments())
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(DesignTokens.Space.m)
            Divider()
            HStack(alignment: .top, spacing: DesignTokens.Space.l) {
                VStack(spacing: DesignTokens.Space.s) {
                    Text("Live (real vibrancy, hover and keys work)", comment: "Gallery caption")
                        .font(.caption).foregroundStyle(.secondary)
                    LiveWheel(items: items, hub: WheelGalleryData.hub(for: sample), material: material,
                              appearance: WheelGallery.appearances[appearanceIndex].appearance)
                        .frame(width: 446, height: 446)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DesignTokens.Space.m)],
                              spacing: DesignTokens.Space.m) {
                        ForEach(WheelGallery.appearances.indices, id: \.self) { i in
                            let a = WheelGallery.appearances[i]
                            VStack(spacing: DesignTokens.Space.xs) {
                                Image(nsImage: snapshot(a.appearance))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                Text(verbatim: a.tag).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(DesignTokens.Space.m)
                }
            }
            .padding(DesignTokens.Space.m)
        }
    }

    private var controls: some View {
        HStack(spacing: DesignTokens.Space.l) {
            Picker(String(localized: "File", comment: "Gallery control"), selection: $sampleIndex) {
                ForEach(WheelGalleryData.samples.indices, id: \.self) { Text(verbatim: WheelGalleryData.samples[$0].name).tag($0) }
            }
            .frame(width: 180)
            Picker(String(localized: "Wheel", comment: "Gallery control"), selection: $kind) {
                ForEach(WheelKind.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            Picker(String(localized: "Appearance", comment: "Gallery control"), selection: $appearanceIndex) {
                ForEach(WheelGallery.appearances.indices, id: \.self) { Text(verbatim: WheelGallery.appearances[$0].tag).tag($0) }
            }
            .frame(width: 220)
            Picker(String(localized: "Material", comment: "Gallery control"), selection: $material) {
                ForEach(RadialMenuStyle.Material.allCases, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
            }
            .frame(width: 170)
            Toggle(String(localized: "Count", comment: "Gallery control"), isOn: $useCount)
            Slider(value: $count, in: 1...24, step: 1)
                .frame(width: 120)
                .disabled(!useCount)
            Text(verbatim: "\(Int(count))").monospacedDigit()
            Stepper(String(localized: "Hover \(hovered)", comment: "Gallery control"), value: $hovered, in: -1...23)
        }
    }

    private func snapshot(_ appearance: RadialAppearance) -> NSImage {
        RadialMenuSnapshot.render(items: items, configuration: WheelTheme.configuration, style: WheelTheme.style,
                                  appearance: appearance, hoveredIndex: hovered >= 0 ? hovered : nil,
                                  hub: WheelGalleryData.hub(for: sample), strings: WheelTheme.strings,
                                  cropToWheel: true, scale: 1)
    }
}

/// A real `RadialMenuView` (live material) inside the gallery window.
private struct LiveWheel: NSViewRepresentable {
    let items: [RadialItem]
    let hub: RadialHubContent
    let material: RadialMenuStyle.Material
    let appearance: RadialAppearance

    func makeNSView(context: Context) -> RadialMenuView {
        var style = WheelTheme.style
        style.material = material
        style.appearanceOverride = appearance
        let view = RadialMenuView(configuration: WheelTheme.configuration, style: style, materialMode: .live)
        view.strings = WheelTheme.strings
        view.keyboardEnabled = true
        view.hub = hub
        view.setItems(items, animated: false)
        return view
    }

    func updateNSView(_ view: RadialMenuView, context: Context) {
        var style = view.style
        if style.material != material || style.appearanceOverride != appearance {
            style.material = material
            style.appearanceOverride = appearance
            view.style = style
        }
        if view.hub != hub { view.hub = hub }
        if view.items.map(\.id) != items.map(\.id) { view.setItems(items, animated: true) }
    }
}
