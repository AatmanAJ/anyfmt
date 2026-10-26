import CoreGraphics
import Foundation
import ImageIO
import PDFKit

// Live estimates for the pinned options panel: output size, duration, frame
// count and dimensions, recomputed while the user moves sliders.
//
// Every estimate goes through the same code the real conversion runs:
// - Audio, video and GIF build their plan with `AVConversionPlanner` (so the
//   encoder, filter graph, hardware choice and stream copies are identical),
//   then run it on a ≤ 2 s slice from the middle of the input and scale by
//   duration. Clips no longer than the slice are converted whole (exact).
// - CBR audio (MP3) and PCM (WAV/AIFF) are computed, not sampled.
// - Images run the live route (`Router` + `RouteExecutor`) on the real input
//   when the output is ≤ 4 MP (exact). Bigger outputs encode a mosaic of 16
//   full-resolution tiles through the same route and scale by pixel count.
// - PDF → image renders page 1 with `PDFKitEngine` (big pages at two lower DPIs,
//   extrapolated), encodes it with the engine's own encoder and multiplies by pages.
//
// Inputs are probed once and cached by (path, mtime, size); results are cached
// per option set, so moving a slider back to a previous value is instant.
// Nothing runs unless `estimate` is called: no background work.

/// What a conversion is expected to produce.
public struct ConversionEstimate: Sendable, Equatable {
    /// Estimated output size in bytes (all output files together).
    public var bytes: Int64?
    /// Seconds, for time-based outputs (audio, video, GIF, animated images).
    public var duration: Double?
    /// Frame count for GIF / animated outputs.
    public var frames: Int?
    /// Output dimensions in pixels, when known.
    public var pixelSize: CGSize?
    /// True when `bytes` is computed (CBR bitrate × duration, PCM) or comes from
    /// a full conversion, rather than scaled from a sample.
    public var isExact: Bool
    /// Size of the input, so the UI can show "−62 %".
    public var inputBytes: Int64?

    public init(bytes: Int64? = nil, duration: Double? = nil, frames: Int? = nil, pixelSize: CGSize? = nil,
                isExact: Bool = false, inputBytes: Int64? = nil) {
        self.bytes = bytes
        self.duration = duration
        self.frames = frames
        self.pixelSize = pixelSize
        self.isExact = isExact
        self.inputBytes = inputBytes
    }
}

public enum Estimator {
    /// Cancellable (checks Task.isCancelled), bounded work: never more than ~1.5 s CPU per call.
    /// Throws only when the input can't be read; unsupported pairs return `inputBytes` and nil estimates.
    public static func estimate(input: URL, target: FormatID, options: OptionValues) async throws -> ConversionEstimate {
        try await estimate(input: input, target: target, options: options, locator: .shared)
    }

    static func estimate(input: URL, target: FormatID, options: OptionValues, locator: EngineLocator) async throws -> ConversionEstimate {
        try Task.checkCancellation()
        let stamp = try FileStamp(input)
        let key = ResultKey(stamp: stamp, target: target, options: options)
        if let hit = results.get(key) { return hit }
        let result = try await compute(input: input, stamp: stamp, target: target, options: options, locator: locator)
        try Task.checkCancellation()
        results.set(key, result)
        return result
    }

    // MARK: - Dispatch

    private static func compute(input: URL, stamp: FileStamp, target: FormatID, options: OptionValues,
                                locator: EngineLocator) async throws -> ConversionEstimate {
        let base = ConversionEstimate(inputBytes: stamp.size)
        guard let from = Formats.detect(input), from != target else { return base }
        let kind = Formats.kind(from)
        let env = Env(input: input, stamp: stamp, from: from, target: target, locator: locator)

        if kind == .video || (from == Formats.gif && AVCodecTables.videoContainers.contains(target)) {
            if target == Formats.gif { return try await gif(env, options: options) }
            if AVCodecTables.videoContainers.contains(target) { return try await video(env, options: options) }
            if AVCodecTables.audioContainers.contains(target) { return try await audio(env, options: options) }
            return base
        }
        if kind == .audio, AVCodecTables.audioContainers.contains(target) {
            return try await audio(env, options: options)
        }
        if from == Formats.pdf, PDFKitEngine.imageOutputs.contains(target) {
            return try await pdf(env, options: options)
        }
        if kind == .image, Formats.kind(target) == .image {
            return try await image(env, options: options)
        }
        return base
    }

