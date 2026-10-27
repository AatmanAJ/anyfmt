import CryptoKit
import Foundation

/// Optional, user-initiated engine packs (never bundled, never downloaded by us).
/// The user downloads the official file in their browser; we verify it against a
/// pinned SHA-256 and install it into Application Support. Until a release
/// engineer fills in the pin (see docs/lanes/F-docs.md), installs are refused.
public struct PackSpec: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        /// A disk image containing `appName` at its root (LibreOffice).
        case dmg(appName: String)
        /// A zip whose single top folder contains `binary` (pandoc: "bin/pandoc").
        case zip(binary: String)
    }

    public let name: String
    public let version: String
    /// Official download page or file the user is sent to (we never fetch it).
    public let downloadURL: URL?
    /// Lowercase hex SHA-256 of the official file; nil = not pinned yet.
    public let sha256: String?
    public let kind: Kind
    /// Folder name inside the packs directory.
    public let installName: String

    public init(name: String, version: String, downloadURL: URL?, sha256: String?, kind: Kind, installName: String) {
        self.name = name
        self.version = version
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.kind = kind
        self.installName = installName
    }
}

public enum OfficePack {
    /// LibreOffice (MPL-2.0), Apple silicon build. Pinned 2026-10-27 after `gpg --verify` of the
    /// `.asc` passed against The Document Foundation's release key
    /// (C2839ECAD9408FBE9531C3E9F434A1EFAFEEAEA3, "LibreOffice Build Team").
    public static let spec = PackSpec(
        name: "LibreOffice", version: "26.8.1",
        downloadURL: URL(string: "https://download.documentfoundation.org/libreoffice/stable/26.8.1/mac/aarch64/LibreOffice_26.8.1_MacOS_aarch64.dmg"),
        sha256: "ca074e0b13571efb30a31fc531c5f95e997030637325e5d5de92d67aefdf0dfc", kind: .dmg(appName: "LibreOffice.app"), installName: "LibreOffice.app")
}

public enum PandocPack {
    /// pandoc (GPL-2.0-or-later). Values mirror Engines/versions.env (PANDOC_URL / PANDOC_SHA256).
    public static let spec = PackSpec(
        name: "pandoc", version: "3.12.1",
        downloadURL: URL(string: "https://github.com/jgm/pandoc/releases/download/3.12.1/pandoc-3.12.1-arm64-macOS.zip"),
        sha256: "c2146cf33a583f3ac93eccddf1bb662371d5cfcce1aad1c87ad860cca1435d46", kind: .zip(binary: "bin/pandoc"), installName: "pandoc")
}

/// System tools the installer needs, injectable for tests.
public protocol PackSystem: Sendable {
    /// Mounts a disk image read-only at `mountPoint`.
    func attach(_ dmg: URL, at mountPoint: URL) async throws
    func detach(_ mountPoint: URL) async throws
    /// Copies a bundle/folder preserving metadata (`ditto`).
    func copy(_ source: URL, to destination: URL) async throws
    /// Expands a zip into `destination` (`ditto -x -k`).
    func unzip(_ zip: URL, to destination: URL) async throws
}

public struct LivePackSystem: PackSystem {
    public init() {}
    public func attach(_ dmg: URL, at mountPoint: URL) async throws {
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/hdiutil"),
                                        ["attach", "-nobrowse", "-readonly", "-noautoopen", "-noverify", "-mountpoint", mountPoint.path, dmg.path])
    }
    public func detach(_ mountPoint: URL) async throws {
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/hdiutil"), ["detach", mountPoint.path, "-force"], checkExit: false)
    }
    public func copy(_ source: URL, to destination: URL) async throws {
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), [source.path, destination.path])
    }
    public func unzip(_ zip: URL, to destination: URL) async throws {
        // The archive was checksum-verified, so don't carry the browser's quarantine flag onto the CLI binary.
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", "--noqtn", zip.path, destination.path])
    }
}

