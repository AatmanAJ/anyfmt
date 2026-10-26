# Prior art: lessons for anyfmt

Research date: 2026-10-18.

**Ground rules.** Everything here was read for lessons only. No code from these projects goes into anyfmt. This file paraphrases behaviour and design ideas; it doesn't reproduce source. The clones live in `research/prior-art-src/`, which is gitignored. Nothing in them was built or run.

| Repo | Snapshot read | Licence | Our stance |
|---|---|---|---|
| `ishanmalu/daisy` | `6c42295` (2026-09-30, v0.10.0, 40 commits) | PolyForm Noncommercial 1.0.0 since `95ff48c` (2026-09-10). Before that it was MIT. | Read only. The early commits were MIT, but BUILD.md says zero code, so we treat the whole history as off limits. |
| `opencoredev/convt` | `1920b04` (2026-10-15, v0.5.0+1) | AGPL-3.0-only | Read the design ideas only. Every line in anyfmt is written fresh. |
| `CapSoftware/Cap` | `346561b` (shallow) | AGPL-3.0, with MIT for some crates | Checked for the CLA question only (see `CLA_RESEARCH.md`). |

---

## Daisy

Daisy is a Swift/AppKit menu-bar app. You hold Shift, drag a file out of Finder, and a radial "petal" wheel appears; you drop the file on a format. It is the closest prior art to anyfmt, and it's about five weeks old. The repo has **no GitHub issues or PRs** (1 star), so every caveat below comes from the source, the commit messages and `CHANGELOG.md`.

### 1. How it detects a system-wide Finder drag

- **Mechanism.** It installs a *global* and a *local* `NSEvent` monitor for left-mouse down, dragged and up. A global monitor sees other apps' events, including Finder's. The local one covers drags that start inside Daisy. There is no polling timer: the logic runs only when a drag event arrives.
- **Telling a real drag from other mouse moves** (current code, from commit `48e042b`):
  - On mouse-down it records `NSPasteboard(name: .drag).changeCount` as a baseline.
  - On each dragged event while Shift is held:
    - If the count has changed since mouse-down, a drag session has started. Daisy then checks only the pasteboard's **types**, not its contents, and summons the wheel only if the types include a file URL or a file-promise type.
    - If the count has *not* changed, it **fails open** after **6 drag events** and summons anyway. The comment gives two reasons: a window being moved, or a drag pasteboard that isn't readable from Daisy.
  - The check repeats on every dragged event because the drag source writes the pasteboard a few events into the drag, not at mouse-down.
- **History, with contradictory findings worth testing ourselves:**
  1. `f74af7a`: read the file URLs straight off the drag pasteboard at the first dragged event.
  2. `5fee1d1`: the author's `--drag-probe` said mouse events arrive fine, but the drag pasteboard came back empty when read from a background process. So detection was changed to show an empty wheel and read the files only in `draggingEntered`, once the drag is over Daisy's window.
  3. `48e042b`: back to inspecting the drag pasteboard (types plus changeCount), with the fail-open fallback.

  Several other open-source apps *do* read file URLs from the drag pasteboard from the background: converty, Kompakt, Clop and boring.notch (see "Other prior art"). The probe in step 2 only sampled every 15th drag event, and its first sample was the very first event, before the source had written anything. So the empty result may have been a timing artefact. **anyfmt's DragProbe must log the changeCount, types and URLs on every event, with timestamps, so we know rather than guess.**
- An earlier commit (`f8a5532`) worried that an ad-hoc-signed app might receive no global mouse events on recent macOS. The next probe (`5fee1d1`) contradicted that: events arrived fine. Treat it as unverified folklore, but test with ad-hoc, Apple Development and Developer ID signatures all the same.

### 2. How it detects modifier keys

