# Lane B: the wheel

`Packages/RadialMenu` (MIT, standalone) + `Sources/Wheel` (app, module HaloApp).
Branch: this worktree. Every commit builds and passes its tests.

## What's built

### Packages/RadialMenu (generic, knows nothing about files)

| File | What |
|---|---|
| `RadialItem.swift` | `RadialItem` (id, title, subtitle, image, badge, accessory, isEnabled, prominence `.title`/`.glyph`, a11y label/hint), `RadialHubContent`, `RadialDropZone` |
| `RadialMenuConfiguration.swift` | Geometry, type and motion (defaults = Halo tokens, copied in), `RadialRing` |
| `RadialMenuStyle.swift` | `RadialMenuStyle` (accent, badge colours, material `.popover`/`.hudWindow`, forced appearance), `RadialAppearance` (dark, increase contrast, reduce transparency, reduce motion), internal resolved palette |
| `RadialLayout.swift` | Pure layout + angular hit testing + keyboard order (no AppKit) |
| `WedgePath.swift` | Rounded annular sectors with constant-width gaps and a fixed path structure (morphable) |
| `RadialPlacement.swift` | Multi-display, Retina-snapped centring with edge push-in and the top exclusion band |
| `RadialMenuView.swift` (+`Input`) | Layer-hosting view: three layer trees (shadows under the material, `NSVisualEffectView` masked per segment, overlay), hover/open/close/morph/confirm, drag destination, mouse, keyboard, VoiceOver |
| `SegmentNode.swift`, `HubNode.swift` | Per-segment and hub layers; `DropZoneNode` for the empty ring |
| `ContentRenderer.swift` | Draws glyph + label (+ subtitle, Pro chip) bitmaps once per state |
| `RadialSegmentElement.swift` | One `NSAccessibilityElement` (radio button) per segment |
| `RadialMenuPanel.swift` | D-003 overlay panel, drag-type registration, placement, dismiss/confirm, `onVisible`, `prewarm()` |
| `RadialMenuSnapshot.swift` | Offscreen render (painted material, optional wallpaper backdrop, crop to wheel) + PNG |
| `README.md`, `Screenshots/` | Usage, behaviour, 6 screenshots |

Public API in one breath: `RadialMenuPanel(configuration:style:draggedTypes:)` → `.menuView`
(`setItems(_:animated:)`, `hub`, `dropZone`, `menuTitle`, `highlightItem(at:)`, `showPage(_:animated:)`,
`playOpenAnimation()`, `playCloseAnimation(toward:)`, `playDropConfirmation(at:)`, `announce(_:)`,
`movementGuard`, `delegate: RadialMenuViewDelegate`), `.show(at:)`, `.position(animated:)`,
`.dismiss(toward:)`, `.confirmDrop(at:)`, `.prewarm()`, `.allowsKeyboard`, `.onVisible`,
`.screensProvider`; `RadialMenuSnapshot.render(items:configuration:style:appearance:hoveredIndex:size:…)`.

Delegate: `didHighlight`, `didActivate`, `canAcceptDropOn`, `didDrop(_:on:)`, `didDropOnEmptyRing`,
`radialMenuDidCancel`, `didRequestNextMenu(forward:)` (Tab), `hasOptionsFor` / `didRequestOptionsFor(_:anchor:)`,
`radialMenuDragDidExit`. All optional.

### Sources/Wheel (app)

