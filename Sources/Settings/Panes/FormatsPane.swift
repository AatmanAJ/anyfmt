import AppKit
import SwiftUI
import HaloCore

struct FormatsPane: View {
    @ObservedObject var model: SettingsModel

    enum Tab: Hashable { case formats, tools }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $model.formatsTab) {
                Text("Formats").tag(Tab.formats)
                Text("Tools").tag(Tab.tools)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .padding(.vertical, DesignTokens.Space.m)
            .accessibilityIdentifier("formats.tab")
            Divider()
            switch model.formatsTab {
            case .formats: FormatsBrowser(model: model, settings: model.settings)
            case .tools: ToolsList(settings: model.settings)
            }
        }
    }
}

// MARK: - Formats

private enum SidebarItem: Hashable {
    case favourite(FormatID)
    case format(FormatID)

    var format: FormatID {
        switch self {
        case .favourite(let f), .format(let f): f
        }
    }
}

private struct FormatsBrowser: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var settings: AppSettings
    @State private var selection: SidebarItem?
    @State private var search = ""

    var body: some View {
        let catalog = model.formatCatalog
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.Space.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.haloSecondaryText)
                        .accessibilityHidden(true)
                    TextField("", text: $search, prompt: Text("Search formats"))
                        .textFieldStyle(.plain)
                        .accessibilityLabel(Text("Search formats"))
                        .accessibilityIdentifier("formats.search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.haloSecondaryText)
                            .accessibilityLabel(Text("Clear search"))
                    }
                }
                .font(.system(size: DesignTokens.TypeRamp.body))
                .padding(.horizontal, DesignTokens.Space.m)
                .frame(minHeight: DesignTokens.Component.Settings.searchHeight)
                .background(Capsule().fill(Color.token(DesignTokens.Component.Settings.chipFill)))
                .padding(.horizontal, DesignTokens.Space.m)
                .padding(.top, DesignTokens.Space.m)
                .padding(.bottom, DesignTokens.Space.s)

                List(selection: $selection) {
                    if !search.isEmpty && groups(catalog).isEmpty {
                        SettingsStateRow(kind: .empty,
                                         title: String(localized: "No formats match “\(search)”"),
                                         detail: String(localized: "Try a file extension such as heic or mp4."))
                            .listRowSeparator(.hidden)
                            .accessibilityIdentifier("formats.noResults")
                    }
                    if search.isEmpty {
                        Section {
                            if settings.favouriteFormats.isEmpty {
                                Text("Star a format to pin it to the start of the ring.")
                                    .font(.system(size: DesignTokens.TypeRamp.label))
                                    .foregroundStyle(Color.haloSecondaryText)
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(settings.favouriteFormats, id: \.self) { id in
                                if let f = Formats.format(id) {
                                    FormatSidebarRow(format: f, settings: settings, showsGrip: true)
                                        .tag(SidebarItem.favourite(id))
                                        .listRowSeparator(.hidden)
                                        .contextMenu { favouriteMenu(id) }
                                }
                            }
                            .onMove { from, to in settings.favouriteFormats.move(fromOffsets: from, toOffset: to) }
                        } header: {
                            Text("Favourites")
                        }
                    }
                    ForEach(groups(catalog), id: \.kind) { group in
                        Section {
                            ForEach(group.formats) { f in
                                FormatSidebarRow(format: f, settings: settings, showsGrip: false)
                                    .tag(SidebarItem.format(f.id))
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text(verbatim: group.kind.sectionTitle)
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("formats.list")
            }
            .frame(width: DesignTokens.Component.Settings.sidebarWidth)

            Divider()

            if let id = selection?.format ?? catalog.first?.id, let format = Formats.format(id) {
                FormatDetail(format: format, schema: model.defaultsSchema(for: id), settings: settings)
                    .id(id)
            } else {
                Spacer()
            }
        }
        .onAppear {
            if selection == nil {
                selection = settings.favouriteFormats.first.map(SidebarItem.favourite)
                    ?? catalog.first.map { SidebarItem.format($0.id) }
            }
        }
    }

    @ViewBuilder private func favouriteMenu(_ id: FormatID) -> some View {
        let favs = settings.favouriteFormats
        let i = favs.firstIndex(of: id) ?? 0
        Button("Move Up") { settings.favouriteFormats.move(fromOffsets: [i], toOffset: i - 1) }
            .disabled(i == 0)
        Button("Move Down") { settings.favouriteFormats.move(fromOffsets: [i], toOffset: i + 2) }
            .disabled(i >= favs.count - 1)
        Divider()
        Button("Remove from Favourites") { settings.favouriteFormats.removeAll { $0 == id } }
    }

    private struct Group { let kind: FileKind; let formats: [Format] }

    private func groups(_ catalog: [Format]) -> [Group] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = catalog.filter { f in
            q.isEmpty || f.label.lowercased().contains(q) || f.name.lowercased().contains(q)
                || f.extensions.contains { $0.hasPrefix(q.trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
        }
        return FileKind.allCases.compactMap { kind in
            let fs = matching.filter { $0.kind == kind }.sorted { $0.order < $1.order }
            return fs.isEmpty ? nil : Group(kind: kind, formats: fs)
        }
    }
}

private struct FormatSidebarRow: View {
    let format: Format
    @ObservedObject var settings: AppSettings
    let showsGrip: Bool

    var body: some View {
        let hidden = settings.hiddenFormats.contains(format.id)
        let favourite = settings.favouriteFormats.contains(format.id)
        HStack(spacing: DesignTokens.Space.s) {
            FormatChip(label: format.label, kind: format.kind, size: 9.5)
                .frame(width: 46, alignment: .leading)
                .opacity(hidden ? 0.45 : 1)
            Text(verbatim: format.name)
                .lineLimit(1)
                .foregroundStyle(hidden ? .secondary : .primary)
            Spacer(minLength: DesignTokens.Space.xs)
            if hidden {
                Image(systemName: "eye.slash")
                    .foregroundStyle(Color.haloSecondaryText)
                    .help(Text("Hidden from the wheel"))
                    .accessibilityLabel(Text("Hidden from the wheel"))
            }
            Button {
                if favourite { settings.favouriteFormats.removeAll { $0 == format.id } }
                else { settings.favouriteFormats.append(format.id) }
            } label: {
                Image(systemName: favourite ? "star.fill" : "star")
                    .foregroundStyle(favourite ? Color.accentText : Color.haloSecondaryText)
            }
            .buttonStyle(.plain)
            .help(favourite ? Text("Remove from Favourites") : Text("Add to Favourites"))
            .accessibilityLabel(favourite ? Text("Remove \(format.label) from Favourites") : Text("Add \(format.label) to Favourites"))
        }
        .font(.system(size: DesignTokens.TypeRamp.body))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(format.label), \(format.name)"))
    }
}

private struct FormatDetail: View {
    let format: Format
    let schema: OptionsSchema
    @ObservedObject var settings: AppSettings
    @StateObject private var presets: FormatPresetsModel

    init(format: Format, schema: OptionsSchema, settings: AppSettings) {
        self.format = format
        self.schema = schema
        self.settings = settings
        _presets = StateObject(wrappedValue: FormatPresetsModel(format: format.id, schema: schema))
    }

    var body: some View {
        Form {
            Section {
                // Editorial header, like the options panel: the format name
                // set huge, the plain description underneath.
                HStack(alignment: .lastTextBaseline, spacing: DesignTokens.Space.m) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        DisplayText(format.label, size: DesignTokens.Component.Settings.formatTitleSize)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel(Text(verbatim: "\(format.label), \(format.name)"))
                        Text(verbatim: format.name)
                            .font(.system(size: DesignTokens.TypeRamp.title, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DesignTokens.Space.xs) {
                        FormatChip(label: format.kind.sectionTitle, kind: format.kind)
                        Text(verbatim: format.extensions.prefix(4).map { ".\($0)" }.joined(separator: " "))
                            .font(.system(size: DesignTokens.TypeRamp.label).monospaced())
                            .foregroundStyle(Color.haloSecondaryText)
                    }
                }
                .padding(.vertical, DesignTokens.Space.xs)

                Toggle(isOn: Binding(get: { !settings.hiddenFormats.contains(format.id) }, set: { on in
                    if on { settings.hiddenFormats.remove(format.id) } else { settings.hiddenFormats.insert(format.id) }
                })) {
                    Text("Show on the wheel")
                    Text("Hidden formats stay available from the command line.")
                }
                .accessibilityIdentifier("formats.showOnWheel")
                if OptInTargets.contains(format.id) && !settings.hiddenFormats.contains(format.id) {
                    Toggle(isOn: Binding(get: { settings.shownFormats.contains(format.id) }, set: { on in
                        if on { settings.shownFormats.insert(format.id) } else { settings.shownFormats.remove(format.id) }
                    })) {
                        Text("Also offer it for other kinds of files")
                        Text("For example a photo → \(format.label) through PDF and text recognition. Off by default to keep the wheel focused.")
                    }
                    .accessibilityIdentifier("formats.showOptIn")
                }
                Toggle(isOn: Binding(get: { settings.favouriteFormats.contains(format.id) }, set: { on in
                    if on { if !settings.favouriteFormats.contains(format.id) { settings.favouriteFormats.append(format.id) } }
                    else { settings.favouriteFormats.removeAll { $0 == format.id } }
                })) {
                    Text("Favourite")
                    Text("Favourites sit first on the ring, in the order of the Favourites list.")
                }
                .accessibilityIdentifier("formats.favourite")
            }

            Section {
                if schema.specs.isEmpty {
                    Text("Nothing to set: converting to \(format.label) has no options.")
                        .foregroundStyle(Color.haloSecondaryText)
                } else {
                    OptionsForm(schema: schema, values: valuesBinding)
                }
            } header: {
                HStack {
                    Text("Defaults for converting to \(format.label)")
                    Spacer()
                    if !schema.specs.isEmpty {
                        Button("Restore Defaults") { settings.formatDefaults[format.id] = nil }
                            .controlSize(.small)
                            .disabled(settings.formatDefaults[format.id] == nil)
                            .accessibilityIdentifier("formats.restoreDefaults")
                    }
                }
            } footer: {
                if !schema.specs.isEmpty {
                    FootnoteText(text: String(localized: "Used every time. You can still change them for one file in the wheel’s options."))
                }
            }

            if !schema.specs.isEmpty {
                PresetsSection(format: format, model: presets, settings: settings, currentValues: valuesBinding.wrappedValue)
            }
        }
        .formStyle(.grouped)
    }

    /// Shows defaults merged with what's stored; stores only what differs.
    private var valuesBinding: Binding<OptionValues> {
        Binding(
            get: { schema.defaults.merging(settings.formatDefaults[format.id] ?? OptionValues()) },
            set: { new in
                let diff = OptionsFormLogic.nonDefault(new, schema: schema)
                settings.formatDefaults[format.id] = diff.values.isEmpty ? nil : diff
            }
        )
    }
}

// MARK: - Presets

private struct PresetsSection: View {
    let format: Format
    @ObservedObject var model: FormatPresetsModel
    @ObservedObject var settings: AppSettings
    let currentValues: OptionValues

    var body: some View {
        Section {
            if model.presets.isEmpty {
                Text("No presets for \(format.label) yet.")
                    .foregroundStyle(Color.haloSecondaryText)
            }
            ForEach(model.presets) { preset in
                PresetRow(preset: preset, model: model) {
                    let diff = OptionsFormLogic.nonDefault(model.schema.defaults.merging(preset.values), schema: model.schema)
                    settings.formatDefaults[format.id] = diff.values.isEmpty ? nil : diff
                }
            }
            HStack {
                Button("Save Current Defaults as Preset") { model.saveAsPreset(currentValues) }
                    .buttonStyle(.haloSecondary)
                    .accessibilityIdentifier("formats.presets.save")
                Spacer()
            }
        } header: {
            HStack {
                Text("Presets")
                Spacer()
                Button("Restore Built-in Presets") { model.restoreBuiltIns() }
                    .controlSize(.small)
                    .disabled(!model.hasHiddenBuiltIns)
                    .accessibilityIdentifier("formats.presets.restore")
            }
        } footer: {
            FootnoteText(text: String(localized: "Presets show next to \(format.label) on the wheel. Click a name to rename it."))
        }
    }
}

private struct PresetRow: View {
    let preset: ConversionPreset
    @ObservedObject var model: FormatPresetsModel
    let useAsDefaults: () -> Void
    @State private var title = ""
    @FocusState private var editing: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                if preset.isBuiltIn {
                    Text(verbatim: preset.title)
                } else {
                    TextField("", text: $title, prompt: Text("Preset name"))
                        .textFieldStyle(.plain)
                        .focused($editing)
                        .onSubmit(commit)
                        .onChange(of: editing) { focused in if !focused { commit() } }
                        .accessibilityLabel(Text("Preset name"))
                        .accessibilityIdentifier("formats.presets.name")
                }
                let summary = model.summary(of: preset)
                if !summary.isEmpty {
                    Text(verbatim: summary)
                        .font(.system(size: DesignTokens.TypeRamp.label))
                        .foregroundStyle(Color.haloSecondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DesignTokens.Space.s)
            if preset.isBuiltIn {
                Text("Built-in")
                    .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                    .foregroundStyle(Color.haloSecondaryText)
                    .padding(.horizontal, DesignTokens.Space.s)
                    .padding(.vertical, DesignTokens.Space.xxs)
                    .background(Capsule().fill(Color.token(DesignTokens.Component.Settings.chipFill)))
            }
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text("Actions for \(preset.title)"))
        }
        .font(.system(size: DesignTokens.TypeRamp.body))
        .contextMenu { menuItems }
        .onAppear { title = preset.title }
        .onChange(of: preset.title) { new in if !editing { title = new } }
    }

    @ViewBuilder private var menuItems: some View {
        Button("Use as Defaults", action: useAsDefaults)
        Divider()
        Button("Move Up") { model.move(preset.id, by: -1) }
            .disabled(!model.canMove(preset.id, by: -1))
        Button("Move Down") { model.move(preset.id, by: 1) }
            .disabled(!model.canMove(preset.id, by: 1))
        Divider()
        if preset.isBuiltIn {
            Button("Hide Built-in Preset") { model.delete(preset.id) }
        } else {
            Button("Delete Preset") { model.delete(preset.id) }
        }
    }

    private func commit() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { title = preset.title; return }
        if t != preset.title { model.rename(preset.id, to: t) }
    }
}

