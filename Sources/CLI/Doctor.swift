import Foundation
import HaloCore

/// `halo doctor`: what this install can do and why. Read-only, local only:
/// it runs the bundled engines' `-version` and `/usr/bin/codesign -dv`, nothing else.
@MainActor
enum Doctor {
    static func run(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        let report = collect()
        if p.has("--json") {
            out(JSON.pretty(report))
            return .ok
        }
        out("\(Brand.cliName) \(cliVersion)")
        out("cli:        \(report["cliPath"] as? String ?? "?")")
        out("app:        \(report["appBundle"] as? String ?? "not inside an app bundle")")
        if let sig = report["signature"] as? [String: Any] { out("signature:  \(sig["status"] ?? "?")\(sig["authority"].map { " (\($0))" } ?? "")") }
        out("engines:")
        for e in report["engines"] as? [[String: Any]] ?? [] {
            let found = (e["found"] as? Bool) == true
            out("  \(String(describing: e["name"]!).padding(toLength: 8, withPad: " ", startingAt: 0)) \(found ? "\(e["source"]!)  \(e["version"] ?? "")\n           \(e["path"]!)" : "missing")")
            if let other = e["pathCopy"] as? String { out("           also on PATH (not used): \(other)") }
        }
        out("packs:")
        for pk in report["packs"] as? [[String: Any]] ?? [] {
            out("  \(pk["name"]!): \((pk["installed"] as? Bool) == true ? "installed" : "not installed")")
        }
        out("conversions: \(report["conversionOptions"]!) options, \(report["routesUnavailable"]!) rows unavailable in this build")
        out("permissions:")
        for perm in report["permissions"] as? [[String: Any]] ?? [] { out("  \(perm["name"]!): \(perm["note"]!)") }
        return .ok
    }

    static func collect() -> [String: Any] {
        let locator = EngineLocator.shared
        let env = ProcessInfo.processInfo.environment
        let envDir = env["HALO_ENGINES_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0).appendingPathComponent("Helpers").path }
        let app = CLIPaths.appBundle
        var engines: [[String: Any]] = []
        for name in ["ffmpeg", "ffprobe", "resvg"] {
            var e: [String: Any] = ["name": name]
            if let u = locator.url(for: name) {
                let path = u.resolvingSymlinksInPath().path
                e["found"] = true
                e["path"] = path
                if CLIPaths.enginesBesideCLI { e["source"] = "bundled" }
                else if let envDir, u.path.hasPrefix(envDir) { e["source"] = "HALO_ENGINES_DIR" }
                else if let app, path.hasPrefix(app.path) { e["source"] = "bundled" }
                else { e["source"] = "beside the CLI or a source checkout" }
                if let v = versionLine(u, arg: name == "resvg" ? "--version" : "-version") { e["version"] = v }
            } else {
                e["found"] = false
            }
            if let onPath = which(name), onPath != (e["path"] as? String) { e["pathCopy"] = onPath }
            engines.append(e)
        }
        let packs: [[String: Any]] = [
            ["name": OfficePack.spec.name, "version": OfficePack.spec.version, "installed": locator.officePackSoffice != nil,
             "path": EngineLocator.packsDirectory.appendingPathComponent(OfficePack.spec.installName).path],
            ["name": PandocPack.spec.name, "version": PandocPack.spec.version, "installed": locator.pandocPack != nil,
             "path": EngineLocator.packsDirectory.appendingPathComponent(PandocPack.spec.installName).path],
        ]
        let registry = EngineRegistry.default
        let unavailable = CapabilityTable.default.rows.filter { !registry.isAvailable($0) }.count
        var report: [String: Any] = [
            "name": Brand.cliName,
            "version": cliVersion,
            "cliPath": CLIPaths.executable.path,
            "engines": engines,
            "packs": packs,
            "packsDirectory": EngineLocator.packsDirectory.path,
            "supportDirectory": CLIPaths.supportDirectory.path,
            "conversionOptions": Router.live().optionCount(),
            "routesUnavailable": unavailable,
            "network": "none: the CLI and `halo mcp` never open sockets or ports",
            "permissions": [
                ["name": "none required", "note": "the CLI needs no macOS permission to convert files you can read"],
                ["name": "Files and Folders / Full Disk Access",
                 "note": "only if you convert files in protected folders (Desktop, Documents, Downloads) from a terminal that lacks access; macOS asks the terminal, not Halo"],
                ["name": "Automation (Pages)", "note": "only for the opt-in Pages export, which the app asks for; the CLI never triggers it"],
            ],
        ]
        if let app { report["appBundle"] = app.path }
        report["signature"] = signature(of: CLIPaths.executable)
        return report
    }

    /// First line of `<tool> -version`, bounded to 3 s.
    static func versionLine(_ tool: URL, arg: String) -> String? {
        run(tool, [arg]).flatMap { $0.out.split(separator: "\n").first.map(String.init) }
    }

    static func which(_ name: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in path.split(separator: ":") {
            let u = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: u.path) { return u.resolvingSymlinksInPath().path }
        }
        return nil
    }

    static func signature(of exe: URL) -> [String: Any] {
        let codesign = URL(fileURLWithPath: "/usr/bin/codesign")
        guard FileManager.default.isExecutableFile(atPath: codesign.path), let r = run(codesign, ["-dv", exe.path]) else {
            return ["status": "unknown"]
        }
        let text = r.err + r.out
        var d: [String: Any] = [:]
        if text.contains("not signed") { d["status"] = "unsigned" }
        else if text.contains("Signature=adhoc") { d["status"] = "ad-hoc" }
        else if r.status == 0 { d["status"] = "signed" }
        else { d["status"] = "unknown" }
        for line in text.split(separator: "\n") {
            if line.hasPrefix("Authority="), d["authority"] == nil { d["authority"] = String(line.dropFirst("Authority=".count)) }
            if line.hasPrefix("TeamIdentifier=") { d["team"] = String(line.dropFirst("TeamIdentifier=".count)) }
            if line.hasPrefix("Identifier=") { d["identifier"] = String(line.dropFirst("Identifier=".count)) }
        }
        return d
    }

    private static func run(_ exe: URL, _ args: [String]) -> (out: String, err: String, status: Int32)? {
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        let o = Pipe(), e = Pipe()
        p.standardOutput = o
        p.standardError = e
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(3)
        let od = o.fileHandleForReading.readDataToEndOfFile()
        let ed = e.fileHandleForReading.readDataToEndOfFile()
        while p.isRunning, Date() < deadline { usleep(10_000) }
        if p.isRunning { p.terminate(); return nil }
        return (String(decoding: od, as: UTF8.self), String(decoding: ed, as: UTF8.self), p.terminationStatus)
    }
}
