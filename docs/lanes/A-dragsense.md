# Lane A: DragSense

`Packages/DragSense` is a standalone MIT SwiftPM package (macOS 13+, Swift 6
language mode, strict concurrency). It does global file-drag and modifier-tap
detection with no TCC permission. It's the Phase 0 winner (D-001)
productionised, and it knows nothing about anyfmt or about file conversion.

Status: **done**. `swift test`: 97 tests, 0 failures, ~0.02 s. Clean build
with zero warnings. No contract changes needed.

## What I built

| File | What |
|---|---|
| `Sources/DragSense/DragSense.swift` | `@MainActor final class DragSense: ObservableObject`: the state machine and poll loop |
| `TapDetector.swift` | Pure tap/hold/chord detector (internal) |
| `ModifierKey.swift` | `enum ModifierKey` (shift, command, control, option, function): flag mapping, symbols ⇧ ⌘ ⌃ ⌥ fn, Apple display order |
| `Trigger.swift` | `struct Trigger { id, key }`, `enum RetapBehavior { ignore, close }` |
| `DragSenseConfiguration.swift` | Every tunable value, clamped by `validated()`. Codable, and missing keys decode to defaults, so saved settings survive new fields |
| `DragInfo.swift` | `DragInfo`, `DragPasteboardContents`, `DragPasteboardType` (file/promise type strings plus `isFileDrag`) |
| `DragSenseState.swift` | `DragSenseState`, `DragSenseEvent` |
| `InputSource.swift` | `protocol InputSource`, `protocol PollScheduler`, `ScreenInfo`, `WakeUpReason` |
| `SystemInputSource.swift` | Real input: NSEvent device state, drag pasteboard (contents read off the main thread), NSScreen, global and local mouse monitors |
| `DispatchPollScheduler.swift` | Real clock (`systemUptime`) plus one main-queue `DispatchSourceTimer`, rescheduled in place |
| `GlobalHotKey.swift` | Carbon `RegisterEventHotKey` wrapper with validation |
| `DragSenseDiagnostics.swift` | `os.Logger` subsystem "DragSense", verbose switch, latency probe, `LatencySummary` |
| `README.md` | What it is, install, usage, permissions and why, how it works, caveats, MIT |
| `Tests/DragSenseTests/**` | `FakeSystem` (manual clock, scripted input) plus `Harness`, then 97 tests in 11 classes |

### Public API summary

```swift
@MainActor final class DragSense: ObservableObject {
    init(configuration: DragSenseConfiguration = .default,
         input: any InputSource = SystemInputSource(),
         scheduler: any PollScheduler = DispatchPollScheduler())
    var configuration: DragSenseConfiguration       // settable, validated, applies live
    @Published private(set) var state: DragSenseState
    private(set) var currentDrag: DragInfo?
    private(set) var isRunning: Bool
    var onEvent: (@MainActor (DragSenseEvent) -> Void)?
    var onStateChange: (@MainActor (DragSenseState) -> Void)?
    func events() -> AsyncStream<DragSenseEvent>
    func stateUpdates() -> AsyncStream<DragSenseState>  // starts with the current state
    func start(); func stop()
    func wheelDidAcceptDrop(); func cancelWheel()
    func markWheelVisible()                         // finishes the latency probe
    let diagnostics: DragSenseDiagnostics           // isVerbose, latencySamples, latencySummary(), onLatencySample
}
enum DragSenseState { idle, dragging(dragID: Int), wheelOpen(triggerID: String), dropped, cancelled }
enum DragSenseEvent { dragBegan(DragInfo), triggerTapped(Trigger, DragInfo, location: CGPoint),
                      dragMoved(CGPoint), dragEnded(location: CGPoint) }
struct DragInfo { fileURLs, promisedTypes, pasteboardTypes, itemCount, changeCount, startLocation,
                  startTime, isPartial; id == changeCount; isPromiseOnly }
struct DragSenseConfiguration { triggers, tapThreshold 0.35 (0.15–0.8), idlePollInterval 0.25,
    activePollRate 240, requireFileTypes true, topExclusionHeight 24, minimumDragDistance 3,
    pasteboardReadTimeout 0.25, dropResolutionTimeout 1, dragMovedInterval 1/60, retapBehavior .ignore }
@MainActor final class GlobalHotKey { init(shortcut:handler:), register() throws, unregister(),
    isRegistered, static validate(_:), static validationError(for:) }
```

## How the app should wire it (for the integrator / lane B)

