import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let stdout: Data
    /// Last ~64 KB of stderr, for error details.
    public let stderr: String
    public var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
}

/// Runs a child process with streaming output and cooperative cancellation:
/// cancelling the calling Task sends SIGTERM, then SIGKILL after 2 s.
public enum ProcessRunner {
    public static func run(
        _ executable: URL,
        _ arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        stdin: Data? = nil,
        captureStdout: Bool = true,
        checkExit: Bool = true,
        onStdoutLine: (@Sendable (String) -> Void)? = nil,
        onStderrLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        try Task.checkCancellation()
        let box = ProcessBox()
        let result: ProcessResult = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ProcessResult, Error>) in
                let p = Process()
                p.executableURL = executable
                p.arguments = arguments
                if let currentDirectory { p.currentDirectoryURL = currentDirectory }
                if let environment { p.environment = environment }
                let outPipe = Pipe(), errPipe = Pipe()
                p.standardOutput = outPipe
                p.standardError = errPipe
                let inPipe: Pipe? = stdin == nil ? nil : Pipe()
                p.standardInput = inPipe ?? FileHandle.nullDevice

                let collector = OutputCollector(captureStdout: captureStdout, onStdoutLine: onStdoutLine, onStderrLine: onStderrLine)
                let group = DispatchGroup()
                group.enter(); group.enter(); group.enter()
                outPipe.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData
                    if d.isEmpty { h.readabilityHandler = nil; collector.finishStdout(); group.leave() } else { collector.stdout(d) }
                }
                errPipe.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData
                    if d.isEmpty { h.readabilityHandler = nil; collector.finishStderr(); group.leave() } else { collector.stderr(d) }
                }
                p.terminationHandler = { _ in group.leave() }
                do {
                    try p.run()
                } catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    cont.resume(throwing: ConversionError.engineMissing(executable.lastPathComponent, detail: error.localizedDescription))
                    return
                }
                box.set(p)
                if let stdin, let inPipe {
                    DispatchQueue.global().async {
                        try? inPipe.fileHandleForWriting.write(contentsOf: stdin)
                        try? inPipe.fileHandleForWriting.close()
                    }
                }
                group.notify(queue: .global()) {
                    let status = p.terminationStatus
                    let r = ProcessResult(status: status, stdout: collector.stdoutData, stderr: collector.stderrTail)
                    if box.wasCancelled {
                        cont.resume(throwing: CancellationError())
                    } else if checkExit && (p.terminationReason != .exit || status != 0) {
                        cont.resume(throwing: ConversionError.engineFailed(executable.lastPathComponent, status: status, detail: r.stderr))
                    } else {
                        cont.resume(returning: r)
                    }
                }
            }
        } onCancel: {
            box.cancel()
        }
        return result
    }
}

/// Owns the Process across the cancellation boundary.
private final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var wasCancelled: Bool { lock.withLock { cancelled } }

    func set(_ p: Process) {
        let cancelNow = lock.withLock { process = p; return cancelled }
        if cancelNow { terminate(p) }
    }

    func cancel() {
        let p = lock.withLock { cancelled = true; return process }
        if let p { terminate(p) }
    }

    private func terminate(_ p: Process) {
        guard p.isRunning else { return }
        p.terminate()
        let pid = p.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if p.isRunning { kill(pid, SIGKILL) }
        }
    }
}

/// Accumulates output and splits it into lines. Called from pipe queues.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let captureStdout: Bool
    private let onStdoutLine: (@Sendable (String) -> Void)?
    private let onStderrLine: (@Sendable (String) -> Void)?
    private var out = Data()
    private var outLine = Data()
    private var errLine = Data()
    private var err = Data()
    private static let stderrLimit = 64 * 1024

    init(captureStdout: Bool, onStdoutLine: (@Sendable (String) -> Void)?, onStderrLine: (@Sendable (String) -> Void)?) {
        self.captureStdout = captureStdout
        self.onStdoutLine = onStdoutLine
        self.onStderrLine = onStderrLine
    }

    var stdoutData: Data { lock.withLock { out } }
    var stderrTail: String { lock.withLock { String(decoding: err, as: UTF8.self) } }

    func stdout(_ d: Data) {
        let lines: [String] = lock.withLock {
            if captureStdout { out.append(d) }
            guard onStdoutLine != nil else { return [] }
            outLine.append(d)
            return Self.drainLines(&outLine)
        }
        lines.forEach { onStdoutLine?($0) }
    }

    func stderr(_ d: Data) {
        let lines: [String] = lock.withLock {
            err.append(d)
            if err.count > Self.stderrLimit { err.removeFirst(err.count - Self.stderrLimit) }
            guard onStderrLine != nil else { return [] }
            errLine.append(d)
            return Self.drainLines(&errLine)
        }
        lines.forEach { onStderrLine?($0) }
    }

    func finishStdout() {
        let rest: String? = lock.withLock { outLine.isEmpty ? nil : String(decoding: outLine, as: UTF8.self) }
        if let rest { onStdoutLine?(rest) }
    }

    func finishStderr() {
        let rest: String? = lock.withLock { errLine.isEmpty ? nil : String(decoding: errLine, as: UTF8.self) }
        if let rest { onStderrLine?(rest) }
    }

    private static func drainLines(_ buf: inout Data) -> [String] {
        var lines: [String] = []
        while let i = buf.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let line = buf[buf.startIndex..<i]
            buf.removeSubrange(buf.startIndex...i)
            if !line.isEmpty { lines.append(String(decoding: line, as: UTF8.self)) }
        }
        return lines
    }
}
