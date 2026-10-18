# BUILD.md §13 final checklist

Status on `main` at the end of the unattended run (2026-10-18, macOS 27.0.1,
M5 Max). "Evidence" is the command or file that proves it. Anything not fully
true points at the BLOCKERS.md entry that explains it.

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Phase 0 decision documented with permissions and edge-case results | ✅ | `docs/DECISIONS.md` D-001…D-005. Zero-permission approach verified with all three TCC preflights false; latency/CPU self-tests. Real-drag edge cases listed with expected behaviour → **B-001** |
| 2 | DragSense and RadialMenu build and test as standalone MIT packages | ✅ | `cd Packages/DragSense && swift test` (106), `cd Packages/RadialMenu && swift test` (50); each has LICENSE (MIT) + README |
| 3 | Cloud client complete against the mock server; openapi.yaml written; signed-out = zero requests | ✅ | `Server/openapi.yaml` (31 operations), `Tests/Mock/server.mjs`, 66 cloud tests incl. three-way zero-request proof. Sync had no real data source until phase 2 (the button was a no-op); `SettingsSyncSource` now syncs favourites, wheel visibility, format defaults and output naming (`SettingsSyncSourceTests`) |
| 4 | No local feature consults Entitlements (grep-verified) | ✅ | `scripts/check-entitlements.sh` (part of `make test`) |
| 5 | CONTRIBUTING.md with CLA/DCO decision; AGPL source offer covers our code + every bundled engine | ✅ | `CONTRIBUTING.md`, `CLA.md`, D-026, `LICENSES/NOTICE.md`, `Engines/VERSIONS.md`, release workflow attaches engine sources. Owner name + CLA Assistant setup → **B-008** |
| 6 | Shift / Command / Control wheels open mid-drag from Finder, stay open after release, accept the drop | ✅ | Real hardware (B-001 sessions, Debug and Release): ⇧ opens the wheel mid-drag on key-down (D-035). It stays open after the key goes up, ⌘/⌃ switch it in place, and a drop on a segment writes the converted file. A release over the centre closes it (D-036). Opening straight onto ⌘/⌃ takes the same trigger path but wasn't tried by hand |
| 7 | Enter-on-selection works (or is opt-in with the permission explained) | ✅ | Opt-in Finder Return shortcut (Accessibility + Automation) with the permissions coach; zero-permission Services item, menu item and ⌃⌥Space drop ring (D-004) |
| 8 | Remappable keys | ✅ | Settings › Keys → `DragSenseConfiguration.triggers` live (AppCoordinator) |
| 9 | ≥ 275 conversion options shipped, `docs/MATRIX.md` all green | ✅ | **793/793** routes pass (`make matrix`), 516 on the wheel by default |
| 10 | All 26 tools, all 6 actions, Float shelf with drag-out | ✅ | `ToolRunners.all` (26 local + 3 Pro), `ActionPerformer`, `FloatShelf`; per-lane tests |
| 11 | Batch + multi-file intersection + folder handling | ✅ | `Router.commonTargets`, `BatchConversion`, combine rows for folders/archives |
| 12 | Never overwrites, Finder-style collision naming | ✅ | `OutputNamer` (`renamex_np(RENAME_EXCL)`), `OutputNamerTests` |
| 13 | Progress windows, cancel, reveal, human errors | ✅ | `ProgressPresenter`, `JobQueue`; `docs/screens/progress-*.png` |
| 14 | Onboarding with live demo + permission coach | ✅ | `docs/screens/onboarding-*.png`; tap-detector tests |
| 15 | Settings complete | ✅ | 7 panes, `docs/screens/settings-*.png`; UI test written (`make uitest` → **B-003**) |
| 16 | Light/dark/increased contrast/reduce motion/reduce transparency/VoiceOver all checked | 🟡 | Every surface rendered in each appearance (`make gallery`), Reduce Motion paths unit-tested, VoiceOver elements per segment/control. A live VoiceOver pass needs a person → **B-001** |
| 17 | Perf budgets met and recorded | ✅ | `docs/PERF.md`: launch 147 ms, idle CPU 0.22 %, idle 28 MB, 12 MP HEIC→JPG 88 ms, key → wheel visible 43–45 ms live in Release (n = 3; more samples for a p95 → **B-001**) |
| 18 | Zero network calls without opt-in | ✅ | `make netcheck`: 0 sockets (lsof every 0.5 s + nettop) from the app, CLI and engines; ffmpeg `--disable-network`; cloud gate tests |
| 19 | All engines bundled, licences + source offer in `LICENSES/`, app < 150 MB | ✅ | ffmpeg/ffprobe/libav*/resvg in the bundle; `LICENSES/` (also inside the app); **63 MB** app, **27 MB** DMG |
| 20 | DMG builds; notarized if creds present | 🟡 | `make dmg` builds a styled, ad-hoc signed DMG. No Developer ID or notary profile on this machine → **B-002** |
| 21 | README with GIF, CONTRIBUTING, CI green | 🟡 | README with `docs/screens/wheel-demo.gif` and a generated format table; CONTRIBUTING; CI workflows lint-clean (`actionlint`), and the CI job's steps (`make build`, `make test`) pass on a **fresh clone** of `main` (engines cached, as CI does after its first run). No GitHub remote yet, so Actions itself has never run → **B-004** |
| 22 | PARITY.md: feature-by-feature vs the reference, honest | ✅ | `docs/PARITY.md` |
| 23 | POLISH_AUDIT.md closed out | ✅ | `docs/POLISH_AUDIT.md`: every item fixed or justified; 3 live-look items → **B-001** |
