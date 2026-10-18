import Foundation

/// Identifies a conversion engine implementation.
public struct EngineID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public enum EngineIDs {
    // Apple frameworks (zero size cost)
    public static let imageIO: EngineID = "imageio"
    public static let pdfKit: EngineID = "pdfkit"
    public static let avFoundation: EngineID = "avfoundation"
    public static let attributedText: EngineID = "attributedtext"   // NSAttributedString docx/odt/rtf/rtfd/html/txt/doc
    public static let webKitPDF: EngineID = "webkitpdf"             // HTML → paginated PDF
    public static let quickLook: EngineID = "quicklook"             // Office/iWork → HTML preview
    public static let archiveTool: EngineID = "bsdtar"              // /usr/bin/bsdtar + ditto
    // Bundled engines
    public static let ffmpeg: EngineID = "ffmpeg"
    public static let ffmpegImage: EngineID = "ffmpeg-image"        // WebP/AVIF stills when ImageIO can't encode
    public static let resvg: EngineID = "resvg"
    // Our own Swift code
    public static let markdown: EngineID = "markdown"
    public static let epub: EngineID = "epub"
    public static let subtitles: EngineID = "subtitles"
    public static let sheets: EngineID = "sheets"
    public static let ooxmlWriter: EngineID = "ooxml"               // PDF → PPTX/XLSX/DOCX writers
    public static let textClipping: EngineID = "textclipping"
    // Opt-in / optional
    public static let pagesAppleEvents: EngineID = "pages-ae"
    public static let officePack: EngineID = "officepack"           // LibreOffice, user-downloaded
    public static let pandocPack: EngineID = "pandocpack"           // pandoc, user-downloaded
}

/// How a capability treats multiple inputs.
public enum Arity: Sendable, Hashable {
    /// One output per input; multi-file drags run it per file.
    case perFile
    /// All inputs become one output (folder/multi → archive).
    case combine
}

public struct CapabilityFlags: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Output preserves all information (PNG→TIFF). Router prefers these for intermediates.
    public static let lossless = CapabilityFlags(rawValue: 1 << 0)
    /// May produce several files (PDF pages → PNGs). Only allowed as the final hop.
    public static let multiOutput = CapabilityFlags(rawValue: 1 << 1)
    /// Only offered when an optional pack is installed (Office pack, pandoc pack).
    public static let needsPack = CapabilityFlags(rawValue: 1 << 2)
    /// Requires the user to opt in (Apple Events to Pages/Finder).
    public static let optIn = CapabilityFlags(rawValue: 1 << 3)
    /// Never used as an intermediate hop (e.g. lossy text extraction).
    public static let terminalOnly = CapabilityFlags(rawValue: 1 << 4)
    /// Drops structure (PDF → TXT). Shown, but routes through it are penalised.
    public static let lossyStructure = CapabilityFlags(rawValue: 1 << 5)
    /// Not offered on the wheel by default (still in the CLI and matrix).
    public static let hiddenByDefault = CapabilityFlags(rawValue: 1 << 6)
}

/// One row of the capability table: "engine E converts A to B".
public struct Capability: Sendable, Hashable, CustomStringConvertible {
    public let from: FormatID
    public let to: FormatID
    public let engine: EngineID
    public let schema: OptionsSchema
    /// Higher wins when two rows cover the same pair. Native/hardware paths ≥ 100,
    /// bundled CLI engines 50–99, fallbacks < 50.
    public let priority: Int
    /// Relative routing cost (≈ seconds of work for a typical file). Default 1.
    public let cost: Double
    public let arity: Arity
    public let flags: CapabilityFlags
    /// Minimum macOS major version this row needs (e.g. ImageIO AVIF encode).
    public let minimumOS: Int

    public init(_ from: FormatID, _ to: FormatID, _ engine: EngineID, schema: OptionsSchema = .none,
                priority: Int = 100, cost: Double = 1, arity: Arity = .perFile,
                flags: CapabilityFlags = [], minimumOS: Int = 13) {
        self.from = from
        self.to = to
        self.engine = engine
        self.schema = schema
        self.priority = priority
        self.cost = cost
        self.arity = arity
        self.flags = flags
        self.minimumOS = minimumOS
    }

    public var description: String { "\(from)→\(to) [\(engine) p\(priority)]" }
}

/// Builder helpers so lane route files read as a table.
public extension Capability {
    /// Rows for every `from` × every `to` (skipping identity) with shared settings.
    static func grid(_ froms: [FormatID], _ tos: [FormatID], _ engine: EngineID, schema: (FormatID) -> OptionsSchema = { _ in .none },
                     priority: Int = 100, cost: Double = 1, flags: CapabilityFlags = [], minimumOS: Int = 13) -> [Capability] {
        froms.flatMap { f in
            tos.filter { $0 != f }.map { t in
                Capability(f, t, engine, schema: schema(t), priority: priority, cost: cost, flags: flags, minimumOS: minimumOS)
            }
        }
    }
}
