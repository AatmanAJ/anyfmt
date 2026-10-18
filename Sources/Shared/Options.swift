import Foundation

// Options schema shared by the wheel's options popover, tool editors, the CLI
// (`--opt quality=80`) and the matrix runner. Engines read typed values via
// `OptionValues` accessors and must tolerate missing keys (use the default).

/// A single option value.
public enum OptionValue: Sendable, Hashable, Codable, CustomStringConvertible {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public var description: String {
        switch self {
        case .bool(let b): b ? "true" : "false"
        case .int(let i): String(i)
        case .double(let d): String(d)
        case .string(let s): s
        }
    }

    /// Parses CLI text ("80", "0.5", "true", "h264") against a spec's kind.
    public static func parse(_ text: String, as kind: OptionKind) -> OptionValue? {
        switch kind {
        case .toggle: return ["1", "true", "yes", "on"].contains(text.lowercased()) ? .bool(true)
                         : ["0", "false", "no", "off"].contains(text.lowercased()) ? .bool(false) : nil
        case .slider, .integer, .fileSize: return Int(text).map(OptionValue.int) ?? Double(text).map { .int(Int($0)) }
        case .decimal: return Double(text).map(OptionValue.double)
        case .choice(let choices): return choices.contains { $0.id == text } ? .string(text) : nil
        case .text, .pageRange, .timeRange, .color, .rect: return .string(text)
        }
    }
}

/// One selectable value of a `.choice` option.
public struct OptionChoice: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let label: String
    public init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

/// What kind of control an option needs.
public enum OptionKind: Sendable, Hashable {
    case slider(min: Int, max: Int, step: Int, unit: String?)
    case integer(min: Int, max: Int, unit: String?)
    case decimal(min: Double, max: Double, step: Double)
    case toggle
    case choice([OptionChoice])
    case fileSize                   // bytes; UI shows KB/MB
    case pageRange                  // "1-3,5" or "" for all
    case timeRange                  // "start-end" seconds, e.g. "1.5-9.25"
    case color                      // "#RRGGBB" or "#RRGGBBAA"
    case rect                       // "x,y,w,h" normalised 0...1, origin top-left
    case text
}

/// Declares one option.
public struct OptionSpec: Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    public let kind: OptionKind
    public let defaultValue: OptionValue
    public let help: String?
    /// Only meaningful when another option has a value, e.g. "targetSize" when mode == "size".
    public let visibleWhen: [String: OptionValue]

    public init(_ id: String, _ label: String, _ kind: OptionKind, default value: OptionValue,
                help: String? = nil, visibleWhen: [String: OptionValue] = [:]) {
        self.id = id
        self.label = label
        self.kind = kind
        self.defaultValue = value
        self.help = help
        self.visibleWhen = visibleWhen
    }
}

/// A named list of options. Capabilities and tools reference schemas by id.
public struct OptionsSchema: Sendable, Hashable, Identifiable {
    public let id: String
    public let specs: [OptionSpec]
    public init(_ id: String, _ specs: [OptionSpec]) { self.id = id; self.specs = specs }

    public static let none = OptionsSchema("none", [])

    public var defaults: OptionValues {
        OptionValues(Dictionary(uniqueKeysWithValues: specs.map { ($0.id, $0.defaultValue) }))
    }

    public func spec(_ id: String) -> OptionSpec? { specs.first { $0.id == id } }
}

/// Concrete option values. Missing keys mean "use the schema default".
public struct OptionValues: Sendable, Hashable, Codable {
    public var values: [String: OptionValue]
    public init(_ values: [String: OptionValue] = [:]) { self.values = values }

    public subscript(key: String) -> OptionValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public func int(_ key: String, default d: Int) -> Int {
        switch values[key] {
        case .int(let i): i
        case .double(let x): Int(x)
        case .string(let s): Int(s) ?? d
        default: d
        }
    }

    public func double(_ key: String, default d: Double) -> Double {
        switch values[key] {
        case .double(let x): x
        case .int(let i): Double(i)
        case .string(let s): Double(s) ?? d
        default: d
        }
    }

    public func bool(_ key: String, default d: Bool) -> Bool {
        if case .bool(let b) = values[key] { return b }
        return d
    }

    public func string(_ key: String, default d: String) -> String {
        switch values[key] {
        case .string(let s): s
        case .some(let v): v.description
        case .none: d
        }
    }

