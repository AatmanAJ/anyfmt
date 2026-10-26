# Lane P (Phase 3 UI): Settings, onboarding, permissions coach, About, OptionsForm

Status: **done**, building clean (no warnings in lane files), 90 lane tests green (91 with the existing smoke test).
Wiring into `AppDelegate` is the orchestrator's (see "Hooks to wire").

## What's built

| Area | Files | Public entry points |
|---|---|---|
| Settings window | `Sources/Settings/SettingsWindowController.swift`, `SettingsModel.swift`, `SettingsHooks.swift`, `Panes/*` | `SettingsWindowController.show(_ pane:)`, `SettingsWindowController.hooks`, `SettingsPane` |
| Settings helpers | `Sources/Settings/Hotkey.swift` (key code + modifiers, validation, recorder), `SettingsSupport.swift` (`NamingPreview`, `ConcurrencyInfo`, `Diagnostics`, `LogsInfo`) | |
| OptionsForm | `Sources/App/Shared/OptionsForm.swift`, `OptionsFormLogic.swift` | `OptionsForm(schema:values:size:)` with `.regular` (rows for a grouped `Form`) and `.compact` (self-contained, for popovers / editor sidebars) |
| Shared UI | `Sources/App/Shared/AnyfmtColors.swift` (iris/mint from DesignTokens), `AnyfmtControls.swift` (switch style, `CardToggle`, `KeyCap`, `FormatChip`, `StatusBadge`, deep links, `onChangeCompat`), `AnyfmtWindow.swift` (⌘W closes), `TriggerKeys.swift` (`TriggerKey`, `TriggerRole`, `TriggerAssignment`, `ModifierTapDetector`), `LocalKeyMonitor.swift` | |
| Permissions | `Sources/App/Permissions/PermissionsCoach.swift`, `LaunchAtLogin.swift` | `PermissionsCoach.shared`, `PermissionRow`, `PermissionsCoachList`, `LaunchAtLogin.shared`, `LaunchAtLoginRow` |
| Onboarding | `Sources/App/Onboarding/*` | `OnboardingWindowController.show(settings:)`, `OnboardingWindowController.hooks`, `DemoWheelContext` |
| About | `Sources/App/About/AboutWindowController.swift` | `AboutWindowController.show()` |
| Entry points | `Sources/App/Shared/AppShellUI.swift` | `AppShellUI.showSettings/showAbout/showOnboardingIfNeeded/handleLaunchArguments` |
| Screenshots | `Sources/App/Shared/UIScreenshots.swift`, `OptionsGallery.swift` | `UIScreenshots.renderAll(to:)`, `--render-ui-screens <dir>` once wired |

