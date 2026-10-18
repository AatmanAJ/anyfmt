import AppKit
import SwiftUI
import HaloCore

@MainActor
final class ImageAnnotateModel: ToolEditorModel {
    enum Mode: String, CaseIterable, Identifiable {
        case select, arrow, line, box, ellipse, text, highlight, freehand
        var id: String { rawValue }

        var glyph: String {
            switch self {
            case .select: "cursorarrow"
            case .arrow: "arrow.up.right"
            case .line: "line.diagonal"
            case .box: "rectangle"
            case .ellipse: "circle"
            case .text: "textformat"
            case .highlight: "highlighter"
            case .freehand: "scribble"
            }
        }

        var label: String {
            switch self {
            case .select: String(localized: "Select")
            case .arrow: String(localized: "Arrow")
            case .line: String(localized: "Line")
            case .box: String(localized: "Box")
            case .ellipse: String(localized: "Ellipse")
            case .text: String(localized: "Text")
            case .highlight: String(localized: "Highlight")
            case .freehand: String(localized: "Draw")
            }
        }

        var kind: Annotation.Kind? {
            switch self {
            case .select: nil
            case .arrow: .arrow
            case .line: .line
            case .box: .box
            case .ellipse: .ellipse
            case .text: .text
            case .highlight: .highlight
            case .freehand: .freehand
            }
        }

        var shortcut: KeyEquivalent {
            switch self {
            case .select: "v"
            case .arrow: "a"
            case .line: "l"
            case .box: "r"
            case .ellipse: "o"
            case .text: "t"
            case .highlight: "h"
            case .freehand: "d"
            }
        }
    }

    let tool: ToolSpec
    let inputs: [URL]
    let preview: CGImage?
    let pixelSize: CGSize

    @Published var annotations: [Annotation] = []
    @Published var selection: UUID?
    @Published var mode: Mode = .arrow
    @Published var color = "#FF3B30" // token-ok: default paint colour (content)
    @Published var width = 0.008
    @Published var fontSize = Annotation.defaultFontSize
    /// Bumped to ask the sidebar to focus the text field.
    @Published var textFocusRequest = 0

