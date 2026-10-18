import XCTest
@testable import HaloApp

/// Crash on real hardware (2026-10-18): the promise reader inherited @MainActor
/// isolation from `PromiseIntake.begin`, and Swift 6's runtime check trapped when
/// AppKit called it on the receive queue. The reader must run anywhere.
@MainActor
final class PromiseReaderIsolationTests: XCTestCase {
    func testReaderRunsOnABackgroundOperationQueue() async throws {
        let batch = PromiseBatch(expected: 1)
        let reader = PromiseIntake.reader(batch, index: 0)
        let queue = OperationQueue()
        let url = URL(fileURLWithPath: "/tmp/promised.jpg")
        queue.addOperation { reader(url, nil) } // where AppKit calls it
        let files = await batch.wait(timeout: 5)
        XCTAssertEqual(files, [url])
    }

    func testReaderReportsFailures() async throws {
        let batch = PromiseBatch(expected: 1)
        let reader = PromiseIntake.reader(batch, index: 0)
        OperationQueue().addOperation { reader(URL(fileURLWithPath: "/tmp/x"), CocoaError(.fileReadUnknown)) }
        let files = await batch.wait(timeout: 5)
        XCTAssertTrue(files.isEmpty, "a failed promise delivers nothing")
    }
}
