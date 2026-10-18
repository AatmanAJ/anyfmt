import Foundation
import XCTest

/// Runs the built `halo` binary and compares stdout, stderr and the exit code
/// with Tests/CLIGolden. Agents parse this output, so it must never change by
/// accident. Re-record on purpose with HALO_RECORD_GOLDEN=1.
final class CLIGoldenTests: XCTestCase {
    private static let goldenDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("CLIGolden")

    private var binary: URL {
        Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("halo")
    }

    private func run(_ args: [String]) throws -> (out: String, err: String, code: Int32) {
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        // A clean environment, as an agent's shell would have. The test runner's
        // own variables (OS_ACTIVITY_DT_MODE mirrors system logs to stderr) stay out.
        let inherited = ProcessInfo.processInfo.environment
        var env = ["NO_COLOR": "1", "PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory()]
        env["HALO_ENGINES_DIR"] = inherited["HALO_ENGINES_DIR"]
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (String(decoding: o, as: UTF8.self), String(decoding: e, as: UTF8.self), p.terminationStatus)
    }

    /// Version numbers change on release; everything else must match exactly.
    private func normalise(_ s: String) -> String {
        s.replacingOccurrences(of: #"halo \d+\.\d+\.\d+[^ ]*"#, with: "halo <version>", options: .regularExpression)
    }

    private func check(_ name: String, _ args: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: binary.path), "halo not built next to the tests")
        let r = try run(args)
        let actual = "$ halo \(args.joined(separator: " "))\nexit: \(r.code)\n--- stdout\n\(normalise(r.out))--- stderr\n\(normalise(r.err))"
        let url = Self.goldenDir.appendingPathComponent("\(name).txt")
        if ProcessInfo.processInfo.environment["HALO_RECORD_GOLDEN"] == "1" {
            try FileManager.default.createDirectory(at: Self.goldenDir, withIntermediateDirectories: true)
            try actual.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        let expected = try String(contentsOf: url, encoding: .utf8)
        if actual != expected {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("halo-golden-\(name).txt")
            try? actual.write(to: tmp, atomically: true, encoding: .utf8)
            XCTFail("CLI output for `\(args.joined(separator: " "))` changed. Diff \(url.path) against \(tmp.path), or re-record with HALO_RECORD_GOLDEN=1.", file: file, line: line)
        }
    }

    func testVersion() throws { try check("version", ["version"]) }
    func testHelp() throws { try check("help", ["help"]) }
    func testFormatsJSON() throws { try check("formats-json", ["formats", "--json"]) }
    func testFormatsFromJSON() throws { try check("formats-from-heic-json", ["formats", "--from", "heic", "--json"]) }
    func testToolsJSON() throws { try check("tools-json", ["tools", "--json"]) }
    func testRoute() throws { try check("route-heic-jpg", ["route", "heic", "jpg"]) }
    func testNoRoute() throws { try check("route-none", ["route", "foo", "bar"]) }
    func testUnknownCommand() throws { try check("unknown-command", ["bogus"]) }
    func testMissingInput() throws { try check("convert-missing-file", ["convert", "/nonexistent/halo.png", "--to", "jpg"]) }
    func testMissingTarget() throws { try check("convert-missing-to", ["convert", "/nonexistent/halo.png"]) }
}
