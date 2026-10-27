import PDFKit
import XCTest
@testable import AnyfmtCore

final class SlidesAndPackTests: XCTestCase {
    // MARK: Quick Look slides

    func testQuickLookSlidesToPDFAndImages() async throws {
        let engine = QuickLookEngine()
        try XCTSkipUnless(engine.isAvailable(Capability(Formats.pptx, Formats.pdf, engine.id)), "qlmanage not available")
        let pptx = try DocsFixtures.url("sample.pptx")
        let pdf = try await runEngine(engine, pptx, from: Formats.pptx, to: Formats.pdf)
        let doc = try XCTUnwrap(PDFDocument(url: pdf[0]))
        XCTAssertEqual(doc.pageCount, 3, "one page per slide")
        let size = doc.page(at: 0)!.bounds(for: .mediaBox).size
        XCTAssertEqual(size.width / size.height, 16.0 / 9.0, accuracy: 0.02, "page keeps the slide aspect")
        XCTAssertTrue(doc.page(at: 1)?.string?.contains("Agenda") ?? false)
        let pngs = try await runEngine(engine, pptx, from: Formats.pptx, to: Formats.png, options: OptionValues([OptionKey.dpi: .string("72")]))
        XCTAssertEqual(pngs.map(\.lastPathComponent), ["out-01.png", "out-02.png", "out-03.png"])
        let img = try XCTUnwrap(ImageSupport.pixelInfo(try Data(contentsOf: pngs[0])))
        XCTAssertEqual(Double(img.width) / Double(img.height), 16.0 / 9.0, accuracy: 0.03)
    }

    func testQuickLookSlideSizeParsing() {
        XCTAssertEqual(QuickLookEngine.slideSize("<style>div.slide, div.loading-slide { width: 960; height: 540;}</style>")?.0, 960)
        XCTAssertEqual(QuickLookEngine.slideSize("<style>div.slide { width: 720px; height: 540px; }</style>")?.1, 540)
        XCTAssertNil(QuickLookEngine.slideSize("<p>none</p>"))
    }

    // MARK: Packs

    struct FakeSystem: PackSystem {
        let appName: String
        func attach(_ dmg: URL, at mountPoint: URL) async throws {
            let mac = mountPoint.appendingPathComponent(appName).appendingPathComponent("Contents/MacOS")
            try FileManager.default.createDirectory(at: mac, withIntermediateDirectories: true)
            try Data("#!/bin/sh\n".utf8).write(to: mac.appendingPathComponent("soffice"))
        }
        func detach(_ mountPoint: URL) async throws {}
        func copy(_ source: URL, to destination: URL) async throws { try FileManager.default.copyItem(at: source, to: destination) }
        func unzip(_ zip: URL, to destination: URL) async throws {
            let bin = destination.appendingPathComponent("pandoc-9.9-arm64/bin")
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            try Data("#!/bin/sh\n".utf8).write(to: bin.appendingPathComponent("pandoc"))
        }
    }

    private func spec(_ kind: PackSpec.Kind, sha: String?, name: String) -> PackSpec {
        PackSpec(name: "Test", version: "1", downloadURL: nil, sha256: sha, kind: kind, installName: name)
    }