/// The Presets section's state for one format. Reads and writes `PresetStore`
/// and refreshes after its own edits (the store's single `onChange` slot is
/// left to sync).
@MainActor
final class FormatPresetsModel: ObservableObject {
    let format: FormatID
    let schema: OptionsSchema
    let store: PresetStore
    @Published private(set) var presets: [ConversionPreset] = []
    @Published private(set) var hasHiddenBuiltIns = false

    init(format: FormatID, schema: OptionsSchema, store: PresetStore = .shared) {
        self.format = format
        self.schema = schema
        self.store = store
        reload()
    }

    func reload() {
        presets = store.presets(for: format)
        hasHiddenBuiltIns = !store.hiddenBuiltIns(for: format).isEmpty
    }

    func rename(_ id: String, to title: String) { store.rename(id, to: title); reload() }
    func delete(_ id: String) { store.delete(id); reload() }
    func restoreBuiltIns() { store.restoreBuiltIns(for: format); reload() }

    func move(_ id: String, by offset: Int) {
        guard canMove(id, by: offset) else { return }
        store.move(id, by: offset)
        reload()
    }

    /// Only user presets move, and only among themselves (built-ins follow).
    func canMove(_ id: String, by offset: Int) -> Bool {
        let user = presets.filter { !$0.isBuiltIn }
        guard let i = user.firstIndex(where: { $0.id == id }) else { return false }
        return user.indices.contains(i + offset)
    }