- **Shift (the summon trigger):** it reads the class property `NSEvent.modifierFlags` *inside the drag-event handler*. That needs no permission. But it is "Shift **held** while the mouse moves", not a tap. If the user stops moving and presses Shift, nothing happens until the next drag event.
- **Option (Tools mode):** handled by `flagsChanged` on the wheel view. That fires only when Daisy's panel is key, and a drag-summoned panel is deliberately *not* made key (see §3). From reading the code, toggling Option mid-drag probably does nothing until after the drop. This is inferred and wasn't tested.
- **Hotkey:** ⌥⇧V through Carbon `RegisterEventHotKey`, which needs no permission. If another app holds the combination, the call fails and Daisy only logs it.
- **No tap detection anywhere** (press and release within a threshold). anyfmt's tap-a-modifier interaction has no prior art in Daisy. The code comment saying that keyboard monitors need Accessibility matches Apple's documentation for global key-event monitors, and `flagsChanged` counts as a key event. So the permission-free path for anyfmt is to **poll `NSEvent.modifierFlags` on a timer during the drag**. FileFlipper does this at 30 Hz. A quick tap may need 60 Hz or faster. That's our inference, to be measured in the spike.

### 3. How the overlay accepts the drop while Finder owns the drag

- The window is a borderless `NSPanel` with the `.nonactivatingPanel` style, `level = .floating`, `hidesOnDeactivate = false` and a clear background. The window is 360 pt; the disc inside it is 286 pt, so the bloom and shadow aren't clipped.
- **A drag summon calls `orderFront` only, never `makeKey` or `activate`.** That keeps Finder's drag session alive and doesn't steal focus. Summons from the hotkey or the menu do `makeKeyAndOrderFront` and activate the app.
- The wheel view registers for file URLs plus every `NSFilePromiseReceiver` readable type:
  - `draggingEntered` and `draggingUpdated` load the URLs, which are readable now that the drag is over Daisy's own window. They also hit-test which petal is under the cursor and return `.copy`.
  - `performDragOperation` runs the petal under the cursor. If the drop lands on the disc but not on a petal, the panel stays open, becomes key and works by keyboard.
  - `draggingEnded` hides the panel if nothing was dropped.
- **File promises** (Photos, Safari, Mail): the promised files are received into a temporary staging folder, with a **30 s guard** in case the source never delivers. The staging folder is cleared at launch. Output for a file that only exists in temp goes to `~/Downloads`.
- Since commit `f8b5403` the wheel always opens **in the centre of the screen that holds the cursor**, not at the cursor, so there is always one place to look. The cost is that every drag has to travel to the middle of the screen. anyfmt's brief puts the wheel at the cursor, which is better for speed but needs a guard so the wheel doesn't open under the drop point by accident.

### 4. TCC permissions

**None requested.** There's no Accessibility, Input Monitoring, Automation, Screen Recording or Full Disk Access check anywhere in the code.

