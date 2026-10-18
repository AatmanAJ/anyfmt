import AppKit
import SwiftUI
import HaloCore

@MainActor
final class ImageCollageModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let items: [ImageEditorItem]

    @Published var order: [Int]
    @Published var layoutKind: CollageStyle.Layout
    @Published var gap: Double
    @Published var background: String
    @Published var width: Int

    static let widthPresets = [1080, 2048, 3000, 4096]

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        items = ImageEditorItem.load(inputs, edge: 512)
        order = Array(inputs.indices)
        let s = CollageStyle(options: tool.defaultOptions)
        layoutKind = s.layout
        gap = Double(s.gap)
        background = s.background
        width = s.width
    }

    var style: CollageStyle {
        CollageStyle(options: OptionValues(["layout": .string(layoutKind.rawValue), "gap": .int(Int(gap)), "color1": .string(background), "width": .int(width)]))
    }

    func layout(for order: [Int]) -> CollageLayout {
        CollageLayout.make(aspects: order.map { items[$0].aspect }, style: style)
    }

    var layout: CollageLayout { layout(for: order) }

    var options: OptionValues {
        OptionValues(["layout": .string(layoutKind.rawValue), "gap": .int(Int(gap)), "color1": .string(background),
                      "width": .int(width), "order": .string(OrderOption.format(order))])
    }

    var canSave: Bool { items.count >= 2 }

    var statusLine: String? { String(localized: "\(items.count) images · \(ImageEditorKit.pixelText(layout.canvas))") }

    /// Moves the item at `from` (position in `order`) to position `to`.
    func move(from: Int, to: Int) {
        guard order.indices.contains(from), order.indices.contains(to), from != to else { return }
        let id = order.remove(at: from)
        order.insert(id, at: to)
    }
}

struct ImageCollageEditor: View {
    @ObservedObject var model: ImageCollageModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImageCollageCanvas(model: model, showOriginal: original)
        }, sidebar: {
            ImageCollageSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageCollageCanvas: View {
    @ObservedObject var model: ImageCollageModel
    let showOriginal: Bool

    @State private var dragging: (position: Int, location: CGPoint)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if showOriginal {
                originals(geo.size)
            } else {
                arrangement(geo.size)
            }
        }
    }

    /// Before: the inputs side by side, unarranged.
    private func originals(_ size: CGSize) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: DesignTokens.Space.l)], spacing: DesignTokens.Space.l) {
                ForEach(model.items) { item in
                    if let t = item.thumbnail {
                        Image(decorative: t, scale: 1).resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }
                }
            }
            .padding(DesignTokens.Space.xl)
        }
    }

    private func arrangement(_ size: CGSize) -> some View {
        let committed = model.layout
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: DesignTokens.Space.xl, dy: DesignTokens.Space.xl)
        let canvas = ImageEditorKit.fit(committed.canvas, in: bounds)
        let scale = canvas.width / max(1, committed.canvas.width)
        // While dragging, show where the tile would land.
        let target = dragging.flatMap { d in hoveredPosition(d.location, layout: committed, canvas: canvas, scale: scale) }
        var shownOrder = model.order
        if let d = dragging, let t = target, t != d.position {
            let id = shownOrder.remove(at: d.position)
            shownOrder.insert(id, at: t)
        }
        let shown = model.layout(for: shownOrder)
        let shownScale = canvas.width / max(1, shown.canvas.width)
        let shownCanvas = CGRect(x: canvas.minX, y: canvas.minY, width: canvas.width, height: shown.canvas.height * shownScale)
        let draggedID = dragging.map { model.order[$0.position] }

        return ZStack(alignment: .topLeading) {
            Rectangle().fill(ImageEditorKit.color(hex: model.background))
                .frame(width: shownCanvas.width, height: shownCanvas.height)
                .offset(x: shownCanvas.minX, y: shownCanvas.minY)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
            ForEach(Array(shownOrder.enumerated()), id: \.element) { position, id in
                let f = shown.frames[position]
                let r = CGRect(x: shownCanvas.minX + f.minX * shownScale, y: shownCanvas.minY + f.minY * shownScale,
                               width: f.width * shownScale, height: f.height * shownScale)
                tile(model.items[id], frame: r, placeholder: id == draggedID)
                    .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("collage"))
                        .onChanged { g in
                            if dragging == nil, let p = model.order.firstIndex(of: id) { dragging = (p, g.location) }
                            dragging?.location = g.location
                        }
                        .onEnded { g in
                            if let d = dragging, let t = hoveredPosition(g.location, layout: committed, canvas: canvas, scale: scale) {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) { model.move(from: d.position, to: t) }
                            }
                            dragging = nil
                        })
                    .accessibilityLabel(String(localized: "Image \(position + 1): \(model.items[id].name)"))
                    .accessibilityAction(named: String(localized: "Move earlier")) { model.move(from: position, to: max(0, position - 1)) }
                    .accessibilityAction(named: String(localized: "Move later")) { model.move(from: position, to: min(model.order.count - 1, position + 1)) }
            }
            if let d = dragging, let id = draggedID, let pos = model.order.firstIndex(of: id) {
                let f = committed.frames[pos]
                let w = f.width * scale, h = f.height * scale
                tile(model.items[id], frame: CGRect(x: d.location.x - w / 2, y: d.location.y - h / 2, width: w, height: h), placeholder: false)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                    .scaleEffect(1.04)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "collage")
        .animation(reduceMotion || dragging == nil ? nil : .easeOut(duration: DesignTokens.Motion.morph), value: shownOrder)
    }

    private func tile(_ item: ImageEditorItem, frame r: CGRect, placeholder: Bool) -> some View {
        Group {
            if let t = item.thumbnail {
                Image(decorative: t, scale: 1).resizable().interpolation(.high)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: max(1, r.width), height: max(1, r.height))
        .opacity(placeholder ? 0.25 : 1)
        .overlay(placeholder ? RoundedRectangle(cornerRadius: 3).strokeBorder(ImageEditorKit.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 3])) : nil)
        .contentShape(Rectangle())
        .offset(x: r.minX, y: r.minY)
        .onHover { inside in (inside ? NSCursor.openHand : NSCursor.arrow).set() }
    }

    private func hoveredPosition(_ p: CGPoint, layout: CollageLayout, canvas: CGRect, scale: CGFloat) -> Int? {
        let local = CGPoint(x: (p.x - canvas.minX) / scale, y: (p.y - canvas.minY) / scale)
        if let i = layout.frames.firstIndex(where: { $0.insetBy(dx: -CGFloat(model.gap) / 2, dy: -CGFloat(model.gap) / 2).contains(local) }) { return i }
        // Nearest frame centre.
        return layout.frames.indices.min { a, b in
            hypot(layout.frames[a].midX - local.x, layout.frames[a].midY - local.y) < hypot(layout.frames[b].midX - local.x, layout.frames[b].midY - local.y)
        }
    }
}

