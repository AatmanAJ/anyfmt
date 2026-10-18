import AppKit

/// Offscreen rendering of a wheel, for galleries, docs and regression screenshots
/// (UI automation isn't available unattended). Vibrancy can't render offscreen,
/// so the material is painted with an equivalent frosted fill.
@MainActor
public enum RadialMenuSnapshot {
    public enum Backdrop {
        /// Transparent background.
        case none
        /// A soft gradient wallpaper (light or dark to match the appearance),
        /// so translucency reads the way it does on a desktop.
        case wallpaper
        case color(NSColor)
    }

    /// Renders the wheel exactly as `RadialMenuView` lays it out, at rest (after
    /// the open animation), optionally with `hoveredIndex` highlighted.
    /// `size` defaults to the configuration's canvas; other sizes scale to fit.
    public static func render(items: [RadialItem],
                              configuration: RadialMenuConfiguration = RadialMenuConfiguration(),
                              style: RadialMenuStyle = RadialMenuStyle(),
                              appearance: RadialAppearance = .light,
                              hoveredIndex: Int? = nil,
                              size: CGSize? = nil,
                              hub: RadialHubContent = RadialHubContent(),
                              page: Int = 0,
                              dropZone: RadialDropZone? = nil,
                              strings: RadialMenuStrings = RadialMenuStrings(),
                              backdrop: Backdrop = .wallpaper,
                              cropToWheel: Bool = false,
                              scale: CGFloat = 2) -> NSImage {
        let view = makeView(items: items, configuration: configuration, style: style, appearance: appearance,
                            hoveredIndex: hoveredIndex, hub: hub, page: page, dropZone: dropZone,
                            strings: strings, scale: scale)
        return render(view: view, size: size, backdrop: backdrop, cropToWheel: cropToWheel, scale: scale)
    }

    /// Builds a painted-material view in its final state (exposed for tests and hosts
    /// that want to tweak the view before rendering it with `render(view:)`).
    public static func makeView(items: [RadialItem], configuration: RadialMenuConfiguration, style: RadialMenuStyle,
                                appearance: RadialAppearance, hoveredIndex: Int?, hub: RadialHubContent,
                                page: Int, dropZone: RadialDropZone?, strings: RadialMenuStrings,
                                scale: CGFloat) -> RadialMenuView {
        var style = style
        style.appearanceOverride = appearance
        let view = RadialMenuView(configuration: configuration, style: style, materialMode: .painted)
        view.setRenderScale(scale)
        view.strings = strings
        view.dropZone = dropZone
        view.hub = hub
        view.setItems(items, animated: false)
        if page != 0 { view.showPage(page, animated: false) }
        view.highlightItem(at: hoveredIndex, animated: false)
        return view
    }

    /// `cropToWheel` trims the canvas to what's drawn (plus room for shadows) at 1:1
    /// instead of scaling the whole canvas into `size`.
    public static func render(view: RadialMenuView, size: CGSize? = nil, backdrop: Backdrop = .wallpaper,
                              cropToWheel: Bool = false, scale: CGFloat = 2) -> NSImage {
        let canvas = view.bounds.size
        let cropSide = ceil(2 * (view.wheelRadius + 22))
        let out = cropToWheel ? CGSize(width: cropSide, height: cropSide) : (size ?? canvas)
        let w = max(1, Int((out.width * scale).rounded())), h = max(1, Int((out.height * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return NSImage(size: out) }
        ctx.scaleBy(x: scale, y: scale)
        drawBackdrop(backdrop, in: CGRect(origin: .zero, size: out), dark: view.resolvedAppearance.isDark, ctx: ctx)
        let fit = cropToWheel ? 1 : min(out.width / canvas.width, out.height / canvas.height)
        ctx.translateBy(x: (out.width - canvas.width * fit) / 2, y: (out.height - canvas.height * fit) / 2)
        ctx.scaleBy(x: fit, y: fit)
        for layer in view.snapshotLayers {
            layer.render(in: ctx)
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: out) }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = out
        let image = NSImage(size: out)
        image.addRepresentation(rep)
        return image
    }

    /// PNG data for an image produced by `render`.
    public static func pngData(_ image: NSImage) -> Data? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first
                ?? image.cgImage(forProposedRect: nil, context: nil, hints: nil).map(NSBitmapImageRep.init(cgImage:))
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func drawBackdrop(_ backdrop: Backdrop, in rect: CGRect, dark: Bool, ctx: CGContext) {
        switch backdrop {
        case .none:
            return
        case .color(let color):
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
        case .wallpaper:
            let colors: [CGColor] = dark
                ? [NSColor(srgbHex: 0x26282B).cgColor, NSColor(srgbHex: 0x1B1C1E).cgColor, NSColor(srgbHex: 0x2C2A28).cgColor]
                : [NSColor(srgbHex: 0xE9EAEC).cgColor, NSColor(srgbHex: 0xDCDFE3).cgColor, NSColor(srgbHex: 0xEDEAE6).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
                                            locations: [0, 0.55, 1]) else { return }
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY),
                                   end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
            // A neutral stand-in for a desktop (no hue), with a soft highlight so
            // translucent fills have something to show through.
            let glow = dark ? NSColor(white: 1, alpha: 0.06) : NSColor(white: 1, alpha: 0.65)
            if let radial = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                       colors: [glow.cgColor, glow.withAlphaComponent(0).cgColor] as CFArray,
                                       locations: [0, 1]) {
                let c = CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.72)
                ctx.drawRadialGradient(radial, startCenter: c, startRadius: 0, endCenter: c,
                                       endRadius: max(rect.width, rect.height) * 0.55, options: [])
            }
        }
    }
}
