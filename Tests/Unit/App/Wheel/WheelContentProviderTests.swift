import HaloCore
import RadialMenu
import UniformTypeIdentifiers
import XCTest
@testable import HaloApp

/// Fixed capability table so these tests don't depend on which engine lanes landed.
enum WheelTestTable {
    static let e: EngineID = "test"

    static let rows: [Capability] =
        Capability.grid(["jpg"], ["png", "heic", "webp", "tiff", "pdf"], e)
        + Capability.grid(["png"], ["jpg", "heic", "webp", "tiff", "pdf", "ico"], e, flags: [.lossless])
        + [Capability("jpg", "bmp", e, flags: [.hiddenByDefault])]
        + Capability.grid(["mov"], ["mp4", "webm", "gif", "mp3", "m4a"], e)
        + Capability.grid(["wav"], ["mp3", "m4a", "flac"], e)
        + Capability.grid(["pdf"], ["png", "jpg", "txt", "docx"], e)
        + Capability.grid(["folder"], ["zip", "tar"], e)

    static var provider: WheelContentProvider { WheelContentProvider(router: Router(table: CapabilityTable(rows))) }

    static func url(_ name: String) -> URL { URL(fileURLWithPath: "/tmp/halo-wheel-tests/\(name)") }
}

@MainActor
final class WheelContentProviderTests: XCTestCase {
    private let provider = WheelTestTable.provider
    private let prefs = WheelPreferences.standard

    private func formats(_ entries: [WheelEntry]) -> [String] {
        entries.compactMap { if case .convert(let t) = $0 { return t.format.rawValue } else { return nil } }
    }

    private func toolIDs(_ entries: [WheelEntry]) -> [ToolID] {
        entries.compactMap { if case .tool(let t) = $0 { return t.id } else { return nil } }
    }

    private func input(_ names: String...) -> WheelInput {
        WheelInput(urls: names.map(WheelTestTable.url))
    }

    // MARK: Convert

