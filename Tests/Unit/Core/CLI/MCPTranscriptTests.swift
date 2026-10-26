import Foundation
import XCTest

/// Drives `anyfmt mcp` through pipes, one request at a time, and compares the
/// whole conversation with Tests/CLIGolden/mcp-transcript.txt.
final class MCPTranscriptTests: XCTestCase {
    /// A running `anyfmt mcp` with line-buffered stdout.
    private final class Server: @unchecked Sendable {
        let process = Process()
        private let input = Pipe()
        private let output = Pipe()
        private let lock = NSLock()
        private var buffer = Data()
        private var lines: [String] = []
        private var closed = false
        private let arrived = DispatchSemaphore(value: 0)

        init(env: [String: String]) throws {
            process.executableURL = AnyfmtCLI.binary
            process.arguments = ["mcp"]
            process.environment = AnyfmtCLI.environment(env)
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            output.fileHandleForReading.readabilityHandler = { [weak self] h in
                let chunk = h.availableData
                self?.receive(chunk)
            }
            try process.run()
        }

        private func receive(_ chunk: Data) {
            lock.withLock {
                if chunk.isEmpty { closed = true } else { buffer += chunk }
                while let nl = buffer.firstIndex(of: 0x0A) {
                    lines.append(String(decoding: buffer[buffer.startIndex..<nl], as: UTF8.self))
                    buffer = Data(buffer[buffer.index(after: nl)...])
                }
            }
            arrived.signal()
        }

        func send(_ line: String) {
            input.fileHandleForWriting.write(Data((line + "\n").utf8))
        }

        /// Lines received until one is the response to `id` (included).
        func until(id: Int, timeout: TimeInterval = 30) -> [String] {
            let deadline = Date().addingTimeInterval(timeout)
            var taken: [String] = []
            while Date() < deadline {
                let next: [String] = lock.withLock { let l = lines; lines.removeAll(); return l }
                for (i, l) in next.enumerated() {
                    taken.append(l)
                    if let obj = try? JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any],
                       obj["method"] == nil, (obj["id"] as? Int) == id || (id == -1 && obj["id"] is NSNull) {
                        let rest = Array(next[(i + 1)...])
                        lock.withLock { lines.insert(contentsOf: rest, at: 0) }
                        return taken
                    }
                }
                _ = arrived.wait(timeout: .now() + 0.2)
            }
            return taken
        }

