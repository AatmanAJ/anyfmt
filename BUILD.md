# BUILD.md: open-source drag-wheel file converter for macOS

Read this whole file before writing a line of code. This is an unattended, multi-hour run. Do not ask questions mid-run. When you hit a hard stop, write it to `BLOCKERS.md` with what you tried, what's needed from a human, and the exact command or credential required, then keep going on everything that isn't blocked.

Working codename: **Halo**. AJ will rename it. Keep the name in exactly one place (`Config/Brand.xcconfig` + `Sources/Shared/Brand.swift`) so a rename is a two-line change.

---

## 1. Mission

Build an open-source (AGPL-3.0) macOS app that matches **Tangerine for Mac** (tangerineformac.com, Leap Studio, $29.99) on features and on polish, then beats it on two things: everything local is free, and you can read every line. We make money the way Cap (cap.so) does: free app, paid cloud (§9b). Every line of code in this repo is ours. No forks, no vendored apps.

The bar is not "a converter with a wheel". The bar is: someone who paid for Tangerine installs Halo, uses it for a day, and can't name a feature or a moment of polish they lost.

### Reference behaviour (verified from Tangerine's site, App Store listing and press kit, Oct 2026)

- Lives in the menu bar. No Dock icon. No main window.
- **Drag a file in Finder, tap Shift** → a radial wheel of output formats appears around the pointer. Drop on a segment → converted copy is saved beside the original.
- **Tap Command mid-drag** → wheel of file-specific editing tools.
- **Tap Control mid-drag** → wheel of file actions: AirDrop, Float, Copy, Move, Copy Path, Terminal. Works on folders, mixed selections and files with no conversions.
- Release the key and keep dragging: the wheel **stays open until drop or cancel**.
- **Enter on a selected Finder file** opens the format menu without dragging; Command / Control switch wheels; arrow keys choose, Enter applies, Escape cancels.
- Trigger keys are remappable in Settings.
- Only relevant formats/tools show for the dragged file. Multi-file drags show only targets every file can produce, and batch.
- Each job opens a small progress window and reveals finished files in Finder.
- Conversions and edits **always write a new copy**, never overwrite.
- Everything local. No uploads.
- Scale: ~275 conversion options, 26 tools, 6 actions across images, video, audio, PDF, documents, slides, spreadsheets, EPUB, subtitles, archives.
- Requirements: Apple silicon, macOS 13+.

Study before building (reference only, never copy):
- `https://tangerineformac.com/` (landing + demo video at `/videos/tangerine-landing-demo.mp4`)
- `https://tangerineformac.com/press` (screenshots: conversion wheel, advanced tools, edit photo, add background, audio tools; product video `/videos/tangerine-demo.mp4`)
- Download the demo videos, extract frames with ffmpeg at 10fps into `research/frames/`, and write `research/INTERACTION_NOTES.md`: wheel geometry, segment count limits, open/close timing, hover states, label typography, progress window layout, editor window layouts. Measure from frames, don't guess.

Also study `github.com/ishanmalu/daisy` (Swift, PolyForm Noncommercial, so **read for lessons only, copy zero code**). Note its DragMonitor caveats and engine-licensing notes in `research/PRIOR_ART.md`.

### Legal lines (non-negotiable)

- Never use the name Tangerine, its icon, screenshots, video, website copy or colour identity in the app, repo, README or assets. "Inspired by drag-to-convert tools" is the most the README says.
- Our own icon, our own palette, our own copy.
- Licensing follows Cap's split: **the app and the cloud client are AGPL-3.0**. The two reusable pieces other Mac devs will want, `Packages/DragSense` (global drag + modifier detection) and `Packages/RadialMenu` (the wheel component), are **MIT** Swift packages with their own LICENSE files. MIT the parts we want spread, AGPL the product.
- We own all the copyright, so add `CONTRIBUTING.md` with a lightweight CLA or DCO-plus-relicence clause (research what Cap and similar AGPL open-core projects use, pick one, record why). That keeps a future paid desktop licence or App Store build possible.
- AGPL is GPL-compatible, so bundle GPL engines (ffmpeg with x264/x265, pandoc) and the app works with **nothing installed**. That zero-install experience is the core polish advantage over existing OSS attempts. Do not make users `brew install` anything.
- Every bundled engine's licence goes in `LICENSES/` with a `NOTICE.md` and a source-offer section. Every release links its exact source tag.
- Prior art to read for lessons only, zero code copied: `ishanmalu/daisy` (PolyForm Noncommercial) and `opencoredev/convt` (AGPL, Rust engine registry with multi-hop routing; its design notes are worth reading, its code is not ours to take).

