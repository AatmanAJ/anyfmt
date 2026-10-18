import Foundation
import HaloCore

/// `halo mcp`: a Model Context Protocol server over stdio. JSON-RPC 2.0,
/// one message per line on stdin/stdout, logs on stderr. No dependencies,
/// no sockets, no ports.
///
/// Dual-era (see docs/CLI.md › MCP):
/// - Legacy clients open with `initialize`; we answer with their
///   `protocolVersion` when we support it, else our latest legacy version
///   (2025-11-25), and serve the session with those semantics.
/// - Modern (2026-07-28) clients send no handshake: every request carries
///   `_meta["io.modelcontextprotocol/protocolVersion"]` and
///   `…/clientCapabilities`. We serve those statelessly, add
///   `resultType: "complete"` and `…/serverInfo` to results, implement
///   `server/discover`, and reject unknown versions with -32022.
@MainActor
final class MCPServer {
    static let modernVersions = ["2026-07-28"]
    static let legacyVersions = ["2025-11-25", "2025-06-18", "2025-03-26"]
    static var supportedVersions: [String] { modernVersions + legacyVersions }

    static let metaVersion = "io.modelcontextprotocol/protocolVersion"
    static let metaCapabilities = "io.modelcontextprotocol/clientCapabilities"
    static let metaServerInfo = "io.modelcontextprotocol/serverInfo"

    static var serverInfo: [String: Any] { ["name": Brand.cliName, "title": Brand.name, "version": cliVersion] }

    static let instructions = """
        \(Brand.name) converts files locally on this Mac (images, video, audio, documents, archives). \
        Plan first: call `targets` with the files to see what they can become, `options` for a target's settings, \
        then `convert` with dryRun true to see routes and output paths, then convert for real. \
        Outputs are written beside the originals (or outDir) and never overwrite anything. Nothing leaves the Mac.
        """

    /// Negotiated legacy version once `initialize` arrived.
    private var legacyVersion: String?
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var cancelled = Set<String>()

    // MARK: Loop

