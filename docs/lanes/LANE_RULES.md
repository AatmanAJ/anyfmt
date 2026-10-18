# Rules for Phase 2 lanes

You are one of ten parallel lanes, each in its **own git worktree on its own
branch**. The orchestrator merges your branch into `main` after review. Read
this whole file first.

## Read before coding
- `BUILD.md`: §2 hard constraints, §12 run rules, plus your lane's section.
- `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`.
- `research/PLATFORM_RESEARCH.md`: the sections relevant to you. It's verified on this machine and saves you from known traps.
- The frozen contracts: `Sources/Shared/*.swift`, `Sources/Engine/*.swift` (root files only),
  `Sources/Jobs/Core/Job.swift`, `Sources/Jobs/Core/OutputNamer.swift`,
  `Sources/Tools/Core/ToolRunner.swift`, `Sources/Tools/Core/ToolRunners.swift`,
  `Sources/Tools/Editors/Shell/EditorShell.swift`, `Sources/Tools/Editors/EditorFactory.swift`.

## Ownership
- Edit **only** your lane's directories (listed in your brief) and your test directories.
- **Never edit** frozen contracts, `project.yml`, `Makefile`, `Config/*`, another lane's directories, or docs other than your own notes.
- New Swift files under your directories are picked up automatically after `xcodegen generate`.
- Need a contract change? Write `docs/contract-changes/<lane>.md` (what, why, exact proposed signature), work around it locally, and keep going. The orchestrator merges contract changes between lanes.
- No new SwiftPM dependencies. If you truly need one, propose it in your contract-changes file.

## Build and test
```bash
export HALO_ENGINES_DIR=/Users/lives/Documents/Projects/Codename_Halo/Engines/dist   # bundled ffmpeg/ffprobe/resvg
xcodegen generate --quiet
xcodebuild -project Halo.xcodeproj -derivedDataPath build/DerivedData -scheme Halo -configuration Debug build -quiet 2>&1 | scripts/xcfilter.sh
xcodebuild -project Halo.xcodeproj -derivedDataPath build/DerivedData -scheme Halo -configuration Debug test -only-testing:CoreTests/<YourTestClass> 2>&1 | scripts/xcfilter.sh
# packages:
cd Packages/<Name> && swift test
```
Core tests live in `Tests/Unit/Core/<Lane>/` (target `CoreTests`, `@testable import HaloCore`).
App-hosted tests live in `Tests/Unit/App/<Lane>/` (target `AppTests`, `@testable import HaloApp`).
Other lanes are building at the same time, so use `-quiet` and `-only-testing:` and don't loop full suites.

## Code rules (non-negotiable)
- Swift 6 language mode, strict concurrency complete. Deployment target **macOS 13**: guard newer APIs with `#available` and a graceful fallback. arm64 only.
- No force unwraps (`!`), `try!` or `as!` outside tests. No `print` in shipping code: use `Log.<module>` (`os.Logger`).
- Every user-facing string is localisable: `L("…")` inside HaloCore, `String(localized:)` / SwiftUI `Text("…")` in the app.
- Use `DesignTokens` for sizes, type, colour and motion in UI.
- **No private APIs. No code copied from any other project** (Daisy, convt, StackOverflow-sized snippets included). Write everything fresh.
- Engines and tools write only inside the `outputDirectory` they're given. **Never overwrite or modify user files.**
- **No network calls.** Exception: lane I, against the local mock server only.
- Match the surrounding style. Comment the non-obvious, not the obvious.

## Fixtures
Engine lanes add `Tests/Fixtures/lanes/<lane>.sh` (contract in `Tests/Fixtures/make-fixtures.sh`).
Every input format you ship must have a fixture named `sample.<primary extension>`.
If you can't generate a fixture for a format, don't ship rows from it: list it in your notes for PARITY.md.

## Git
- Commit on your branch early and often, using conventional commits (`feat(image): …`, `test(av): …`).
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every commit must build and pass your tests. **Don't merge, rebase onto main, push, or check out other branches.**

## Notes for the orchestrator
Keep `docs/lanes/<lane>.md` up to date:
- What you built (files, public API)
- Decisions and reasons, ready to move into DECISIONS.md (include licence and size for anything bundled)
- What's shipped (routes, tools, actions) and what isn't (for PARITY.md, with what it would take)
- Contract change requests (summary; the detail goes in `docs/contract-changes/`)
- Test results and any perf numbers
- Blockers needing a human, with the exact command or credential

## Unattended
Never ask questions. Decide, record the decision, move on. If something is
impossible, write it under Blockers in your notes and finish everything else.
Prefer complete, tested and polished over sprawling. Your final message is
your report to the orchestrator: what's done, test results, known gaps.