    struct Env {
        let input: URL
        let stamp: FileStamp
        let from: FormatID
        let target: FormatID
        let locator: EngineLocator
    }

    // MARK: - Video → GIF

    private static func gif(_ env: Env, options raw: OptionValues) async throws -> ConversionEstimate {
        let probe = try await mediaProbe(env)
        var est = ConversionEstimate(duration: probe.facts.duration, inputBytes: env.stamp.size)
        guard let v = probe.facts.video else { return est }
        var options = StandardSchemas.gif.defaults.merging(raw)
        let sourceFPS = v.frameRate ?? v.nominalFrameRate
        // 0 means "source frame rate" in the estimate (and is passed on as the source rate).
        if options.int(OptionKey.fps, default: 15) <= 0, let sourceFPS {
            options[OptionKey.fps] = .int(max(1, Int(sourceFPS.rounded())))
        }
        // Same arithmetic as AVConversionPlanner.gifPlan.
        let requestedWidth = options.int(OptionKey.gifWidth, default: 640)
        let width = max(2, requestedWidth > 0 ? min(requestedWidth, v.displayWidth) : v.displayWidth)
        let height = max(1, Int((Double(width) * Double(v.displayHeight) / Double(max(1, v.displayWidth))).rounded()))
        let requestedFPS = Double(max(1, options.int(OptionKey.fps, default: 15)))
        let fps = min(requestedFPS, sourceFPS.map { max(1, $0) } ?? requestedFPS)
        est.pixelSize = CGSize(width: width, height: height)
        if let d = probe.facts.duration { est.frames = max(1, Int((d * fps).rounded())) }

        // GIF filters run on the source frames (decode + scale) then on the output frames (palette).
        let work = Double(v.displayWidth * v.displayHeight) * fps * 2
        let sample = try await sampleEncode(env, probe: probe, options: options, pixelWork: work, encoder: "gif")
        if let sample {
            est.bytes = sample.bytes
            est.isExact = sample.isWhole
        }
        return est
    }

    // MARK: - Video → video

    private static func video(_ env: Env, options raw: OptionValues) async throws -> ConversionEstimate {
        let probe = try await mediaProbe(env)
        let facts = probe.facts
        var est = ConversionEstimate(duration: facts.duration, inputBytes: env.stamp.size)
        let options = StandardSchemas.video.defaults.merging(raw)
        let vopts = AVVideoOptions(options)
        if let v = facts.video {
            let size = AVConversionPlanner.targetSize(width: v.displayWidth, height: v.displayHeight, maxShortEdge: vopts.maxShortEdge)
            est.pixelSize = CGSize(width: size.0, height: size.1)
        }
        guard let plan = try? plan(env, facts: facts, options: options) else { return est }
        guard let duration = facts.duration, duration > 0 else { return est }

        if plan.video == nil || plan.video == .copy {
            // Remux (or only audio re-encoded): sum the streams' bitrates.
            est.bytes = copyModel(probe, plan: plan, removeAudio: vopts.removeAudio, duration: duration, inputBytes: env.stamp.size)
            return est
        }
        guard let v = facts.video else { return est }
        let size = AVConversionPlanner.targetSize(width: v.displayWidth, height: v.displayHeight, maxShortEdge: vopts.maxShortEdge)
        let fps = min(vopts.fps ?? .infinity, v.frameRate ?? v.nominalFrameRate ?? 30)
        // Decode cost is at the source size, encode cost at the output size.
        let work = Double(v.displayWidth * v.displayHeight) * fps * 0.3 + Double(size.0 * size.1) * fps
        if let sample = try await sampleEncode(env, probe: probe, options: options, pixelWork: work, encoder: plan.video?.encoder ?? "") {
            est.bytes = sample.bytes
            est.isExact = sample.isWhole
        }
        return est
    }

