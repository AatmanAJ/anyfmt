import Foundation

/// Lane E: subtitle rows. Pure Swift, no bundled engine.
public enum SubtitleRoutes {
    public static let rows: [Capability] = [
        Capability(Formats.srt, Formats.vtt, EngineIDs.subtitles, priority: 100, cost: 0.1),
        Capability(Formats.vtt, Formats.srt, EngineIDs.subtitles, priority: 100, cost: 0.1),
        // A transcript is a dead end: never an intermediate hop.
        Capability(Formats.srt, Formats.txt, EngineIDs.subtitles, schema: StandardSchemas.subtitleText,
                   priority: 100, cost: 0.1, flags: [.terminalOnly, .lossyStructure]),
        Capability(Formats.vtt, Formats.txt, EngineIDs.subtitles, schema: StandardSchemas.subtitleText,
                   priority: 100, cost: 0.1, flags: [.terminalOnly, .lossyStructure]),
    ]
}
