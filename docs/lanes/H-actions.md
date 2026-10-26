# Lane H: Actions + Float shelf

The Control wheel's six local actions (BUILD.md §8): AirDrop, Float, Copy,
Move, Copy Path, Terminal. All in the app target (`AnyfmtApp`), under
`Sources/Actions/**`. Tests in `Tests/Unit/App/Actions/`. Screens in
`docs/screens/float-*.png` and `docs/screens/move-chooser*.png`.

Every action works on files, folders and mixed selections, never consults
accounts or entitlements, and never touches the network. Share link
(`ActionIDs.shareLink`) is lane I's: `supports(.shareLink)` is `false` and
`perform(.shareLink, …)` returns `.failed`.

## Public API (what other lanes call)

| Caller | Call | Notes |
|---|---|---|
| Wheel (lane B) | `ActionPerformer.shared.perform(id, urls:, promises:, at:) async -> ActionOutcome` | `point` in screen coordinates (AppKit, bottom-left), e.g. `NSEvent.mouseLocation` at the drop. Start it straight from `performDragOperation` in a `Task { @MainActor in … }` so promise requests go out while the drag is fresh. Pass promises only when the drag had no file URLs (Mail, Photos). |
| Wheel | `ActionPerformer.shared.supports(id)` / `canPerform(id, urls:)` | `canPerform` is false for AirDrop on Macs without it. |
| Wheel | `ActionOutcome` = `.done(String?)` / `.cancelled` / `.failed(String)` | Show `.done` messages (e.g. “Copied 3 items”) in the confirmation HUD; `nil` means the action's own UI was the feedback (shelf, terminal window, AirDrop sheet). `.failed` messages are human and ready to show. |
| App (menu bar) | `FloatShelf.shared.toggle()`, `.isVisible`, `.count` | `FloatShelf` is an `ObservableObject` (`@Published isVisible`, `count`) for the menu item's checkmark. |
| App (launch) | touch `ActionPerformer.shared` once | Its init purges `Received/` batches older than 3 days in the background. Optional; otherwise it happens on first use. |
| App (gallery) | `ActionScreens.render(into: URL)` | Writes the 8 PNGs below. Safe to call from `--render-gallery`. |
| Settings | `ActionMenuItems()` | SwiftUI rows for a `Form` section: terminal picker (installed terminals only, with icons) and “Recent Move folders · Clear”. E.g. `Section("Actions") { ActionMenuItems() }`. |

Other public types: `ActionPreferences` (UserDefaults-backed, `init(defaults:)`
for tests), `FileMover` / `MoveReport`, `PathFormatter`, `FileClipboard`,
`TerminalApp` / `TerminalLauncher` / `TerminalLaunchPlan`, `PromiseIntake` /
`PendingPromises`, `ShelfModel` / `ShelfItem` / `ShelfPresence`.

## Files

```
Sources/Actions/
  ActionPerformer.swift      entry point, per-action flows, outcome messages
  ActionOutcome.swift
  ActionPreferences.swift    terminal choice, recent Move folders, shelf position
  ActionMenuItems.swift      Settings rows (SwiftUI)
  AirDrop/AirDropSender.swift
  Clipboard/FileClipboard.swift   Copy + Copy Path formatting
  Move/FileMover.swift       never-overwrite moves, cross-volume staging
  Move/MoveChooser.swift     destination card + NSOpenPanel fallback
  Terminal/TerminalLauncher.swift
  Promises/PromiseIntake.swift
  Float/ShelfModel.swift     pure model: items, pile poses, presence rules
  Float/FloatShelf.swift     controller (singleton), commands, refresh
  Float/ShelfWindow.swift    NSPanel + presenter (geometry, pop-in, resize, snap)
  Float/ShelfCardView.swift  card: modes, header, hover, drop target, menus, summaries
  Float/ShelfStackView.swift pile: layers, physics, drag-out, VoiceOver elements
  Float/ShelfGridView.swift  expanded grid + cells
  Float/ShelfPrintLayer.swift  print/icon layers, count badge
  Float/ShelfThumbnails.swift  QuickLook thumbnails with icon fallback
  Float/ShelfNameLayout.swift  two-line Finder-like names
  UI/ActionStyle.swift       palette (DesignTokens), card chrome, labels, buttons
  Snapshots/ActionScreens.swift  offscreen renders + procedural sample art
```

