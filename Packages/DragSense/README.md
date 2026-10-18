# DragSense

Detects global file drags and modifier taps for background macOS apps, with
**no permissions**.

DragSense notices when the user is dragging files in *any* app (Finder,
the Desktop, Spotlight, Mail, Photos, a browser) and tells you when they
**tap** a modifier key mid-drag. You might use it to open a drop target under
the pointer while the other app still owns the drag. It draws nothing and
knows nothing about what you do with the files.

- Public AppKit API only. No Accessibility, no Input Monitoring, no private API.
- A tap is a press and release within a threshold. Holds and chords never
  fire, so the source app's own drag modifiers (Finder's ⌘ move, ⌥ copy) still work.
- Detection is an explicit, unit-tested state machine. Remap keys at runtime.
- Costs about 0.04 % of one core while idle. Detection adds at most one poll interval (~4 ms at 240 Hz).
- Swift 6 strict concurrency, macOS 13+, no dependencies (AppKit and Carbon only).

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/<owner>/<repo>", from: "1.0.0"),
// target:
.product(name: "DragSense", package: "DragSense"),
```

Or add the local `Packages/DragSense` folder as a package dependency.

## Usage

```swift
import DragSense

@MainActor final class WheelController {
    let sense = DragSense(configuration: .init(triggers: [
        Trigger(id: "convert", key: .shift),
        Trigger(id: "tools", key: .command),
    ]))

    func start() {
        sense.onEvent = { [weak self] event in
            switch event {
            case .triggerTapped(let trigger, let drag, let location):
                self?.show(trigger.id, files: drag.fileURLs, promised: drag.promisedTypes, at: location)
            case .dragEnded(let location):
                self?.finish(at: location) // then call sense.wheelDidAcceptDrop() or sense.cancelWheel()
            case .dragBegan, .dragMoved:
                break
            }
        }
        sense.start()
    }
}
```

The same events are available as `sense.events()` (an `AsyncStream`). State
is available as `sense.state` (`@Published`, so SwiftUI can observe it), as
`sense.stateUpdates()` and through `onStateChange`.

### The state machine

```
idle → dragging → wheelOpen(triggerID) → dropped / cancelled → idle
```

- **Once open, the wheel stays open** after the key is released, until you
  call `wheelDidAcceptDrop()` or `cancelWheel()`.
- Tapping a **different** trigger while it's open switches wheels: you get
  `.triggerTapped` again, in the same drag session.
- Tapping the **same** trigger again is ignored by default. Set
  `retapBehavior = .close` to make it close the wheel instead.
- `cancelWheel()` while the button is still down returns to `dragging`, so
  another tap reopens the wheel. After mouse-up it returns to `idle`.
- When the mouse goes up with the wheel open you get `.dragEnded(location:)`.
  DragSense then waits for your verdict. Your drop target's
  `performDragOperation` usually calls `wheelDidAcceptDrop()`, before or
  after `.dragEnded` arrives; both orders work. If nothing answers within
  `dropResolutionTimeout` (default 1 s), DragSense cancels by itself.

### Recommended drop target

DragSense doesn't draw anything. A drop target that works while another app
owns the drag looks like this:

- a borderless `NSPanel` with `.nonactivatingPanel`, at level `.popUpMenu`.
  That's above the Dock and menu bar, but below the drag image, so the dragged
  icon stays on top;
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
  and `hidesOnDeactivate = false`;
- shown with `orderFrontRegardless()`, never made key;
- `registerForDraggedTypes` (file URLs plus `NSFilePromiseReceiver.readableDraggedTypes`)
  called before the panel is ordered in;
- every hit area painted with alpha ≥ 0.01, because fully transparent pixels
  never receive `draggingEntered`.

## Permissions: none, and why

| What DragSense reads | API | Why no permission |
|---|---|---|
| Mouse buttons, pointer, modifier keys | `NSEvent.pressedMouseButtons`, `.mouseLocation`, `.modifierFlags` | Documented as live device state, independent of event delivery. No key *events* are read. |
| Is a drag happening, and of what? | `NSPasteboard(name: .drag)`: `changeCount`, `types`, file URLs, promised types | The drag pasteboard is readable from any process. Pasteboard privacy (macOS 15.4+) only covers the general pasteboard. |
| Wake-up on mouse-down | Global and local `NSEvent` monitors for left mouse down/dragged | Only key-related global monitors need a grant. |
| Optional global hotkey | Carbon `RegisterEventHotKey` | Never needed a grant. |

Verified on macOS 27.0.1 with `AXIsProcessTrusted()`,
`CGPreflightListenEventAccess()` and `CGPreflightPostEventAccess()` all
`false`. The global `flagsChanged` monitor (`SystemInputSource(observesModifierEvents: true)`)
is **off by default**: reports conflict on whether it needs a grant on some
versions. Polling already sees every tap, so the monitor only trims one poll
interval off detection.

## How it works

1. **Idle.** A 4 Hz timer with generous leeway runs, and a mouse-down monitor
   wakes it early. While the button is up, the drag pasteboard's `changeCount`
   is recorded as the *idle baseline*.
2. **Button down.** The poll switches to 240 Hz. A drag has begun when the
   `changeCount` differs from the idle baseline and the pasteboard carries
   `public.file-url` or a file-promise type. Comparing against the idle
   baseline, not a mouse-down snapshot, means a late wake-up can't miss the
   source's write. An unchanged count never counts, so the previous drag's
   leftover contents never trigger anything. There's no "after N drag events,
   assume a drag" fallback either, so window moves and text drags are ignored.
3. **Taps.** Modifier flags are sampled on every tick. A tap is one key down
   and up within `tapThreshold` (default 0.35 s, range 0.15–0.8 s) with no
   other modifier involved. Keys already held when the button went down never
   count.
4. **Still pointer.** The poll keeps running while the pointer is still. The
   OS sends no drag events then, but a tap still has to be seen.
5. **Contents.** File URLs and promised types are read once per drag, on a
   private queue, off the main thread. A lazy provider in the source app can
   make that read slow: 5–12 ms was measured for a one-item browser drag. If
   it takes longer than `pasteboardReadTimeout` (0.25 s), the drag carries on
   with `DragInfo.isPartial = true`. Taps that land while the read is pending
   are held and delivered when it finishes.

## Testing your integration

`DragSense(configuration:input:scheduler:)` takes any `InputSource` (device
and pasteboard state) and `PollScheduler` (clock and timer). Give it a fake
with a manual clock and you can script a whole drag deterministically: press,
move, pasteboard write, key taps, release. The package's own tests do exactly
this (`Tests/DragSenseTests/Support/FakeSystem.swift`).

## Global hotkey

```swift
import Carbon // kVK_ key codes

