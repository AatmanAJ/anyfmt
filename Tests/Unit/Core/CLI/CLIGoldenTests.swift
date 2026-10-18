import Foundation
import XCTest

/// Runs the built `halo` binary and compares stdout, stderr and the exit code
/// with Tests/CLIGolden. Agents parse this output, so it must never change by
/// accident. Re-record on purpose with `TEST_RUNNER_HALO_RECORD_GOLDEN=1`.
final class CLIGoldenTests: XCTestCase {
    private var scratch: URL!
    private var support: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(HaloCLI.isBuilt, "halo not built next to the tests")
        scratch = try HaloCLI.scratch("golden")
        support = scratch.appendingPathComponent("support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch { try? FileManager.default.removeItem(at: scratch) }
    }

    private var tokens: [URL: String] { [scratch: "<tmp>"] }

    /// Runs one command with a private support dir (presets, recents).
    @discardableResult
    private func run(_ args: [String], env: [String: String] = [:]) throws -> HaloCLI.Result {
        try HaloCLI.run(args, env: ["HALO_SUPPORT_DIR": support.path].merging(env) { _, n in n })
    }

    private func render(_ args: [String], _ r: HaloCLI.Result, filterOut: (String) -> Bool = { $0.contains(#""event":"progress""#) }) -> String {
        let shown = args.map { arg in HaloCLI.normalise(arg, paths: tokens) }.joined(separator: " ")
        let stdout = r.out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !filterOut($0) }.joined(separator: "\n")
        return "$ halo \(shown)\nexit: \(r.code)\n--- stdout\n\(HaloCLI.normalise(stdout, paths: tokens))--- stderr\n\(HaloCLI.normalise(r.err, paths: tokens))"
    }

    private func check(_ name: String, _ args: [String], env: [String: String] = [:], expect code: Int32? = nil,
                       file: StaticString = #filePath, line: UInt = #line) throws {
        let r = try run(args, env: env)
        if let code { XCTAssertEqual(r.code, code, "exit code of `halo \(args.joined(separator: " "))`: \(r.err)", file: file, line: line) }
        try HaloCLI.check(name, render(args, r), file: file, line: line)
    }

    private func png(_ name: String = "photo.png") throws -> URL {
        let u = scratch.appendingPathComponent(name)
        try HaloCLI.makePNG(at: u)
        return u
    }

    // MARK: Listing (every --json document)

    func testVersion() throws { try check("version", ["version"], expect: 0) }
    func testVersionJSON() throws { try check("version-json", ["version", "--json"], expect: 0) }
    func testHelp() throws { try check("help", ["help"], expect: 0) }
    func testHelpJSON() throws { try check("help-json", ["help", "--json"], expect: 0) }
    func testFormatsJSON() throws { try check("formats-json", ["formats", "--json"], expect: 0) }
    func testFormatsFromJSON() throws { try check("formats-from-heic-json", ["formats", "--from", "heic", "--json"], expect: 0) }
    func testToolsJSON() throws { try check("tools-json", ["tools", "--json"], expect: 0) }
    func testOptionsGIFJSON() throws { try check("options-gif-json", ["options", "gif", "--json"], expect: 0) }
    func testOptionsJPGJSON() throws { try check("options-jpg-json", ["options", "jpg", "--json"], expect: 0) }
    func testOptionsUnknown() throws { try check("options-unknown-json", ["options", "nope", "--json"], expect: 2) }
    func testSchemaJSON() throws { try check("schema-json", ["schema", "--json"], expect: 0) }
    func testRoute() throws { try check("route-heic-jpg", ["route", "heic", "jpg"], expect: 0) }
    func testRouteJSON() throws { try check("route-heic-jpg-json", ["route", "heic", "jpg", "--json"], expect: 0) }
    func testNoRoute() throws { try check("route-none", ["route", "foo", "bar"], expect: 3) }
    func testUnknownCommand() throws { try check("unknown-command", ["bogus"], expect: 2) }
    func testUnknownFlag() throws { try check("unknown-flag-json", ["formats", "--bogus", "--json"], expect: 2) }

    func testTargetsJSON() throws {
        let f = try png()
        try check("targets-png-json", ["targets", f.path, "--json"], expect: 0)
    }

    func testTargetsMissing() throws {
        try check("targets-missing", ["targets", scratch.appendingPathComponent("gone.png").path], expect: 4)
    }

    func testSchemaHasEverything() throws {
        let r = try run(["schema", "--json"])
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(r.out.utf8)) as? [String: Any])
        XCTAssertEqual(obj["schemaVersion"] as? Int, 1)
        for key in ["cli", "exitCodes", "events", "formats", "routes", "options", "tools", "presets", "mcp"] {
            XCTAssertNotNil(obj[key], "schema lacks \(key)")
        }
        let codes = (obj["exitCodes"] as? [[String: Any]])?.compactMap { $0["code"] as? Int }
        XCTAssertEqual(codes, [0, 2, 3, 4, 5, 6, 7, 8])
    }

    // MARK: convert

    func testMissingTarget() throws { try check("convert-missing-to", ["convert", "/nonexistent/halo.png"], expect: 2) }
    func testMissingInput() throws { try check("convert-missing-file", ["convert", "/nonexistent/halo.png", "--to", "jpg"], expect: 4) }

    func testDryRunJSON() throws {
        let f = try png()
        try check("convert-dry-run-json", ["convert", f.path, "--to", "jpg", "--opt", "quality=70", "--dry-run", "--json"], expect: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: scratch.appendingPathComponent("photo.jpg").path), "dry run wrote a file")
    }

    func testDryRunHuman() throws {
        let f = try png()
        try check("convert-dry-run", ["convert", f.path, "--to", "jpg", "--dry-run"], expect: 0)
    }

    /// The NDJSON stream of a real conversion. Progress lines are timing-dependent,
    /// so they're checked here (well-formed, increasing, ending at 1) and left out of the golden.
    func testConvertNDJSON() throws {
        let f = try png()
        let args = ["convert", f.path, "--to", "jpg", "--opt", "quality=70", "--out-dir", scratch.appendingPathComponent("out").path, "--json"]
        let r = try run(args)
        XCTAssertEqual(r.code, 0, r.err)
        let lines = r.out.split(separator: "\n").map(String.init)
        var last = -1.0
        var progressCount = 0
        for l in lines {
            let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any], "not JSON: \(l)")
            XCTAssertNotNil(obj["event"])
            if obj["event"] as? String == "progress" {
                let x = try XCTUnwrap(obj["fraction"] as? Double)
                XCTAssertGreaterThan(x, last)
                last = x
                progressCount += 1
            }
        }
        XCTAssertGreaterThan(progressCount, 0)
        XCTAssertEqual(last, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: scratch.appendingPathComponent("out/photo.jpg").path))
        try HaloCLI.check("convert-ndjson", render(args, r) { $0.contains(#""event":"progress""#) })

        // Same again: Finder-style rename, never overwrite.
        let again = try run(args)
        XCTAssertEqual(again.code, 0)
        XCTAssertTrue(again.out.contains("photo 2.jpg"), again.out)
    }

    func testOverwriteNever() throws {
        let f = try png()
        try HaloCLI.makePNG(at: scratch.appendingPathComponent("photo.jpg")) // name taken (content irrelevant)
        try check("convert-overwrite-never", ["convert", f.path, "--to", "jpg", "--overwrite", "never", "--json"], expect: 6)
    }

    func testUnsupportedRoute() throws {
        let f = try png()
        try check("convert-unsupported", ["convert", f.path, "--to", "srt", "--json"], expect: 3)
    }

    func testBadOption() throws {
        let f = try png()
        try check("convert-bad-option", ["convert", f.path, "--to", "jpg", "--opt", "bogus=1"], expect: 2)
        try check("convert-bad-value-json", ["convert", f.path, "--to", "jpg", "--opt", "quality=loud", "--json"], expect: 2)
    }

    func testUnknownFormat() throws {
        let f = try png()
        try check("convert-unknown-format", ["convert", f.path, "--to", "nope"], expect: 2)
    }

    func testCloudUnavailable() throws {
        let f = try png()
        try check("convert-cloud", ["convert", f.path, "--to", "mp4", "--opt", "cloud=true"], expect: 8)
        try check("tool-cloud", ["tool", "cloud.transcribe", f.path], expect: 8)
    }

    func testPartialBatch() throws {
        let f = try png()
        try check("convert-partial", ["convert", f.path, scratch.appendingPathComponent("gone.png").path, "--to", "jpg", "--json"], expect: 6)
    }

    func testUnreadableInput() throws {
        let bad = scratch.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: bad)
        let r = try run(["convert", bad.path, "--to", "jpg", "--json"])
        XCTAssertEqual(r.code, 4, r.out)
        XCTAssertTrue(r.out.contains(#""code":"input_missing""#), r.out)
    }

    func testEngineFailed() throws {
        let engines = try XCTUnwrap(try HaloCLI.failingEngines(in: scratch.appendingPathComponent("engines")), "needs HALO_ENGINES_DIR")
        let wav = scratch.appendingPathComponent("tone.wav")
        try HaloCLI.makeWAV(at: wav)
        try check("convert-engine-failed", ["convert", wav.path, "--to", "mp3", "--json"],
                  env: ["HALO_ENGINES_DIR": engines.path], expect: 5)
    }

    func testSkipAlreadyTarget() throws {
        let f = try png()
        try check("convert-skip", ["convert", f.path, "--to", "png", "--json"], expect: 0)
    }

    /// SIGINT mid-job: the job stops, nothing is written, exit 7.
    func testCancelledBySIGINT() throws {
        let f = try png()
        let p = Process()
        p.executableURL = HaloCLI.binary
        p.arguments = ["convert", f.path, "--to", "tiff", "--json"]
        p.environment = HaloCLI.environment(["HALO_SUPPORT_DIR": support.path, "HALO_TEST_DELAY_MS": "20000"])
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        // Wait for the start event, so the job is running when the signal lands.
        let handle = out.fileHandleForReading
        var buffer = Data()
        let deadline = Date().addingTimeInterval(20)
        while !String(decoding: buffer, as: UTF8.self).contains("\n"), Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer += chunk
        }
        kill(p.processIdentifier, SIGINT)
        buffer += handle.readDataToEndOfFile()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 7)
        let text = HaloCLI.normalise(String(decoding: buffer, as: UTF8.self), paths: tokens)
        try HaloCLI.check("convert-sigint", "$ halo convert <tmp>/photo.png --to tiff --json   (SIGINT after start)\nexit: \(p.terminationStatus)\n--- stdout\n\(text)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: scratch.appendingPathComponent("photo.tiff").path))
    }

    // MARK: tool

    func testToolNDJSON() throws {
        let f = try png()
        let args = ["tool", "meta.strip", f.path, "--json"]
        let r = try run(args)
        XCTAssertEqual(r.code, 0, r.err)
        try HaloCLI.check("tool-strip-ndjson", render(args, r) { $0.contains(#""event":"progress""#) })
    }

    func testToolUnknown() throws { try check("tool-unknown", ["tool", "nope.nope", "/tmp/x.png"], expect: 2) }

    // MARK: presets / jobs / doctor

    func testPresetsLifecycle() throws {
        var transcript = ""
        func step(_ args: [String], _ code: Int32) throws -> String {
            let r = try run(args)
            XCTAssertEqual(r.code, code, "\(args): \(r.err)")
            transcript += render(args, r) + "\n"
            return r.out
        }
        _ = try step(["presets", "list", "--format", "jpg", "--json"], 0)
        let added = try step(["presets", "add", "--format", "jpg", "--title", "Tiny", "--opt", "quality=40", "--json"], 0)
        let id = try XCTUnwrap((try JSONSerialization.jsonObject(with: Data(added.utf8)) as? [String: Any])?["id"] as? String)
        _ = try step(["presets", "show", id, "--json"], 0)
        _ = try step(["presets", "list", "--format", "jpg"], 0)
        _ = try step(["presets", "add", "--format", "jpg", "--title", "Bad", "--opt", "fps=10"], 2)
        // The preset applies by title, and explicit options win.
        let f = try png()
        _ = try step(["convert", f.path, "--to", "jpg", "--preset", "tiny", "--dry-run", "--json"], 0)
        _ = try step(["convert", f.path, "--to", "jpg", "--preset", "Tiny", "--opt", "quality=90", "--dry-run", "--json"], 0)
        _ = try step(["presets", "rm", id, "--json"], 0)
        _ = try step(["presets", "rm", "builtin.jpg.web", "--json"], 0)
        _ = try step(["presets", "list", "--format", "jpg", "--all", "--json"], 0)
        _ = try step(["presets", "show", "missing"], 2)
        try HaloCLI.check("presets-lifecycle", transcript)
    }

    func testPresetsAllJSON() throws { try check("presets-json", ["presets", "--json"], expect: 0) }

    func testJobsEmpty() throws { try check("jobs-empty-json", ["jobs", "--json"], expect: 0) }

    func testJobsFromStore() throws {
        let f = try png()
        let file: [String: Any] = ["version": 1, "items": [
            ["id": "6F0C2A7E-1B7D-4B7B-9E2B-8A1D2F3C4B5A", "title": "photo.png → PNG", "paths": [f.path], "date": "2026-10-01T09:30:00Z"],
            ["id": "1A2B3C4D-1B7D-4B7B-9E2B-8A1D2F3C4B5A", "title": "deleted.mov → MP4", "paths": ["/nonexistent/deleted.mp4"], "date": "2026-09-30T08:00:00Z"],
        ]]
        try JSONSerialization.data(withJSONObject: file).write(to: support.appendingPathComponent("recents.json"))
        try check("jobs-json", ["jobs", "--json"], expect: 0)
    }

    /// Paths, versions and the signature differ per machine, so doctor is checked by shape.
    func testDoctorJSON() throws {
        let r = try run(["doctor", "--json"])
        XCTAssertEqual(r.code, 0, r.err)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(r.out.utf8)) as? [String: Any])
        for key in ["name", "version", "cliPath", "engines", "packs", "permissions", "signature", "network", "conversionOptions", "supportDirectory"] {
            XCTAssertNotNil(obj[key], "doctor lacks \(key)")
        }
        let engines = try XCTUnwrap(obj["engines"] as? [[String: Any]])
        XCTAssertEqual(engines.compactMap { $0["name"] as? String }, ["ffmpeg", "ffprobe", "resvg"])
        if ProcessInfo.processInfo.environment["HALO_ENGINES_DIR"] != nil {
            for e in engines {
                XCTAssertEqual(e["found"] as? Bool, true, "\(e)")
                XCTAssertEqual(e["source"] as? String, "HALO_ENGINES_DIR")
                XCTAssertNotNil(e["version"])
            }
        }
        let status = (obj["signature"] as? [String: Any])?["status"] as? String
        XCTAssertTrue(["signed", "ad-hoc", "unsigned", "unknown"].contains(status ?? ""), "\(String(describing: status))")
        XCTAssertEqual(obj["supportDirectory"] as? String, support.path)
    }
}
