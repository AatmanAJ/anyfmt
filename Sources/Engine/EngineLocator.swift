import Foundation

/// Finds bundled engine binaries (ffmpeg, ffprobe, resvg) and optional packs.
///
/// Search order:
/// 1. `ANYFMT_ENGINES_DIR` environment variable (dev, tests, worktrees). Points at
///    a directory containing `Helpers/` (Engines/dist layout).
/// 2. The app bundle: `<App>.app/Contents/Helpers`.
/// 3. Next to the running executable (the CLI lives in Contents/Helpers).
/// 4. Walking up from the executable to a source checkout's `Engines/dist`.
public struct EngineLocator: Sendable {
    public let helperDirectories: [URL]

    public init(helperDirectories: [URL]) { self.helperDirectories = helperDirectories }

    public static let shared = EngineLocator(helperDirectories: defaultDirectories())

    static func defaultDirectories() -> [URL] {
        var dirs: [URL] = []
        let env = ProcessInfo.processInfo.environment
        if let d = env["ANYFMT_ENGINES_DIR"], !d.isEmpty {
            dirs.append(URL(fileURLWithPath: d).appendingPathComponent("Helpers"))
        }
        let bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "app" {
            dirs.append(bundle.appendingPathComponent("Contents/Helpers"))
        }
        let exe = URL(fileURLWithPath: CommandLine.arguments.first ?? "").resolvingSymlinksInPath().deletingLastPathComponent()
        dirs.append(exe)
        // Source checkout fallback: …/Codename_Halo/Engines/dist/Helpers
        var dir = exe
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Engines/dist/Helpers")
            if FileManager.default.fileExists(atPath: candidate.path) { dirs.append(candidate); break }
            dir.deleteLastPathComponent()
        }
        return dirs
    }

    /// Absolute URL of a bundled helper, or nil if not shipped in this build.
    public func url(for tool: String) -> URL? {
        for d in helperDirectories {
            let u = d.appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: u.path) { return u }
        }
        return nil
    }

    public var ffmpeg: URL? { url(for: "ffmpeg") }
    public var ffprobe: URL? { url(for: "ffprobe") }
    public var resvg: URL? { url(for: "resvg") }

    /// Optional packs are installed by the user into Application Support.
    public static var packsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(Brand.name).appendingPathComponent("Packs")
    }

    /// `soffice` from the Office pack, if the user installed it.
    public var officePackSoffice: URL? {
        let u = Self.packsDirectory.appendingPathComponent("LibreOffice.app/Contents/MacOS/soffice")
        return FileManager.default.isExecutableFile(atPath: u.path) ? u : nil
    }

    /// `pandoc` from the pandoc pack, if the user installed it.
    public var pandocPack: URL? {
        let u = Self.packsDirectory.appendingPathComponent("pandoc/bin/pandoc")
        return FileManager.default.isExecutableFile(atPath: u.path) ? u : nil
    }
}