    /// Values in `other` win.
    public func merging(_ other: OptionValues) -> OptionValues {
        OptionValues(values.merging(other.values) { _, new in new })
    }
}

// MARK: - Standard schemas

/// Option keys used across engines. Use these constants, never string literals.
public enum OptionKey {
    public static let quality = "quality"           // 1...100
    public static let lossless = "lossless"         // bool
    public static let sizeMode = "sizeMode"         // "quality" | "size" | "percent"
    public static let targetSize = "targetSize"     // bytes
    public static let percent = "percent"           // 1...100
    public static let dpi = "dpi"
    public static let pages = "pages"               // page range
    public static let pageSize = "pageSize"         // "a4" | "letter" | "fit"
    public static let maxDimension = "maxDimension" // px, 0 = keep
    public static let background = "background"     // color for flattening alpha
    public static let bitrate = "bitrate"           // kbps
    public static let sampleRate = "sampleRate"     // Hz, 0 = keep
    public static let channels = "channels"         // "keep" | "mono" | "stereo"
    public static let bitDepth = "bitDepth"         // 16 | 24
    public static let videoCodec = "videoCodec"     // "auto" | "h264" | "hevc" | "av1" | "vp9" | "prores"
    public static let videoQuality = "videoQuality" // "high" | "balanced" | "small"
    public static let resolution = "resolution"     // 0 = keep, else max height
    public static let fps = "fps"                   // 0 = keep
    public static let hardware = "hardware"         // bool: prefer VideoToolbox
    public static let audio = "audio"               // "keep" | "remove"
    public static let gifWidth = "gifWidth"
    public static let compression = "compression"   // archive level 0...9
    public static let timestamps = "timestamps"     // bool, subtitle → txt
    public static let sheet = "sheet"               // "first" | "all"
    public static let cloud = "cloud"               // bool: run as a cloud job (Pro)
}

