import XCTest
@testable import HaloCore

final class OutputNamerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("namer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func touch(_ name: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try Data(name.utf8).write(to: u)
        return u
    }

    func testBaseNameAndToolSuffix() {
        let u = URL(fileURLWithPath: "/x/photo.heic")
        XCTAssertEqual(OutputNamer.baseName(for: u), "photo")
        XCTAssertEqual(OutputNamer.baseName(for: u, toolSuffix: "compressed"), "photo-compressed")
        XCTAssertEqual(OutputNamer.baseName(for: u, pattern: "{name} ({format})", targetLabel: "JPG"), "photo (JPG)")
        XCTAssertEqual(OutputNamer.stem(of: URL(fileURLWithPath: "/x/a.tar.gz")), "a")
    }

    func testFinderStyleCollisions() throws {
        _ = try touch("photo.png")
        XCTAssertEqual(OutputNamer.freeURL(in: dir, base: "photo", ext: "png").lastPathComponent, "photo 2.png")
        _ = try touch("photo 2.png")
        XCTAssertEqual(OutputNamer.freeURL(in: dir, base: "photo", ext: "png").lastPathComponent, "photo 3.png")
    }

    func testPlaceNeverOverwrites() throws {
        let existing = try touch("doc.pdf")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(UUID().uuidString).pdf")
        try Data("new".utf8).write(to: tmp)
        let placed = try OutputNamer.place(tmp, in: dir, base: "doc", ext: "pdf")
        XCTAssertEqual(placed.lastPathComponent, "doc 2.pdf")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "doc.pdf", "original untouched")
        XCTAssertEqual(try String(contentsOf: placed, encoding: .utf8), "new")
    }

    func testPlacerGroupsMultipleOutputsIntoFolder() throws {
        let input = try touch("deck.pdf")
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("w-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var files: [URL] = []
        for i in 1...3 {
            let f = work.appendingPathComponent("deck-\(i).png")
            try Data().write(to: f)
            files.append(f)
        }
        let out = try OutputPlacer(policy: .default).place(files, for: input, target: "png")
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].lastPathComponent, "deck (PNG)")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: out[0].path).count, 3)
    }

    func testPreservesDatesForConversions() throws {
        let input = try touch("old.heic")
        let past = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: input.path)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("o-\(UUID().uuidString).jpg")
        try Data().write(to: tmp)
        let out = try OutputPlacer(policy: .default).place([tmp], for: input, target: "jpg")
        let m = try FileManager.default.attributesOfItem(atPath: out[0].path)[.modificationDate] as? Date
        XCTAssertEqual(m?.timeIntervalSince1970 ?? 0, past.timeIntervalSince1970, accuracy: 1)
    }
}
