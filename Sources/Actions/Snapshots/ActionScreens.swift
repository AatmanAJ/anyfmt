import AppKit
import HaloCore

/// Offscreen renders of the actions' UI for docs/screens (D-025: UI tests
/// can't run unattended, so screens are rendered from views directly).
///
///     try ActionScreens.render(into: docsScreensURL)
///
/// Writes float-stack-{light,dark}.png, float-grid-{light,dark}.png,
/// float-empty-{light,dark}.png, float-drop-{light,dark}.png (files dragged
/// over an empty shelf) and move-chooser{,-dark}.png. Cards are solid
/// charcoal tiles, so the renders match the screen.
@MainActor
public enum ActionScreens {
    @discardableResult
    public static func render(into directory: URL, scale: CGFloat = 2) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let samples = try SampleFiles()
        defer { samples.remove() }
        var written: [URL] = []
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            guard let look = NSAppearance(named: appearance) else { continue }
            written.append(try renderShelf(.collapsed, samples: samples, appearance: look, scale: scale,
                                           to: directory.appendingPathComponent("float-stack-\(name).png")))
            written.append(try renderShelf(.expanded, samples: samples, appearance: look, scale: scale,
                                           to: directory.appendingPathComponent("float-grid-\(name).png")))
            written.append(try renderShelf(.empty, samples: samples, appearance: look, scale: scale,
                                           to: directory.appendingPathComponent("float-empty-\(name).png")))
            written.append(try renderShelf(.empty, dropTarget: true, samples: samples, appearance: look, scale: scale,
                                           to: directory.appendingPathComponent("float-drop-\(name).png")))
            written.append(try renderMoveChooser(samples: samples, appearance: look, scale: scale,
                                                 to: directory.appendingPathComponent(name == "light" ? "move-chooser.png" : "move-chooser-dark.png")))
        }
        return written
    }

    // MARK: Shelf

    static func renderShelf(_ mode: ShelfCardView.Mode, dropTarget: Bool = false, samples: SampleFiles,
                            appearance: NSAppearance, scale: CGFloat, to url: URL) throws -> URL {
        let provider = SampleThumbnails(samples: samples)
        let card = ShelfCardView()
        card.forceSolid = true
        card.forceControlsVisible = mode != .collapsed
        card.stackView.thumbnails = provider
        card.stackView.renderScale = scale
        card.gridView.thumbnails = provider
        card.gridView.renderScale = scale
        let items = mode == .empty ? [] : samples.shelfItems
        card.apply(items: items, change: nil, animated: false)
        if mode == .expanded { card.setMode(.expanded, animated: false) }
        let size = ShelfCardView.size(mode: card.mode, count: items.count)
        if mode == .expanded, let first = items.first {
            card.gridView.cell(for: first.id)?.forceHover = true
        }
        if dropTarget { card.showDropTarget() }
        return try capture(card, cardSize: size, appearance: appearance, scale: scale, to: url)
    }

    // MARK: Move chooser

    static func renderMoveChooser(samples: SampleFiles, appearance: NSAppearance, scale: CGFloat, to url: URL) throws -> URL {
        let view = MoveChooserView(items: Array(samples.files.suffix(3)), destinations: samples.recentDestinations)
        view.forceSolid = true
        return try capture(view, cardSize: view.preferredSize, appearance: appearance, scale: scale, to: url)
    }

    // MARK: Capture

    /// Puts `card` on a backdrop in a window parked far off screen (nothing
    /// appears on the display), lets AppKit draw it, and renders the layer tree.
    static func capture(_ card: ActionCardView, cardSize: NSSize, appearance: NSAppearance,
                        scale: CGFloat, to url: URL) throws -> URL {
        let margin = DesignTokens.Space.xxl
        let size = NSSize(width: cardSize.width + 2 * margin, height: cardSize.height + 2 * margin)
        let window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.isOpaque = true
        let backdrop = BackdropView(frame: NSRect(origin: .zero, size: size))
        backdrop.appearance = appearance
        window.contentView = backdrop
        card.frame = NSRect(x: margin, y: margin, width: cardSize.width, height: cardSize.height)
        backdrop.addSubview(card)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.layoutSubtreeIfNeeded()
        card.refreshAppearance()
        backdrop.displayIfNeeded()
        CATransaction.commit()
        CATransaction.flush()
        // A run-loop turn lets text and image layers commit their contents.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        backdrop.layoutSubtreeIfNeeded()
        backdrop.displayIfNeeded()
        CATransaction.flush()

        guard let layer = backdrop.layer,
              let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.fileWriteUnknown)
        }
        ctx.scaleBy(x: scale, y: scale)
        appearance.performAsCurrentDrawingAppearance {
            layer.render(in: ctx)
        }
        guard let image = ctx.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url, options: .atomic)
        return url
    }
}

