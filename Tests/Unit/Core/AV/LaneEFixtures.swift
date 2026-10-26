import AVFoundation
import Foundation
import XCTest
@testable import AnyfmtCore

/// Carries a non-Sendable value into a `@Sendable` callback (tests only).
final class UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// Shared test support for lane E: finds the bundled engines, generates the
/// lane fixtures once per run (via Tests/Fixtures/lanes/av.sh), and runs
/// conversions into throwaway directories.
enum LaneE {
    /// Repository root of this checkout (worktree or main).
    static let repoRoot: URL = {
        var u = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { u.deleteLastPathComponent() } // AV, Core, Unit, Tests, <root>
        return u
    }()

    /// `Engines/dist/Helpers` from ANYFMT_ENGINES_DIR, else the nearest checkout that has it
    /// (worktrees share the main checkout's built engines).
    static let helpers: URL? = {
        let env = ProcessInfo.processInfo.environment
        for key in ["ANYFMT_ENGINES_DIR", "TEST_RUNNER_HALO_ENGINES_DIR"] {
            if let d = env[key], !d.isEmpty {
                let h = URL(fileURLWithPath: d).appendingPathComponent("Helpers")
                if FileManager.default.isExecutableFile(atPath: h.appendingPathComponent("ffmpeg").path) { return h }
            }
        }
        var dir = repoRoot
        for _ in 0..<6 {
            let h = dir.appendingPathComponent("Engines/dist/Helpers")
            if FileManager.default.isExecutableFile(atPath: h.appendingPathComponent("ffmpeg").path) { return h }
            dir.deleteLastPathComponent()
        }
        return nil
    }()

    static var locator: EngineLocator { EngineLocator(helperDirectories: helpers.map { [$0] } ?? []) }
    static var context: EngineContext { EngineContext(locator: locator) }

    static func requireEngines(file: StaticString = #filePath, line: UInt = #line) throws -> EngineLocator {
        guard helpers != nil else { throw XCTSkip("bundled ffmpeg not found (set ANYFMT_ENGINES_DIR)") }
        return locator
    }

