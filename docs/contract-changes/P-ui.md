# Contract change requests from lane P (UI: Settings, onboarding, About)

None of these block lane P; each has a local workaround already in place.

## P-1 App-wide accent colour (iris) via the asset catalog

**What:** add a colour set `AccentColor` (light `#6E56F8`, dark `#8B78FF`,
from `DesignTokens.Palette.iris`) to `Sources/App/Resources/Assets.xcassets`
and set, in `project.yml` › targets › App › settings › base:

```yaml
ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
```

**Why:** SwiftUI `.tint` reaches SwiftUI-drawn controls only. AppKit-backed
pieces (NSSwitch, list selection, focus rings, default buttons in alerts)
follow the app's accent colour. With `NSAccentColorName` set, users on the
default "Multicolor" accent get iris everywhere, and users who chose their own
accent keep it (the native rule).

**Workaround in place:** lane P tints switches, sliders and prominent buttons
with `.tint(Color.iris)` and keeps secondary buttons neutral.

## P-2 Bundle the LICENSES folder

**What:** copy the repo's `LICENSES/` into `Halo.app/Contents/Resources/LICENSES`
(folder reference or a build phase).

**Why:** Settings › Engines › "Licence…" / "All Licences…" and About › "Licences…"
open `Bundle.main.resourceURL/LICENSES[/<engine>-<version>]`.
`BundledEnginesTests.testLicenceFoldersResolveForEveryEngine` checks every
engine maps to a folder in that layout.

**Workaround in place:** without a bundled copy (dev builds) the buttons open
`<Brand.sourceURL>/tree/main/LICENSES`.

## P-3 App delegate wiring (orchestrator, `Sources/App/AppDelegate.swift`)

```swift
// applicationDidFinishLaunching, after setActivationPolicy:
if AppShellUI.handleLaunchArguments() { NSApp.terminate(nil); return } // --render-ui-screens <dir>
SettingsWindowController.hooks = SettingsHooks(
    accountPane: { AnyView(AccountSettingsView()) },            // lane I
    terminalPicker: { AnyView(TerminalPicker()) },              // lane H
    packs: { PackManager.shared.statuses },                     // Office / pandoc packs
    onCheckForUpdates: { updater.checkForUpdates() },           // Sparkle
    onUpdateChecksChanged: { updater.setAutomaticChecks($0) },
    onTriggerKeysChanged: { dragSensor.reloadConfiguration(); hotKeys.reregister() },
    onFinderShortcutChanged: { finderShortcut.setEnabled($0) })
OnboardingWindowController.hooks = OnboardingHooks(
    demoWheel: { ctx in AnyView(RadialMenuDemo(ctx)) },         // lane B (optional)
    onFinish: { /* e.g. show a one-time menu bar tip */ },
    onUpdateChecksChanged: { updater.setAutomaticChecks($0) },
    onFinderShortcutChanged: { finderShortcut.setEnabled($0) })
AppShellUI.showOnboardingIfNeeded()
// Menu: "Settings…" → AppShellUI.showSettings()   "About Halo" → AppShellUI.showAbout()
```

`--reset-onboarding` / `--show-onboarding` (used by `Tests/UI/OnboardingUITests`)
are handled by `AppShellUI.handleLaunchArguments()` too.

## P-4 Makefile: `make screens` (optional)

```make
screens: build
	$(PRODUCTS)/Halo.app/Contents/MacOS/Halo --render-ui-screens $(CURDIR)/docs/screens
```

Until then: `TEST_RUNNER_HALO_WRITE_SCREENS=1 xcodebuild … test -only-testing:AppTests/UIScreenshotTests`.

## P-5 FYI: UI-state keys outside AppSettings (no API change)

Not user settings, so they don't belong in `AppSettings` and `resetAll()`
correctly leaves them alone:

| Key | Where | Meaning |
|---|---|---|
| `ui.settings.lastPane` | `AppSettings.defaults` | Settings opens on the last pane used |
| `ui.permissions.asked.<permission>` | `UserDefaults.standard` | The coach already showed macOS's prompt once; next time it deep-links straight to the pane |

## P-6 FYI: placeholder `SUFeedURL`

`project.yml` ships `https://updates.example.invalid/appcast.xml`. The update
opt-in one-liner shows the feed's host ("Checks <host> daily. Nothing else is
sent."); for a `.invalid` host it says "the Halo update server" instead.
Set the real feed URL before release and the line names it automatically.
