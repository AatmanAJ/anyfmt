import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Runs the built `anyfmt` binary for the CLI and MCP golden tests, and owns the
/// golden-file comparison. Agents parse this output, so it must never change
/// by accident. Re-record on purpose with
/// `TEST_RUNNER_HALO_RECORD_GOLDEN=1 make test-unit` (xcodebuild strips the prefix).
enum AnyfmtCLI {
    static let goldenDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("CLIGolden")

    static var binary: URL {
        Bundle(for: Marker.self).bundleURL.deletingLastPathComponent().appendingPathComponent("anyfmt")
    }

    static var isBuilt: Bool { FileManager.default.isExecutableFile(atPath: binary.path) }

    static var recording: Bool { ProcessInfo.processInfo.environment["ANYFMT_RECORD_GOLDEN"] == "1" }

    private final class Marker {}

    /// A clean environment, as an agent's shell would have. The test runner's
    /// own variables (OS_ACTIVITY_DT_MODE mirrors system logs to stderr) stay out.
    static func environment(_ extra: [String: String] = [:]) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var env = ["NO_COLOR": "1", "PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory()]
        env["ANYFMT_ENGINES_DIR"] = inherited["ANYFMT_ENGINES_DIR"]
        env.merge(extra) { _, new in new }
        return env
    }

    struct Result {
        let out: String
        let err: String
        let code: Int32
    }

    static func run(_ args: [String], env: [String: String] = [:], stdin: Data? = nil) throws -> Result {
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        p.environment = environment(env)
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        let input = Pipe()
        p.standardInput = stdin == nil ? FileHandle.nullDevice : input
        try p.run()
        if let stdin {
            input.fileHandleForWriting.write(stdin)
            try input.fileHandleForWriting.close()
        }
        // Drain stderr on another thread so a full pipe never blocks the child.
        let errData = DataBox()
        let group = DispatchGroup()
        group.enter()
        let errHandle = err.fileHandleForReading
        DispatchQueue.global().async {
            errData.data = errHandle.readDataToEndOfFile()
            group.leave()
        }
        let o = out.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        p.waitUntilExit()
        return Result(out: String(decoding: o, as: UTF8.self), err: String(decoding: errData.data, as: UTF8.self), code: p.terminationStatus)
    }

    final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    /// Makes nondeterministic text stable: version, temp paths, UUIDs, dates.
    static func normalise(_ s: String, paths: [URL: String] = [:]) -> String {
        var t = s
        // Longest first so a sub-folder wins over its parent.
        for (url, token) in paths.sorted(by: { $0.key.path.count > $1.key.path.count }) {
            for variant in pathVariants(url) { t = t.replacingOccurrences(of: variant, with: token) }
        }
        if let v = version {
            t = t.replacingOccurrences(of: "anyfmt \(v)", with: "anyfmt <version>")
            t = t.replacingOccurrences(of: "\"\(v)\"", with: "\"<version>\"")
            t = t.replacingOccurrences(of: #"\"\#(v)\""#, with: #"\"<version>\""#)
        }
        t = t.replacingOccurrences(of: #"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"#, with: "<uuid>", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"#, with: "<date>", options: .regularExpression)
        // DocumentPDF's default page size follows the Mac's region.
        t = t.replacingOccurrences(of: #"("default" ?: ?)"(a4|letter)""#, with: "$1\"<region-page-size>\"", options: .regularExpression)
        return t
    }

    /// The binary's marketing version (from `anyfmt version --json`), cached.
    static let version: String? = {
        guard isBuilt, let r = try? run(["version", "--json"]),
              let obj = try? JSONSerialization.jsonObject(with: Data(r.out.utf8)) as? [String: Any] else { return nil }
        return obj["version"] as? String
    }()

    static func pathVariants(_ url: URL) -> [String] {
        let p = url.standardizedFileURL.path
        var v = [url.resolvingSymlinksInPath().path, p]
        if p.hasPrefix("/private/") { v.append(String(p.dropFirst("/private".count))) } else { v.append("/private" + p) }
        return Array(Set(v)).sorted { $0.count > $1.count }
    }

    /// Compares `actual` with Tests/CLIGolden/<name>.txt (or records it).
    static func check(_ name: String, _ actual: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = goldenDir.appendingPathComponent("\(name).txt")
        if recording {
            try FileManager.default.createDirectory(at: goldenDir, withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        let expected = try String(contentsOf: url, encoding: .utf8)
        if actual != expected {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-golden-\(name).txt")
            try? actual.write(to: tmp, atomically: true, encoding: .utf8)
            XCTFail("Output for golden “\(name)” changed. Diff \(url.path) against \(tmp.path), or re-record with TEST_RUNNER_HALO_RECORD_GOLDEN=1.", file: file, line: line)
        }
    }

    // MARK: Fixtures

    /// A fresh scratch folder (resolved, so paths normalise reliably).
    static func scratch(_ name: String) throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-cli-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u.resolvingSymlinksInPath()
    }

    /// A small deterministic PNG: a 48×32 two-colour gradient.
    static func makePNG(at url: URL, width: Int = 48, height: Int = 32) throws {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        for x in 0..<width {
            ctx.setFillColor(CGColor(srgbRed: CGFloat(x) / CGFloat(width), green: 0.4, blue: 0.8, alpha: 1))
            ctx.fill(CGRect(x: x, y: 0, width: 1, height: height))
        }
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// A 0.1 s 8 kHz mono 16-bit WAV of a square wave.
    static func makeWAV(at url: URL) throws {
        let rate = 8000, samples = 800
        var pcm = Data()
        for i in 0..<samples {
            let v: Int16 = (i / 20) % 2 == 0 ? 8000 : -8000
            withUnsafeBytes(of: v.littleEndian) { pcm.append(contentsOf: $0) }
        }
        func u32(_ v: Int) -> Data { withUnsafeBytes(of: UInt32(v).littleEndian) { Data($0) } }
        func u16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
        var d = Data("RIFF".utf8) + u32(36 + pcm.count) + Data("WAVE".utf8)
        d += Data("fmt ".utf8) + u32(16) + u16(1) + u16(1) + u32(rate) + u32(rate * 2) + u16(2) + u16(16)
        d += Data("data".utf8) + u32(pcm.count) + pcm
        try d.write(to: url)
    }

    /// An engines folder whose ffmpeg always fails (exit 1) and whose ffprobe is
    /// the real one, so "engine failed" (exit 5) can be triggered on purpose.
    static func failingEngines(in dir: URL) throws -> URL? {
        guard let real = ProcessInfo.processInfo.environment["ANYFMT_ENGINES_DIR"], !real.isEmpty else { return nil }
        let realProbe = URL(fileURLWithPath: real).appendingPathComponent("Helpers/ffprobe")
        guard FileManager.default.isExecutableFile(atPath: realProbe.path) else { return nil }
        let helpers = dir.appendingPathComponent("Helpers", isDirectory: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        let ffmpeg = helpers.appendingPathComponent("ffmpeg")
        try "#!/bin/sh\necho 'simulated ffmpeg failure' >&2\nexit 1\n".write(to: ffmpeg, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffmpeg.path)
        try FileManager.default.createSymbolicLink(at: helpers.appendingPathComponent("ffprobe"), withDestinationURL: realProbe)
        return dir
    }
}
