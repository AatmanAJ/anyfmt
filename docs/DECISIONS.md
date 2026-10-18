# Decisions

Every non-obvious choice, why we made it, and what it costs. Numbered so code
and other docs can cite them (`D-001`). Newest decisions are appended, never
rewritten. If a decision is reversed, a new entry says so.

---

## Phase 0: drag detection spike (`Spikes/DragProbe`)

### D-001 Detecting a Finder drag + modifier tap from a background app

**Winner: zero-permission hybrid (approach A + B-mouse).**

| # | Approach | TCC permission | Verdict |
|---|---|---|---|
| A | Poll `NSEvent.pressedMouseButtons`, `NSPasteboard(name: .drag).changeCount`, `NSEvent.modifierFlags` | **None** | **Ship.** Documented as live device state; used by shipping apps (research/PRIOR_ART.md, research/PLATFORM_RESEARCH.md A3). |
| B-mouse | Global `NSEvent` monitor for `leftMouseDown/Dragged/Up` | **None** | **Ship as a wake-up signal** so the poller idles at a low rate when no button is down. |
| B-flags | Global `.flagsChanged` monitor | Conflicting reports (none vs Accessibility) | **Not relied on.** Installed opportunistically: if events arrive they shave ~4 ms, but nothing depends on them. |
| C | `CGEventTap` listen-only | Input Monitoring | Rejected: a permission prompt for something A does without one. |
| D | SkyLight / CGS drag notifications, Dock notifications | Private API | **Off-limits** (BUILD.md §12). |

How A works:

1. **Idle**: a 4 Hz timer with 250 ms leeway (coalesced by the OS) plus the global
   mouse-down monitor. Whenever the button is up we refresh the *idle baseline*
   `changeCount` of the drag pasteboard.
2. **Button down**: poll at 240 Hz. A drag has started when the drag
   pasteboard's `changeCount` differs from the idle baseline **and** it carries
   file types (`public.file-url` or promised-file types). We compare against the
   idle baseline rather than the mouse-down snapshot so a late wake-up can't miss
   Finder's write. We never fall back to "N drag events passed" (Daisy's
   heuristic, which summons the wheel on window moves and text drags).
3. **Trigger key**: by default the wheel opens the moment a trigger key goes
   down mid-drag, so a tap and a hold both work (D-035). Keys already held when
   the button went down never count. The opt-in "Only on a quick tap" mode keeps
   the original rule: press then release within the tap threshold (default
   350 ms, user-adjustable) with no other modifier joining in. In that mode
   chords and holds never trigger, so Finder's own ⌘ (move) / ⌥ (copy) / ⌘⌥
   (alias) drag modifiers keep working.
4. Polling continues while the pointer is still, because the OS sends no drag
   events then. This is why a timer is required at all.

**Measured on this machine** (macOS 27.0.1, M5 Max, release build):

| Metric | Result | Method |
|---|---|---|
| Overlay `orderFrontRegardless` → window-server "visible" | p50 **12.3 ms**, p95 **14.8 ms**, max 15.4 ms (n = 60) | `DragProbe --selftest` (occlusion-state notification) |
| Detection delay added by polling | ≤ 4.2 ms (240 Hz) | by construction |
| **Key tap → wheel visible (estimated)** | **p95 ≈ 19 ms** (target < 50 ms) | sum of the two rows |
| Idle CPU of the watcher | **0.15 %** of one core at a 20 Hz idle poll; production uses 4 Hz + mouse monitor | `DragProbe --idle-cpu 20` (`getrusage`) |

**Permissions verified** by `AXIsProcessTrusted() == false`,
`CGPreflightListenEventAccess() == false` and `CGPreflightPostEventAccess() == false`
in the same process that installed the monitors and ran the poller, so nothing
in the shipped path can depend on a grant. The drag pasteboard was read
cross-process with no grant (it still held a previous browser drag's types,
which is also why we compare change counts and never trust leftover contents).

**Not verified here (needs a human, see BLOCKERS.md B-001):** this machine
can't synthesise input (no Accessibility for the harness), so a real Finder
drag with a real key tap has not been observed. DragProbe logs every source
side by side for that run. A clean-user-account check is also listed there.

### D-002 Edge cases (expected behaviour; confirm in the B-001 run)

