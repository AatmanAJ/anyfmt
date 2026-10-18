import AppKit
import HaloCore

// Some engines (HTML → PDF via WebKit, NSAttributedString document import)
// need AppKit and a live main run loop, so the CLI runs inside a faceless
// NSApplication (no Dock icon, no menu bar) and exits when the command finishes.
//
// SIGINT cancels the running command: engines stop (ProcessRunner terminates
// child processes), temp files are removed, and the exit code is 7.
MainActor.assumeIsolated {
    CLIPaths.locateBundledEngines()
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let args = Array(CommandLine.arguments.dropFirst())
    let task = Task { @MainActor in await CLI.run(args) }

    signal(SIGINT, SIG_IGN)
    let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    let state = InterruptState()
    interrupt.setEventHandler {
        if state.interrupted { exit(ExitCode.cancelled.rawValue) } // second ^C: stop now
        state.interrupted = true
        err("cancelling…")
        task.cancel()
    }
    interrupt.resume()

    Task { @MainActor in
        let code = await task.value
        exit(state.interrupted && code != ExitCode.usage.rawValue ? ExitCode.cancelled.rawValue : code)
    }
    app.run()
}

/// Touched only on the main queue (the signal source and the exit task).
final class InterruptState: @unchecked Sendable {
    var interrupted = false
}
