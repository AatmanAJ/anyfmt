# Blockers

Hard stops from the unattended build. Each entry says what was tried, what a
human needs to do, and the exact command or credential. Everything not listed
here was finished and is verified by `make test`, `make matrix`, `make perf`
and `make netcheck`.

---

## B-001 One real-hardware session (~15 min) — drags, taps, drops, clicks

**Why blocked.** The build machine's harness has no Accessibility permission and
can't synthesise mouse or keyboard input. So no real Finder drag, key tap,
drop or click was ever performed, even though every path is unit-tested, every
screen is rendered offscreen, and latency, CPU and memory were measured. All
detection uses permission-free public API (D-001).

**What was tried.** Synthesising input from the build harness (`CGPreflightPostEventAccess()` = false,
`AXIsProcessTrusted()` = false). Desktop control (computer use) isn't enabled for the build
session either: no computer-use tools are available. The detection, wheel, drop and job paths are all
covered with fakes in unit tests, and every screen is rendered offscreen.

**Progress: real-hardware sessions (2026-10-18, the user on the dev Mac, Debug then Release builds).**
- ✅ File drags from Finder are detected with no permissions granted (drag
  pasteboard read in 0.6–0.7 ms).
- ✅ The wheel opens mid-drag on ⇧ key-down. The user expected tap *or hold*, so
  key-down activation is now the default (D-035).
- ✅ Drop on a segment → converted file beside the original (PDF → PNG in 148 ms),
  after the lost-drop fix below.
- ✅ Live key → wheel visible, **Release** build: 43.0 / 44.3 / 44.8 ms, all under
  the 50 ms budget (n = 3, so not yet a p95; margin ≈ 5 ms). The Debug builds
  measured 62.1 / 27.8 ms, then 90.5 / 61.6 ms after a per-show availability
  re-check crept in (removed in D-037).
