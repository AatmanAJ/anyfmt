import Foundation
import HaloCore

// `halo` — the command-line face of the same capability table the wheel uses.
//   halo formats [--json]
//   halo convert <file>... --to <format> [--opt key=value]... [--out <dir>]
//   halo tool <tool-id> <file>... [--opt key=value]... [--out <dir>]
//   halo tools
// Phase 1 skeleton; the full CLI lands in Phase 3 (see docs/ARCHITECTURE.md).

let cliArgs = Array(CommandLine.arguments.dropFirst())

func writeOut(_ s: String) { FileHandle.standardOutput.write(Data((s + "\n").utf8)) }

switch cliArgs.first {
case "formats":
    let router = Router.live()
    for f in Formats.all {
        let targets = router.allRoutes(from: f.id).keys.sorted().map(\.rawValue)
        if !targets.isEmpty { writeOut("\(f.id.rawValue)\t→ \(targets.joined(separator: " "))") }
    }
    writeOut("options: \(router.optionCount())")
default:
    writeOut("usage: \(Brand.cliName) formats | convert | tool | tools")
}