- Triggers: `[Trigger(id: "convert", key: .shift), Trigger(id: "tools", key: .command), Trigger(id: "actions", key: .control)]`.
  Settings › Keys edits `configuration.triggers` live. Persist the whole
  `DragSenseConfiguration` with `JSONEncoder`.
- `.triggerTapped(trigger, info, location)`: build the wheel for `trigger.id`
  from `info.fileURLs`, or from `info.promisedTypes` for promise-only drags,
  and show it at `location`. A second `.triggerTapped` while open means
  **switch** (morph). If `info.isPartial`, read the dragging pasteboard on drop.
- Overlay `performDragOperation`: call `sense.wheelDidAcceptDrop()`.
- `.dragEnded(location)`: if the drop missed the wheel or landed in the hub
  (cancel zone), call `sense.cancelWheel()`. Otherwise wait for
  `performDragOperation`. DragSense auto-cancels after 1 s as a backstop.
- On the overlay's first `NSWindow.didChangeOcclusionStateNotification` with
  `.visible`, call `sense.markWheelVisible()`. Read
  `sense.diagnostics.latencySummary()` for PERF.md (key tap → wheel visible p95).
- Drop ring fallback (D-004): `GlobalHotKey(shortcut: .init(keyCode: 49 /* kVK_Space */, modifiers: [.control, .option]))`.
  Settings should show `GlobalHotKey.validationError(for:)` for rejected shortcuts.

## Decisions (ready for DECISIONS.md)

- **A-1 Same-trigger re-tap is ignored by default.** `retapBehavior = .close` is
  available. Reason: people double-tap by habit, and closing by accident
  mid-drag is worse than a wasted tap. Mid-drag, the wheel still closes by
  dropping in the hub or outside it.
- **A-2 Cancel while the button is down returns to `dragging`.** It doesn't go
  to idle, so another tap reopens the wheel in the same drag. Observers see
  `wheelOpen → cancelled → dragging`.
- **A-3 Mouse-up with the wheel open leaves the state at `wheelOpen`.** It stays
  there until the host's verdict or `dropResolutionTimeout` (1 s). Reason:
  AppKit's `performDragOperation` and our poll's mouse-up arrive in either order.
  This replaces Daisy-style 0.1–0.15 s dismissal timers with an explicit handshake.
- **A-4 Drag pasteboard contents are read off the main thread.** The main
  thread only reads `changeCount` and `types`, which measured 0.4 µs and 3.8 µs.
  File URLs and promised types are read once per drag on a private serial queue.
  That read took 5–12 ms cross-process for a one-item browser drag, and a hung
  lazy provider could block for much longer. While it's in flight the main
  thread doesn't touch the pasteboard (`dragPasteboardChangeCount` returns nil),
  so the NSPasteboard object is only ever used by one thread at a time; we
  don't rely on NSPasteboard being thread-safe. After 5 s the read is logged as
  stalled and polling resumes. A tap during the read is held, then delivered.
  After `pasteboardReadTimeout` (0.25 s), the drag goes on with
  `DragInfo.isPartial`, and a late result fills `currentDrag` for later events.
- **A-5 Each drag's change count is consumed at detection.** It becomes the
  baseline at once, so a drag can never be detected twice, even if it ends
  while its read is in flight. (This bug was found in review and is covered by
  a regression test.)
- **A-6 Minimum drag distance is waived when the press was seen late.** If the
  idle timer, not a mouse-down event, saw the button first, the true press point
  is unknown. The distance check exists for apps that write the drag pasteboard
  on mouse-down, and those are caught when the wake-up is prompt.
- **A-7 A non-file `changeCount` bump gets its types re-checked for 150 ms,
  then ignored** until the count changes again. Some sources clear the
  pasteboard and write it a moment later. This keeps `types` reads from running
  at 240 Hz for the whole length of a text drag.
- **A-8 The top exclusion band is per screen, and suppresses opening only.** The
  band is `max(topExclusionHeight, menu bar or notch inset)`, which is 33 pt on
  this MacBook. Switching wheels inside it is allowed, because the wheel already
  exists. `topExclusionHeight = 0` disables the band.
- **A-9 The global `flagsChanged` monitor is opt-in** (`SystemInputSource(observesModifierEvents:)`,
  default false). D-001 said "install opportunistically". For an MIT package
  that advertises "no permissions", a keyboard-class monitor whose TCC status
  is contested isn't worth ~4 ms. When on, it only triggers an extra poll and
  never feeds tap detection, so it can't double-fire.
