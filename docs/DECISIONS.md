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
3. **Modifier tap**: press then release within the tap threshold (default
   350 ms, user-adjustable) with no other modifier joining in. Chords and holds
   never trigger, so Finder's own ⌘ (move) / ⌥ (copy) / ⌘⌥ (alias) drag
   modifiers keep working.
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

Full parity (press Return in Finder → wheel) needs **two** grants: Accessibility
(an active event tap to swallow Return before Finder starts renaming) and
Automation → Finder (Apple Events to read the selection). We ship it as an
**opt-in "Finder shortcut" mode** in Settings › Keys, off by default. The coach
explains both prompts in one sentence each. While it's on, Return opens the
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