public struct PackInstaller: Sendable {
    public enum Failure: Error, LocalizedError, Equatable {
        case notPinned(String), checksumMismatch(expected: String, actual: String), layout(String)
        public var errorDescription: String? {
            switch self {
            case .notPinned(let n): L("\(n) can’t be installed by this build yet (no verified checksum).")
            case .checksumMismatch: L("The downloaded file doesn’t match the official release. Download it again from the official site.")
            case .layout(let d): L("The downloaded file isn’t the expected package (\(d)).")
            }
        }
    }

    public let spec: PackSpec
    public let packsDirectory: URL
    public let system: any PackSystem

    public init(spec: PackSpec, packsDirectory: URL = EngineLocator.packsDirectory, system: any PackSystem = LivePackSystem()) {
        self.spec = spec
        self.packsDirectory = packsDirectory
        self.system = system
    }

    public var installedURL: URL { packsDirectory.appendingPathComponent(spec.installName) }

    /// Streaming SHA-256 of a file, lowercase hex.
    public static func sha256(of url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Verifies the file against the pin, then installs (replacing an older install atomically).
    @discardableResult
    public func install(from file: URL) async throws -> URL {
        guard let pin = spec.sha256?.lowercased(), pin.count == 64 else { throw Failure.notPinned(spec.name) }
        let actual = try Self.sha256(of: file)
        guard actual == pin else { throw Failure.checksumMismatch(expected: pin, actual: actual) }
        let fm = FileManager.default
        try fm.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        let staging = packsDirectory.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        let staged = staging.appendingPathComponent(spec.installName)
        switch spec.kind {
        case .dmg(let appName):
            let mount = staging.appendingPathComponent("mnt", isDirectory: true)
            try fm.createDirectory(at: mount, withIntermediateDirectories: true)
            try await system.attach(file, at: mount)
            do {
                let app = mount.appendingPathComponent(appName)
                guard fm.fileExists(atPath: app.path) else { throw Failure.layout("no \(appName)") }
                try await system.copy(app, to: staged)
                try await system.detach(mount)
            } catch {
                try? await system.detach(mount)
                throw error
            }
        case .zip(let binary):
            let expanded = staging.appendingPathComponent("x", isDirectory: true)
            try await system.unzip(file, to: expanded)
            // The binary sits under one top-level folder (pandoc-3.12.1-arm64/bin/pandoc) or at the root.
            let tops = (try? fm.contentsOfDirectory(at: expanded, includingPropertiesForKeys: nil)) ?? []
            guard let root = ([expanded] + tops).first(where: { fm.fileExists(atPath: $0.appendingPathComponent(binary).path) }) else {
                throw Failure.layout("no \(binary)")
            }
            try fm.moveItem(at: root, to: staged)
            let bin = staged.appendingPathComponent(binary)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bin.path)
        }
        let dest = installedURL
        if fm.fileExists(atPath: dest.path) {
            _ = try fm.replaceItemAt(dest, withItemAt: staged)
        } else {
            try fm.moveItem(at: staged, to: dest)
        }
        return dest
    }

    public func uninstall() throws {
        if FileManager.default.fileExists(atPath: installedURL.path) { try FileManager.default.removeItem(at: installedURL) }
    }
}

// MARK: - Engines

/// LibreOffice from the Office pack: faithful slides → PDF/images and legacy
/// Office (PPT/XLS/DOC), Keynote/Pages/Numbers import. Rows are `.needsPack`.
public struct OfficePackEngine: ConversionEngine {
    public let id = EngineIDs.officePack
    let soffice: @Sendable () -> URL?

    public init(soffice: @escaping @Sendable () -> URL? = { EngineLocator.shared.officePackSoffice }) {
        self.soffice = soffice
    }

    public func isAvailable(_ capability: Capability) -> Bool { soffice() != nil }

