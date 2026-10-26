import AppKit
import XCTest
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class TerminalActionTests: XCTestCase {
    private let apps: [String: URL] = [
        "com.apple.Terminal": URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
        "com.mitchellh.ghostty": URL(fileURLWithPath: "/Applications/Ghostty.app"),
        "dev.warp.Warp-Stable": URL(fileURLWithPath: "/Applications/Warp.app"),
    ]

    // MARK: Detection

    func testInstalledTerminalsComeFromTheInjectedLookupInPickerOrder() {
        let installed = TerminalLauncher.installed { self.apps[$0] }
        XCTAssertEqual(installed.map(\.app.name), ["Terminal", "Ghostty", "Warp"])
        XCTAssertEqual(installed.first?.appURL.lastPathComponent, "Terminal.app")
        XCTAssertEqual(TerminalLauncher.installed { _ in nil }, [])
    }

    func testKnownBundleIdentifiers() {
        XCTAssertEqual(TerminalApp.terminal.bundleID, "com.apple.Terminal")
        XCTAssertEqual(TerminalApp.iTerm2.bundleID, "com.googlecode.iterm2")
        XCTAssertEqual(TerminalApp.ghostty.bundleID, "com.mitchellh.ghostty")
        XCTAssertEqual(TerminalApp.warp.bundleID, "dev.warp.Warp-Stable")
    }

    func testResolveFallsBackToTerminalWhenTheChoiceIsMissing() {
        XCTAssertEqual(TerminalLauncher.resolve(preferred: "dev.warp.Warp-Stable") { self.apps[$0] }?.app, .warp)
        XCTAssertEqual(TerminalLauncher.resolve(preferred: "com.googlecode.iterm2") { self.apps[$0] }?.app, .terminal)
        XCTAssertNil(TerminalLauncher.resolve(preferred: "com.apple.Terminal") { _ in nil })
    }

    // MARK: Folder choice

    func testWorkingFolderRules() {
        let isFolder: (URL) -> Bool = { $0.pathExtension.isEmpty }
        func folder(_ paths: [String]) -> String? {
            TerminalLauncher.workingFolder(for: paths.map { URL(fileURLWithPath: $0) }, isFolder: isFolder)?.path
        }
        XCTAssertEqual(folder(["/Users/me/Code"]), "/Users/me/Code", "a folder opens at itself")
        XCTAssertEqual(folder(["/Users/me/Code/main.swift"]), "/Users/me/Code", "a file opens at its parent")
        XCTAssertEqual(folder(["/Users/me/Code/a.swift", "/Users/me/Code/b.swift"]), "/Users/me/Code")
        XCTAssertEqual(folder(["/Users/me/Code/App", "/Users/me/Code/readme.md"]), "/Users/me/Code",
                       "a mixed selection opens where the items are")
        XCTAssertEqual(folder(["/Users/me/Code/A/x.txt", "/Users/me/Code/B/y.txt"]), "/Users/me/Code", "deepest common folder")
        XCTAssertEqual(folder(["/Volumes/Disk/a.txt", "/Users/me/b.txt"]), "/Volumes/Disk", "nothing in common: first item's folder")
        XCTAssertNil(folder([]))
    }

    func testPackagesCountAsFiles() throws {
        let tmp = try TempFolder()
        let app = try tmp.folder("Tool.app")
        try tmp.file("Tool.app/Contents/Info.plist")
        let plain = try tmp.folder("Plain")
        XCTAssertFalse(TerminalLauncher.isPlainFolder(app), "an .app bundle is a file to Finder")
        XCTAssertTrue(TerminalLauncher.isPlainFolder(plain))
        XCTAssertEqual(TerminalLauncher.workingFolder(for: [app])?.path, tmp.url.path)
        XCTAssertEqual(TerminalLauncher.workingFolder(for: [plain])?.path, plain.path)
    }

    // MARK: Launch plans

    func testWarpURLEncodesThePath() {
        let url = TerminalLauncher.newWindowURL(scheme: "warp", folder: URL(fileURLWithPath: "/Users/me/My Stuff & Co/#1 + 50%/Café ✨"))
        XCTAssertEqual(url?.absoluteString,
                       "warp://action/new_window?path=/Users/me/My%20Stuff%20%26%20Co/%231%20%2B%2050%25/Caf%C3%A9%20%E2%9C%A8")
        let back = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == "path" }?.value
        XCTAssertEqual(back, "/Users/me/My Stuff & Co/#1 + 50%/Café ✨", "the query decodes to the exact path")
    }

    func testPlanPerApp() {
        let folder = URL(fileURLWithPath: "/Users/me/Code", isDirectory: true)
        let terminal = InstalledTerminal(app: .terminal, appURL: apps["com.apple.Terminal"]!)
        let ghostty = InstalledTerminal(app: .ghostty, appURL: apps["com.mitchellh.ghostty"]!)
        let iterm = InstalledTerminal(app: .iTerm2, appURL: URL(fileURLWithPath: "/Applications/iTerm.app"))
        let warp = InstalledTerminal(app: .warp, appURL: apps["dev.warp.Warp-Stable"]!)

        XCTAssertEqual(TerminalLauncher.launchPlan(for: terminal, folder: folder), .openFolder(folder, withApplicationAt: terminal.appURL))
        XCTAssertEqual(TerminalLauncher.launchPlan(for: iterm, folder: folder), .openFolder(folder, withApplicationAt: iterm.appURL))
        XCTAssertEqual(TerminalLauncher.launchPlan(for: ghostty, folder: folder), .openFolder(folder, withApplicationAt: ghostty.appURL))
        XCTAssertEqual(TerminalLauncher.launchPlan(for: warp, folder: folder),
                       .openURL(URL(string: "warp://action/new_window?path=/Users/me/Code")!, withApplicationAt: warp.appURL))
    }

    func testTerminalActionOpensTheChosenTerminalAtTheFilesFolder() async throws {
        let tmp = try TempFolder()
        let file = try tmp.file("src/main.swift")
        let prefs = ActionPreferences(defaults: makeTestDefaults())
        prefs.terminalBundleID = TerminalApp.warp.bundleID
        var plans: [TerminalLaunchPlan] = []
        let performer = ActionPerformer(
            preferences: prefs, pasteboard: makeTestPasteboard(),
            shelf: makeTestShelf(presenter: FakeShelfPresenter()),
            intake: PromiseIntake(root: tmp.url.appendingPathComponent("received")),
            appLookup: { self.apps[$0] },
            openTerminal: { plans.append($0) },
            chooseDestination: { _, _, _ in nil },
            modifierFlags: { [] })

        let outcome = await performer.perform(ActionIDs.terminal, urls: [file], at: .zero)

        XCTAssertEqual(outcome, .done(nil))
        let expected = TerminalLauncher.newWindowURL(scheme: "warp", folder: file.deletingLastPathComponent())
        XCTAssertEqual(plans, [.openURL(expected!, withApplicationAt: apps["dev.warp.Warp-Stable"]!)])
    }

    func testTerminalActionFailsHumanlyWhenNothingIsInstalled() async throws {
        let tmp = try TempFolder()
        let performer = ActionPerformer(
            preferences: ActionPreferences(defaults: makeTestDefaults()), pasteboard: makeTestPasteboard(),
            shelf: makeTestShelf(presenter: FakeShelfPresenter()),
            intake: PromiseIntake(root: tmp.url.appendingPathComponent("received")),
            appLookup: { _ in nil }, openTerminal: { _ in XCTFail("nothing to open") },
            chooseDestination: { _, _, _ in nil }, modifierFlags: { [] })
        let outcome = await performer.perform(ActionIDs.terminal, urls: [tmp.url], at: .zero)
        XCTAssertEqual(outcome, .failed("Couldn’t find a terminal app."))
    }
}
