import Foundation

// Tools 19–22: trim audio, normalize, bleep, change channels. Outputs keep
// the input's container and codec family (bitrate matched to the source).

private extension MediaRun {
    /// Maps for audio-file tools: the first audio stream, plus cover art copied.
    func audioMaps(_ info: MediaInfo, audioLabel: String? = nil) -> [String] {
        var m = ["-map", audioLabel ?? "0:\(info.audio?.index ?? 0)"]
        // Cover art is an attached-picture video stream; keep it untouched.
        m += ["-map", "0:v?", "-c:v", "copy"]
        return m
    }
}

/// 19. Trim audio. Stream copy for MP3/AAC (cuts land on ~23–26 ms frame
/// boundaries, no generation loss); everything else re-encodes in its own codec,
/// sample-exact.
public struct TrimAudioRunner: ToolRunner {
    public let id = ToolIDs.trimAudio
    public init() {}

    public static func canCopy(codec: String, container: MediaContainer) -> Bool {
        (codec == "mp3" && container == .mp3) || (codec == "aac" && [.m4a, .mp4, .mov, .caf].contains(container))
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let audio = info.audio else { throw ConversionError.noAudio(run.input) }
        let container = try run.container(of: run.input)
        guard let r = MediaTimes.range(run.options.string("range", default: "")), r.lowerBound < info.duration else {
            throw ConversionError.invalidOption("range")
        }
        let start = r.lowerBound, end = min(r.upperBound, info.duration)
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        let meta = MediaEncoders.metadata(request.metadata, info: info)
        let copy = run.options.bool(OptionKey.lossless, default: true) && Self.canCopy(codec: audio.codec, container: container)
        var args = start > 0 ? ["-ss", MediaTimes.arg(start)] : []
        args += ["-i", run.input.path, "-t", MediaTimes.arg(end - start)] + run.audioMaps(info)
        args += copy ? ["-c:a", "copy"] : MediaEncoders.audio(container: container, source: audio)
        args += meta + MediaRun.muxerFlags(container) + [out.path]
        try await run.ffmpeg.run(args, duration: end - start, progress: context.progress)
        return ConversionOutput(try run.requireOutput(out))
    }
}

/// Integrated loudness measurement from ffmpeg's loudnorm filter.
public struct LoudnessMeasurement: Sendable, Equatable {
    public let integrated: Double
    public let truePeak: Double
    public let range: Double
    public let threshold: Double
    public let offset: Double

    /// Parses the last JSON object loudnorm prints (`print_format=json`).
    public static func parse(_ log: String) -> LoudnessMeasurement? {
        guard let close = log.lastIndex(of: "}"), let open = log[..<close].lastIndex(of: "{") else { return nil }
        let json = Data(log[open...close].utf8)
        guard let obj = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
        func v(_ k: String) -> Double? {
            if let s = obj[k] as? String { return Double(s) }
            return obj[k] as? Double
        }
        guard let i = v("input_i"), let tp = v("input_tp"), let lra = v("input_lra"), let th = v("input_thresh") else { return nil }
        return LoudnessMeasurement(integrated: i, truePeak: tp, range: lra, threshold: th, offset: v("target_offset") ?? 0)
    }

    /// Runs loudnorm in analysis mode over the first audio stream of `url`.
    static func measure(_ url: URL, stream: Int, target: Double, truePeak: Double, ffmpeg: FFmpeg,
                        duration: Double, progress: ProgressSink) async throws -> LoudnessMeasurement {
        let af = "loudnorm=I=\(target):TP=\(truePeak):LRA=11:print_format=json"
        // A later -loglevel overrides FFmpeg.run's "error" so loudnorm's report reaches stderr.
        let r = try await ffmpeg.run(["-loglevel", "info", "-i", url.path, "-map", "0:\(stream)", "-af", af, "-f", "null", "-"],
                                     duration: duration, progress: progress)
        guard let m = parse(r.stderr) else {
            throw ConversionError.other(L("Couldn’t measure the loudness of “\(url.lastPathComponent)”."), detail: String(r.stderr.suffix(2000)))
        }
        return m
    }
}

/// 20. Normalize loudness (EBU R128) in two passes: measure, then a linear
/// gain to the target. Video streams are copied untouched.
public struct NormalizeAudioRunner: ToolRunner {
    public let id = ToolIDs.normalizeAudio
    public init() {}

    static let truePeak = -1.0