| File | What |
|---|---|
| `WheelModel.swift` | `WheelKind` (convert/tools/actions, Tab order, titles), `WheelPreferences` (Codable, tolerant decoding), `WheelEntry`, `WheelSelection`, `WheelInput` (URLs + promised UTTypes, `format(for: UTType)`) |
| `WheelContentProvider.swift` | Entries per kind, `resolve` (empty → Actions fallback with a hub note), item mapping (labels, glyphs, "via X", VoiceOver text) |
| `CloudSegments.swift` | **Only** file that touches `Entitlements`/`CloudFeature`: Pro decoration, filter, `intercept` (explainer callbacks), `allowsCloudJobs` (video "convert in the cloud" toggle) |
| `WheelHub.swift` | Finder icon at once, QuickLook thumbnail async (56 pt), idle text (size / "N files" / "N items" / "Folder") |
| `WheelController.swift` | `show(kind:urls:promisedTypes:at:)`, `switchKind`, `hide`, `confirmDrop`, `dragDidEnd`, `showForSelection(urls:at:)`, `showDropRing(at:)`, `prewarm`, `onSelect(selection, urls, promises, dropPoint)`, `onCancel`, `markVisible`, `onKindChange`, `rememberedOptions` |
| `WheelOptionsPopover.swift` | SwiftUI options popover from `RouteTarget.schema` in an `NSPopover` anchored to the segment, drop target mid-drag |
| `WheelTheme.swift` | DesignTokens → `RadialMenuConfiguration`/`RadialMenuStyle`/`RadialMenuStrings` (localised) |
| `WheelGallery.swift`, `WheelGalleryData.swift` | `WheelGallery.renderAll(to:scale:) throws -> [URL]`, `WheelGallery.showWindow()`, fake capability table per file kind |

## Decisions (ready for DECISIONS.md)

**D-B01 Ring split and paging.** ≤ 8 items: one ring, item 0 centred at 12 o'clock, clockwise.
9–20: inner ring full (8), the rest on an outer ring of fixed 30° wedges as one arc centred on
12 o'clock, so the outer ring "fills up" from the top as a file gains targets (a 9th target is
one tab above the wheel, not a 360° band). > 20: outer ring pages: 11 items + a **More** segment
at 11 o'clock with page dots; it flips on a 0.5 s hover dwell (mid-drag), click, Return,
Page Up/Down or scroll. Never an overflow menu. Every item is reachable (tested to 60).

**D-B02 Hit testing.** Angle from the hub picks the wedge (gaps belong to the nearer wedge);
radius picks the ring with the boundary halfway between rings; where a partial outer arc has
no wedge, the inner wedge at that angle wins. Dead zone r < 34 pt = nothing (drop refused,
wheel closes). 18 pt overshoot past the outer edge still hits. 1.5° angular and 3 pt radial
hysteresis.

**D-B03 Material: per-segment masked vibrancy, `.popover` by default.** One behind-window
`NSVisualEffectView` (state `.active`, so it stays vibrant while Halo is inactive mid-drag)
whose layer mask holds one shape layer per segment, animated with the same animations as the
segment. Verified on macOS 27 by capturing our own window: the layer mask clips the
behind-window material exactly (corners alpha 0). Shadows live in a layer tree *under* the
material, so they show only outside the wedges. `.popover` reads as bright frosted in light
mode and smoky in dark, holding label contrast over busy wallpapers; `.hudWindow` is darker
and more see-through (switchable in the gallery). Inside an ordinary window (gallery,
onboarding demo) the view switches to within-window blending. Reduce Transparency hides the
vibrancy and paints an opaque fill.

**D-B04 Empty wheels fall back to Actions.** A file with no conversions (or no tools) gets the
Actions wheel, with the hub pill saying "No conversions" / "No tools" and VoiceOver announcing
it. A wheel with one disabled "nothing here" segment is a dead end; Actions always work.

