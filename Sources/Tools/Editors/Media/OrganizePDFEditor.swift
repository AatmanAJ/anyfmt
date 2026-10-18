import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import HaloCore

/// Merge / split / reorder / rotate / delete PDF pages on a thumbnail grid.
@MainActor
final class OrganizePDFModel: MediaEditorModel {
    struct Page: Identifiable, Hashable {
        let id: UUID
        let input: Int
        let page: Int
        var rotation: Int
        var ref: PDFPageRef { PDFPageRef(input: input, page: page, rotation: rotation) }
        var key: Int { input * 1_000_000 + page }
    }

    let tool: ToolSpec
    let inputs: [URL]
    @Published var pages: [Page]
    @Published var selection: Set<UUID> = []
    @Published var split: Bool
    @Published private(set) var thumbnails: [Int: NSImage] = [:]
    @Published var dragging: UUID?
    let pageCounts: [Int]
    let failed: [URL]
    private let documents: [PDFDocument?]
    private(set) var originalPages: [Page]
    private var anchor: UUID?
    private var thumbTask: Task<Void, Never>?

    static let tags = ["A", "B", "C", "D", "E", "F", "G", "H"]

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        documents = inputs.map { url in
            guard let d = PDFDocument(url: url), !d.isLocked else { return nil }
            return d
        }
        failed = zip(inputs, documents).filter { $0.1 == nil }.map(\.0)
        pageCounts = documents.map { $0?.pageCount ?? 0 }
        let all = pageCounts.enumerated().flatMap { i, n in (0..<n).map { Page(id: UUID(), input: i, page: $0, rotation: 0) } }
        originalPages = all
        if let refs = PDFPageRef.parse(options.string("order", default: ""), pageCounts: pageCounts),
           !options.string("order", default: "").isEmpty {
            pages = refs.map { Page(id: UUID(), input: $0.input, page: $0.page, rotation: $0.rotation) }
        } else {
            pages = all
        }
        split = options.bool("split", default: false)
    }

    var subject: String {
        inputs.count == 1 ? inputs[0].lastPathComponent : String(localized: "\(inputs.count) PDFs")
    }

    func start() {
        guard thumbTask == nil else { return }
        let keys = Array(Set(originalPages.map(\.key))).sorted()
        thumbTask = Task { [weak self] in
            for key in keys {
                guard let self, !Task.isCancelled else { return }
                let input = key / 1_000_000, index = key % 1_000_000
                if let page = self.documents[input]?.page(at: index) {
                    self.thumbnails[key] = page.thumbnail(of: CGSize(width: 260, height: 260), for: .cropBox)
                }
                await Task.yield()
            }
        }
    }

    func teardown() { thumbTask?.cancel() }

    func settle() async {
        let deadline = Date().addingTimeInterval(10)
        while thumbnails.count < Set(originalPages.map(\.key)).count, Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }

    var isChanged: Bool { pages.map(\.ref) != originalPages.map(\.ref) }
    var deletedCount: Int { max(0, originalPages.count - pages.count) }

    var options: OptionValues {
        OptionValues(["order": .string(isChanged ? PDFPageRef.format(pages.map(\.ref)) : ""), "split": .bool(split)])
    }

    var canSave: Bool { !pages.isEmpty && failed.isEmpty && (isChanged || inputs.count > 1 || split) }

    var statusLine: String? {
        let total = originalPages.count
        var s = pages.count == total ? String(localized: "\(pages.count) pages") : String(localized: "\(total) pages → \(pages.count) pages")
        if inputs.count > 1 { s += " · " + String(localized: "merging \(inputs.count) files") }
        if split { s += " · " + String(localized: "\(pages.count) separate files") }
        return s
    }

    // MARK: Editing

    func tap(_ page: Page) {
        let mods = NSEvent.modifierFlags
        if mods.contains(.command) {
            if selection.contains(page.id) { selection.remove(page.id) } else { selection.insert(page.id) }
            anchor = page.id
        } else if mods.contains(.shift), let a = anchor, let i = pages.firstIndex(where: { $0.id == a }),
                  let j = pages.firstIndex(of: page) {
            selection = Set(pages[min(i, j)...max(i, j)].map(\.id))
        } else {
            selection = [page.id]
            anchor = page.id
        }
    }

    func selectAll() { selection = Set(pages.map(\.id)) }

    private var targets: Set<UUID> { selection }

    func rotate(_ degrees: Int, only page: Page? = nil) {
        let ids = page.map { [$0.id] } ?? targets
        for i in pages.indices where ids.contains(pages[i].id) {
            pages[i].rotation = ((pages[i].rotation + degrees) % 360 + 360) % 360
        }
    }

    func delete(only page: Page? = nil) {
        let ids = page.map { [$0.id] } ?? targets
        guard !ids.isEmpty, pages.count > ids.count else { return } // never delete every page
        pages.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    func reset() {
        pages = originalPages
        selection = []
    }

    /// Live reorder while dragging over `target`.
    func moveDragging(onto target: Page) {
        guard let d = dragging, d != target.id, let from = pages.firstIndex(where: { $0.id == d }),
              let to = pages.firstIndex(of: target) else { return }
        pages.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func movePage(_ page: Page, by delta: Int) {
        guard let i = pages.firstIndex(of: page) else { return }
        let j = min(max(0, i + delta), pages.count - 1)
        guard i != j else { return }
        pages.move(fromOffsets: IndexSet(integer: i), toOffset: j > i ? j + 1 : j)
    }

    func thumbnail(_ p: Page) -> NSImage? { thumbnails[p.key] }

    func handle(_ key: EditorKey) -> Bool {
        switch key {
        case .delete: delete()
        case .command("a"): selectAll()
        case .command("l"): rotate(-90)
        case .command("r"): rotate(90)
        default: return false
        }
        return true
    }
}

struct OrganizePDFEditor: View {
    @ObservedObject var model: OrganizePDFModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EditorShell(model: model, preview: { original in preview(original) }, sidebar: { sidebar }, onSave: onSave, onClose: onClose)
            .background(KeyMonitor(handler: model.handle))
    }

    private func preview(_ original: Bool) -> some View {
        VStack(spacing: 0) {
            toolbar(original)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132, maximum: 170), spacing: DesignTokens.Space.l)],
                          spacing: DesignTokens.Space.l) {
                    let shown = original ? model.originalPages : model.pages
                    ForEach(Array(shown.enumerated()), id: \.element.id) { n, page in
                        PageCell(model: model, page: page, number: n + 1, interactive: !original)
                    }
                }
                .padding(DesignTokens.Space.l)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: model.pages)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selection = [] }
        }
    }

    private func toolbar(_ original: Bool) -> some View {
        HStack(spacing: DesignTokens.Space.s) {
            Button { model.rotate(-90) } label: { Label("Rotate Left", systemImage: "rotate.left") }
                .help(String(localized: "Rotate selected pages left (⌘L)"))
            Button { model.rotate(90) } label: { Label("Rotate Right", systemImage: "rotate.right") }
                .help(String(localized: "Rotate selected pages right (⌘R)"))
            Button(role: .destructive) { model.delete() } label: { Label("Delete", systemImage: "trash") }
                .help(String(localized: "Delete selected pages (⌫)"))
            Spacer()
            Text(model.selection.isEmpty ? String(localized: "Drag pages to reorder") : String(localized: "\(model.selection.count) selected"))
                .font(MediaStyle.caption()).foregroundStyle(.secondary)
            Button(String(localized: "Select All")) { model.selectAll() }
        }
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
        .disabled(original)
        .padding(.horizontal, DesignTokens.Space.l)
        .padding(.vertical, DesignTokens.Space.s)
        .environment(\.isEnabled, !original)
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(model.inputs.count > 1 ? String(localized: "Files") : String(localized: "File")) {
            ForEach(Array(model.inputs.enumerated()), id: \.offset) { i, url in
                HStack(spacing: DesignTokens.Space.s) {
                    InputTag(index: i)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(url.lastPathComponent).font(MediaStyle.label(.medium)).lineLimit(1).truncationMode(.middle)
                        Text(model.failed.contains(url) ? String(localized: "Can’t open (locked or damaged)") : String(localized: "\(model.pageCounts[i]) pages"))
                            .font(MediaStyle.caption()).foregroundStyle(model.failed.contains(url) ? MediaStyle.danger : .secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        Divider()
        SidebarSection(String(localized: "Output")) {
            InfoRow(label: String(localized: "Pages"), value: "\(model.pages.count)")
            if model.deletedCount > 0 {
                InfoRow(label: String(localized: "Deleted"), value: "\(model.deletedCount)")
            }
            Toggle(String(localized: "Split into single pages"), isOn: $model.split).toggleStyle(.switch).controlSize(.small)
            Text(model.split ? String(localized: "Saves \(model.pages.count) one-page PDFs together in a folder.")
                             : String(localized: "Saves one PDF with the pages in this order."))
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Reset Pages")) { model.reset() }.controlSize(.small).disabled(!model.isChanged)
        }
        Divider()
        Note(systemImage: "text.cursor", text: String(localized: "Pages are copied as they are: text stays selectable and nothing is turned into images. Bookmarks are kept for pages you keep."))
        Divider()
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("⌘A", String(localized: "Select all")), ("⌘L ⌘R", String(localized: "Rotate left / right")),
                             ("⌫", String(localized: "Delete selected")), ("⌘-click", String(localized: "Add to selection"))])
        }
    }
}