    /// Saves `values` (the defaults as shown: schema defaults plus the user's
    /// changes) as a new preset named "Preset N".
    @discardableResult
    func saveAsPreset(_ values: OptionValues) -> ConversionPreset {
        let taken = Set(presets.map(\.title))
        var n = presets.filter { !$0.isBuiltIn }.count + 1
        while taken.contains(Self.untitled(n)) { n += 1 }
        let preset = store.add(Self.untitled(n), format: format, values: PresetStore.validated(values, against: schema))
        reload()
        return preset
    }

    static func untitled(_ n: Int) -> String { String(localized: "Preset \(n)") }

    /// "480 px · 10 fps · Dither off": the preset's values in schema order,
    /// choices by their labels.
    func summary(of preset: ConversionPreset) -> String {
        schema.specs.compactMap { spec -> String? in
            guard let v = preset.values[spec.id] else { return nil }
            switch spec.kind {
            case .choice(let choices):
                return choices.first { $0.id == v.description }.map(\.label)
            case .toggle:
                guard case .bool(let on) = v else { return nil }
                return on ? spec.label : String(localized: "\(spec.label) off")
            case .slider(_, _, _, let unit), .integer(_, _, let unit):
                return "\(spec.label) \(v.description)" + (unit.map { $0 == "%" ? " %" : " \($0)" } ?? "")
            default:
                return "\(spec.label) \(v.description)"
            }
        }
        .joined(separator: " · ")
    }
}

