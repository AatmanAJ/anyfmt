import XCTest
@testable import HaloCore

final class ZipTests: XCTestCase {
    func testCRC32KnownValues() {
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(CRC32.checksum(Data()), 0)
        var c = CRC32()
        c.update(Data("1234".utf8))
        c.update(Data("56789".utf8))
        XCTAssertEqual(c.value, 0xCBF4_3926, "incremental CRC must match one-shot")
    }

    func testDeflateRoundTripIncludingLargeInput() throws {
        let text = Data(String(repeating: "Halo deflate round trip. ", count: 50_000).utf8)
        let packed = try Deflate.compress(text)
        XCTAssertLessThan(packed.count, text.count / 10)
        XCTAssertEqual(try Deflate.decompress(packed, expectedSize: text.count), text)
        var random = Data(count: 300_000)
        random.withUnsafeMutableBytes { for i in 0..<$0.count { $0[i] = UInt8.random(in: 0...255) } }
        XCTAssertEqual(try Deflate.decompress(try Deflate.compress(random)), random)
        XCTAssertEqual(try Deflate.decompress(try Deflate.compress(Data())), Data())
    }

    func testWriterReaderRoundTripStoredDeflatedUnicode() throws {
        var w = ZipWriter(options: .init(deterministic: true))
        try w.add("mimetype", "application/epub+zip", compress: false)
        try w.add("dir/naïve café.txt", String(repeating: "x", count: 5000))
        try w.addDirectory("empty")
        try w.add("bin.dat", Data([0, 1, 2, 3, 255]))
        let data = try w.finish()
        // mimetype first, stored, at offset 30 (EPUB/OCF requirement).
        XCTAssertEqual(String(decoding: data[30..<38], as: UTF8.self), "mimetype")
        XCTAssertEqual(data[8], 0, "method must be stored")
        let r = try ZipReader(data: data)
        XCTAssertEqual(r.entries.map(\.path), ["mimetype", "dir/naïve café.txt", "empty/", "bin.dat"])
        XCTAssertEqual(try r.text("mimetype"), "application/epub+zip")
        XCTAssertEqual(try r.text("dir/naïve café.txt").count, 5000)
        XCTAssertEqual(r.entry("dir/naïve café.txt")?.method, 8)
        XCTAssertEqual(try r.data("bin.dat"), Data([0, 1, 2, 3, 255]))
        XCTAssertEqual(r.entry("DIR/NAÏVE CAFÉ.TXT")?.path, "dir/naïve café.txt", "case-insensitive fallback")
        // Deterministic: same input → same bytes.
        var w2 = ZipWriter(options: .init(deterministic: true))
        try w2.add("mimetype", "application/epub+zip", compress: false)
        try w2.add("dir/naïve café.txt", String(repeating: "x", count: 5000))
        try w2.addDirectory("empty")
        try w2.add("bin.dat", Data([0, 1, 2, 3, 255]))
        XCTAssertEqual(try w2.finish(), data)
        // System unzip agrees.
        let dir = try tempDir("zip")
        let file = dir.appendingPathComponent("t.zip")
        try data.write(to: file)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-tq", file.path]
        p.standardOutput = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "unzip -t must accept our archive")
    }

    func testWriterRejectsUnsafeAndDuplicateNames() {
        var w = ZipWriter()
        XCTAssertThrowsError(try w.add("../x", Data()))
        XCTAssertThrowsError(try w.add("/abs", Data()))
        XCTAssertNoThrow(try w.add("a", Data()))
        XCTAssertThrowsError(try w.add("a", Data()))
    }

    func testCorruptionIsDetected() throws {
        var w = ZipWriter(options: .init(deterministic: true))
        try w.add("a.txt", Data("hello hello hello hello hello hello hello hello hello hello hello hello".utf8), compress: false)
        var data = try w.finish()
        data[30 + 5 + 2] ^= 0xFF  // flip a payload byte
        let r = try ZipReader(data: data)
        XCTAssertThrowsError(try r.data("a.txt")) { e in
            guard case ZipReader.Failure.crcMismatch = e else { return XCTFail("expected CRC failure, got \(e)") }
        }
        XCTAssertThrowsError(try ZipReader(data: Data("not a zip".utf8)))
    }

    func testZip64CentralDirectoryIsRead() throws {
        // Hand-built archive whose central directory uses ZIP64 sizes/offset and a ZIP64 EOCD.
        let payload = Data("zip64 payload".utf8)
        let crc = CRC32.checksum(payload)
        var d = Data()
        d.le32(0x0403_4B50); d.le16(45); d.le16(0); d.le16(0); d.le16(0); d.le16(0x21); d.le32(crc)
        d.le32(0xFFFF_FFFF); d.le32(0xFFFF_FFFF); d.le16(5); d.le16(20)
        d.append(Data("a.txt".utf8))
        d.le16(0x0001); d.le16(16); d.append(le64(UInt64(payload.count))); d.append(le64(UInt64(payload.count)))
        d.append(payload)
        let cdStart = d.count
        d.le32(0x0201_4B50); d.le16(45); d.le16(45); d.le16(0); d.le16(0); d.le16(0); d.le16(0x21); d.le32(crc)
        d.le32(0xFFFF_FFFF); d.le32(0xFFFF_FFFF); d.le16(5); d.le16(28); d.le16(0); d.le16(0); d.le16(0); d.le32(0); d.le32(0xFFFF_FFFF)
        d.append(Data("a.txt".utf8))
        d.le16(0x0001); d.le16(24); d.append(le64(UInt64(payload.count))); d.append(le64(UInt64(payload.count))); d.append(le64(0))
        let cdSize = d.count - cdStart
        let eocd64 = d.count
        d.le32(0x0606_4B50); d.append(le64(44)); d.le16(45); d.le16(45); d.le32(0); d.le32(0)
        d.append(le64(1)); d.append(le64(1)); d.append(le64(UInt64(cdSize))); d.append(le64(UInt64(cdStart)))
        d.le32(0x0706_4B50); d.le32(0); d.append(le64(UInt64(eocd64))); d.le32(1)
        d.le32(0x0605_4B50); d.le16(0xFFFF); d.le16(0xFFFF); d.le16(0xFFFF); d.le16(0xFFFF); d.le32(0xFFFF_FFFF); d.le32(0xFFFF_FFFF); d.le16(0)
        let r = try ZipReader(data: d)
        XCTAssertEqual(r.entries.count, 1)
        XCTAssertEqual(r.entries[0].uncompressedSize, payload.count)
        XCTAssertEqual(try r.data("a.txt"), payload)
    }

    private func le64(_ v: UInt64) -> Data {
        var d = Data()
        d.le32(UInt32(v & 0xFFFF_FFFF))
        d.le32(UInt32(v >> 32))
        return d
    }

    func testZipSlipIsRefused() throws {
        let root = try tempDir("slip")
        for bad in ["../evil", "/etc/passwd", "a/../../b", "..", "a/\0b"] {
            XCTAssertThrowsError(try ZipReader.safeDestination(for: bad, in: root), bad)
        }
        XCTAssertEqual(try ZipReader.safeDestination(for: "ok/file.txt", in: root).lastPathComponent, "file.txt")
        // A real malicious archive (python-made fixture): extraction refuses and writes nothing outside.
        let r = try ZipReader(url: try DocsFixtures.url("edge-zipslip.zip"))
        let target = root.appendingPathComponent("x", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        XCTAssertThrowsError(try r.extractAll(to: target))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("evil.txt").path))
    }
}