---

## 2. Hard constraints

- Swift 6, strict concurrency on. AppKit for the overlay/wheel/event plumbing, SwiftUI for windows (settings, editors, progress, onboarding).
- macOS 13.0 minimum, arm64 only.
- `LSUIElement = YES` menu bar agent.
- Not sandboxed, Developer ID distribution (GitHub Releases DMG + Homebrew cask). Not the Mac App Store.
- Project generated with **XcodeGen** (`project.yml` committed, `.xcodeproj` gitignored). One `make` target per job: `make bootstrap`, `make engines`, `make build`, `make test`, `make matrix`, `make dmg`.
- **Local is sacred.** Zero network calls unless the user (a) opts into Sparkle update checks, or (b) signs in and explicitly uses a cloud feature. Every cloud action is visibly labelled as uploading (cloud glyph on the segment, a one-line "this uploads to {server}" note the first time). No analytics, no crash reporters that phone home, no account prompt on first launch.
- Zero third-party UI frameworks. Dependencies allowed via SwiftPM only when they replace a mountain of work: Sparkle, and whatever the engine research in §5 justifies (record each in `DECISIONS.md` with licence + reason).
- Every user-facing string in a `Localizable.xcstrings` catalog from day one (English only for now).
- No force unwraps outside tests. No `print` in shipping code; use `os.Logger` with subsystem per module.

---

## 3. Repo layout (also the subagent collision map)

```
Halo/
  project.yml
  Makefile
  Config/                 xcconfigs, Brand.xcconfig, entitlements
  Sources/
    App/                  app delegate, menu bar, lifecycle, permissions coach
    Wheel/                app-specific wheel content + overlay host  (lane B)
    Engine/               capability registry, router, job runner    (lane C)
      Image/  AV/  Docs/  Archive/  Subtitles/                       (lanes D, E, F)
    Cloud/                account, entitlements, share links, sync   (lane I)
    Tools/                editor windows + tool implementations      (lane G)
    Actions/              AirDrop, Float shelf, Copy, Move, Path, Terminal (lane H)
    Jobs/                 progress windows, queue, reveal, naming    (lane C)
    Settings/             SwiftUI settings, key remapping, defaults
    Shared/               Brand, logging, file-type utils, design tokens
  Packages/               MIT, standalone SwiftPM, own LICENSE + README + tests
    DragSense/            global drag + modifier detection           (lane A)
    RadialMenu/           generic radial menu component              (lane B)
  Server/                 NOT built in this run: openapi.yaml contract + README only (§9b)
  Engines/                build scripts + pinned versions for bundled binaries
  Tests/
    Unit/  Matrix/  UI/
    Mock/                 local mock server for the cloud contract   (lane I)
    Fixtures/             generated by script, never committed binaries > 1MB
  research/
  LICENSES/
  docs/                   DECISIONS.md, PARITY.md, BLOCKERS.md, ARCHITECTURE.md
```

---

## 4. Phases

Run phases in order. Inside a phase, use subagents (separate git worktrees) for lanes that only touch their own directory. Merge to `main` only when `make build && make test` passes. Commit small, conventional-commit messages.

### Phase 0: the spike that decides everything (do this alone, no subagents)

The whole product rests on detecting "a file drag is in progress and the user just tapped a modifier", from a background app, while Finder owns the drag. Prove it before anything else.

Build `Spikes/DragProbe` as a tiny standalone app that:
1. Detects a system-wide drag start (approach to test: global `NSEvent` monitor for `.leftMouseDragged` combined with polling `NSPasteboard(name: .drag).changeCount`; test alternatives you find in research).
2. Reads the dragged file URLs from the drag pasteboard.
3. Detects a **tap** (press + release within a threshold, distinct from a held key) of Shift, Command, Control during the drag. Test both `flagsChanged` global monitors and polling `NSEvent.modifierFlags`.
4. Opens a borderless, non-activating overlay window at the cursor that **accepts the drop** while Finder still owns the drag session.
5. Logs latency from key tap to overlay visible. Target under 50ms.

