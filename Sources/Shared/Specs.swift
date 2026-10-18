import Foundation

// Tool and action declarations (pure data). The wheel, the CLI and tests read
// these catalogues. Implementations live in Sources/Tools and Sources/Actions
// and are looked up by id.

public struct ToolID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public struct ActionID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

/// How many inputs a tool takes.
public enum ToolArity: Sendable, Hashable {
    /// Runs once per input file (batches naturally).
    case perFile
    /// Consumes all inputs together (collage, join, images → PDF, merge PDFs).
    case combine(minimum: Int)
}

public struct ToolSpec: Sendable, Hashable, Identifiable {
    public let id: ToolID
    public let title: String
    public let glyph: String
    /// Kinds this tool applies to. Empty = any file.
    public let kinds: Set<FileKind>
    /// Narrower filter by format, if needed (e.g. PDF tools). Empty = any format of `kinds`.
    public let formats: Set<FormatID>
    public let arity: ToolArity
    /// Opens a focused editor window instead of running instantly.
    public let needsEditor: Bool
    public let schema: OptionsSchema
    /// Appended to output names: "photo-compressed.jpg".
    public let outputSuffix: String
    /// Non-nil for Pro tools that run on our servers. Never set for local tools.
    public let cloudFeature: CloudFeature?

    public init(_ id: ToolID, _ title: String, glyph: String, kinds: Set<FileKind>, formats: Set<FormatID> = [],
                arity: ToolArity = .perFile, needsEditor: Bool, schema: OptionsSchema = .none,
                suffix: String, cloud: CloudFeature? = nil) {
        self.id = id
        self.title = title
        self.glyph = glyph
        self.kinds = kinds
        self.formats = formats
        self.arity = arity
        self.needsEditor = needsEditor
        self.schema = schema
        self.outputSuffix = suffix
        self.cloudFeature = cloud
    }

    public var defaultOptions: OptionValues { schema.defaults }

    public func applies(to format: FormatID) -> Bool {
        let kind = Formats.kind(format)
        if !formats.isEmpty { return formats.contains(format) }
        return kinds.isEmpty || kinds.contains(kind)
    }

    /// True when every input qualifies and the arity is satisfied.
    public func applies(to inputs: [FormatID]) -> Bool {
        guard !inputs.isEmpty, inputs.allSatisfy(applies(to:)) else { return false }
        if case .combine(let minimum) = arity { return inputs.count >= minimum }
        return true
    }
}

public struct ActionSpec: Sendable, Hashable, Identifiable {
    public let id: ActionID
    public let title: String
    public let glyph: String
    /// Non-nil only for the Pro share-link action.
    public let cloudFeature: CloudFeature?

    public init(_ id: ActionID, _ title: String, glyph: String, cloud: CloudFeature? = nil) {
        self.id = id
        self.title = title
        self.glyph = glyph
        self.cloudFeature = cloud
    }
}

public enum ToolIDs {
    // Images
    public static let compressImage: ToolID = "image.compress"
    public static let resizeImage: ToolID = "image.resize"
    public static let cropImage: ToolID = "image.crop"
    public static let adjustImage: ToolID = "image.adjust"
    public static let annotateImage: ToolID = "image.annotate"
    public static let redactImage: ToolID = "image.redact"
    public static let removeBackground: ToolID = "image.removeBackground"
    public static let addBackground: ToolID = "image.addBackground"
    public static let collage: ToolID = "image.collage"
    public static let imagesToPDF: ToolID = "image.toPDF"
    public static let readCodes: ToolID = "image.readCodes"
    // Video
    public static let trimVideo: ToolID = "video.trim"
    public static let cropVideo: ToolID = "video.crop"
    public static let speedVideo: ToolID = "video.speed"
    public static let splitVideo: ToolID = "video.split"
    public static let joinVideo: ToolID = "video.join"
    public static let snapshotVideo: ToolID = "video.snapshot"
    public static let compressVideo: ToolID = "video.compress"
    // Audio
    public static let trimAudio: ToolID = "audio.trim"
    public static let normalizeAudio: ToolID = "audio.normalize"
    public static let bleepAudio: ToolID = "audio.bleep"
    public static let channelsAudio: ToolID = "audio.channels"
    // Metadata
    public static let editMetadata: ToolID = "meta.edit"
    public static let stripMetadata: ToolID = "meta.strip"
    // PDF
    public static let organizePDF: ToolID = "pdf.organize"
    public static let compressPDF: ToolID = "pdf.compress"
    // Cloud (Pro)
    public static let transcribe: ToolID = "cloud.transcribe"
    public static let upscale: ToolID = "cloud.upscale"
    public static let removeBackgroundHQ: ToolID = "cloud.removeBackgroundHQ"
}