// MARK: - Tools

private struct ToolsList: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            ForEach(ToolGroup.allCases) { group in
                let tools = ToolCatalog.local.filter { group.contains($0.id) }
                if !tools.isEmpty {
                    Section {
                        ForEach(tools) { tool in
                            Toggle(isOn: Binding(get: { !settings.hiddenTools.contains(tool.id) }, set: { on in
                                if on { settings.hiddenTools.remove(tool.id) } else { settings.hiddenTools.insert(tool.id) }
                            })) {
                                HStack(spacing: DesignTokens.Space.m) {
                                    Image(systemName: tool.glyph)
                                        .font(.system(size: DesignTokens.TypeRamp.title, weight: .medium))
                                        .foregroundStyle(Color.accentText)
                                        .frame(width: DesignTokens.Component.Settings.rowIconWidth)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                                        Text(verbatim: tool.title)
                                        Text(tool.needsEditor ? "Opens an editor with a live preview" : "Runs straight away with your defaults")
                                            .font(.system(size: DesignTokens.TypeRamp.label))
                                            .foregroundStyle(Color.haloSecondaryText)
                                    }
                                }
                            }
                            .accessibilityIdentifier("tools.show.\(tool.id.rawValue)")
                        }
                    } header: {
                        Text(verbatim: group.title)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Tool groups follow the id prefix ("image.compress" → Images).
enum ToolGroup: String, CaseIterable, Identifiable {
    case image, video, audio, meta, pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: String(localized: "Images")
        case .video: String(localized: "Video")
        case .audio: String(localized: "Audio")
        case .meta: String(localized: "Metadata")
        case .pdf: String(localized: "PDF")
        }
    }

