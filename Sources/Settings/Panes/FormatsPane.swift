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
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("", text: $search, prompt: Text("Search formats"))
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("formats.search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Clear search"))
                    }
                }
                .font(.system(size: DesignTokens.TypeRamp.body))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
                .padding(.horizontal, DesignTokens.Space.m)
                .padding(.top, DesignTokens.Space.m)
                .padding(.bottom, DesignTokens.Space.s)

                List(selection: $selection) {
                    if search.isEmpty {
                        Section {
                            if settings.favouriteFormats.isEmpty {
                                Text("Star a format to pin it to the start of the ring.")
                                    .font(.system(size: DesignTokens.TypeRamp.label))
                                    .foregroundStyle(.secondary)
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
            .frame(width: 272)

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
            Spacer(minLength: 4)
            if hidden {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.tertiary)
                    .help(Text("Hidden from the wheel"))
            }
            Button {
                if favourite { settings.favouriteFormats.removeAll { $0 == format.id } }
                else { settings.favouriteFormats.append(format.id) }
            } label: {
                Image(systemName: favourite ? "star.fill" : "star")
                    .foregroundStyle(favourite ? Color.iris : Color.secondary.opacity(0.6))
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

    var body: some View {
        Form {
            Section {
                HStack(spacing: DesignTokens.Space.m) {
                    Image(systemName: format.glyph)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(FormatChip.tint(for: format.kind).gradient))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: format.name)
                            .font(.system(size: DesignTokens.TypeRamp.title, weight: .semibold))
                        Text(verbatim: "\(format.kind.sectionTitle) · " + format.extensions.prefix(4).map { ".\($0)" }.joined(separator: " "))
                            .font(.system(size: DesignTokens.TypeRamp.label))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    FormatChip(label: format.label, kind: format.kind, size: 12)
                }
                .padding(.vertical, 2)

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
                        .foregroundStyle(.secondary)
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
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.iris)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(verbatim: tool.title)
                                        Text(tool.needsEditor ? "Opens an editor with a live preview" : "Runs straight away with your defaults")
                                            .font(.system(size: DesignTokens.TypeRamp.label))
                                            .foregroundStyle(.secondary)
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

    /// Options schema for converting *to* `format`, minus per-job choices that
    /// don't belong in a saved default (running in the cloud).
    func defaultsSchema(for format: FormatID) -> OptionsSchema {
        let rows = router.table.rows
        let schema: OptionsSchema
        if rows.isEmpty {
            schema = FormatSchemaFallback.schema(for: format)
        } else {
            schema = rows.filter { $0.to == format }
                .sorted { $0.priority > $1.priority }
                .map(\.schema)
                .first { !$0.specs.isEmpty } ?? .none
        }
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