public enum ActionIDs {
    public static let airDrop: ActionID = "airdrop"
    public static let float: ActionID = "float"
    public static let copy: ActionID = "copy"
    public static let move: ActionID = "move"
    public static let copyPath: ActionID = "copyPath"
    public static let terminal: ActionID = "terminal"
    public static let shareLink: ActionID = "shareLink"
}

/// Tool option schemas. Tools may add editor-only state on top.
public enum ToolSchemas {
    public static let compress = OptionsSchema("tool.compress", [
        OptionSpec(OptionKey.sizeMode, L("Mode"), .choice([
            OptionChoice("quality", L("Quality")), OptionChoice("size", L("Target size")), OptionChoice("percent", L("Percentage")),
        ]), default: .string("quality")),
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(70),
                   visibleWhen: [OptionKey.sizeMode: .string("quality")]),
        OptionSpec(OptionKey.targetSize, L("Target size"), .fileSize, default: .int(1_000_000),
                   visibleWhen: [OptionKey.sizeMode: .string("size")]),
        OptionSpec(OptionKey.percent, L("Percentage of original"), .slider(min: 5, max: 95, step: 5, unit: "%"), default: .int(50),
                   visibleWhen: [OptionKey.sizeMode: .string("percent")]),
    ])

    public static let resize = OptionsSchema("tool.resize", [
        OptionSpec("mode", L("Mode"), .choice([
            OptionChoice("preset", L("Preset")), OptionChoice("pixels", L("Exact size")), OptionChoice("percent", L("Percentage")),
        ]), default: .string("percent")),
        OptionSpec("preset", L("Preset"), .choice([
            OptionChoice("3840", "3840 px"), OptionChoice("2048", "2048 px"), OptionChoice("1920", "1920 px"),
            OptionChoice("1280", "1280 px"), OptionChoice("1080", "1080 px"), OptionChoice("800", "800 px"), OptionChoice("512", "512 px"),
        ]), default: .string("1920"), visibleWhen: ["mode": .string("preset")]),
        OptionSpec("width", L("Width"), .integer(min: 1, max: 32768, unit: "px"), default: .int(1920), visibleWhen: ["mode": .string("pixels")]),
        OptionSpec("height", L("Height"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0),
                   help: L("0 keeps the aspect ratio"), visibleWhen: ["mode": .string("pixels")]),
        OptionSpec(OptionKey.percent, L("Scale"), .slider(min: 5, max: 400, step: 5, unit: "%"), default: .int(50), visibleWhen: ["mode": .string("percent")]),
    ])

    public static let crop = OptionsSchema("tool.crop", [
        OptionSpec("rect", L("Crop"), .rect, default: .string("0,0,1,1")),
        OptionSpec("aspect", L("Aspect"), .choice([
            OptionChoice("free", L("Free")), OptionChoice("1:1", L("Square")), OptionChoice("4:3", "4:3"),
            OptionChoice("3:2", "3:2"), OptionChoice("16:9", "16:9"), OptionChoice("9:16", "9:16"),
        ]), default: .string("free")),
    ])

    public static let adjust = OptionsSchema("tool.adjust", [
        OptionSpec("exposure", L("Exposure"), .decimal(min: -2, max: 2, step: 0.05), default: .double(0)),
        OptionSpec("contrast", L("Contrast"), .decimal(min: 0.5, max: 1.5, step: 0.01), default: .double(1)),
        OptionSpec("saturation", L("Saturation"), .decimal(min: 0, max: 2, step: 0.01), default: .double(1)),
        OptionSpec("warmth", L("Warmth"), .decimal(min: -1, max: 1, step: 0.01), default: .double(0)),
    ])

    public static let redact = OptionsSchema("tool.redact", [
        OptionSpec("style", L("Style"), .choice([
            OptionChoice("blur", L("Blur")), OptionChoice("pixelate", L("Pixelate")), OptionChoice("solid", L("Solid")),
        ]), default: .string("pixelate")),
        OptionSpec("regions", L("Regions"), .text, default: .string(""), help: L("Semicolon-separated rects x,y,w,h (0…1)")),
    ])

    public static let addBackground = OptionsSchema("tool.addBackground", [
        OptionSpec("fill", L("Fill"), .choice([
            OptionChoice("solid", L("Solid")), OptionChoice("gradient", L("Gradient")), OptionChoice("image", L("Image")),
        ]), default: .string("gradient")),
        OptionSpec("color1", L("Colour"), .color, default: .string("#6E56F8")),
        OptionSpec("color2", L("Second colour"), .color, default: .string("#22C3A6"), visibleWhen: ["fill": .string("gradient")]),
        OptionSpec("imagePath", L("Background image"), .text, default: .string(""), visibleWhen: ["fill": .string("image")]),
        OptionSpec("padding", L("Padding"), .slider(min: 0, max: 40, step: 1, unit: "%"), default: .int(10)),
        OptionSpec("cornerRadius", L("Corner radius"), .slider(min: 0, max: 20, step: 1, unit: "%"), default: .int(4)),
        OptionSpec("shadow", L("Shadow"), .toggle, default: .bool(true)),
    ])

    public static let collage = OptionsSchema("tool.collage", [
        OptionSpec("layout", L("Layout"), .choice([
            OptionChoice("grid", L("Grid")), OptionChoice("row", L("Row")), OptionChoice("column", L("Column")),
        ]), default: .string("grid")),
        OptionSpec("gap", L("Gap"), .slider(min: 0, max: 80, step: 2, unit: "px"), default: .int(16)),
        OptionSpec("color1", L("Background"), .color, default: .string("#FFFFFF")),
        OptionSpec("width", L("Output width"), .integer(min: 256, max: 16384, unit: "px"), default: .int(3000)),
    ])

    public static let imagesToPDF = OptionsSchema("tool.imagesToPDF", [
        OptionSpec(OptionKey.pageSize, L("Page size"), .choice([
            OptionChoice("fit", L("Fit each image")), OptionChoice("a4", "A4"), OptionChoice("letter", L("US Letter")),
        ]), default: .string("fit")),
        OptionSpec("order", L("Order"), .text, default: .string(""), help: L("Comma-separated input indices; empty keeps drag order")),
    ])

    public static let trim = OptionsSchema("tool.trim", [
        OptionSpec("range", L("Range"), .timeRange, default: .string("")),
        OptionSpec("lossless", L("Lossless when possible"), .toggle, default: .bool(true)),
    ])

    public static let speed = OptionsSchema("tool.speed", [
        OptionSpec("factor", L("Speed"), .choice([
            OptionChoice("0.25", "0.25×"), OptionChoice("0.5", "0.5×"), OptionChoice("0.75", "0.75×"),
            OptionChoice("1.25", "1.25×"), OptionChoice("1.5", "1.5×"), OptionChoice("2", "2×"), OptionChoice("4", "4×"),
        ]), default: .string("2")),
        OptionSpec("keepPitch", L("Keep audio pitch"), .toggle, default: .bool(true)),
    ])

    public static let split = OptionsSchema("tool.split", [
        OptionSpec("mode", L("Split"), .choice([
            OptionChoice("at", L("At times")), OptionChoice("every", L("Every N seconds")),
        ]), default: .string("every")),
        OptionSpec("at", L("Split points (s)"), .text, default: .string(""), visibleWhen: ["mode": .string("at")]),
        OptionSpec("every", L("Segment length"), .integer(min: 1, max: 36000, unit: "s"), default: .int(60), visibleWhen: ["mode": .string("every")]),
    ])

    public static let snapshot = OptionsSchema("tool.snapshot", [
        OptionSpec("times", L("Times (s)"), .text, default: .string(""), help: L("Comma-separated seconds; empty = middle frame")),
        OptionSpec("format", L("Format"), .choice([OptionChoice("png", "PNG"), OptionChoice("jpg", "JPG")]), default: .string("png")),
    ])

    public static let compressVideo = OptionsSchema("tool.compressVideo", [
        OptionSpec(OptionKey.sizeMode, L("Mode"), .choice([
            OptionChoice("quality", L("Preset")), OptionChoice("size", L("Target size")),
        ]), default: .string("quality")),
        OptionSpec(OptionKey.videoQuality, L("Preset"), .choice([
            OptionChoice("high", L("High")), OptionChoice("balanced", L("Balanced")), OptionChoice("small", L("Small file")),
        ]), default: .string("balanced"), visibleWhen: [OptionKey.sizeMode: .string("quality")]),
        OptionSpec(OptionKey.targetSize, L("Target size"), .fileSize, default: .int(25_000_000), visibleWhen: [OptionKey.sizeMode: .string("size")]),
        OptionSpec(OptionKey.resolution, L("Resolution"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("1080", "1080p"), OptionChoice("720", "720p"), OptionChoice("480", "480p"),
        ]), default: .string("0")),
    ])

    public static let normalize = OptionsSchema("tool.normalize", [
        OptionSpec("target", L("Loudness target"), .choice([
            OptionChoice("-14", L("−14 LUFS (streaming)")), OptionChoice("-16", L("−16 LUFS (podcast)")),
            OptionChoice("-23", L("−23 LUFS (EBU R128 broadcast)")),
        ]), default: .string("-16")),
    ])

    public static let bleep = OptionsSchema("tool.bleep", [
        OptionSpec("ranges", L("Ranges"), .text, default: .string(""), help: L("Semicolon-separated start-end seconds")),
        OptionSpec("style", L("Replace with"), .choice([OptionChoice("tone", L("1 kHz tone")), OptionChoice("silence", L("Silence"))]), default: .string("tone")),
    ])

    public static let channels = OptionsSchema("tool.channels", [
        OptionSpec("mode", L("Channels"), .choice([
            OptionChoice("mono", L("Mono")), OptionChoice("stereo", L("Stereo")), OptionChoice("swap", L("Swap left/right")),
        ]), default: .string("mono")),
    ])

    public static let organizePDF = OptionsSchema("tool.organizePDF", [
        OptionSpec("order", L("Page order"), .text, default: .string(""),
                   help: L("Comma list of input:page[:rotation], e.g. 1:1,1:3:90,2:1. Empty = merge all in order")),
        OptionSpec("split", L("Split into single pages"), .toggle, default: .bool(false)),
    ])

    public static let compressPDF = OptionsSchema("tool.compressPDF", [
        OptionSpec(OptionKey.sizeMode, L("Mode"), .choice([
            OptionChoice("quality", L("Preset")), OptionChoice("size", L("Target size")),
        ]), default: .string("quality")),
        OptionSpec(OptionKey.quality, L("Image quality"), .slider(min: 10, max: 95, step: 5, unit: "%"), default: .int(60),
                   visibleWhen: [OptionKey.sizeMode: .string("quality")]),
        OptionSpec(OptionKey.dpi, L("Image resolution"), .choice([
            OptionChoice("72", "72 DPI"), OptionChoice("150", "150 DPI"), OptionChoice("200", "200 DPI"), OptionChoice("300", "300 DPI"),
        ]), default: .string("150"), visibleWhen: [OptionKey.sizeMode: .string("quality")]),
        OptionSpec(OptionKey.targetSize, L("Target size"), .fileSize, default: .int(2_000_000), visibleWhen: [OptionKey.sizeMode: .string("size")]),
    ])

    public static let metadata = OptionsSchema("tool.metadata", [
        OptionSpec("fields", L("Fields"), .text, default: .string(""), help: L("JSON object of field → value to set; null removes")),
    ])
}