Document in `docs/DECISIONS.md`:
- Exactly which TCC permissions each approach needs (Accessibility, Input Monitoring, none). Verify on a clean user account if possible; state how you verified.
- Which approach wins and why.
- Edge cases: drag from Desktop, from a Finder list view, from Spotlight, from Mail attachments, from browser downloads bar, from Stage Manager, across displays, with Mission Control, full-screen apps.

Also spike **"Enter on a Finder selection opens the wheel"**: find a reliable way to read the current Finder selection (Apple Events to Finder needs Automation permission; record the tradeoff). If it needs a permission, make it opt-in.

**Hard-stop rule:** if mid-drag detection is impossible on current macOS without a private API, do not use private APIs. Ship a global hotkey + drop-onto-ring fallback, document precisely why, and keep going.

### Phase 1: contracts (alone, no subagents)

Write these interfaces and freeze them before fanning out:

- `FileKind` + UTType mapping for every format in §5.
- `Capability` registry: a declarative table of `(input UTType, output UTType, engine, options schema, priority)`. The wheel, the CLI and the tests all read this single table. Adding a format = one row plus one engine method. Native/hardware paths get higher priority than fallbacks.
- `Router`: multi-hop path planning across capabilities (cap hops at 3; a still format can never route into video/audio except by a direct step). Multi-file intersection logic.
- Options schema per target (quality, target size, percentage, pages, DPI, video flags) shared by the wheel's options popover and the CLI.
- `Entitlements` protocol (§9b): `isSignedIn`, `plan`, `can(_ feature: CloudFeature)`. Local features never consult it.
- `Job` protocol: progress (`Progress`), cancellation, temp dir, output naming, atomic move into place.
- `ToolSpec`: id, applicable kinds, whether it needs an editor window, default options.
- `ActionSpec`: id, applicable to anything including folders.
- Output naming rule: `name.ext` → `name.png`; on collision `name 2.png`, `name 3.png` (Finder style). Never overwrite. Preserve creation/modification dates where meaningful. Preserve or strip metadata per user setting.

Write `docs/ARCHITECTURE.md` with a diagram (Mermaid) of drag → sense → wheel → router → job → output.

### Phase 2: parallel lanes (subagents, one worktree each)

| Lane | Owns | Done when |
|---|---|---|
| A DragSense | `Packages/DragSense` | Phase 0 winner productionised, unit-tested state machine (idle → dragging → wheelOpen(kind) → dropped/cancelled), key tap vs hold handling, remappable keys |
| B Wheel | `Packages/RadialMenu`, `Sources/Wheel` | See §6. Pixel-perfect, 120Hz-smooth, keyboard-complete. The package knows nothing about files |
| C Engine core | `Sources/Engine` root, `Sources/Jobs` | Router, job queue (concurrency = performance cores − 1 for CPU jobs, 1 for VideoToolbox jobs), cancel, progress windows, reveal-in-Finder |
| D Image + PDF | `Engine/Image` | All image + PDF routes in §5 pass the matrix |
| E Audio + Video + Subtitles | `Engine/AV`, `Engine/Subtitles` | All AV routes pass, VideoToolbox hardware encode where faster, ffmpeg progress parsed live |
| F Docs, Slides, Sheets, EPUB, Archives | `Engine/Docs`, `Engine/Archive` | All routes in §5 pass, or are listed in PARITY.md with the reason |
| I Cloud client | `Sources/Cloud` | §9b client side against a local mock server, fully gated, zero network when signed out |
| G Tools | `Sources/Tools` | All 26 tools in §7 |
| H Actions + Float | `Sources/Actions` | All 6 actions in §8 |

Each lane writes its own tests in `Tests/Unit/<Lane>` and adds its routes to the matrix runner. Lanes never edit another lane's directory; if a contract needs to change, write a proposal in `docs/CONTRACT_CHANGES.md`, finish what you can, and the orchestrator merges contract changes between lanes.