    static func serve() async -> ExitCode {
        let server = MCPServer()
        let lines = AsyncStream<String> { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                while let line = readLine(strippingNewline: true) { continuation.yield(line) }
                continuation.finish()
            }
        }
        err("\(Brand.cliName) mcp: ready on stdio (protocol \(supportedVersions.joined(separator: ", ")))")
        for await line in lines { server.handle(line) }
        // stdin closed: finish what's running, then exit.
        for task in server.inFlight.values { await task.value }
        return .ok
    }

    private func send(_ message: [String: Any]) {
        var m = message
        m["jsonrpc"] = "2.0"
        out(JSON.line(m))
    }

    private func reply(_ id: Any, _ result: [String: Any], modern: Bool) {
        var r = result
        if modern {
            r["resultType"] = "complete"
            var meta = (r["_meta"] as? [String: Any]) ?? [:]
            meta[Self.metaServerInfo] = Self.serverInfo
            r["_meta"] = meta
        }
        send(["id": id, "result": r])
    }

    private func fail(_ id: Any?, _ code: Int, _ message: String, data: Any? = nil) {
        var e: [String: Any] = ["code": code, "message": message]
        if let data { e["data"] = data }
        send(["id": id ?? NSNull(), "error": e])
    }

    private static func key(_ id: Any) -> String { JSON.line([id]) }

    // MARK: Dispatch

    func handle(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let parsed = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8), options: [.fragmentsAllowed]) else {
            fail(nil, -32700, "Parse error")
            return
        }
        guard let msg = parsed as? [String: Any] else {
            fail(nil, -32600, parsed is [Any] ? "Invalid Request: JSON-RPC batches are not supported" : "Invalid Request")
            return
        }
        let id = msg["id"].flatMap { $0 is NSNull ? nil : $0 }
        guard msg["jsonrpc"] as? String == "2.0" else { fail(id, -32600, "Invalid Request: jsonrpc must be \"2.0\""); return }
        guard let method = msg["method"] as? String else {
            if id == nil { fail(nil, -32600, "Invalid Request") }
            return // a response from the client: we never send requests, so ignore it
        }
        if let id, !(id is String || (id is NSNumber && !JSON.isBool(id))) {
            fail(nil, -32600, "Invalid Request: id must be a string or a number")
            return
        }
        let params = (msg["params"] as? [String: Any]) ?? [:]
        guard let id else { notification(method, params); return }
        request(id: id, method: method, params: params)
    }

    private func notification(_ method: String, _ params: [String: Any]) {
        switch method {
        case "notifications/initialized":
            break
        case "notifications/cancelled":
            guard let rid = params["requestId"] else { return }
            let k = Self.key(rid)
            guard let task = inFlight[k] else { return } // unknown or finished: ignore
            cancelled.insert(k)
            task.cancel()
            err("mcp: cancelled request \(k)\((params["reason"] as? String).map { ": \($0)" } ?? "")")
        default:
            break
        }
    }

    private func request(id: Any, method: String, params: [String: Any]) {
        let meta = params["_meta"] as? [String: Any]
        if let requested = meta?[Self.metaVersion] {
            // Modern, stateless request.
            guard let v = requested as? String, Self.modernVersions.contains(v) else {
                fail(id, -32022, "Unsupported protocol version",
                     data: ["supported": Self.supportedVersions, "requested": requested])
                return
            }
            guard meta?[Self.metaCapabilities] is [String: Any] else {
                fail(id, -32602, "Invalid params: _meta[\"\(Self.metaCapabilities)\"] is required")
                return
            }
            dispatch(id: id, method: method, params: params, modern: true)
            return
        }
        switch method {
        case "initialize":
            let asked = params["protocolVersion"] as? String ?? ""
            let version = Self.legacyVersions.contains(asked) ? asked : Self.legacyVersions[0]
            legacyVersion = version
            err("mcp: initialize: client asked for \(asked.isEmpty ? "no version" : asked), serving \(version)")
            reply(id, ["protocolVersion": version,
                       "capabilities": ["tools": ["listChanged": false]],
                       "serverInfo": Self.serverInfo,
                       "instructions": Self.instructions], modern: false)
        case "ping":
            reply(id, [:], modern: false)
        default:
            guard legacyVersion != nil else {
                if method == "server/discover" {
                    fail(id, -32602, "Invalid params: _meta[\"\(Self.metaVersion)\"] is required")
                } else {
                    fail(id, -32600, "Invalid Request: send initialize first, or put \(Self.metaVersion) in _meta (\(Self.modernVersions[0]))")
                }
                return
            }
            dispatch(id: id, method: method, params: params, modern: false)
        }
    }

    private func dispatch(id: Any, method: String, params: [String: Any], modern: Bool) {
        switch method {
        case "server/discover":
            reply(id, ["supportedVersions": Self.supportedVersions,
                       "capabilities": ["tools": ["listChanged": false]],
                       "instructions": Self.instructions,
                       "ttlMs": 3_600_000, "cacheScope": "public"], modern: modern)
        case "tools/list":
            var r: [String: Any] = ["tools": MCPTools.definitions]
            if modern { r["ttlMs"] = 3_600_000; r["cacheScope"] = "public" }
            reply(id, r, modern: modern)
        case "tools/call":
            call(id: id, params: params, modern: modern)
        case "ping" where !modern:
            reply(id, [:], modern: false)
        case "initialize" where modern:
            fail(id, -32601, "Method not found: initialize is not part of \(Self.modernVersions[0]); use server/discover")
        default:
            fail(id, -32601, "Method not found: \(method)")
        }
    }

    // MARK: tools/call

    private func call(id: Any, params: [String: Any], modern: Bool) {
        guard let name = params["name"] as? String else {
            fail(id, -32602, "Invalid params: tools/call needs a tool name")
            return
        }
        guard MCPTools.names.contains(name) else {
            fail(id, -32602, "Unknown tool: \(name)")
            return
        }
        let arguments = (params["arguments"] as? [String: Any]) ?? [:]
        let progress = ((params["_meta"] as? [String: Any])?["progressToken"]).map { MCPProgress(token: Box($0)) }
        let k = Self.key(id)
        let idBox = Box(id)
        let argBox = Box(arguments)
        inFlight[k] = Task { @MainActor [weak self] in
            let (payload, isError) = await MCPTools.call(name, argBox.value as! [String: Any], progress: progress)
            guard let self else { return }
            self.inFlight[k] = nil
            if self.cancelled.remove(k) != nil || Task.isCancelled { return } // never answer a cancelled request
            self.reply(idBox.value, ["content": [["type": "text", "text": JSON.line(payload)]],
                                     "structuredContent": payload,
                                     "isError": isError], modern: modern)
        }
    }
}

/// Carries a decoded JSON value (always immutable) across concurrency domains.
struct Box: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}

/// Sends `notifications/progress` for one request, overall fraction 0…1,
/// strictly increasing (whole percents).
final class MCPProgress: @unchecked Sendable {
    private let token: Box
    private let lock = NSLock()
    private var jobs = 1
    private var finished = 0
    private var last = -1

    init(token: Box) { self.token = token }

    func handle(_ e: RunEvent) {
        switch e {
        case .start(let n): lock.withLock { jobs = max(1, n) }
        case .progress(let file, let f):
            let (overall, message): (Double, String) = lock.withLock {
                ((Double(finished) + f) / Double(jobs), (file as NSString).lastPathComponent)
            }
            emit(overall, message)
        case .output, .error:
            let overall: Double = lock.withLock { finished = min(jobs, finished + 1); return Double(finished) / Double(jobs) }
            emit(overall, nil)
        case .skip, .done: break
        }
    }

    private func emit(_ fraction: Double, _ message: String?) {
        let pct = Int((min(1, max(0, fraction)) * 100).rounded(.down))
        let send: Bool = lock.withLock { guard pct > last else { return false }; last = pct; return true }
        guard send else { return }
        var p: [String: Any] = ["progressToken": token.value, "progress": JSON.number(Double(pct) / 100), "total": 1]
        if let message { p["message"] = message }
        out(JSON.line(["jsonrpc": "2.0", "method": "notifications/progress", "params": p]))
    }
}
