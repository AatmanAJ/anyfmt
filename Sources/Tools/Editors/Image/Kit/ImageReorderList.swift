import AppKit
import SwiftUI
import HaloCore

/// One input image as the multi-file editors show it.
struct ImageEditorItem: Identifiable {
    let id: Int              // index into the editor's inputs
    let url: URL
    let thumbnail: CGImage?
    /// Upright pixel size.
    let pixelSize: CGSize
    let dpi: CGFloat

    var aspect: CGFloat { pixelSize.height > 0 ? pixelSize.width / pixelSize.height : 1 }
    var name: String { url.lastPathComponent }

    static func load(_ urls: [URL], edge: Int = 480) -> [ImageEditorItem] {
        urls.enumerated().map { i, url in
            let thumb = ToolImageSupport.thumbnail(url, maxPixelSize: edge)
            let size = ToolImageSupport.pixelSize(of: url) ?? thumb.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 1, height: 1)
            let dpi = (ToolImageSupport.properties(of: url)?["DPIWidth"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 72
            return ImageEditorItem(id: i, url: url, thumbnail: thumb, pixelSize: size, dpi: dpi)
        }
    }
}

extension ImageEditorKit {
    /// Drag-to-reorder list of thumbnails with VoiceOver move actions.
    struct ReorderList: View {
        let items: [ImageEditorItem]
        @Binding var order: [Int]
        var selection: Binding<Int?>? = nil

        var body: some View {
            List {
                ForEach(Array(order.enumerated()), id: \.element) { position, id in
                    if let item = items.first(where: { $0.id == id }) {
                        row(item, position: position, selected: selection?.wrappedValue == id)
                            .listRowBackground(selection?.wrappedValue == id ? ImageEditorKit.accent.opacity(0.22) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { selection?.wrappedValue = id }
                    }
                }
                .onMove { from, to in order.move(fromOffsets: from, toOffset: to) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: min(CGFloat(order.count) * 44 + 4, 264))
            .background(EditorPalette.chip)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                .strokeBorder(Color.haloHairline, lineWidth: DesignTokens.Shape.hairline))
        }

        private func row(_ item: ImageEditorItem, position: Int, selected: Bool) -> some View {
            HStack(spacing: DesignTokens.Space.s) {
                Text("\(position + 1)")
                    .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.haloSecondaryText)
                    .frame(width: 16, alignment: .trailing)
                Group {
                    if let t = item.thumbnail {
                        Image(decorative: t, scale: 1).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        EditorPalette.canvas
                    }
                }
                .frame(width: EditorTokens.rowThumbnail, height: EditorTokens.rowThumbnail)
                .clipped()
                Text(item.name)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: selected ? .bold : .regular))
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "line.3.horizontal").foregroundStyle(Color.haloSecondaryText).accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(position + 1): \(item.name)"))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityAction(named: String(localized: "Move up")) { move(item.id, by: -1) }
            .accessibilityAction(named: String(localized: "Move down")) { move(item.id, by: 1) }
        }

        private func move(_ id: Int, by delta: Int) {
            guard let i = order.firstIndex(of: id) else { return }
            let j = min(order.count - 1, max(0, i + delta))
            guard i != j else { return }
            order.swapAt(i, j)
        }
    }
}