public enum StandardSchemas {
    public static let imageLossy = OptionsSchema("image.lossy", [
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(85)),
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0),
                   help: L("Longest edge in pixels. 0 keeps the original size.")),
    ])

    public static let imageLosslessCapable = OptionsSchema("image.webp", [
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(85)),
        OptionSpec(OptionKey.lossless, L("Lossless"), .toggle, default: .bool(false)),
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0)),
    ])

    public static let imageLossless = OptionsSchema("image.lossless", [
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0)),
    ])

    public static let imageOpaque = OptionsSchema("image.opaque", [
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(85)),
        OptionSpec(OptionKey.background, L("Background for transparency"), .color, default: .string("#FFFFFF")),
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0)),
    ])

    public static let imageOpaqueLossless = OptionsSchema("image.opaque.lossless", [
        OptionSpec(OptionKey.background, L("Background for transparency"), .color, default: .string("#FFFFFF")),
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0),
                   help: L("Longest edge in pixels. 0 keeps the original size.")),
    ])

    public static let pdfRender = OptionsSchema("pdf.render", [
        OptionSpec(OptionKey.dpi, L("Resolution"), .choice([
            OptionChoice("72", "72 DPI"), OptionChoice("150", "150 DPI"),
            OptionChoice("300", "300 DPI"), OptionChoice("600", "600 DPI"),
        ]), default: .string("300")),
        OptionSpec(OptionKey.pages, L("Pages"), .pageRange, default: .string(""), help: L("Leave empty for all pages, or e.g. 1-3,5")),
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(90)),
    ])

    public static let toPDF = OptionsSchema("to.pdf", [
        OptionSpec(OptionKey.pageSize, L("Page size"), .choice([
            OptionChoice("fit", L("Fit content")), OptionChoice("a4", "A4"), OptionChoice("letter", L("US Letter")),
        ]), default: .string("fit")),
    ])

    public static let documentPDF = OptionsSchema("doc.pdf", [
        OptionSpec(OptionKey.pageSize, L("Page size"), .choice([
            OptionChoice("a4", "A4"), OptionChoice("letter", L("US Letter")),
        ]), default: .string(Locale.current.region?.identifier == "US" ? "letter" : "a4")),
    ])

    public static let audioLossy = OptionsSchema("audio.lossy", [
        OptionSpec(OptionKey.bitrate, L("Bitrate"), .choice([
            OptionChoice("96", "96 kbps"), OptionChoice("128", "128 kbps"), OptionChoice("192", "192 kbps"),
            OptionChoice("256", "256 kbps"), OptionChoice("320", "320 kbps"),
        ]), default: .string("256")),
        OptionSpec(OptionKey.sampleRate, L("Sample rate"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("44100", "44.1 kHz"), OptionChoice("48000", "48 kHz"),
        ]), default: .string("0")),
        OptionSpec(OptionKey.channels, L("Channels"), .choice([
            OptionChoice("keep", L("Keep")), OptionChoice("mono", L("Mono")), OptionChoice("stereo", L("Stereo")),
        ]), default: .string("keep")),
    ])

    public static let audioLossless = OptionsSchema("audio.lossless", [
        OptionSpec(OptionKey.sampleRate, L("Sample rate"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("44100", "44.1 kHz"), OptionChoice("48000", "48 kHz"), OptionChoice("96000", "96 kHz"),
        ]), default: .string("0")),
        OptionSpec(OptionKey.bitDepth, L("Bit depth"), .choice([
            OptionChoice("keep", L("Keep")), OptionChoice("16", "16-bit"), OptionChoice("24", "24-bit"),
        ]), default: .string("keep")),
        OptionSpec(OptionKey.channels, L("Channels"), .choice([
            OptionChoice("keep", L("Keep")), OptionChoice("mono", L("Mono")), OptionChoice("stereo", L("Stereo")),
        ]), default: .string("keep")),
    ])

    public static let video = OptionsSchema("video", [
        OptionSpec(OptionKey.videoQuality, L("Quality"), .choice([
            OptionChoice("high", L("High")), OptionChoice("balanced", L("Balanced")), OptionChoice("small", L("Small file")),
        ]), default: .string("balanced")),
        OptionSpec(OptionKey.resolution, L("Resolution"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("2160", "4K"), OptionChoice("1080", "1080p"),
            OptionChoice("720", "720p"), OptionChoice("480", "480p"),
        ]), default: .string("0")),
        OptionSpec(OptionKey.fps, L("Frame rate"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("60", "60 fps"), OptionChoice("30", "30 fps"), OptionChoice("24", "24 fps"),
        ]), default: .string("0")),
        OptionSpec(OptionKey.hardware, L("Use hardware encoder when faster"), .toggle, default: .bool(true)),
        OptionSpec(OptionKey.audio, L("Audio"), .choice([
            OptionChoice("keep", L("Keep")), OptionChoice("remove", L("Remove")),
        ]), default: .string("keep")),
        OptionSpec(OptionKey.cloud, L("Convert in the cloud (Pro, uploads the file)"), .toggle, default: .bool(false)),
    ])

    public static let gif = OptionsSchema("gif", [
        OptionSpec(OptionKey.gifWidth, L("Width"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("960", "960 px"), OptionChoice("640", "640 px"), OptionChoice("480", "480 px"), OptionChoice("320", "320 px"),
        ]), default: .string("640")),
        OptionSpec(OptionKey.fps, L("Frame rate"), .choice([
            OptionChoice("10", "10 fps"), OptionChoice("15", "15 fps"), OptionChoice("24", "24 fps"), OptionChoice("30", "30 fps"),
        ]), default: .string("15")),
    ])

    public static let archive = OptionsSchema("archive", [
        OptionSpec(OptionKey.compression, L("Compression"), .slider(min: 0, max: 9, step: 1, unit: nil), default: .int(6)),
    ])

    public static let subtitleText = OptionsSchema("subtitle.txt", [
        OptionSpec(OptionKey.timestamps, L("Include timestamps"), .toggle, default: .bool(false)),
    ])

    public static let sheet = OptionsSchema("sheet", [
        OptionSpec(OptionKey.sheet, L("Sheets"), .choice([
            OptionChoice("first", L("First sheet")), OptionChoice("all", L("All sheets (one file each)")),
        ]), default: .string("first")),
    ])

    public static let all: [OptionsSchema] = [
        .none, imageLossy, imageLosslessCapable, imageLossless, imageOpaque, imageOpaqueLossless, pdfRender, toPDF, documentPDF,
        audioLossy, audioLossless, video, gif, archive, subtitleText, sheet,
    ]

    public static func schema(_ id: String) -> OptionsSchema {
        all.first { $0.id == id } ?? .none
    }
}