let ring = GlobalHotKey(shortcut: .init(keyCode: UInt32(kVK_Space), modifiers: [.control, .option])) {
    showDropRing()
}
try ring.register()
```

Shortcuts must include ⌘ or ⌃. From macOS 15, Option-only and
Option+Shift-only hotkeys are refused for sandboxed apps. fn and bare
modifier keys are rejected. `GlobalHotKey.validationError(for:)` lets a
settings UI explain why a shortcut isn't allowed.

## Diagnostics

- `sense.diagnostics.isVerbose = true` logs every transition and tap to
  `os.Logger`, subsystem `DragSense`. To watch it:
  `log stream --level debug --predicate 'subsystem == "DragSense"'`.
- Latency probe: call `sense.markWheelVisible()` once your wheel is really on
  screen. `sense.diagnostics.latencySummary()` then gives the p50, p95 and max
  latency from tap to visible wheel. Each measurement starts at the poll
  *before* the release was seen, so the result is an upper bound that includes
  polling delay.

## Caveats and limitations

- **Real-hardware checks.** The detection path was verified in a test harness
  that couldn't synthesise input. Every API involved is permission-free and
  documented, but nobody has yet watched a real Finder drag with a real key
  tap. Do that once per macOS release.
- **Very short taps.** A press and release that both fall between two polls is
  invisible. At 240 Hz that means a tap under ~4 ms, which fingers don't produce.
- **Durations are quantised** to the poll interval (±4 ms), so the threshold
  boundary is soft by that much.
- **Left button only.** Drags with other mouse buttons aren't tracked.
- **Drags already under way** when you call `start()` aren't picked up.
- **Top band.** Taps inside the top band of each screen never open a wheel.
  The band is the larger of `topExclusionHeight` (default 24 pt) and that
  screen's menu-bar or notch inset; it covers the menu bar and Mission Control's
  drag-to-top zone. Switching wheels there is still allowed.
- **fn as a trigger** is noisy: some keyboards report the fn flag for arrow and
  function keys.
- **Secure input.** It's unknown whether secure input (a focused password
  field) hides modifier state from `NSEvent.modifierFlags`.
- **Early pasteboard writes.** An app that writes the drag pasteboard with the
  button *up*, less than one idle interval before a press, can look like the
  start of a drag. The `minimumDragDistance` check filters most of these.
- **Module and class share a name.** `DragSense.Trigger` won't resolve as a
  module-qualified name. Use the unqualified names.

## Licence

MIT. See [LICENSE](LICENSE).
