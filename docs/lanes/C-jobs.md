# Lane C: jobs core, router internals, progress windows

Branch: this worktree. Three commits; each builds and passes its tests.

## What I built

### HaloCore (`Sources/Jobs/Core`, no AppKit)

| File | Public API |
|---|---|
| `ConversionJob.swift` | `final class ConversionJob: Job, JobDescribing`. `init(inputs:route:target:options:registry:id:)`, `convenience init(input:to:options:router:registry:)` (plans with `Router.live()` by default), `convenience init(combining:to:…)`. Exposes `route`, `target`, `isCombine`, `title` ("photo.heic → JPG"), `activityTitle` / `completedTitle` / `failedTitle`, `diagnostics`. |
| `BatchConversion.swift` | `struct BatchConversion`: `init(files:target: RouteTarget, options:registry:formatOf:)` and `init(files:to: FormatID, options:router:registry:)`. Gives `jobs`, `skipped`, `unsupported`, `isCombine`, `fileCount`, `skippedNote` ("2 already JPG"), and the batch titles. |
| `ToolJob.swift` | `final class ToolJob: Job, JobDescribing`. `init(tool:inputs:options:registry:id:)` and `static func batch(tool:inputs:options:registry:) -> [ToolJob]` (one job per file for per-file tools, one job for combine tools). Placement uses the tool's `outputSuffix` and never copies dates. |
| `JobQueue.swift` | `@MainActor final class JobQueue: ObservableObject`. `@Published records: [JobRecord]`, `@Published batches: [JobBatch]`, `limits`, `policyProvider`, `onJobFinished`, `onBatchFinished`, `submit(_ job:)`, `submit(_ batch: BatchConversion)`, `submitBatch(_:title:…)`, `cancel(_ id:)` (works for a job or a batch id), `cancelAll()`, `retry(_ id:) -> Bool`, `clearFinished()`, `record(_:)`, `batch(_:)`, `records(inBatch:)`, `runningCount(for:)`, `isIdle`, `waitUntilIdle()`, `waitForJob(_:)`. |
| `JobRecord.swift` | `JobRecord` (id, titles, inputs, `iconURL`, resource class, batch id, policy snapshot, state, fraction, ETA, outputs, error message and details, submitted/started/finished dates, `cancelRequested`, `attempt`). `JobBatch`. `BatchProgress` (counts, aggregate fraction, `position` for "3 of 12"). |
| `ConcurrencyLimits.swift` | `ConcurrencyLimits` (`.system` is CPU = `hw.perflevel0.physicalcpu` − 1 (min 1), falling back to `activeProcessorCount`; VideoToolbox 1; IO 4; network 2). `ETAModel`, a steadier wrapper over the frozen `ETAEstimator`. |
| `JobScratch.swift` | `JobScratch` (`<tmp>/<Brand.name>-jobs/<uuid>`, `makeDirectory`, `remove` (refuses paths outside the root), `purgeStale(olderThan:)`). `JobRunner.run(_:policy:engine:scratch:)` runs any `Job` and always removes its folder. The CLI can use it as is. |
| `JobFailure.swift` | `JobDescribing` protocol. `JobFailure.from(_ error:)` turns any error into a human message plus technical details (ConversionError, Cocoa file errors, ENOSPC, cancellation). `JobDiagnostics.report(…)` adds app/OS versions, the job, the route and the error, and is what "Copy details" copies. |
| `JobProgress.swift` | (internal) `JobProgressDriver`: monotonic, thread-safe bridge from an engine's `ProgressSink` to `Job.progress`. |
| `RecentConversions.swift` | `RecentConversions` (thread-safe; `.shared`; `init(directory:)`; `items` (newest first, prunes deleted outputs on read and saves the pruned list), `add(title:outputs:date:)`, `add(_ record:)`, `remove(_:)`, `clear()`). Stored at `Application Support/<Brand.name>/recents.json`, limit 10, deduplicated by output path. `RecentConversion` value type. |

### Router internals (`Sources/Engine/Router.swift`, `RouteExecutor.swift`)

No public API changed.
- `allRoutes(from:)` is memoised per start format, per Router instance, in a lock-protected `RouteMemo`. A Router is immutable, so its memo never goes stale.
- `Router.live()` reuses one warm Router while the *available* rows are identical (`LiveRouterCache`). If an engine or pack appears or disappears, the rows differ, so it builds a fresh Router. That's the invalidation.
- `RouteExecutor` deletes `stepN-1/` as soon as hop N has produced its output. It never deletes a folder an engine handed back as its output, and it never touches the user's input. A 3-hop route over a big video holds at most two generations on disk.