### Settings (AppKit window, SwiftUI panes)
- `NSWindow` + `NSToolbar` with `.preference` style, one selectable item per pane with an SF Symbol. No SwiftUI `Settings` scene, no private selectors.
- Remembers the last pane (`ui.settings.lastPane`), title follows the pane, top-left-anchored animated resize per pane (crossfade + frame, instant with Reduce Motion), and live re-fit when a pane's content changes (KVO on `NSHostingController.preferredContentSize`; covered by `testWindowGrowsWhenAPaneRevealsMoreRows`). Formats is a fixed 780×560 pane with its own scrolling.
- ⌘W closes (`AnyfmtWindow`), single instance, closing removes the pane so its `onDisappear` stops monitors and polling.
- **General**: launch at login (always re-reads `SMAppService.mainApp.status`, also on app activation; `.requiresApproval` → "Open Login Items" via `openSystemSettingsLoginItems()`; `.notFound` and register errors explained), sounds, haptics, optional terminal picker hook, update checks opt-in with the honest one-liner ("Checks <feed host> daily. Nothing else is sent.") and Check Now (hook).
- **Keys**: Convert / Tools / Actions pickers over ⇧ ⌘ ⌃ ⌥ fn; choosing a key in use swaps the two (`TriggerAssignment`). Tap-speed slider 0.15–0.8 s (0.05 steps) with a live "Try it" area (local flagsChanged monitor, no permission): "Tap detected ✓ … opens the X wheel", "Held … — not a tap", "⇧ + ⌘ together — not a tap". Drop-ring toggle + hotkey recorder (must include ⌘ or ⌃; also rejects modifier-only keys and shortcuts macOS owns, e.g. ⌘Space, ⌘Tab, ⌃←). Finder Return shortcut opt-in, with inline permission coach rows. Zero-permission Services note with a Keyboard Shortcuts deep link.
- **Output**: Beside the original / chosen folder (Safari-style menu with "Choose Folder…" → `NSOpenPanel`, sheet on the window; missing folder explained), name pattern with {name} {format} {date} chips, live preview through the real `OutputNamer` ("photo.heic → photo.jpg, then photo 2.jpg") and warnings (no {name}, unknown token), metadata policy with a per-choice explanation, keep dates, reveal in Finder.
- **Formats**: segmented Formats | Tools. Formats: searchable list grouped by `FileKind`, a Favourites section with drag-to-reorder (`onMove`) plus Move Up/Down/Remove context menu, star toggles and a hidden-from-wheel marker on every row; detail with Show on wheel, Favourite and a per-format defaults editor (`OptionsForm`). Only values that differ from the schema defaults are stored, and the per-job "convert in the cloud" option is never offered as a saved default (no upsell in local flows). Tools: every `ToolCatalog.local` tool with a Show on wheel switch, grouped by id prefix.
- **Engines**: bundled engine table (name, version, licence, "Licence…" per engine + "All Licences…"), macOS frameworks note, optional packs from the hook with "This downloads N MB from <host> · <licence>", Install / Remove / progress. Header: "Everything here runs on your Mac."
- **Account**: lane I's view via hook, else a calm "Cloud features are optional" panel (no upsell).
- **Advanced**: conversions at once (Automatic (N) = performance cores − 1, from `hw.perflevel0.physicalcpu`), detailed logging, `log show … --predicate 'subsystem == "<bundle id>"'` with Copy Command, `~/Library/Logs/<Brand>` Show in Finder, Copy Diagnostics (versions, macOS, model, engines, packs, settings JSON with the output folder reduced to "custom folder" and any path-like string redacted), `anyfmt` CLI link command, Reset All Settings… with a destructive confirmation alert (keeps onboarding state, notifies hooks).

### OptionsForm
Every `OptionKind`: slider with unit read-out (snapping in the binding, so no tick per step), integer (field + stepper, clamped), decimal slider (signed read-out for ranges through 0), toggle, choice (segmented for ≤ 4 short choices, else pop-up), fileSize (number + KB/MB/GB, decimal like Finder), pageRange / timeRange / text with inline validation hints, colour (`ColorPicker` ⇄ `#RRGGBB(AA)`), rect (four 0…1 fields + validation). Honours `visibleWhen` (transitively: a hidden controller hides its dependants), shows `help` as the grouped-form subtitle, regular and compact sizes. Values are coerced to each kind's canonical form, so `.string("80")` or `.double(80)` stored by another lane still edits correctly.