        /// Closes stdin and returns everything written until stdout closes.
        func finish(timeout: TimeInterval = 30) -> [String] {
            try? input.fileHandleForWriting.close()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning, Date() < deadline { _ = arrived.wait(timeout: .now() + 0.2) }
            // Let the reader drain the last bytes.
            for _ in 0..<10 where !lock.withLock({ closed }) { _ = arrived.wait(timeout: .now() + 0.1) }
            return lock.withLock { let l = lines; lines.removeAll(); return l }
        }
    }

    func testTranscript() throws {
        try XCTSkipUnless(AnyfmtCLI.isBuilt, "anyfmt not built next to the tests")
        let scratch = try AnyfmtCLI.scratch("mcp")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let support = scratch.appendingPathComponent("support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let png = scratch.appendingPathComponent("photo.png")
        try AnyfmtCLI.makePNG(at: png)
        let outDir = scratch.appendingPathComponent("out").path

        // Each convert that really runs waits 1 s first, so the cancellation below
        // lands while the job is in flight (ANYFMT_TEST_DELAY_MS; dry runs don't wait).
        let server = try Server(env: ["ANYFMT_SUPPORT_DIR": support.path, "ANYFMT_TEST_DELAY_MS": "1000"])
        var transcript = ""
        var progressTokens: [String] = []

        func record(_ lines: [String]) {
            for l in lines {
                if l.contains(#""method":"notifications/progress""#) {
                    // Count depends on timing: checked below, not in the golden.
                    progressTokens.append(l)
                    continue
                }
                transcript += "← \(normalise(l))\n"
            }
        }
        func normalise(_ s: String) -> String {
            var t = AnyfmtCLI.normalise(s, paths: [scratch: "<tmp>"])
            // Encoder output size can change with the OS's ImageIO.
            t = t.replacingOccurrences(of: #"("|\\")bytes("|\\"):\d+"#, with: "$1bytes$2:<n>", options: .regularExpression)
            return t
        }
        func step(_ id: Int, _ json: String) {
            transcript += "→ \(normalise(json))\n"
            server.send(json)
            record(server.until(id: id))
        }
        func note(_ json: String) {
            transcript += "→ \(normalise(json))\n"
            server.send(json)
        }
        let modern = #""_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{},"io.modelcontextprotocol/clientInfo":{"name":"golden","version":"1"}}"#

        // Legacy era: version negotiation, then the session.
        step(1, #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2099-01-01","capabilities":{},"clientInfo":{"name":"golden","version":"1"}}}"#)
        step(2, #"{"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"golden","version":"1"}}}"#)
        step(3, #"{"jsonrpc":"2.0","id":3,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"golden","version":"1"}}}"#)
        note(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
        step(4, #"{"jsonrpc":"2.0","id":4,"method":"ping"}"#)
        step(5, #"{"jsonrpc":"2.0","id":5,"method":"tools/list"}"#)
        step(6, #"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"targets","arguments":{"files":["\#(png.path)"]}}}"#)
        step(7, #"{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"options","arguments":{"format":"jpg"}}}"#)
        step(8, #"{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"convert","arguments":{"files":["\#(png.path)"],"to":"jpg","options":{"quality":70},"dryRun":true}}}"#)
        step(9, #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"convert","arguments":{"files":["\#(png.path)"],"to":"jpg","options":{"quality":70},"outDir":"\#(outDir)"},"_meta":{"progressToken":"convert-9"}}}"#)
        step(10, #"{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"estimate","arguments":{"file":"\#(png.path)","to":"jpg","options":{"quality":70}}}}"#)
        step(11, #"{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"convert","arguments":{"files":["\#(scratch.path)/gone.png"],"to":"jpg"}}}"#)
        step(12, #"{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"convert","arguments":{"files":["\#(png.path)"],"to":"jpg","options":{"bogus":1}}}}"#)
        step(13, #"{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"presets","arguments":{"format":"gif"}}}"#)
        step(14, #"{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"no_such_tool","arguments":{}}}"#)
        step(15, #"{"jsonrpc":"2.0","id":15,"method":"resources/list"}"#)
        step(-1, #"{"jsonrpc":"2.0","id":16,"method":"tools/list""#) // malformed JSON → -32700, id null

        // Modern era: stateless requests carrying the version in _meta.
        step(17, #"{"jsonrpc":"2.0","id":17,"method":"server/discover","params":{\#(modern)}}"#)
        step(18, #"{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"formats","arguments":{"from":"png"},\#(modern)}}"#)
        step(19, #"{"jsonrpc":"2.0","id":19,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"1999-01-01","io.modelcontextprotocol/clientCapabilities":{}}}}"#)
        step(20, #"{"jsonrpc":"2.0","id":20,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}}}"#)

        // Cancellation: the convert is still waiting when the notification lands,
        // so it never answers; the ping after it does.
        let cancelled = #"{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"convert","arguments":{"files":["\#(png.path)"],"to":"tiff","outDir":"\#(outDir)"}}}"#
        transcript += "→ \(normalise(cancelled))\n"
        server.send(cancelled)
        note(#"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":21,"reason":"golden test"}}"#)
        step(22, #"{"jsonrpc":"2.0","id":22,"method":"ping"}"#)

        let rest = server.finish()
        record(rest)
        transcript += "(stdin closed; server exit \(server.process.terminationStatus))\n"
        XCTAssertFalse(rest.contains { $0.contains(#""id":21"#) }, "cancelled request was answered: \(rest)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(outDir)/photo.tiff"), "cancelled convert wrote its output")
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(outDir)/photo.jpg"))

        XCTAssertFalse(progressTokens.isEmpty, "no progress notifications for a request with a progressToken")
        for p in progressTokens { XCTAssertTrue(p.contains(#""progressToken":"convert-9""#), p) }
        XCTAssertTrue(progressTokens.last?.contains(#""progress":1"#) == true, "\(progressTokens)")

        try AnyfmtCLI.check("mcp-transcript", transcript)
    }
}