| Source of the drag | Drag pasteboard mid-drag | Expected | Notes |
|---|---|---|---|
| Finder icon/list/column/gallery view | `public.file-url` items | ✅ wheel + drop | Main path |
| Desktop | same as Finder | ✅ | Desktop is a Finder window |
| Spotlight results | file URLs | ✅ | Spotlight writes file URLs |
| Mail attachments | file promises only | ✅ wheel from promised type; files materialise on drop | `NSFilePromiseReceiver` in `performDragOperation` |
| Browser downloads bar (Safari/Chrome) | file URLs (Safari) / promises (some) | ✅ both handled | |
| Photos | file promises | ✅ | Format comes from the promised UTType |
| Stage Manager | normal | ✅ | Panel joins all spaces |
| Across displays | normal | ✅ | Wheel positioned on the pointer's screen and pushed inward at edges |
| Mission Control active | drag into MC | ⚠️ wheel suppressed while the pointer is in the top 24 pt band (MC/menu bar drag zone) | Avoids fighting the system UI |
| Full-screen apps | normal | ✅ | `.fullScreenAuxiliary` + `.canJoinAllSpaces` |
| Text/image drags (not files) | no file types | ✅ ignored | We require file types |
| Window moves / selections | no pasteboard change | ✅ ignored | |

### D-003 The overlay window

Borderless `NSPanel` with `.nonactivatingPanel`, level `.popUpMenu` (101): above
the Dock (20) and menu bar (24) but **below the drag image (500)**, so the
dragged icon stays on top. Collection behaviour
`[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`,
`hidesOnDeactivate = false`, shown with `orderFrontRegardless()`, never key or
main, so Finder keeps focus and keeps owning the drag. Drag types are
registered before the panel is ordered in. **Every hit area is painted with
alpha ≥ 0.01**, because fully transparent pixels never receive `draggingEntered`.

### D-004 "Enter on a Finder selection"

Full parity (press Return in Finder → wheel) needs **three** grants:
Accessibility and Input Monitoring (an active keyboard event tap to swallow
Return before Finder starts renaming; on current macOS `CGEvent.tapCreate`
fails without Input Monitoring even when Accessibility is granted, as found on
real hardware) and Automation → Finder (Apple Events to read the selection). We ship it as an
**opt-in "Finder shortcut" mode** in Settings › Keys, off by default. The coach
explains each prompt in one sentence, and a failed tap says which grant is missing. While it's on, Return opens the
wheel only when Finder is frontmost, a selection exists, and Finder's focused
element is not a text field (so rename still works).

