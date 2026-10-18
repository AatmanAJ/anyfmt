import Foundation
import HaloCore

// Matrix runner skeleton. Phase 4 fills this in: every route on its fixture,
// validated by actually opening the output; writes docs/MATRIX.md.
let router = Router.live()
FileHandle.standardOutput.write(Data("routes: \(router.optionCount())\n".utf8))
