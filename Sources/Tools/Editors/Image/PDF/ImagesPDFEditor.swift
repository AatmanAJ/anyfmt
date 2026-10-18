import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HaloCore

@MainActor
final class ImagesPDFModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let items: [ImageEditorItem]

    @Published var order: [Int]
    @Published var pageSize: String
    @Published var selection: Int?

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        items = ImageEditorItem.load(inputs, edge: 420)
        order = OrderOption.apply(tool.defaultOptions.string("order", default: ""), to: Array(inputs.indices))
        pageSize = tool.defaultOptions.string(OptionKey.pageSize, default: "fit")
    }

    var options: OptionValues {
        OptionValues([OptionKey.pageSize: .string(pageSize), "order": .string(OrderOption.format(order))])
    }

    var canSave: Bool { !order.isEmpty }

    var pageCountText: String {
        order.count == 1 ? String(localized: "1 page") : String(localized: "\(order.count) pages")
    }

    var statusLine: String? {
        let size: String = switch pageSize {
        case "a4": "A4"
        case "letter": String(localized: "US Letter")
        default: String(localized: "pages fit each image")
        }
        return "\(pageCountText) · \(size)"
    }

    func page(_ item: ImageEditorItem) -> (media: CGRect, frame: CGRect) {
        PDFPagePlan.page(for: item.pixelSize, dpi: item.dpi, pageSize: pageSize)
    }

    func move(from: Int, to: Int) {
        guard order.indices.contains(from), order.indices.contains(to), from != to else { return }
        let id = order.remove(at: from)
        order.insert(id, at: to)
    }

    func reverse() { order.reverse() }

    func sortByName() {
        order.sort { items[$0].name.localizedStandardCompare(items[$1].name) == .orderedAscending }
    }
}

struct ImagesPDFEditor: View {
    @ObservedObject var model: ImagesPDFModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImagesPDFPages(model: model, showOriginal: original)
        }, sidebar: {
            ImagesPDFSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImagesPDFPages: View {
    @ObservedObject var model: ImagesPDFModel
    let showOriginal: Bool
    @State private var dragged: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: DesignTokens.Space.xl)], spacing: DesignTokens.Space.xl) {
                ForEach(Array((showOriginal ? Array(model.items.indices) : model.order).enumerated()), id: \.element) { position, id in
                    pageCard(model.items[id], number: position + 1, selected: model.selection == id && !showOriginal)
                        .onTapGesture { model.selection = id }
                        .onDrag {
                            dragged = id
                            return NSItemProvider(object: String(id) as NSString)
                        }
                        .onDrop(of: [.plainText], delegate: PageDrop(target: id, model: model, dragged: $dragged, animate: !reduceMotion))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "Page \(position + 1): \(model.items[id].name)"))
                        .accessibilityAction(named: String(localized: "Move earlier")) { model.move(from: position, to: max(0, position - 1)) }
                        .accessibilityAction(named: String(localized: "Move later")) { model.move(from: position, to: min(model.order.count - 1, position + 1)) }
                }
            }
            .padding(DesignTokens.Space.xl)
        }
    }

    private func pageCard(_ item: ImageEditorItem, number: Int, selected: Bool) -> some View {
        let plan = showOriginal ? (media: CGRect(origin: .zero, size: item.pixelSize), frame: CGRect(origin: .zero, size: item.pixelSize)) : model.page(item)
        let box: CGFloat = 170
        let s = min(box / plan.media.width, box / plan.media.height)
        let pw = plan.media.width * s, ph = plan.media.height * s
        // PDF frames are y-up; the card is y-down.
        let f = CGRect(x: plan.frame.minX * s, y: (plan.media.height - plan.frame.maxY) * s, width: plan.frame.width * s, height: plan.frame.height * s)
        return VStack(spacing: DesignTokens.Space.s) {
            ZStack(alignment: .topLeading) {
                // The page itself is paper white in both appearances.
                Rectangle().fill(Color(hex: DesignTokens.Primitive.paper0))
                if let t = item.thumbnail {
                    Image(decorative: t, scale: 1).resizable().interpolation(.high)
                        .frame(width: f.width, height: f.height)
                        .offset(x: f.minX, y: f.minY)
                }
            }
            .frame(width: pw, height: ph)
            .clipShape(Rectangle())
            .overlay(Rectangle().strokeBorder(selected ? ImageEditorKit.accent : Color.haloHairline, lineWidth: selected ? 3 : DesignTokens.Shape.hairline))
            .frame(width: box, height: box)
            .opacity(dragged == item.id ? 0.4 : 1)
            HStack(spacing: 4) {
                Text("\(number)").font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(selected ? EditorPalette.onSelected : Color.haloInk)
                    .padding(.horizontal, DesignTokens.Space.xs + 1)
                    .background(Capsule().fill(selected ? EditorPalette.selected : Color.clear))
                Text(item.name).font(.system(size: DesignTokens.TypeRamp.caption, weight: selected ? .semibold : .regular))
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(selected ? Color.haloInk : Color.haloSecondaryText)
            }
            .frame(maxWidth: box)
        }
    }

    private struct PageDrop: DropDelegate {
        let target: Int
        let model: ImagesPDFModel
        @Binding var dragged: Int?
        let animate: Bool

        func dropEntered(info: DropInfo) {
            guard let d = dragged, d != target, let from = model.order.firstIndex(of: d), let to = model.order.firstIndex(of: target) else { return }
            if animate {
                withAnimation(.easeOut(duration: DesignTokens.Motion.morph)) { model.move(from: from, to: to) }
            } else {
                model.move(from: from, to: to)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

        func performDrop(info: DropInfo) -> Bool {
            dragged = nil
            return true
        }
    }
}

struct ImagesPDFSidebar: View {
    @ObservedObject var model: ImagesPDFModel

    var body: some View {
        ImageEditorKit.Section(String(localized: "Page size")) {
            EditorChoiceChips(String(localized: "Page size"), selection: $model.pageSize, options: [
                .init("fit", String(localized: "Fit image")),
                .init("a4", String(localized: "A4")),
                .init("letter", String(localized: "Letter")),
            ])
            ImageEditorKit.Hint(model.pageSize == "fit"
                ? String(localized: "Each page is exactly the size of its image. JPEGs are embedded without recompression.")
                : String(localized: "Images are centred with a margin and pages turn landscape for landscape photos."))
        }
        ImageEditorKit.Section(String(localized: "Pages")) {
            HStack {
                Text(model.pageCountText)
                    .font(.haloDisplay(DesignTokens.Typeface.Size.displayM))
                    .displayTracking(DesignTokens.Typeface.Size.displayM)
                Spacer()
                Menu {
                    Button(String(localized: "Sort by name")) { model.sortByName() }
                    Button(String(localized: "Reverse order")) { model.reverse() }
                } label: { Image(systemName: "arrow.up.arrow.down") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(String(localized: "Reorder pages"))
            }
            ImageEditorKit.ReorderList(items: model.items, order: $model.order,
                                       selection: Binding(get: { model.selection }, set: { model.selection = $0 }))
            ImageEditorKit.Hint(String(localized: "Drag pages to reorder them."))
        }
    }
}