    func contains(_ id: ToolID) -> Bool { id.rawValue.hasPrefix(rawValue + ".") }
}

// MARK: - Model support

extension SettingsModel {
    /// Formats the Formats pane lists: every conversion target the router
    /// knows, or the whole catalogue while no engine rows exist yet.
    var formatCatalog: [Format] {
        let rows = router.table.rows
        guard !rows.isEmpty else { return Formats.all }
        let targets = Set(rows.map(\.to))
        return Formats.all.filter { targets.contains($0.id) }
    }

    /// Options schema for converting *to* `format` (`OptionsSchema.forTarget`),
    /// minus per-job choices that don't belong in a saved default (running in
    /// the cloud, page ranges).
    func defaultsSchema(for format: FormatID) -> OptionsSchema {
        guard router.table.rows.isEmpty else { return OptionsSchema.forTarget(format, table: router.table) ?? .none }
        let schema = FormatSchemaFallback.schema(for: format)
        return OptionsSchema(schema.id, schema.specs.filter { $0.id != OptionKey.cloud })
    }
}

/// Standard schemas by target, used only while the capability table is empty
/// (engine lanes not merged yet). Once rows exist, their schemas win.
enum FormatSchemaFallback {
    static func schema(for f: FormatID) -> OptionsSchema {
        switch f {
        case Formats.jpg: StandardSchemas.imageOpaque
        case Formats.heic, Formats.heif, Formats.avif, Formats.jxl, Formats.jp2: StandardSchemas.imageLossy
        case Formats.webp: StandardSchemas.imageLosslessCapable
        case Formats.png, Formats.tiff, Formats.bmp, Formats.tga, Formats.ico, Formats.icns, Formats.psd, Formats.exr:
            StandardSchemas.imageLossless
        case Formats.gif: StandardSchemas.gif
        case Formats.pdf: StandardSchemas.toPDF
        case Formats.mp3, Formats.m4a, Formats.ogg, Formats.opus, Formats.wma: StandardSchemas.audioLossy
        case Formats.wav, Formats.flac, Formats.aiff, Formats.caf: StandardSchemas.audioLossless
        case Formats.mp4, Formats.mov, Formats.mkv, Formats.webm, Formats.avi, Formats.wmv, Formats.m4v: StandardSchemas.video
        case Formats.zip, Formats.tar, Formats.gz, Formats.sevenZip: StandardSchemas.archive
        case Formats.csv, Formats.tsv, Formats.json: StandardSchemas.sheet
        default: .none
        }
    }
}

/// Target formats that some input reaches only through an opt-in route.
@MainActor
enum OptInTargets {
    private static var cache: Set<FormatID>?

    static func contains(_ format: FormatID) -> Bool {
        if let cache { return cache.contains(format) }
        let router = Router.live()
        var set = Set<FormatID>()
        for from in Set(router.table.rows.map(\.from)) {
            for (to, route) in router.allRoutes(from: from) where !route.isShownByDefault { set.insert(to) }
        }
        cache = set
        return set.contains(format)
    }
}
