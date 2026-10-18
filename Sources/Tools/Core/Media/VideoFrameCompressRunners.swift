import Foundation

// Tools 17–18: snapshot frames, compress video.

/// 17. Exact frames as PNG/JPG. Times are where the user paused: the frame
/// on screen at time t is the one whose display interval contains t.
public struct SnapshotVideoRunner: ToolRunner {
    public let id = ToolIDs.snapshotVideo
    public init() {}

    /// Seconds of the first frame displayed at `t`.
    public static func frameStart(at t: Double, frameDuration fd: Double) -> Double {
        guard fd > 0 else { return t }
        return (max(0, t) / fd + 1e-4).rounded(.down) * fd
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let fd = video.frameDuration
        let format = run.options.string("format", default: "png") == "jpg" ? "jpg" : "png"
        var times = MediaTimes.list(run.options.string("times", default: ""))
        if times.isEmpty { times = [info.duration / 2] }
        let lastFrame = max(0, info.duration - fd)
        let frames = times.map { Self.frameStart(at: min($0, lastFrame), frameDuration: fd) }

        var filters: [String] = []
        if abs(video.sampleAspect - 1) > 0.01 { filters.append("scale=iw*sar:ih,setsar=1") }
        let codec: [String] = format == "png"
            ? ["-c:v", "png", "-pix_fmt", video.isTenBit ? "rgb48be" : "rgb24"]
            : ["-c:v", "mjpeg", "-q:v", "2", "-pix_fmt", "yuvj444p"]
        var outputs: [URL] = []
        for (i, t) in frames.enumerated() {
            let out = frames.count == 1 ? run.outputURL(ext: format) : run.outputURL(ext: format, suffix: String(format: "-%03d", i + 1))
            // Seek half a frame early: the first frame at or after that is exactly frame t.
            let seek = max(0, t - fd / 2)
            var args = seek > 0 ? ["-ss", MediaTimes.arg(seek)] : []
            args += ["-i", run.input.path, "-map", "0:\(video.index)", "-frames:v", "1"]
            if !filters.isEmpty { args += ["-vf", filters.joined(separator: ",")] }
            args += codec + ["-map_metadata", "-1", "-f", "image2", "-update", "1", out.path]
            try await run.ffmpeg.run(args, progress: context.progress.scaled(Double(i) / Double(frames.count)...Double(i + 1) / Double(frames.count)))
            outputs.append(try run.requireOutput(out))
        }
        return ConversionOutput(outputs)
    }
}

/// 18. Compress video. Presets: VideoToolbox constant quality capped at a
/// fraction of the source bitrate (so the result is reliably smaller).
/// Target size: two-pass software encode at the bitrate that fits, audio included.
public struct CompressVideoRunner: ToolRunner {
    public let id = ToolIDs.compressVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    struct Preset {
        let quality: VideoQuality
        /// Max video bitrate as a fraction of the source's.
        let capFraction: Double
        let audioKbps: Int
    }

    static func preset(_ id: String) -> Preset {
        switch id {
        case "high": Preset(quality: .high, capFraction: 0.8, audioKbps: 160)
        case "small": Preset(quality: .small, capFraction: 0.4, audioKbps: 96)
        default: Preset(quality: .balanced, capFraction: 0.6, audioKbps: 128)
        }
    }

    /// Scale filter capping the short edge at `limit` (never upscales).
    static func scaleFilter(_ video: MediaInfo.Video, shortEdge limit: Int) -> String? {
        let w = video.displayWidth, h = video.displayHeight
        guard limit > 0, min(w, h) > limit else { return nil }
        return w >= h ? "scale=-2:\(limit)" : "scale=\(limit):-2"
    }

