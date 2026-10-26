import Foundation
import os

// Named option sets per target format. The wheel's preset arc, the pinned
// options panel, Settings › Formats, the CLI (`anyfmt presets`) and sync all read
// the same `PresetStore`. AnyfmtCore only: no AppKit here (the CLI links it).

/// A named set of option values for converting to one format.
public struct ConversionPreset: Codable, Hashable, Identifiable, Sendable {
    /// "builtin.gif.small" for built-ins, a UUID string for user presets.
    public var id: String
    /// Target format.
    public var format: FormatID
    /// Short, e.g. "Small · 10 fps · 480 w".
    public var title: String
    /// Only the keys the preset sets; merge onto the schema defaults to apply.
    public var values: OptionValues
    public var isBuiltIn: Bool

    public init(id: String, format: FormatID, title: String, values: OptionValues, isBuiltIn: Bool) {
        self.id = id
        self.format = format
        self.title = title
        self.values = values
        self.isBuiltIn = isBuiltIn
    }
}

/// User presets, hidden built-ins and the last-used options per format,
/// persisted as JSON in `Application Support/<Brand.name>/presets.json`.
///
/// Thread-safe. Writes are atomic; an unreadable file is moved aside and the
/// store starts empty. `onChange` fires (outside the lock) after every change.
public final class PresetStore: @unchecked Sendable {
    public static let shared = PresetStore(fileURL: RecentConversions.defaultDirectory.appendingPathComponent("presets.json"))

    public let fileURL: URL
    private let lock = NSLock()
    private var state: State?
    /// Modification date + size of the file `state` came from. The app and the
    /// `anyfmt` CLI share the file, so a change made by the other process is picked
    /// up on the next read instead of being overwritten.
    private var loadedStamp: FileStamp?
    private var changeHandler: (@Sendable () -> Void)?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Called after any change (local edit or applied sync document).
    public var onChange: (@Sendable () -> Void)? {
        get { lock.withLock { changeHandler } }
        set { lock.withLock { changeHandler = newValue } }
    }

    // MARK: Reading

    /// User presets first (in user order), then the built-ins not hidden.
    public func presets(for format: FormatID) -> [ConversionPreset] {
        lock.withLock {
            let s = loadLocked()
            let hidden = Set(s.hidden)
            return s.user.filter { $0.format == format }
                + Self.builtIns(for: format).filter { !hidden.contains($0.id) }
        }
    }

    public func allUserPresets() -> [ConversionPreset] {
        lock.withLock { loadLocked().user }
    }

    /// Built-ins of `format` the user has hidden.
    public func hiddenBuiltIns(for format: FormatID) -> [ConversionPreset] {
        lock.withLock {
            let hidden = Set(loadLocked().hidden)
            return Self.builtIns(for: format).filter { hidden.contains($0.id) }
        }
    }

    public func lastUsed(for format: FormatID) -> OptionValues? {
        lock.withLock { loadLocked().lastUsed[format.rawValue] }
    }

    // MARK: Editing

    /// Adds a user preset at the end of `format`'s list. Values are validated
    /// against the format's options when the capability table knows it.
    @discardableResult
    public func add(_ title: String, format: FormatID, values: OptionValues) -> ConversionPreset {
        let preset = ConversionPreset(id: UUID().uuidString, format: format, title: Self.cleanTitle(title),
                                      values: Self.validated(values, for: format), isBuiltIn: false)
        mutate { $0.user.append(preset); return true }
        return preset
    }

    /// Renames a user preset. Built-ins keep their titles.
    public func rename(_ id: String, to title: String) {
        let title = Self.cleanTitle(title)
        mutate { s in
            guard let i = s.user.firstIndex(where: { $0.id == id }), s.user[i].title != title else { return false }
            s.user[i].title = title
            return true
        }
    }

    /// Deletes a user preset; a built-in is hidden instead.
    public func delete(_ id: String) {
        mutate { s in
            if let i = s.user.firstIndex(where: { $0.id == id }) {
                s.user.remove(at: i)
                return true
            }
            guard Self.builtIn(id) != nil, !s.hidden.contains(id) else { return false }
            s.hidden.append(id)
            return true
        }
    }

    /// Moves a user preset `offset` places among the user presets of its format
    /// (negative = up). Clamped to the list; built-ins always follow user presets
    /// in their fixed order, so moving one does nothing.
    public func move(_ id: String, by offset: Int) {
        mutate { s in
            guard offset != 0, let preset = s.user.first(where: { $0.id == id }) else { return false }
            let slots = s.user.indices.filter { s.user[$0].format == preset.format }
            guard let at = slots.firstIndex(where: { s.user[$0].id == id }) else { return false }
            let to = min(max(at + offset, 0), slots.count - 1)
            guard to != at else { return false }
            var group = slots.map { s.user[$0] }
            group.insert(group.remove(at: at), at: to)
            for (slot, p) in zip(slots, group) { s.user[slot] = p }
            return true
        }
    }

