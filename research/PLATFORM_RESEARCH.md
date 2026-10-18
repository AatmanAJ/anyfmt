# Platform research for Halo (macOS 13+, arm64, LSUIElement)

Researched 2026-10-18. Every item gives the answer, the minimum macOS, sources and a confidence level. Where I ran something, it ran on **macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), MacOSX27.0.sdk, Apple M5 Max**. The throwaway programs are in the session scratchpad (`.../scratchpad/platform/`) and are not part of the repo.

**Test-harness limits (they apply throughout).** The test process had **no Accessibility and no Input Monitoring** (`AXIsProcessTrusted()`, `CGPreflightListenEventAccess()` and `CGPreflightPostEventAccess()` all returned `false`), and it can't synthesise input. So nothing here proves what happens during a real Finder drag or a real key press. Those claims come from documentation and other people's reports, and each one says so. I also didn't create event taps, because a keyboard tap would raise a TCC prompt on the user's screen. Phase 0's `Spikes/DragProbe` has to verify section A on real hardware, ideally on a clean user account.

Confidence: **high** means documented by Apple or verified here, **medium** means consistent real-world reports, **low** means inferred or contradicted.

---

## Implications for Halo (read this first)

1. **Mid-drag detection looks possible with no TCC permission, using public API.**
   - A global `leftMouseDown/Dragged/Up` monitor (no permission) detects the drag.
   - `NSPasteboard(name: .drag).changeCount` differing from the mouse-down snapshot, with file types present, confirms it is a file drag.
   - A **120 Hz timer polling `NSEvent.modifierFlags` and `pressedMouseButtons`** catches modifier taps. Both are documented as live device state, and AeroSpace, Daisy and Perch use them without permission.
   - **Do not depend on a global `.flagsChanged` monitor.** Reports conflict on whether it needs a grant.
   - DragProbe must confirm these on real hardware (I couldn't synthesise input): mouse-monitor delivery during a Finder drag, live `modifierFlags`, and `draggingEntered` on a panel that appears mid-drag. (A1–A3)
2. **Anything keyboard-level needs a grant.**
   - `keyDown` monitors need Input Monitoring or Accessibility.
   - A listen-only `CGEventTap` needs Input Monitoring.
   - Swallowing Return in Finder needs an active tap, which means Accessibility.
   - Reading the Finder selection needs Automation (Apple Events).
   - So exact "Enter on a Finder selection" parity is an **opt-in Power mode** with two prompts. (A4, B)
3. **Zero-permission fallbacks exist, and they also satisfy BUILD.md's hard-stop rule.**
   - A **Services** entry with `NSSendFileTypes` and `NSRequiredContext` receives the Finder selection with no TCC prompt. The user can give it a shortcut, and it works from an LSUIElement app.
   - A Carbon `RegisterEventHotKey` hotkey opens the wheel at the pointer with no permission. Include ⌘ or ⌃ in it: macOS 15 refuses Option-only and Option+Shift-only hotkeys for sandboxed apps. (A4, B)
4. **Wheel window recipe.**
   - Use a borderless `.nonactivatingPanel` at `.popUpMenu` (101). That is above the Dock (20) and menu bar (24) and **below the drag image (500)**, so the dragged icon stays on top.
   - Set `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` and `hidesOnDeactivate = false`, and show it with `orderFrontRegardless()`.
   - Call `registerForDraggedTypes` before ordering in.
   - **Give every hit area alpha ≥ ~0.005.** Fully transparent pixels never get `draggingEntered`.
   - Keep the wheel out of the top-edge Mission Control band.
   - No public "drag started" notification exists. (A6, A7)
5. **File-promise drags** (Mail, Photos, browsers, Screenshot thumbnail) expose only `promised-file-content-type` mid-drag. That's enough to choose formats. Call `NSFilePromiseReceiver.receivePromisedFiles` only in `performDragOperation`. (A5)
6. **ImageIO cannot encode WebP or JPEG XL on any version.**
   - **AVIF encode works on 26.5 and 27 but is unverified on 13–15.** Gate it with `CGImageDestinationCopyTypeIdentifiers()` at runtime.
   - Bundle libwebp and an AV1 encoder (SVT-AV1 via ffmpeg, or libavif) for WebP and AVIF output.
   - HEIC encode is fine on every Apple silicon Mac. (C)
7. **Background removal is macOS 14+** (`VNGenerateForegroundInstanceMaskRequest`). On macOS 13 only person segmentation exists. Saliency maps (68×68) are not masks. Label the tool "macOS 14+" for non-people images, or bundle a licence-compatible matting model. (D)
8. **Don't use NSAttributedString or `textutil` as the DOCX writer.**
   - Tested: they drop tables, lists, images and links.
   - DOCX import keeps tables but drops images.
   - Use pandoc for DOCX/ODT/EPUB output.
   - The HTML importer is main-thread only.
   - For HTML→PDF use an offscreen `WKWebView` + `printOperation(with:)` + **`runModal(for:)`**, which paginated properly (8 pages). `createPDF` gives one tall page, and `op.run()` hung. (E)
9. **Quick Look gives only page 1 publicly.** `QLThumbnailGenerator` renders page 1 or slide 1 of docx, pptx and xlsx. There's no public multi-page API.
   - `qlmanage -p -o` still produces an HTML bundle for Office files on 27. Piping that through WebKit gave one PDF page per slide.
   - But qlmanage is a debug tool, so at most use it as a best-effort fallback. Real slide or spreadsheet rendering means the optional Office pack. (F)
10. **Video.**
    - VideoToolbox has hardware H.264, HEVC (also with alpha) and ProRes encoders. There is **no AV1 or VP9 encoder**.
    - **AV1 hardware decode exists only on M3 and later.** Bundle dav1d for M1/M2.
    - AVFoundation export writes only mov, mp4, m4v and m4a(-ish), so everything else goes through ffmpeg.
    - ffmpeg's `*_videotoolbox` encoders require hardware by default. `-q:v` works only on arm64 macOS, which suits Halo. (G)
11. **UTTypes.**
    - **`.srt` has no system UTI**, so declare an imported type; `.ass` and `.ssa` don't either.
    - `UTType(filenameExtension:)` returns the *single-file* iWork types and a *dynamic* type for `.rtfd`. Use `URL.resourceValues(.contentTypeKey)` and treat both iWork variants as one format. (H)
12. **Small things.**
    - Expect **no trackpad haptics** while Halo isn't active, which is the case during a Finder drag. The only workaround found is private.
    - AirDrop from an LSUIElement app needs an anchor window and activation; multi-file `canPerform` is true.
    - Open terminals with `NSWorkspace.open([folder], withApplicationAt:)`. Use `warp://action/new_window?path=` for Warp. Ghostty opens a *tab* by default.
    - With `SMAppService.mainApp`, always re-read `status`. (H)

---

## A. Drag and modifier detection from a background app while Finder owns the drag

### A1. Global mouse monitors (`.leftMouseDown/.leftMouseDragged/.leftMouseUp`)

- **Permission: none.**
  - The `addGlobalMonitorForEvents` doc and the SDK header (`NSEvent.h`) gate only key-related events: "Key-related events may only be monitored if accessibility is enabled or if your application is trusted for accessibility access."
  - WWDC19 session 701 describes the 10.15 gate as *keyboard* input monitoring.
  - Quinn (DTS): "You should, in general, be able to get mouse events without triggering this privacy restriction."
  - Locally, registration returned a non-nil token with no TCC grant. That only proves registration, not delivery.
- **Min macOS:** 10.6.
- **Delivery during another app's `NSDraggingSession`: yes in practice.** It is not documented. Shipping apps rely on it:
  - boring.notch's `DragDetector` uses global down, dragged and up monitors. It snapshots `NSPasteboard(name: .drag).changeCount` on mouse-down and compares it on each `leftMouseDragged`. Issue #884 shows it firing during Chrome drags on 15.6.1.
  - NotchDrop uses a global `leftMouseDragged` monitor.
  - Daisy uses the same pattern and claims it works "out of the box".
  - Perch polls `NSEvent.pressedMouseButtons` every 60 ms as a backstop and notes it "needs no Accessibility/Input Monitoring permission" (measured on 26.6).
- **Caveat:** `leftMouseDragged` events stop arriving when the pointer is still. A modifier tap with a stationary pointer produces no mouse event, so don't sample modifiers only inside the drag handler (A3).
- **Sources:** [addGlobalMonitorForEvents](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)), [WWDC19-701](https://developer.apple.com/videos/play/wwdc2019/701/), [forum 123797](https://developer.apple.com/forums/thread/123797), [boring.notch DragDetector](https://github.com/TheBoredTeam/boring.notch/blob/main/boringNotch/observers/DragDetector.swift), [boring.notch #884](https://github.com/TheBoredTeam/boring.notch/issues/884), [NotchDrop EventMonitors](https://github.com/Lakr233/NotchDrop/blob/main/NotchDrop/EventMonitors.swift), [Perch](https://github.com/hausfold/perch).
- **Confidence:** high for "no permission". Medium-high for delivery during a Finder drag (consistent practice; unverified here because no input could be synthesised).

### A2. Global `.flagsChanged` and `.keyDown` monitors

- **`.keyDown` global monitor: needs a grant.**
  - Quinn: an NSEvent global key monitor "requires the Accessibility privilege".
  - A tested report (viskly PR #3, macOS 26.4.1, TCC reset with `tccutil`) found that a global `keyDown` monitor "delivers nothing without Input Monitoring".
  - So assume Accessibility or Input Monitoring is needed. Sources: [forum 707680](https://developer.apple.com/forums/thread/707680), [forum 789896](https://developer.apple.com/forums/thread/789896), [viskly #3](https://github.com/viskly/viskly/pull/3).
  - **Confidence:** high.
- **`.flagsChanged` global monitor: contested. Don't build on it.**
  - **For working without permission:** viskly PR #3 claims a tested result on macOS 26.4.1 (Apple silicon, Developer ID, TCC reset): a global `flagsChanged` monitor for a right-⌘ shortcut worked "with only the microphone granted", needing "no consent".
  - **Against:** pladder #12 says global NSEvent monitors "including `flagsChanged`" need Accessibility or Input Monitoring; this is a claim, not a test. Icey #40 treats `flagsChanged` from other apps as unreliable "without Accessibility, or while secure input is on". A review comment in vorssaint-utils #2983 says untrusted processes don't get it. Apple's doc wording ("key-related events") arguably covers it.
  - Sources: [pladder #12](https://github.com/dinooo13/pladder/issues/12), [icey #40](https://github.com/leonardovida/icey/pull/40), [vorssaint-utils #2983](https://github.com/vorssaint/vorssaint-utils/pull/2983).
  - **Min macOS:** 10.6.
  - **Confidence:** low. It may differ between 13, 14, 15 and 26, and with secure input. DragProbe must test it on a TCC-clean account on 13 and on current macOS.

### A3. Polling `NSEvent.modifierFlags`, `pressedMouseButtons`, `mouseLocation` and `CGEventSource` state

- **`NSEvent.modifierFlags` (class), `NSEvent.pressedMouseButtons`, `NSEvent.mouseLocation`: no permission. They are live during another app's drag.**
  - The docs say `modifierFlags` and `pressedMouseButtons` report "the state of devices combined with synthesized events at the moment, independent of which events have been delivered". `mouseLocation` is reported "regardless of the current event or pending events".
  - Real-world:
    - AeroSpace PR #2271: "Polling `NSEvent.modifierFlags`… Works without Accessibility".
    - Daisy reads `NSEvent.modifierFlags.contains(.shift)` inside its global drag handler.
    - Perch polls `pressedMouseButtons` with no permission.
  - Locally all three returned values with no grant (0, 0, a valid point). Live values couldn't be checked because no keys could be pressed.
  - **Min macOS:** 10.6.
  - **Confidence:** high for "no permission". Medium-high for "live mid-drag" (documented semantics plus practice).
  - Sources: [modifierFlags](https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.type.property), [pressedMouseButtons](https://developer.apple.com/documentation/appkit/nsevent/pressedmousebuttons), [mouseLocation](https://developer.apple.com/documentation/appkit/nsevent/mouselocation), [AeroSpace #2271](https://github.com/nikitabobko/AeroSpace/pull/2271).
- **`CGEventSource.flagsState(.combinedSessionState)`, `buttonState`:** these returned values locally without a grant. No doc mentions permission.
  - **Min macOS:** 10.4.
  - **Confidence:** medium.
- **`CGEventSource.keyState(_:key:)`:** this one **is gated for ordinary keys.**
  - SlowQuitApps #32 (Mojave): `keyState(kVK_ANSI_Q)` returned false while Q was held, while ⌘ (keycode 55) read true. Granting Accessibility fixed it.
  - So modifiers appear ungated and letter keys gated. Since 10.15 the gate is presumably Input Monitoring; that part is inferred.
  - Source: [SlowQuitApps #32](https://github.com/dteoh/SlowQuitApps/issues/32).
  - **Confidence:** medium.
- **Secure input** (a focused password field, some terminals): key and modifier events to other processes may be suppressed. It's unknown whether `modifierFlags` polling is affected. Test it.
- **Recommended design for DragSense.** While a drag is live:
  - Run a **120 Hz `DispatchSourceTimer`** that samples `NSEvent.modifierFlags` and `NSEvent.pressedMouseButtons`. The drag is live from the `changeCount` bump with the button down until `pressedMouseButtons == 0` or a global `leftMouseUp`.
  - Detect a *tap* as a press and release of exactly one of ⇧/⌘/⌃ within roughly 300 ms, with no other modifier involved.
  - Sampling at 8 ms keeps the tap-to-visible budget well under the 50 ms target.
  - Use a global `flagsChanged` monitor only as an opportunistic low-latency path if DragProbe shows it works.

### A4. CGEventTap and TCC

| Tap | TCC | API to check or request | Min macOS | Confidence |
|---|---|---|---|---|
| Listen-only (`.listenOnly`), session or annotated-session level, with **key** events | **Input Monitoring** (`kTCCServiceListenEvent`). An Accessibility grant also satisfies it. | `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()`, or `IOHIDCheckAccess` / `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` | 10.15 | high |
| Active / modifying (`.defaultTap`), which can swallow events (e.g. Return) | **Accessibility** | `AXIsProcessTrustedWithOptions`; `CGPreflightPostEventAccess()` / `CGRequestPostEventAccess()` (10.15) cover *posting* | 10.15 (gate) | high |
| Listen-only, **mouse-only** mask | **Not documented.** The `tapCreate` doc says only key up/down need assistive access, and that disallowed bits are cleared from the mask (NULL if it ends up empty). No authoritative report either way. Not tested here, to avoid raising a TCC prompt on the user's screen. | — | — | low |

Notes:

- WWDC19-701: "a listen-only event requires authorization for input monitoring, a modifying event app requires authorization for accessibility features."
- DTS (2026): Accessibility "specifically grants both 'post' and 'listen'".
- Revoking Accessibility while an active tap is live can freeze input ([forum 735204](https://developer.apple.com/forums/thread/735204)). Always handle `tapDisabledByTimeout/ByUserInput` and re-check trust.
- The header still says HID-level taps need root.
- Sources: [tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)), [forum 122492](https://developer.apple.com/forums/thread/122492), [forum 828052](https://developer.apple.com/forums/thread/828052), [forum 679303](https://developer.apple.com/forums/thread/679303), [CGPreflightPostEventAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()). Local SDK: `CGEvent.h` lines 398–408.

**Carbon `RegisterEventHotKey` (global hotkey):** **no permission**, works in the sandbox, and is still functional ([KeyboardShortcuts FAQ](https://github.com/sindresorhus/KeyboardShortcuts): "Does this package cause any permission dialogs? No."). This is the permission-free fallback trigger that BUILD.md's hard-stop rule calls for. Two constraints:

- It needs a non-modifier key, so it can't do a modifier tap.
- **From macOS 15, Option-only and Option+Shift-only combinations are refused for sandboxed apps**; non-sandboxed apps reportedly keep working ([Shottr KB](https://shottr.cc/kb/sequoia)). Include ⌘ or ⌃ in defaults anyway.

**Confidence:** high.

### A5. The drag pasteboard (`NSPasteboard(name: .drag)`, 10.13+)

- **Cross-process read: yes, with no permission.**
  - Locally (no grants), the drag pasteboard reported `changeCount 56` and 1 item with the types from the user's last drag (an image dragged from a Chromium-based browser): `public.url`, `public.url-name`, `public.jpeg`, `com.apple.pasteboard.promised-file-url`, `com.apple.pasteboard.promised-file-content-type`, plus browser-private types.
  - The pattern "changeCount differs from the mouse-down snapshot ⇒ a real drag session started" is what boring.notch and Daisy ship. Daisy also notes the source "writes the pasteboard a few events into the drag", so re-check on every dragged event and timer tick, not just the first.
  - A boring.notch PR (#1233) claimed changeCount stopped bumping on 14+ and was **retracted** ("a reinstall resolves the symptom").
  - Confidence: high for the read, medium-high for the bump.
- **Pasteboard privacy (15.4+):** it does **not** apply. The SDK header for `NSPasteboard.AccessBehavior` says: "The default behavior for the General pasteboard is to ask upon programmatic access. **All other pasteboards default to always allow access.**" Locally, `accessBehavior` was `.alwaysAllow` (2) for the drag pasteboard. Sources: [AccessBehavior](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum), [mjtsai](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4). **Confidence:** high.
- **Reading file URLs mid-drag:** works in practice for **Finder drags**, which carry `public.file-url` items. It isn't documented.
  - Halo needs it **before** the drop, because the wheel shows only formats valid for the dragged files.
  - Halo isn't sandboxed, so the sandbox-extension pitfall (peeking at URLs before the drop can stop a sandboxed app getting its extension; [Wade Tregaskis](https://wadetregaskis.com/mac-app-sandboxing-interferes-with-drag-drop/)) doesn't apply. Still, read only `fileURL` items: lazily provided types call back into the source app.
  - **Confidence:** medium. DragProbe must confirm `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])` mid-drag for Desktop, list view, Spotlight and Stage Manager sources.
- **File promises** come from Mail attachments, Photos, Safari/Chrome image drags, the Screenshot thumbnail and many Electron apps.
  - Modern types (SDK `HIServices/Pasteboard.h`): `com.apple.pasteboard.promised-file-url` (`kPasteboardTypeFileURLPromise`) and `com.apple.pasteboard.promised-file-content-type` (`kPasteboardTypeFilePromiseContent`). The legacy `NSFilesPromisePboardType` is deprecated (10.0–10.14).
  - Don't hard-code strings. Register `NSFilePromiseReceiver.readableDraggedTypes`.
  - **Mid-drag you only get the promised content type(s), not files.** That's enough to pick the wheel's formats, but the file only exists after the drop.
  - `NSFilePromiseReceiver` (10.12+). `receivePromisedFiles(atDestination:options:operationQueue:reader:)` "effectively calls in the promises", so call it **only in `performDragOperation`, as the drop target**.
  - Use one destination for all receivers. `fileNames` is empty until then, and the reader can return an error.
  - Handle promises before plain URLs. Apple's sample lists Safari images, Photos and Mail as promise sources.
  - Known real-world failures: Mail/Spark attachments silently dropped (boring.notch #1299, #1301); Outlook "file not found" (#1044).
  - Sources: [Apple: Supporting drag and drop through file promises](https://developer.apple.com/documentation/appkit/supporting-drag-and-drop-through-file-promises), [boring.notch #1299](https://github.com/TheBoredTeam/boring.notch/issues/1299).
  - **Confidence:** high for the API. Medium for per-app behaviour.
  - `com.apple.NSFilePromiseItemMetaData` was not verified as a current type.

### A6. A non-activating panel as a mid-drag drop target

- **Works in shipping apps with no permission.**
  - Perch: `[.borderless, .nonactivatingPanel]`, level `.statusBar`, `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `orderFrontRegardless()`. It accepts Finder drops with no permission.
  - NotchDrop: level `.statusBar + 8`.
  - boring.notch uses a **private** SkyLight/CGSSpace window. That is **off-limits**.
  - Sources: [Perch ARCHITECTURE.md](https://github.com/hausfold/perch/blob/main/ARCHITECTURE.md), [NotchWindow.swift](https://github.com/Lakr233/NotchDrop/blob/main/NotchDrop/NotchWindow.swift).
  - **Confidence:** medium-high.
- **Gotchas found in Perch's source:**
  1. **Fully transparent pixels are click-through and "never receive draggingEntered".** Fill the wheel's background, including the centre "cancel" disc, with at least alpha ≈ 0.005.
  2. With SwiftUI content, `Color.clear` needs `.contentShape`, or `NSHostingView.hitTest` returns nil and the drag never routes to it. Halo's wheel is AppKit, so make `hitTest` return the view across the whole ring.
  3. Don't set `ignoresMouseEvents = true` on the drop window.
  4. Call `registerForDraggedTypes` *before* ordering the panel in.
- **Appearing under a stationary cursor: undocumented, with no reports either way.**
  - The window server picks the destination as the drag moves. Once you *are* the destination, `draggingUpdated` is periodic by default (`wantsPeriodicDraggingUpdates`) and is re-sent "when the mouse moves or a modifier flag changes".
  - For Halo this barely matters: the wheel opens centred on the pointer (the cancel zone), and choosing a segment requires a move, which fires `draggingEntered`.
  - DragProbe should still log whether `draggingEntered` arrives without a move, so that "drop immediately on the centre = cancel" works.
  - **Confidence:** low.
- **Use the destination callbacks once inside.** Use `draggingUpdated(_:)` location for segment hit-testing, and `draggingSourceOperationMask` / `NSEvent.modifierFlags` for modifier changes while hovering. Return `.copy` (never `.move`) so Finder leaves the original alone.
- **Window levels** (local `CGWindowLevelForKey`):

| Window | Level |
|---|---|
| normal | 0 |
| floating | 3 |
| Dock | 20 |
| main menu | 24 |
| status (`.statusBar`) | 25 |
| `.popUpMenu` | 101 |
| overlay | 102 |
| help | 200 |
| **dragging image** | **500** |
| `.screenSaver` | 1000 |
| assistiveTechHigh | 1500 |
| shielding | 2147483628 |

  - **Use `.popUpMenu` (101), or anything from `.statusBar` (25) up to 499.** That clears the Dock and menu bar, and the dragged file's image stays drawn *above* the wheel.
  - `.screenSaver` would cover the drag image. Inferred: the drag image window is at 500.
- **Spaces, full screen, Stage Manager, Mission Control:**
  - `.fullScreenAuxiliary` (10.7) lets the panel appear over a full-screen app's space.
  - `.canJoinAllSpaces` follows Space switches. `.stationary` keeps Mission Control from moving it. `.ignoresCycle` keeps it out of ⌘`.
  - `.canJoinAllApplications` (13.0) keeps a window out of Stage Manager's layout but lets it join other apps' full-screen spaces. Apple says not to combine it with `.primary`/`.auxiliary`.
  - **Mission Control's "drag windows to top of screen"** (macOS 15+) arms for *any* drag near the top edge and "runs above every window level". Keep the wheel's hit zones out of the top band. When there's no room, shift the wheel down rather than centring it on the pointer.
  - Sources: [canJoinAllApplications](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications), Perch `MissionControlCheck.swift`.
  - **Confidence:** medium.

### A7. A public "drag started/ended" signal

- **None exists.**
  - `NSDraggingSession` and its source callbacks only cover drags *your* app starts.
  - There's no distributed notification, and forum questions asking for one got no Apple answer ([672010](https://developer.apple.com/forums/thread/672010), [767615](https://developer.apple.com/forums/thread/767615)).
- **Off-limits (private or undocumented):** SkyLight/CGS window and space calls, the `com.apple.dock.prefchanged` distributed notification, Dock preference keys, and the `MTActuator` haptics. Window-titlebar drag notifications seen in Wine sources relate to titlebar drags, not file drags.
- **The permission-free building blocks** are:
  - global mouse monitors;
  - `NSPasteboard(name: .drag).changeCount` plus `types`;
  - polling of `pressedMouseButtons`, `modifierFlags` and `mouseLocation`.
- **Confidence:** high.

**Section A bottom line:** mid-drag detection with **zero TCC permissions** looks feasible with public API: a mouse monitor, plus the drag-pasteboard changeCount, plus polling modifierFlags at 120 Hz. That keeps it within BUILD.md's hard-stop rule. The three facts DragProbe must confirm on real hardware are:

1. Global `leftMouseDragged` and `leftMouseUp` arrive during a Finder drag.
2. `modifierFlags` is live mid-drag.
3. The panel receives `draggingEntered` and `performDragOperation`.

The `flagsChanged` monitor is a bonus if it turns out to work.

---

## B. Reading the Finder selection ("Enter opens the wheel")

| Route | Permission | Works for | Min macOS | Confidence |
|---|---|---|---|---|
| **Apple Events:** `tell application "Finder" to get selection` (NSAppleScript, or `NSAppleEventDescriptor` / `AESendMessage`) | **Automation consent** for Finder (TCC `kTCCServiceAppleEvents`), prompted on first send. Needs `NSAppleEventsUsageDescription` in Info.plist (10.14+); without it, sends fail. Under the hardened runtime it also needs the **`com.apple.security.automation.apple-events`** entitlement (failures surface as -1744 then -1743). Not needed for events to yourself or same-team apps. Halo isn't sandboxed, so `scripting-targets` doesn't matter: Finder's sdef only publishes the `com.apple.finder.trash` access group, so a sandboxed app couldn't use it for `selection` anyway. | Every Finder view and the Desktop. Finder's notion of selection is authoritative. Returns `«class docf»`/alias items; ask for `POSIX path of (item as alias)`, or use `selection as alias list`. | 10.14 for the consent model | high |
| Preflight: `AEDeterminePermissionToAutomateTarget(target, typeWildCard, typeWildCard, askUserIfNeeded)` | — | Returns `noErr`, `errAEEventNotPermitted` (-1743), `errAEEventWouldRequireUserConsent` (-1744, with `false`) or `procNotFound`. Even after the user denies, `false` keeps returning -1744, so it **can't silently detect "denied"**. The header says don't call it on the main thread. | 10.14 | high |
| **Accessibility API:** `AXUIElementCreateApplication(finderPID)` → focused window → `AXSelectedChildren` / `AXSelectedRows` → `AXURL` / `AXFilename` | **Accessibility** (`AXIsProcessTrusted`) | Undocumented per view. One report says icon-view items and list-view rows expose selection. In file dialogs `AXURL` showed up as `file:///.file/id=…` reference URLs, which need resolving. The Desktop is a separate AX element tree. Column and gallery views are unverified. Couldn't test locally (not trusted). | — | low |
| **Services menu** (`NSServices` with `NSSendFileTypes` such as `public.item`/`public.folder`, plus `NSMessage`, `NSPortName`, `NSRequiredContext`) | **None.** Finder puts the selected file URLs on a private pasteboard and calls your provider (`NSApp.servicesProvider`). | Every Finder view and the Desktop, via the right-click **Services/Quick Actions** submenu, the Finder > Services menu, or a **keyboard shortcut the user assigns** in System Settings > Keyboard > Keyboard Shortcuts > Services > Files and Folders. Terminal ships exactly this ("New Terminal at Folder", `NSSendFileTypes` `public.directory`), and on macOS 27 `pbs -dump_pboard` still lists it. | 10.0 (`NSRequiredContext` 10.6) | high |
| Finder Sync extension (`FIFinderSyncController.default().selectedItemURLs()`) | None, but the user must enable the extension in System Settings > Extensions. It's an app extension, so it's sandboxed. | **Only valid inside `menu(for:)` or its actions.** It returns nil outside the extension's monitored directories, for example from a toolbar click. That's good for a "Convert with Halo" context menu, but **not** for a keyboard trigger. ([doc](https://developer.apple.com/documentation/findersync/fifindersynccontroller/selecteditemurls())) | 10.10 | high |
| **Intercepting Return in Finder** | **Accessibility.** Swallowing Return before Finder sees it needs an active `.defaultTap` CGEventTap; posting needs PostEvent, which lives in the Accessibility pane. A listen-only tap (Input Monitoring) can *see* Return but not stop it, so Finder would still start a rename. A global `keyDown` NSEvent monitor needs a grant and can't swallow either. | Confirmed: `tapCreate` doc; Quinn [707680](https://developer.apple.com/forums/thread/707680); [735204](https://developer.apple.com/forums/thread/735204) (revoking Accessibility under a live tap can block input). | 10.15 (TCC split) | high |

**Services details** (Apple's Services Implementation Guide, SysServices "properties", "providing" and "overview" articles):

- **Include `NSRequiredContext`, even an empty dictionary.** "Otherwise the system registers your service, but does not automatically present it." Non-contextual services are off by default (10.6 AppKit notes).
- **Default shortcut:** `NSKeyEquivalent` is one character used with ⌘ (uppercase adds ⇧). The user can override it. It can't be plain Return.
- **Launch:** "If the service provider is not currently running, it is automatically launched."
  - Service launches set `NSApplicationLaunchIsDefaultLaunchKey = false`, so don't open UI for a default launch then.
  - On macOS 27 the service request can arrive after `applicationDidBecomeActive` ([ghostty #14412](https://github.com/ghostty-org/ghostty/issues/14412)).
- **Cache refresh:** call `NSUpdateDynamicServices()` after install. `/System/Library/CoreServices/pbs -update` and `-flush` still exist on macOS 27 and are for debugging only. Debug a missing entry with `-NSDebugServices <bundle-id>`.
- **LSUIElement apps** can be providers (e.g. ServiceLLM ships 7 services as an accessory app).
- **Confidence:** high for the mechanics. Medium for enable-by-default behaviour on 13–27, so test with a fresh user.
- **Sources:** [Services properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html), [providing](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html), [overview](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/overview.html), [NSAppleEventsUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription), [apple-events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), [forum 130949](https://developer.apple.com/forums/thread/130949), [QA1888](https://developer.apple.com/library/archive/qa/qa1888/_index.html), [mjtsai on AEDeterminePermission](https://mjtsai.com/blog/2018/08/31/aedeterminepermissiontoautomatetarget-added-but-aepocalyse-still-looms/), [AX report](https://github.com/can1357/oh-my-pi/pull/15282), [KM forum](https://forum.keyboardmaestro.com/t/how-do-i-run-script-on-selected-file-in-file-open-dialog/10039), [ServiceLLM](https://github.com/9t29zhmwdh-coder/ServiceLLM).

**What this means for "Enter on a selected Finder file":** exact Tangerine parity, where plain Return in Finder opens the wheel *instead of* renaming, needs **Accessibility** (to swallow Return) **plus Automation for Finder** (to read the selection). That's two prompts, so make it an opt-in "Power mode".

The zero-permission default is:

- a **Services entry** "Open Halo Wheel" (`NSSendFileTypes` = `public.item`, `NSRequiredContext` = `{}`), with a suggested ⌘-based shortcut the user can rebind in System Settings;
- plus a permission-free Carbon hotkey (A4) that opens the wheel at the pointer for drop-onto-ring.

Both work on 13+ with no TCC grant.

**A rejected hack.** Registering a modifier-less Carbon hotkey for Return only while Finder is frontmost would swallow Return with no permission. It would also break rename-commit, the Finder search field and sheets, because without AX you can't tell whether a text field has focus. And the selection still needs Automation. Not recommended.

**Inference (low confidence):** BUILD.md cites Tangerine's App Store listing, so it is sandboxed. A sandboxed app can't get an active event tap or AX control of Finder, so Tangerine probably uses a listen-only tap (Input Monitoring) plus some selection source. Verify on a clean account if it matters.

---

## C. ImageIO encode support by macOS version

**Output of `CGImageDestinationCopyTypeIdentifiers()` on this machine (macOS 27.0.1), 22 types:**

```
com.adobe.pdf, com.adobe.photoshop-image, com.apple.atx, com.apple.icns, com.compuserve.gif,
com.ilm.openexr-image, com.microsoft.bmp, com.microsoft.dds, com.microsoft.ico,
com.truevision.tga-image, org.khronos.astc, org.khronos.ktx, org.khronos.ktx2, public.avif,
public.heic, public.heics, public.jpeg, public.jpeg-2000, public.pbm, public.png, public.pvr, public.tiff
```

`CGImageSourceCopyTypeIdentifiers()` returned 62 decodable types, including `org.webmproject.webp`, `public.jpeg-xl`, `public.avif`, `public.avis`, `public.heic`, `public.heif`, `public.avci`, `org.nema.dicom` and about 30 camera RAW types.

Real encodes of a 64×64 RGBA image with half-transparent pixels:

| UTI | `CGImageDestinationCreateWithData` | Result |
|---|---|---|
| `public.avif` | OK | 568 B. It round-trips and keeps alpha. |
| `public.heic` | OK | 785 B. It round-trips and keeps alpha. |
| `org.webmproject.webp` | **nil** | No encoder. |
| `public.jpeg-xl` | **nil** | No encoder. |

| Format | Encode 13 | Encode 14 | Encode 15 | Encode 26 / 27 | Decode since | Confidence |
|---|---|---|---|---|---|---|
| HEIC (`public.heic`) | yes | yes | yes | yes | 10.13 | high |
| AVIF (`public.avif`) | **unverified** | **unverified** | **unverified** | yes (26.5 third-party probe, 27.0.1 local) | 13.0 (still images, Safari 16 / Ventura) | encode before 26: low |
| WebP | no | no | no | no (27.0.1 local) | 11.0 (`kCGImagePropertyWebPDictionary` is `IMAGEIO_AVAILABLE_STARTING(11.0, 14.0)`) | high |
| JPEG XL | no | no | no | no (27.0.1 local) | 14.0 (Safari 17 / Sonoma) | high for "no encode", medium for decode-since-14 |

Notes:

- **AVIF encode.** Apple doesn't document when it arrived. There is no `UTType.avif` constant in the SDK (use `UTType("public.avif")`); the SDK has `UTTypeWebP`, and `UTTypeJPEGXL` is marked `API_AVAILABLE(macos(15.2))`. Third-party sources disagree:
  - Nuke's docs say AVIF encoding is "only available on recent OS versions", and its code checks at runtime.
  - The `kompressor` docs claim iOS 16+, without evidence.
  - AnyDoor's research note records a successful HEIC and AVIF encode with alpha on macOS 26.5.
  
  **Gate it at runtime:** check `CGImageDestinationCopyTypeIdentifiers().contains("public.avif")`. If it's missing, fall back to the bundled ffmpeg (libaom or SVT-AV1) or libavif, and test on a real macOS 13, 14 and 15 machine before calling it native. (Sources: [Nuke supported formats](https://github.com/kean/Nuke/blob/main/Documentation/Nuke.docc/Customization/ImageFormats/supported-image-formats.md), [kompressor format-support](https://github.com/cracknco/kompressor/blob/main/docs/format-support.md), [AnyDoor probe note](https://github.com/ZingerLittleBee/AnyDoor/blob/main/docs/research/2026-07-10-image-target-size-compression-market-research.md), [Safari 16 / AVIF](https://webkit.org/blog/13152/webkit-features-in-safari-16-0/), [Safari 16.1 release notes](https://developer.apple.com/documentation/safari-release-notes/safari-16_1-release-notes))
- **WebP encode.** ImageIO has never had one; Nuke states that `isSupported(.webp)` is false on every platform. Halo needs libwebp (`cwebp`) or ffmpeg's `libwebp` for WebP output. High confidence.
- **JPEG XL.** Decode only, from macOS 14 (Safari 17 / Sonoma per the [WebKit WWDC23 post](https://webkit.org/blog/14205/news-from-wwdc23-webkit-features-in-safari-17-beta/) and [STP 173 notes](https://webkit.org/blog/14378/release-notes-for-safari-technology-preview-173/)). JPEG XL output would need libjxl. It isn't in BUILD.md's output list, so skip it.
- **HEIC encode and hardware.** Every Apple silicon Mac has the HEVC hardware encoder: VideoToolbox lists `com.apple.videotoolbox.videoencoder.ave.hevc` with `hw=true`, and there is also a software HEVC encoder (`hevc.vcp`). On arm64-only Halo there's no hardware caveat. The only reported HEIC-encode breakage is the iOS 17.5 Simulator ([forum 755470](https://developer.apple.com/forums/thread/755470)), which doesn't matter for a Mac app. High confidence.
- **Alpha and backgrounds.** For destinations that can't hold alpha (JPEG), ImageIO composites onto `kCGImageDestinationBackgroundColor`, which defaults to white. HEIC and AVIF keep alpha (verified here and in AnyDoor's 26.5 probe).
- **Metadata.** AnyDoor reports that on 26.5 `CGImageDestinationCopyImageSource` refuses lossless metadata edits for AVIF, and silently fails to strip GPS from HEIC. So "strip metadata" has to re-encode for those two formats. Medium confidence.
- **SVG input.** ImageIO can't decode SVG (`public.svg-image` is in neither list). Keep resvg, as BUILD.md plans.

---

## D. Vision for background removal (macOS 13 floor)

Availability comes from the MacOSX27.0 SDK headers, which state Apple's own minimums, and from Apple docs. The runtime results come from a synthetic 640×480 image (two flat-colour shapes on grey) on macOS 27.

| API | Min macOS | Notes | Confidence |
|---|---|---|---|
| `VNGenerateForegroundInstanceMaskRequest` (ObjC-style) | **14.0** | `API_AVAILABLE(macos(14.0))`; `VNInstanceMaskObservation` 14.0; `generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)` and `generateScaledMaskForImage(forInstances:from:)` are on the observation. Local run: 2 instances found, BGRA masked image at full resolution, 192 ms first call. This is the "lift subject" quality path. | high |
| `GenerateForegroundInstanceMaskRequest` (Swift-native struct) | **15.0** | `@available(macOS 15.0, …)` in `Vision.swiftinterface`. It's the same model with an async API. | high |
| `VNGeneratePersonSegmentationRequest` | **12.0** | People only, with `.fast/.balanced/.accurate` quality levels; `supportedOutputPixelFormats` is 15.0. Local `.balanced` run: 734 ms. On macOS 13 it's the only built-in segmentation, and it only works for portraits. | high |
| `VNGeneratePersonInstanceMaskRequest` | **14.0** | Up to 4 people as separate instances. | high |
| VisionKit `ImageAnalysisOverlayView` | 13.0 | Live Text overlay. | high |
| `ImageAnalysisOverlayView.subjects` / `image(for:)` (subject lifting) | **14.0** | Per Apple docs ([subjects](https://developer.apple.com/documentation/visionkit/imageanalysisoverlayview/subjects)). It needs a view; Vision is the cleaner route for batch work. | high |
| `VNGenerateObjectnessBasedSaliencyImageRequest` / `VNGenerateAttentionBasedSaliencyImageRequest` | 10.15 (revision 2 is 14.0) | Returns a **68×68** float heat map plus `salientObjects` bounding boxes (2 found locally). Too coarse to use as a cut-out mask. At best it's a crop or bounding-box hint, or a seed for your own GrabCut-style refinement. | high (availability), medium (usefulness) |
| `VNDetectBarcodesRequest` | 10.13 | Revision 3 is 13.0. Revision 4 is 14.0 and is now the default (it adds MSI Plessey, inverted colours and supplemental payloads). `supportedSymbologies()` 12.0. Symbologies: Aztec, Code39 (+checksum, fullASCII), Code93(i), Code128, DataMatrix, EAN8/13, I2of5(+checksum), ITF14, PDF417, QR, UPCE (all 10.13); Codabar, GS1DataBar (+Expanded, Limited), MicroPDF417, MicroQR (12.0); MSIPlessey (14.0). The local run listed all 24. | high |

**Background removal on macOS 13.** Nothing built-in works on arbitrary subjects. The realistic options are:

1. People only: `VNGeneratePersonSegmentationRequest` with `.accurate`.
2. Hide or grey out "Remove background" on 13.x for non-people images, with the label "Requires macOS 14".
3. Bundle a small Core ML matting model, for example a U²-Net or RMBG-class model. Check the licence: several are non-commercial, which conflicts with AGPL distribution.

Saliency isn't a usable mask. Source headers: `Vision.framework/Headers/VNGenerateForegroundInstanceMaskRequest.h`, `VNGeneratePersonSegmentationRequest.h`, `VNTypes.h`, `VNDetectBarcodesRequest.h`.

Also available:

- Core Image `CIFilter.personSegmentation()`: 12.0, people only, same model as the Vision request.
- No general-purpose "subject lift" `CIFilter` exists.
- Apple's JSON docs agree with the headers, e.g. [VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest), [VNInstanceMaskObservation](https://developer.apple.com/documentation/vision/vninstancemaskobservation), [GenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest), [VNGeneratePersonSegmentationRequest](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest), [VNDetectBarcodesRequestRevision3](https://developer.apple.com/documentation/vision/vndetectbarcodesrequestrevision3) (13.0, not 12), [Revision4](https://developer.apple.com/documentation/vision/vndetectbarcodesrequestrevision4), [saliency (Kodeco)](https://www.kodeco.com/5807038-saliency-analysis-in-ios-using-vision).

---

## E. AppKit document conversion

### NSAttributedString document types

All are in `AppKit/NSAttributedString.h`. `NSOfficeOpenXMLTextDocumentType` (.docx) and `NSOpenDocumentTextDocumentType` (.odt) have been there since 10.5. `docFormat` (.doc, Word 97 binary), `wordML` (Word 2003 XML), `webArchive`, `rtf`, `rtfd` and `html` are long-standing and macOS-only, except rtf, rtfd and html. All are available on 13+. There is no reader or writer for **.pages** or **.epub**.

**Round-trip test (macOS 27).** The source contained a heading, bold text, a link, a 2-item `NSTextList`, a 2×2 `NSTextTable` and a PNG `NSTextAttachment`. I wrote it with `data(from:documentAttributes:)` (`fileWrapper(from:)` for RTFD) and read it back with `NSAttributedString(url:)`:

| Written as | Image | List | Table | Link | Notes |
|---|---|---|---|---|---|
| docx | **lost** | **lost** (bullets written as literal `\t•\t` text) | **lost** (cells written as plain paragraphs, no `<w:tbl>`) | **lost** | The writer emits no `word/media` part. I checked by unzipping `document.xml`. |
| odt | lost | kept | kept | kept | |
| doc | lost | lost | kept | lost | |
| wordML (.xml) | lost | lost | lost | lost | |
| rtf | lost (expected, RTF can't embed) | kept | kept | kept | |
| rtfd | kept | kept | kept | kept | |
| html | kept (written as a sibling file) | kept | kept | kept | |
| webarchive | kept | kept | kept | kept | |

**Reading a real-structure docx.** I hand-built the file with `w:tbl`, `w:numPr` numbering and an inline `w:drawing` PNG. Results: the **table was kept**, the **list was kept** (but the decimal numbering came back as a bullet marker), and the **image was dropped**.

Conclusions:

- `textutil` and NSAttributedString are fine for text-heavy DOCX↔RTF/TXT/HTML/ODT.
- They are **not** acceptable as Halo's DOCX writer: it drops tables, lists and images.
- DOCX import loses images.

Use pandoc for DOCX/ODT/EPUB/MD output, as BUILD.md already plans. Keep `textutil` and NSAttributedString for RTF, RTFD, TXT and `.textClipping` text, and for quick DOCX→TXT.

Gotchas:

- `fileWrapper(from:documentAttributes:)` returned a **directory** wrapper for docx, odt and html once an attachment was present. Use `data(from:documentAttributes:)` for single-file formats.
- The HTML importer must run on the **main thread**. On a background thread it "tries to synchronize with the main thread, fails, and times out". Even on main it can time out on external resources, and Apple says it's meant for markdown-like styling, "not for general HTML import" ([Apple docs](https://developer.apple.com/documentation/foundation/nsattributedstring/init(data:options:documentattributes:))). For HTML→PDF use WebKit instead.

Confidence: high for these tests. Fidelity on complex real-world Word files will be worse, not better.

### HTML → paginated PDF

Tested on macOS 27 with 120 paragraphs, a CSS `page-break-before: always` section and a table:

| Method | Min macOS | Result |
|---|---|---|
| `WKWebView.createPDF(configuration:)` (`WKPDFConfiguration` 10.15.4, `createPDF` 11.0, `allowTransparentBackground` 14.0) | 11.0 | **1 page, 783×5912 pt.** One tall page with no pagination; CSS page breaks are ignored. |
| `WKWebView.printOperation(with:)` + `NSPrintInfo(jobDisposition: .save, jobSavingURL:)` + **`runModal(for:delegate:didRun:contextInfo:)`** with the web view in an offscreen borderless window | 11.0 | **8 pages, 612×792 (US Letter).** Margins applied and `page-break-before` honoured. This is the method that paginates properly. |
| Same, but `op.run()` and no window | 11.0 | **Hung** (killed after 40 s). This matches [forum 705138](https://developer.apple.com/forums/thread/705138), where `runOperation` gives blank pages and the fix is the modal-for-window variant without showing a sheet. Also set `op.view?.frame` or it can crash. See also [forum 803249](https://developer.apple.com/forums/thread/803249). |
| `NSTextView` + `NSPrintOperation(view:printInfo:)` + `op.run()` (no window) | any | Works synchronously: a 64× repeated docx body came to 14 pages. It's good for RTF/DOCX→PDF without WebKit, with NSAttributedString's fidelity limits. |
| `WebPage.exported(as: .pdf(region:))` (SwiftUI WebKit) | 26.0 | Region or contents export, so still a single "page". It doesn't help with pagination. |

**Recommendation.** Use one offscreen `WKWebView` in a hidden borderless `NSWindow`, wait for `didFinish`, then call `printOperation(with:)` and `runModal(for:)`. Paper size, margins and `horizontalPagination = .fit` come from `NSPrintInfo`; CSS `@page` and `break-before` both work. Confidence: high (tested). Variation between macOS versions is untested; the third-party [macmyths note](https://macmyths.com/convert-a-webpage-to-pdf-with-webkit-on-macos/) warns about it.

---

## F. Quick Look

| Question | Answer | Min macOS | Confidence |
|---|---|---|---|
| Does `qlmanage -p -o <dir> file` still produce an HTML preview bundle for Office files? | **Yes, on macOS 27.0.1.** `tu.docx` (made by `textutil -convert docx`), a hand-built `real.docx`, a hand-built 3-slide `min.pptx`, `font.xlsx`, `blank.xls` and `elegant.dotx` each printed `produced a preview with data of type public.html` and wrote `<name>.qlpreview/{Preview.html, PreviewProperties.plist, Attachment1.png/.css}`. `real.docx` came out with a real `<table>` and `<img src="Attachment1.png">`; `min.pptx` came out with 3 `<div class="slide">`. | long-standing; checked on 27 | high (tested) |
| Which component does it? | Apple's own legacy generators are still in `/System/Library/QuickLook/`. `Office.qlgenerator` handles docx, doc, dotx, pptx, ppt, pps, pot, xlsx, xls, xlt and csv. `iWork.qlgenerator` handles pages, key and numbers, plus their templates and sff variants. odt goes to `Text.qlgenerator`. Apple's generators still run, but **third-party `.qlgenerator` plug-ins stopped working in macOS 15** ([Eclectic Light](https://eclecticlight.co/2024/10/31/how-sequoia-has-changed-quicklook-and-its-thumbnails/), [mjtsai](https://mjtsai.com/blog/2024/11/05/sequoia-no-longer-supports-quicklook-generator-plug-ins/)). | 15.0 removal for third-party | high |
| iWork | Not tested with a real file: no real .pages/.key/.numbers was on the machine, and `SampleDocument.numbers` in the Numbers bundle is a 2011 stub that "did not produce any preview". iWork packages carry embedded `preview*.jpg` images, which is what QL shows. | — | low |
| Is `qlmanage` an API? | No. Its man page calls it a "Quick Look Server debug and management tool", and its output layout is undocumented. Shelling out to it for Office→HTML→PDF is a private-ish contract that could change. If used at all, treat it as a best-effort fallback behind a capability probe. | — | high |
| Can `QLThumbnailGenerator` render page images of Office files? | **Yes, but only the first page or slide.** `.thumbnail` gave `real.docx` 792×1024 (page 1, including the table, the image and correctly numbered "1. 2." items), `min.pptx` 1024×768 (slide 1), `font.xlsx` 216×164, `blank.xls` 340×272, and rtf/odt 792×1024. `.icon` worked for everything. The stub `.numbers` failed with `QLThumbnailErrorDomain 0`. `QLThumbnailGenerator` is 10.15+. | 10.15 | high (tested) |
| Is there a public API for a multi-page PDF from Quick Look? | **No.** `QLThumbnailGenerator` gives one image. `QLPreviewView` and `QLPreviewPanel` only display. `QLPreviewReply` (12.0) is for *providing* previews from your own extension, not for consuming other generators. | — | high |
| Experiment: QL HTML → PDF | Feeding `min.pptx.qlpreview/Preview.html` into the WKWebView print pipeline (section E) gave a **3-page PDF, one slide per page**, though on Letter paper rather than the slide aspect. The `real.docx` preview gave 2 pages, the second blank because of the generator's `min-height` CSS. It works as a hack; fidelity is QL-preview grade (fonts approximated, no animations, charts often missing). | — | medium |

**Implication.** For PPT/PPTX/XLS→PDF/PNG, the zero-size route is QuickLook-thumbnail for page 1 only. Real multi-page output needs either the qlmanage-HTML hack, which is undocumented, or the optional "Office pack" (LibreOffice) that BUILD.md already anticipates.

---

## G. AVFoundation and VideoToolbox

**Local run (macOS 27, M5 Max).** `AVAssetExportSession.allExportPresets()` lists:

```
640x480, 960x540, 1280x720, 1920x1080, 3840x2160, LowQuality, MediumQuality, HighestQuality,
HEVC1920x1080(+WithAlpha), HEVC3840x2160(+WithAlpha), HEVC4320x2160, HEVC7680x4320,
HEVCHighestQuality(+WithAlpha), MVHEVC960x960/1440x1440/4320x4320/7680x7680,
AppleM4A, AppleM4V480pSD/720pHD/1080pHD/AppleTV/Cellular/WiFi/iPod, AppleProRes422LPCM, AppleProRes4444LPCM
```

`Passthrough` works but isn't in the list. `supportedFileTypes` for a small HEVC .mov source:

- **Video presets** (Highest, HEVCHighest, 1920x1080, HEVC1920x1080, Medium): `.mov`, `.mp4`, `.m4v`, `com.apple.immersive-video`.
- **AppleM4A**: `.m4a`, `com.apple.quicktime-audio`.
- **Passthrough**: mov, mp4, m4v, m4a, 3gp, 3g2, amr, wav, aiff, aifc, caf.

Formats such as MKV, WebM, AVI, MP3, FLAC, OGG and Opus are **not** AVFoundation export targets. They all need ffmpeg.

| Item | Answer | Min macOS | Confidence |
|---|---|---|---|
| Export API | `export(to:as:isolation:) async throws` is documented as 10.15, but in the 27 SDK it is `@backDeployed(before: macOS 26.0)`, so it works on 13 when built with the current Xcode. `states(updateInterval:)` for progress is **15.0 only**. On 13–14, poll `progress` instead. `exportAsynchronously` is deprecated in 15. ([export(to:as:)](https://developer.apple.com/documentation/avfoundation/avassetexportsession/export(to:as:isolation:)), [states](https://developer.apple.com/documentation/avfoundation/avassetexportsession/states(updateinterval:))) | 13 with back-deploy | high (local SDK) |
| VideoToolbox encoders on M5 Max (`VTCopyVideoEncoderList`) | **Hardware:** H.264 (`ave.avc`), HEVC (`ave.hevc`), HEVC+alpha (`muxa`), ProRes 422/HQ/LT/Proxy/4444/4444 XQ (`appleproreshw.*`), JPEG. **Software:** H.264, HEVC, ProRes, JPEG, H.263. There is **no AV1 or VP9 encoder**. ProRes hardware encode exists on M1 Pro/Max/Ultra and on M2 and later, base chips included; on a base M1 it falls back to the software ProRes encoder, which still works. | — | high (local) |
| AVAssetWriter + HEVC/H.264 | It uses VideoToolbox. Pass `AVVideoEncoderSpecificationKey: [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true]` to fail rather than fall back silently. A local 320×240 HEVC write completed. ([AVVideoEncoderSpecificationKey](https://developer.apple.com/documentation/avfoundation/avvideoencoderspecificationkey), [RequireHardwareAcceleratedVideoEncoder](https://developer.apple.com/documentation/videotoolbox/kvtvideoencoderspecification_requirehardwareacceleratedvideoencoder)) | 10.10 / 10.9 | high |
| ffmpeg VideoToolbox | `h264_videotoolbox`, `hevc_videotoolbox` and `prores_videotoolbox` use Apple's encoder, and by default require hardware (`-allow_sw 0` is the default; `-require_sw 1` forces software). Local Homebrew ffmpeg 9.0.2: 720p30 HEVC ran at 13.2× and H.264 at 14.5× realtime with `-allow_sw 0`. `-q:v` (constant quality via `kVTCompressionPropertyKey_Quality`) works **only on arm64 macOS**, which suits Halo. Other options: `-realtime`, `-prio_speed`, `-spatial_aq`, `-constant_bit_rate` (macOS 13+), `-alpha_quality`. Tag HEVC as `-tag:v hvc1` so QuickTime and Finder play it. ([videotoolboxenc.c](https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/videotoolboxenc.c)) | — | high |
| VT vs x264/x265 | Hardware is much faster and lower power, but at a given bitrate it is lower quality than x264/x265 slow presets. Use VT for "fast/default" and x264/x265 for a "best quality/smallest" option. | — | medium (general knowledge, not measured here) |
| AV1 hardware **decode** | **M3 family, M4 family, M5 family** (Apple newsroom and spec pages), and A17 Pro. `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` returned **true** on the M5 Max. **M1 and M2 have no AV1 decode**: VT returns `kVTCouldNotFindVideoDecoderErr`, and AVFoundation won't play AV1 there. So bundle **dav1d** in ffmpeg for AV1 input on M1/M2 and on macOS 13. In practice hardware AV1 means macOS 14+ (first OS on M3). ([M3](https://www.apple.com/newsroom/2023/10/apple-unveils-m3-m3-pro-and-m3-max-the-most-advanced-chips-for-a-personal-computer/), [M4](https://www.apple.com/newsroom/2024/05/apple-introduces-m4-chip/), [forum 722933](https://developer.apple.com/forums/thread/722933), [forum 739953](https://developer.apple.com/forums/thread/739953)) | 14 (M3+) | high |
| AV1 hardware **encode** | None on any Apple silicon (absent from every spec page; [Bitmovin](https://bitmovin.com/blog/apple-av1-support/)). AV1 output means libaom or SVT-AV1 (software). The local Homebrew build has `--enable-libsvtav1`. | — | high |
| VP9 | No hardware decode (`VTIsHardwareDecodeSupported(VP9)` = false on M5 Max). Use ffmpeg libvpx. | — | high (local) |

---

## H. Other

### SMAppService (launch at login)

- `SMAppService.mainApp.register()` / `unregister()`, `status` and `openSystemSettingsLoginItems()` are all macOS 13.0 (SDK `SMAppService.h`). `status` is one of `.notRegistered`, `.enabled`, `.requiresApproval` or `.notFound`.
- `register()` posts a "Login Item Added" notification. The user can switch it off in System Settings > General > Login Items, so always re-read `status` rather than caching your own boolean. If you get `.requiresApproval`, deep-link with `openSystemSettingsLoginItems()`.
- No helper app is needed for the main app.

Sources: [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register()), [nilcoalescing](https://nilcoalescing.com/blog/LaunchAtLoginSetting). **Confidence: high.**

### AirDrop from a menu-bar app

- `NSSharingService(named: .sendViaAirDrop)` (10.8). Local results on 27: `canPerform(withItems:)` was **true for 1 file, 2 files and a folder**, and false for a bare string. So multi-file AirDrop works, contrary to an airdrop-cli note.
- **For an LSUIElement app, the picker needs an anchor window:**
  - Implement `NSSharingServiceDelegate.sharingService(_:sourceWindowForShareItems:sharingContentScope:)` to return a small window you own.
  - Bring it to the front (`makeKeyAndOrderFront`; activate the app).
  - The open-source airdrop-cli needed this: PR #10 set the activation policy on macOS 13, PR #13 added `makeKeyAndOrderFront`, and PR #22 fixed a transparent-window bug on macOS 26.
- Call `perform(withItems:)` *after* the drop finishes, not inside `performDragOperation`, so Finder's drag session is over.

Sources: [Apple doc](https://developer.apple.com/documentation/appkit/nssharingservice/name/sendviaairdrop), [airdrop-cli](https://github.com/vldmrkl/airdrop-cli). **Confidence: medium** (the picker presentation wasn't tested here because it would put UI on the user's screen).

### Haptics during a drag

- `NSHapticFeedbackManager.defaultPerformer.perform(_:performanceTime:)` (10.11). It only works on Force Touch trackpads, only while a finger is on the trackpad, and only "in response to user-initiated actions". The `.alignment` pattern is documented for an object being dragged.
- **Real-world report:** it produced **nothing from an LSUIElement app that is not active**. The glisse project (macOS 27) worked around it with private `MTActuator` APIs (MultitouchSupport). **That is private and off-limits.**
- During a Finder-owned drag Halo is not active, so plan for **no haptic on segment change**, or treat it as best effort. Mouse users get nothing either way.

Sources: [perform(_:performanceTime:)](https://developer.apple.com/documentation/appkit/nshapticfeedbackperformer/perform(_:performancetime:)), [FeedbackPattern](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager/feedbackpattern), [glisse](https://github.com/helgafinn/glisse). **Confidence: medium.**

### QLThumbnailGenerator for hub, shelf and progress icons

- Use `QLThumbnailGenerator.shared.generateBestRepresentation(for:)` (10.15) with `representationTypes: [.thumbnail]`, and fall back to `.icon`. Locally it rendered real page-1 thumbnails for docx, pptx, xlsx, xls, rtf and odt, and icons for everything (section F).
- For many items, `generateRepresentations(for:update:)` delivers `.lowQualityThumbnail` first, then upgrades.
- Thumbnails are produced out of process and work without a window or activation. **Confidence: high.**

### UTTypes

Local results on 27 with `UTType(filenameExtension:)`, which conforms to `.data` by default:

| Ext | Result | Note |
|---|---|---|
| `.srt` | **`dyn.ah62d4rv4ge81g6xy` (dynamic, undeclared)** | The system declares no SubRip UTI. Halo must add a `UTImportedTypeDeclarations` entry (e.g. `org.matroska.srt`-style, conforming to `public.plain-text`; pick one and keep it stable) or match by extension. `.ass`, `.ssa`, `.sub` and `.mkv` are dynamic too. |
| `.vtt` | `org.w3.webvtt` (conforms to `public.text`) | declared |
| `.epub` | `org.idpf.epub-container` (`UTType.epub`) | declared |
| `.pages` / `.key` / `.numbers` | **`com.apple.iwork.pages.sffpages` / `keynote.sffkey` / `numbers.sffnumbers`** (single-file variants) | Package variants come back only via `UTType(filenameExtension:conformingTo: .package)`: `com.apple.iwork.pages.pages`, `com.apple.iwork.keynote.key`, `com.apple.iwork.numbers.numbers`. **Always use `URL.resourceValues(forKeys: [.contentTypeKey])` on real files**, and treat both variants as the same format. |
| `.textClipping` | `com.apple.finder.textclipping` | declared |
| `.rtfd` | **dynamic** with the default `.data` conformance; `com.apple.rtfd` (`UTType.rtfd`) with `conformingTo: .package` or from `resourceValues` on a real bundle | `UTType.flatRTFD` = `com.apple.flat-rtfd` |
| `.webloc` | `com.apple.web-internet-location` | also `.inetloc` `com.apple.generic-internet-location`, `.fileloc` `com.apple.file-internet-location`, `.url` `com.microsoft.internet-shortcut` |
| `.avif` / `.jxl` / `.webp` / `.heic` | `public.avif` (no `UTType` constant), `public.jpeg-xl` (`UTType.jpegxl`, 15.2+), `org.webmproject.webp`, `public.heic` | |
| `.md` | `net.daringfireball.markdown` | |

**Confidence: high** (local). On macOS 13 the same identifiers should exist, except that the `UTType.jpegxl` *constant* is 15.2+. The identifier string still resolves earlier if the system declares it. Verify `.srt` and `.jxl` on a macOS 13 VM.

### Opening a terminal at a folder

| App | Bundle ID | `open -a <App> /dir` / `NSWorkspace.open([dir], withApplicationAt:)` | Better route | Confidence |
|---|---|---|---|---|
| Terminal | `com.apple.Terminal` | **New window at that folder.** Its Info.plist (local) declares `public.directory`, `com.apple.bundle` and `com.apple.resolvable` with role Editor. | Also Services "New Terminal at Folder" / "New Terminal Tab at Folder" (`NSSendFileTypes` `public.directory`), invocable with `NSPerformService`. | high |
| iTerm2 | `com.googlecode.iterm2` | Opens a session at that folder. You can't choose tab vs window, and old reports describe an extra home-directory window on cold launch ([iterm2 #6562](https://gitlab.com/gnachman/iterm2/-/issues/6562)). | Services "New iTerm2 Window Here" / "New iTerm2 Tab Here"; or AppleScript (needs Automation consent). | medium |
| Ghostty | `com.mitchellh.ghostty` | Declares `public.directory`; `application(_:openFile:)` sets the working directory. **By default it opens a new tab** in the current window (window if none). This is set by `macos-dock-drop-behavior` (default `new-tab`; `new-window` is available). A known bug opens `$HOME` when given a file instead of a folder (#7286), so always pass a folder. A double window when launched via a Service on macOS 27 is [#14412](https://github.com/ghostty-org/ghostty/issues/14412). | Services "New Ghostty Tab Here" / "New Ghostty Window Here". ([Info.plist](https://github.com/ghostty-org/ghostty/blob/main/macos/Ghostty-Info.plist), [config reference](https://ghostty.org/docs/config/reference)) | high |
| Warp | `dev.warp.Warp-Stable` | Mixed reports: works from a shell, reportedly not via NSWorkspace ([discussion 612](https://github.com/warpdotdev/Warp/discussions/612)). | **URI scheme:** `warp://action/new_window?path=<percent-encoded folder>` or `warp://action/new_tab?path=…` (`warppreview://` for Preview builds) ([Warp docs](https://docs.warp.dev/terminal/more-features/uri-scheme/)). | medium-high |

Only Terminal is installed on this machine, so I checked its Info.plist locally. The other bundle IDs come from Homebrew cask metadata and the apps' sources. I didn't launch any terminal, because that would open windows on the user's screen.

**Recommendation.** Resolve the app with `NSWorkspace.urlForApplication(withBundleIdentifier:)`:

- Terminal, iTerm2, Ghostty: `NSWorkspace.shared.open([folderURL], withApplicationAt:, configuration:)`.
- Warp: open the `warp://` URL.

None of these needs Automation permission. Always pass a **folder** (the file's parent for files).

---

## Local test programs (scratchpad, not in repo) and what each showed

| Program | What it checked |
|---|---|
| `imageio.swift` | Destination and source UTI lists; real AVIF, HEIC, WebP, JXL, JPEG and PNG encodes with alpha round-trip (C) |
| `attrdocs.swift`, `readdoc.swift` | NSAttributedString write and read round-trip across 8 formats; reading a hand-built docx with a table, numbering and an image (E) |
| `webpdf.swift`, `webpdf2.swift`, `textpdf.swift`, `pdfinfo.swift` | `createPDF` vs `printOperation` (runModal vs run) vs NSTextView printing; page counts (E, F) |
| `gen/mkoffice.py` + `qlmanage` + `qlthumb.swift` | Hand-built docx and 3-slide pptx; QL HTML bundles; `QLThumbnailGenerator` thumbnails and icons (F) |
| `av.swift` + ffmpeg | Export presets and file types; VT encoder list; HW decode support; AVAssetWriter HEVC; ffmpeg VT encodes (G) |
| `vision.swift` | Foreground instance mask, person segmentation, saliency and barcode symbologies at runtime (D) |
| `uti.swift`, `uti2.swift`, `airdrop.swift` | UTType resolution; terminal bundle IDs; AirDrop `canPerform` (H) |
| `probe.swift`, `dragtypes.swift`, `levels.swift` | TCC preflight state; live-state APIs without grants; drag pasteboard cross-process types and `accessBehavior`; window levels (A) |

Sources are cited inline next to each claim. Where the evidence is an SDK header, the header is named (MacOSX27.0.sdk). Apple's own minimum versions appear there as `API_AVAILABLE(...)`.