    /// Narrows audio encoder options to the first output audio stream, so
    /// passthrough tracks keep their own codec settings.
    static func firstStream(_ args: [String]) -> [String] {
        let narrowed = ["-c:a": "-c:a:0", "-b:a": "-b:a:0", "-ar": "-ar:a:0", "-sample_fmt": "-sample_fmt:a:0"]
        return args.map { narrowed[$0] ?? $0 }
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let audio = info.audio else { throw ConversionError.noAudio(run.input) }
        let container = try run.container(of: run.input)
        let target = min(-5, max(-70, run.options.double("target", default: -16)))
        let m = try await LoudnessMeasurement.measure(run.input, stream: audio.index, target: target, truePeak: Self.truePeak,
                                                      ffmpeg: run.ffmpeg, duration: info.duration,
                                                      progress: context.progress.scaled(0...0.4))
        guard m.integrated.isFinite, m.integrated > -70 else {
            throw ConversionError.other(L("“\(run.input.lastPathComponent)” is silent, so there’s nothing to normalize."),
                                        detail: "input_i \(m.integrated)")
        }
        // A target LRA below the source's forces loudnorm into dynamic mode; keep it linear.
        let lra = min(50, max(11, (m.range + 1).rounded(.up)))
        let sr = audio.sampleRate > 0 ? audio.sampleRate : 48000
        let af = "loudnorm=I=\(target):TP=\(Self.truePeak):LRA=\(lra):measured_I=\(m.integrated):measured_TP=\(m.truePeak)"
            + ":measured_LRA=\(m.range):measured_thresh=\(m.threshold):offset=\(m.offset):linear=true:print_format=none,aresample=\(sr)"
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        var args = ["-i", run.input.path, "-filter_complex", "[0:\(audio.index)]\(af)[norm]"]
        if info.hasVideo {
            if let v = info.video { args += ["-map", "0:\(v.index)", "-c:v", "copy"] }
        } else {
            args += ["-map", "0:v?", "-c:v", "copy"]
        }
        args += ["-map", "[norm]"] + Self.firstStream(MediaEncoders.audio(container: container, source: audio))
        // Other audio tracks (commentary, languages) pass through.
        for (n, other) in info.audios.dropFirst().enumerated() { args += ["-map", "0:\(other.index)", "-c:a:\(n + 1)", "copy"] }
        if info.subtitleCount > 0, [.mkv, .mp4, .mov, .m4v, .webm].contains(container) { args += ["-map", "0:s?", "-c:s", "copy"] }
        args += MediaEncoders.metadata(request.metadata, info: info) + MediaRun.muxerFlags(container) + [out.path]
        try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress.scaled(0.4...1))
        return ConversionOutput(try run.requireOutput(out))
    }
}

/// 21. Bleep: mute ranges, optionally replacing them with a 1 kHz tone. Edges
/// get a 5 ms ramp so cuts don't click.
public struct BleepAudioRunner: ToolRunner {
    public let id = ToolIDs.bleepAudio
    public init() {}

    public static let toneAmplitude = 0.3
    static let ramp = 0.005

    /// The aeval expression for `ranges` (seconds). Pure, for tests.
    public static func expression(ranges: [ClosedRange<Double>], tone: Bool) -> String {
        let r = MediaTimes.arg(ramp)
        let mask = ranges.map { range in
            let s = MediaTimes.arg(range.lowerBound), e = MediaTimes.arg(range.upperBound)
            return "clip((t-\(s))/\(r),0,1)*clip((\(e)-t)/\(r),0,1)"
        }.joined(separator: "+")
        let m = "(\(mask))"
        return tone ? "val(ch)*(1-\(m))+\(toneAmplitude)*sin(2*PI*1000*t)*\(m)" : "val(ch)*(1-\(m))"
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let audio = info.audio else { throw ConversionError.noAudio(run.input) }
        let container = try run.container(of: run.input)
        let ranges = MediaTimes.ranges(run.options.string("ranges", default: "")).filter { $0.lowerBound < info.duration }
        guard !ranges.isEmpty else {
            throw ConversionError.other(L("Mark at least one part of the audio to bleep."), detail: "no ranges")
        }
        let tone = run.options.string("style", default: "tone") != "silence"
        let expr = Self.expression(ranges: ranges, tone: tone)
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        var args = ["-i", run.input.path, "-filter_complex", "[0:\(audio.index)]asetpts=PTS-STARTPTS,aeval=exprs='\(expr)':c=same[b]"]
        args += run.audioMaps(info, audioLabel: "[b]") + MediaEncoders.audio(container: container, source: audio)
        args += MediaEncoders.metadata(request.metadata, info: info) + MediaRun.muxerFlags(container) + [out.path]
        try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
        return ConversionOutput(try run.requireOutput(out))
    }
}

/// 22. Change channels: mono downmix, stereo upmix (duplicate), swap L/R.
public struct ChannelsAudioRunner: ToolRunner {
    public let id = ToolIDs.channelsAudio
    public init() {}

    /// Filter for `mode` given the source channel count, or a human error.
    public static func filter(mode: String, channels: Int) -> Result<String, ConversionError> {
        switch (mode, channels) {
        case ("mono", 1):
            return .failure(.other(L("This file is already mono."), detail: "mono→mono"))
        case ("mono", 2):
            return .success("pan=mono|c0=0.5*c0+0.5*c1")
        case ("mono", _):
            return .success("aresample=ochl=mono")
        case ("stereo", 1):
            return .success("pan=stereo|c0=c0|c1=c0")
        case ("stereo", 2):
            return .failure(.other(L("This file is already stereo."), detail: "stereo→stereo"))
        case ("stereo", _):
            return .success("aresample=ochl=stereo")
        case ("swap", 2):
            return .success("pan=stereo|c0=c1|c1=c0")
        case ("swap", _):
            return .failure(.other(L("Swapping left and right needs a stereo file."), detail: "swap with \(channels) channels"))
        default:
            return .failure(.invalidOption("mode"))
        }
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let audio = info.audio else { throw ConversionError.noAudio(run.input) }
        let container = try run.container(of: run.input)
        let af = try Self.filter(mode: run.options.string("mode", default: "mono"), channels: audio.channels).get()
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        var args = ["-i", run.input.path, "-filter_complex", "[0:\(audio.index)]\(af)[c]"]
        args += run.audioMaps(info, audioLabel: "[c]") + MediaEncoders.audio(container: container, source: audio)
        args += MediaEncoders.metadata(request.metadata, info: info) + MediaRun.muxerFlags(container) + [out.path]
        try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
        return ConversionOutput(try run.requireOutput(out))
    }
}
