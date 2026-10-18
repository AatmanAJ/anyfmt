import XCTest
@testable import HaloApp

@MainActor
final class ActionPreferencesTests: XCTestCase {
    func testTerminalDefaultsToTerminalAppAndPersists() {
        let defaults = makeTestDefaults()
        let prefs = ActionPreferences(defaults: defaults)
        XCTAssertEqual(prefs.terminalBundleID, "com.apple.Terminal")
        prefs.terminalBundleID = TerminalApp.ghostty.bundleID
        XCTAssertEqual(ActionPreferences(defaults: defaults).terminalBundleID, "com.mitchellh.ghostty")
    }

    func testRecentFoldersAreMostRecentFirstWithoutDuplicates() {
        let prefs = ActionPreferences(defaults: makeTestDefaults(), isDirectory: { _ in true })
        let a = URL(fileURLWithPath: "/Users/me/A", isDirectory: true)
        let b = URL(fileURLWithPath: "/Users/me/B", isDirectory: true)
        let c = URL(fileURLWithPath: "/Users/me/C", isDirectory: true)
        prefs.noteRecentFolder(a)
        prefs.noteRecentFolder(b)
        prefs.noteRecentFolder(c)
        prefs.noteRecentFolder(URL(fileURLWithPath: "/Users/me/A/", isDirectory: true)) // same folder again
        XCTAssertEqual(prefs.recentFolders.map(\.path), ["/Users/me/A", "/Users/me/C", "/Users/me/B"])
    }

    func testRecentFoldersAreCappedAtEight() {
        let prefs = ActionPreferences(defaults: makeTestDefaults(), isDirectory: { _ in true })
        for i in 1...12 { prefs.noteRecentFolder(URL(fileURLWithPath: "/f/\(i)", isDirectory: true)) }
        XCTAssertEqual(prefs.recentFolders.count, ActionPreferences.maxRecentFolders)
        XCTAssertEqual(prefs.recentFolders.first?.path, "/f/12")
        XCTAssertEqual(prefs.recentFolders.last?.path, "/f/5")
    }

    func testMissingFoldersArePrunedAndThePruneIsSaved() {
        let defaults = makeTestDefaults()
        var gone: Set<String> = []
        let prefs = ActionPreferences(defaults: defaults, isDirectory: { !gone.contains($0.path) })
        for name in ["x", "y", "z"] { prefs.noteRecentFolder(URL(fileURLWithPath: "/r/\(name)", isDirectory: true)) }
        gone = ["/r/y"]
        XCTAssertEqual(prefs.recentFolders.map(\.lastPathComponent), ["z", "x"])
        gone = []
        XCTAssertEqual(ActionPreferences(defaults: defaults, isDirectory: { _ in true }).recentFolders.map(\.lastPathComponent),
                       ["z", "x"], "a pruned folder doesn't come back")
    }

    func testRealFoldersWithSymlinkedSpellingDedupe() throws {
        let tmp = try TempFolder()
        let real = try tmp.folder("Real")
        let link = tmp.url.appendingPathComponent("Alias")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let prefs = ActionPreferences(defaults: makeTestDefaults())
        prefs.noteRecentFolder(real)
        prefs.noteRecentFolder(link)
        XCTAssertEqual(prefs.recentFolders.count, 1)
    }

    func testRemoveAndClearRecents() {
        let prefs = ActionPreferences(defaults: makeTestDefaults(), isDirectory: { _ in true })
        let a = URL(fileURLWithPath: "/q/a", isDirectory: true)
        prefs.noteRecentFolder(a)
        prefs.noteRecentFolder(URL(fileURLWithPath: "/q/b", isDirectory: true))
        prefs.removeRecentFolder(a)
        XCTAssertEqual(prefs.recentFolders.map(\.lastPathComponent), ["b"])
        prefs.clearRecentFolders()
        XCTAssertEqual(prefs.recentFolders, [])
    }

    func testShelfOriginRoundTrips() {
        let defaults = makeTestDefaults()
        let prefs = ActionPreferences(defaults: defaults)
        XCTAssertNil(prefs.shelfOrigin)
        prefs.shelfOrigin = CGPoint(x: 1200.5, y: 340)
        XCTAssertEqual(ActionPreferences(defaults: defaults).shelfOrigin, CGPoint(x: 1200.5, y: 340))
        prefs.shelfOrigin = nil
        XCTAssertNil(prefs.shelfOrigin)
    }
}