Zero-permission alternatives, both on by default:
- **Services menu** item "Open in Halo Wheel" (`NSSendFileTypes` + `NSRequiredContext`
  so it's enabled without a trip to System Settings). Users can assign it any
  shortcut in System Settings › Keyboard › Shortcuts › Services.
- **Global hotkey** (Carbon `RegisterEventHotKey`, needs no permission, default
  ⌃⌥Space, must include ⌘ or ⌃) that opens an empty **drop ring** at the pointer.
  Drag files onto it and pick a segment. This is also the BUILD.md hard-stop fallback.

### D-005 Hard-stop rule

Not triggered: mid-drag detection works with public API and no permission. The
hotkey + drop-ring fallback from D-004 ships anyway, so the app stays usable if
a future macOS changes drag-pasteboard behaviour.

---

## Phase 1: contracts

### D-010 One capability table, assembled per lane
`CapabilityTable.default` = concatenation of `ImageRoutes`, `AVRoutes`,
`SubtitleRoutes`, `DocsRoutes`, `ArchiveRoutes`. One declarative source of
truth that the wheel, the CLI, the router and the matrix all read, with
per-lane files so parallel lanes never edit the same file. `integrityIssues()`
(unit-tested) rejects duplicate rows, identity rows, unknown formats, orphan
rows and orphan engines.

### D-011 Router: bounded exhaustive search with a cost model
Formats ≈ 70 and hops ≤ 3, so we enumerate paths exhaustively (microseconds)
instead of BFS. Cost = Σ row cost + 0.5 per extra hop + 1 per lossy
intermediate + 4 per structure-losing step. Prior-art lesson (convt):
unweighted BFS with alphabetical ties picks silly paths. Rules:
still⇄time-based crossing only as one direct step (PNG→GIF→MP4 is never planned;
GIF→MP4 is a direct row, which is fine); `.multiOutput` and `.terminalOnly` rows
only as the final hop; `.combine` rows never chained. Multi-file drags show
the intersection of reachable targets. Files already in the target format are
skipped, but at least one file must need converting.

### D-012 Naming and placement
`name.ext → name.png`, collisions `name 2.png`, `name 3.png`. Tools append
`-<suffix>` (`photo-compressed.jpg`). Multi-file outputs (PDF pages) go into a
fresh folder `name (PNG)`. Placement uses `renamex_np(RENAME_EXCL)`, so even a
file that appears between the check and the move is never clobbered. Format
conversions copy creation/modification dates from the source; tools don't.

### D-013 Brand in one place
`Config/Brand.xcconfig` (`BRAND_NAME`) + `Sources/Shared/Brand.swift` (`name`).
Bundle id, URL scheme, CLI name and window titles all derive from these. Swift
module names are fixed (`HaloCore`, `HaloApp`, `HaloCLI`) so a rename never
touches `import` lines.

### D-014 Module split
`HaloCore.framework` (no UI: Shared, Engine, Jobs/Core, Tools/Core) is linked by
the app, the `halo` CLI and the matrix runner. App-only code (wheel, editors,
actions, cloud, settings, progress windows) lives in the app target. The two
MIT packages are local SwiftPM packages with no dependency on Halo.

---

## Engines

### D-020 ffmpeg 9.0.2, GPL, built from pinned source (`Engines/build-ffmpeg.sh`)
Shared libav* dylibs with every codec library linked statically, so ffmpeg and
ffprobe share one copy. **39 MB total** for ffmpeg, ffprobe, the libs and resvg.
Built with `--disable-network`, so the bundled engine cannot open a socket
(only file/pipe protocols). Codecs and why:

| Library | Version | Licence | Why |
|---|---|---|---|
| x264 | stable@b35605a | GPL-2.0+ | H.264 software encode (quality reference, non-VT paths) |
| x265 | 4.2 | GPL-2.0+ | HEVC software encode (MKV/HEVC when VT unavailable) |
| libvpx | 1.17.0 | BSD-3 | VP8/VP9 for WebM |
| libaom (encoder only) | 3.15.2 | BSD-2 | AV1 for WebM/MKV and AVIF stills on macOS < 14 |
| dav1d | 1.5.4 | BSD-2 | AV1 decode on M1/M2 (no HW AV1 decode before M3) |
| opus | 1.6.1 | BSD-3 | Opus audio |
| libvorbis/libogg | 1.3.7 / 1.3.6 | BSD-3 | Ogg Vorbis (ffmpeg's native vorbis encoder is experimental) |
| LAME | 3.100 | LGPL-2.0 | MP3 |
| libwebp | 1.6.0 | BSD-3 | WebP stills + animated WebP (ImageIO never encodes WebP) |
| VideoToolbox / AudioToolbox | system | Apple | Hardware H.264/HEVC/ProRes, `aac_at` |

### D-021 resvg 0.48.1 for SVG input
Apache-2.0 OR MIT, 2.9 MB, built with cargo `--locked`. More faithful than
WebKit snapshots and works headless (CLI, matrix).

### D-022 pandoc is **not** bundled (192 MB binary)
pandoc 3.12.1's arm64 binary alone is 192 MB, which blows the 150 MB app budget.
Platform research also showed NSAttributedString/`textutil` drop tables, lists,
images and links when *writing* DOCX. So the default pipeline is our own
document model with our own DOCX/ODT/EPUB/HTML/Markdown writers (lane F), and
pandoc is an optional, user-initiated, checksum-verified **pandoc pack**
(`EngineIDs.pandocPack`) for anyone who wants pandoc's fidelity. Zero install by default.

### D-023 Archives use the system's bsdtar/ditto
macOS ships `/usr/bin/bsdtar` (libarchive 3.7.4): it writes zip/tar/gz and reads
zip, tar, gz, 7z, RAR and RAR5. Zero size cost, and nothing for users to
install. `ditto` keeps resource forks/xattrs for Finder-faithful zips.
Limits (encrypted RAR, some solid RAR5) are listed in PARITY.md.

### D-024 Sparkle 2.10.0 (MIT) for updates, off by default
`SUEnableAutomaticChecks = NO`; the updater isn't even started unless the user
opts in during onboarding or in Settings. No system profiling. EdDSA private
key never committed (BLOCKERS.md B-005).

### D-025 UI tests vs unattended runs
macOS UI testing needs Automation Mode, which needs an admin password to enable.
The Wheel Gallery and editor screenshots are therefore rendered **offscreen**
(`NSView` caching) by `make gallery`/`make test`, and the XCUITest suite runs
under `make uitest` once a human enables Automation Mode (BLOCKERS.md B-003).

### D-026 Contributor agreement: lightweight licence-grant CLA via CLA Assistant
See research/CLA_RESEARCH.md. Cap uses neither CLA nor DCO (so it can't
relicense outside contributions). Grafana, Plausible, Element, Mattermost,
Cal.com, Twenty and Documenso use CLAs, and Grafana and Cal.com have actually
relicensed. We need the right to ship a paid desktop licence or a Mac App Store
build (incompatible with AGPL unless the copyright holder relicenses), so we use
a short licence grant (not an assignment) with an explicit relicensing clause
and a promise that each contribution also stays available under AGPL. Enforced
by hosted CLA Assistant, one click per contributor. DCO-plus-clause was
rejected because a sign-off doesn't show that the extra clause was seen.

---

## Integration

### D-030 Lane decisions
Each lane recorded its decisions in its notes file; they're part of this log by reference:
[A DragSense](lanes/A-dragsense.md) (A-1…A-13) · [B Wheel](lanes/B-wheel.md) (D-B01…D-B12) ·
[C Jobs](lanes/C-jobs.md) (D-C1…D-C14) · [D Image + PDF](lanes/D-image.md) (D-D1…D-D15) ·
[E Audio/Video/Subtitles](lanes/E-av.md) · [H Actions](lanes/H-actions.md) (H-1…H-9) ·
[I Cloud](lanes/I-cloud.md) (D-I1…D-I12) · [F Docs/Sheets/Archives](lanes/F-docs.md) (D-F01…D-F18) ·
[G1 Image tools](lanes/G1-image-tools.md) · [G2 Media tools](lanes/G2-media-tools.md) · [P UI](lanes/P-ui.md) (D-P1…D-P7).
The ones that changed a shared contract are applied in the code and listed in `docs/contract-changes/`.

### D-031 Hardened runtime only on Developer ID builds
With hardened runtime on, dyld's library validation refuses to map an ad-hoc-signed
`HaloCore.framework` or libav dylib into an ad-hoc-signed process ("different Team IDs"),
so a local Release build couldn't even launch its CLI or the embedded ffmpeg. Every
Developer ID build (`make dmg` with `DEVELOPER_ID`, the release workflow) sets
`HALO_HARDENED_RUNTIME=YES` and signs every nested binary with `--options runtime`, as
notarization requires. Local ad-hoc builds leave it off. Nothing is weakened for
distributed builds. No `disable-library-validation` entitlement is used.

### D-032 Cross-family multi-hop routes are opt-in on the wheel
With every lane merged, a photo could reach DOCX, EPUB or XLSX via PDF + OCR, and a
spreadsheet could reach RTF via HTML. These routes work, but they clutter the wheel and
surprise people. `Route.isShownByDefault` (one rule, used by the wheel and the matrix
count) hides routes that pass through a `.hiddenByDefault` row or hop between families
(images, text documents, spreadsheets, slides, audio, video, archives) in more than one
step. Direct rows and anything ending in PDF stay visible. All 793 routes still ship:
the CLI, the matrix, and Settings › Formats can switch any target on. 516 are on the
wheel out of the box.

### D-033 Optional packs: Halo never downloads them
F built a checksum-verified installer that installs from a local file only. Settings ›
Engines opens the official download page in the browser, then the user picks the
downloaded file, which is verified against its pinned SHA-256 before installing. The
app makes no network request for packs. The LibreOffice pin is still empty, so that
install is refused until BLOCKERS B-011 is done.

### D-034 String Catalogs are synced by script
`xcodebuild` emits `.stringsdata` but only the Xcode IDE writes them into `.xcstrings`.
`scripts/sync-strings.py` runs after every `make build`. It keeps comments and
translations and marks removed keys stale, so all 1,388 user-facing strings are in the
two catalogs (HaloCore, app).

### D-035 The wheel opens on key-down by default
The first real-hardware session (B-001) found the quick-tap rule too strict: the
user expected to *hold* ⇧ / ⌘ / ⌃ mid-drag, as in the reference app, and fell back
to the Services menu. DragSense now has `TriggerActivation`: `.press` (the default)
opens or switches the wheel on the sample where a trigger key goes down, and a key
pressed before the drag was recognised opens it as soon as the drag is. `.tap` is
the old behaviour. Settings › Keys › "Open the wheel" picks between them, and the
tap-speed slider only shows in tap mode. Trade-off: in press mode, holding ⌘ to
move a file in Finder opens the Tools wheel (⌥ copy is unaffected, it isn't a
trigger). Dropping outside the wheel still moves the file. Users who rely on ⌘-move
pick "Only on a quick tap" or remap the key. Confirmed on real hardware: the wheel
opened mid-drag on ⇧ key-down.

### D-036 A release on a segment waits for AppKit's drop
DragSense polls the button, so it sees the button go up a few milliseconds
*before* AppKit delivers `performDragOperation` to the wheel. The coordinator
used to hide the wheel and cancel on `dragEnded`, which ordered the panel out
before the drop arrived, so every drop was lost (found in the B-001 log: "awaiting
host" then "cancelled" in the same millisecond). The fix keys off what AppKit will
do. It delivers a drop only when the destination's last `draggingEntered` /
`draggingUpdated` answer wasn't empty, and RadialMenu now records that answer as
`acceptsCurrentDrop`. On `dragEnded`, if that answer was "accept" (a segment) or the
pointer is over the options popover, the wheel waits, and `onSelect` reports the
drop to DragSense. A release over the hub, a gap, a disabled segment or another
app hides the wheel at once. A first version waited for any release inside the
panel's frame, and the second hardware try showed the wheel lingering after a
release over the hub, because AppKit sends no drop there. If an expected drop never
arrives, DragSense gives up after `dropResolutionTimeout` (1 s) and its `.cancelled`
state hides the wheel. Confirmed on real hardware: drop on a segment → PDF → PNG
written in 148 ms.

### D-037 The wheel asks the live router on every show
`WheelContentProvider.live()` used to capture one Router at launch, so a pack
installed later never reached the wheel even though the toast said it had. It now
calls `Router.live()` per show, which returns the same memoised Router while
availability is unchanged (availability is re-checked at most every 2 s, or at once
after `Router.invalidateLive()`). Launch, and every pack install or
removal, plans routes from all 59 start formats on a utility-priority task
(`Router.warmLive()`, 188 ms in a Debug build), so the first drag of a format
doesn't pay a cold search (≈ 9 ms). Asking per show exposed the availability
re-check (7–13 ms in Debug) on most shows, since the 2 s cache had usually expired
by the next drag. An expired snapshot is now answered at once and refreshed on a
utility queue, so a show only waits after `invalidateLive()` (a pack change). The
launch prewarm also draws the Convert label style, fetches a file icon, formats a
size and loads every format glyph, so a first show does no one-off work on the
main thread. Debug main-thread cost of a show: 8 ms first, 6 ms warm
(`WheelShowPerfTests`).

### D-038 Aiming mid-drag: sticky selection, ⌥ lock, configure after the drop
Mid-drag the same pointer aimed and configured: the only way into a format's
options was a 0.6 s hover dwell, so moving toward the popover often picked a
neighbouring segment. Aiming now happens during the drag and configuring after it.
- **Sticky selection** (RadialMenu). Once a segment is highlighted, the pointer must
  go `max(30 % of the wedge, 10°)` past its edge to leave it, capped at 45 % so a
  neighbour is always reachable. For 8 inner segments that's 13.5°; outer-ring wedges
  get the 10° floor. The new segment must also hold for **60 ms** (`switchDelay`)
  before it takes, and the ring boundary has ±6 pt of slack. Moves into the hub or
  off the wheel stay immediate, so cancelling never lags. These are starting values,
  to be tuned by hand on hardware (BLOCKERS B-001).
- **Lock: ⌥ tap.** Space was the first idea, but mid-drag Finder is the key app and
  our panel never becomes key, so key events never reach us. Reading Space's state
  from outside needs Input Monitoring, which breaks the no-permission promise (D-001).
  Modifier state is free to read, and ⌥ isn't a default trigger, so DragSense reports
  a quick ⌥ tap while a wheel is open as `lockKeyTapped`. Locked, drift and even the
  hub can't change the target, and a drop anywhere on the wheel lands on it. A cobalt
  outline, the hub pill ("GIF · Locked") and a VoiceOver announcement show the state.
  If ⌥ is remapped as a trigger, the lock key is ignored. In keyboard mode, Space locks.
- **Configure after the drop.** ⌥ *held* at the drop, or a drop on the **tune lip**
  (the outer 12 pt of segments that have options; the pill reads "GIF · Options"),
  asks the host to configure instead of run (`RadialDropTarget.tune`). The drag is
  over by then, so there's nothing left to mis-aim. In keyboard mode, ⌥-Return does
  the same.
- **Preset chips.** Up to three chips outside the rim, shown when locked or after a
  400 ms dwell. Dropping on one runs with that preset. The hit area grows to cover the
  band out to the chips while they show, and a corridor keeps the segment selected on
  the way there, so the drag can't fall through to the window below.

### D-039 Display face: Inter Display (bundled, OFL 1.1); body stays SF Pro
The redesign needs a heavy, tightly tracked grotesk for format names, numerals and
headlines. The reference's face looks like a commercial Helvetica-Now-style
display cut, which can't ship in an AGPL app. **Inter Display** (Inter v4.1, release
2024-11-16, by Rasmus Andersson) is licensed under the **SIL Open Font License 1.1**.
That was verified from the release's own `LICENSE.txt`, not assumed. OFL allows
bundling and redistribution with any software, including GPL/AGPL, provided the
fonts aren't sold on their own and the licence travels with them. Only the two
weights in use ship (`InterDisplay-Black.ttf`, `InterDisplay-ExtraBold.ttf`, about
0.4 MB each, from release zip SHA-256 `9883fdd4…b11e`). They're registered for the
process only (`CTFontManagerRegisterFontsForURL(.process)`), and the licence is in
`LICENSES/inter-4.1/`. Body and labels stay on the system font (SF Pro) for Dynamic
Type, localisation and zero extra size. The sampled indigo top band of the
reference's blue gradient (`#3E28D1`) is kept in the tokens for the record but
unused, because it reads as the purple the brief bans; `band.cobalt` starts from
deep cobalt instead.

### D-040 Pro activation is optional, offline-verified, and gates nothing local
Onboarding ends with "Have a Pro key or account?". The page has a key field and a
sign-in button, and the primary button is still **Start Using Halo**, so skipping
is the default. Nothing nags afterwards. Activation also lives in Settings ›
Account and in the menu bar ("Pro Licence & Account…").
- Keys are `HALO1-…`: Crockford base32 of a length-prefixed canonical JSON payload
  (plan, seats, issue and expiry dates, key id) plus an Ed25519 signature. They're
  verified offline with CryptoKit against a public-key table indexed by key id, so
  keys can be rotated, and stored in the login Keychain. Details are in
  `docs/LICENCE_KEYS.md`.
- An active key only raises the plan reported by the cloud entitlements. Signed out,
  every cloud feature is still unavailable, because the server enforces cloud
  access. `scripts/check-entitlements.sh` still proves that no local feature reads
  entitlements.
- Business model unchanged: local free forever, paid cloud (Pro/Team), and a
  pay-per-use API (`docs/API.md`). There's no commercial-use fee for local features.
  Under AGPL, anyone can build and use the app from source, so such a fee would
  only tax honest users.

### D-041 The CLI is the agent interface; MCP is in-house over stdio
- **One registry.** `halo` links HaloCore, so formats, routes, option schemas
  (`OptionsSchema.forTarget`), presets (the same `presets.json`, re-read whenever
  either process changes it) and estimates are the app's own. `halo schema --json`
  (`schemaVersion: 1`) dumps all of it, so an agent can plan without guessing.
- **Contract.** `--json` on every command. Convert and tool print NDJSON events on
  stdout (start / progress / output / skip / error / done), with human text on
  stderr. Nothing ever prompts. Exit codes: 0 ok, 2 usage, 3 unsupported route,
  4 input, 5 engine, 6 partial batch, 7 cancelled, 8 cloud. The old sysexits
  codes were too coarse for agents to branch on; the mapping is in `docs/CLI.md`.
  Golden tests pin every JSON shape.
- **MCP.** A small hand-written JSON-RPC server over stdio, with no new
  dependencies. The official Swift SDK is MIT/Apache-2.0, but it pulls in SwiftNIO
  and a docc plugin pinned to a branch, and it targets an older spec. The server
  speaks 2025-11-25 (also 2025-06-18 and 2025-03-26) through `initialize`, and
  2026-07-28 statelessly (per-request version, `server/discover`). The official MCP
  Inspector passed `tools/list` and `tools/call`. There's no network and no port:
  local automation goes through the CLI and MCP only, never an HTTP server.
- **PATH symlinks.** Through the cask's or Settings' symlink, argv[0] is plain
  "halo", so the CLI couldn't find its bundled engines and every audio, video and
  SVG route vanished. It now resolves its own Helpers folder.