    private(set) var undoStack: [[Annotation]] = []
    private(set) var redoStack: [[Annotation]] = []

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        preview = inputs.first.flatMap { ImageEditorKit.preview($0) }
        pixelSize = inputs.first.flatMap(ToolImageSupport.pixelSize(of:)) ?? .zero
        annotations = Annotation.decodeList(tool.defaultOptions.string("annotations", default: "[]"))
    }

    var options: OptionValues { OptionValues(["annotations": .string(Annotation.encodeList(annotations))]) }
    var canSave: Bool { preview != nil && !annotations.isEmpty }
    var statusLine: String? {
        annotations.isEmpty ? String(localized: "Pick a tool and drag on the image")
            : String(localized: "\(annotations.count) marks · \(ImageEditorKit.pixelText(pixelSize))")
    }

    var selected: Annotation? { annotations.first { $0.id == selection } }

    // MARK: Undo

    func checkpoint() {
        undoStack.append(annotations)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = last
        if let s = selection, !annotations.contains(where: { $0.id == s }) { selection = nil }
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }

    // MARK: Editing

    func update(_ id: UUID, _ body: (inout Annotation) -> Void) {
        guard let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        body(&annotations[i])
    }

    func add(_ a: Annotation) {
        checkpoint()
        annotations.append(a)
        selection = a.id
    }

    func deleteSelection() {
        guard let s = selection else { return }
        checkpoint()
        annotations.removeAll { $0.id == s }
        selection = nil
    }

    func clearAll() {
        guard !annotations.isEmpty else { return }
        checkpoint()
        annotations.removeAll()
        selection = nil
    }

    /// Colour / width / size changes apply to the selection and become the new default.
    func setColor(_ hex: String) {
        color = hex
        if let s = selection, selected?.color != hex { checkpoint(); update(s) { $0.color = hex } }
    }

    func setWidth(_ w: Double, commit: Bool) {
        width = w
        guard let s = selection, selected?.kind != .text else { return }
        if commit { checkpoint() }
        update(s) { $0.width = w }
    }

    func setFontSize(_ f: Double, commit: Bool) {
        fontSize = f
        guard let s = selection, selected?.kind == .text else { return }
        if commit { checkpoint() }
        update(s) { $0.fontSize = f }
    }

    func newAnnotation(_ kind: Annotation.Kind, at p: CGPoint) -> Annotation {
        switch kind {
        case .text:
            Annotation(kind: .text, points: [p], color: color, width: width, text: String(localized: "Text"), fontSize: fontSize)
        case .highlight:
            Annotation(kind: .highlight, points: [p, p], color: color == "#FF3B30" ? "#FFCC00" : color, width: width) // token-ok: paint colours
        case .freehand:
            Annotation(kind: .freehand, points: [p], color: color, width: width)
        default:
            Annotation(kind: kind, points: [p, p], color: color, width: width)
        }
    }

    func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard let s = selection else { return }
        checkpoint()
        update(s) { a in a.points = a.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) } }
    }

    /// Topmost mark under `p` (normalised), measured in view points.
    func hit(_ p: CGPoint, viewSize: CGSize) -> UUID? {
        func v(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x * viewSize.width, y: q.y * viewSize.height) }
        let pv = v(p)
        let unit = min(viewSize.width, viewSize.height)
        for a in annotations.reversed() {
            let tolerance = max(6, CGFloat(a.width) * unit / 2 + 4)
            switch a.kind {
            case .arrow, .line, .freehand:
                let pts = a.points.map(v)
                if pts.count == 1, let only = pts.first, hypot(only.x - pv.x, only.y - pv.y) <= tolerance { return a.id }
                for i in 0..<max(0, pts.count - 1) where Self.distance(pv, pts[i], pts[i + 1]) <= tolerance { return a.id }
            default:
                let b = AnnotationRenderer.bounds(of: a, imageSize: viewSize)
                if b.insetBy(dx: -4 / max(1, viewSize.width), dy: -4 / max(1, viewSize.height)).contains(p) { return a.id }
            }
        }
        return nil
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