struct ImageCollageSidebar: View {
    @ObservedObject var model: ImageCollageModel

    var body: some View {
        ImageEditorKit.Section(String(localized: "Layout")) {
            Picker(String(localized: "Layout"), selection: $model.layoutKind) {
                Label(String(localized: "Grid"), systemImage: "square.grid.2x2").tag(CollageStyle.Layout.grid)
                Label(String(localized: "Row"), systemImage: "rectangle.split.3x1").tag(CollageStyle.Layout.row)
                Label(String(localized: "Column"), systemImage: "rectangle.split.1x2").tag(CollageStyle.Layout.column)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            ImageEditorKit.Hint(String(localized: "Images are never cropped: rows are sized to fit each photo whole."))
        }
        ImageEditorKit.Section(String(localized: "Spacing")) {
            ImageEditorKit.ValueSlider(label: String(localized: "Gap"), value: $model.gap, range: 0...80, step: 2, neutral: 16,
                                       format: { "\(Int($0)) px" })
            Text("Background").font(.system(size: DesignTokens.TypeRamp.body))
            ImageEditorKit.SwatchPicker(hex: $model.background, swatches: ["#FFFFFF", "#F2F2F7", "#1C1B22", "#000000", "#6E56F8", "#22C3A6"])
        }
        ImageEditorKit.Section(String(localized: "Output width")) {
            Picker(String(localized: "Output width"), selection: $model.width) {
                ForEach(ImageCollageModel.widthPresets, id: \.self) { w in Text("\(w) px").tag(w) }
                if !ImageCollageModel.widthPresets.contains(model.width) { Text("\(model.width) px").tag(model.width) }
            }
            .labelsHidden()
        }
        ImageEditorKit.Section(String(localized: "Order")) {
            ImageEditorKit.ReorderList(items: model.items, order: $model.order)
            ImageEditorKit.Hint(String(localized: "Drag photos in the preview or in this list to reorder."))
        }
    }
}