    static func filter(_ to: FormatID) -> String? {
        switch to {
        case Formats.pdf: "pdf"
        case Formats.docx: "docx:MS Word 2007 XML"
        case Formats.odt: "odt"
        case Formats.xlsx: "xlsx:Calc MS Excel 2007 XML"
        case Formats.ods: "ods"
        case Formats.csv: "csv:Text - txt - csv (StarCalc):44,34,76,1"
        case Formats.pptx: "pptx:Impress MS PowerPoint 2007 XML"
        case Formats.odp: "odp"
        default: nil
        }
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let soffice = soffice() else { throw ConversionError.engineMissing("LibreOffice", detail: "Office pack not installed") }
        let imageTarget = request.to == Formats.png || request.to == Formats.jpg
        let target = imageTarget ? Formats.pdf : request.to
        guard let filter = Self.filter(target) else { throw ConversionError.unsupported(from: request.from, to: request.to) }
        let work = request.outputDirectory.appendingPathComponent(".lo-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let staged = work.appendingPathComponent("input").appendingPathExtension(request.input.pathExtension)
        try fm.copyItem(at: request.input, to: staged)
        let profile = work.appendingPathComponent("profile", isDirectory: true)
        let outDir = work.appendingPathComponent("out", isDirectory: true)
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        context.progress(0.1)
        _ = try await ProcessRunner.run(soffice, [
            "--headless", "--norestore", "--nologo", "--nodefault", "--nolockcheck",
            "-env:UserInstallation=\(profile.absoluteString)",
            "--convert-to", filter, "--outdir", outDir.path, staged.path,
        ], environment: ["HOME": work.path, "PATH": "/usr/bin:/bin"])
        let produced = outDir.appendingPathComponent("input").appendingPathExtension(Formats.extension(for: target))
        guard fm.fileExists(atPath: produced.path) else { throw ConversionError.outputMissing(produced.lastPathComponent) }
        context.progress(0.8)
        if imageTarget {
            let files = try PDFRaster.writePages(produced, to: request.outputDirectory, baseName: request.baseName,
                                                 type: request.to == Formats.png ? .png : .jpeg,
                                                 dpi: Double(request.options.string(OptionKey.dpi, default: "150")) ?? 150,
                                                 quality: Double(request.options.int(OptionKey.quality, default: 90)) / 100)
            return ConversionOutput(files)
        }
        let out = request.defaultOutputURL
        try fm.moveItem(at: produced, to: out)
        context.progress(1)
        return ConversionOutput(out)
    }
}

/// pandoc from the pandoc pack, preferred for package ↔ package documents when
/// installed. Only DOCX/ODT/EPUB inputs: their images are inside the package, so
/// pandoc never has a reason to fetch anything (it would for remote images in
/// Markdown/HTML, which our no-network rule forbids).
public struct PandocPackEngine: ConversionEngine {
    public let id = EngineIDs.pandocPack
    let pandoc: @Sendable () -> URL?

    public init(pandoc: @escaping @Sendable () -> URL? = { EngineLocator.shared.pandocPack }) {
        self.pandoc = pandoc
    }

    public func isAvailable(_ capability: Capability) -> Bool { pandoc() != nil }

    static func name(_ f: FormatID, output: Bool) -> String? {
        switch f {
        case Formats.docx: "docx"
        case Formats.odt: "odt"
        case Formats.epub: output ? "epub3" : "epub"
        default: nil
        }
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let pandoc = pandoc() else { throw ConversionError.engineMissing("pandoc", detail: "pandoc pack not installed") }
        guard let from = Self.name(request.from, output: false), let to = Self.name(request.to, output: true) else {
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        let out = request.defaultOutputURL
        let args = ["--from", from, "--to", to, "--output", out.path, request.input.path]
        context.progress(0.1)
        _ = try await ProcessRunner.run(pandoc, args, currentDirectory: request.outputDirectory)
        context.progress(1)
        return ConversionOutput(out)
    }
}
