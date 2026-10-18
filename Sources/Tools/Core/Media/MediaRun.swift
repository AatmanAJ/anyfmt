import Foundation

/// Shared plumbing for the ffmpeg-based tools: inputs, output naming inside
/// `request.outputDirectory`, a private scratch folder, encoder fallback.
struct MediaRun: Sendable {
    let request: ToolRequest
    let context: EngineContext
    let ffmpeg: FFmpeg

    init(_ request: ToolRequest, _ context: EngineContext) throws {
        self.request = request
        self.context = context
        self.ffmpeg = FFmpeg(locator: context.locator)
        guard ffmpeg.isAvailable else {
            throw ConversionError.engineMissing("ffmpeg", detail: "not found in \(context.locator.helperDirectories.map(\.path))")
        }
        guard !request.inputs.isEmpty else { throw ConversionError.invalidOption("inputs") }
    }

    var input: URL { request.inputs[0] }
    var options: OptionValues { request.options }

    /// Container of `url`, from its extension.
    func container(of url: URL) throws -> MediaContainer {
        guard let c = MediaContainer(extension: url.pathExtension) else {
            throw ConversionError.other(L("“\(url.lastPathComponent)” is in a format this tool can’t write back."),
                                        detail: "no container for .\(url.pathExtension)")
        }
        return c
    }

    /// Extension for outputs that keep the input's container: the input's own, lowercased.
    func keptExtension(of url: URL) -> String {
        let e = url.pathExtension.lowercased()
        return e.isEmpty ? (Formats.detect(url).map(Formats.extension(for:)) ?? "mp4") : e
    }

    func probe(_ url: URL) async throws -> MediaInfo {
        try await MediaInfo.load(url, locator: context.locator)
    }

    /// `<outputDirectory>/<baseName><suffix>.<ext>`, never an existing item.
    func outputURL(ext: String, suffix: String = "") -> URL {
        OutputNamer.freeURL(in: request.outputDirectory, base: request.baseName + suffix, ext: ext)
    }

    /// A private folder inside the output directory for list files, pass logs
    /// and intermediates. Callers remove it with `cleanup(_:)`.
    func makeScratch() throws -> URL {
        let u = request.outputDirectory.appendingPathComponent(".halo-scratch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func cleanup(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Runs ffmpeg once per attempt until one succeeds. Partial outputs from a
    /// failed attempt are removed before the next. Cancellation never retries.
    func runAttempts(_ attempts: [EncoderAttempt], removing outputs: @escaping @Sendable () -> [URL],
                     _ body: (EncoderAttempt) async throws -> Void) async throws {
        var lastError: Error = ConversionError.engineFailed("ffmpeg", status: -1, detail: "no encoder attempts")
        for (i, attempt) in attempts.enumerated() {
            do {
                try await body(attempt)
                if i > 0 { context.logger.info("encoded with fallback \(attempt.label, privacy: .public)") }
                return
            } catch let e as ConversionError {
                guard case .engineFailed = e else { throw e }
                lastError = e
                context.logger.error("encoder \(attempt.label, privacy: .public) failed: \(e.technicalDetails, privacy: .public)")
                for u in outputs() { try? FileManager.default.removeItem(at: u) }
                try Task.checkCancellation()
            }
        }
        throw lastError
    }

    /// Stream maps for the main video plus every audio stream (and subtitles
    /// where the container carries them).
    static func avMaps(_ info: MediaInfo, container: MediaContainer, includeSubtitles: Bool = true) -> [String] {
        var m: [String] = []
        if let v = info.video { m += ["-map", "0:\(v.index)"] }
        for a in info.audios { m += ["-map", "0:\(a.index)"] }
        if includeSubtitles, info.subtitleCount > 0, [.mkv, .mp4, .mov, .m4v, .webm].contains(container) {
            m += ["-map", "0:s?", "-c:s", "copy"]
        }
        return m
    }

    /// Extra muxer flags so QuickTime-family outputs play progressively.
    static func muxerFlags(_ container: MediaContainer) -> [String] {
        container.isQuickTime ? ["-movflags", "+faststart"] : []
    }

    /// Ensures ffmpeg produced the file.
    func requireOutput(_ url: URL) throws -> URL {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else { throw ConversionError.outputMissing(url.lastPathComponent) }
        return url
    }

    static func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }
}

extension ConversionError {
    static func noAudio(_ url: URL) -> ConversionError {
        .other(L("“\(url.lastPathComponent)” has no audio track."), detail: "no audio stream")
    }

    static func noVideo(_ url: URL) -> ConversionError {
        .other(L("“\(url.lastPathComponent)” has no video track."), detail: "no video stream")
    }
}
