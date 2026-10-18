import AppKit
import SwiftUI
import HaloCore

/// Which part of the crop frame a drag grabbed.
enum ImageCropHandle: CaseIterable, Hashable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move

    var isCorner: Bool { [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(self) }

    /// Handle position on a unit rect (normalised, y down).
    func anchor(in r: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: r.minX, y: r.minY)
        case .top: CGPoint(x: r.midX, y: r.minY)
        case .topRight: CGPoint(x: r.maxX, y: r.minY)
        case .right: CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: CGPoint(x: r.maxX, y: r.maxY)
        case .bottom: CGPoint(x: r.midX, y: r.maxY)
        case .bottomLeft: CGPoint(x: r.minX, y: r.maxY)
        case .left: CGPoint(x: r.minX, y: r.midY)
        case .move: CGPoint(x: r.midX, y: r.midY)
        }
    }

    var cursor: NSCursor {
        switch self {
        case .left, .right: .resizeLeftRight
        case .top, .bottom: .resizeUpDown
        case .move: .openHand
        default: .crosshair
        }
    }
}

@MainActor
final class ImageCropModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let preview: CGImage?
    /// Upright full-resolution size.
    let pixelSize: CGSize

    @Published var rect: CGRect
    @Published var aspect: String {
        didSet { if aspect != oldValue { rect = fitted(rect, toAspect: aspect) } }
    }

    static let minimumPixels: CGFloat = 16

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        let url = inputs.first
        preview = url.flatMap { ImageEditorKit.preview($0) }
        pixelSize = url.flatMap(ToolImageSupport.pixelSize(of:)) ?? preview.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 1, height: 1)
        let defaults = tool.defaultOptions
        aspect = defaults.string("aspect", default: "free")
        rect = CropGeometry.parseRect(defaults.string("rect", default: "0,0,1,1")) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    var options: OptionValues {
        OptionValues(["rect": .string(CropGeometry.format(rect)), "aspect": .string(aspect)])
    }

    var cropPixels: CGSize { CropGeometry.pixelRect(rect, aspect: "free", imageSize: pixelSize).size }

    var statusLine: String? {
        guard preview != nil else { return nil }
        return "\(ImageEditorKit.pixelText(pixelSize)) → \(ImageEditorKit.pixelText(cropPixels))"
    }

    var canSave: Bool { preview != nil }

    var isFullFrame: Bool { abs(rect.width - 1) < 0.0005 && abs(rect.height - 1) < 0.0005 }

    func reset() {
        rect = CropGeometry.defaultRect(aspect: aspect, imageSize: pixelSize)
    }

    /// Width / height in normalised units for the aspect (nil = free).
    private func normalizedRatio(_ aspect: String) -> CGFloat? {
        guard let r = CropGeometry.ratio(aspect), pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        return r / (pixelSize.width / pixelSize.height)
    }

    private var minSize: CGSize {
        CGSize(width: min(1, Self.minimumPixels / max(1, pixelSize.width)), height: min(1, Self.minimumPixels / max(1, pixelSize.height)))
    }

    /// The largest rect of `aspect` centred on `r`'s centre that fits the image.
    func fitted(_ r: CGRect, toAspect aspect: String) -> CGRect {
        guard let k = normalizedRatio(aspect) else { return r }
        var w = r.width, h = r.width / k
        if h > r.height { h = r.height; w = h * k }
        // Grow toward the full image when switching from a small free rect isn't wanted; keep the user's scale.
        let cx = min(max(r.midX, w / 2), 1 - w / 2), cy = min(max(r.midY, h / 2), 1 - h / 2)
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// New rect for dragging `handle` of `start` to normalised point `p`
    /// (`translation` is used for moves).
    func dragged(_ handle: ImageCropHandle, start: CGRect, to p: CGPoint, translation: CGSize) -> CGRect {
        let k = normalizedRatio(aspect)
        let m = minSize
        switch handle {
        case .move:
            var r = start.offsetBy(dx: translation.width, dy: translation.height)
            r.origin.x = min(max(0, r.minX), 1 - r.width)
            r.origin.y = min(max(0, r.minY), 1 - r.height)
            return r
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            let opposite: ImageCropHandle = [.topLeft: .bottomRight, .topRight: .bottomLeft, .bottomRight: .topLeft, .bottomLeft: .topRight][handle] ?? .bottomRight
            return cornerRect(anchor: opposite.anchor(in: start), to: p, ratio: k, min: m)
        case .left, .right:
            let fixedX = handle == .left ? start.maxX : start.minX
            let x = min(1, max(0, p.x))
            var w = max(m.width, abs(x - fixedX))
            w = handle == .left ? min(w, fixedX) : min(w, 1 - fixedX)
            let minX = handle == .left ? fixedX - w : fixedX
            guard let k else { return CGRect(x: minX, y: start.minY, width: w, height: start.height) }
            var h = w / k
            if h > 1 { h = 1; w = h * k }
            let cy = min(max(start.midY, h / 2), 1 - h / 2)
            return CGRect(x: handle == .left ? fixedX - w : fixedX, y: cy - h / 2, width: w, height: h)
        case .top, .bottom:
            let fixedY = handle == .top ? start.maxY : start.minY
            let y = min(1, max(0, p.y))
            var h = max(m.height, abs(y - fixedY))
            h = handle == .top ? min(h, fixedY) : min(h, 1 - fixedY)
            let minY = handle == .top ? fixedY - h : fixedY
            guard let k else { return CGRect(x: start.minX, y: minY, width: start.width, height: h) }
            var w = h * k
            if w > 1 { w = 1; h = w / k }
            let cx = min(max(start.midX, w / 2), 1 - w / 2)
            return CGRect(x: cx - w / 2, y: handle == .top ? fixedY - h : fixedY, width: w, height: h)
        }
    }

    /// Rect spanned from a fixed corner to the pointer, aspect-locked when `ratio` is set.
    func cornerRect(anchor a: CGPoint, to raw: CGPoint, ratio k: CGFloat?, min m: CGSize) -> CGRect {
        let p = ImageEditorKit.clamp01(raw)
        let sx: CGFloat = p.x >= a.x ? 1 : -1, sy: CGFloat = p.y >= a.y ? 1 : -1
        // Room available in the drag direction.
        let roomX = sx > 0 ? 1 - a.x : a.x, roomY = sy > 0 ? 1 - a.y : a.y
        var w = max(m.width, abs(p.x - a.x)), h = max(m.height, abs(p.y - a.y))
        if let k {
            if w / h > k { h = w / k } else { w = h * k }
            let s = min(1, roomX / w, roomY / h)
            w *= s; h *= s
        } else {
            w = min(w, roomX); h = min(h, roomY)
        }
        return CGRect(x: sx > 0 ? a.x : a.x - w, y: sy > 0 ? a.y : a.y - h, width: w, height: h)
    }

    /// Moves by whole source pixels.
    func nudge(dx: CGFloat, dy: CGFloat) {
        let t = CGSize(width: dx / max(1, pixelSize.width), height: dy / max(1, pixelSize.height))
        rect = dragged(.move, start: rect, to: .zero, translation: t)
    }
}

