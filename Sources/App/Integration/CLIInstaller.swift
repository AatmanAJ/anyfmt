import Foundation
import AnyfmtCore

/// Offers the bundled `anyfmt` command-line tool on the user's PATH by
/// symlinking it (BUILD.md §9). Never needs admin rights: it uses the first
/// writable directory that's already on PATH, preferring Homebrew's and the
/// user's own bin folders, and otherwise reports the exact command to run.
enum CLIInstaller {
    static var bundledTool: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(Brand.cliName)")
    }

    static let candidateDirectories: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin"),
            home.appendingPathComponent(".local/bin"),
            home.appendingPathComponent("bin"),
        ]
    }()

    enum Status: Equatable {
        case installed(URL)
        case notInstalled
        case linkPointsElsewhere(URL)
    }

    static func status() -> Status {
        for dir in candidateDirectories {
            let link = dir.appendingPathComponent(Brand.cliName)
            guard let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else { continue }
            let resolved = URL(fileURLWithPath: dest, relativeTo: dir).standardizedFileURL
            return resolved.path == bundledTool.standardizedFileURL.path ? .installed(link) : .linkPointsElsewhere(link)
        }
        return .notInstalled
    }

    /// Directories that are on PATH (as seen by a login shell) and writable.
    static func writableTargets(path: String = ProcessInfo.processInfo.environment["PATH"] ?? "") -> [URL] {
        let onPath = Set(path.split(separator: ":").map { URL(fileURLWithPath: String($0)).standardizedFileURL.path })
        return candidateDirectories.filter {
            FileManager.default.isWritableFile(atPath: $0.path) && (onPath.isEmpty || onPath.contains($0.standardizedFileURL.path))
        }
    }

    /// Creates the symlink. Returns the link URL, or throws with the manual command.
    @discardableResult
    static func install() throws -> URL {
        guard let dir = writableTargets().first ?? candidateDirectories.first(where: { FileManager.default.isWritableFile(atPath: $0.path) }) else {
            throw ConversionError.other(L("No writable folder on your PATH. Run this in Terminal:"), detail: manualCommand)
        }
        let link = dir.appendingPathComponent(Brand.cliName)
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil {
            try FileManager.default.removeItem(at: link) // only ever replaces a symlink, never a real file
        } else if FileManager.default.fileExists(atPath: link.path) {
            throw ConversionError.other(L("A different “\(Brand.cliName)” already exists there."), detail: link.path)
        }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundledTool)
        return link
    }

    static func uninstall() {
        if case .installed(let link) = status() { try? FileManager.default.removeItem(at: link) }
    }

    static var manualCommand: String {
        "sudo ln -sf \"\(bundledTool.path)\" /usr/local/bin/\(Brand.cliName)"
    }
}