- Mouse monitors are global and need no permission (the author's probe confirmed this).
- Shift comes from polling `modifierFlags` (no permission).
- The hotkey uses Carbon (no permission).
- The Finder entry is a Services menu item, "Convert with Daisy…", declared through `NSServices` in Info.plist (no permission).
- The app isn't sandboxed and is ad-hoc signed by default. A separate script does Developer ID signing and notarisation.

The permission-free approach is clearly *possible*. The price is that you can't detect a keyboard tap through a global key monitor.

### 5. Caveats, bugs and timing hacks (from code, commits and the changelog)

**Drag-summon timing**
- After mouse-up, Daisy waits **0.1 s** before dismissing a drag-summoned wheel, so that AppKit can deliver `performDragOperation` first. This is a timing hack. converty and Kompakt both use **0.15 s**.
- An **8 s** backstop timer dismisses the wheel if no mouse-up ever arrives. Before `f8b5403` the backstop was 0.6 s.
- The `summoning` flag is cleared *only* by a mouse-up event. If one is missed, for example during Mission Control or a Space switch mid-drag, later Shift-drags can't summon until the next click. converty and Kompakt also check `NSEvent.pressedMouseButtons`, which recovers from this. anyfmt should too.

**False positives**
- The fail-open rule ("6 drag events with an unchanged changeCount means summon") makes the wheel flash for Shift-drags that aren't file drags, such as window moves or text selection, until mouse-up.
- Two related problems seen in other apps:
  - **Stale drag pasteboard.** The drag pasteboard keeps the *previous* drag's contents after that drag ends (an OpenYoink finding). A type check without a changeCount guard can therefore see an old Finder file URL.
  - Daisy's type check only runs after the changeCount moves, so Daisy avoids this one.

**Files on the clipboard**
- Up to 0.8.1, summoning loaded file URLs from the general clipboard. That looked like the wheel "keeping" the last file. The fix (`6c0c356`) was that the wheel always opens empty and the user presses ⌘V to paste.
- Reading the general pasteboard programmatically is also the thing macOS pasteboard privacy now warns about (see "Other prior art"). **anyfmt shouldn't auto-read the general pasteboard.**

**Multiple files**
- A multi-file drop arrives in Finder's *selection* order. Daisy sorts by natural filename order (img2 before img10) when it combines files into one PDF.
- It also asks "one PDF or N PDFs?" only when both readings are valid.

**Engine runs**
- An engine that exits 0 but writes nothing is treated as a failure. This was found after resvg passed silently while writing a file called `-o` into `/`.
- A launched app's working directory is `/`, which is read-only, so engines run with the working directory set to a temp folder.
- Bundled tools built on glib get `GIO_MODULE_DIR` and related variables pointed at an empty path, so they don't load Homebrew's modules.
- There is a 600 s process timeout, reported as exit code 124. The timeout flag had a cross-queue race, fixed in `f8b5403`.

**Swift dispatch bug** (`4b3a719`)
- A protocol method declared only in an extension is statically dispatched. Multi-step converters therefore silently ran the no-op default.
- Make every overridable behaviour a protocol *requirement*.

**Watch-folder bugs** (`1440a8e`)
- An FSEvents stream created without the CF-types flag crashed the app.
- A rule caught its own outputs, so it reprocessed them forever.
- Rules missed paths reached through symlinks (`/tmp` vs `/private/tmp`).
- Large copies were picked up after a fixed 1 s instead of once their size had settled.

**Menu and metadata**
- Quit was silently greyed out: every menu item targeted an object that doesn't respond to `terminate:`. The self-test now checks that every menu item can fire.
- Stale metadata: `Info.plist` still says "MIT licensed" and `LICENSES/NOTICE.md` still says "Kuori" (the old name). Lesson: generate these strings from a single source and test them.

**Animation**
- A window's drop shadow isn't recomputed while its content shape animates, which leaves a ring of stale shadow. Daisy's fix was to keep the disc's shape fixed and animate inside it.
- A behind-window blur can't be captured by an offscreen cache, so screenshots need a live window (`--demo`).

**Updater**
- An update must match the SHA-256 published with the release *and* satisfy the running app's own code-signing requirement.
- Ad-hoc builds can never satisfy that requirement, so they fall back to "download and reveal in Finder".

### 6. Engines and licensing notes

**What it bundles** (about 20 MB, chosen to be "GPL-free")
- cwebp (BSD-3): ImageIO decodes WebP but can't encode it.
- qpdf (Apache-2.0).
- resvg (MPL-2.0).
- 7zz from sevenzip (LGPL-2.1+ and BSD-3).
- unar (LGPL-2.1+).
- Their dylibs: giflib, libjpeg-turbo, libpng and ca-certificates.

**What it doesn't bundle** (found on `PATH` if the user installed them)
- ffmpeg (GPL-3), pandoc and potrace (GPL-2).
- libvips: LGPL itself, but its Homebrew bottle hard-links fftw (GPL-2) and libimagequant (GPL-3), and removing either stops vips from loading.
- Dropping these took the engine folder from 350 MB to 20 MB.

**Why GPL-free.** Daisy's own licence isn't GPL-compatible, and the author wanted to avoid any source-offer obligation. anyfmt's position is different: an AGPL anyfmt can bundle GPL engines as separate programs, as long as it ships a proper source offer. **But a future Mac App Store or proprietary build has the same constraint Daisy has.** GPL/AGPL code can't go through the App Store's terms, so it would need Daisy's kind of GPL-free engine set. Design anyfmt's engine registry so the GPL engines can be switched off per build flavour.

**How it bundles**
- It copies binaries out of Homebrew bottles.
- A script walks `otool -L`, copies every non-system dylib in, and rewrites install names and rpaths to `@loader_path`.
- It ad-hoc signs everything with `--deep`.
- It claims LGPL relinking is satisfied because the LGPL libraries ship as separate, replaceable dylibs.
- **Weak spots:**
  - The source pointer in NOTICE is just `brew fetch --build-from-source <formula>`. That's thin for LGPL-2.1 §6, which wants the source itself or a written offer, and it doesn't pin a version.
  - Copying bottles means versions float with the build machine.
  - anyfmt's plan to build from pinned sources (`make engines`) is the right correction.
- **7-Zip check for anyfmt:** if anyfmt ships 7-Zip, confirm whether the build includes the unRAR code. That code has a licence restriction separate from the LGPL. Daisy doesn't address this.

**Architecture**
- Homebrew no longer publishes x86_64 bottles for pandoc, qpdf or sevenzip, so Daisy's bundled engines are arm64 only.
- Its engine locator reads each candidate's Mach-O header, walking fat slice tables, and skips binaries with no slice for the running CPU. It searches the app bundle, then Application Support, then `PATH` and the Homebrew prefixes.
- Lesson: decide our Intel story up front. Either build universal engines from source, or declare the Intel engine paths unsupported.

**Bring-your-own LibreOffice.** Daisy uses `/Applications/LibreOffice.app` or a copy in Application Support, and never downloads it. Text documents go to PDF through AppKit's own text and print system, with no LibreOffice needed (`48e042b`).

**Routing is minimal.** The first converter that lists the target wins. There's no graph search, and multi-step conversions are hand-coded inside each converter. anyfmt's capability registry plus router (below) is a real step up.

### 7. Lessons for anyfmt's DragProbe (Phase 0)

1. Test **both** of these and compare:
   - (a) event-driven: global and local mouse monitors;
   - (b) a pure polling loop that reads `pressedMouseButtons`, the drag pasteboard's `changeCount` and `modifierFlags`, with no monitors at all.

   Polling also gives us modifier *taps* without asking for any permission. Record the latency and CPU cost of each.
2. Capture the changeCount baseline at mouse-down. Treat a drag as "files" only after the count advances *and* the types include a file URL or promise. Never fail open on a count that hasn't moved.
3. Recover from missed mouse-ups by checking `pressedMouseButtons`. Use one dismiss path, with a short grace period (100–150 ms) so `performDragOperation` lands first.
4. Show the overlay with `orderFront` only, as a non-activating panel. Make it key only after the drop.
5. Accept file promises from the start, with a staging folder, a timeout and cleanup at launch.
6. Log every probe event unbuffered (Daisy learned this in `041b954`) with timestamps, then run the BUILD.md edge-case list against it.

---

## convt

convt is a Rust engine with a GPUI desktop app, a CLI, a Finder Sync menu and a paid cloud API. It's AGPL-3.0-only and sells signed builds. The routing design is spread across `AGENTS.md`, `docs/plan.md` and `crates/convt-core` (`engine.rs`, `registry.rs`). Below are the ideas only, in our own words.

### How routes are modelled

- **Format** is a static table entry with a stable id, a display name, a **category** (image, vector, video, audio, pdf, document, presentation, spreadsheet), its extensions (the first one is used for output) and a MIME type. There's also a per-format "can keep transparency" fact, so images going to JPEG are flattened onto a background.
- **Engine** is one backend. It provides:
  - an id;
  - an integer **priority** (default 0; higher wins);
  - an **"unavailable reason"** (missing binary, missing library, wrong OS) that is checked when it registers;
  - a list of **direct steps** `(from, to)`;
  - a convert call.

  The convert call gets an empty, private output folder and returns *every* file it wrote. That makes paged output (PDF to one PNG per page) part of the contract.
- **Registry.** Registering an engine skips it, and records why, if it's unavailable. Otherwise its steps are merged into an adjacency map that keeps **one edge per (from, to) pair: the engine with the highest priority**. Ties keep the engine registered first. The skipped engines and their reasons show up in `convt engines`, which helps users understand why a target is missing.
- **Route (Plan)** is the ordered list of `(engine, step)` hops, printable as `heic -[img]-> png -[pdf]-> pdf` for logs and debugging.
- **Convention:** adding a format means declaring a step on an engine, and the registry finds the chains. A native or hardware path gets a higher priority than the fallback. On macOS, ImageIO HEIC sits at priority 20, above libheif at 10. Every client (CLI, app, Finder extension, Linux menus, cloud worker) gets conversions from the same default registry, and nothing is allowed to bypass it.

### Path search

- **Unweighted BFS** from the source format, with a depth map and a parent map.
- **Determinism fix.** Hash-map iteration order changes between runs, so equal-length routes were being chosen at random. Neighbours are now visited in a fixed order:
  1. engine priority, highest first;
  2. preferred **lossless intermediates** first (png, tiff, wav, flac, mkv, pdf, odt, ods, odp);
  3. format id, alphabetically.

  A test repeats the same plan 50 times and expects the identical route every time.
- **Same format to same format is "no route".** Same-format operations are tools, not conversions.
- `targets(from)` runs the planner against every format and keeps the ones that succeed, sorted by category and then name. It's simple; one BFS per target.
- **Menu targets** are a separate, curated short list per category: the 3–4 "popular" targets, filtered to what's reachable. The user can override them, and the menu falls back to the default list so it is never empty. Everything else stays one click away in Quick convert. That separation, between all reachable targets and the ones worth a wheel slot, is directly useful for anyfmt's ring.

### Hop limits, cost and priority

- **Max 3 hops.** The code comment argues that longer chains are nearly always lossy detours.
- There's **no cost function.** Hop count is the only distance. Priority does two things: it picks the single engine for each edge at registration, and it orders exploration within one BFS layer, which decides ties between equal-length routes. A shorter route always beats a longer one, whatever the engines' priorities.
- Lossless-intermediate preference applies **only on ties.**

### How it avoids silly routes

- **The still-to-media guard.** A multi-hop route may not *produce* a video or audio format from a non-media source. Only a direct step can do that. So an SVG never offers MP4 by way of PNG to GIF to MP4. Inside the BFS, an edge is skipped when it isn't the first hop, it leads to a media format, and the source isn't media.
- The hop cap and the lossless tie-break do the rest.
- **Side effect worth noting.** The guard is keyed on *category*, and GIF is an image. So GIF to MP4 (a direct step) works, but **GIF to WebM through MP4 is rejected**, and a unit test asserts that. Animated GIF to WebM is a reasonable request. The category-based rule is too coarse here.

### How a route is executed

- Every hop runs on **every artifact** the previous hop produced, and each file carries the page index it came from. This fixed a real bug, noted in `docs/plan.md`: PDF to WebP through PNG used to drop every page after the first.
- Progress is scaled per hop and per artifact into one overall fraction. Cancellation is checked between artifacts.
- An engine that returns no files, or a file outside its private folder, is an error.
- **Staging** happens in a hidden temporary folder *inside the destination folder*, so publishing is a rename on the same volume.
  - Final names are reserved by exclusive create, with ` (1)`, ` (2)` on a collision and `-2`, `-3` for pages. So **the input or an existing file is never replaced**, and two jobs that pick the same name both survive.
  - Failure or cancel removes everything the job wrote.
  - Tests cover each of these.

### What anyfmt should take, and what to change

**Take**
- The engine/step/priority/availability split.
- Paged artifacts as a first-class part of the contract.
- Deterministic tie-breaking.
- The 3-hop cap.
- The still-to-media rule.
- The publish model: stage in the destination, reserve names, never overwrite.
- The separate curated list of targets for the ring.
- The `describe()` string for logs.

BUILD.md's Router spec ("cap hops at 3; a still format can never route into video/audio except by a direct step") already matches.

**Change**
- **Use a weighted search (Dijkstra) under the hop cap**, with an explicit cost per edge:
  - a hop penalty;
  - an engine cost (native Apple framework < bundled CLI < optional pack);
  - a lossy-step penalty.

  That makes "prefer native" and "avoid lossy intermediates" real rules instead of tie-breakers. It also allows a two-hop native route to beat a one-hop slow fallback when we want that.
- **Keep ranked alternatives per edge**, not just the top one. Then a runtime failure of the preferred engine (a codec missing from a build, say) can retry on the next one.
- **Make the media guard property-based.** Treat an animated or time-based input such as an animated GIF, APNG or animated WebP as media for this rule, so GIF to MP4 to WebM is allowed while SVG to MP4 stays blocked.
- **Compute targets in one pass.** A single bounded search from the source gives every reachable target. Then intersect across a multi-file drop, as the BUILD.md "multi-file intersection" requirement asks. That replaces one planner run per format.
- **Grade route quality**, so the wheel can mark a lossy or slow route (for example PDF to DOCX) and PARITY.md can report it honestly.

### Other convt ideas worth noting

- **Finder Sync extension design.** The extension is sandboxed, so it never probes engines. The app writes the target table to an **App Group container** whenever engines or settings change.
  - The extension builds its menu from that table. It hands requests back as small JSON files in the container plus a custom URL, because AppKit drops launch arguments from sandboxed callers.
  - Caveat: **App Groups don't work for ad-hoc signed builds**, so the menu shrinks to "Open in…". There's also a Services-menu fallback.
  - Whether the extension is enabled is detected through `pluginkit` and polled once a second during onboarding.
- **Licence inventory discipline** (`docs/licence-inventory.md`):
  - It treats a link to an upstream repo as *not* being corresponding source for a patched binary.
  - It records that passing `libx264` to FFmpeg makes the build GPL.
  - It treats codec patents (H.264, HEVC, AAC) as separate from copyright.
  - It prefers macOS system codecs where they cover the format.

  anyfmt's `LICENSES/` and NOTICE work should follow the same discipline.
- **Business model.** convt sells signed builds and a 7-day trial under AGPL. It says plainly that builds from source are unrestricted and the AGPL allows removing the licence check. That's allowed under AGPL. A **Mac App Store or proprietary build is a different matter**: it needs relicensing rights (see `CLA_RESEARCH.md`). convt has no CONTRIBUTING file or CLA; 106 of its 114 commits are by the owner.

---

## Other prior art

Short notes on other open-source shelf and wheel apps and on drag-detection techniques. We read short excerpts of the drag-detection files (via the GitHub API) for lessons only. GPL-licensed ones are especially off limits for code.

| Project | Licence | What it is | Lesson for anyfmt |
|---|---|---|---|
| [rirachii/converty](https://github.com/rirachii/converty) | GPL-3.0 | Native Mac converter with a **Shift-drag wheel**, almost the same product idea | While the mouse is down it runs a **40 ms (25 Hz) timer in common run-loop modes**, as well as reacting to drag events. It confirms a drag once changeCount moves and caches the file list per changeCount. It checks `pressedMouseButtons` to catch missed mouse-ups, waits 150 ms after mouse-up before dismissing, and falls back to the legacy filenames pasteboard type when URL reading returns nothing. It reads file URLs from the drag pasteboard from the background. |
| [edinabazi/Kompakt](https://github.com/edinabazi/Kompakt) | MIT | Image and video compressor with an external drop zone | Combines the mouse-down baseline with a last-seen changeCount, and keeps a **drag-session counter** so a mouse-up queued from an older drag can't dismiss a newer one. Rechecks `pressedMouseButtons` before ending the session; 150 ms grace. |
| [Aimee51819/FileFlipper](https://github.com/Aimee51819/FileFlipper) | MIT | Shift (formats) and ⌥⇧ (tools) mid-drag picker | **Pure polling at 30 Hz** (`pressedMouseButtons`, drag changeCount, `modifierFlags`), with no event monitors or taps, so **no Accessibility or Input Monitoring**. Keeps the baseline fresh while the button is up, so a late poll still sees the drag start. This is the closest model for anyfmt's modifier-tap detection. |
| [FuzzyIdeas/Clop](https://github.com/FuzzyIdeas/Clop) | GPL-3.0 | Clipboard/file optimiser that shows a drop zone during any file drag | **Pasteboard reads are synchronous XPC round-trips.** Doing them on the main thread mid-drag froze the UI for 30 s or more when the pasteboard server was slow (their issue CLOP-273). They now resolve drag contents off the main thread on one serial queue, with an "in flight" flag so 60 events per second don't pile up. They also hit crashes in NSPasteboard's type cache when two threads touched it. Drag state is debounced by 200 ms. |
| [MuQY1818/OpenYoink](https://github.com/MuQY1818/OpenYoink) | MIT | Open-source Yoink-style shelf | **The drag pasteboard keeps the previous drag's contents after the gesture ends**, so a stale file URL can show up on a later non-file drag. A drag only counts once changeCount advances past the mouse-down value. Its screen-edge trigger fires after a dwell time while dragging, at most once per entry into the edge band. |
| [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) | GPL-3.0 | Notch shelf | Uses the same changeCount-plus-type check (file URL, URL or string), then tracks entry to and exit from a screen region during the drag, so the shelf opens only when the drag nears the notch. |
| [Lakr233/NotchDrop](https://github.com/Lakr233/NotchDrop) | MIT | Notch file shelf and AirDrop | Global monitors for mouse moved, down and dragged, plus `flagsChanged` for Option. Its drop target is a fixed region, so it needs little drag classification. |
| [MrKai77/Loop](https://github.com/MrKai77/Loop) | GPL-3.0 | **Radial menu** window manager, triggered by holding a key | Radial-menu UX prior art. It needs Accessibility to move windows and uses active (CGEvent tap) and passive monitors. This shows the permission cost of global keyboard triggers that anyfmt can avoid by polling modifiers. |
| [kando-menu/kando](https://github.com/kando-menu/kando) | MIT (code) | Cross-platform pie menu | Pie/marking-menu interaction ideas (direction-based selection, nested rings). Concept reference only; we didn't review the code. |
| [Dropover](https://dropoverapp.com), [Yoink](https://eternalstorms.at/yoink/mac/) | Commercial | Drag shelves | Both offer several triggers (gestures during a drag, screen-edge or shelf placement, shortcuts), which suggests users want more than one way in. anyfmt's hotkey and drop-onto-ring fallback should be a first-class path, not an afterthought. |

GitHub code search for `"NSPasteboard(name: .drag)" changeCount` in Swift returns about 270 files. The **mouse-down baseline plus a changeCount delta** is the de facto community technique; nobody uses a private API for this.

### Technique discussions and platform risks

- **Convention write-up:** Wade Tregaskis, "[Mac app sandboxing interferes with drag & drop](https://wadetregaskis.com/mac-app-sandboxing-interferes-with-drag-drop/)" (Jan 2024). It describes inferring a drag from global drag events plus a changing drag-pasteboard count, with mouse-up as the end.
  - **In a sandboxed app, reading file URLs off the drag pasteboard breaks access to the dropped file.** Listing types is safe. A security-scoped reading option only partly works around it (FB13520048).
  - This matters for any future **Mac App Store (sandboxed) anyfmt**: it would have to rely on the drop-onto-ring path and read types only before the drop.
- **Thread safety:** Michael Tsai, "[NSPasteboard crashes when handling file promises](https://mjtsai.com/blog/2026/08/03/nspasteboard-crashes-when-handling-file-promises/)" (Aug 2026). NSPasteboard's type cache gets mutated from the main thread and the global dispatch pool at once, which corrupts memory. That is in tension with Clop's move off the main thread. **anyfmt rule: give all NSPasteboard access one owner** (one actor or queue), read only the changeCount and types mid-drag, and read URLs once (`draggingEntered` or `performDragOperation`).
- **Pasteboard privacy:** "[Pasteboard privacy preview in macOS 15.4](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/)". macOS now alerts when an app programmatically reads the **general** pasteboard without a paste-related user action. It adds `accessBehavior` and the `detect…` APIs, which inspect types without reading. The drag pasteboard isn't mentioned. **The DragProbe must confirm that reading the drag pasteboard raises no alert on the macOS versions we target.** anyfmt must never poll the general pasteboard.
- **Stack Overflow:** "[Global drag and drop detection on macOS for files and promised files](https://stackoverflow.com/questions/70544827/global-drag-and-drop-detection-on-macos-for-files-and-promised-files)". The same monitor-plus-pasteboard approach, with promised files as the hard case.
