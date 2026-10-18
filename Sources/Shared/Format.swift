import Foundation
import UniformTypeIdentifiers

/// Broad family a format belongs to. Drives wheel grouping, glyphs, and the
/// router rule that still formats never reach audio/video except directly.
public enum FileKind: String, Sendable, Codable, CaseIterable, Hashable {
    case image, vector, audio, video, pdf, document, slides, spreadsheet, ebook, subtitle, archive, folder, other

    /// Still kinds may only enter `.audio`/`.video` through a single direct step.
    public var isStill: Bool {
        switch self {
        case .image, .vector, .pdf, .document, .slides, .spreadsheet, .ebook, .subtitle: true
        case .audio, .video, .archive, .folder, .other: false
        }
    }

    public var isTimeBased: Bool { self == .audio || self == .video }

    public var glyph: String {
        switch self {
        case .image: "photo"
        case .vector: "scribble.variable"
        case .audio: "waveform"
        case .video: "film"
        case .pdf: "doc.richtext"
        case .document: "doc.text"
        case .slides: "rectangle.on.rectangle"
        case .spreadsheet: "tablecells"
        case .ebook: "book.closed"
        case .subtitle: "captions.bubble"
        case .archive: "archivebox"
        case .folder: "folder"
        case .other: "doc"
        }
    }
}

/// Stable identifier of a file format, e.g. `"jpg"`. Used as the key in the
/// capability table, settings, the CLI (`halo convert in.heic --to jpg`) and tests.
public struct FormatID: RawRepresentable, Hashable, Sendable, Codable, Comparable,
                        ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.lowercased() }
    public init(_ raw: String) { self.init(rawValue: raw) }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    public var description: String { rawValue }
    public static func < (a: FormatID, b: FormatID) -> Bool { a.rawValue < b.rawValue }
}

/// A file format we can read and/or write.
public struct Format: Sendable, Hashable, Identifiable {
    public let id: FormatID
    public let kind: FileKind
    /// Short label shown on wheel segments, e.g. "JPG".
    public let label: String
    /// Human name, e.g. "JPEG image".
    public let name: String
    /// File extensions, primary first, lowercase, without dot.
    public let extensions: [String]
    /// Uniform type identifiers this format answers to, primary first.
    public let typeIdentifiers: [String]
    /// SF Symbol for the segment glyph (falls back to the kind glyph).
    public let glyph: String
    /// Order inside its kind on the wheel (lower first).
    public let order: Int
    /// A package/folder on disk (rtfd, pages, key, numbers) rather than a flat file.
    public let isPackage: Bool

    public init(_ id: FormatID, kind: FileKind, label: String, name: String,
                extensions: [String], types: [String], glyph: String? = nil,
                order: Int = 100, isPackage: Bool = false) {
        self.id = id
        self.kind = kind
        self.label = label
        self.name = name
        self.extensions = extensions
        self.typeIdentifiers = types
        self.glyph = glyph ?? kind.glyph
        self.order = order
        self.isPackage = isPackage
    }

    public var primaryExtension: String { extensions.first ?? id.rawValue }

    public var utType: UTType? {
        for t in typeIdentifiers { if let u = UTType(t) { return u } }
        return UTType(filenameExtension: primaryExtension)
    }
}