## What each action does

1. **AirDrop**: `NSSharingService(named: .sendViaAirDrop)` with every URL
   (multi-file and folders work). An LSUIElement app has no window, so a clear
   2×2 anchor window (alpha 1, clear content; a zero-alpha source window makes
   the picker transparent on recent macOS) sits just below the drop point; the
   app activates, the delegate returns the anchor, and success / failure /
   cancel (`NSUserCancelledError`) map to the outcome. Afterwards the anchor
   closes and focus returns to the previously frontmost app if we still hold it.
2. **Float**: see the shelf section below.
3. **Copy**: one pasteboard item per file with `public.file-url` (⌘V in Finder
   pastes copies); the first item also carries `public.utf8-plain-text` with all
   POSIX paths, newline-separated (text views read the first string, so pasting
   into a text field gives the paths).
4. **Move**: a compact card at the drop point lists up to 8 recent destinations
   (most recent first, missing folders pruned, hidden when they're where the
   items already are or inside a moved folder) plus “Choose Folder…”
   (`NSOpenPanel`, folders only, “Move Here”). With no recents it goes straight
   to the open panel. Keys: ↑↓, Return, 1–8, ⌘O, Esc; clicking elsewhere
   cancels. The move itself: see Decisions.
5. **Copy Path**: POSIX paths, one per line, no trailing newline, no trailing
   slash, Unicode as NFC. **Option held at the drop** copies shell-quoted paths
   separated by spaces (`/a/plain.txt '/a/with space.txt'`), ready to paste
   into a command line, the same shape Terminal uses for dropped files.