### App (`Sources/Jobs/UI`, SwiftUI hosted in AppKit)

| File | What |
|---|---|
| `JobsController.swift` | The one object the app wires up. It owns `queue`, `presenter` and `recents`. `convert(_:to:options:near:)`, `runTool(_:on:options:near:)`, `submit(_:near:)`. It purges stale scratch folders and pre-warms the router memo in the background 1.5 s after init. |
| `ProgressPresenter.swift` | `present(job:near:)`, `present(batch:near:)`, `present(jobs:near:)` (one card when the ids are exactly one batch), `dismissAll()`. Handles stacking, the summary card, auto-close, hover pause, reveal, copy details, retry, cancel and VoiceOver announcements. |
| `ProgressPanel.swift` | Borderless `.nonactivatingPanel` at `.floating`, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`. It never becomes key or main. The hosting view accepts first mouse, tracks hover with `.activeAlways` (it works while Finder is frontmost) and reports content-size changes. |
| `ProgressCardView.swift` | The card, the "+N more" card, icon (Finder icon or Quick Look "print" thumbnail, fanned stack for batches), bar, buttons, and chrome (vibrancy with a rounded `maskImage`, hairline, a shadow clipped so it never covers a neighbour). |
| `ProgressCardState.swift` | Pure state builder from records: titles, captions, percent, ETA text (full and compact), saved-to note, batch counts, failure message, details. Unit-tested. |
| `ProgressStackLayout.swift` | Pure geometry: picks the display (multi-display, nearest fallback), centres the newest card under the drop point and pushes the column on-screen. |
| `ProgressTheme.swift` | Every metric, type size, colour and timing, derived from `DesignTokens` (iris accent, success/danger/ink/mist). |
| `Reveal.swift` | `Reveal.finder.inFinder(urls)` merges requests within 250 ms into one `activateFileViewerSelecting`. `now(_:)` is for clicks. It is injectable for tests. |
| `FileIconProvider.swift` | NSWorkspace icon right away, then a QL `.thumbnail` for image, vector, video and PDF files. The cache is a bounded `NSCache` of 48 entries. |
| `ProgressCardGallery.swift` | Offscreen `ImageRenderer` render of every state into `docs/screens/progress-*.png`. |

Screens (rendered by `make test`, see `ProgressGalleryTests`): `progress-running`, `-success`,
`-failure`, `-batch`, `-states-light`, `-states-dark`, `-stack-light`, `-stack-dark`,
`-high-contrast`, `-reduce-transparency-dark`, `-interactions` (hover "Show in Finder", "Copied").

## Integration for the orchestrator (App lane / Phase 3)

```swift
// AppDelegate.applicationDidFinishLaunching (skip under isRunningTests)
jobs = JobsController(policyProvider: { Settings.shared.outputPolicy })   // settings lane
// Wheel drop on a conversion segment (lane B):
jobs.convert(urls, to: routeTarget, options: chosenOptions, near: NSEvent.mouseLocation)
// Instant tool, or an editor's "Save copy" (lane G):
jobs.runTool(toolID, on: urls, options: editorValues, near: point)
// Menu bar "Recent conversions": jobs.recents.items → title + Reveal.finder.now(item.outputs)
// Settings › Advanced › concurrency: jobs.queue.limits = ConcurrencyLimits(cpu: n)
// make gallery: in --render-gallery, also call ProgressCardGallery.render(into: dir)
```

Cloud jobs (lane I) conform to `Job` with `resourceClass = .network` and optionally
`JobDescribing`, then go through `jobs.submit(job, near:)`. They get the same card, cancel and retry.

## Decisions (ready for DECISIONS.md)

- **D-C1 Scratch folders.** Every run gets `FileManager.temporaryDirectory/<Brand.name>-jobs/<job uuid>`, created fresh, with leftovers from a previous attempt removed. `JobRunner` deletes it in a `defer`, so success, failure and cancel are all covered. Deletion refuses paths outside the root. At launch, `purgeStale` removes folders older than 6 h. It's age-gated rather than delete-all because the CLI may be mid-job.
- **D-C2 Queue scheduling.** One FIFO per resource class, and classes never block each other. Limits come from `ConcurrencyLimits.system` (P-cores − 1 via `hw.perflevel0.physicalcpu`, VT 1, IO 4, network 2) and can be changed at runtime. Jobs run in `Task.detached(priority: .userInitiated)`. Cancelling a queued job takes effect immediately. Cancelling a running job cancels its Task (`ProcessRunner` sends SIGTERM, then SIGKILL after 2 s), and the record flips to `.cancelled` when the job has actually exited. That keeps the concurrency slot honest. A job that finishes successfully despite a late cancel is reported as succeeded, because its files exist.
- **D-C3 Progress polling, not KVO.** A main-actor loop reads `Job.progress.fractionCompleted` (thread-safe) at ≤ 30 Hz, only while something runs, and republishes only on a visible change (≥ 0.1 % or ETA moving ≥ 0.5 s). Idle cost is zero, there are no KVO observers to tear down, and it's clean under Swift 6 strict concurrency.
- **D-C4 ETA.** `ETAModel` wraps the frozen `ETAEstimator`. It stays silent for the first 0.8 s or 2 %, samples at 4 Hz, counts down between samples, and lets a new estimate pull the countdown down (blended) but push it up only on a real slowdown (> 1.3 × + 2 s). Tested to be non-increasing at a steady rate and within 15 % of the truth.
- **D-C5 Resource class of a conversion.** `.videoToolbox` only when the final hop's engine is ffmpeg or AVFoundation, the target is MP4/MOV/M4V/MKV, `hardware` isn't off, and `videoCodec` isn't AV1 or VP9. VideoToolbox has no VP8/VP9/AV1/WMV encoders, so WebM, AVI and WMV are CPU encodes. Archive targets and the bsdtar engine are `.io`. Everything else is `.cpu`.
- **D-C6 Combine naming.** A combine conversion of one item is named after it (`Photos.zip`). Several items are named `Archive.zip` in the first item's folder, as Finder does. Items already in the target format (a `.zip` among folders) go into the archive rather than being skipped.
- **D-C7 Retry** re-runs the same `Job` object with a fresh policy snapshot. The record keeps its id and `attempt` increments. Succeeded jobs are never re-run, because that would make "photo 2.jpg". Batch retry re-runs only failed and cancelled members.
- **D-C8 Copy details** contains: app version and build, macOS version, arch, the job title, inputs (file names only, never full paths), the route with engines, resource class, options, attempt, and the technical error.
- **D-C9 Progress card.** Size is 288 × 70 pt. The reference is ≈ 260 × 70; the extra 28 pt lets name, percentage and ETA share one line. Corner radius is `Radius.large`, the accent is iris, type is `TypeRamp.body` semibold for the title and caption + 0.5 for detail. The footer uses `ViewThatFits` and picks the longest wording that fits without truncation: full ETA, then compact ETA ("12 s left"), then without the skipped note, then a middle-truncated name. Success swaps the bar for the new file's name (showing collision names like `photo 2.jpg`) and where it went. The ✕ morphs into a ✓ and the whole card becomes a "Show in Finder" target.
- **D-C10 One panel per card, older panels in front.** Each card gets its own non-activating panel, so lifetimes and animations are independent. Panels carry a transparent 22 pt margin for the soft shadow. The upward shadow is clipped to inside the 8 pt stack gap, and older (lower) panels are ordered in front. The only overlap is a lower panel's fully clear top margin over the card above, and fully transparent pixels are click-through (PLATFORM_RESEARCH A6), so every button stays clickable.
- **D-C11 Anchor.** The newest card is centred horizontally under the drop point with its top edge 26 pt below it, so the pointer doesn't rest on it (resting there would pause auto-close). A new presentation re-anchors the whole stack at the latest drop point, because the stack follows where the user is working. The column is pushed inside the visible frame (inset 12 pt) of the display containing the point, or the nearest one. The newest card wins if the column is too tall.
- **D-C12 Motion.** Cards spring in (response 0.34, damping 0.8) from slightly above, towards the drop point, at a scale of 0.92 to 1. They ease out in 0.14 s, and the panel is ordered out at 0.18 s. Restacks slide windows over 0.26 s (ease-out). Reduce Motion means fades only and no window sliding. Reduce Transparency means a solid surface. Increased Contrast means a 1 pt hairline, a stronger track, ink-coloured secondary text and outlined quiet buttons. VoiceOver gets labelled elements, a progress value with `.updatesFrequently`, and announcements on success and failure.
- **D-C13 Reveal coalescing.** Reveals within 250 ms merge into one Finder call. Batches reveal once, when the whole batch is done, with every output. A partly failed batch still reveals what converted.
- **D-C14 Router memo.** Memoisation is per Router instance (immutable, so no invalidation is needed). `live()` caches by exact available rows. Measured on a 331-row synthetic table shaped like the real one, Debug build: cold `commonTargets` for 3 inputs takes **10.5 ms**, memoised **0.025 ms** (≈ 420×). `JobsController` pre-warms all start formats on a utility task 1.5 s after launch, so the first Shift-tap is warm too.

## Shipped

- Conversion jobs (per-file, multi-hop, multi-output, combine), tool jobs (per-file and combine), the batch planner with skip and unsupported reporting, the queue with per-class limits, cancel, retry and batches, recents, scratch hygiene and the ETA.
- Progress windows: icon or thumbnail, title, determinate bar, percentage and ETA, cancel, stacking (5 visible plus "+N more"), on-screen clamping across displays, success state with reveal and auto-close (paused on hover), failure state with Copy details, Close and Retry, skipped note, all accessibility modes.

Not shipped / for PARITY.md:
- An expandable per-file list inside a batch card (optional in the brief). The batch card shows "3 of 12" and aggregate progress, and Copy details lists every failed file.
- Live vibrancy can't be captured offscreen (`ImageRenderer` can't draw `NSVisualEffectView`). The screenshots use the translucent fallback surface (`ProgressCardSurface.translucent`) over our own backdrop. The on-screen panels use real behind-window vibrancy (`.popover` material, rounded `maskImage`).

## Contract change requests

None. Everything was built on the frozen contracts. The only additions are internal: `Router.computeAllRoutes`, `Router.cached(for:)`, `memoizedStartCount`, `RouteExecutor.isInside`.

## Tests

- `Tests/Unit/Core/Jobs/`: 45 new tests. With the existing RouterTests (11) and OutputNamerTests (5), that makes `CoreTests` = 61, all still green.
  - **JobQueueTests:** per-class limits and FIFO; P-core limit; progress and ETA publishing; cancelling a running conversion whose engine runs a real `/bin/sh … exec sleep 30` (child PID gone with ESRCH, scratch folder removed, nothing placed, < 5 s), with a queued job never starting; batch cancel and cancelAll; failure message and details (no full paths); retry with a fresh policy; batch aggregates and hooks; an idle queue stops publishing; error mapping.
  - **ConversionJobTests:** titles; never overwriting (pre-created `photo.jpg` and `photo 2.jpg` give `photo 3.jpg`); dates kept and the folder policy honoured; multi-hop routes with options on the final hop only; no route; missing engine; multi-output into a folder; combine naming (`Archive.zip` / `Photos.zip`); resource class table; re-runs; age-gated scratch purge.
  - **BatchConversionTests:** skipping same-format files, unsupported files, router-planned batches, the queue run, combine including existing archives.
  - **ToolJobTests:** suffix plus never overwriting, no date copy, per-file loop and split, combine run with minimum arity, missing runner, resource class.
  - **RecentConversionsTests:** limit of 10 newest first, persistence round-trip, pruning (whole and partial entries) saved to disk, dedupe, corrupt-file recovery.
  - **ETAModelTests:** monotonic countdown at a steady rate within tolerance, a real slowdown raises the ETA, no ETA when stalled or done.
  - **RouterMemoTests:** memo equals the uncached search for every start; the cached router is reused until rows change (added rows, vanished engine); `live()` is warm; thread safety under 64 concurrent tasks; perf measurement; executor deletes intermediate steps as it goes; pass-through outputs are kept.
- `Tests/Unit/App/JobsUI/` (18 tests): the presenter creates a floating non-activating panel below the drop point; stacking with newest on top, consistent spacing and z-order; 5 visible plus summary, with folded cards coming back; clamping at the bottom-right corner; success reveals once and auto-closes; no reveal when the policy is off; hover pauses auto-close; failure stays, the panel grows, Copy details reaches a private pasteboard and Retry works; cancel from the card; one card per batch with one reveal of all outputs; JobsController wiring to recents; pure layout clamping on every edge; the newest card wins on short screens; multi-display selection; ETA and percent text; card states from records; batch counts, notes and failure message. Plus `ProgressGalleryTests` (renders and checks all screens).

Results: full `-scheme Halo test` gives `CoreTests` 61 / 61 and `AppTests` 19 / 19 (18 new plus the smoke test). Core passed on three consecutive runs. `scripts/check-entitlements.sh` passes. My files produce no compiler warnings under Swift 6 strict concurrency.

```bash
xcodebuild … test -only-testing:CoreTests      # 61 tests, ~3–5 s
xcodebuild … test -only-testing:AppTests       # 19 tests, ~2 s
```

## Blockers

None for this lane. Two items need a human on real hardware (they fit into BLOCKERS B-001's
five-minute session):
1. Click a lower card's ✕ while three cards are stacked. This confirms panel-margin click-through as the platform research predicts.
2. Glance at a live card over a busy wallpaper in light and dark mode, to confirm the vibrancy material (`.popover`) and the 0.38 / 0.22 tint.
