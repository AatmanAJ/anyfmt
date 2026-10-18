import AppKit
import HaloCore

// Some engines (HTML → PDF via WebKit, NSAttributedString document import)
// need AppKit and a live main run loop, so the CLI runs inside a faceless
// NSApplication (no Dock icon, no menu bar) and exits when the command finishes.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let args = Array(CommandLine.arguments.dropFirst())
    Task { @MainActor in
        let code = await CLI.run(args)
        exit(code)
    }
    app.run()
}