### Onboarding (720×520, 4 screens)
Progress dots (clickable), ← / → / Return navigation, Skip, Reduce Motion (crossfades, no springs), closing = finished (never nags).
1. **Live demo**: Sample.heic (a generated twilight-lake thumbnail, `SampleArtwork`) on a dotted stage. Own drag tracking (`DragGesture` inside the view, not a system drag); a local flagsChanged monitor and the same tap rule as the sensor (`ModifierTapDetector`, `AppSettings.tapThreshold`, remapped keys). Tap → the wheel opens at the pointer (hook `demoWheel`, fallback `DemoWheelRing`: rounded wedges with even gaps, hub thumbnail, staggered spring open, hover scale + lift, VoiceOver buttons); tapping another key morphs wheels in place; the wheel stays open after the key is released; angular hit test with a hub dead zone that cancels; Esc cancels, Return applies. Dropping on a segment shows the new file appearing beside the original with a check badge and "Saved Sample.jpg beside the original — In Finder it works exactly like this." Tools and actions get their own lines. Hints coach holds, chords, unmapped keys and "drag first". Legend shows the mapped keys and lights the active one. VoiceOver can open each wheel from the tile's actions.
2. **Permissions coach**: "No permissions needed". The Finder Return shortcut is an opt-in switch; its two rows (Accessibility, Automation for Finder) explain themselves in one sentence each, show a status dot and turn into "Granted ✓" live (0.5 s polling of `AXIsProcessTrusted` and `AEDeterminePermissionToAutomateTarget(com.apple.finder, askUserIfNeeded: false)` off the main thread, only while visible). The button shows macOS's own prompt the first time (so anyfmt appears in the pane's list), then deep-links to `…?Privacy_Accessibility` / `…?Privacy_Automation`. No restart. Services alternative noted.
3. **Launch at login** (`SMAppService`, same model as Settings).
4. **Update checks**, off by default, honest one-liner, then "Start Using anyfmt" sets `AppSettings.onboardingCompleted`.

### About
App icon, name, version (build), "Free and open source (AGPL-3.0). You can read every line." + link to `Brand.sourceURL`, credits for every bundled engine from the embedded table (scrolling, faded edge), "Licences…", copyright line.

## Hooks the orchestrator must wire
See `docs/contract-changes/P-ui.md` P-3 for the exact code.

| Hook | Owner | Without it |
|---|---|---|
| `SettingsHooks.accountPane` | lane I `AccountSettingsView` | calm "Cloud features are optional" panel |
| `SettingsHooks.terminalPicker` | lane H | General has no Actions section |
| `SettingsHooks.packs` | Office / pandoc pack manager | "No optional packs are offered in this build." |
| `SettingsHooks.engineVersions` | (default fine) | embedded `Engines/VERSIONS.md` table |
| `SettingsHooks.onCheckForUpdates`, `onUpdateChecksChanged` | Sparkle wrapper | Check Now disabled; the setting still saves |
| `SettingsHooks.onTriggerKeysChanged` | lane A sensor + hotkey registration | settings save; sensor rereads on next launch |
| `SettingsHooks.onFinderShortcutChanged` | Finder shortcut (event tap) owner | setting saves only |
| `OnboardingHooks.demoWheel` | lane B `RadialMenuView` | `DemoWheelRing` fallback (screenshots use it) |
| `OnboardingHooks.onFinish / onUpdateChecksChanged / onFinderShortcutChanged` | app delegate | settings saved only |
| `AppShellUI.handleLaunchArguments()` | AppDelegate | `--render-ui-screens`, `--reset-onboarding`, `--show-onboarding` inactive |

## Decisions (ready for DECISIONS.md)
- **D-P1 Settings is AppKit-hosted, not a SwiftUI `Settings` scene.** We need the `.preference` toolbar, per-pane animated sizing, a remembered pane and identical behaviour on macOS 13–27; the scene API gives none of that reliably and opening it from an agent app needs private selectors on some versions.
- **D-P2 Grouped `Form` panes, iris tint scoped.** Native grouped forms for every pane; `.tint(iris)` only on switches, sliders and prominent buttons so secondary buttons and pop-ups stay system-neutral (root tint turns every bordered button into an iris pill on macOS 26+). App-wide iris for AppKit pieces is contract request P-1.
- **D-P3 Snapshot rendering.** Offscreen windows are never key, so controls draw inactive. Screenshot mode (`EnvironmentValues.isSnapshot`) sets `controlActiveState = .key` / `appearsActive` and swaps NSSwitch for a drawn copy of the active switch; nothing changes in the running app. Windows are ordered in at alpha 0 so nothing flashes on screen.
- **D-P4 Permission prompts only from a button.** Onboarding and Settings never prompt on their own. First press = macOS's own prompt (registers anyfmt in the pane), later presses = deep link. Polling stops when the rows leave the screen.
- **D-P5 Saved format defaults store only differences** from the schema, so an engine changing its default later still reaches users who never touched that option.
- **D-P6 Fallback schemas.** While the capability table is empty (engine lanes not merged) the Formats pane uses `StandardSchemas` by target (`FormatSchemaFallback`); once rows exist, the router's schemas win (first non-empty, highest priority).
- **D-P7 Engine table embedded, drift-tested.** `BundledEngines.versionsTable` is the VERSIONS.md rows verbatim; `BundledEnginesTests` fails if they diverge and checks every engine maps to a `LICENSES/<name>-<version>` folder.

