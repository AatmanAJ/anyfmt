import Foundation

/// Every tool runner shipped in this build.
///   ImageToolRunners: lane G1 (image tools 1–11, metadata 23–24)
///   MediaToolRunners: lane G2 (video 12–18, audio 19–22, PDF 25–26)
public enum ToolRunners {
    public static var all: [any ToolRunner] { ImageToolRunners.all + MediaToolRunners.all }
}