struct ImageAnnotateEditor: View {
    @ObservedObject var model: ImageAnnotateModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImageAnnotateCanvas(model: model, showOriginal: original)
        }, sidebar: {
            ImageAnnotateSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageAnnotateCanvas: View {
    @ObservedObject var model: ImageAnnotateModel
    let showOriginal: Bool

    private enum Action {
        case creating(UUID)
        case moving(UUID, [CGPoint])
        case handle(UUID, Int)
        case none
    }

    @State private var action: Action = .none
    @State private var snapshot: [Annotation] = []
    @State private var keys = ImageEditorKeyCatcher.Handle()

    var body: some View {
        ImageEditorKit.FittedImage(image: model.preview, size: model.pixelSize, source: model.inputs.first) { rect in
            if !showOriginal {
                Canvas { ctx, _ in
                    ctx.withCGContext { cg in
                        cg.translateBy(x: rect.minX, y: rect.minY)
                        cg.clip(to: CGRect(origin: .zero, size: rect.size))
                        AnnotationRenderer.draw(model.annotations, in: cg, size: rect.size)
                    }
                }
                .allowsHitTesting(false)
                selectionOverlay(rect)
                Rectangle().fill(Color.white.opacity(0.001))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .gesture(drag(rect))
                    .onContinuousHover { phase in
                        if case .active = phase { (model.mode == .select ? NSCursor.arrow : NSCursor.crosshair).set() } else { NSCursor.arrow.set() }
                    }
            }
        }
        .background(ImageEditorKeyCatcher(handle: keys) { event in
            if ImageEditorKeyCatcher.isDelete(event), model.selection != nil { model.deleteSelection(); return true }
            if let d = ImageEditorKeyCatcher.arrowDelta(event), model.selection != nil {
                let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
                model.nudgeSelection(dx: d.x * step / max(1, model.pixelSize.width), dy: d.y * step / max(1, model.pixelSize.height))
                return true
            }
            return false
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Annotation canvas"))
        .accessibilityValue(String(localized: "\(model.annotations.count) marks"))
    }

    @ViewBuilder
    private func selectionOverlay(_ rect: CGRect) -> some View {
        if let a = model.selected {
            let b = ImageEditorKit.denormalized(AnnotationRenderer.bounds(of: a, imageSize: rect.size), in: rect)
            OverlayStroke(path: Path { $0.addRect(b.insetBy(dx: -4, dy: -4)) }, dash: [5, 3], width: DesignTokens.Shape.hairline)
            ForEach(Array(handlePoints(a).enumerated()), id: \.offset) { _, p in
                let v = ImageEditorKit.denormalized(p, in: rect)
                OverlayHandle(round: true).position(v).allowsHitTesting(false)
            }
        }
    }

    private func handlePoints(_ a: Annotation) -> [CGPoint] {
        switch a.kind {
        case .arrow, .line, .box, .ellipse, .highlight: Array(a.points.prefix(2))
        default: []
        }
    }

    private func drag(_ rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let p = ImageEditorKit.normalized(g.location, in: rect)
                if case .none = action { begin(at: ImageEditorKit.normalized(g.startLocation, in: rect), rect: rect) }
                switch action {
                case .creating(let id):
                    model.update(id) { a in
                        let q = ImageEditorKit.clamp01(p)
                        if a.kind == .freehand {
                            if let last = a.points.last, hypot((q.x - last.x) * rect.width, (q.y - last.y) * rect.height) >= 2 { a.points.append(q) }
                        } else if a.kind != .text {
                            a.points = [a.points[0], q]
                        }
                    }
                case .moving(let id, let original):
                    let s = ImageEditorKit.normalized(g.startLocation, in: rect)
                    model.update(id) { $0.points = original.map { CGPoint(x: $0.x + p.x - s.x, y: $0.y + p.y - s.y) } }
                case .handle(let id, let index):
                    model.update(id) { a in if index < a.points.count { a.points[index] = ImageEditorKit.clamp01(p) } }
                case .none:
                    break
                }
            }
            .onEnded { _ in finish(rect: rect) }
    }

    private func begin(at s: CGPoint, rect: CGRect) {
        keys.focus()
        snapshot = model.annotations
        // Handles of the selection win in every mode.
        if let a = model.selected {
            for (i, h) in handlePoints(a).enumerated() where hypot((h.x - s.x) * rect.width, (h.y - s.y) * rect.height) <= 8 {
                action = .handle(a.id, i)
                return
            }
        }
        if model.mode == .select || model.mode == .text, let id = model.hit(s, viewSize: rect.size) {
            model.selection = id
            action = .moving(id, model.annotations.first { $0.id == id }?.points ?? [])
            return
        }
        guard let kind = model.mode.kind else {
            model.selection = nil
            action = .none
            return
        }
        let a = model.newAnnotation(kind, at: ImageEditorKit.clamp01(s))
        model.annotations.append(a)
        model.selection = a.id
        action = .creating(a.id)
    }

    private func finish(rect: CGRect) {
        defer { action = .none }
        if case .creating(let id) = action, let a = model.annotations.first(where: { $0.id == id }) {
            let b = AnnotationRenderer.bounds(of: a, imageSize: rect.size)
            let tiny = a.kind != .text && a.kind != .freehand
                && max(abs(a.points[0].x - (a.points.last?.x ?? 0)) * rect.width, abs(a.points[0].y - (a.points.last?.y ?? 0)) * rect.height) < 4
            if tiny || (a.kind == .freehand && a.points.count < 2 && b.width * rect.width < 3) {
                model.annotations.removeAll { $0.id == id }
                model.selection = nil
                return
            }
            if a.kind == .text { model.textFocusRequest += 1 }
        }
        // A click (no drag) on a text mark puts the caret in its text field.
        if case .moving(let id, _) = action, model.annotations == snapshot,
           model.annotations.first(where: { $0.id == id })?.kind == .text {
            model.textFocusRequest += 1
        }
        if model.annotations != snapshot {
            // Record the state before this gesture.
            let after = model.annotations
            model.annotations = snapshot
            model.checkpoint()
            model.annotations = after
        }
    }
}

struct ImageAnnotateSidebar: View {
    @ObservedObject var model: ImageAnnotateModel
    @FocusState private var textFocused: Bool
    private var shortSide: Double { Double(max(1, min(model.pixelSize.width, model.pixelSize.height))) }

    var body: some View {
        ImageEditorKit.Section(String(localized: "Tool")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(ImageAnnotateModel.Mode.allCases) { m in
                    let selected = model.mode == m
                    Button { model.mode = m } label: {
                        VStack(spacing: 2) {
                            Image(systemName: m.glyph).font(.system(size: EditorTokens.cellGlyphSize, weight: .medium))
                            Text(m.label).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(EditorCellButtonStyle(selected: selected))
                    .keyboardShortcut(m.shortcut, modifiers: [.command, .option])
                    .help("\(m.label) (⌥⌘\(String(m.shortcut.character).uppercased()))")
                    .accessibilityLabel(m.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        ImageEditorKit.Section(String(localized: "Colour")) {
            ImageEditorKit.SwatchPicker(hex: Binding(get: { model.selected?.color ?? model.color }, set: { model.setColor($0) }))
        }
        if model.selected?.kind == .text || (model.selected == nil && model.mode == .text) {
            ImageEditorKit.Section(String(localized: "Text")) {
                if let s = model.selected, s.kind == .text {
                    TextField(String(localized: "Text"), text: Binding(get: { model.selected?.text ?? "" }, set: { v in model.update(s.id) { $0.text = v } }),
                              axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($textFocused)
                        .onChange(of: textFocused) { focused in if focused { model.checkpoint() } }
                        .accessibilityLabel(String(localized: "Annotation text"))
                }
                ImageEditorKit.ValueSlider(label: String(localized: "Size"),
                                           value: Binding(get: { model.selected?.fontSize ?? model.fontSize }, set: { model.setFontSize($0, commit: false) }),
                                           range: 0.02...0.16, step: 0.002, neutral: Annotation.defaultFontSize,
                                           format: { "\(max(1, Int(($0 * shortSide).rounded()))) px" },
                                           onEditingEnded: { model.setFontSize(model.selected?.fontSize ?? model.fontSize, commit: true) })
            }
        } else {
            ImageEditorKit.Section(String(localized: "Line")) {
                ImageEditorKit.ValueSlider(label: String(localized: "Width"),
                                           value: Binding(get: { model.selected?.width ?? model.width }, set: { model.setWidth($0, commit: false) }),
                                           range: 0.002...0.03, step: 0.0005, neutral: 0.008,
                                           format: { "\(max(1, Int(($0 * shortSide).rounded()))) px" },
                                           onEditingEnded: { model.setWidth(model.selected?.width ?? model.width, commit: true) })
            }
        }
        ImageEditorKit.Section(String(localized: "Edit")) {
            HStack(spacing: DesignTokens.Space.s) {
                Button { model.undo() } label: { Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward") }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!model.canUndo)
                Button { model.redo() } label: { Label(String(localized: "Redo"), systemImage: "arrow.uturn.forward") }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canRedo)
            }
            .labelStyle(.titleAndIcon)
            HStack(spacing: DesignTokens.Space.s) {
                Button(role: .destructive) { model.deleteSelection() } label: { Label(String(localized: "Delete"), systemImage: "trash") }
                    .disabled(model.selection == nil)
                Button(String(localized: "Clear all")) { model.clearAll() }
                    .disabled(model.annotations.isEmpty)
            }
            ImageEditorKit.Hint(String(localized: "Click a mark to select it, then drag it or its handles. Delete removes it; arrow keys nudge. Hover a tool for its shortcut."))
        }
        .onChange(of: model.textFocusRequest) { _ in textFocused = true }
    }
}
