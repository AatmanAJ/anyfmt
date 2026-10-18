import Foundation

/// Lane E: audio and video rows.
///
/// - ffmpeg (priority 90) covers every pair: audio ⇄ audio, video ⇄ video,
///   video → GIF, video → audio extraction, and GIF → video as direct rows
///   (the router only lets still ⇄ time-based cross in one direct step).
/// - AVFoundation passthrough (priority 110) wins MOV ⇄ MP4 ⇄ M4V: same
///   speed as an ffmpeg remux, but keeps QuickTime tracks and metadata intact.
///   It hands anything needing a re-encode to ffmpeg.
/// - AVFoundation → M4A (priority 40) is a fallback for builds without ffmpeg.
public enum AVRoutes {
    static let audioInputs: [FormatID] = [Formats.mp3, Formats.m4a, Formats.wav, Formats.flac, Formats.ogg,
                                          Formats.opus, Formats.aiff, Formats.caf, Formats.wma]
    static let audioOutputs: [FormatID] = [Formats.mp3, Formats.m4a, Formats.wav, Formats.flac, Formats.ogg,
                                           Formats.opus, Formats.aiff, Formats.caf]
    static let videoInputs: [FormatID] = [Formats.mp4, Formats.mov, Formats.mkv, Formats.webm, Formats.avi, Formats.wmv, Formats.m4v]
    static let videoOutputs: [FormatID] = videoInputs
    static let gifTargets: [FormatID] = [Formats.mp4, Formats.mov, Formats.webm, Formats.mkv]

    static func audioSchema(_ to: FormatID) -> OptionsSchema {
        AVCodecTables.losslessAudio.contains(to) ? StandardSchemas.audioLossless : StandardSchemas.audioLossy
    }

    static func audioFlags(_ to: FormatID) -> CapabilityFlags {
        AVCodecTables.losslessAudio.contains(to) ? .lossless : []
    }

    public static let rows: [Capability] = ffmpegRows + avFoundationRows

    static let ffmpegRows: [Capability] = {
        var rows: [Capability] = []
        for to in audioOutputs {
            rows += Capability.grid(audioInputs, [to], EngineIDs.ffmpeg, schema: audioSchema,
                                    priority: 90, cost: 1, flags: audioFlags(to))
        }
        rows += Capability.grid(videoInputs, videoOutputs, EngineIDs.ffmpeg, schema: { _ in StandardSchemas.video },
                                priority: 90, cost: 3)
        rows += videoInputs.map { Capability($0, Formats.gif, EngineIDs.ffmpeg, schema: StandardSchemas.gif, priority: 90, cost: 3) }
        for to in audioOutputs {
            rows += Capability.grid(videoInputs, [to], EngineIDs.ffmpeg, schema: audioSchema,
                                    priority: 90, cost: 1, flags: audioFlags(to))
        }
        rows += gifTargets.map { Capability(Formats.gif, $0, EngineIDs.ffmpeg, schema: StandardSchemas.video, priority: 90, cost: 2) }
        return rows
    }()

    static let avFoundationRows: [Capability] = {
        let remux = Array(AVFoundationEngine.remuxFormats).sorted()
        var rows = Capability.grid(remux, remux, EngineIDs.avFoundation, schema: { _ in StandardSchemas.video },
                                   priority: 110, cost: 0.5)
        let m4aSources: [FormatID] = [Formats.mp3, Formats.wav, Formats.aiff, Formats.caf, Formats.flac,
                                      Formats.mp4, Formats.mov, Formats.m4v]
        rows += m4aSources.map { Capability($0, Formats.m4a, EngineIDs.avFoundation, schema: StandardSchemas.audioLossy, priority: 40, cost: 1) }
        return rows
    }()

    /// Queue class for a hop of this lane: video encodes share the one
    /// media engine, so they run one at a time; audio is plain CPU work.
    public static func resourceClass(for hop: Capability, options: OptionValues) -> ResourceClass {
        let videoTarget = AVCodecTables.videoContainers.contains(hop.to) || hop.to == Formats.gif
        guard videoTarget else { return .cpu }
        return options.bool(OptionKey.hardware, default: true) ? .videoToolbox : .cpu
    }
}