    /// Bytes for a plan whose video is copied: copied streams keep their bitrate,
    /// re-encoded audio gets the encoder's default bitrate.
    static func copyModel(_ probe: MediaProbeResult, plan: AVConversionPlan, removeAudio: Bool, duration: Double, inputBytes: Int64) -> Int64 {
        let facts = probe.facts
        var bitsPerSecond = 0.0
        var known = true
        if facts.video != nil {
            if let br = probe.videoBitRate { bitsPerSecond += Double(br) } else { known = false }
        }
        if !removeAudio {
            for (k, a) in facts.audio.enumerated() {
                let action = k < plan.audio.count ? plan.audio[k] : .copy
                switch action {
                case .copy:
                    if let br = a.bitRate { bitsPerSecond += Double(br) } else { known = false }
                case .encode(let enc):
                    let ch = a.channels ?? 2
                    let kbps: Int = switch enc {
                    case "libopus": AVDefaultAudio.opusBitrate(channels: ch)
                    case "libmp3lame": AVDefaultAudio.mp3Bitrate
                    case "wmav2": AVDefaultAudio.wmaBitrate
                    default: AVDefaultAudio.aacBitrate(channels: ch)
                    }
                    bitsPerSecond += Double(kbps * 1000)
                }
            }
        }
        guard known else {
            // Bitrates unknown (common for WebM/MKV): a remux keeps the input's size.
            return inputBytes
        }
        return Int64(bitsPerSecond / 8 * duration * containerOverhead)
    }

    // MARK: - Audio

    private static func audio(_ env: Env, options raw: OptionValues) async throws -> ConversionEstimate {
        let probe = try await mediaProbe(env)
        let facts = probe.facts
        var est = ConversionEstimate(duration: facts.duration, inputBytes: env.stamp.size)
        guard let a = facts.primaryAudio, let duration = facts.duration, duration > 0 else { return est }
        let options = AVRoutes.audioSchema(env.target).defaults.merging(raw)
        let o = AVAudioOptions(options)
        guard let plan = try? plan(env, facts: facts, options: options) else { return est }

        let target = env.target
        let depth = o.bitDepth ?? ((a.bitDepth ?? 16) > 16 ? 24 : 16)
        let channels = o.channels ?? ((a.channels ?? 2) > 2 && target == Formats.mp3 ? 2 : (a.channels ?? 2))
        let sampleRate = target == Formats.opus ? 48000 : (o.sampleRate ?? a.sampleRate ?? 44100)

        if plan.audio == [.copy] {
            // Stream copy: the audio bytes don't change.
            if Formats.kind(env.from) == .audio {
                est.bytes = env.stamp.size
            } else if let br = a.bitRate {
                est.bytes = Int64(Double(br) / 8 * duration) + 1024
            }
            return est
        }
        switch target {
        case Formats.mp3:
            // libmp3lame -b:a is constant bitrate: bitrate × duration, plus the
            // LAME info frame, encoder padding and ID3v2 tags (and cover art, if kept).
            let frame = 1152.0 / Double(sampleRate)
            let audioBytes = Double(o.bitrate * 1000) / 8 * (duration + 2 * frame)
            est.bytes = Int64(audioBytes) + 600 + coverBytes(probe, inputBytes: env.stamp.size, duration: duration)
            est.isExact = true
            return est
        case Formats.wav, Formats.aiff:
            let pcm = Double(sampleRate * channels * depth / 8) * duration
            est.bytes = Int64(pcm.rounded()) + (target == Formats.wav ? 44 : 54) + 200
            est.isExact = true
            return est
        default:
            break
        }
        // AAC (average bitrate), Vorbis/Opus (VBR) and FLAC/ALAC (content-dependent
        // compression) are sampled; the PCM model is the fallback. FLAC/ALAC slices start
        // at 0: ffmpeg's FLAC encoder takes its block size from the first decoded frame, and
        // after a seek that frame is short (measured −36 % from a seeked MP3 slice).
        let work = Double(sampleRate * channels) * 0.05
        if let sample = try await sampleEncode(env, probe: probe, options: options, pixelWork: work, encoder: "audio",
                                               maxSample: 10, fromStart: AVCodecTables.losslessAudio.contains(target)) {
            est.bytes = sample.bytes
            est.isExact = sample.isWhole
        } else {
            let pcm = Double(sampleRate * channels * depth / 8) * duration
            switch target {
            case Formats.flac, Formats.caf: est.bytes = Int64(pcm * 0.6)
            default: est.bytes = Int64(Double(o.bitrate * 1000) / 8 * duration)
            }
        }
        return est
    }

    /// Cover art carried into MP3/M4A/FLAC: what the input holds beyond its audio.
    static func coverBytes(_ probe: MediaProbeResult, inputBytes: Int64, duration: Double) -> Int64 {
        guard probe.facts.coverArt != nil, let br = probe.facts.primaryAudio?.bitRate else { return 0 }
        return max(0, inputBytes - Int64(Double(br) / 8 * duration))
    }