    /// Generated once per test run; nil if generation failed (message in `fixtureError`).
    private static let generated: (URL?, String?) = {
        guard let helpers else { return (nil, "no engines") }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-laneE-fixtures-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.removeItem(at: out)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [repoRoot.appendingPathComponent("Tests/Fixtures/lanes/av.sh").path]
        var env = ProcessInfo.processInfo.environment
        env["OUT"] = out.path
        env["FFMPEG"] = helpers.appendingPathComponent("ffmpeg").path
        env["FFPROBE"] = helpers.appendingPathComponent("ffprobe").path
        p.environment = env
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        do { try p.run() } catch { return (nil, "\(error)") }
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return (nil, String(decoding: errData, as: UTF8.self)) }
        return (out, nil)
    }()

    static func fixtures(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        _ = try requireEngines()
        guard let dir = generated.0 else {
            XCTFail("fixture generation failed: \(generated.1 ?? "?")", file: file, line: line)
            throw XCTSkip("no fixtures")
        }
        return dir
    }

    static func fixture(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let url = try fixtures(file: file, line: line).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("missing fixture \(name)", file: file, line: line)
            throw XCTSkip("missing fixture \(name)")
        }
        return url
    }

    static func tempDirectory() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-laneE-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Runs one engine conversion into a fresh directory and returns the output.
    static func convert(_ input: URL, to: FormatID, engine: any ConversionEngine = FFmpegAVEngine(),
                        from: FormatID? = nil, options: [String: OptionValue] = [:], schema: OptionsSchema? = nil,
                        metadata: MetadataPolicy = .keep, context: EngineContext? = nil) async throws -> URL {
        let src = from ?? Formats.detect(input) ?? FormatID(input.pathExtension)
        let defaults = schema ?? AVRoutes.rows.first { $0.from == src && $0.to == to }?.schema ?? .none
        let request = ConversionRequest(inputs: [input], from: src, to: to,
                                        options: defaults.defaults.merging(OptionValues(options)),
                                        outputDirectory: try tempDirectory(), baseName: "out", metadata: metadata)
        let out = try await engine.convert(request, context: context ?? self.context)
        guard let file = out.files.first else { throw ConversionError.outputMissing("none") }
        return file
    }

    static func probe(_ url: URL) async throws -> AVInputFacts {
        try await AVProbe.facts(for: url, locator: locator)
    }

    /// Raw ffprobe JSON (format + streams) for assertions on fields facts don't keep.
    static func probeJSON(_ url: URL) async throws -> [String: Any] {
        guard let exe = locator.ffprobe else { throw XCTSkip("no ffprobe") }
        let r = try await ProcessRunner.run(exe, ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", url.path])
        return (try JSONSerialization.jsonObject(with: r.stdout) as? [String: Any]) ?? [:]
    }

    static func formatTags(_ url: URL) async throws -> [String: String] {
        let json = try await probeJSON(url)
        return ((json["format"] as? [String: Any])?["tags"] as? [String: String]) ?? [:]
    }

    /// A synthetic H.264 + AAC clip (testsrc2 + tone) of any length, for slow-path tests.
    static func makeClip(seconds: Int, size: String, ext: String = "mov") async throws -> URL {
        let out = try tempDirectory().appendingPathComponent("clip.\(ext)")
        try await ffmpeg(["-filter_complex", "testsrc2=size=\(size):rate=30:duration=\(seconds)[v];sine=frequency=440:sample_rate=48000:duration=\(seconds)[a]",
                          "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
                          "-c:a", "aac_at", out.path])
        return out
    }

    /// An iPhone-style MOV: real QuickTime `mdta` metadata (location, make, model,
    /// software, capture date, title), written by AVFoundation as a camera would.
    static func makeAppleMetadataMovie() async throws -> URL {
        let out = try tempDirectory().appendingPathComponent("iphone.mov")
        let asset = AVURLAsset(url: try fixture("sample.mov"))
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { throw XCTSkip("no export session") }
        func item(_ id: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
            let m = AVMutableMetadataItem()
            m.identifier = id
            m.value = value as NSString
            m.dataType = kCMMetadataBaseDataType_UTF8 as String
            return m
        }
        s.outputURL = out
        s.outputFileType = .mov
        s.metadata = [
            item(.quickTimeMetadataLocationISO6709, "+37.3349-122.0090+010.000/"),
            item(.quickTimeMetadataMake, "Apple"),
            item(.quickTimeMetadataModel, "iPhone 15 Pro"),
            item(.quickTimeMetadataSoftware, "17.0"),
            item(.quickTimeMetadataCreationDate, "2024-05-01T12:00:00+0200"),
            item(.quickTimeMetadataTitle, "Private trip"),
        ]
        let box = UncheckedBox(s)
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in box.value.exportAsynchronously { c.resume() } }
        guard s.status == .completed else { throw XCTSkip("could not build the iPhone-style fixture: \(s.status.rawValue)") }
        return out
    }

    /// What Apple's own reader sees: identifier → string value, plus "creationDate" (UTC ISO 8601).
    static func appleMetadata(_ url: URL) async throws -> [String: String] {
        let asset = AVURLAsset(url: url)
        var out: [String: String] = [:]
        for i in try await asset.load(.metadata) {
            if let id = i.identifier?.rawValue, let v = try? await i.load(.stringValue) { out[id] = v }
        }
        if let item = try await asset.load(.creationDate), let date = try? await item.load(.dateValue) {
            let f = ISO8601DateFormatter()
            out["creationDate"] = f.string(from: date)
        }
        return out
    }

    /// Runs the bundled ffmpeg directly (test media generation).
    static func ffmpeg(_ args: [String]) async throws {
        guard let exe = locator.ffmpeg else { throw XCTSkip("no ffmpeg") }
        _ = try await ProcessRunner.run(exe, ["-hide_banner", "-nostdin", "-loglevel", "error", "-y"] + args)
    }
}
