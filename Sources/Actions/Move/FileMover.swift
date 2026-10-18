import Foundation
import HaloCore

public struct MovedItem: Equatable, Sendable {
    public let source: URL
    public let destination: URL
    /// True when the item got a Finder-style "name 2.ext" because the name was taken.
    public var wasRenamed: Bool { source.lastPathComponent != destination.lastPathComponent }
}

public struct MoveFailure: Equatable, Sendable {
    public let item: URL
    public let message: String
}

public struct MoveReport: Equatable, Sendable {
    public var moved: [MovedItem] = []
    /// Items whose folder already was the destination (nothing to do).
    public var alreadyThere: [URL] = []
    public var failures: [MoveFailure] = []
}

/// Why a whole move is refused before anything is touched.
public enum MoveRefusal: Error, Equatable, Sendable {
    case nothingToMove
    case destinationMissing(String)
    case destinationNotFolder(String)
    /// A folder can't go inside itself or one of its own subfolders.
    case intoItself(String)

    public var message: String {
        switch self {
        case .nothingToMove:
            String(localized: "There’s nothing to move.")
        case .destinationMissing(let name):
            String(localized: "“\(name)” isn’t there any more.")
        case .destinationNotFolder(let name):
            String(localized: "“\(name)” isn’t a folder.")
        case .intoItself(let name):
            String(localized: "“\(name)” can’t be moved into itself.")
        }
    }
}

/// Moves items into a folder. **Never overwrites**: a taken name becomes
/// "name 2.ext", "name 3.ext" (Finder style, via `OutputNamer.freeURL`), and
/// every placement is an exclusive `renamex_np(RENAME_EXCL)`, so a file that
/// appears between the check and the move is never clobbered.
///
/// Same volume: one atomic rename. Different volume: copy to a hidden staging
/// name inside the destination, exclusively rename it into place, then remove
/// the original (so an interrupted copy never leaves a half file under the
/// real name, and the original is only removed after a complete copy).
public struct FileMover: Sendable {
    /// Tests only: take the different-volume path (copy + remove) even on one volume.
    let simulateCrossVolume: Bool

    public init() { simulateCrossVolume = false }

    init(simulateCrossVolume: Bool) { self.simulateCrossVolume = simulateCrossVolume }

    /// Refuses moves that make no sense before touching anything.
    public func check(_ items: [URL], into destination: URL) -> MoveRefusal? {
        guard !items.isEmpty else { return .nothingToMove }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let destName = destination.lastPathComponent
        guard fm.fileExists(atPath: destination.path, isDirectory: &isDir) else { return .destinationMissing(destName) }
        guard isDir.boolValue else { return .destinationNotFolder(destName) }
        let dest = Self.canonicalFolder(destination)
        for item in items where Self.isRealDirectory(item) {
            let path = Self.canonicalItem(item)
            if dest == path || dest.hasPrefix(path + "/") {
                return .intoItself(item.lastPathComponent)
            }
        }
        return nil
    }

    /// Moves every item it can, reporting each one. Call `check` first; this
    /// re-checks and moves nothing if the move is refused.
    public func move(_ items: [URL], into destination: URL) -> MoveReport {
        var report = MoveReport()
        if let refusal = check(items, into: destination) {
            report.failures = items.map { MoveFailure(item: $0, message: refusal.message) }
            return report
        }
        let dest = Self.canonicalFolder(destination)
        for item in items {
            if Self.canonicalFolder(item.deletingLastPathComponent()) == dest {
                report.alreadyThere.append(item)
                continue
            }
            do {
                let placed = try moveOne(item, into: destination)
                report.moved.append(MovedItem(source: item, destination: placed))
            } catch {
                report.failures.append(MoveFailure(item: item, message: error.message))
                Log.actions.error("move failed: \(item.lastPathComponent, privacy: .private) – \(error.detail, privacy: .public)")
            }
        }
        return report
    }

    // MARK: One item

    struct MoveIssue: Error {
        let message: String
        let detail: String
    }

    private func moveOne(_ item: URL, into folder: URL) throws(MoveIssue) -> URL {
        let fm = FileManager.default
        let itemName = item.lastPathComponent
        let folderName = folder.lastPathComponent
        // lstat semantics: a symlink is moved as a link, never followed.
        guard (try? fm.attributesOfItem(atPath: item.path)) != nil else {
            throw MoveIssue(message: Self.message(errno: ENOENT, item: itemName, folder: folderName), detail: "missing")
        }
        let (base, ext) = Self.nameParts(of: item, isDirectory: Self.isRealDirectory(item), isPackage: Self.isPackage(item))
        for _ in 0..<10_000 {
            let candidate = OutputNamer.freeURL(in: folder, base: base, ext: ext)
            let err = simulateCrossVolume ? EXDEV : Self.renameExclusive(item, to: candidate)
            switch err {
            case 0:
                return candidate
            case EEXIST, ENOTEMPTY:
                continue // Someone took the name between the check and the rename: try the next.
            case EXDEV:
                return try copyAcrossVolumes(item, into: folder, base: base, ext: ext)
            default:
                throw MoveIssue(message: Self.message(errno: err, item: itemName, folder: folderName), detail: "rename errno \(err)")
            }
        }
        throw MoveIssue(message: Self.message(errno: -1, item: itemName, folder: folderName), detail: "no free name")
    }

