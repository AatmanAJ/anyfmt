# Contract changes requested by lane F (docs, slides, sheets, EPUB, archives)

None of these block lane F: every route ships and passes without them. They
make outputs nicer or keep the merged build correct.

## 1. `OutputPlacer.ext(of:target:)`: keep the inner extension for single-file gzip

**What.** When the target is `gz` and the engine wrote `<name>.<ext>.gz` (one
plain file compressed, e.g. `notes.txt.gz`), return `"<ext>.gz"` as the
extension, the way `.tar.gz` is already special-cased.

**Why.** `ArchiveEngine` names a single compressed file `notes.txt.gz` (what
`gzip` does). Today the placer uses the input's stem plus the last path
extension, so the user gets `notes.gz`, and gunzipping that yields an
extension-less `notes`. No current lane F row produces a single-file `.gz`
(folders/archives always become `.tar.gz`), so this only matters if "any file →
GZIP" rows are added later.

**Proposed code** (`Sources/Jobs/Core/OutputNamer.swift`, `OutputPlacer.ext`):

```swift
static func ext(of file: URL, target: FormatID?) -> String {
    let name = file.lastPathComponent.lowercased()
    if name.hasSuffix(".tar.gz") { return "tar.gz" }
    if target == Formats.gz, file.pathExtension.lowercased() == "gz" {
        let inner = file.deletingPathExtension().pathExtension
        if !inner.isEmpty { return inner + ".gz" }
    }
    ...unchanged...
}
```

## 2. The matrix runner and CLI must keep an async `main`

Not a signature change, a requirement. `WebKitPDFEngine`, `SheetsEngine` (→ PDF)
and `QuickLookEngine` render through an offscreen `WKWebView` on the **main
actor**. Swift's async top-level code runs the main run loop (`CFRunLoopRun`),
so `await RouteExecutor().execute(…)` works from a command-line process
(verified with a CLI harness linked against AnyfmtCore: md→pdf 0.25 s,
pptx→png 3 pages). A synchronous `main` that blocks the main thread on a
semaphore while waiting for a job would deadlock these engines.
`Tests/Matrix/main.swift` must therefore stay top-level `await`-based (Phase 4).

## 3. Router rebuild when availability changes (lane B/C)

`QuickLookEngine`, `OfficePackEngine`, `PandocPackEngine` and
`PagesAppleEventsEngine` answer `isAvailable` from the live system (pack
installed in `EngineLocator.packsDirectory`, `UserDefaults` key
`optIn.iWorkAppleEvents`, iWork app present). Whoever caches `Router.live()`
should rebuild it when the user installs/removes a pack or flips the iWork
toggle in Settings, so the wheel's targets update without a relaunch.

## 4. Settings hooks (lane Settings/App), for information

- Office pack: `PackInstaller(spec: OfficePack.spec).install(from: localDMG)`;
  `OfficePack.spec.downloadURL` is the official page to send the user to (we
  never download it). `installedURL`/`uninstall()` for status and removal.
- pandoc pack: same with `PandocPack.spec` (zip).
- iWork: `PagesAppleEventsEngine.optInKey` (`"optIn.iWorkAppleEvents"`), default off.