- ✅ ⌘ and ⌃ switch the open wheel mid-drag: 8 switches between Convert, Tools and
  Actions in one drag, each in the same poll sample as its key-down (the redraw
  itself isn't timed). A release over the centre closes the wheel at once (D-036).
- 🐞 Found and fixed: every drop on a segment was lost, because the wheel hid on
  mouse-up before AppKit delivered the drop. Then a release over the hub left the
  wheel open for up to 1 s (D-036). Also found: the wheel never saw packs installed
  after launch (D-037), and the Finder Return shortcut also needs Input Monitoring
  (D-004).
- ⏳ Still to do by hand: opening straight onto ⌘ / ⌃ (only switching was tried), a
  few more latency samples for a real p95, and steps 2–8 below.

**Two ways to finish it:**
- **Let Claude do it:** turn on *Settings → This computer → Computer use* in the Claude desktop
  app, then ask Claude to "run the BLOCKERS.md B-001 session". It can drag in Finder, tap the
  keys and screenshot the results.
- **Do it yourself** (about 15 minutes, on the dev Mac; optionally again on a fresh user account
  to confirm no permission prompt appears):

```bash
make build && open build/DerivedData/Build/Products/Debug/Halo.app
```

1. **Wheels.** Drag a file from a Finder window, tap ⇧ → convert wheel. Tap ⌘,
   then ⌃ → it morphs. Release the key, keep dragging, drop on a segment →
   new file beside the original, progress card near the drop point, Finder
   reveals it. Repeat from the Desktop, a Finder list view, Spotlight, a Mail
   attachment and Photos (file promises). Drop in the hub → cancels.
2. **Multi-file + folder.** Drag 3 HEICs + 1 PNG → only common targets. Drag a
   folder, tap ⌃ → actions; tap ⇧ → archive targets.
3. **Actions.** Drop on AirDrop, Float (then drag items out of the shelf into
   Finder/Mail, with and without ⌥), Copy (⌘V in Finder), Move (recent folders
   + Choose…), Copy Path, Terminal.
4. **Tools.** ⌘ wheel on an image → Crop (editor opens) → Save copy. On a video
   → Trim. On a PDF → Merge/split. Read QR on a QR screenshot.
5. **Options.** Right-click (or hover) a segment → options popover → Convert.
6. **Other ways in.** Finder › right-click › Services › "Open in Halo Wheel".
   ⌃⌥Space → drop ring. Menu bar › Open Wheel for Finder Selection (asks for
   Automation once).
7. **Look.** The wheel's vibrancy over a busy wallpaper, light + dark; stacked
   progress cards (click ✕ on a lower card).
8. **Spike log** (optional): `cd Spikes/DragProbe && swift run -c release DragProbe`
   records which detection source fires first and the trigger → visible latency
   (`~/Library/Logs/DragProbe.log`).

The in-app latency probe (`DragSense.diagnostics.latencySummary()`) gives the
real key tap → wheel visible p95 for docs/PERF.md (the estimate there is ≈ 30 ms).

## B-002 Developer ID signing + notarization

**Why blocked.** No signing identity on this machine (`security find-identity -v -p codesigning`
→ 0) and no notarytool profile. `make dmg` therefore produces an **ad-hoc signed**
DMG (verified: builds, styled layout, launches). Hardened runtime is switched on
automatically for Developer ID builds (D-031).

**Do this once:**

```bash
# 1. Install your "Developer ID Application" certificate in the login keychain (Xcode › Settings › Accounts › Manage Certificates).
# 2. Store notary credentials (App Store Connect API key recommended):
xcrun notarytool store-credentials halo-notary --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-uuid>
# 3. Build, sign, notarize, staple:
DEVELOPER_ID="Developer ID Application: <Name> (<TEAMID>)" TEAM_ID=<TEAMID> NOTARY_PROFILE=halo-notary make dmg
```

For CI, add repository secrets: `DEVELOPER_ID`, `TEAM_ID`, `DEVELOPER_ID_CERT_P12_BASE64`,
`DEVELOPER_ID_CERT_PASSWORD`, `AC_API_KEY_ID`, `AC_API_ISSUER`, `AC_API_KEY_P8` (used by
`.github/workflows/release.yml`).

## B-003 UI tests need macOS Automation Mode

**Why blocked.** `automationmodetool` reports "Automation Mode is disabled. This device
requires user authentication to enable Automation Mode." XCUITest can't run unattended.
Screens are rendered offscreen instead (D-025) and committed in `docs/screens/`.

```bash
sudo automationmodetool enable-automationmode-without-authentication
make uitest
```

## B-004 GitHub repository + CI

**Why blocked.** No remote is configured, and creating a public repository is
publishing, which needs the owner's go-ahead. CI workflows exist
(`.github/workflows/ci.yml`, `nightly.yml`, `release.yml`) and are `actionlint`-clean.
The CI job's steps (`make build`, `make test`) pass on a **fresh clone** of `main`, and
`make matrix` passes locally. That fresh-clone run caught, and led to a fix for, one
timing-sensitive test.

```bash
gh repo create aiwithaj/halo --public --source . --remote origin --push
```

Then check the first CI run. The first engines build takes about 10 minutes and is
cached afterwards, keyed on `Engines/versions.env`. If the slug differs, update
`Brand.sourceURL`, `packaging/homebrew/halo.rb` and the README links.

## B-005 Sparkle update feed

**Why blocked.** It needs a hosting decision and a URL.

- The EdDSA key pair **was generated** (`generate_keys --account halo-updates`). The
  **private key is in this Mac's login Keychain** (item "https://sparkle-project.org",
  account `halo-updates`) and is in no file or repo. The public key is in `project.yml`
  (`SUPublicEDKey`).
- Back up the private key and add it to CI:
  ```bash
  build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account halo-updates -x halo-updates-private.key
  # store the file in your password manager, then:
  gh secret set SPARKLE_ED_PRIVATE_KEY < halo-updates-private.key && rm halo-updates-private.key
  ```
- Set the real feed URL. `SUFeedURL` in `project.yml` is the placeholder
  `https://updates.example.invalid/appcast.xml`. A GitHub Pages URL or a release asset URL both work.
  Update checks stay off unless a user opts in.

## B-006 Cloud server

**Why blocked.** BUILD.md says not to build the server in this run. The client, the
OpenAPI contract (`Server/openapi.yaml`, 31 operations) and a mock server
(`Tests/Mock/server.mjs`) are complete and tested end to end.

- Replace `CloudConfig.defaultServer` (`https://cloud.example.invalid`) in
  `Sources/Cloud/CloudConfig.swift` with the hosted URL.
- Register OAuth client `halo-mac` with redirect `halo://auth/callback`.
- Magic-link email needs a sending provider on the server (see `Server/README.md`).