    // MARK: - Sampling

    struct SampleResult {
        var bytes: Int64
        /// The whole input was converted (no scaling).
        var isWhole: Bool
    }

    /// Longest slice we encode.
    static let maxSampleSeconds = 2.0
    /// Shortest slice worth scaling from.
    static let minSampleSeconds = 0.5

    /// Rough encoder throughput on Apple silicon, in "pixel work" units per second
    /// of wall time. Keeps a 4K HEVC software encode from taking 10 s to estimate.
    static func throughput(_ encoder: String) -> Double {
        switch encoder {
        case let e where e.hasSuffix("_videotoolbox"): 400e6
        case "libx264": 90e6
        case "libx265": 25e6
        case "libvpx-vp9": 35e6
        case "libaom-av1": 20e6
        case "prores_ks": 120e6
        case "gif": 60e6
        case "audio": 1e9
        default: 200e6
        }
    }

    /// Seconds of input to encode so the sample costs about a second.
    static func sampleSeconds(duration: Double, pixelWork: Double, encoder: String, maxSample: Double) -> Double {
        let budget = throughput(encoder) * 1.0
        let s = pixelWork > 0 ? budget / pixelWork : maxSample
        return min(duration, max(minSampleSeconds, min(maxSample, s)))
    }

    /// Plans the real conversion, runs it on a slice from the middle, and scales the bytes.
    /// Nil when the engine can't run it (the estimate then has no size); throws on cancel.
    private static func sampleEncode(_ env: Env, probe: MediaProbeResult, options: OptionValues, pixelWork: Double,
                                     encoder: String, maxSample: Double = maxSampleSeconds,
                                     fromStart: Bool = false) async throws -> SampleResult? {
        guard let duration = probe.facts.duration, duration > 0 else { return nil }
        let length = sampleSeconds(duration: duration, pixelWork: pixelWork, encoder: encoder, maxSample: maxSample)
        // Clips barely longer than the slice are converted whole.
        let whole = duration <= length * 1.25
        let start = whole || fromStart ? 0 : (duration - length) / 2

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-estimate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let ctx = AVConversionPlanner.Context(input: env.input, output: dir.appendingPathComponent("sample").appendingPathExtension(Formats.extension(for: env.target)),
                                              scratchDirectory: dir, metadata: .keep)
        guard var plan = try? AVConversionPlanner.plan(probe.facts, from: env.from, to: env.target, options: options, context: ctx) else { return nil }
        if !whole { plan = trimmed(plan, input: env.input.path, start: start, length: length) }
        stats.recordSample()
        do {
            try await FFmpegAVEngine().run(plan, context: EngineContext(locator: env.locator), duration: whole ? duration : length)
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            return nil
        }
        try Task.checkCancellation()
        let out = (plan.output.path as NSString).resolvingSymlinksInPath
        guard let size = (try? FileManager.default.attributesOfItem(atPath: out)[.size] as? NSNumber)?.int64Value, size > 0 else {
            return nil
        }
        if whole { return SampleResult(bytes: size, isWhole: true) }
        let scale = duration / length
        // Several streams: count each stream's packets. A stream-copied track in a seeked
        // slice drags pre-roll packets into the file (measured: +60 % on a 2 s MOV slice),
        // so copied audio is costed from its source bitrate instead.
        if AVCodecTables.videoContainers.contains(env.target), !plan.audio.isEmpty,
           let streams = try await packetBytes(plan.output, locator: env.locator), let video = streams.first(where: { $0.isVideo }) {
            var total = Double(video.bytes) * scale
            let audio = streams.filter { !$0.isVideo }
            for (k, action) in plan.audio.enumerated() {
                let sourceRate = k < probe.facts.audio.count ? probe.facts.audio[k].bitRate : nil
                if action == .copy, let br = sourceRate {
                    total += Double(br) / 8 * duration
                } else if k < audio.count {
                    total += Double(audio[k].bytes) * scale
                }
            }
            return SampleResult(bytes: Int64((total * containerOverhead).rounded()), isWhole: false)
        }
        // Album art is carried once, whatever the duration.
        if plan.coverArt != nil, let streams = try await packetBytes(plan.output, locator: env.locator),
           let cover = streams.first(where: { $0.isVideo }), cover.bytes < size {
            return SampleResult(bytes: Int64((Double(size - cover.bytes) * scale).rounded()) + cover.bytes, isWhole: false)
        }
        return SampleResult(bytes: Int64((Double(size) * scale).rounded()), isWhole: false)
    }

