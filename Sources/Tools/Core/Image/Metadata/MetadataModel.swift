import Foundation

/// One metadata field as the editor shows it.
public struct MetadataField: Sendable, Hashable, Identifiable {
    /// Stable key. Editable keys are what `ToolSchemas.metadata` "fields" JSON
    /// uses ("title", "artist", "gpsLatitude" …); read-only keys are namespaced
    /// ("exif.FNumber") and only displayed.
    public let key: String
    public let label: String
    /// Namespace / group heading: "IPTC", "EXIF", "GPS", "Tags", "PDF info", "File" …
    public let group: String
    public let value: String
    public let editable: Bool
    /// Hint for the editor's text field.
    public let placeholder: String?

    public init(key: String, label: String, group: String, value: String, editable: Bool, placeholder: String? = nil) {
        self.key = key
        self.label = label
        self.group = group
        self.value = value
        self.editable = editable
        self.placeholder = placeholder
    }

    public var id: String { key }
}

public enum MetadataContainer: String, Sendable {
    case image, media, pdf
}

/// Everything the editor needs about one file's metadata.
public struct MetadataSnapshot: Sendable {
    public let container: MetadataContainer
    public let fields: [MetadataField]
    /// Shown instead of edit controls when the format can't be edited.
    public let readOnlyReason: String?

    public init(container: MetadataContainer, fields: [MetadataField], readOnlyReason: String? = nil) {
        self.container = container
        self.fields = fields
        self.readOnlyReason = readOnlyReason
    }

    public var editableFields: [MetadataField] { fields.filter(\.editable) }

    public func value(_ key: String) -> String? { fields.first { $0.key == key }?.value }

    /// Groups in display order.
    public var groups: [(name: String, fields: [MetadataField])] {
        var order: [String] = []
        var byGroup: [String: [MetadataField]] = [:]
        for f in fields {
            if byGroup[f.group] == nil { order.append(f.group) }
            byGroup[f.group, default: []].append(f)
        }
        return order.map { ($0, byGroup[$0] ?? []) }
    }
}

/// The "fields" option: JSON object of key → string (set) or null (remove).
public enum MetadataChanges {
    public static func parse(_ json: String) throws -> [String: String?] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConversionError.invalidOption("fields")
        }
        var out: [String: String?] = [:]
        for (k, v) in object {
            switch v {
            case is NSNull: out[k] = .some(nil)
            case let s as String: out[k] = s
            case let n as NSNumber: out[k] = n.stringValue
            case let a as [Any]: out[k] = a.map { "\($0)" }.joined(separator: ", ")
            default: throw ConversionError.invalidOption("fields.\(k)")
            }
        }
        return out
    }

    public static func encode(_ changes: [String: String?]) -> String {
        var object: [String: Any] = [:]
        for (k, v) in changes { object[k] = v ?? NSNull() }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Diff of edited values against the original snapshot: changed values are
    /// set, cleared values become null, untouched keys are left out.
    public static func diff(original: MetadataSnapshot, edited: [String: String]) -> [String: String?] {
        var out: [String: String?] = [:]
        for f in original.editableFields {
            let new = (edited[f.key] ?? f.value).trimmingCharacters(in: .whitespacesAndNewlines)
            let old = f.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard new != old else { continue }
            out[f.key] = new.isEmpty ? .some(nil) : new
        }
        return out
    }
}

/// Reads metadata for the editor (tool 23).
public enum MetadataReader {
    public static func read(_ url: URL, locator: EngineLocator = .shared) async throws -> MetadataSnapshot {
        switch MetadataRouting.container(for: url) {
        case .image: try ImageMetadataIO.read(url)
        case .pdf: try PDFMetadataIO.read(url)
        case .media: try await MediaMetadataIO.read(url, ffmpeg: FFmpeg(locator: locator))
        case nil: throw ConversionError.other(L("\(Brand.name) can’t read metadata from this kind of file."), detail: "no metadata container for \(url.pathExtension)")
        }
    }
}

enum MetadataRouting {
    static func container(for url: URL) -> MetadataContainer? {
        guard let f = Formats.detect(url) else { return nil }
        switch Formats.kind(f) {
        case .image: return .image
        case .pdf: return .pdf
        case .audio, .video: return .media
        default: return nil
        }
    }
}

/// Tool 23: write a copy with the "fields" changes applied.
struct EditMetadataRunner: ToolRunner {
    let id = ToolIDs.editMetadata

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        let changes = try MetadataChanges.parse(request.options.string("fields", default: ""))
        let out = ToolOutput(request: request)
        let url: URL
        switch MetadataRouting.container(for: input) {
        case .image: url = try ImageMetadataIO.write(input, changes: changes, output: out)
        case .pdf: url = try PDFMetadataIO.write(input, changes: changes, output: out)
        case .media: url = try await MediaMetadataIO.write(input, changes: changes, output: out, ffmpeg: FFmpeg(locator: context.locator))
        case nil: throw ConversionError.other(L("\(Brand.name) can’t edit metadata in this kind of file."), detail: input.pathExtension)
        }
        context.progress(1)
        return ConversionOutput(url)
    }
}

/// Tool 24: write a copy with all metadata removed (orientation applied,
/// colour profile kept).
struct StripMetadataRunner: ToolRunner {
    let id = ToolIDs.stripMetadata

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        let out = ToolOutput(request: request)
        let url: URL
        switch MetadataRouting.container(for: input) {
        case .image: url = try await ImageMetadataIO.strip(input, output: out, context: context)
        case .pdf: url = try PDFMetadataIO.strip(input, output: out)
        case .media: url = try await MediaMetadataIO.strip(input, output: out, ffmpeg: FFmpeg(locator: context.locator))
        case nil: throw ConversionError.other(L("\(Brand.name) can’t strip metadata from this kind of file."), detail: input.pathExtension)
        }
        context.progress(1)
        return ConversionOutput(url)
    }
}