### Phase 3: integration, polish pass, onboarding, settings (orchestrator + one UI subagent)

### Phase 4: matrix, performance, packaging, release prep (orchestrator)

---

## 5. Formats and engines

Target the full Tangerine matrix. For every route, the engine choice is a **research task**, not an assumption: check current docs/man pages/release notes, prefer Apple frameworks (zero size cost), then bundled CLI engines. Record every choice in `DECISIONS.md` with licence and binary size. Keep the final app under **150MB** (Tangerine ships at 97.6MB; beating that is a stretch goal).

| Category | Inputs | Outputs | Notes / starting candidates to evaluate |
|---|---|---|---|
| Images | JPG PNG WebP HEIC TIFF AVIF BMP GIF SVG(input) | JPG PNG WebP HEIC TIFF AVIF BMP GIF PDF | ImageIO first; verify which formats ImageIO can *encode* on macOS 13 vs current (WebP/AVIF encode likely need libwebp/libavif or ffmpeg); resvg for SVG raster; preserve colour profiles + EXIF orientation |
| Audio | MP3 M4A WAV FLAC OGG Opus AIFF WMA(input) | MP3 M4A WAV FLAC OGG Opus AIFF | AVFoundation where it can, bundled ffmpeg for the rest; sensible default bitrates exposed in an options popover |
| Video | MP4 MOV MKV WebM AVI WMV GIF | same + GIF + MP3/M4A audio extract | ffmpeg (GPL build: x264, x265, libvpx, libopus, libmp3lame, libwebp, libdav1d/libaom as justified); h264/hevc via VideoToolbox when faster at equal quality; high-quality GIF via palettegen/paletteuse |
| PDF | PDF | DOCX PAGES PPTX XLSX JPG PNG EPUB TXT MD | PDFKit for render/text; images at 300 DPI, all pages; DOCX/PPTX/XLSX/EPUB/MD from PDF are the hardest routes, research honest options and grade output quality |
| Documents | DOCX PAGES MD TXT EPUB RTF RTFD text-clippings | DOCX PAGES MD TXT EPUB HTML PDF | pandoc (static arm64 build) + `textutil` + PDFKit; `.pages` read/write needs research (package format; Apple Events to Pages only if installed, opt-in) |
| Slides | PPT PPTX | PDF JPG PNG, PDF→PPTX | Research a lightweight renderer. If the only faithful path is LibreOffice, ship it as an **optional, user-initiated "Office pack" download** (clearly labelled, checksum-verified) rather than bundling 300MB, and say so in PARITY.md |
| Spreadsheets | XLSX ODS CSV TSV XLS(input) | XLSX ODS CSV TSV PDF | evaluate pure Swift/C libs for read + write (record licences); PDF via our own table renderer if needed |
| EPUB | EPUB | PDF DOCX TXT MD HTML | pandoc + our PDF path |
| Subtitles | SRT VTT | SRT VTT TXT | pure Swift parser/writer, preserve timing exactly, fixture with edge cases (overlaps, styling tags, BOM, CRLF) |
| Archives | ZIP TAR GZIP RAR(input) 7z(input, stretch) | ZIP TAR GZIP | libarchive/bsdtar; RAR extract via unar or equivalent with a compatible licence; folders → archive; archive → folder |

Count the shipped routes automatically (`make matrix` prints the number). Target ≥ 275 options to match. List anything missing in `PARITY.md`.

---

## 6. The wheel (lane B): polish spec

This is the product. Spend the time here.

