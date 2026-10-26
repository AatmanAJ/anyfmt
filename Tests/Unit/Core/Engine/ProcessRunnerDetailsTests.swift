import XCTest
@testable import AnyfmtCore

/// "Copy details" must be able to reproduce a failure: the command line comes first.
final class ProcessRunnerDetailsTests: XCTestCase {
    func testQuoting() {
        XCTAssertEqual(ProcessRunner.shellQuoted("-i"), "-i")
        XCTAssertEqual(ProcessRunner.shellQuoted("/tmp/a b.mov"), "'/tmp/a b.mov'")
        XCTAssertEqual(ProcessRunner.shellQuoted("it's"), "'it'\\''s'")
        XCTAssertEqual(ProcessRunner.shellQuoted(""), "''")
    }

    func testFailureDetailStartsWithTheCommand() async throws {
        do {
            _ = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo boom >&2; exit 3"])
            XCTFail("should throw")
        } catch ConversionError.engineFailed(let name, let status, let detail) {
            XCTAssertEqual(name, "sh")
            XCTAssertEqual(status, 3)
            XCTAssertTrue(detail.hasPrefix("$ sh -c 'echo boom >&2; exit 3'\n"), detail)
            XCTAssertTrue(detail.contains("boom"))
        }
    }
}
