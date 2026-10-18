import XCTest
import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers
@testable import HaloCore

final class MetadataToolTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws { dir = try G1.tempDir(name) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private let richProperties: [String: Any] = [
        kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2020:01:02 03:04:05",
                                                   kCGImagePropertyExifFNumber as String: 2.8],
        kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFArtist as String: "Ann Artist", kCGImagePropertyTIFFMake as String: "TestCam",
                                                   kCGImagePropertyTIFFModel as String: "One"],
        kCGImagePropertyIPTCDictionary as String: [kCGImagePropertyIPTCObjectName as String: "Old title", kCGImagePropertyIPTCKeywords as String: ["a", "b"]],
        kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 48.8584, kCGImagePropertyGPSLatitudeRef as String: "N",
                                                  kCGImagePropertyGPSLongitude as String: 2.2945, kCGImagePropertyGPSLongitudeRef as String: "E"],
    ]

    private func fields(_ changes: [String: String?]) -> OptionValues {
        OptionValues(["fields": .string(MetadataChanges.encode(changes))])
    }

    // MARK: Images

    func testReadImageFields() async throws {
        let url = try G1.write(G1.photo(), to: dir.appendingPathComponent("m.jpg"), type: .jpeg, properties: richProperties)
        let snap = try await MetadataReader.read(url, locator: G1.locator)
        XCTAssertEqual(snap.container, .image)
        XCTAssertEqual(snap.value("title"), "Old title")
        XCTAssertEqual(snap.value("artist"), "Ann Artist")
        XCTAssertEqual(snap.value("keywords"), "a, b")
        XCTAssertEqual(snap.value("dateTaken"), "2020-01-02 03:04:05")
        XCTAssertEqual(snap.value("gpsLatitude"), "48.858400")
        XCTAssertEqual(snap.value("tiff.camera"), "TestCam One")
        XCTAssertEqual(snap.value("exif.aperture"), "ƒ/2.8")
        XCTAssertEqual(Set(snap.editableFields.map(\.key)), Set(ImageMetadataIO.editableKeys))
        XCTAssertTrue(snap.groups.contains { $0.name == "GPS" })
    }

    func testJPEGEditIsLosslessAndRoundTrips() async throws {
        let input = try G1.write(G1.photo(width: 300, height: 200), to: dir.appendingPathComponent("e.jpg"), type: .jpeg, properties: richProperties)
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [input], options: fields([
            "title": "New title", "artist": "Bob", "keywords": "x, y, z", "dateTaken": "2024-05-06 07:08:09",
            "gpsLatitude": nil, "gpsLongitude": nil, "copyright": "© Bob",
        ]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "jpg")
        let snap = try await MetadataReader.read(out[0], locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "New title")
        XCTAssertEqual(snap.value("artist"), "Bob")
        XCTAssertEqual(snap.value("keywords"), "x, y, z")
        XCTAssertEqual(snap.value("dateTaken"), "2024-05-06 07:08:09")
        XCTAssertEqual(snap.value("copyright"), "© Bob")
        XCTAssertEqual(snap.value("gpsLatitude"), "")
        XCTAssertNil(G1.properties(out[0])[kCGImagePropertyGPSDictionary as String])
        XCTAssertEqual(snap.value("tiff.camera"), "TestCam One", "untouched fields survive")
        // The compressed scan is byte-identical.
        let a = try XCTUnwrap(JPEGSegments.parse(try Data(contentsOf: input))), b = try XCTUnwrap(JPEGSegments.parse(try Data(contentsOf: out[0])))
        XCTAssertEqual(a.scan, b.scan)
        XCTAssertEqual(G1.pixels(try G1.decode(input)), G1.pixels(try G1.decode(out[0])))
    }

    func testJPEGWithXMPKeepsItConsistent() async throws {
        // ImageIO writes XMP for IPTC fields; edits must update it, not leave the old title behind.
        let input = try G1.write(G1.photo(width: 120, height: 80), to: dir.appendingPathComponent("x.jpg"), type: .jpeg, properties: richProperties)
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [input], options: fields(["title": "Fresh", "artist": "Cy"]), in: dir)
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(out[0] as CFURL, nil))
        let meta = try XCTUnwrap(CGImageSourceCopyMetadataAtIndex(src, 0, nil))
        let title = CGImageMetadataCopyStringValueWithPath(meta, nil, "dc:title[x-default]" as CFString) as String?
        XCTAssertNotEqual(title, "Old title")
        let data = try Data(contentsOf: out[0])
        XCTAssertNil(data.range(of: Data("Old title".utf8)), "old title must be gone from every block")
        XCTAssertNil(data.range(of: Data("Ann Artist".utf8)))
    }

    func testPNGEditKeepsPixelData() async throws {
        let input = try G1.write(G1.photo(width: 160, height: 120, alpha: true), to: dir.appendingPathComponent("e.png"), type: .png)
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [input], options: fields(["title": "PNG title", "description": "About"]), in: dir)
        let snap = try await MetadataReader.read(out[0], locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "PNG title")
        XCTAssertEqual(snap.value("description"), "About")
        let idat = { (u: URL) in PNGChunks.parse(try Data(contentsOf: u))?.filter { $0.type == "IDAT" }.map(\.data) }
        XCTAssertEqual(try idat(input), try idat(out[0]))
    }

    func testHEICEditRoundTrips() async throws {
        let input = try G1.write(G1.photo(width: 160, height: 120), to: dir.appendingPathComponent("e.heic"), type: .heic, properties: richProperties)
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [input], options: fields(["title": "HEIC title", "gpsLatitude": "-33.5"]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "heic")
        let snap = try await MetadataReader.read(out[0], locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "HEIC title")
        XCTAssertEqual(snap.value("gpsLatitude"), "-33.500000")
        XCTAssertEqual(snap.value("gpsLongitude"), "2.294500")
    }

    func testInvalidValuesAreRejected() async throws {
        let input = try G1.write(G1.photo(), to: dir.appendingPathComponent("bad.jpg"), type: .jpeg)
        for change: [String: String?] in [["dateTaken": "yesterday"], ["gpsLatitude": "123"], ["nonsense": "x"]] {
            do {
                _ = try await G1.run(ToolIDs.editMetadata, inputs: [input], options: fields(change), in: dir)
                XCTFail("expected rejection of \(change)")
            } catch is ConversionError {}
        }
    }

    func testStripJPEGRemovesEverythingButKeepsOrientationAndPixels() async throws {
        var props = richProperties
        props[kCGImagePropertyOrientation as String] = 6
        let input = try G1.write(G1.photo(width: 300, height: 200), to: dir.appendingPathComponent("s.jpg"), type: .jpeg, properties: props)
        let out = try await G1.run(ToolIDs.stripMetadata, inputs: [input], in: dir)
        let p = G1.properties(out[0])
        XCTAssertNil(p[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil(p[kCGImagePropertyIPTCDictionary as String])
        let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNil(tiff?[kCGImagePropertyTIFFArtist as String])
        XCTAssertNil(tiff?[kCGImagePropertyTIFFMake as String])
        XCTAssertNil((p[kCGImagePropertyExifDictionary as String] as? [String: Any])?[kCGImagePropertyExifDateTimeOriginal as String])
        XCTAssertEqual((p[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue, 6, "orientation still applies")
        XCTAssertEqual(ToolImageSupport.pixelSize(of: out[0]), CGSize(width: 200, height: 300))
        let data = try Data(contentsOf: out[0])
        for secret in ["Ann Artist", "TestCam", "Old title"] { XCTAssertNil(data.range(of: Data(secret.utf8)), secret) }
        XCTAssertEqual(try XCTUnwrap(JPEGSegments.parse(try Data(contentsOf: input))).scan, try XCTUnwrap(JPEGSegments.parse(data)).scan)
    }

    func testStripPNGAndHEIC() async throws {
        let png = try G1.write(G1.photo(width: 80, height: 60), to: dir.appendingPathComponent("s.png"), type: .png, properties: richProperties)
        let heic = try G1.write(G1.photo(width: 80, height: 60), to: dir.appendingPathComponent("s.heic"), type: .heic, properties: richProperties)
        for input in [png, heic] {
            let out = try await G1.run(ToolIDs.stripMetadata, inputs: [input], in: dir)
            XCTAssertEqual(out[0].pathExtension, input.pathExtension)
            let p = G1.properties(out[0])
            XCTAssertNil(p[kCGImagePropertyGPSDictionary as String], input.lastPathComponent)
            XCTAssertNil((p[kCGImagePropertyIPTCDictionary as String] as? [String: Any])?[kCGImagePropertyIPTCObjectName as String], input.lastPathComponent)
            XCTAssertNil((p[kCGImagePropertyTIFFDictionary as String] as? [String: Any])?[kCGImagePropertyTIFFArtist as String], input.lastPathComponent)
        }
    }

    func testJPEGSegmentsRoundTripExactly() throws {
        let url = try G1.write(G1.photo(width: 64, height: 48), to: dir.appendingPathComponent("r.jpg"), type: .jpeg, properties: richProperties)
        let data = try Data(contentsOf: url)
        let file = try XCTUnwrap(JPEGSegments.parse(data))
        XCTAssertEqual(JPEGSegments.build(file), data)
        XCTAssertTrue(file.header.contains(where: \.isExif))
    }

    // MARK: PDF

    private func makePDF(title: String) throws -> URL {
        let url = dir.appendingPathComponent("doc.pdf")
        var box = CGRect(x: 0, y: 0, width: 200, height: 200)
        let aux: [String: Any] = [kCGPDFContextTitle as String: title, kCGPDFContextAuthor as String: "Writer A", kCGPDFContextSubject as String: "Subj"]
        let ctx = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, aux as CFDictionary))
        for _ in 0..<2 { ctx.beginPDFPage(nil); ctx.fill(CGRect(x: 10, y: 10, width: 20, height: 20)); ctx.endPDFPage() }
        ctx.closePDF()
        return url
    }

    func testPDFEditRoundTrip() async throws {
        let input = try makePDF(title: "Secret title")
        let snap0 = try await MetadataReader.read(input, locator: G1.locator)
        XCTAssertEqual(snap0.value("title"), "Secret title")
        XCTAssertEqual(snap0.value("pdf.pages"), "2")
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [input],
                                   options: fields(["title": "Public title", "author": nil, "keywords": "k1, k2"]), in: dir)
        let snap = try await MetadataReader.read(out[0], locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "Public title")
        XCTAssertEqual(snap.value("author"), "")
        XCTAssertEqual(snap.value("subject"), "Subj")
        XCTAssertEqual(snap.value("keywords"), "k1, k2")
        XCTAssertEqual(PDFDocument(url: out[0])?.pageCount, 2)
        XCTAssertFalse(PDFMetadataIO.hasXMP(out[0]))
    }

    func testPDFStripRemovesTitleAndXMP() async throws {
        let input = try makePDF(title: "Secret title")
        let out = try await G1.run(ToolIDs.stripMetadata, inputs: [input], in: dir)
        let doc = try XCTUnwrap(PDFDocument(url: out[0]))
        XCTAssertEqual(doc.pageCount, 2)
        XCTAssertNil(doc.documentAttributes?[PDFDocumentAttribute.titleAttribute])
        XCTAssertNil(doc.documentAttributes?[PDFDocumentAttribute.authorAttribute])
        XCTAssertFalse(PDFMetadataIO.hasXMP(out[0]))
        let data = try Data(contentsOf: out[0])
        XCTAssertNil(data.range(of: Data("Secret title".utf8)))
    }

    // MARK: Audio (ffmpeg)

    private func makeMP3() async throws -> URL {
        try XCTSkipUnless(G1.ffmpeg.isAvailable, "bundled ffmpeg not found")
        let wav = dir.appendingPathComponent("tone.wav")
        try G1.writeWAV(to: wav)
        let mp3 = dir.appendingPathComponent("tone.mp3")
        try await G1.ffmpeg.run(["-i", wav.path, "-c:a", "libmp3lame", "-b:a", "96k", "-metadata", "title=Old song",
                                 "-metadata", "artist=Old artist", "-metadata", "comment=hello", mp3.path])
        return mp3
    }

    func testMP3EditRoundTrip() async throws {
        let mp3 = try await makeMP3()
        let snap0 = try await MetadataReader.read(mp3, locator: G1.locator)
        XCTAssertEqual(snap0.container, .media)
        XCTAssertEqual(snap0.value("title"), "Old song")
        XCTAssertNotNil(snap0.value("media.audio"))
        let out = try await G1.run(ToolIDs.editMetadata, inputs: [mp3],
                                   options: fields(["title": "New song", "album": "Album X", "comment": nil, "date": "2026"]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "mp3")
        let snap = try await MetadataReader.read(out[0], locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "New song")
        XCTAssertEqual(snap.value("album"), "Album X")
        XCTAssertEqual(snap.value("artist"), "Old artist")
        XCTAssertEqual(snap.value("comment"), "")
        XCTAssertEqual(snap.value("date"), "2026")
        let probe = try await G1.ffmpeg.probe(out[0])
        XCTAssertEqual(probe.duration ?? 0, 1, accuracy: 0.1)
    }

    func testMP3Strip() async throws {
        let mp3 = try await makeMP3()
        let out = try await G1.run(ToolIDs.stripMetadata, inputs: [mp3], in: dir)
        let probe = try await G1.ffmpeg.probe(out[0])
        let tags = probe.format?.tags ?? [:]
        XCTAssertNil(tags["title"]); XCTAssertNil(tags["artist"]); XCTAssertNil(tags["comment"])
        XCTAssertNil(tags["encoder"], "bit-exact: ffmpeg adds no tag of its own")
        XCTAssertTrue(probe.hasAudio)
    }

    // MARK: Changes JSON

    func testChangesDiffAndJSON() throws {
        let snap = MetadataSnapshot(container: .image, fields: [
            MetadataField(key: "title", label: "Title", group: "IPTC", value: "A", editable: true),
            MetadataField(key: "artist", label: "Artist", group: "TIFF", value: "B", editable: true),
            MetadataField(key: "copyright", label: "©", group: "TIFF", value: "", editable: true),
            MetadataField(key: "image.size", label: "Size", group: "Image", value: "1 × 1", editable: false),
        ])
        let diff = MetadataChanges.diff(original: snap, edited: ["title": "A", "artist": "  ", "copyright": "Me", "image.size": "9"])
        XCTAssertEqual(diff.count, 2)
        XCTAssertEqual(diff["artist"], .some(nil))
        XCTAssertEqual(diff["copyright"], "Me")
        let parsed = try MetadataChanges.parse(MetadataChanges.encode(diff))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed["artist"], .some(nil))
        XCTAssertThrowsError(try MetadataChanges.parse("[1,2]"))
        XCTAssertEqual(try MetadataChanges.parse("").count, 0)
    }
}