## B-007 Older macOS versions (13, 14, 15)

**Why blocked.** Only macOS 27.0.1 was available: no VM, no second Mac.

**What is verified without one:**
- The deployment target is macOS 13 everywhere, and Swift makes any unguarded use of a newer API a *compile error*. So a clean build proves every newer call sits behind `#available` with a fallback.
- Every Mach-O we ship has minimum OS **13.0** (`vtool -show-build`: app, HaloCore, CLI, ffmpeg/ffprobe, all libav* dylibs, resvg). Sparkle's prebuilt binaries are 12.0.
- Rows that depend on OS features are gated at runtime, not by version guesses: ImageIO AVIF encode via `CGImageDestinationCopyTypeIdentifiers`, Vision requests, decoders.

**Still untested:** actual runtime behaviour on 13–15. Run `make test && make matrix` on a macOS 13 machine or VM. Expect rows to drop out (e.g. ImageIO AVIF → the ffmpeg fallback; remove background → people only), not failures.

## B-008 Contributor agreement setup

**Why blocked.** It needs the owner's legal name and accounts.

1. Replace `[OWNER LEGAL NAME]` in `CLA.md`. A lawyer review is recommended (research/CLA_RESEARCH.md).
2. Publish the identical text as a public Gist.
3. Link the repo and Gist at <https://cla-assistant.io>. Allowlist `dependabot[bot]` and `github-actions[bot]`.
4. Make the CLA check required on `main` before merging the first outside PR.

## B-009 Camera RAW input needs a real sample

**Why blocked.** ImageIO on macOS 27 classifies hand-written DNGs as plain TIFF (three
layouts tried), so no RAW fixture could be generated. RAW rows aren't shipped,
because every shipped route must pass the matrix.

**Do this.** Add a CC0 camera DNG under 1 MB at `Tests/Fixtures/static/sample.dng`, then
enable the `raw → *` rows in `Sources/Engine/Image/ImageRoutes.swift`. ImageIO already
decodes real DNG/CR3/NEF/ARW files.

## B-010 Homebrew cask

**Why blocked.** There's no release DMG URL yet (B-002, B-004).

```bash
gh repo create aiwithaj/homebrew-tap --public
shasum -a 256 dist/Halo-0.1.0.dmg   # into packaging/homebrew/halo.rb, then copy it to Casks/halo.rb in the tap
```

## B-011 Office pack checksum (LibreOffice)

**Why blocked.** The installer only accepts a pinned, verified file (D-033), and
LibreOffice's SHA-256 can't be pinned without downloading the release. The pandoc pack
is already pinned.

```bash
curl -LO https://download.documentfoundation.org/libreoffice/stable/26.8.1/mac/aarch64/LibreOffice_26.8.1_MacOS_aarch64.dmg
curl -LO https://download.documentfoundation.org/libreoffice/stable/26.8.1/mac/aarch64/LibreOffice_26.8.1_MacOS_aarch64.dmg.asc
gpg --verify LibreOffice_26.8.1_MacOS_aarch64.dmg.asc   # The Document Foundation's release key
shasum -a 256 LibreOffice_26.8.1_MacOS_aarch64.dmg      # → OfficePack.spec.sha256 in Sources/Engine/Docs/Packs/Packs.swift
```

This unlocks the faithful PPT, KEY and ODP routes and the higher-fidelity Office
routes (`.needsPack` rows, already implemented).

## B-012 Open our Office/EPUB output in the real apps

**Why blocked.** Word, Pages, PowerPoint, Excel, Keynote, Numbers, LibreOffice and
Books aren't installed here. Apple's own Office Quick Look generator and AppKit already
read every DOCX, XLSX and PPTX we write, and the EPUB passes structural checks.
`epubcheck` needs Java and the network.

Run `make fixtures matrix`, then open `Tests/Matrix/out/*-to-{docx,odt,xlsx,pptx,epub}/*`
in each app and note any "repair" prompt.

## B-013 iWork opt-in end to end

**Why blocked.** It needs Pages, Keynote and Numbers installed, plus a one-time
Automation consent prompt. It was never run in tests, because the prompt would block.

```bash
defaults write dev.aiwithaj.halo optIn.iWorkAppleEvents -bool YES
halo convert report.pages --to pdf && halo convert notes.docx --to pages
```
