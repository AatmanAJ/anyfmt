import XCTest
@testable import HaloCore

final class RecentConversionsTests: JobsTestCase {
    private var dir: URL { root.appendingPathComponent("support", isDirectory: true) }

    func testKeepsTenNewestFirstAndPersists() throws {
        let outputs = try makeFiles((1...12).map { "out\($0).jpg" })
        let recents = RecentConversions(directory: dir)
        for (i, u) in outputs.enumerated() {
            recents.add(title: "in\(i + 1).heic → JPG", outputs: [u], date: Date(timeIntervalSince1970: Double(1_700_000_000 + i)))
        }
        XCTAssertEqual(recents.items.count, RecentConversions.limit)
        XCTAssertEqual(recents.items.first?.title, "in12.heic → JPG", "newest first")
        XCTAssertEqual(recents.items.last?.title, "in3.heic → JPG")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("recents.json").path))

        let reloaded = RecentConversions(directory: dir)
        XCTAssertEqual(reloaded.items.map(\.title), recents.items.map(\.title))
        XCTAssertEqual(reloaded.items.first?.outputs, [outputs[11]])
        XCTAssertEqual(reloaded.items.first?.date.timeIntervalSince1970 ?? 0, 1_700_000_011, accuracy: 1)
    }

    func testStaleEntriesPrunedOnRead() throws {
        let outputs = try makeFiles(["a.jpg", "b.jpg", "c1.png", "c2.png"])
        let recents = RecentConversions(directory: dir)
        recents.add(title: "a", outputs: [outputs[0]])
        recents.add(title: "b", outputs: [outputs[1]])
        recents.add(title: "c", outputs: [outputs[2], outputs[3]])
        try FileManager.default.removeItem(at: outputs[1])
        try FileManager.default.removeItem(at: outputs[3])
        XCTAssertEqual(recents.items.map(\.title), ["c", "a"])
        XCTAssertEqual(recents.items.first?.outputs, [outputs[2]], "partly deleted entries keep what's left")
        XCTAssertEqual(RecentConversions(directory: dir).items.map(\.title), ["c", "a"], "pruned list was saved")
    }

    func testRecordsOnlySucceededJobsAndDeduplicates() throws {
        let out = try makeFiles(["x.jpg"])[0]
        let recents = RecentConversions(directory: dir)
        recents.add(JobRecord(title: "failed", inputs: [], state: .failed(message: "m", details: "d")))
        recents.add(JobRecord(title: "x.heic → JPG", inputs: [], state: .succeeded([out]), outputs: [out]))
        recents.add(JobRecord(title: "x.heic → JPG again", inputs: [], state: .succeeded([out]), outputs: [out]))
        XCTAssertEqual(recents.items.map(\.title), ["x.heic → JPG again"])
        recents.clear()
        XCTAssertTrue(recents.items.isEmpty)
    }

    func testCorruptFileStartsFresh() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{nope".utf8).write(to: dir.appendingPathComponent("recents.json"))
        let recents = RecentConversions(directory: dir)
        XCTAssertTrue(recents.items.isEmpty)
        let out = try makeFiles(["y.png"])[0]
        recents.add(title: "y", outputs: [out])
        XCTAssertEqual(RecentConversions(directory: dir).items.count, 1)
    }
}