/// Coloured letter for an input file.
private struct InputTag: View {
    let index: Int

    static func color(_ i: Int) -> Color {
        [MediaStyle.accent, MediaStyle.mint, MediaStyle.color(DesignTokens.Palette.proGold), MediaStyle.danger][i % 4]
    }

    var body: some View {
        Text(OrganizePDFModel.tags[index % OrganizePDFModel.tags.count])
            .font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(RoundedRectangle(cornerRadius: 4).fill(Self.color(index)))
    }
}

private struct PageCell: View {
    @ObservedObject var model: OrganizePDFModel
    let page: OrganizePDFModel.Page
    let number: Int
    let interactive: Bool
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var selected: Bool { interactive && model.selection.contains(page.id) }

    var body: some View {
        VStack(spacing: DesignTokens.Space.s) {
            ZStack {
                if let image = model.thumbnail(page) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .rotationEffect(.degrees(Double(page.rotation)))
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: page.rotation)
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.06)).aspectRatio(0.77, contentMode: .fit)
                }
                if hovering && interactive { hoverButtons }
            }
            .frame(width: 124, height: 124)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).fill(selected ? MediaStyle.accent.opacity(0.14) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .strokeBorder(selected ? MediaStyle.accent : Color.clear, lineWidth: contrast == .increased ? 3 : 2))
            .opacity(model.dragging == page.id ? 0.35 : 1)
            HStack(spacing: 5) {
                Text("\(number)").font(MediaStyle.label(.semibold).monospacedDigit())
                InputTagSmall(index: page.input, multiple: model.inputs.count > 1, page: page.page + 1)
                if page.rotation != 0 {
                    Image(systemName: "rotate.right").font(.system(size: 9)).foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Rotated \(page.rotation) degrees"))
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if interactive { model.tap(page) } }
        .onDrag {
            model.dragging = page.id
            return NSItemProvider(object: page.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: PageDropDelegate(model: model, target: page))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(number), from \(model.inputs[page.input].lastPathComponent) page \(page.page + 1)"))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { model.tap(page) }
        .accessibilityAction(named: Text("Rotate right")) { model.rotate(90, only: page) }
        .accessibilityAction(named: Text("Delete page")) { model.delete(only: page) }
        .accessibilityAction(named: Text("Move earlier")) { model.movePage(page, by: -1) }
        .accessibilityAction(named: Text("Move later")) { model.movePage(page, by: 1) }
    }

    private var hoverButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                cellButton("rotate.left", String(localized: "Rotate left")) { model.rotate(-90, only: page) }
                cellButton("rotate.right", String(localized: "Rotate right")) { model.rotate(90, only: page) }
                cellButton("trash", String(localized: "Delete page")) { model.delete(only: page) }
            }
            .padding(4)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 4)
        }
    }

    private func cellButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11, weight: .medium)).frame(width: 22, height: 20) }
            .buttonStyle(.borderless)
            .help(label)
            .accessibilityLabel(Text(label))
    }
}

private struct InputTagSmall: View {
    let index: Int
    let multiple: Bool
    let page: Int

    var body: some View {
        if multiple {
            Text("\(OrganizePDFModel.tags[index % OrganizePDFModel.tags.count])\(page)")
                .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(InputTag.color(index)))
        } else {
            Text("p.\(page)").font(MediaStyle.caption().monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

private struct PageDropDelegate: DropDelegate {
    let model: OrganizePDFModel
    let target: OrganizePDFModel.Page

    func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated { model.moveDragging(onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated { model.dragging = nil }
        return true
    }

    func dropExited(info: DropInfo) {}
}
