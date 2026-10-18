import AppKit
import SwiftUI
import HaloCore

@MainActor
final class ImageRedactModel: ToolEditorModel {
    struct Region: Identifiable, Equatable {
        let id = UUID()
        var rect: CGRect
    }

    let tool: ToolSpec
    let inputs: [URL]
    let preview: CGImage?
    let pixelSize: CGSize

    @Published var regions: [Region] = [] { didSet { if regions != oldValue { renderPreview() } } }
    @Published var selection: UUID?
    @Published var style: Redactor.Style { didSet { if style != oldValue { renderPreview() } } }
    @Published var color = "#000000" { didSet { if color != oldValue { renderPreview() } } }
    @Published private(set) var rendered: CGImage?
    private(set) var undoStack: [[Region]] = []

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        preview = inputs.first.flatMap { ImageEditorKit.preview($0, edge: 1200) }
        pixelSize = inputs.first.flatMap(ImageSupport.pixelSize(of:)) ?? .zero
        let o = tool.defaultOptions
        style = Redactor.Style(rawValue: o.string("style", default: "pixelate")) ?? .pixelate
        regions = Redactor.parseRegions(o.string("regions", default: "")).map { Region(rect: $0) }
        rendered = preview
    }

    var options: OptionValues {
        OptionValues(["style": .string(style.rawValue), "regions": .string(Redactor.format(regions.map(\.rect))), "color": .string(color)])
    }

    var canSave: Bool { preview != nil && !regions.isEmpty }

    var statusLine: String? {
        regions.isEmpty ? String(localized: "Drag over anything you want to hide")
            : String(localized: "\(regions.count) areas · saved copy is permanently redacted")
    }

    func renderPreview() {
        guard let preview else { return }
        rendered = (try? Redactor.apply(preview, regions: regions.map(\.rect), style: style, fill: HexColor.cgColor(color),
                                        referenceSize: pixelSize)) ?? preview
    }

    func checkpoint() {
        undoStack.append(regions)
        if undoStack.count > 200 { undoStack.removeFirst() }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        regions = last
        if let s = selection, !regions.contains(where: { $0.id == s }) { selection = nil }
    }

    func deleteSelection() {
        guard let s = selection else { return }
        checkpoint()
        regions.removeAll { $0.id == s }
        selection = nil
    }

    func clearAll() {
        guard !regions.isEmpty else { return }
        checkpoint()
        regions.removeAll()
        selection = nil
    }

    func update(_ id: UUID, _ rect: CGRect) {
        guard let i = regions.firstIndex(where: { $0.id == id }) else { return }
        regions[i].rect = rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

struct ImageRedactEditor: View {
    @ObservedObject var model: ImageRedactModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImageRedactCanvas(model: model, showOriginal: original)
        }, sidebar: {
            ImageRedactSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageRedactCanvas: View {
    @ObservedObject var model: ImageRedactModel
    let showOriginal: Bool

    private enum Action { case none, creating(UUID, CGPoint), moving(UUID, CGRect), resizing(UUID, CGPoint) }
    @State private var action: Action = .none
    @State private var before: [ImageRedactModel.Region] = []
    @State private var keys = ImageEditorKeyCatcher.Handle()

    var body: some View {
        ImageEditorKit.FittedImage(image: showOriginal ? model.preview : model.rendered, size: model.pixelSize) { rect in
            if !showOriginal {
                ForEach(model.regions) { r in
                    let v = ImageEditorKit.denormalized(r.rect, in: rect)
                    let selected = r.id == model.selection
                    Rectangle().path(in: v)
                        .stroke(selected ? ImageEditorKit.accent : Color.white.opacity(0.85),
                                style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: selected ? [] : [5, 3]))
                        .shadow(color: .black.opacity(0.4), radius: 1)
                        .allowsHitTesting(false)
                    if selected {
                        // Resize handle (bottom-right); drag inside to move.
                        Circle().fill(Color.white).overlay(Circle().strokeBorder(ImageEditorKit.accent, lineWidth: 1.5))
                            .frame(width: 11, height: 11).position(x: v.maxX, y: v.maxY).allowsHitTesting(false)
                    }
                }
                Rectangle().fill(Color.white.opacity(0.001))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .gesture(drag(rect))
                    .onContinuousHover { phase in if case .active = phase { NSCursor.crosshair.set() } else { NSCursor.arrow.set() } }
            }
        }
        .background(ImageEditorKeyCatcher(handle: keys) { event in
            if event.isDeleteKey, model.selection != nil { model.deleteSelection(); return true }
            return false
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Redaction canvas"))
        .accessibilityValue(String(localized: "\(model.regions.count) areas"))
        .accessibilityHint(String(localized: "Drag to cover an area. Select an area and press Delete to remove it."))
    }

    private func drag(_ rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let p = ImageEditorKit.clamp01(ImageEditorKit.normalized(g.location, in: rect))
                if case .none = action { begin(ImageEditorKit.clamp01(ImageEditorKit.normalized(g.startLocation, in: rect)), rect: rect) }
                switch action {
                case .creating(let id, let anchor), .resizing(let id, let anchor):
                    model.update(id, CGRect(x: min(anchor.x, p.x), y: min(anchor.y, p.y), width: abs(p.x - anchor.x), height: abs(p.y - anchor.y)))
                case .moving(let id, let start):
                    let s = ImageEditorKit.normalized(g.startLocation, in: rect)
                    var r = start.offsetBy(dx: p.x - s.x, dy: p.y - s.y)
                    r.origin.x = min(max(0, r.minX), 1 - r.width)
                    r.origin.y = min(max(0, r.minY), 1 - r.height)
                    model.update(id, r)
                case .none:
                    break
                }
            }
            .onEnded { _ in
                if case .creating(let id, _) = action, let r = model.regions.first(where: { $0.id == id }),
                   r.rect.width * rect.width < 4 || r.rect.height * rect.height < 4 {
                    model.regions.removeAll { $0.id == id }
                    model.selection = nil
                } else if model.regions != before {
                    let after = model.regions
                    model.regions = before
                    model.checkpoint()
                    model.regions = after
                }
                action = .none
            }
    }

    private func begin(_ s: CGPoint, rect: CGRect) {
        keys.focus()
        before = model.regions
        if let sel = model.regions.first(where: { $0.id == model.selection }) {
            let corner = CGPoint(x: sel.rect.maxX, y: sel.rect.maxY)
            if hypot((corner.x - s.x) * rect.width, (corner.y - s.y) * rect.height) <= 9 {
                action = .resizing(sel.id, CGPoint(x: sel.rect.minX, y: sel.rect.minY))
                return
            }
        }
        if let hit = model.regions.last(where: { $0.rect.contains(s) }) {
            model.selection = hit.id
            action = .moving(hit.id, hit.rect)
            return
        }
        let r = ImageRedactModel.Region(rect: CGRect(origin: s, size: .zero))
        model.regions.append(r)
        model.selection = r.id
        action = .creating(r.id, s)
    }
}

struct ImageRedactSidebar: View {
    @ObservedObject var model: ImageRedactModel

    var body: some View {
        ImageEditorKit.Section(String(localized: "Style")) {
            Picker(String(localized: "Style"), selection: $model.style) {
                Text("Pixelate").tag(Redactor.Style.pixelate)
                Text("Blur").tag(Redactor.Style.blur)
                Text("Solid").tag(Redactor.Style.solid)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            if model.style == .solid {
                ImageEditorKit.SwatchPicker(hex: $model.color, swatches: ["#000000", "#FFFFFF", "#6E56F8", "#FF3B30"])
            }
        }
        ImageEditorKit.Section(String(localized: "Areas")) {
            HStack(spacing: DesignTokens.Space.s) {
                Button { model.undo() } label: { Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward") }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(model.undoStack.isEmpty)
                Button(role: .destructive) { model.deleteSelection() } label: { Label(String(localized: "Delete"), systemImage: "trash") }
                    .disabled(model.selection == nil)
                Button(String(localized: "Clear")) { model.clearAll() }
                    .disabled(model.regions.isEmpty)
                    .help(String(localized: "Remove every area"))
            }
            ImageEditorKit.Hint(String(localized: "Drag on the image to cover an area. Drag an area to move it, or its corner to resize."))
        }
        HStack(alignment: .top, spacing: DesignTokens.Space.s) {
            Image(systemName: "lock.fill").foregroundStyle(ImageEditorKit.accent).font(.system(size: 12))
            ImageEditorKit.Hint(String(localized: "The saved copy is redacted for good: covered pixels are replaced, not hidden, and no thumbnail of the original is kept. Your original file isn’t touched."))
        }
        .padding(DesignTokens.Space.m)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).fill(ImageEditorKit.accent.opacity(0.08)))
        .accessibilityElement(children: .combine)
    }
}