**D-B05 Convert order.** Favourites (Settings order) → targets of the input's own kind
(a video's MP4/WebM/MKV before MP3/GIF) → the router's kind/catalogue order. Hidden formats
and `.hiddenByDefault` rows are dropped unless shown or favourited.

**D-B06 Hover.** The hovered wedge's path springs outward (lift 5 pt + the 1.06 scale applied
to the band depth, a touch wider into the gaps) while its glyph/label scale 1.06 and move
out 3 pt; fill swaps to iris with a soft iris glow; 0.1 s colour change. Growing the path
rather than translating the layer keeps the masked vibrancy seamless (no sliver of the old
position). The hub pill swaps instantly to the hovered title (a crossfade overlapped two
labels for 80 ms; looked messy in captured frames). Haptic `.alignment` on every segment change
(best effort; AppKit drops it while we're inactive, D-B11).

**D-B07 Motion budget.** Open: segments scale 0.55 → 1 + fade from the hub, stagger
`min(8 ms, fit)` so the whole fan always ends by 150 ms (verified for 1–24). Close: everything
collapses toward the pointer in 110 ms. Wheel switch: wedges morph to new angles in 160 ms,
new wedges grow from slivers, removed ones collapse, labels crossfade. Drop: 2 × 90 ms fill
pulse, then a 110 ms dissolve toward the drop point. Reduce Motion: 120 ms crossfades only,
no lift, no collapse.

**D-B08 Edge push-in + movement guard.** Placement clamps the wheel inside the pointer's screen
(8 pt inset, below the menu bar and the 24 pt top band, may overlap the Dock), snapped to the
backing pixel grid. When it had to be pushed, the pointer may start over a segment, so nothing
is selected (and a drop is refused) until the pointer moves 8 pt. Morphs that add a ring
re-place the panel with a 160 ms frame animation.

**D-B09 Options popover mid-drag.** Right-click (keyboard/drop-ring modes) or a 600 ms hover
dwell opens the popover for convert segments with a schema. Mid-drag the button is held, so
the popover shows the values that will be used and is itself a drop target: dropping files on
it ends the drag, makes the controls live, and "Convert" applies them. Values are remembered
per format for the session (`rememberedOptions`; the host may persist them). The "Convert in
the cloud" toggle goes through `CloudSegments.allowsCloudJobs()`.

**D-B10 Pro segments.** Cloud glyph + gold "PRO" chip under the label, or a compact chip on
the glyph's corner when there's no room (outer ring). Choosing one while signed out refuses
the drop (the icon slides home, nothing happens to the file) and calls
`cloud.onProTapWhileSignedOut(feature)`; signed in without the plan calls
`onProTapWithoutPlan` (falls back to the signed-out explainer). `WheelPreferences.showCloudItems`
hides them entirely. Local items never consult entitlements.

**D-B11 Keyboard map.** ←/→ previous/next in angular order (wraps), ↑/↓ outward/inward ring
(single ring: previous/next), Return/Enter apply, Escape cancel, Tab/Shift-Tab next/previous
wheel, 1–9 select item 1–9 (select only; Return applies), Page Up/Down pages. Selection mode
preselects the first target so Return-Return converts to the top favourite.

**D-B12 Drop ring.** `showDropRing(at:)` shows an empty dotted ring ("Drop files") and activates
Halo so Escape works. Drop files on it and it becomes the convert wheel in place (fan-out
animation, keys + clicks). It doesn't close when Finder takes focus (the user is about to drag
from there); it closes on Escape, a click in the hub, `hide()`, or after 12 s with nothing dropped.

## What ships / doesn't (for PARITY.md)

Ships: everything in BUILD.md §6 except as noted below; 3 wheels; second ring; paging;
options popover; drop ring; Pro decoration; Wheel Gallery (window + offscreen PNGs).

