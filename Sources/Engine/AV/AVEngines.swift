import Foundation

/// Lane E: audio and video engines.
public enum AVEngines {
    public static let all: [any ConversionEngine] = [FFmpegAVEngine(), AVFoundationEngine()]
}