    func testPackInstallerVerifiesChecksumThenInstalls() async throws {
        let dir = try tempDir("pack")
        let file = dir.appendingPathComponent("download.dmg")
        try Data("pretend disk image".utf8).write(to: file)
        let sha = try PackInstaller.sha256(of: file)
        XCTAssertEqual(sha.count, 64)
        let packs = dir.appendingPathComponent("Packs", isDirectory: true)

        let unpinned = PackInstaller(spec: spec(.dmg(appName: "LibreOffice.app"), sha: nil, name: "LibreOffice.app"), packsDirectory: packs, system: FakeSystem(appName: "LibreOffice.app"))
        do { try await unpinned.install(from: file); XCTFail("unpinned must refuse") } catch let e as PackInstaller.Failure { XCTAssertEqual(e, .notPinned("Test")) }

        let wrong = PackInstaller(spec: spec(.dmg(appName: "LibreOffice.app"), sha: String(repeating: "0", count: 64), name: "LibreOffice.app"), packsDirectory: packs, system: FakeSystem(appName: "LibreOffice.app"))
        do { try await wrong.install(from: file); XCTFail("mismatch must refuse") } catch PackInstaller.Failure.checksumMismatch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: packs.appendingPathComponent("LibreOffice.app").path))

        let good = PackInstaller(spec: spec(.dmg(appName: "LibreOffice.app"), sha: sha.uppercased(), name: "LibreOffice.app"), packsDirectory: packs, system: FakeSystem(appName: "LibreOffice.app"))
        let installed = try await good.install(from: file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.appendingPathComponent("Contents/MacOS/soffice").path))
        // Reinstall replaces atomically; staging folders are cleaned up.
        _ = try await good.install(from: file)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: packs.path).filter { !$0.hasPrefix(".") }, ["LibreOffice.app"])
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: packs.path).allSatisfy { !$0.hasPrefix(".staging") })

        let zipFile = dir.appendingPathComponent("pandoc.zip")
        try Data("pretend zip".utf8).write(to: zipFile)
        let pandoc = PackInstaller(spec: spec(.zip(binary: "bin/pandoc"), sha: try PackInstaller.sha256(of: zipFile), name: "pandoc"), packsDirectory: packs, system: FakeSystem(appName: ""))
        let p = try await pandoc.install(from: zipFile)
        let attrs = try FileManager.default.attributesOfItem(atPath: p.appendingPathComponent("bin/pandoc").path)
        XCTAssertEqual((attrs[.posixPermissions] as? Int ?? 0) & 0o111, 0o111, "binary is executable")
        try pandoc.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: p.path))
    }

    func testPinnedPacksMatchVersionsEnv() throws {
        let env = try String(contentsOf: DocsFixtures.repoRoot.appendingPathComponent("Engines/versions.env"), encoding: .utf8)
        func value(_ k: String) -> String? {
            env.split(separator: "\n").first { $0.hasPrefix(k + "=") }.map { String($0.dropFirst(k.count + 1)) }
        }
        XCTAssertEqual(PandocPack.spec.downloadURL?.absoluteString, value("PANDOC_URL"))
        XCTAssertEqual(PandocPack.spec.sha256, value("PANDOC_SHA256"))
        XCTAssertEqual(PandocPack.spec.version, value("PANDOC_VERSION"))
        XCTAssertEqual(OfficePack.spec.downloadURL?.absoluteString, value("LIBREOFFICE_URL"))
        XCTAssertEqual(OfficePack.spec.sha256, value("LIBREOFFICE_SHA256"), "pinned only after the .asc verifies (BLOCKERS.md B-011)")
        XCTAssertEqual(OfficePack.spec.version, value("LIBREOFFICE_VERSION"))
    }

    func testPackEnginesAreUnavailableWithoutPacks() {
        let office = OfficePackEngine(soffice: { nil })
        XCTAssertFalse(office.isAvailable(Capability(Formats.pptx, Formats.pdf, office.id)))
        XCTAssertTrue(OfficePackEngine(soffice: { URL(fileURLWithPath: "/bin/echo") }).isAvailable(Capability(Formats.pptx, Formats.pdf, office.id)))
        XCTAssertFalse(PandocPackEngine(pandoc: { nil }).isAvailable(Capability(Formats.docx, Formats.odt, EngineIDs.pandocPack)))
        XCTAssertEqual(OfficePackEngine.filter(Formats.xlsx), "xlsx:Calc MS Excel 2007 XML")
        // Pack rows outrank Quick Look when the pack is present.
        let qlRow = DocsRoutes.rows.first { $0.from == Formats.pptx && $0.to == Formats.pdf && $0.engine == EngineIDs.quickLook }
        let loRow = DocsRoutes.rows.first { $0.from == Formats.pptx && $0.to == Formats.pdf && $0.engine == EngineIDs.officePack }
        XCTAssertGreaterThan(loRow?.priority ?? 0, qlRow?.priority ?? 0)
        XCTAssertTrue(loRow?.flags.contains(.needsPack) ?? false)
    }

    // MARK: iWork (opt-in; never runs AppleScript in tests)

    func testIWorkRowsNeedOptInAndTheApp() {
        let row = Capability(Formats.pages, Formats.pdf, EngineIDs.pagesAppleEvents)
        let off = PagesAppleEventsEngine(environment: .init(isInstalled: { _ in true }, optedIn: { false }))
        XCTAssertFalse(off.isAvailable(row), "default is off even with Pages installed")
        let noApp = PagesAppleEventsEngine(environment: .init(isInstalled: { _ in false }, optedIn: { true }))
        XCTAssertFalse(noApp.isAvailable(row))
        let on = PagesAppleEventsEngine(environment: .init(isInstalled: { $0 == .pages }, optedIn: { true }))
        XCTAssertTrue(on.isAvailable(row))
        XCTAssertFalse(on.isAvailable(Capability(Formats.key, Formats.pdf, EngineIDs.pagesAppleEvents)), "Keynote not installed")
        XCTAssertTrue(DocsRoutes.rows.filter { $0.engine == EngineIDs.pagesAppleEvents }.allSatisfy { $0.flags.contains(.optIn) })
    }

    func testIWorkScriptsQuotePathsAndUseDictionaryFormats() throws {
        let s = try XCTUnwrap(PagesAppleEventsEngine.script(app: .pages, input: URL(fileURLWithPath: "/tmp/My \"Doc\".pages"),
                                                            output: URL(fileURLWithPath: "/tmp/out.docx"), to: Formats.docx))
        XCTAssertTrue(s.contains("tell application id \"com.apple.iWork.Pages\""))
        XCTAssertTrue(s.contains("POSIX file \"/tmp/My \\\"Doc\\\".pages\""))
        XCTAssertTrue(s.contains("as Microsoft Word"))
        XCTAssertTrue(s.contains("close theDoc saving no"))
        let save = try XCTUnwrap(PagesAppleEventsEngine.script(app: .numbers, input: URL(fileURLWithPath: "/tmp/a.xlsx"), output: URL(fileURLWithPath: "/tmp/a.numbers"), to: Formats.numbers))
        XCTAssertTrue(save.contains("save theDoc in"))
        XCTAssertNil(PagesAppleEventsEngine.script(app: .keynote, input: URL(fileURLWithPath: "/a"), output: URL(fileURLWithPath: "/b"), to: Formats.csv))
    }
}