public enum ToolCatalog {
    public static let all: [ToolSpec] = [
        // Images (1–11)
        ToolSpec(ToolIDs.compressImage, L("Compress"), glyph: "arrow.down.right.and.arrow.up.left", kinds: [.image], needsEditor: false, schema: ToolSchemas.compress, suffix: "compressed"),
        ToolSpec(ToolIDs.resizeImage, L("Resize"), glyph: "arrow.up.left.and.down.right.magnifyingglass", kinds: [.image], needsEditor: false, schema: ToolSchemas.resize, suffix: "resized"),
        ToolSpec(ToolIDs.cropImage, L("Crop"), glyph: "crop", kinds: [.image], needsEditor: true, schema: ToolSchemas.crop, suffix: "cropped"),
        ToolSpec(ToolIDs.adjustImage, L("Adjust"), glyph: "slider.horizontal.3", kinds: [.image], needsEditor: true, schema: ToolSchemas.adjust, suffix: "adjusted"),
        ToolSpec(ToolIDs.annotateImage, L("Annotate"), glyph: "pencil.tip.crop.circle", kinds: [.image], needsEditor: true, suffix: "annotated"),
        ToolSpec(ToolIDs.redactImage, L("Redact"), glyph: "eye.slash", kinds: [.image], needsEditor: true, schema: ToolSchemas.redact, suffix: "redacted"),
        ToolSpec(ToolIDs.removeBackground, L("Remove background"), glyph: "person.crop.rectangle", kinds: [.image], needsEditor: false, suffix: "cutout"),
        ToolSpec(ToolIDs.addBackground, L("Add background"), glyph: "rectangle.inset.filled", kinds: [.image], needsEditor: true, schema: ToolSchemas.addBackground, suffix: "background"),
        ToolSpec(ToolIDs.collage, L("Collage"), glyph: "square.grid.2x2", kinds: [.image], arity: .combine(minimum: 2), needsEditor: true, schema: ToolSchemas.collage, suffix: "collage"),
        ToolSpec(ToolIDs.imagesToPDF, L("Images to PDF"), glyph: "doc.on.doc", kinds: [.image], arity: .combine(minimum: 1), needsEditor: true, schema: ToolSchemas.imagesToPDF, suffix: "combined"),
        ToolSpec(ToolIDs.readCodes, L("Read QR / barcode"), glyph: "qrcode.viewfinder", kinds: [.image], needsEditor: false, suffix: "codes"),
        // Video (12–18)
        ToolSpec(ToolIDs.trimVideo, L("Trim"), glyph: "timeline.selection", kinds: [.video], needsEditor: true, schema: ToolSchemas.trim, suffix: "trimmed"),
        ToolSpec(ToolIDs.cropVideo, L("Crop video"), glyph: "crop", kinds: [.video], needsEditor: true, schema: ToolSchemas.crop, suffix: "cropped"),
        ToolSpec(ToolIDs.speedVideo, L("Change speed"), glyph: "gauge.with.dots.needle.67percent", kinds: [.video], needsEditor: false, schema: ToolSchemas.speed, suffix: "speed"),
        ToolSpec(ToolIDs.splitVideo, L("Split"), glyph: "scissors", kinds: [.video], needsEditor: true, schema: ToolSchemas.split, suffix: "part"),
        ToolSpec(ToolIDs.joinVideo, L("Join"), glyph: "rectangle.stack.badge.plus", kinds: [.video], arity: .combine(minimum: 2), needsEditor: true, suffix: "joined"),
        ToolSpec(ToolIDs.snapshotVideo, L("Snapshot frame"), glyph: "camera.viewfinder", kinds: [.video], needsEditor: true, schema: ToolSchemas.snapshot, suffix: "frame"),
        ToolSpec(ToolIDs.compressVideo, L("Compress video"), glyph: "arrow.down.right.and.arrow.up.left", kinds: [.video], needsEditor: false, schema: ToolSchemas.compressVideo, suffix: "compressed"),
        // Audio (19–22)
        ToolSpec(ToolIDs.trimAudio, L("Trim audio"), glyph: "waveform.path", kinds: [.audio], needsEditor: true, schema: ToolSchemas.trim, suffix: "trimmed"),
        ToolSpec(ToolIDs.normalizeAudio, L("Normalize"), glyph: "speaker.wave.2", kinds: [.audio, .video], needsEditor: false, schema: ToolSchemas.normalize, suffix: "normalized"),
        ToolSpec(ToolIDs.bleepAudio, L("Bleep"), glyph: "speaker.slash", kinds: [.audio], needsEditor: true, schema: ToolSchemas.bleep, suffix: "bleeped"),
        ToolSpec(ToolIDs.channelsAudio, L("Change channels"), glyph: "headphones", kinds: [.audio], needsEditor: false, schema: ToolSchemas.channels, suffix: "channels"),
        // Metadata (23–24)
        ToolSpec(ToolIDs.editMetadata, L("Edit metadata"), glyph: "info.circle", kinds: [.image, .audio, .video, .pdf], needsEditor: true, schema: ToolSchemas.metadata, suffix: "edited"),
        ToolSpec(ToolIDs.stripMetadata, L("Strip metadata"), glyph: "eraser", kinds: [.image, .audio, .video, .pdf], needsEditor: false, suffix: "clean"),
        // PDF (25–26)
        ToolSpec(ToolIDs.organizePDF, L("Merge / split / reorder"), glyph: "rectangle.grid.2x2", kinds: [.pdf], needsEditor: true, schema: ToolSchemas.organizePDF, suffix: "organized"),
        ToolSpec(ToolIDs.compressPDF, L("Compress PDF"), glyph: "arrow.down.doc", kinds: [.pdf], needsEditor: false, schema: ToolSchemas.compressPDF, suffix: "compressed"),
        // Pro, server-backed. Never counted as local tools.
        ToolSpec(ToolIDs.transcribe, L("Transcribe"), glyph: "text.bubble", kinds: [.audio, .video], needsEditor: false, suffix: "transcript", cloud: .transcription),
        ToolSpec(ToolIDs.upscale, L("Upscale"), glyph: "arrow.up.backward.and.arrow.down.forward", kinds: [.image], needsEditor: false, suffix: "upscaled", cloud: .upscale),
        ToolSpec(ToolIDs.removeBackgroundHQ, L("Remove background HQ"), glyph: "wand.and.stars", kinds: [.image], needsEditor: false, suffix: "cutout-hq", cloud: .backgroundRemovalHQ),
    ]

