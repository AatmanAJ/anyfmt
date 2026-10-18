import AppKit
import XCTest
@testable import HaloApp

/// A scratch folder that disappears after the test.
final class TempFolder {
    let url: URL

    init(_ label: String = "actions") throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("halo-\(label)-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ path: String, contents: String? = nil) throws -> URL {
        let u = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((contents ?? path).utf8).write(to: u)
        return u
    }

    @discardableResult
    func folder(_ path: String) throws -> URL {
        let u = url.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func names(in path: String = "") -> [String] {
        let dir = path.isEmpty ? url : url.appendingPathComponent(path)
        return ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    func read(_ path: String) -> String? {
        (try? Data(contentsOf: url.appendingPathComponent(path))).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// A private pasteboard per test, so tests never touch the user's clipboard.
@MainActor
func makeTestPasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("dev.aiwithaj.halo.tests.\(UUID().uuidString)"))
}

@MainActor
func makeTestDefaults() -> UserDefaults {
    let name = "dev.aiwithaj.halo.tests.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name) ?? .standard
    d.removePersistentDomain(forName: name)
    return d
}

/// Records what FloatShelf asks of its window.
@MainActor
final class FakeShelfPresenter: ShelfPresenting {
    enum Call: Equatable {
        case show(count: Int, near: CGPoint?)
        case update(count: Int, added: Int, removed: Int, raised: Int)
        case hide
    }

    var onCommand: ((ShelfCommand) -> Void)?
    var cardFrame: CGRect? = CGRect(x: 100, y: 200, width: 176, height: 200)
    private(set) var calls: [Call] = []
    private(set) var lastItems: [ShelfItem] = []

    func show(items: [ShelfItem], near point: CGPoint?, savedOrigin: CGPoint?) {
        lastItems = items
        calls.append(.show(count: items.count, near: point))
    }

    func update(items: [ShelfItem], change: ShelfChange) {
        lastItems = items
        calls.append(.update(count: items.count, added: change.added.count, removed: change.removed.count, raised: change.raised.count))
    }

    func hide() { calls.append(.hide) }

    func reset() { calls = [] }
}

@MainActor
func makeTestShelf(presenter: FakeShelfPresenter, defaults: UserDefaults? = nil, intakeRoot: URL? = nil,
                   locate: @escaping (ShelfItem) -> (url: URL, bookmark: Data?)? = { ($0.url, nil) }) -> FloatShelf {
    let prefs = ActionPreferences(defaults: defaults ?? makeTestDefaults())
    let root = intakeRoot ?? FileManager.default.temporaryDirectory.appendingPathComponent("halo-received-\(UUID().uuidString)")
    return FloatShelf(presenter: presenter, preferences: prefs, intake: PromiseIntake(root: root),
                      locate: locate, makeBookmark: { _ in nil })
}