    func testImageConvertTargetsFollowTheRouter() {
        let entries = provider.entries(for: input("photo.jpg"), kind: .convert, preferences: prefs)
        // ico is reachable via PNG; txt/docx via PDF jump families, so they're opt-in
        // (Route.isShownByDefault); bmp is hidden by default.
        XCTAssertEqual(Set(formats(entries)), ["png", "heic", "webp", "tiff", "pdf", "ico"])
        var shown = prefs
        shown.shownFormats = ["docx"]
        XCTAssertTrue(formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: shown)).contains("docx"),
                      "Settings › Formats can switch a cross-family target on")
        XCTAssertFalse(formats(entries).contains("bmp"), "hiddenByDefault rows stay off the wheel")
        guard case .convert(let ico)? = entries.first(where: { $0.id == "convert.ico" }) else { return XCTFail("no ico") }
        XCTAssertTrue(ico.isMultiHop)
        XCTAssertEqual(WheelContentProvider.viaFormat(of: ico), "png")
        let item = WheelContentProvider.item(for: .convert(ico))
        XCTAssertEqual(item.subtitle, "via PNG")
        XCTAssertEqual(item.prominence, .title)
        XCTAssertEqual(item.title, "ICO")
    }

    func testVideoAudioAndPDF() {
        XCTAssertEqual(Set(formats(provider.entries(for: input("clip.mov"), kind: .convert, preferences: prefs))),
                       ["mp4", "webm", "gif", "mp3", "m4a"])
        XCTAssertEqual(Set(formats(provider.entries(for: input("song.wav"), kind: .convert, preferences: prefs))),
                       ["mp3", "m4a", "flac"])
        let pdf = formats(provider.entries(for: input("doc.pdf"), kind: .convert, preferences: prefs))
        XCTAssertTrue(pdf.contains("png") && pdf.contains("docx"))
    }

    func testMultiFileIntersection() {
        // jpg and png: both reach heic/webp/tiff/pdf; jpg also reaches png, png also reaches jpg.
        let entries = provider.entries(for: input("a.jpg", "b.png"), kind: .convert, preferences: prefs)
        let f = Set(formats(entries))
        XCTAssertTrue(f.isSuperset(of: ["heic", "webp", "tiff", "pdf"]))
        XCTAssertTrue(f.contains("png"), "inputs already in the target format are skipped, not blocking")
        // jpg and mov share nothing.
        XCTAssertTrue(provider.entries(for: input("a.jpg", "b.mov"), kind: .convert, preferences: prefs).isEmpty)
    }

    func testFolderGetsArchiveTargetsAndFullActions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wheel-folder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let folder = WheelInput(urls: [dir])
        XCTAssertTrue(folder.containsFolder)
        XCTAssertEqual(Set(formats(provider.entries(for: folder, kind: .convert, preferences: prefs))), ["zip", "tar"])
        XCTAssertTrue(provider.entries(for: folder, kind: .tools, preferences: prefs).isEmpty)
        let actions = provider.entries(for: folder, kind: .actions, preferences: prefs)
        XCTAssertEqual(actions.count, ActionCatalog.all.count, "actions work on anything, folders included")
        // An empty tools wheel falls back to actions, with a note in the hub.
        let resolved = provider.resolve(folder, kind: .tools, preferences: prefs)
        XCTAssertEqual(resolved.kind, .actions)
        XCTAssertNotNil(resolved.note)
    }

    func testNoConversionsFallsBackToActions() {
        for name in ["notes.txt", "mystery.xyz"] {
            let resolved = provider.resolve(input(name), kind: .convert, preferences: prefs)
            XCTAssertEqual(resolved.kind, .actions, name)
            XCTAssertEqual(resolved.entries.count, ActionCatalog.all.count, name)
            XCTAssertEqual(resolved.note, String(localized: "No conversions"), name)
        }
        let ok = provider.resolve(input("photo.jpg"), kind: .convert, preferences: prefs)
        XCTAssertEqual(ok.kind, .convert)
        XCTAssertNil(ok.note)
    }

    func testMixedSelectionToolsAreTheCommonOnes() {
        let tools = toolIDs(provider.entries(for: input("a.jpg", "b.mov"), kind: .tools, preferences: prefs))
        XCTAssertEqual(Set(tools), [ToolIDs.editMetadata, ToolIDs.stripMetadata])
    }

    func testImageToolsAndArity() {
        let one = toolIDs(provider.entries(for: input("a.jpg"), kind: .tools, preferences: prefs))
        XCTAssertTrue(one.contains(ToolIDs.cropImage))
        XCTAssertTrue(one.contains(ToolIDs.imagesToPDF), "minimum 1")
        XCTAssertFalse(one.contains(ToolIDs.collage), "collage needs 2+ images")
        XCTAssertFalse(one.contains(ToolIDs.trimVideo))
        let two = toolIDs(provider.entries(for: input("a.jpg", "b.png"), kind: .tools, preferences: prefs))
        XCTAssertTrue(two.contains(ToolIDs.collage))
        let audio = toolIDs(provider.entries(for: input("a.wav"), kind: .tools, preferences: prefs))
        XCTAssertTrue(audio.contains(ToolIDs.trimAudio))
        XCTAssertFalse(audio.contains(ToolIDs.cropImage))
        let pdf = toolIDs(provider.entries(for: input("a.pdf"), kind: .tools, preferences: prefs))
        XCTAssertTrue(pdf.contains(ToolIDs.organizePDF))
    }

    func testPromiseOnlyDragsUseThePromisedType() {
        let promised = WheelInput(promisedTypes: [.jpeg])
        XCTAssertEqual(Set(formats(provider.entries(for: promised, kind: .convert, preferences: prefs))),
                       Set(formats(provider.entries(for: input("x.jpg"), kind: .convert, preferences: prefs))))
        XCTAssertEqual(WheelInput.format(for: .png), Formats.png)
        XCTAssertEqual(WheelInput.format(for: .pdf), Formats.pdf)
        XCTAssertEqual(WheelInput.format(for: .quickTimeMovie), Formats.mov)
        XCTAssertEqual(WheelInput.format(for: .folder), Formats.folder)
        XCTAssertEqual(WheelInput.format(for: .heic), Formats.heic)
    }

    // MARK: Preferences

    func testFavouritesComeFirstInTheirOrder() {
        var p = prefs
        p.favouriteFormats = ["pdf", "webp", "doesnotexist"]
        let f = formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: p))
        XCTAssertEqual(Array(f.prefix(2)), ["pdf", "webp"])
        // The rest keep their usual order.
        let rest = Array(f.dropFirst(2))
        let usual = formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: prefs))
            .filter { !["pdf", "webp"].contains($0) }
        XCTAssertEqual(rest, usual)
    }

    func testSameKindTargetsComeFirst() {
        let f = formats(provider.entries(for: input("clip.mov"), kind: .convert, preferences: prefs))
        let videoCount = f.filter { Formats.kind(FormatID($0)) == .video }.count
        XCTAssertEqual(videoCount, 2)
        XCTAssertTrue(f.prefix(videoCount).allSatisfy { Formats.kind(FormatID($0)) == .video }, "\(f)")
    }

    func testHiddenAndShownFormats() {
        var p = prefs
        p.hiddenFormats = ["heic", "tiff"]
        var f = formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: p))
        XCTAssertFalse(f.contains("heic") || f.contains("tiff"))
        p.shownFormats = ["bmp"]
        f = formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: p))
        XCTAssertTrue(f.contains("bmp"), "user can reveal hiddenByDefault rows")
        var fav = prefs
        fav.favouriteFormats = ["bmp"]
        XCTAssertEqual(formats(provider.entries(for: input("photo.jpg"), kind: .convert, preferences: fav)).first, "bmp")
    }

    func testHiddenToolsAndCloudItems() {
        var p = prefs
        p.hiddenTools = [ToolIDs.cropImage]
        XCTAssertFalse(toolIDs(provider.entries(for: input("a.jpg"), kind: .tools, preferences: p)).contains(ToolIDs.cropImage))
        p.showCloudItems = false
        let tools = provider.entries(for: input("a.jpg"), kind: .tools, preferences: p)
        XCTAssertFalse(toolIDs(tools).contains(ToolIDs.upscale))
        XCTAssertTrue(toolIDs(tools).contains(ToolIDs.compressImage), "local tools unaffected")
        let actions = provider.entries(for: input("a.jpg"), kind: .actions, preferences: p)
        XCTAssertEqual(actions.count, ActionCatalog.local.count)
    }

    func testPreferencesRoundTripAndTolerateMissingKeys() throws {
        let p = WheelPreferences(favouriteFormats: ["png"], hiddenFormats: ["bmp"], hiddenTools: [ToolIDs.collage],
                                 showCloudItems: false)
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(WheelPreferences.self, from: data), p)
        let partial = try JSONDecoder().decode(WheelPreferences.self, from: Data(#"{"favouriteFormats":["jpg"]}"#.utf8))
        XCTAssertEqual(partial.favouriteFormats, ["jpg"])
        XCTAssertTrue(partial.showCloudItems)
    }

    func testKindsCycle() {
        XCTAssertEqual(WheelKind.convert.next, .tools)
        XCTAssertEqual(WheelKind.tools.next, .actions)
        XCTAssertEqual(WheelKind.actions.next, .convert)
        for k in WheelKind.allCases { XCTAssertEqual(k.next.previous, k) }
    }

    func testEntryIDsAreStableAndUnique() {
        let all = provider.entries(for: input("a.jpg"), kind: .convert, preferences: prefs)
            + provider.entries(for: input("a.jpg"), kind: .tools, preferences: prefs)
            + provider.entries(for: input("a.jpg"), kind: .actions, preferences: prefs)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertTrue(all.contains { $0.id == "convert.png" })
        XCTAssertTrue(all.contains { $0.id == "action.copy" })
    }
}
