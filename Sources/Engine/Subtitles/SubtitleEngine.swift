import Foundation

/// SRT ⇄ VTT and SRT/VTT → TXT, in pure Swift. Timing is exact to the
/// millisecond; see `SRTParser`, `VTTParser` and `SubtitleMarkup` for what
/// is preserved.
public struct SubtitleEngine: ConversionEngine {
    public let id = EngineIDs.subtitles
    public init() {}

    public func isAvailable(_ capability: Capability) -> Bool {
        [Formats.srt, Formats.vtt].contains(capability.from)
            && [Formats.srt, Formats.vtt, Formats.txt].contains(capability.to)
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        try Task.checkCancellation()
        let data: Data
        do {
            data = try Data(contentsOf: request.input)
        } catch {
            throw ConversionError.unreadable(request.input, detail: error.localizedDescription)
        }
        let doc = try Self.parse(data, as: request.from, url: request.input)
        for w in doc.warnings {
            context.logger.notice("subtitles: \(request.input.lastPathComponent, privacy: .private) \(w.description, privacy: .public)")
        }
        guard !doc.cues.isEmpty else {
            throw ConversionError.unreadable(request.input, detail: "no subtitle cues found (\(doc.warnings.count) blocks skipped)")
        }
        let output: Data
        switch request.to {
        case Formats.vtt: output = VTTWriter.write(doc)
        case Formats.srt: output = SRTWriter.write(doc)
        case Formats.txt:
            output = SubtitleTextWriter.write(doc, timestamps: request.options.bool(OptionKey.timestamps, default: false))
        default: throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        try Task.checkCancellation()
        let url = request.defaultOutputURL
        do {
            try output.write(to: url, options: .withoutOverwriting)
        } catch {
            throw ConversionError.other(L("The converted subtitles couldn’t be saved."), detail: "\(url.path): \(error)")
        }
        context.progress(1)
        return ConversionOutput(url)
    }

    static func parse(_ data: Data, as format: FormatID, url: URL) throws -> SubtitleDocument {
        switch format {
        case Formats.srt: return SRTParser.parse(data)
        case Formats.vtt: return VTTParser.parse(data)
        default: throw ConversionError.unreadable(url, detail: "not a subtitle format: \(format)")
        }
    }
}
