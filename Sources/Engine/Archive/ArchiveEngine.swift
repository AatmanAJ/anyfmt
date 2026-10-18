import Foundation

/// Archives with the system's own tools (zero size cost, D-023):
/// - create: `ditto -c -k --sequesterRsrc` for ZIP (Finder-faithful, keeps
///   resource forks/xattrs), `bsdtar` for TAR / TAR.GZ / 7z, our own streaming
///   gzip for a single file;
/// - extract: `bsdtar -x` into a fresh folder (bsdtar refuses `..` and strips
///   leading `/` by default; verified on macOS 27), plain-gzip fallback, and the
///   archive's single top folder is unwrapped when it repeats the archive name.
public struct ArchiveEngine: ConversionEngine {
    public let id = EngineIDs.archiveTool
    public static let bsdtar = URL(fileURLWithPath: "/usr/bin/bsdtar")
    public static let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
    public static let archives: Set<FormatID> = [Formats.zip, Formats.tar, Formats.gz, Formats.rar, Formats.sevenZip]

    public init() {}

    public func isAvailable(_ capability: Capability) -> Bool {
        FileManager.default.isExecutableFile(atPath: Self.bsdtar.path) && FileManager.default.isExecutableFile(atPath: Self.ditto.path)
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let level = min(max(request.options.int(OptionKey.compression, default: 6), 0), 9)
        context.progress(0.05)
        if request.to == Formats.folder {
            guard Self.archives.contains(request.from) else { throw ConversionError.unsupported(from: request.from, to: request.to) }
            let folder = try await Self.extract(request.input, format: request.from, into: request.outputDirectory, name: request.baseName).folder
            context.progress(1)
            return ConversionOutput(folder)
        }
        if Self.archives.contains(request.from) {
            // Archive → archive: unpack privately, then pack what came out.
            let scratch = request.outputDirectory.appendingPathComponent(".x-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratch) }
            let (folder, lifted) = try await Self.extract(request.input, format: request.from, into: scratch, name: request.baseName)
            context.progress(0.5)
            // Keep the original layout: one top folder stays one top folder, loose items stay loose.
            let items = lifted ? [folder] : try Self.children(of: folder)
            let packed = try await Self.pack(items.isEmpty ? [folder] : items, to: request.to, in: request.outputDirectory,
                                             baseName: request.baseName, level: level)
            context.progress(1)
            return ConversionOutput(packed)
        }
        let out = try await Self.pack(request.inputs, to: request.to, in: request.outputDirectory, baseName: request.baseName, level: level)
        context.progress(1)
        return ConversionOutput(out)
    }

    static func children(of dir: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != ".DS_Store" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func isDirectory(_ u: URL) -> Bool {
        var d: ObjCBool = false
        return FileManager.default.fileExists(atPath: u.path, isDirectory: &d) && d.boolValue
    }

    // MARK: Create

    static func pack(_ items: [URL], to format: FormatID, in dir: URL, baseName: String, level: Int) async throws -> URL {
        let fm = FileManager.default
        var sources = items
        var staging: URL?
        defer { if let staging { try? fm.removeItem(at: staging) } }
        if items.count > 1 {
            // Several items → one archive: clone them side by side (APFS clones are free).
            let s = dir.appendingPathComponent(".pack-\(UUID().uuidString)", isDirectory: true)
            let root = s
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            var used = Set<String>()
            for item in items {
                var name = item.lastPathComponent
                var n = 2
                while used.contains(name.lowercased()) {
                    let ext = (item.lastPathComponent as NSString).pathExtension
                    let stem = (item.lastPathComponent as NSString).deletingPathExtension
                    name = ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)"
                    n += 1
                }
                used.insert(name.lowercased())
                try fm.copyItem(at: item, to: root.appendingPathComponent(name))
            }
            staging = s
            sources = try children(of: s)
        }

        switch format {
        case Formats.zip:
            let out = dir.appendingPathComponent(baseName).appendingPathExtension("zip")
            if sources.count == 1 {
                // --keepParent embeds a folder's own name; for a single file it would embed the file's *parent*.
                let keep = isDirectory(sources[0]) ? ["--keepParent"] : []
                _ = try await ProcessRunner.run(ditto, ["-c", "-k", "--sequesterRsrc"] + keep + ["--zlibCompressionLevel", "\(level)", sources[0].path, out.path])
            } else if let staging {
                _ = try await ProcessRunner.run(ditto, ["-c", "-k", "--sequesterRsrc", "--zlibCompressionLevel", "\(level)", staging.path, out.path])
            }
            return out
        case Formats.tar:
            let out = dir.appendingPathComponent(baseName).appendingPathExtension("tar")
            try await bsdtarCreate(sources, out: out, extra: ["--format", "pax"])
            return out
        case Formats.sevenZip:
            let out = dir.appendingPathComponent(baseName).appendingPathExtension("7z")
            try await bsdtarCreate(sources, out: out, extra: ["--format", "7zip", "--options", "7zip:compression=lzma2,7zip:compression-level=\(level)"])
            return out
        case Formats.gz:
            if sources.count == 1, !isDirectory(sources[0]) {
                // One file: plain gzip, keeping its own extension (notes.txt → notes.txt.gz).
                let out = dir.appendingPathComponent(sources[0].lastPathComponent + ".gz")
                try Gzip.compress(sources[0], to: out)
                return out
            }
            let out = dir.appendingPathComponent(baseName + ".tar.gz")
            try await bsdtarCreate(sources, out: out, extra: ["-z", "--options", "gzip:compression-level=\(max(level, 1))"])
            return out
        default:
            throw ConversionError.unsupported(from: Formats.folder, to: format)
        }
    }

    /// `bsdtar -c` over items that may live in different folders, without any
    /// name ever being parsed as an option (names go in through `-T` with NULs).
    static func bsdtarCreate(_ items: [URL], out: URL, extra: [String]) async throws {
        let groups = Dictionary(grouping: items) { $0.deletingLastPathComponent().path }
        var args = ["-c", "-f", out.path, "--no-mac-metadata"] + extra
        let lists = out.deletingLastPathComponent().appendingPathComponent(".lists-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: lists, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: lists) }
        for (k, (parent, members)) in groups.sorted(by: { $0.key < $1.key }).enumerated() {
            let list = lists.appendingPathComponent("\(k).list")
            var data = Data()
            for m in members { data.append(Data(m.lastPathComponent.utf8)); data.append(0) }
            try data.write(to: list)
            args += ["-C", parent, "--null", "-T", list.path]
        }
        _ = try await ProcessRunner.run(bsdtar, args)
    }

    // MARK: Extract

    /// Extracts into `<dir>/<name>` (fresh). `lifted` = the archive's single top folder was unwrapped.
    static func extract(_ archive: URL, format: FormatID, into dir: URL, name: String) async throws -> (folder: URL, lifted: Bool) {
        let fm = FileManager.default
        let dest = dir.appendingPathComponent(name.isEmpty ? "Archive" : name, isDirectory: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let result = try await ProcessRunner.run(bsdtar, ["-x", "-f", archive.path, "-C", dest.path, "--no-same-owner"], checkExit: false)
        if result.status != 0 {
            let err = result.stderr
            let lower = err.lowercased()
            if lower.contains("passphrase") || lower.contains("encrypt") || lower.contains("password") {
                throw ConversionError.other(L("This archive is password-protected, which isn’t supported."), detail: err)
            }
            if format == Formats.gz, lower.contains("unrecognized archive format") || (try? children(of: dest).isEmpty) ?? true {
                // Not a tarball: plain gzip of one file.
                try? fm.removeItem(at: dest)
                try fm.createDirectory(at: dest, withIntermediateDirectories: true)
                let inner = Gzip.originalName(archive) ?? OutputNamer.stem(of: archive)
                try Gzip.decompress(archive, to: dest.appendingPathComponent(sanitize(inner)))
            } else if !onlyRefusals(err) {
                throw ConversionError.engineFailed("bsdtar", status: result.status, detail: err)
            } else {
                Log.engine.notice("archive: skipped unsafe members in \(archive.lastPathComponent, privacy: .private): \(err, privacy: .public)")
            }
        }
        // Finder's sidecar metadata folder isn't content.
        let macosx = dest.appendingPathComponent("__MACOSX")
        if fm.fileExists(atPath: macosx.path) { try? fm.removeItem(at: macosx) }
        let items = try children(of: dest)
        guard !items.isEmpty else { throw ConversionError.outputMissing(archive.lastPathComponent) }
        // archive.zip containing only "archive/" → don't produce "archive/archive/".
        if items.count == 1, isDirectory(items[0]), matches(items[0].lastPathComponent, name) || matches(items[0].lastPathComponent, OutputNamer.stem(of: archive)) {
            let inner = items[0]
            let lifted = dir.appendingPathComponent(".lift-\(UUID().uuidString)", isDirectory: true)
            try fm.moveItem(at: inner, to: lifted)
            try fm.removeItem(at: dest)
            try fm.moveItem(at: lifted, to: dest)
            return (dest, true)
        }
        return (dest, false)
    }

    static func matches(_ a: String, _ b: String) -> Bool {
        a.precomposedStringWithCanonicalMapping.lowercased() == b.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// bsdtar exits 1 after refusing unsafe members ("Path contains '..'") but extracts the rest; that's a success.
    static func onlyRefusals(_ stderr: String) -> Bool {
        let lines = stderr.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { l in
            l.contains("Path contains '..'") || l.contains("Removing leading") || l.contains("Error exit delayed") || l.contains("Cannot extract through symlink")
        }
    }

    static func sanitize(_ name: String) -> String {
        let n = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return n.isEmpty || n == "." || n == ".." ? "file" : n
    }
}

/// Streaming gzip (RFC 1952) on top of the Compression framework's raw deflate.
public enum Gzip {
    public enum Failure: Error, Sendable { case notGzip, truncated, crc }

    public static func compress(_ input: URL, to output: URL) throws {
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let inH = try FileHandle(forReadingFrom: input)
        let outH = try FileHandle(forWritingTo: output)
        defer { try? inH.close(); try? outH.close() }
        var header = Data([0x1F, 0x8B, 0x08, 0x08])
        let mtime = UInt32(clamping: Int((try? input.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970) ?? 0))
        header.le32(mtime)
        header.append(contentsOf: [0x00, 0x03])
        header.append(Data(input.lastPathComponent.utf8.filter { $0 != 0 }))
        header.append(0)
        try outH.write(contentsOf: header)
        let stream = try DeflateStream(.encode)
        var crc = CRC32()
        var size: UInt64 = 0
        while true {
            try Task.checkCancellation()
            let chunk = try inH.read(upToCount: 1 << 20) ?? Data()
            crc.update(chunk)
            size += UInt64(chunk.count)
            try stream.process(chunk, final: chunk.isEmpty) { try outH.write(contentsOf: $0) }
            if chunk.isEmpty { break }
        }
        var trailer = Data()
        trailer.le32(crc.value)
        trailer.le32(UInt32(truncatingIfNeeded: size))
        try outH.write(contentsOf: trailer)
    }

    /// Name stored in the gzip header (FNAME), if any.
    public static func originalName(_ url: URL) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url), let head = try? h.read(upToCount: 4096) else { return nil }
        try? h.close()
        let b = [UInt8](head)
        guard b.count > 10, b[0] == 0x1F, b[1] == 0x8B, b[3] & 0x08 != 0 else { return nil }
        var i = 10
        if b[3] & 0x04 != 0, b.count > 12 { i += 2 + (Int(b[10]) | Int(b[11]) << 8) }
        guard i < b.count else { return nil }
        guard let end = b[i...].firstIndex(of: 0) else { return nil }
        let name = String(decoding: b[i..<end], as: UTF8.self)
        return (name as NSString).lastPathComponent.isEmpty ? nil : (name as NSString).lastPathComponent
    }

    public static func decompress(_ input: URL, to output: URL) throws {
        let inH = try FileHandle(forReadingFrom: input)
        defer { try? inH.close() }
        let first = try inH.read(upToCount: 1 << 16) ?? Data()
        let b = [UInt8](first)
        guard b.count >= 18, b[0] == 0x1F, b[1] == 0x8B, b[2] == 8 else { throw Failure.notGzip }
        let flags = b[3]
        var i = 10
        if flags & 0x04 != 0 { guard b.count > 12 else { throw Failure.truncated }; i += 2 + (Int(b[10]) | Int(b[11]) << 8) }
        if flags & 0x08 != 0 { while i < b.count, b[i] != 0 { i += 1 }; i += 1 }
        if flags & 0x10 != 0 { while i < b.count, b[i] != 0 { i += 1 }; i += 1 }
        if flags & 0x02 != 0 { i += 2 }
        guard i < b.count else { throw Failure.truncated }
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let outH = try FileHandle(forWritingTo: output)
        defer { try? outH.close() }
        let stream = try DeflateStream(.decode)
        var chunk = first.subdata(in: first.startIndex + i ..< first.endIndex)
        while true {
            try Task.checkCancellation()
            let next = try inH.read(upToCount: 1 << 20) ?? Data()
            // The 8-byte trailer is ignored by the raw inflater once the stream ends.
            try stream.process(chunk, final: next.isEmpty) { out in
                try outH.write(contentsOf: out)
            }
            if next.isEmpty { break }
            chunk = next
        }
    }
}