/// A plain desktop stand-in: page black in dark (the approved board), a light
/// grey in light so the #F2F2F2 tile and its hairline read.
@MainActor
private final class BackdropView: NSView {
    private let fill = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(fill)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = bounds
        fill.zPosition = -1
        fill.backgroundColor = ActionStyle.cg(
            ActionStyle.color((light: DesignTokens.Primitive.paper100, dark: DesignTokens.Primitive.ink1000)),
            in: effectiveAppearance)
        CATransaction.commit()
    }
}

/// Sample files on disk (names, kinds and icons are real) with drawn
/// thumbnails standing in for QuickLook.
@MainActor
final class SampleFiles {
    let root: URL
    private(set) var files: [URL] = []
    private(set) var art: [String: NSImage] = [:]
    let recentDestinations: [MoveDestination]

    init() throws {
        let fm = FileManager.default
        root = fm.temporaryDirectory.appendingPathComponent("\(Brand.slug)-screens-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        // Oldest first: the last one ends up on top of the pile.
        let specs: [(String, NSImage?)] = [
            ("Brand Assets", nil),
            ("Q3 Roadmap.pdf", SampleArt.document()),
            ("Interview.mov", SampleArt.dusk()),
            ("Lagoon.heic", SampleArt.lagoon()),
            ("Golden Hour.jpg", SampleArt.sunset()),
        ]
        for (name, image) in specs {
            let url = root.appendingPathComponent(name)
            if url.pathExtension.isEmpty {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try Data(count: 1_200_000).write(to: url)
            }
            files.append(url)
            if let image { art[name] = image }
        }
        // Recent Move destinations as a typical user would have them. Display
        // only (nothing is created): standard folders keep their real icons.
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let folderIcon = NSWorkspace.shared.icon(for: .folder)
        func dest(_ path: String, detail: String) -> MoveDestination {
            let url = home.appendingPathComponent(path, isDirectory: true)
            let icon = ActionPreferences.directoryExists(url) ? NSWorkspace.shared.icon(forFile: url.path) : folderIcon
            return MoveDestination(url: url, name: url.lastPathComponent, detail: detail, icon: icon)
        }
        recentDestinations = [
            dest("Documents/Client Work", detail: "~/Documents"),
            dest("Desktop", detail: String(localized: "Home")),
            dest("Pictures/Screenshots", detail: "~/Pictures"),
            dest("Downloads", detail: String(localized: "Home")),
        ]
    }

    var shelfItems: [ShelfItem] {
        files.enumerated().map { i, url in
            // Fixed ids so the pile looks the same in every render.
            let id = UUID(uuidString: String(format: "%08X-1A2B-4C3D-8E4F-%012X", 0x5EED0000 + i * 0x3B7, 0xA5A5 + i * 0x1F3)) ?? UUID()
            return ShelfItem(id: id, url: url)
        }
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

@MainActor
private final class SampleThumbnails: ShelfThumbnailProviding {
    let samples: SampleFiles
    init(samples: SampleFiles) { self.samples = samples }

    func thumbnail(for url: URL, side: CGFloat, scale: CGFloat, update: @escaping @MainActor (ShelfThumbnail) -> Void) -> ShelfThumbnail {
        if let art = samples.art[url.lastPathComponent] {
            return ShelfThumbnail(image: art, isIcon: false)
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: side, height: side)
        return ShelfThumbnail(image: icon, isIcon: true)
    }
}

/// Procedural stand-ins for photo thumbnails (our own art, no assets), drawn
/// from the palette so the renders sit inside the direction: a heat-band
/// sunset, a cobalt lagoon, a night skyline and a document.
/// NSImage draws them lazily, possibly off the main actor.
enum SampleArt {
    private typealias P = DesignTokens.Primitive

    static func image(width: CGFloat, height: CGFloat, draw: @escaping @Sendable (CGContext, CGSize) -> Void) -> NSImage {
        NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(ctx, rect.size)
            return true
        }
    }

    static func cg(_ hex: Int, alpha: CGFloat = 1) -> CGColor { NSColor.halo((light: hex, dark: hex)).withAlphaComponent(alpha).cgColor }

    static func linear(_ ctx: CGContext, _ colors: [Int], from: CGPoint, to: CGPoint) {
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colours = colors.map { cg($0) } as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: colours, locations: nil) {
            ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    static func sunset() -> NSImage {
        image(width: 480, height: 360) { ctx, s in
            linear(ctx, [P.cream100, P.orange500, P.flame600], from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: s.height * 0.3))
            ctx.setFillColor(cg(P.paper0))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.56, y: s.height * 0.34, width: s.width * 0.2, height: s.width * 0.2))
            ctx.setFillColor(cg(P.ember700))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: s.height * 0.38))
            ctx.addLine(to: CGPoint(x: s.width * 0.22, y: s.height * 0.58))
            ctx.addLine(to: CGPoint(x: s.width * 0.4, y: s.height * 0.42))
            ctx.addLine(to: CGPoint(x: s.width * 0.62, y: s.height * 0.62))
            ctx.addLine(to: CGPoint(x: s.width, y: s.height * 0.36))
            ctx.addLine(to: CGPoint(x: s.width, y: 0))
            ctx.addLine(to: CGPoint(x: 0, y: 0))
            ctx.fillPath()
            ctx.setFillColor(cg(P.ink900))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: s.height * 0.22))
            ctx.addCurve(to: CGPoint(x: s.width, y: s.height * 0.26),
                         control1: CGPoint(x: s.width * 0.35, y: s.height * 0.34),
                         control2: CGPoint(x: s.width * 0.7, y: s.height * 0.14))
            ctx.addLine(to: CGPoint(x: s.width, y: 0))
            ctx.addLine(to: CGPoint(x: 0, y: 0))
            ctx.fillPath()
        }
    }

    static func lagoon() -> NSImage {
        image(width: 300, height: 400) { ctx, s in
            linear(ctx, [P.cobalt400, P.cobaltBright, P.cobalt700], from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            ctx.setFillColor(cg(P.cream100))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.18, y: s.height * 0.48, width: s.width * 0.64, height: s.height * 0.12))
            ctx.setFillColor(cg(P.ink800))
            ctx.fillEllipse(in: CGRect(x: s.width * 0.34, y: s.height * 0.53, width: s.width * 0.3, height: s.height * 0.1))
            ctx.setStrokeColor(cg(P.paper0, alpha: 0.5))
            ctx.setLineWidth(3)
            for i in 0..<5 {
                let y = s.height * (0.12 + CGFloat(i) * 0.07)
                ctx.move(to: CGPoint(x: s.width * 0.1, y: y))
                ctx.addCurve(to: CGPoint(x: s.width * 0.9, y: y),
                             control1: CGPoint(x: s.width * 0.35, y: y + 8), control2: CGPoint(x: s.width * 0.65, y: y - 8))
            }
            ctx.strokePath()
        }
    }

    static func dusk() -> NSImage {
        image(width: 480, height: 270) { ctx, s in
            linear(ctx, [P.ink1000, P.cobalt700, P.flame600], from: CGPoint(x: 0, y: s.height), to: CGPoint(x: 0, y: 0))
            let widths: [CGFloat] = [0.08, 0.06, 0.1, 0.07, 0.09, 0.05, 0.11, 0.08, 0.06, 0.1, 0.07, 0.13]
            let heights: [CGFloat] = [0.42, 0.6, 0.35, 0.72, 0.5, 0.4, 0.64, 0.3, 0.55, 0.45, 0.68, 0.38]
            var x: CGFloat = 0
            for (w, h) in zip(widths, heights) {
                ctx.setFillColor(cg(P.ink950))
                ctx.fill(CGRect(x: x * s.width, y: 0, width: w * s.width, height: h * s.height))
                ctx.setFillColor(cg(P.orange500, alpha: 0.85))
                var wy: CGFloat = 0.06
                while wy < h - 0.06 {
                    ctx.fill(CGRect(x: (x + w * 0.3) * s.width, y: wy * s.height, width: 3, height: 4))
                    wy += 0.09
                }
                x += w
            }
        }
    }

    static func document() -> NSImage {
        image(width: 300, height: 388) { ctx, s in
            ctx.setFillColor(cg(P.paper0))
            ctx.fill(CGRect(origin: .zero, size: s))
            ctx.setFillColor(cg(P.ink950))
            ctx.fill(CGRect(x: 26, y: s.height - 58, width: s.width * 0.55, height: 16))
            ctx.setFillColor(cg(P.paper100))
            var y = s.height - 92
            for i in 0..<9 {
                let w = (i % 3 == 2) ? s.width * 0.5 : s.width - 52
                ctx.fill(CGRect(x: 26, y: y, width: w, height: 7))
                y -= 17
            }
            let bars: [CGFloat] = [0.35, 0.55, 0.45, 0.8]
            for (i, h) in bars.enumerated() {
                ctx.setFillColor(cg(i == 3 ? P.orange500 : P.cobalt500))
                ctx.fill(CGRect(x: 30 + CGFloat(i) * 46, y: 34, width: 30, height: 90 * h))
            }
        }
    }
}
