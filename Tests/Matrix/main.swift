import AppKit
import AnyfmtCore

// anyfmt-matrix: runs every shipped route on its fixture, validates each output by
// opening it (ImageIO decode, ffprobe probe + duration, PDFKit pages, archive
// listing, re-parse for text formats), and writes docs/MATRIX.md.
//
//   anyfmt-matrix --fixtures Tests/Fixtures/generated --out Tests/Matrix/out --report docs/MATRIX.md
//               [--only <from-format>] [--jobs N] [--json path]

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let args = Array(CommandLine.arguments.dropFirst())
    Task { @MainActor in
        let code = await MatrixRunner(args: args).run()
        exit(code)
    }
    app.run()
}