## Screenshots (docs/screens)
Rendered offscreen by `UIScreenshotTests` (D-025). Refresh with
`TEST_RUNNER_HALO_WRITE_SCREENS=1 xcodebuild -project anyfmt.xcodeproj -derivedDataPath build/DerivedData -scheme anyfmt test -only-testing:AppTests/UIScreenshotTests`
(or `anyfmt --render-ui-screens docs/screens` once P-3 is wired). Without the variable the test renders to a temp folder, so `make test` stays clean.

- `settings-{general,keys,output,formats,engines,account,advanced}-{light,dark}.png`, `settings-formats-tools-{light,dark}.png`
- `onboarding-{1,2,3,4}.png` (light) and `onboarding-{1,2,3,4}-dark.png`; `onboarding-1-wheel[-dark].png` (demo wheel open, WebP highlighted), `onboarding-1-done[-dark].png` (confirmation)
- `about.png`, `about-dark.png`
- `options-form-{light,dark}.png`: every OptionKind, regular and compact

Sample state in screenshots: favourites JPG/PNG/WebP/PDF, BMP/TGA hidden, Finder shortcut on with Accessibility granted and Automation not, two sample packs. Version shows "1.0 (100)".

## Tests (Tests/Unit/App/Settings, hosted, suite-named UserDefaults)
90 tests, all passing:
`OptionsFormLogicTests` (visibleWhen incl. transitive and loosely typed, coercion per kind, non-default diff, choice style, file size, hex, rect, page/time ranges), `TriggerAssignmentTests` (swap, repair, model writes + hook), `ModifierTapDetectorTests` (tap, hold, exclusive threshold, chords, other key spoils, reset), `TapTesterTests`, `HotkeyTests` (needs ⌘/⌃, modifier-only, reserved, storage round trip, display), `NamingPreviewTests`, `AppSettingsPersistenceTests` (defaults, full round trip, reset keeps onboarding, hooks, last pane), `BundledEnginesTests` (drift vs VERSIONS.md, parse, licence folders), `DiagnosticsTests` (no paths), `PermissionsCoachTests` (live grant via polling, prompt-then-deep-link, denied automation), `LaunchAtLoginTests` (fake SMAppService), `DemoHitTestTests`, `DemoModelTests` (drag→tap→drop, morph, hold/chord, remapped keys, cancel), `OnboardingModelTests` (incl. closing the window counts as finished and tears down polling), `SettingsWindowTests` (toolbar, resize, remembered pane, live re-fit, ⌘W), `FormatsPaneModelTests`, `UIScreenshotTests`.

```bash
xcodebuild -project anyfmt.xcodeproj -derivedDataPath build/DerivedData -scheme anyfmt -configuration Debug test \
  -only-testing:AppTests/OptionsFormLogicTests … (or just -only-testing:AppTests)
```

## Not done / for PARITY.md and the polish audit
- Real interaction (clicking through panes, dragging favourites, the demo with real keys) wasn't exercised by a human: the harness can't synthesise input. Logic is unit-tested and every screen is rendered; `Tests/UI/OnboardingUITests` needs Automation Mode (B-003).
- Toggle switches in the live app use the system accent until P-1 lands (SwiftUI tint may not reach NSSwitch).
- The tap test area and the demo watch modifiers only inside anyfmt's own windows (by design: no permission). The real drag sensor is lane A's.
- Haptics toggle is stored; delivery during a Finder drag is best-effort (PLATFORM_RESEARCH H).

## Blockers
None.