    public static var local: [ToolSpec] { all.filter { $0.cloudFeature == nil } }

    public static func spec(_ id: ToolID) -> ToolSpec? { all.first { $0.id == id } }

    /// Tools that apply to every one of `inputs`.
    public static func tools(for inputs: [FormatID]) -> [ToolSpec] {
        all.filter { $0.applies(to: inputs) }
    }
}

public enum ActionCatalog {
    public static let all: [ActionSpec] = [
        ActionSpec(ActionIDs.airDrop, L("AirDrop"), glyph: "airplayaudio"),
        ActionSpec(ActionIDs.float, L("Float"), glyph: "tray.and.arrow.up"),
        ActionSpec(ActionIDs.copy, L("Copy"), glyph: "doc.on.doc"),
        ActionSpec(ActionIDs.move, L("Move"), glyph: "folder.badge.gearshape"),
        ActionSpec(ActionIDs.copyPath, L("Copy Path"), glyph: "link"),
        ActionSpec(ActionIDs.terminal, L("Terminal"), glyph: "terminal"),
        ActionSpec(ActionIDs.shareLink, L("Share link"), glyph: "link.icloud", cloud: .shareLink),
    ]

    public static var local: [ActionSpec] { all.filter { $0.cloudFeature == nil } }

    public static func spec(_ id: ActionID) -> ActionSpec? { all.first { $0.id == id } }
}