6. **Terminal**: opens the chosen terminal at the folder (a folder itself; a
   file's, or package's, parent; several items: the deepest folder containing
   all of them, else the first item's folder). Terminal.app, iTerm2 and Ghostty
   via `NSWorkspace.open([folder], withApplicationAt:)`; Warp via
   `warp://action/new_window?path=<percent-encoded>`. Installed terminals are
   detected with `NSWorkspace.urlForApplication(withBundleIdentifier:)`. If the
   chosen one is gone, Terminal.app is used. No Automation permission anywhere.

## Float shelf

- Floating, non-activating `NSPanel` at `.floating`,
  `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`, never hides on
  deactivate, so it survives Space changes and sits over full-screen apps.
  The panel has a transparent margin and the card casts its own layer shadow,
  so the shadow scales with the pop-in.
- **Collapsed**: the newest 3 items as a physical pile (content thumbnails as
  bordered “prints”, Finder icons as-is), each with a fixed tilt/offset derived
  from its id, an iris count badge, title (“5 items” or the file name) and a
  kind summary (“2 images, 1 folder”; four kinds or more: the two biggest groups
  and “+N more”; one item: “PNG image · 2.4 MB”).
- **Expanded**: click the pile (or rest on it for 0.85 s, which collapses again
  1 s after the pointer leaves) for a grid of every item in arrival order:
  thumbnail + two-line name (breaks at spaces, else before the extension; the
  middle is cut only if it still doesn't fit). Hover shows a ✕ per cell.
  More than 3 rows scroll.
- **Empty** (opened from the menu bar): a dashed drop zone, “Drop files here /
  Files stay in place.” It stays up until toggled off or used and emptied.
- **Drag out**: drag the pile = every item (pile formation); drag a cell = that
  item. Outside the app the source offers copy/move/link/generic, so the
  destination behaves exactly as for a Finder drag (same disk moves, other disk
  copies, ⌥ copies). Inside the app (e.g. onto the wheel) copy only. Never
  `.delete`. **A plain drag-out that lands removes the items from the shelf;
  holding Option keeps them** (unless the destination moved the file anyway).
  A cancelled drag animates back and keeps them.
- **Drop in**: the card is a drop target for file URLs and file promises
  (received into `Received/<uuid>`), with an iris glow while hovering.
- **Context menu** (right-click or ⋯): Reveal in Finder, Copy, Copy Paths,
  AirDrop All…, Show All / Collapse, Clear Shelf. Per item (grid): Open, Reveal,
  Copy, Copy Path, AirDrop…, Remove from Shelf. Double-click opens. ✕ (top left,
  on hover) clears the shelf.
- **Physics**: pop-in springs out of the drop point (response 0.42, damping
  0.7); new items drop onto the pile from above with extra tilt and settle with
  a little bounce (0.42 / 0.62), staggered 60 ms, while the pile gives slightly;
  removed items tip over and fall out; grid cells pop in and shrink out; the
  window resizes with an ease-out curve. **Reduce Motion**: every one of these
  becomes an opacity crossfade.
- **Appearance**: popover material kept `.active` (our app is almost never
  active), hairline inner stroke; **Increase Contrast** thickens and darkens
  the stroke; **Reduce Transparency** swaps the material for a solid fill. White
  text and the count badge use the light iris in both modes (the dark-mode iris
  is ≈3.3:1 under white text; the light one ≈4.9:1).
- **VoiceOver**: the card is a group (“Float shelf, 5 items”); the pile exposes
  one element per item (button, role description “file”, press = Open, custom
  actions Remove from Shelf / Reveal in Finder / Copy); grid cells are the same;
  controls are labelled. Controls stay visible while VoiceOver is on.
- **Staleness**: items carry bookmarks; every 4 s while visible (and when the
  pointer comes over the shelf, and after a drag) the shelf follows renamed or
  moved files and drops deleted or trashed ones, dismissing itself if empty.
- **Position**: snaps to a screen edge within 24 pt after you drag it (by its
  background); its last position is the only thing persisted. Float drops pop
  in at the drop point; the menu bar toggle uses the saved position, else the
  right side of the main screen. Always clamped on screen, multi-display aware.

## Decisions (ready for DECISIONS.md)

- **H-1 The shelf references files, it never copies them.** Copying would
  double disk use and leave stale copies; references keep “park now, drop
  later” honest. Bookmarks follow renames/moves; trashed files count as gone.
- **H-2 Drag-out = Finder drag semantics; plain drag removes, ⌥ keeps.** The
  shelf is a deferred drag, so the destination should do what it would have
  done with the original drag. ⌥ is both Finder's copy modifier and our “keep”
  modifier, so the two never disagree. `.delete` (Trash) isn't offered, so a
  slip can't trash anything.
- **H-3 Move never overwrites.** `OutputNamer.freeURL` picks Finder-style names
  (“photo 2.jpg”, “archive 2.tar.gz”, “Project 2”, “Tool 2.app”, “.zshrc 2”) and
  placement is `renamex_np(RENAME_EXCL)`, retried on `EEXIST`. Cross-volume:
  copy to a hidden staging name in the destination, exclusive-rename into
  place, then remove the original, so an interrupted copy never sits under the
  real name and the original goes only after a complete copy. Folders are never
  merged. Symlinks move as links. A folder into itself (or its subfolder,
  symlinks resolved) is refused before anything is touched.
- **H-4 Received promise files** live in
  `~/Library/Application Support/<Brand.name>/Received/<uuid>/` (one folder per
  receiver, so same-named attachments can't collide) and are purged after 3
  days. They're app-owned copies; the originals stay in Mail/Photos.
- **H-5 Terminal folder for several items** = deepest common folder (for a
  Finder selection, the folder you're looking at); first item's folder if they
  share only `/`. Packages (.app, .rtfd) count as files.
- **H-6 Ghostty opens a tab, by design.** Its folder-open behaviour is set by
  Ghostty's `macos-dock-drop-behavior` (default `new-tab`); there's no public,
  permission-free way to force a window from outside (its Services entry has a
  double-window bug on macOS 27). The Settings row says how to get a window.
- **H-7 Warp uses its URI scheme** with every character except unreserved ones
  and `/` percent-encoded (spaces, `&`, `#`, `+`, `%`, Unicode).
- **H-8 Copy Path text is NFC.** File URLs carry NFD from the file-system
  representation; NFC is friendlier in text and APFS/HFS+ resolve both.
- **H-9 Offscreen renders use the solid (Reduce Transparency) card**, because
  window-server materials can't be captured; they're rendered by parking a
  window at (-30000, -30000) and calling `CALayer.render(in:)`, so nothing
  appears on screen. Sample thumbnails are procedural (our own art).

## Shipped / not shipped (for PARITY.md)

Shipped: all six local actions, the Float shelf with everything above, the
Move chooser, terminal picker, promise intake, offscreen screens.

Not shipped (and what it would take):
- **Quick Look on shelf items** (Space / menu item): needs `QLPreviewPanel`
  control from a non-activating panel; activating the app for it is doable,
  ~1 day with a real-hardware check.
- **Full keyboard control of the shelf**: clicking the pile to expand it
  focuses the shelf so Esc collapses it, but there's no arrow-key navigation
  between items yet (VoiceOver navigation and actions work).
- **Undo for Move**, and **progress UI for big cross-volume moves** (the move
  runs off the main thread with no progress window; lane C's progress windows
  could host it as a job).
- **Multiple shelves**: not required; the model supports one.
- **Haptics**: none (an inactive agent gets none; the only workaround is private).

## Contract change requests

None. (Note for the orchestrator: `scripts/check-entitlements.sh` matches
`\.plan\b`, so a local method named `plan(...)` trips it. I renamed mine to
`launchPlan(for:folder:)`; other lanes may hit the same false positive.)

## Tests

`Tests/Unit/App/Actions/`, 74 tests, all passing:

```
xcodebuild … test -only-testing:AppTests/ClipboardActionTests -only-testing:AppTests/MoveActionTests \
  -only-testing:AppTests/ActionPreferencesTests -only-testing:AppTests/TerminalActionTests \
  -only-testing:AppTests/FloatShelfModelTests -only-testing:AppTests/FloatShelfControllerTests \
  -only-testing:AppTests/ActionPerformerTests -only-testing:AppTests/ActionScreensTests
```

(The test target is `AppTests`; its product is `AnyfmtAppTests`.) Coverage: Copy
Path formatting (single, multi, spaces, Unicode, folders, shell quoting, the ⌥
variant through the performer); Copy on a private named pasteboard; Move
collision naming with pre-created collisions (files, folders, tar.gz,
dotfiles, extensionless), never-overwrite content checks, several source
folders, already-there, the simulated cross-volume path (no staging
leftovers), refusals (into itself, through a symlink, missing/non-folder
destination), symlinks moved as links, chooser filtering, outcome messages;
recents ordering, dedupe (incl. symlinked spellings), cap of 8, pruning that
persists; terminal detection with an injected lookup, fallback, folder rules,
packages, Warp URL encoding round-trip, plans per app, the action end to end
with an injected opener; shelf model add/raise/dedupe/stack order/remove/
refresh (moves, deletes, collapse), pose stability, presence and auto-dismiss,
the controller with a fake presenter (show at drop point, update, dismiss on
last removal, drag-out rules, refresh prunes deleted files, bookmarks follow a
rename, position saved); promise intake paths, unique batch folders, purge;
two-line name layout; placement geometry; and the offscreen renders.

`scripts/check-entitlements.sh`: passes.

To refresh the screens into `docs/screens`:

```
TEST_RUNNER_HALO_SCREENS_DIR="$PWD/docs/screens" xcodebuild … test -only-testing:AppTests/ActionScreensTests
```

## Blockers needing a human

- **Real-hardware check (~10 min)**, same harness limit as B-001 (no input
  synthesis): drop a Finder selection on each Control-wheel action; drag the
  shelf pile into Finder, Mail and Slack; drag one grid cell out with and
  without ⌥; drop files from Finder, Mail and Photos onto the shelf; AirDrop
  2 files from the wheel and from the shelf menu; open each installed terminal.
  Expected behaviour is described above.
- Strings use `String(localized:)`; the app's `Localizable.xcstrings` (lane App's
  file) picks them up the next time it's synced in Xcode.