    /// Index, headers and interleaving of MP4/MOV/MKV (measured ≈ 1.2 % on a 12 s MOV).
    static let containerOverhead = 1.012

    struct StreamBytes {
        var isVideo: Bool
        var bytes: Int64
    }

    /// Bytes of every packet per output stream, in stream order (video first, as the planner maps it).
    static func packetBytes(_ url: URL, locator: EngineLocator) async throws -> [StreamBytes]? {
        guard let exe = locator.ffprobe else { return nil }
        let r: ProcessResult
        do {
            r = try await ProcessRunner.run(exe, ["-v", "error", "-show_entries", "stream=index,codec_type:packet=stream_index,size",
                                                  "-of", "json", url.path])
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            return nil
        }
        struct Probe: Decodable {
            struct Stream: Decodable { let index: Int; let codec_type: String? }
            struct Packet: Decodable { let stream_index: Int; let size: String? }
            let streams: [Stream]?
            let packets: [Packet]?
        }
        guard let p = try? JSONDecoder().decode(Probe.self, from: r.stdout), let streams = p.streams else { return nil }
        var sums: [Int: Int64] = [:]
        for packet in p.packets ?? [] { sums[packet.stream_index, default: 0] += Int64(packet.size ?? "") ?? 0 }
        return streams.filter { $0.codec_type == "video" || $0.codec_type == "audio" }
            .map { StreamBytes(isVideo: $0.codec_type == "video", bytes: sums[$0.index] ?? 0) }
    }

    /// The plan with `-ss start -t length` in front of every `-i <input>` (not the palette input).
    static func trimmed(_ plan: AVConversionPlan, input: String, start: Double, length: Double) -> AVConversionPlan {
        var p = plan
        p.passes = plan.passes.map { AVPass(arguments: trim($0.arguments, input: input, start: start, length: length), weight: $0.weight) }
        p.fallback = plan.fallback.map { trimmed($0, input: input, start: start, length: length) }
        return p
    }

    static func trim(_ args: [String], input: String, start: Double, length: Double) -> [String] {
        var out: [String] = []
        out.reserveCapacity(args.count + 4)
        for (i, a) in args.enumerated() {
            if a == "-i", i + 1 < args.count, args[i + 1] == input {
                if start > 0 { out += ["-ss", String(format: "%.3f", start)] }
                out += ["-t", String(format: "%.3f", length)]
            }
            out.append(a)
        }
        return out
    }

    private static func plan(_ env: Env, facts: AVInputFacts, options: OptionValues) throws -> AVConversionPlan {
        let scratch = FileManager.default.temporaryDirectory
        let ctx = AVConversionPlanner.Context(input: env.input, output: scratch.appendingPathComponent("plan.\(Formats.extension(for: env.target))"),
                                              scratchDirectory: scratch, metadata: .keep)
        return try AVConversionPlanner.plan(facts, from: env.from, to: env.target, options: options, context: ctx)
    }

    // MARK: - Images

    /// Outputs up to this many pixels are converted for real (exact).
    static let exactPixelLimit = 4_000_000.0
    /// Bigger outputs are sampled as a mosaic of `tileGrid`² full-resolution tiles.
    static let tileGrid = 4
    static let tileEdge = 256