- **A-10 Chord rule.** A key pressed while another is held spoils both. Two keys
  first seen in the same sample are a chord. A release and a press in the same
  sample are treated as sequential, because the order can't be known.
  Caps Lock, numeric-pad and help flags are ignored.
- **A-11 Tap timing for the latency probe.** The probe starts at the poll before
  the release was seen, so it's a conservative upper bound that includes polling
  delay and main-thread stalls. Wheel switches aren't measured.
- **A-12 Wake-ups come from global plus local monitors** for left mouse down and
  dragged. The local monitors cover drags that start in the app's own windows,
  such as the Float shelf. `mouseDragged` only wakes an idle poller (a missed
  mouse-down); otherwise the active timer covers it.
- **A-13 Combine `@Published` state**, plus AsyncStreams and callbacks.
  Callbacks are synchronous and the lowest-latency path, so use them for the wheel.
- Licence: MIT (already in `Packages/DragSense/LICENSE`). Size: about 1.8k lines
  of source including docs. Nothing is bundled.

## Shipped vs not (for PARITY.md)

Shipped: Shift / Command / Control (any of the five modifiers) tap mid-drag
opens the wheel. It stays open after release, switches on another trigger,
keys are remappable live, the threshold is adjustable, promise drags (Mail,
Photos, browsers) work, and drags from multiple displays and the menu-bar or
Mission Control band are handled. The hotkey fallback is included.

Not in this package (by design): drawing the wheel, accepting the drop (lane B),
and Enter on a Finder selection (D-004, app-level and opt-in).

## Tests and numbers

- `cd Packages/DragSense && swift test`: **97 tests, 0 failures** (0.015 s). The
  classes are StateMachine (19), Tap (22), TapDetector (4), Pasteboard (18),
  Geometry (5), Timing (6), Delivery (5), Diagnostics (5), Configuration (5),
  ModifierKey (3) and GlobalHotKey (5). They cover every item in the brief: full
  transitions, tap vs hold vs chord, threshold boundaries (35 vs 36 ticks at
  0.35 s), live remap, switching while open, staying open after release,
  mouse-up ends the drag, late wake-up via the idle baseline, stale pasteboard,
  non-file drags, promise-only drags, the top band (per screen and notch),
  missed mouse-up recovery, and hotkey validation. They also cover re-entrant
  callbacks, slow and timed-out reads, AsyncStream, Combine and the latency probe.
- **Mutation check.** I broke 10 core rules one at a time: threshold `<=`, the
  chord rule, the pre-held rule, the baseline compare, the drop-while-down
  handling, the top band, the minimum distance, the idle refresh, re-tap, and
  type re-check throttling. Every break failed at least one test.
- **Live smoke run** on this machine (macOS 27.0.1, M5 Max, release build, from
  a scratch probe; no input synthesised):
  - `AXIsProcessTrusted`, `CGPreflightListenEventAccess` and `CGPreflightPostEventAccess`
    were all false before and after a full run.
  - The real drag pasteboard read worked off the main thread: 5.4–12.4 ms for a
    stale one-item browser promise drag, and `promisedTypes = ["org.webmproject.webp"]`.
  - `DispatchPollScheduler` at 240 Hz gave 239 ticks/s, with tick gaps of p50 4.16 ms,
    p99 5.34 ms and max 5.49 ms.
  - A started `DragSense` used **0.040 % of one core while idle** (10 s,
    getrusage). D-001 measured 0.15 % at 20 Hz.
  - Per-tick main-thread cost is about 1 µs: changeCount 0.4 µs, device state 0.1 µs.
  - The `GlobalHotKey` ⌃⌥⇧⌘F19 registered and unregistered fine.
  - `NSFilePromiseReceiver.readableDraggedTypes` returned the metadata type, a
    dyn type and the promised content type; all are merged into the file-type set.

## Known gaps

- **B-001 still applies.** Nobody has observed a real Finder drag with a real
  key tap, because the harness can't synthesise input. A person should run the
  host app (or DragProbe) once. The package logs everything with `isVerbose`.
- It's unknown whether secure input (a focused password field) hides
  `modifierFlags`.
- fn as a trigger may be noisy (arrow and F-keys can report the fn flag).
- A drag pasteboard write with the button up, less than one idle interval
  before a press, can look like a drag start. `minimumDragDistance` filters most.
- The module and class are both named `DragSense`, so module-qualified names
  (`DragSense.Trigger`) don't resolve. This matters only if the app defines a
  clashing type name; none exists today.

## Contract change requests

None.

## Blockers

None new. B-001 (real-hardware verification) is unchanged.