- Borderless `NSPanel`, `.nonactivatingPanel`, `.fullScreenAuxiliary`, joins all spaces, level above everything relevant, never steals focus from Finder.
- Material: vibrancy (`NSVisualEffectView`, hudWindow or popover material, test both) with a hairline inner stroke, correct in light, dark, increased contrast and reduce transparency.
- Geometry: the dragged file's real icon/thumbnail (QuickLook thumbnail, `QLThumbnailGenerator`) sits in the hub; segments fan around it. Derive segment count limits and ring sizes from the frame measurements in `research/INTERACTION_NOTES.md`, then do better: when a file has more targets than fit, use a second ring or a paged ring with a clear affordance, never an overflow menu.
- Each segment: format glyph (SF Symbols or our own drawn set), short label, consistent type ramp from `Shared/DesignTokens.swift`.
- Hit testing is angular from the hub, not rectangular, so the whole wedge is the target. Dead zone in the hub = cancel.
- Hover: segment scales/lifts with a spring (response ~0.25, damping ~0.8, tune by eye), haptic tick on segment change via `NSHapticFeedbackManager` on trackpads.
- Open animation: segments stagger out from the hub, total under 180ms. Close: collapse to the drop point. Respect Reduce Motion (crossfade only).
- Switching wheels (Shift ↔ Command ↔ Control) mid-drag morphs, doesn't flash.
- Keyboard: arrows move, Enter applies, Escape cancels, Tab cycles wheels, number keys 1–9 jump to segments. VoiceOver labels on every segment.
- Multi-display + Retina correctness, cursor near a screen edge pushes the wheel inward instead of clipping.
- On drop: segment confirms (brief fill), wheel dissolves, progress window appears near the drop point.

Build a **Wheel Gallery** debug window (hidden menu item with Option held) that renders the wheel for every file kind with fake data, every appearance mode, every segment count 1–24. Screenshot it in `make test` (UI test) into `docs/screens/` so regressions are visible.

---

## 7. Tools (lane G): all 26

Command wheel. Each tool either runs instantly with smart defaults or opens a focused SwiftUI editor window. Editors share one shell: live preview, before/after toggle, options sidebar, "Save copy" primary button, Esc to close.

Images
1. Compress (quality slider, **target file size** mode, **percentage** mode for single files and batches)
2. Resize (presets + exact px + percentage)
3. Crop (free, aspect presets)
4. Adjust (exposure, contrast, saturation, warmth, Core Image)
5. Annotate (arrow, box, text, highlight, PencilKit-style freehand)
6. Redact (box blur/pixelate/solid)
7. Remove background (Vision foreground mask)
8. Add background (solid, gradient, image; the "add a background" editor)
9. Images → collage (grid layouts, gap, background)
10. Images → PDF (order editor, page size)
11. Read QR / barcodes (Vision; copies result, offers to open URLs only after confirmation)

Video
12. Trim (filmstrip scrubber, frame-accurate in/out, lossless when possible)
13. Crop video
14. Change speed
15. Split (at playhead / every N seconds)
16. Join (multi-file)
17. Snapshot frame(s)
18. Compress video (quality presets + target size)

Audio
19. Trim audio (waveform view)
20. Normalize (EBU R128 loudness target)
21. Bleep (mark ranges on waveform, tone or silence)
22. Change channels (mono/stereo/swap)

Metadata (any file)
23. View + edit metadata (EXIF, IPTC, ID3, video tags, PDF info)
24. Strip all metadata

PDF
25. Merge / split / reorganize pages (thumbnail grid, drag to reorder, delete, rotate)
26. Compress PDF (Quartz filters + image downsampling, target size mode)

If a tool turns out to be two features, split it and keep counting. PARITY.md tracks the list against Tangerine's.

---

## 8. Actions (lane H): all 6

Control wheel. Work on files, folders and mixed selections. Never count against anything.