    /// Shows every built-in of `format` again.
    public func restoreBuiltIns(for format: FormatID) {
        let ids = Set(Self.builtIns(for: format).map(\.id))
        mutate { s in
            let before = s.hidden.count
            s.hidden.removeAll { ids.contains($0) }
            return s.hidden.count != before
        }
    }

    public func recordLastUsed(_ values: OptionValues, for format: FormatID) {
        let values = Self.validated(values, for: format)
        mutate { s in
            guard s.lastUsed[format.rawValue] != values else { return false }
            s.lastUsed[format.rawValue] = values
            return true
        }
    }

    // MARK: Validation

    /// Keeps only keys `schema` declares, with a value of the right type:
    /// numbers clamped to the spec's range, choices only when listed (a number
    /// whose text is a listed choice becomes that choice).
    public static func validated(_ values: OptionValues, against schema: OptionsSchema) -> OptionValues {
        var out = OptionValues()
        for (key, value) in values.values {
            guard let spec = schema.spec(key), let v = coerce(value, to: spec.kind) else { continue }
            out[key] = v
        }
        return out
    }

    private static func coerce(_ value: OptionValue, to kind: OptionKind) -> OptionValue? {
        func number(_ v: OptionValue) -> Double? {
            switch v {
            case .int(let i): Double(i)
            case .double(let d): d.isFinite ? d : nil
            default: nil
            }
        }
        switch kind {
        case .slider(let lo, let hi, _, _), .integer(let lo, let hi, _):
            return number(value).map { .int(min(max(Int($0.rounded()), lo), hi)) }
        case .decimal(let lo, let hi, _):
            return number(value).map { .double(min(max($0, lo), hi)) }
        case .fileSize:
            return number(value).map { .int(max(0, Int($0.rounded()))) }
        case .toggle:
            if case .bool = value { return value }
            return nil
        case .choice(let choices):
            switch value {
            case .bool: return nil
            default: return choices.contains { $0.id == value.description } ? .string(value.description) : nil
            }
        case .text, .pageRange, .timeRange, .color, .rect:
            if case .string = value { return value }
            return nil
        }
    }

    /// Validated against the format's options; unchanged when no row targets it.
    private static func validated(_ values: OptionValues, for format: FormatID) -> OptionValues {
        guard let schema = OptionsSchema.forTarget(format) else { return values }
        return validated(values, against: schema)
    }

    private static func cleanTitle(_ title: String) -> String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? L("Untitled preset") : String(t.prefix(80))
    }

    // MARK: Sync

    /// JSON of the user presets, hidden built-ins and last-used options; nil
    /// while there's nothing the user made.
    public func syncDocument() -> Data? {
        lock.withLock {
            let s = loadLocked()
            guard !s.isEmpty else { return nil }
            return try? Self.encoder.encode(s)
        }
    }

    /// Replaces the local presets with a document from `syncDocument()` (another
    /// Mac). Throws, changing nothing, when the data isn't such a document.
    public func applySyncDocument(_ data: Data) throws {
        var incoming = try JSONDecoder().decode(State.self, from: data)
        incoming.sanitise()
        mutate { s in
            guard s != incoming else { return false }
            s = incoming
            return true
        }
    }

    // MARK: Storage

    struct State: Codable, Equatable {
        var version = 1
        var user: [ConversionPreset] = []
        var hidden: [String] = []
        var lastUsed: [String: OptionValues] = [:]

        var isEmpty: Bool { user.isEmpty && hidden.isEmpty && lastUsed.isEmpty }

        /// Drops what this build can't use: duplicate ids, built-in flags on user
        /// entries, unknown hidden ids; re-validates values.
        mutating func sanitise() {
            var seen = Set<String>()
            user = user.compactMap { p in
                guard !p.id.isEmpty, PresetStore.builtIn(p.id) == nil, seen.insert(p.id).inserted else { return nil }
                var p = p
                p.isBuiltIn = false
                p.title = PresetStore.cleanTitle(p.title)
                p.values = PresetStore.validated(p.values, for: p.format)
                return p
            }
            var seenHidden = Set<String>()
            hidden = hidden.filter { PresetStore.builtIn($0) != nil && seenHidden.insert($0).inserted }
            lastUsed = Dictionary(uniqueKeysWithValues: lastUsed.map { key, values in
                let format = FormatID(key)
                return (format.rawValue, PresetStore.validated(values, for: format))
            })
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
            user = try c.decodeIfPresent([ConversionPreset].self, forKey: .user) ?? []
            hidden = try c.decodeIfPresent([String].self, forKey: .hidden) ?? []
            lastUsed = try c.decodeIfPresent([String: OptionValues].self, forKey: .lastUsed) ?? [:]
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    /// Applies `change` under the lock; saves and notifies when it returns true.
    private func mutate(_ change: (inout State) -> Bool) {
        let handler: (@Sendable () -> Void)? = lock.withLock {
            var s = loadLocked()
            guard change(&s) else { return nil }
            state = s
            saveLocked(s)
            return changeHandler ?? {}
        }
        handler?()
    }

    private struct FileStamp: Equatable {
        let modified: Date?
        let size: Int?
    }

    private func currentStamp() -> FileStamp? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else { return nil }
        return FileStamp(modified: a[.modificationDate] as? Date, size: (a[.size] as? NSNumber)?.intValue)
    }

    private func loadLocked() -> State {
        if let state, currentStamp() == loadedStamp { return state }
        var loaded = State()
        if let data = try? Data(contentsOf: fileURL) {
            do {
                loaded = try JSONDecoder().decode(State.self, from: data)
                loaded.sanitise()
            } catch {
                moveAsideLocked()
                loaded = State()
            }
        }
        state = loaded
        loadedStamp = currentStamp()
        return loaded
    }

    private func saveLocked(_ s: State) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(s).write(to: fileURL, options: .atomic)
            loadedStamp = currentStamp()
        } catch {
            Log.settings.error("presets: could not save \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func moveAsideLocked() {
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        try? FileManager.default.removeItem(at: aside)
        if (try? FileManager.default.moveItem(at: fileURL, to: aside)) == nil {
            try? FileManager.default.removeItem(at: fileURL)
        }
        Log.settings.error("presets: unreadable file moved aside to \(aside.lastPathComponent, privacy: .public)")
    }
}