    /// Plans the audio and video bitrates for a target size. Pure, for tests.
    public static func budget(targetBytes: Int, duration: Double, hasAudio: Bool) -> (videoBps: Int, audioKbps: Int) {
        let totalBps = Double(targetBytes) * 8 / max(duration, 0.1)
        let audioKbps = !hasAudio ? 0 : (totalBps < 300_000 ? 48 : (totalBps < 1_000_000 ? 96 : 128))
        // ~3 % container overhead.
        let video = (totalBps * 0.97) - Double(audioKbps * 1000)
        return (Int(video), audioKbps)
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let container = try run.container(of: run.input)
        let inputSize = MediaRun.fileSize(run.input)
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        let meta = MediaEncoders.metadata(request.metadata, info: info)
        let maps = MediaRun.avMaps(info, container: container)
        var filters: [String] = []
        if let s = Self.scaleFilter(video, shortEdge: run.options.int(OptionKey.resolution, default: 0)) { filters.append(s) }

        if run.options.string(OptionKey.sizeMode, default: "quality") == "size" {
            let target = run.options.int(OptionKey.targetSize, default: 25_000_000)
            guard Int64(target) < inputSize else {
                throw ConversionError.other(L("“\(run.input.lastPathComponent)” is already smaller than the target size."),
                                            detail: "input \(inputSize) ≤ target \(target)")
            }
            let budget = Self.budget(targetBytes: target, duration: info.duration, hasAudio: info.hasAudio)
            guard budget.videoBps >= 20_000 else {
                throw ConversionError.other(L("That target is too small for a video this long. Try a larger size."),
                                            detail: "video budget \(budget.videoBps) bps")
            }
            // Very low bits per pixel looks blocky at full size; drop resolution instead.
            if filters.isEmpty, let auto = Self.autoShortEdge(video, videoBps: budget.videoBps),
               let s = Self.scaleFilter(video, shortEdge: auto) { filters.append(s) }
            let enc = MediaEncoders.twoPassVideo(container: container, source: video, bitRate: budget.videoBps)
            let audio = info.hasAudio ? MediaEncoders.audio(container: container, source: info.audio, bitRateKbps: budget.audioKbps) : []
            let scratch = try run.makeScratch()
            defer { run.cleanup(scratch) }
            let log = scratch.appendingPathComponent("pass").path
            let vf = filters.isEmpty ? [] : ["-vf", filters.joined(separator: ",")]
            let pass1 = ["-i", run.input.path, "-map", "0:\(video.index)"] + vf + enc.args
                + ["-pass", "1", "-passlogfile", log, "-an", "-f", "null", "-"]
            try await run.ffmpeg.run(pass1, duration: info.duration, progress: context.progress.scaled(0...0.45))
            let pass2 = ["-i", run.input.path] + maps + vf + enc.args + ["-pass", "2", "-passlogfile", log] + audio + meta
                + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(pass2, duration: info.duration, progress: context.progress.scaled(0.45...1))
            return ConversionOutput(try run.requireOutput(out))
        }

        let preset = Self.preset(run.options.string(OptionKey.videoQuality, default: "balanced"))
        let cap = info.videoBitRate.map { Int(Double($0) * preset.capFraction) }
        let attempts = MediaEncoders.video(container: container, source: video, quality: preset.quality, maxRate: cap)
        let srcAudioKbps = info.audio?.bitRate.map { $0 / 1000 } ?? preset.audioKbps
        let audio = info.hasAudio ? MediaEncoders.audio(container: container, source: info.audio,
                                                       bitRateKbps: max(48, min(preset.audioKbps, srcAudioKbps))) : []
        let vf = filters.isEmpty ? [] : ["-vf", filters.joined(separator: ",")]
        try await run.runAttempts(attempts, removing: { [out] }) { enc in
            let args = ["-i", run.input.path] + maps + vf + enc.args + audio + meta + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
        }
        let result = try run.requireOutput(out)
        if MediaRun.fileSize(result) >= inputSize {
            try? FileManager.default.removeItem(at: result)
            throw ConversionError.other(L("“\(run.input.lastPathComponent)” is already well compressed. Try the Small file preset or a lower resolution."),
                                        detail: "output not smaller than input (\(inputSize) bytes)")
        }
        return ConversionOutput(result)
    }

    /// Short edge to scale to when the bitrate is too thin for the source size.
    static func autoShortEdge(_ video: MediaInfo.Video, videoBps: Int) -> Int? {
        let fps = video.frameRate > 0 ? video.frameRate : 30
        let w = Double(video.displayWidth), h = Double(video.displayHeight)
        func bpp(_ short: Double) -> Double {
            let scale = short / min(w, h)
            return Double(videoBps) / (w * scale * h * scale * fps)
        }
        let minimum = 0.03
        guard bpp(min(w, h)) < minimum else { return nil }
        for edge in [1080, 720, 540, 480, 360] where Double(edge) < min(w, h) {
            if bpp(Double(edge)) >= minimum { return edge }
        }
        return min(w, h) > 360 ? 360 : nil
    }
}
