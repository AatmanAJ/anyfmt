import XCTest
@testable import HaloCore

final class ArchiveTests: XCTestCase {
    private let engine = ArchiveEngine()

    private func list(_ archive: URL) throws -> [String] {
        let p = Process()
        p.executableURL = ArchiveEngine.bsdtar
        p.arguments = ["-tf", archive.path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map { String($0).precomposedStringWithCanonicalMapping }
    }

    private func files(in dir: URL) -> [String] {
        let root = dir.resolvingSymlinksInPath().standardizedFileURL.path
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])
        var out: [String] = []
        while let u = e?.nextObject() as? URL {
            if (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                let p = u.resolvingSymlinksInPath().standardizedFileURL.path
                out.append(String(p.dropFirst(root.count + 1)).precomposedStringWithCanonicalMapping)
            }
        }
        return out.sorted()
    }

    func testFolderToEveryArchiveAndBack() async throws {
        let folder = try DocsFixtures.url("sample-folder")
        let expected = files(in: folder)
        XCTAssertTrue(expected.contains("Ünïcødé – notes.md".precomposedStringWithCanonicalMapping))
        for to in [Formats.zip, Formats.tar, Formats.gz, Formats.sevenZip] {
            let out = try await runEngine(engine, folder, from: Formats.folder, to: to, baseName: "sample-folder")
            XCTAssertEqual(out.count, 1)
            let names = try list(out[0])
            XCTAssertTrue(names.contains { $0.hasPrefix("sample-folder/sub dir/") }, "\(to): \(names)")
            let from: FormatID = to
            let back = try await runEngine(engine, out[0], from: from, to: Formats.folder, baseName: "sample-folder")
            XCTAssertEqual(back[0].lastPathComponent, "sample-folder")
            XCTAssertEqual(files(in: back[0]), expected, "\(to) round trip, top folder unwrapped (no sample-folder/sample-folder)")
        }
        let tgz = try await runEngine(engine, folder, from: Formats.folder, to: Formats.gz)
        XCTAssertTrue(tgz.first?.lastPathComponent.hasSuffix(".tar.gz") ?? false)
    }

    func testMultipleInputsCombineIntoOneArchive() async throws {
        let dir = try tempDir("multi")
        let a = dir.appendingPathComponent("one folder", isDirectory: true)
        let b = dir.appendingPathComponent("two", isDirectory: true)
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        try Data("1".utf8).write(to: a.appendingPathComponent("x.txt"))
        try Data("2".utf8).write(to: b.appendingPathComponent("-dash.txt"))
        for to in [Formats.zip, Formats.tar] {
            let out = try await runEngine(engine, a, from: Formats.folder, to: to, baseName: "Archive", inputs: [a, b])
            let names = try list(out[0])
            XCTAssertTrue(names.contains("one folder/x.txt"), "\(names)")
            XCTAssertTrue(names.contains("two/-dash.txt"), "names starting with '-' are never parsed as options: \(names)")
        }
    }

    func testExtractRAR7zGzipAndConvertBetweenArchives() async throws {
        let rar = try await runEngine(engine, try DocsFixtures.url("sample.rar"), from: Formats.rar, to: Formats.folder, baseName: "sample")
        XCTAssertEqual(files(in: rar[0]), ["data/numbers.csv", "readme.txt"])
        XCTAssertEqual(try String(contentsOf: rar[0].appendingPathComponent("readme.txt"), encoding: .utf8), "Hello from a RAR archive.\n")
        let seven = try await runEngine(engine, try DocsFixtures.url("sample.7z"), from: Formats.sevenZip, to: Formats.folder, baseName: "sample")
        XCTAssertTrue(files(in: seven[0]).contains("sub dir/deep/pixel.png"))
        // Plain gzip of one file → folder holding that file under its original name.
        let gz = try await runEngine(engine, try DocsFixtures.url("sample.gz"), from: Formats.gz, to: Formats.folder, baseName: "sample")
        XCTAssertEqual(files(in: gz[0]), ["notes.txt"])
        // RAR → ZIP keeps the single top folder.
        let zip = try await runEngine(engine, try DocsFixtures.url("sample.rar"), from: Formats.rar, to: Formats.zip, baseName: "sample")
        let zipNames = try list(zip[0])
        XCTAssertTrue(zipNames.contains("sample/readme.txt"), "\(zipNames)")
        // gz (single file) → zip holds the file at the root.
        let z2 = try await runEngine(engine, try DocsFixtures.url("sample.gz"), from: Formats.gz, to: Formats.zip, baseName: "sample")
        XCTAssertEqual(try list(z2[0]), ["notes.txt"])
    }

    func testPathTraversalNeverEscapes() async throws {
        let out = try await runEngine(engine, try DocsFixtures.url("edge-zipslip.tar"), from: Formats.tar, to: Formats.folder, baseName: "edge")
        let root = out[0].deletingLastPathComponent()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("evil.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/tmp/halo-absolute-evil.txt"))
        XCTAssertTrue(files(in: out[0]).contains("safe/ok.txt"))
        let zip = try await runEngine(engine, try DocsFixtures.url("edge-zipslip.zip"), from: Formats.zip, to: Formats.folder, baseName: "edge")
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip[0].deletingLastPathComponent().appendingPathComponent("evil.txt").path))
        XCTAssertTrue(files(in: zip[0]).contains("safe/ok.txt"))
    }

    func testGzipStreamingRoundTrip() throws {
        let dir = try tempDir("gz")
        let src = dir.appendingPathComponent("big file.txt")
        try Data(String(repeating: "gzip stream test line\n", count: 200_000).utf8).write(to: src)
        let gz = dir.appendingPathComponent("big file.txt.gz")
        try Gzip.compress(src, to: gz)
        XCTAssertEqual(Gzip.originalName(gz), "big file.txt")
        // System gzip agrees.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        p.arguments = ["-t", gz.path]
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        let back = dir.appendingPathComponent("back.txt")
        try Gzip.decompress(gz, to: back)
        XCTAssertEqual(try Data(contentsOf: back), try Data(contentsOf: src))
    }
}