struct ImageCropEditor: View {
    @ObservedObject var model: ImageCropModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImageCropCanvas(model: model, showOriginal: original)
        }, sidebar: {
            ImageCropSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageCropCanvas: View {
    @ObservedObject var model: ImageCropModel
    let showOriginal: Bool

    @State private var active: ImageCropHandle?
    @State private var startRect: CGRect = .zero
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var keys = ImageEditorKeyCatcher.Handle()

    var body: some View {
        ImageEditorKit.FittedImage(image: model.preview, size: model.pixelSize, source: model.inputs.first) { imageRect in
            if !showOriginal {
                overlay(imageRect)
            }
        }
        .background(ImageEditorKeyCatcher(handle: keys) { event in
            guard let d = ImageEditorKeyCatcher.arrowDelta(event) else { return false }
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            model.nudge(dx: d.x * step, dy: d.y * step)
            return true
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Crop area"))
    }

    @ViewBuilder
    private func overlay(_ imageRect: CGRect) -> some View {
        let crop = ImageEditorKit.denormalized(model.rect, in: imageRect)
        let o = EditorTokens.Overlay.self
        ZStack(alignment: .topLeading) {
            Path { p in
                p.addRect(imageRect)
                p.addRect(crop)
            }
            .fill(EditorPalette.overlayHalo.opacity(contrast == .increased ? o.dimIncreased : o.dim), style: FillStyle(eoFill: true))

            // Rule of thirds: quiet white lines with a dark halo.
            OverlayStroke(path: Path { p in
                for i in 1...2 {
                    let x = crop.minX + crop.width * CGFloat(i) / 3, y = crop.minY + crop.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: crop.minY)); p.addLine(to: CGPoint(x: x, y: crop.maxY))
                    p.move(to: CGPoint(x: crop.minX, y: y)); p.addLine(to: CGPoint(x: crop.maxX, y: y))
                }
            }, width: DesignTokens.Shape.hairline, quiet: true)
            .opacity(active == nil ? o.thirds : o.thirdsActive)

            OverlayStroke(path: Rectangle().path(in: crop))
            handles(crop)
            OverlayBadge(text: "\(Int(model.cropPixels.width.rounded())) × \(Int(model.cropPixels.height.rounded()))")
                .offset(x: crop.minX + DesignTokens.Space.s, y: max(imageRect.minY + DesignTokens.Space.xs, crop.minY + DesignTokens.Space.s))
                .opacity(crop.width > 110 && crop.height > 40 ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Rectangle().fill(Color.white.opacity(0.001))
                .contentShape(Rectangle())
                .gesture(drag(imageRect))
                .onContinuousHover { phase in
                    if case .active(let p) = phase { hit(p, crop: crop).cursor.set() } else { NSCursor.arrow.set() }
                }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Crop frame"))
        .accessibilityValue(ImageEditorKit.pixelText(model.cropPixels))
        .accessibilityHint(String(localized: "Drag to move or resize. Arrow keys nudge by one pixel, with Shift by ten."))
    }

    /// Cobalt corner brackets (dark halo, white rim) plus square handles on the edges.
    private func handles(_ r: CGRect) -> some View {
        let o = EditorTokens.Overlay.self
        let len = min(o.cornerLength, min(r.width, r.height) / 3)
        return ZStack(alignment: .topLeading) {
            OverlayStroke(path: Path { p in
                for (c, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                                    (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0), (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0)] {
                    p.move(to: CGPoint(x: c.x, y: c.y + dy * len)); p.addLine(to: c); p.addLine(to: CGPoint(x: c.x + dx * len, y: c.y))
                }
            }, width: o.cornerWidth)
            ForEach([ImageCropHandle.top, .bottom, .left, .right], id: \.self) { h in
                let a = h.anchor(in: r)
                OverlayHandle().position(a)
            }
        }
        .allowsHitTesting(false)
    }

    private func hit(_ p: CGPoint, crop: CGRect) -> ImageCropHandle {
        let tolerance: CGFloat = 12
        for h in ImageCropHandle.allCases where h != .move {
            let a = h.anchor(in: crop)
            if abs(a.x - p.x) <= tolerance && abs(a.y - p.y) <= tolerance { return h }
        }
        if abs(p.x - crop.minX) <= 6 && p.y > crop.minY && p.y < crop.maxY { return .left }
        if abs(p.x - crop.maxX) <= 6 && p.y > crop.minY && p.y < crop.maxY { return .right }
        if abs(p.y - crop.minY) <= 6 && p.x > crop.minX && p.x < crop.maxX { return .top }
        if abs(p.y - crop.maxY) <= 6 && p.x > crop.minX && p.x < crop.maxX { return .bottom }
        return crop.contains(p) ? .move : .bottomRight
    }

    private func drag(_ imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                let crop = ImageEditorKit.denormalized(model.rect, in: imageRect)
                if active == nil {
                    keys.focus()
                    var handle = hit(g.startLocation, crop: crop)
                    startRect = model.rect
                    if handle == .bottomRight && !crop.insetBy(dx: -12, dy: -12).contains(g.startLocation) {
                        // Outside the frame: draw a new one from the press point.
                        let s = ImageEditorKit.clamp01(ImageEditorKit.normalized(g.startLocation, in: imageRect))
                        startRect = CGRect(origin: s, size: .zero)
                        handle = .bottomRight
                    }
                    active = handle
                }
                guard let handle = active else { return }
                let p = ImageEditorKit.normalized(g.location, in: imageRect)
                let t = CGSize(width: g.translation.width / max(1, imageRect.width), height: g.translation.height / max(1, imageRect.height))
                if startRect.width == 0 && startRect.height == 0 {
                    model.rect = model.cornerRect(anchor: startRect.origin, to: p,
                                                  ratio: CropGeometry.ratio(model.aspect).map { $0 / (model.pixelSize.width / model.pixelSize.height) },
                                                  min: CGSize(width: 0.01, height: 0.01))
                } else {
                    model.rect = model.dragged(handle, start: startRect, to: p, translation: t)
                }
            }
            .onEnded { _ in active = nil }
    }
}

/// A rectangle drawn at the aspect it stands for (free = crop symbol).
private struct AspectGlyph: View {
    let ratio: CGFloat?
    var body: some View {
        GeometryReader { geo in
            if let ratio {
                let box = geo.size
                let w = min(box.width, box.height * ratio), h = w / ratio
                Rectangle()
                    .strokeBorder(lineWidth: 1.5)
                    .frame(width: w, height: h)
                    .position(x: box.width / 2, y: box.height / 2)
            } else {
                Image(systemName: "crop").font(.system(size: EditorTokens.cellGlyphSize)).frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ImageCropSidebar: View {
    @ObservedObject var model: ImageCropModel

    private let aspects: [(id: String, label: String)] = [
        ("free", String(localized: "Free")), ("1:1", String(localized: "Square")), ("4:3", "4:3"),
        ("3:2", "3:2"), ("16:9", "16:9"), ("9:16", "9:16"),
    ]

    var body: some View {
        ImageEditorKit.Section(String(localized: "Aspect ratio")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Space.s), count: 3), spacing: DesignTokens.Space.s) {
                ForEach(aspects, id: \.id) { a in
                    let selected = model.aspect == a.id
                    Button { model.aspect = a.id } label: {
                        VStack(spacing: 3) {
                            AspectGlyph(ratio: CropGeometry.ratio(a.id)).frame(width: 22, height: 16)
                            Text(a.label)
                        }
                    }
                    .buttonStyle(EditorCellButtonStyle(selected: selected))
                    .accessibilityLabel(a.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        ImageEditorKit.Section(String(localized: "Size")) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(Int(model.cropPixels.width.rounded())) × \(Int(model.cropPixels.height.rounded()))")
                    .font(.haloDisplay(DesignTokens.Typeface.Size.displayM))
                    .displayTracking(DesignTokens.Typeface.Size.displayM)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityLabel(ImageEditorKit.pixelText(model.cropPixels))
                Text("px").font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold)).foregroundStyle(Color.haloSecondaryText)
                Spacer()
                Button(String(localized: "Reset")) { model.reset() }
                    .disabled(model.isFullFrame && model.aspect == "free")
            }
            ImageEditorKit.Hint(String(localized: "Drag the frame or its handles. Drag outside it to draw a new one. Arrow keys nudge by 1 px, Shift by 10 px."))
        }
    }
}
