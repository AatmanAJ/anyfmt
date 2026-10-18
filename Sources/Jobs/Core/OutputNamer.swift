import Foundation

/// Output naming + placement. The one rule: **never overwrite**.
///
/// `name.ext` → `name.png`; on collision `name 2.png`, `name 3.png` (Finder
/// style). Placement uses `renamex_np(RENAME_EXCL)` so a file appearing
/// between the check and the move can't be clobbered (no TOCTOU race).
public enum OutputNamer {
    /// Base name for an output: applies the pattern and tool suffix.
    /// - Parameters:
    ///   - input: the original file.
    ///   - pattern: OutputPolicy.namePattern ("{name}" default).
    ///   - targetLabel: e.g. "JPG" for {format}.
    ///   - toolSuffix: e.g. "compressed" → "photo-compressed".
    public static func baseName(for input: URL, pattern: String = "{name}", targetLabel: String = "",
                                toolSuffix: String? = nil, date: Date = Date()) -> String {
        let name = stem(of: input)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        var s = pattern.isEmpty ? "{name}" : pattern
        s = s.replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{format}", with: targetLabel)
            .replacingOccurrences(of: "{date}", with: df.string(from: date))
            .replacingOccurrences(of: "{tool}", with: toolSuffix ?? "")
        if let toolSuffix, !toolSuffix.isEmpty, !pattern.contains("{tool}") { s += "-\(toolSuffix)" }
        s = sanitize(s)
        return s.isEmpty ? name : s
    }

    /// File name without extension; `archive.tar.gz` → `archive`.
    public static func stem(of url: URL) -> String {
        var u = url
        if u.pathExtension.lowercased() == "gz", u.deletingPathExtension().pathExtension.lowercased() == "tar" {
            u = u.deletingPathExtension()
        }
        return u.deletingPathExtension().lastPathComponent
    }

    static func sanitize(_ s: String) -> String {
        // "/" and ":" are invalid in macOS file names; collapse whitespace.
        let cleaned = s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First free URL in `directory` for `base` + `ext`: "base.ext", "base 2.ext", …
    /// `ext` may be empty (folders) or compound ("tar.gz").
    public static func freeURL(in directory: URL, base: String, ext: String, fileManager: FileManager = .default) -> URL {
        var n = 1
        while true {
            let u = candidate(directory, base, ext, n)
            if !fileManager.fileExists(atPath: u.path) && !isSymlink(u) { return u }
            n += 1
        }
    }

    static func candidate(_ dir: URL, _ base: String, _ ext: String, _ n: Int) -> URL {
        let name = n == 1 ? base : "\(base) \(n)"
        return dir.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
    }

    private static func isSymlink(_ u: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: u.path)) != nil
    }

    /// Atomically moves `source` to the first free name in `directory`.
    /// Never replaces an existing item. Returns the final URL.
    @discardableResult
    public static func place(_ source: URL, in directory: URL, base: String, ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var n = 1
        while n < 10_000 {
            let dest = candidate(directory, base, ext, n)
            let rc: Int32 = source.withUnsafeFileSystemRepresentation { src in
                dest.withUnsafeFileSystemRepresentation { dst in
                    guard let src, let dst else { errno = EINVAL; return -1 }
                    return renamex_np(src, dst, UInt32(RENAME_EXCL))
                }
            }
            if rc == 0 { return dest }
            switch errno {
            case EEXIST, ENOTEMPTY:
                n += 1
            case EXDEV:
                // Different volume: copy exclusively, then remove the temp source.
                if FileManager.default.fileExists(atPath: dest.path) { n += 1; continue }
                do {
                    try FileManager.default.copyItem(at: source, to: dest) // fails if dest exists
                    try? FileManager.default.removeItem(at: source)
                    return dest
                } catch CocoaError.fileWriteFileExists {
                    n += 1
                }
            default:
                throw ConversionError.other(L("Couldn’t save the result."), detail: "rename \(source.path) → \(dest.path): errno \(errno)")
            }
        }
        throw ConversionError.other(L("Couldn’t find a free file name."), detail: base)
    }

    /// Copies creation/modification dates from `original` onto `output`.
    public static func copyDates(from original: URL, to output: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: original.path) else { return }
        var set: [FileAttributeKey: Any] = [:]
        if let c = attrs[.creationDate] { set[.creationDate] = c }
        if let m = attrs[.modificationDate] { set[.modificationDate] = m }
        try? FileManager.default.setAttributes(set, ofItemAtPath: output.path)
    }

    /// Directory outputs for `input` go to under `policy`.
    public static func outputDirectory(for input: URL, policy: OutputPolicy) -> URL {
        switch policy.location {
        case .besideOriginal: input.deletingLastPathComponent()
        case .folder(let u): u
        }
    }
}

/// Places a job's temp outputs into the user's folder following the policy.
public struct OutputPlacer: Sendable {
    public let policy: OutputPolicy
    public init(policy: OutputPolicy) { self.policy = policy }

    /// - Parameters:
    ///   - files: what the engine wrote (temp dir).
    ///   - input: the original (decides directory + base name).
    ///   - target: output format (decides extension).
    ///   - toolSuffix: tool name tag, nil for conversions.
    ///   - preserveDates: conversions copy the source dates when the policy allows.
    /// Multiple files are grouped into a folder named after the input (also collision-safe).
    public func place(_ files: [URL], for input: URL, target: FormatID?, toolSuffix: String? = nil) throws -> [URL] {
        guard !files.isEmpty else { throw ConversionError.outputMissing(input.lastPathComponent) }
        let dir = OutputNamer.outputDirectory(for: input, policy: policy)
        let label = target.map(Formats.label) ?? ""
        let base = OutputNamer.baseName(for: input, pattern: policy.namePattern, targetLabel: label, toolSuffix: toolSuffix)
        let preserve = policy.preserveDates && toolSuffix == nil
        if files.count == 1 {
            let f = files[0]
            let ext = Self.ext(of: f, target: target)
            let out = try OutputNamer.place(f, in: dir, base: base, ext: ext)
            if preserve { OutputNamer.copyDates(from: input, to: out) }
            return [out]
        }
        // Many files: put them in a fresh folder "<base>" (or "<base> 2"…), keeping engine names.
        let folderName = target.map { "\(base) (\(Formats.label($0)))" } ?? base
        let staging = files[0].deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        for f in files {
            try FileManager.default.moveItem(at: f, to: staging.appendingPathComponent(f.lastPathComponent))
        }
        let folder = try OutputNamer.place(staging, in: dir, base: folderName, ext: "")
        return [folder]
    }

    static func ext(of file: URL, target: FormatID?) -> String {
        let name = file.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") { return "tar.gz" }
        // One plain file gzipped keeps its own extension: notes.txt → notes.txt.gz.
        if target == Formats.gz, file.pathExtension.lowercased() == "gz" {
            let inner = file.deletingPathExtension().pathExtension
            if !inner.isEmpty { return inner + ".gz" }
        }
        if target == Formats.folder { return "" }
        if let target, file.pathExtension.isEmpty { return Formats.extension(for: target) }
        return file.pathExtension
    }
}