    private func copyAcrossVolumes(_ item: URL, into folder: URL, base: String, ext: String) throws(MoveIssue) -> URL {
        let fm = FileManager.default
        let itemName = item.lastPathComponent
        let folderName = folder.lastPathComponent
        let staging = folder.appendingPathComponent(".\(itemName).\(Brand.slug)-moving-\(UUID().uuidString.prefix(8))")
        do {
            try fm.copyItem(at: item, to: staging)
        } catch {
            try? fm.removeItem(at: staging) // only ever our own partial copy
            throw MoveIssue(message: Self.message(cocoa: error, item: itemName, folder: folderName), detail: "\(error)")
        }
        var placed: URL?
        for _ in 0..<10_000 {
            let candidate = OutputNamer.freeURL(in: folder, base: base, ext: ext)
            let err = Self.renameExclusive(staging, to: candidate)
            if err == 0 { placed = candidate; break }
            if err == EEXIST || err == ENOTEMPTY { continue }
            try? fm.removeItem(at: staging)
            throw MoveIssue(message: Self.message(errno: err, item: itemName, folder: folderName), detail: "place errno \(err)")
        }
        guard let placed else {
            try? fm.removeItem(at: staging)
            throw MoveIssue(message: Self.message(errno: -1, item: itemName, folder: folderName), detail: "no free name")
        }
        do {
            try fm.removeItem(at: item)
        } catch {
            throw MoveIssue(
                message: String(localized: "Copied “\(itemName)” to “\(folderName)”, but couldn’t remove the original."),
                detail: "\(error)")
        }
        return placed
    }

    // MARK: Naming

    /// Splits a name so collisions read like Finder's: "photo 2.jpg",
    /// "archive 2.tar.gz", "Project 2" (folder), "Tool 2.app" (package),
    /// "Makefile 2", ".zshrc 2".
    public static func nameParts(of url: URL, isDirectory: Bool, isPackage: Bool) -> (base: String, ext: String) {
        let name = url.lastPathComponent
        if isDirectory && !isPackage { return (name, "") }
        let lower = name.lowercased()
        if lower.hasSuffix(".tar.gz") && name.count > 7 {
            return (String(name.dropLast(7)), String(name.suffix(6)))
        }
        let ext = url.pathExtension
        guard !ext.isEmpty else { return (name, "") }
        let base = url.deletingPathExtension().lastPathComponent
        guard !base.isEmpty else { return (name, "") }
        return (base, ext)
    }

    // MARK: Paths

    /// Canonical path of an item: symlinks resolved in its parent, but the
    /// item itself is not followed (moving a link moves the link).
    static func canonicalItem(_ url: URL) -> String {
        let std = url.standardizedFileURL
        if std.path == "/" { return "/" }
        let parent = std.deletingLastPathComponent().resolvingSymlinksInPath().path
        return (parent as NSString).appendingPathComponent(std.lastPathComponent)
    }

    /// Canonical path of a folder, symlinks fully resolved.
    static func canonicalFolder(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// A directory that is not a symlink to one.
    static func isRealDirectory(_ url: URL) -> Bool {
        let type = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
        return type == .typeDirectory
    }

    static func isPackage(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage ?? false
    }

    /// `renamex_np(RENAME_EXCL)`; returns 0 or the errno.
    static func renameExclusive(_ from: URL, to: URL) -> Int32 {
        from.withUnsafeFileSystemRepresentation { src -> Int32 in
            to.withUnsafeFileSystemRepresentation { dst -> Int32 in
                guard let src, let dst else { return EINVAL }
                return renamex_np(src, dst, UInt32(RENAME_EXCL)) == 0 ? 0 : errno
            }
        }
    }

    // MARK: Messages

    static func message(errno err: Int32, item: String, folder: String) -> String {
        switch err {
        case EACCES, EPERM: String(localized: "You don’t have permission to move “\(item)”.")
        case ENOENT: String(localized: "“\(item)” isn’t there any more.")
        case EROFS: String(localized: "“\(folder)” is on a read-only disk.")
        case ENOSPC: String(localized: "There isn’t enough space for “\(item)” in “\(folder)”.")
        case EINVAL: String(localized: "“\(item)” can’t be moved into itself.")
        case EBUSY: String(localized: "“\(item)” is in use.")
        default: String(localized: "Couldn’t move “\(item)”.")
        }
    }

    static func message(cocoa error: Error, item: String, folder: String) -> String {
        guard let e = error as? CocoaError else { return message(errno: -1, item: item, folder: folder) }
        switch e.code {
        case .fileWriteOutOfSpace: return message(errno: ENOSPC, item: item, folder: folder)
        case .fileWriteVolumeReadOnly: return message(errno: EROFS, item: item, folder: folder)
        case .fileWriteNoPermission, .fileReadNoPermission: return message(errno: EACCES, item: item, folder: folder)
        case .fileNoSuchFile, .fileReadNoSuchFile: return message(errno: ENOENT, item: item, folder: folder)
        default: return message(errno: -1, item: item, folder: folder)
        }
    }
}

private extension Error {
    var message: String { (self as? FileMover.MoveIssue)?.message ?? String(localized: "Couldn’t move the item.") }
    var detail: String { (self as? FileMover.MoveIssue)?.detail ?? "\(self)" }
}
