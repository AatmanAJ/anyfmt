import AppKit
import PDFKit
import SwiftUI
import HaloCore

@MainActor
final class MetadataEditorModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]

    @Published private(set) var snapshot: MetadataSnapshot?
    @Published private(set) var loadError: String?
    @Published var edited: [String: String] = [:]
    let thumbnail: NSImage

    private var loadTask: Task<Void, Never>?

    init(tool: ToolSpec, inputs: [URL], autoload: Bool = true) {
        self.tool = tool
        self.inputs = inputs
        thumbnail = Self.thumbnail(for: inputs.first)
        if autoload { loadTask = Task { [weak self] in await self?.load() } }
    }

    deinit { loadTask?.cancel() }

    var url: URL? { inputs.first }

    func load() async {
        guard let url else { return }
        do {
            let s = try await MetadataReader.read(url)
            snapshot = s
            edited = Dictionary(uniqueKeysWithValues: s.editableFields.map { ($0.key, $0.value) })
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    var changes: [String: String?] {
        guard let snapshot else { return [:] }
        return MetadataChanges.diff(original: snapshot, edited: edited)
    }

    var options: OptionValues { OptionValues(["fields": .string(MetadataChanges.encode(changes))]) }

    var canSave: Bool { snapshot?.readOnlyReason == nil && !changes.isEmpty }

    var statusLine: String? {
        guard snapshot != nil else { return loadError ?? String(localized: "Reading metadata…") }
        let n = changes.count
        return n == 0 ? String(localized: "No changes yet") : n == 1 ? String(localized: "1 change") : String(localized: "\(n) changes")
    }

    func isChanged(_ key: String) -> Bool { changes.keys.contains(key) }

    func revert() {
        guard let snapshot else { return }
        edited = Dictionary(uniqueKeysWithValues: snapshot.editableFields.map { ($0.key, $0.value) })
    }

    var hasLocation: Bool {
        !(edited["gpsLatitude"] ?? "").isEmpty || !(edited["gpsLongitude"] ?? "").isEmpty
    }

    func removeLocation() {
        edited["gpsLatitude"] = ""
        edited["gpsLongitude"] = ""
    }

    func clearAll() {
        for k in edited.keys { edited[k] = "" }
    }

    func binding(_ key: String) -> Binding<String> {
        Binding(get: { self.edited[key] ?? "" }, set: { self.edited[key] = $0 })
    }

    static func thumbnail(for url: URL?) -> NSImage {
        guard let url else { return NSImage() }
        if let cg = ToolImageSupport.thumbnail(url, maxPixelSize: 320) {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        if url.pathExtension.lowercased() == "pdf", let page = PDFDocument(url: url)?.page(at: 0) {
            return page.thumbnail(of: NSSize(width: 240, height: 240), for: .mediaBox)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct MetadataEditor: View {
    @ObservedObject var model: MetadataEditorModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            MetadataTable(model: model, showOriginal: original)
        }, sidebar: {
            MetadataSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct MetadataTable: View {
    @ObservedObject var model: MetadataEditorModel
    let showOriginal: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if let snapshot = model.snapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
                    if let reason = snapshot.readOnlyReason {
                        Label(reason, systemImage: "lock")
                            .font(.system(size: DesignTokens.TypeRamp.body))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.groups, id: \.name) { group in
                        groupCard(group.name, group.fields)
                    }
                }
                .padding(DesignTokens.Space.xl)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        } else if let error = model.loadError {
            VStack(spacing: DesignTokens.Space.m) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 28)).foregroundStyle(.secondary)
                Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .padding(DesignTokens.Space.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView(String(localized: "Reading metadata…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func groupCard(_ name: String, _ fields: [MetadataField]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            Text(name)
                .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DesignTokens.Space.xs)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.id) { i, field in
                    row(field)
                    if i < fields.count - 1 { Divider().padding(.leading, 140) }
                }
            }
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.4 : 0.08), lineWidth: contrast == .increased ? 1 : 0.5))
        }
    }

    private func row(_ field: MetadataField) -> some View {
        let changed = model.isChanged(field.key) && !showOriginal
        return HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.m) {
            HStack(spacing: 4) {
                Circle().fill(ImageEditorKit.accent).frame(width: 6, height: 6).opacity(changed ? 1 : 0)
                    .accessibilityHidden(true)
                Text(field.label)
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(field.editable ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 128, alignment: .leading)
            if field.editable && !showOriginal && model.snapshot?.readOnlyReason == nil {
                let removed = changed && (model.edited[field.key] ?? "").isEmpty
                TextField(removed ? "" : (field.placeholder ?? ""), text: model.binding(field.key))
                    .textFieldStyle(.plain)
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .overlay(alignment: .leading) {
                        if removed {
                            HStack(spacing: 4) {
                                Text(field.value).strikethrough().foregroundStyle(.secondary).lineLimit(1)
                                Text("Removed").foregroundStyle(ImageEditorKit.danger)
                            }
                            .font(.system(size: DesignTokens.TypeRamp.body))
                            .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(field.label)
                    .accessibilityValue(removed ? String(localized: "Will be removed") : changed ? String(localized: "Changed") : "")
            } else {
                Text(field.value.isEmpty ? "—" : field.value)
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(field.value.isEmpty ? .tertiary : (field.editable ? .primary : .secondary))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !field.editable {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
                        .help(String(localized: "Read-only technical field"))
                        .accessibilityLabel(String(localized: "Read-only"))
                }
            }
        }
        .padding(.horizontal, DesignTokens.Space.m)
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
    }
}

struct MetadataSidebar: View {
    @ObservedObject var model: MetadataEditorModel

    var body: some View {
        VStack(alignment: .center, spacing: DesignTokens.Space.s) {
            Image(nsImage: model.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 120)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .accessibilityHidden(true)
            Text(model.url?.lastPathComponent ?? "")
                .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                .lineLimit(2).multilineTextAlignment(.center).truncationMode(.middle)
            if let size = model.snapshot?.value("file.size") {
                Text(size).font(.system(size: DesignTokens.TypeRamp.caption)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)

        ImageEditorKit.Section(String(localized: "Changes")) {
            // In table order.
            let order = model.snapshot?.fields.map(\.key) ?? []
            let changes = model.changes.sorted { (order.firstIndex(of: $0.key) ?? .max) < (order.firstIndex(of: $1.key) ?? .max) }
            if changes.isEmpty {
                ImageEditorKit.Hint(String(localized: "Edit any field on the left. Clearing a field removes it from the copy."))
            } else {
                ForEach(changes, id: \.key) { key, value in
                    let label = model.snapshot?.fields.first { $0.key == key }?.label ?? key
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                        Text(value.map { "→ \($0)" } ?? String(localized: "Removed"))
                            .font(.system(size: DesignTokens.TypeRamp.caption))
                            .foregroundStyle(value == nil ? ImageEditorKit.danger : .secondary)
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
            }
            HStack {
                Button(String(localized: "Revert")) { model.revert() }
                    .disabled(model.changes.isEmpty)
                Spacer()
            }
        }
        ImageEditorKit.Section(String(localized: "Privacy")) {
            if model.snapshot?.container == .image {
                Button { model.removeLocation() } label: { Label(String(localized: "Remove location"), systemImage: "location.slash") }
                    .disabled(!model.hasLocation)
            }
            Button { model.clearAll() } label: { Label(String(localized: "Clear all editable fields"), systemImage: "eraser") }
                .disabled(model.snapshot == nil)
            ImageEditorKit.Hint(String(localized: "To remove everything, including camera details, use Strip metadata."))
        }
    }
}