    private static func image(_ env: Env, options: OptionValues) async throws -> ConversionEstimate {
        let facts = try imageProbe(env)
        var est = ConversionEstimate(inputBytes: env.stamp.size)
        let longest = max(facts.width, facts.height)
        let maxDim = max(0, options.int(OptionKey.maxDimension, default: 0))
        let edge = maxDim > 0 ? min(maxDim, longest) : longest
        let out = scaled(facts.width, facts.height, longestEdge: edge)
        est.pixelSize = CGSize(width: out.0, height: out.1)
        let animated = (facts.frames ?? 1) > 1
        if animated, [Formats.gif, Formats.webp, Formats.avif].contains(env.target) {
            est.frames = facts.frames
            est.duration = facts.duration
        }
        let outPixels = Double(out.0 * out.1)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-estimate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Small outputs (and animations, whose frames can't be tiled): the real conversion.
        if outPixels <= exactPixelLimit || animated {
            guard let route = Router.live().route(from: env.from, to: env.target) else { return est }
            var runOptions = options
            let sampleEdge = 1024
            let downscale = outPixels > exactPixelLimit
            if downscale { runOptions[OptionKey.maxDimension] = .int(sampleEdge) }
            guard let bytes = try await runRoute(route, input: env.input, options: runOptions, dir: dir, env: env) else { return est }
            if downscale {
                let s = scaled(facts.width, facts.height, longestEdge: min(sampleEdge, longest))
                est.bytes = Int64(Double(bytes) * outPixels / Double(max(1, s.0 * s.1)))
            } else {
                est.bytes = bytes
                est.isExact = true
            }
            return est
        }

        // Big stills: decode at the output size exactly as the real pipeline does, cut a
        // mosaic of tiles spread over the picture (full-resolution detail and noise, which
        // a downscale would smooth away: measured −50 % on HEIC/AVIF), encode it through
        // the live route with the same options, and scale by pixel count.
        try Task.checkCancellation()
        let input = try ImageInput.open(env.input, format: env.from)
        let decoded = try ImageOps.decode(input, maxPixelSize: edge)
        guard let mosaic = mosaic(of: decoded) else { return est }
        try Task.checkCancellation()
        let carrier = env.target == Formats.png ? Formats.tiff : Formats.png
        let tile = dir.appendingPathComponent("mosaic").appendingPathExtension(Formats.extension(for: carrier))
        try ImageWriter.write(mosaic, to: tile, uti: carrier == Formats.png ? ImageUTI.png : ImageUTI.tiff, options: [:])
        guard let route = Router.live().route(from: carrier, to: env.target) else { return est }
        var runOptions = options
        runOptions[OptionKey.maxDimension] = .int(0)
        guard let bytes = try await runRoute(route, input: tile, options: runOptions, dir: dir, env: env) else { return est }
        est.bytes = Int64((Double(bytes) * outPixels / Double(mosaic.width * mosaic.height)).rounded())
        return est
    }

    /// Runs a live route into a fresh folder under `dir`; total bytes written, nil if the engine failed. Throws on cancel.
    private static func runRoute(_ route: Route, input: URL, options: OptionValues, dir: URL, env: Env) async throws -> Int64? {
        stats.recordSample()
        let work = dir.appendingPathComponent("run-\(UUID().uuidString)", isDirectory: true)
        let files: [URL]
        do {
            files = try await RouteExecutor().execute(route, inputs: [input], options: options, baseName: "estimate",
                                                       metadata: .keep, workDirectory: work, context: EngineContext(locator: env.locator))
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            return nil
        }
        try Task.checkCancellation()
        let bytes = files.reduce(Int64(0)) { $0 + fileSize($1) }
        return bytes > 0 ? bytes : nil
    }

    /// `tileGrid`² tiles of up to `tileEdge` px, evenly spread, packed edge to edge.
    /// Tile edges are multiples of 16, so seams fall on JPEG/HEVC/AV1 block boundaries.
    static func mosaic(of image: CGImage) -> CGImage? {
        let n = tileGrid
        let tw = max(16, min(tileEdge, image.width / n / 16 * 16))
        let th = max(16, min(tileEdge, image.height / n / 16 * 16))
        guard image.width >= tw, image.height >= th else { return nil }
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? ImageOps.sRGB
        let bits = image.bitsPerComponent > 8 ? 16 : 8
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        var info = hasAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        if bits == 16 { info |= CGBitmapInfo.byteOrder16Little.rawValue }
        guard let ctx = CGContext(data: nil, width: tw * n, height: th * n, bitsPerComponent: bits, bytesPerRow: 0,
                                  space: space, bitmapInfo: info) else { return nil }
        ctx.interpolationQuality = .none
        for row in 0..<n {
            for col in 0..<n {
                let x = (image.width - tw) * col / max(1, n - 1)
                let y = (image.height - th) * row / max(1, n - 1)
                guard let piece = image.cropping(to: CGRect(x: x, y: y, width: tw, height: th)) else { return nil }
                // Crops count from the top; CG draws from the bottom-left.
                ctx.draw(piece, in: CGRect(x: col * tw, y: (n - 1 - row) * th, width: tw, height: th))
            }
        }
        return ctx.makeImage()
    }

    /// Size after fitting the longest edge (ImageIO thumbnail rounding).
    static func scaled(_ w: Int, _ h: Int, longestEdge edge: Int) -> (Int, Int) {
        let longest = max(w, h)
        guard longest > 0, edge < longest else { return (w, h) }
        let s = Double(edge) / Double(longest)
        return (max(1, Int((Double(w) * s).rounded())), max(1, Int((Double(h) * s).rounded())))
    }

    // MARK: - PDF → images

    private static func pdf(_ env: Env, options raw: OptionValues) async throws -> ConversionEstimate {
        let options = StandardSchemas.pdfRender.defaults.merging(raw)
        var est = ConversionEstimate(inputBytes: env.stamp.size)
        let doc = try PDFKitEngine.open(env.input)
        let pages = (try? PageRange.parse(options.string(OptionKey.pages, default: ""), pageCount: doc.pageCount)) ?? []
        guard let first = pages.first, let page = doc.page(at: first - 1) else { return est }
        let dpi = Double(min(PDFKitEngine.dpiRange.upperBound, max(PDFKitEngine.dpiRange.lowerBound,
                                                                   options.int(OptionKey.dpi, default: PDFKitEngine.defaultDPI))))
        guard let full = pagePixels(page, dpi: dpi) else { return est }
        est.pixelSize = CGSize(width: full.0, height: full.1)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-estimate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fullPixels = Double(full.0 * full.1)
        guard fullPixels > exactPixelLimit else {
            guard let bytes = try await encodePage(page, dpi: dpi, env: env, options: options, dir: dir) else { return est }
            est.bytes = bytes.bytes * Int64(pages.count)
            est.isExact = pages.count == 1
            return est
        }
        // Pages are vector art: the same picture at any DPI, so the growth of bytes with
        // resolution is measured, not assumed. Render at ≤ 4 MP and at a quarter of that,
        // fit bytes ∝ pixels^α, extrapolate to the chosen DPI. (Linear scaling was +19 %
        // on JPEG and +140 % on HEIC at 600 DPI; full-DPI tiles miss sparse pages, −35 %.)
        let hiDPI = dpi * (exactPixelLimit / fullPixels).squareRoot()
        guard let hi = try await encodePage(page, dpi: hiDPI, env: env, options: options, dir: dir),
              let lo = try await encodePage(page, dpi: hiDPI / 2, env: env, options: options, dir: dir) else { return est }
        let alpha = lo.bytes > 0 && hi.bytes > lo.bytes
            ? min(1.1, max(0.3, log(Double(hi.bytes) / Double(lo.bytes)) / log(hi.pixels / lo.pixels)))
            : 1
        let perPage = Double(hi.bytes) * pow(fullPixels / hi.pixels, alpha)
        est.bytes = Int64(perPage.rounded()) * Int64(pages.count)
        return est
    }

    /// Renders and encodes one page the way `PDFKitEngine` does; bytes and rendered pixel count.
    private static func encodePage(_ page: PDFPage, dpi: Double, env: Env, options: OptionValues,
                                   dir: URL) async throws -> (bytes: Int64, pixels: Double)? {
        try Task.checkCancellation()
        guard let image = PDFKitEngine.render(page, dpi: dpi) else { return nil }
        let url = dir.appendingPathComponent("page-\(UUID().uuidString)").appendingPathExtension(Formats.extension(for: env.target))
        stats.recordSample()
        do {
            try await PDFKitEngine.encode(image, as: env.target, to: url, dpi: dpi, options: options, work: dir,
                                          context: EngineContext(locator: env.locator), progress: .ignore)
        } catch {
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            return nil
        }
        try Task.checkCancellation()
        let bytes = fileSize(url)
        return bytes > 0 ? (bytes, Double(image.width * image.height)) : nil
    }

    /// Pixel size `PDFKitEngine.render` produces for a page.
    static func pagePixels(_ page: PDFPage, dpi: Double) -> (Int, Int)? {
        let box = page.bounds(for: .cropBox)
        let rotation = ((page.rotation % 360) + 360) % 360
        let (wPt, hPt) = rotation % 180 == 0 ? (box.width, box.height) : (box.height, box.width)
        guard wPt > 0, hPt > 0 else { return nil }
        var scale = dpi / 72
        if Double(max(wPt, hPt)) * scale > PDFKitEngine.maxPixelEdge { scale = PDFKitEngine.maxPixelEdge / Double(max(wPt, hPt)) }
        return (max(1, Int((Double(wPt) * scale).rounded())), max(1, Int((Double(hPt) * scale).rounded())))
    }

    // MARK: - Probing (cached)

    struct MediaProbeResult: Sendable {
        let facts: AVInputFacts
        /// Video stream bitrate (bits/s), when the container reports it.
        let videoBitRate: Int?
    }

    struct ImageFacts: Sendable {
        /// Oriented (as displayed) size.
        let width: Int
        let height: Int
        let frames: Int?
        let duration: Double?
    }

    enum Probe: Sendable {
        case media(MediaProbeResult)
        case image(ImageFacts)
    }

    /// ffprobe once per input (path, mtime, size).
    static func mediaProbe(_ env: Env) async throws -> MediaProbeResult {
        if case .media(let m)? = probes.get(env.stamp) { return m }
        guard let exe = env.locator.ffprobe else {
            throw ConversionError.engineMissing("ffprobe", detail: "not found in \(env.locator.helperDirectories.map(\.path))")
        }
        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(exe, ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", env.input.path])
        } catch let error as ConversionError {
            if case .engineFailed(_, _, let detail) = error { throw ConversionError.unreadable(env.input, detail: "ffprobe: \(detail)") }
            throw error
        }
        let facts = try AVProbe.facts(fromJSON: result.stdout, url: env.input)
        let probe = try? JSONDecoder().decode(MediaProbe.self, from: result.stdout)
        let videoBitRate = facts.video.flatMap { v in probe?.streams.first { $0.index == v.index }?.bit_rate.flatMap(Int.init) }
        let m = MediaProbeResult(facts: facts, videoBitRate: videoBitRate)
        probes.set(env.stamp, .media(m))
        return m
    }

    static func imageProbe(_ env: Env) throws -> ImageFacts {
        if case .image(let f)? = probes.get(env.stamp) { return f }
        let input = try ImageInput.open(env.input, format: env.from)
        let f = ImageFacts(width: input.orientedWidth, height: input.orientedHeight,
                           frames: input.animation?.frameCount, duration: input.animation?.totalDuration)
        probes.set(env.stamp, .image(f))
        return f
    }

    static func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }

    // MARK: - Caches

    /// Identifies one version of a file.
    struct FileStamp: Hashable, Sendable {
        let path: String
        let modified: Double
        let size: Int64

        init(_ url: URL) throws {
            let path = url.standardizedFileURL.path
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
                throw ConversionError.unreadable(url, detail: "no such file")
            }
            self.path = path
            modified = (attrs[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
            size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            guard FileManager.default.isReadableFile(atPath: path) else {
                throw ConversionError.unreadable(url, detail: "not readable")
            }
        }
    }

    struct ResultKey: Hashable, Sendable {
        let stamp: FileStamp
        let target: FormatID
        let options: OptionValues
    }

    static let probes = LRUCache<FileStamp, Probe>(capacity: 32)
    static let results = LRUCache<ResultKey, ConversionEstimate>(capacity: 128)
    static let stats = Stats()

    /// Counts sample conversions (tests check that cache hits run none).
    final class Stats: @unchecked Sendable {
        private let lock = NSLock()
        private var samples = 0
        func recordSample() { lock.withLock { samples += 1 } }
        var sampleCount: Int { lock.withLock { samples } }
    }

    /// Drops every cached probe and result (tests).
    static func resetCaches() {
        probes.removeAll()
        results.removeAll()
    }
}

/// Small thread-safe least-recently-used cache.
final class LRUCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int
    private var values: [Key: Value] = [:]
    /// Oldest first.
    private var order: [Key] = []

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func get(_ key: Key) -> Value? {
        lock.withLock {
            guard let v = values[key] else { return nil }
            touch(key)
            return v
        }
    }

    func set(_ key: Key, _ value: Value) {
        lock.withLock {
            if values.updateValue(value, forKey: key) != nil {
                touch(key)
            } else {
                order.append(key)
                if order.count > capacity { values[order.removeFirst()] = nil }
            }
        }
    }

    func removeAll() { lock.withLock { values.removeAll(); order.removeAll() } }

    var count: Int { lock.withLock { values.count } }

    private func touch(_ key: Key) {
        if let i = order.firstIndex(of: key) { order.remove(at: i) }
        order.append(key)
    }
}
