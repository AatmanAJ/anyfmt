import Foundation

/// Lane G2's tool runners: video 12–18, audio 19–22, PDF 25–26.
public enum MediaToolRunners {
    public static let all: [any ToolRunner] = [
        TrimVideoRunner(),
        CropVideoRunner(),
        SpeedVideoRunner(),
        SplitVideoRunner(),
        JoinVideoRunner(),
        SnapshotVideoRunner(),
        CompressVideoRunner(),
        TrimAudioRunner(),
        NormalizeAudioRunner(),
        BleepAudioRunner(),
        ChannelsAudioRunner(),
        OrganizePDFRunner(),
        CompressPDFRunner(),
    ]
}