1. **AirDrop**: `NSSharingService(named: .sendViaAirDrop)`.
2. **Float**: a floating shelf (Dropover-style) that holds the dragged items so you can drag them out later. Stacks multiple items, shows thumbnails, drag-out works into any app, survives Space changes, dismisses when empty. Smooth physics on appear/stack.
3. **Copy**: copy items to the pasteboard as files.
4. **Move**: choose a destination (recent folders list + folder picker).
5. **Copy Path**: POSIX paths, newline-separated for multiple.
6. **Terminal**: open Terminal (or user's chosen terminal app: iTerm2, Ghostty, Warp if installed) at the folder or the file's parent.

---

## 9. App shell

- **Menu bar**: template icon (our own design), menu with: Open wheel for Finder selection, Recent conversions (last 10, click to reveal), Float shelf toggle, Settings, Check for updates (if opted in), About, Quit.
- **Onboarding**: 4 short screens, the first is a live, interactive mini-demo where the user drags a sample file inside the window and tries Shift / Command / Control for real. Then a permissions coach that explains each permission in one sentence, deep-links to the exact System Settings pane, and detects the grant live (no "restart the app"). Then launch-at-login toggle (`SMAppService`). Then update-check opt-in.
- **Settings** (SwiftUI, standard toolbar style): General (launch at login, sounds, haptics), Keys (remap the three triggers, tap threshold), Output (save beside original vs chosen folder, naming pattern, keep/strip metadata, reveal after), Formats (default quality per format, hide formats from the wheel, reorder favourites so they sit at the top of the ring), Engines (show bundled engine versions + licences, optional Office pack status), Advanced (concurrency, logs folder, reset).
- **Progress windows**: small, stack neatly when several jobs run, show file icon, name, determinate progress, ETA, cancel. On success: auto-reveal (setting), brief success state, auto-close. On failure: human error message + "Copy details" for bug reports.
- **CLI** (`halo` binary inside the bundle, symlink offered in Settings): `halo convert`, `halo tool`, `halo formats`, using the same capability table. Stretch, but cheap because the engine is shared.

---

## 9b. Business model: free local, paid cloud (Cap-style)

Verified reference (cap.so/pricing + CapSoftware/Cap README, Oct 2026): Cap's app is AGPLv3 with MIT capture crates. Free covers personal local use. Paid tiers add commercial rights, unlimited share links, cloud storage, AI, custom domains and teams. The desktop app can point at a self-hosted server via a "Server URL" setting.

Our split. Locked decision: **nothing that runs on the Mac is ever paywalled.** Every conversion, tool and action is free, including commercial use. That's the whole pitch against a $29.99 local app. We charge only for things that cost us servers.

| Free (forever, offline) | Pro (needs our servers) |
|---|---|
| All conversions, tools, actions, Float, batch, CLI | **Share link**: segment on the Control wheel. Converts if needed, uploads, copies a link. Expiry, password, download count, custom domain on higher tier |
| Unlimited files, no account | **Cloud jobs**: send heavy video conversions/compressions to the cloud when the Mac is slow or on battery, results land beside the original |
| Self-hosting the server | **Sync**: favourites, wheel order, presets, recipes, settings across Macs |
| | **Inbox**: convert from phone or browser and the result drops into a folder on your Mac |
| | **AI tools that need GPUs we pay for**: transcription → SRT/VTT, upscale, high-quality background removal (local versions stay free where Apple frameworks can do it) |
| | Small free quota of share links (e.g. a handful a month, short expiry) so people feel it before paying |

In this run, build **only the client side** (lane I):
- `Sources/Cloud/`: sign-in (email magic link or passkey/Sign in with Apple, research and pick, record why), keychain token storage, `Entitlements` implementation, plan badge in Settings, "Server URL" field for self-hosters (Cap does exactly this), share-link flow, sync engine for settings/presets, cloud-job submission with resumable upload + progress in the normal progress window.
- Pro-only segments show a small cloud glyph and a "Pro" chip. Tapping one while signed out opens a calm, one-screen explainer, never a nag. No upsell anywhere in local flows.
- `Server/openapi.yaml`: the full API contract the client uses (auth, entitlements, share links, uploads, cloud jobs, sync, inbox). `Server/README.md` describes the intended stack options and self-host story. **Do not build the server.** AJ will run that as a separate build.
- `Tests/Mock/`: a tiny local mock server (Swift or Node, whatever is quickest) implementing the openapi contract so every cloud flow is tested end to end with no real backend.
- Verify with network logging that signed-out use makes zero requests.

---

## 10. Quality gates

### Tests
- Unit tests for DragSense state machine, Router, naming, every subtitle edge case, capability table integrity (no orphan engines, no duplicate rows).
- `Tests/Fixtures/make-fixtures.sh` generates a fixture for every input format (use the bundled ffmpeg, PDFKit, textutil, pandoc to create them). No large binaries in git.
- `make matrix`: runs **every route** on its fixture, then validates the output by actually opening it (ImageIO decode, AVAsset/ffprobe probe with duration check, PDFKit page count, archive listing, re-parse for text formats). Writes `docs/MATRIX.md` with pass/fail, time and output size per route. Target 100% of shipped routes passing.
- UI tests: onboarding flow, settings, Wheel Gallery screenshots.

### Performance budgets (measure, write results to `docs/PERF.md`)
- Key tap → wheel visible: < 50ms p95.
- Idle CPU: ~0%. Idle memory: < 40MB.
- App launch to ready: < 300ms.
- 12MP HEIC → JPG: < 400ms. 1 minute 1080p MOV → MP4: report time, must use hardware encode where faster.

### Polish audit
Before calling Phase 3 done, write `docs/POLISH_AUDIT.md`: go through every screen and interaction against the reference frames and list any spot where we're worse. Fix every item or justify it.

---

## 11. Packaging and release

- `Engines/build-*.sh` build or fetch **pinned** arm64 engine binaries with checksums, vendor dylibs, rewrite install names to `@loader_path`, strip. Record exact versions and configure flags in `Engines/VERSIONS.md` (GPL source-offer compliance).
- Hardened runtime on. Codesign every nested binary.
- `make dmg`: signed, notarized DMG with a styled background and Applications alias.
- Signing + notarization need AJ's Apple Developer ID certificate and a notarytool keychain profile. If they're not present: build ad-hoc signed, finish everything else, and put the exact setup steps in `BLOCKERS.md`. Do not stop the run for this.
- Sparkle 2 appcast generation script (EdDSA keys: generate locally, never commit the private key, note in BLOCKERS.md where AJ must store it).
- Homebrew cask file template in `packaging/`.
- GitHub Actions: build + unit tests on every push (macOS arm64 runner). Matrix job nightly.
- README: what it is, a GIF of the wheel (recorded from the Wheel Gallery or a scripted demo), install, permissions explained honestly, format table generated from the capability registry, build-from-source, licence, credits to every engine.
- `CONTRIBUTING.md` with "how to add a format in one row".

---

## 12. Run rules

- Unattended. No questions. Decide, record the decision and the reason in `DECISIONS.md`, move on.
- Verify capabilities against current docs before relying on them. Never assume an API, encoder or flag exists because it used to.
- Subagents only for lanes that own separate directories. Never two agents in one directory.
- Commit after every green step. Never leave `main` red.
- No private APIs. No code copied from Daisy or any non-OSI-licensed project. No Tangerine assets.
- No code copied from convt or any other project. Reading for ideas is fine; every line here is written fresh.
- Never paywall, nag or gate a local feature. Pro checks only ever sit in front of server-backed actions.
- If a route can't be done well, don't ship a bad one. Remove it from the wheel, log it in PARITY.md with what it would take.

## 13. Final checklist (all must be true, or explained in BLOCKERS.md)

- [ ] Phase 0 decision documented with permissions and edge-case results
- [ ] DragSense and RadialMenu build and test as standalone MIT packages
- [ ] Cloud client complete against the mock server; openapi.yaml written; signed-out = zero requests
- [ ] No local feature consults Entitlements (grep-verified)
- [ ] CONTRIBUTING.md with CLA/DCO decision; AGPL source offer covers our code + every bundled engine
- [ ] Shift / Command / Control wheels open mid-drag from Finder, stay open after key release, accept the drop
- [ ] Enter-on-selection path works (or is opt-in with the permission explained)
- [ ] Remappable keys
- [ ] ≥ 275 conversion options shipped, `docs/MATRIX.md` all green
- [ ] All 26 tools, all 6 actions, Float shelf with drag-out
- [ ] Batch + multi-file intersection + folder handling
- [ ] Never overwrites, Finder-style collision naming
- [ ] Progress windows, cancel, reveal, human errors
- [ ] Onboarding with live demo + permission coach
- [ ] Settings complete
- [ ] Light/dark/increased contrast/reduce motion/reduce transparency/VoiceOver all checked
- [ ] Perf budgets met and recorded
- [ ] Zero network calls without opt-in (verify with Little Snitch-style logging or `nettop` during a test run)
- [ ] All engines bundled, licences + source offer in `LICENSES/`, app < 150MB
- [ ] DMG builds; notarized if creds present
- [ ] README with GIF, CONTRIBUTING, CI green
- [ ] PARITY.md: feature-by-feature vs Tangerine, honest
- [ ] POLISH_AUDIT.md closed out