// MARK: - Built-in presets

extension PresetStore {
    /// Two per format, plain and short. Values use the format's real option keys
    /// (tests check each one validates unchanged against `OptionsSchema.forTarget`).
    public static let allBuiltIns: [ConversionPreset] = {
        func p(_ format: FormatID, _ slug: String, _ title: String, _ values: [String: OptionValue]) -> ConversionPreset {
            ConversionPreset(id: "builtin.\(format.rawValue).\(slug)", format: format, title: title,
                             values: OptionValues(values), isBuiltIn: true)
        }
        var all: [ConversionPreset] = [
            p(Formats.gif, "small", L("Small · 10 fps · 480 w"),
              [OptionKey.gifWidth: .string("480"), OptionKey.fps: .string("10")]),
            p(Formats.gif, "smooth", L("Smooth · 24 fps · 720 w"),
              [OptionKey.gifWidth: .string("720"), OptionKey.fps: .string("24")]),
            p(Formats.jpg, "web", L("Web · 80 %"), [OptionKey.quality: .int(80)]),
            p(Formats.jpg, "best", L("Best · 95 %"), [OptionKey.quality: .int(95)]),
            p(Formats.webp, "web", L("Web · 80 %"), [OptionKey.quality: .int(80), OptionKey.lossless: .bool(false)]),
            p(Formats.webp, "lossless", L("Lossless"), [OptionKey.lossless: .bool(true)]),
            p(Formats.png, "screen", L("Screen · 72 dpi"), [OptionKey.dpi: .string("72")]),
            p(Formats.png, "print", L("Print · 300 dpi"), [OptionKey.dpi: .string("300")]),
        ]
        for f in [Formats.heic, Formats.avif] {
            all += [p(f, "small", L("Small · 60 %"), [OptionKey.quality: .int(60)]),
                    p(f, "best", L("Best · 90 %"), [OptionKey.quality: .int(90)])]
        }
        for f in [Formats.mp4, Formats.mov, Formats.webm] {
            all += [p(f, "small", L("Small · 720p"), [OptionKey.videoQuality: .string("small"), OptionKey.resolution: .string("720")]),
                    p(f, "share", L("Share · 1080p"), [OptionKey.videoQuality: .string("balanced"), OptionKey.resolution: .string("1080")])]
        }
        for f in [Formats.mp3, Formats.m4a] {
            all += [p(f, "voice", L("Voice · 64 kbps mono"), [OptionKey.bitrate: .string("64"), OptionKey.channels: .string("mono")]),
                    p(f, "music", L("Music · 192 kbps"), [OptionKey.bitrate: .string("192")])]
        }
        return all
    }()

    public static func builtIns(for format: FormatID) -> [ConversionPreset] {
        allBuiltIns.filter { $0.format == format }
    }

    static func builtIn(_ id: String) -> ConversionPreset? {
        allBuiltIns.first { $0.id == id }
    }
}