Not verifiable unattended (needs a human, like B-001):
- A real Finder drag onto the panel (the machine can't synthesise input). The drag-destination
  path is unit-tested through the view's own methods; `performDragOperation`/promises need the
  B-001 run.
- Trackpad haptics mid-drag: called on every segment change, but AppKit ignores haptics while
  Halo isn't active (PLATFORM_RESEARCH H). Should work in selection/drop-ring modes (Halo is active); unconfirmed.
- How `.popover` vs `.hudWindow` vibrancy looks over a real desktop: window captures can't
  include the backdrop without Screen Recording permission. Shapes, masks and animation were
  verified from captures of our own window.

## Integration for the orchestrator (not my files)

- `AppDelegate`: `--render-gallery <dir>` → `try WheelGallery.renderAll(to: URL(fileURLWithPath: dir))`
  then exit (that's what `make gallery` runs). Hidden menu item with ⌥ held → `WheelGallery.showWindow()`.
  Call `wheelController.prewarm()` at launch (first show p95 drops by the window-server setup).
- DragSense → `WheelController`: drag started + tap → `show(kind:urls:promisedTypes:at: NSEvent.mouseLocation)`;
  further taps → `switchKind(_:)`; drag ended (mouse up anywhere) → `dragDidEnd()` (no-op if the drop landed on us).
- Services "Open in Halo Wheel" / Finder shortcut → `showForSelection(urls:at:)`; hotkey → `showDropRing(at:)`.
- `onSelect(selection, urls, promises, dropPoint)` → jobs (convert/tool) or lane H actions; promises must be
  received with `NSFilePromiseReceiver.receivePromisedFiles` (already captured from the drop). Progress window
  near `dropPoint`.
- `cloud.entitlements` / `cloud.onProTapWhileSignedOut` from lane I; `preferences` from Settings.
- `markVisible` → perf measurement. `rememberedOptions` can be persisted by Settings.
- `make gallery` writes 117 wheel PNGs + 8 options-popover PNGs (≈ 54 MB at 2×). For committed regression
  images use `renderAll(to:scale: 1)` (≈ ¼ the size) or a subset.
- New user-facing strings use `String(localized:)` in the app module; the app's string catalog picks them up.

Contract changes requested: none. (Nice-to-have for lane C: a `Formats.format(for: UTType)` in HaloCore;
`WheelInput.format(for:)` does it locally for now.)

## Tests

- `cd Packages/RadialMenu && swift test`: **47 tests, 0 failures** (layout 1–60 items, ring split, paging,
  hit testing incl. wrap-around at 12 o'clock, dead zone, partial arc fallback, hysteresis, morphable path
  structure, open budget 1–24, spring maths, placement at every edge/corner, menu bar, top band, multi-display
  with negative coordinates, nearest screen, tiny screens, pixel snapping, keyboard map, VoiceOver elements,
  hit-area alpha, click-through outside the disc, panel recipe, movement guard, snapshots in every appearance).
- `xcodebuild … test -only-testing:AppTests`: **34 tests, 0 failures** (2 skipped dev hooks): content provider for
  image/video/audio/pdf/multi/mixed/folder/no-conversion/unknown/promise-only, favourites, same-kind order,
  hidden/shown formats, hidden tools, cloud items, preferences Codable, Pro decoration only on cloud items,
  explainer routing signed out / without plan, controller show/switch/hide/fallback/select/options/Tab/cancel/drop
  ring, options model (visibility, cloud gate, MB conversion), gallery `renderAll` writes every case.
- Dev hooks: `TEST_RUNNER_HALO_GALLERY_OUT=<dir> xcodebuild … -only-testing:AppTests/WheelGalleryTests` renders the
  full gallery and a capture of the gallery window there.
- `scripts/check-entitlements.sh`: passes.

## Performance (release, M5 Max, macOS 27.0.1, n = 40)

| Step | p50 | p95 |
|---|---|---|
| `setItems` for 22 items (layout + label bitmaps; highlight bitmaps are lazy) | 2.5 ms | 6.0 ms |
| `panel.show` → window server reports visible (incl. vibrancy, first commit) | 15.5 ms | 26 ms |
| Estimated key tap → wheel visible (+ ≤ 4.2 ms DragSense polling, D-001) | ≈ 20 ms | ≈ 30 ms (budget 50) |

Hover, open, close and morph run entirely in Core Animation (no Swift per frame).

## Blockers

None blocking. Human checks for the B-001 session: drag a Finder file, tap Shift, drop on a segment / the hub /
outside; drag from Mail (promise); trackpad haptic in selection mode; compare `.popover` and `.hudWindow` in the
gallery's live wheel over a busy wallpaper.
