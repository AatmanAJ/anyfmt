# Onboarding and About: redesign notes

The approved direction (PLAN-PHASE2 §2, board `docs/screens/after/direction/6-onboarding-welcome-dark.png`)
applied to the six onboarding pages and the About window.

Renders: `docs/screens/onboarding/onboarding-{1…6}[-dark].png`, `onboarding-2-{wheel,done}[-dark].png`,
`docs/screens/about[-dark].png` (`make gallery`).

## What every page now shares

- **Full bleed.** The window is the page: `bg.window` (near-black `ink.950` in dark, white in light), no
  radial washes, no card outlines. Window grew from 720 × 520 to 760 × 600 so the permissions page fits
  without crowding the footer.
- **Left-aligned editorial column.** 48 pt margins; headline at the top left, then a plain subtitle
  (15 pt, `text.secondary`, a 440 pt measure), then at most one charcoal tile (`bg.tile`, `Shape.tile`).
- **Headlines** are Inter Display Black, uppercase, −3 % tracking, lines set tight (−0.2 em). Line breaks
  live in the localized string (`"Convert\nwhile you\ndrag."`) so translators choose them. VoiceOver reads
  each headline as one header.
- **One band per page, used as a spotlight**: heat column on the welcome page, cobalt column on
  permissions, the hovered wedge's heat band on the demo, a heat strip on About. Launch, updates and
  activate carry none. `BandGradient` swaps bands for a flat fill under Reduce Transparency and
  Increased Contrast.
- **Footer**: Skip as quiet text at the bottom left, progress dots in the middle, Back (quiet pill) and
  the one blue pill (Continue / Start Using Halo) on the right. Dots: the current step is cobalt *and*
  20 pt wide, the rest are 6 pt `dotRest` grey, so state never rides on colour alone.
- **Motion**: page changes slide + fade on `Curve.glide` (0.22 s); under Reduce Motion they crossfade
  in `Curve.reducedCrossfade`. Keyboard paging (← → Return) uses the same animation.
- **No page icons.** The tinted-circle `PageIcon` is gone; the display type carries each page.
- Tokens: `Sources/App/Shared/DesignTokens+Onboarding.swift` (`DesignTokens.Component.Onboarding`).
  `scripts/check-tokens.sh --report` has no hits in these files.

## Per page, before → after

| Page | Before | After |
|---|---|---|
| 1 Welcome | Centred "Welcome to Halo", iris dashed-circle icon, purple radial glow, three icon bullets in an outlined card | "CONVERT / WHILE YOU / DRAG." at 56 pt top left, subtitle, the heat band column on the right (like the board). The three promises sit in one charcoal tile as display tags (LOCAL / PRIVATE / FREE) with one plain sentence each |
| 2 Demo | Centred title, dot-grid stage 640 × 252, purple wheel with SF Symbols in every wedge, iris selection | Split: "DRAG. / PRESS. / DROP." with the instructions and a vertical key legend (key pills + uppercase role) on the left; the stage as a 420 × 392 charcoal tile on the right with the live hint under it. The wheel matches the new wheel look: black disc, charcoal wedges, uppercase display labels, heat band on the wedge under the pointer, black label on the band. No glyphs, no blur, no shadow. The sample photo was a purple twilight; it is now a sunset in the heat primitives with black hills |
| 3 Permissions | Green shield in a circle, centred headline, card overflowing the footer | "NO PERMISSIONS / NEEDED." at 40 pt, cobalt band column (cobalt.700 → 500 → bright → 400, never toward violet). The Finder-shortcut toggle and, only while it's on, the three permission rows in one tile; the old 45 %-opacity greyed list (grey on grey) is gone |
| 4 Launch | Menu-bar icon in a circle, centred | "READY WHEN / YOU DRAG." top left; the launch-at-login tile and footnote sit at the foot of the page, poster style |
| 5 Updates | Download icon in a circle, centred, heart footnote | "STAY UP / TO DATE." top left; the update-check tile and footnote at the foot |
| 6 Activate | Key icon, centred, form-style card with system buttons | The quiet page: "GOT A / PRO KEY?", one sentence (skipping changes nothing), a pill key field, Paste (quiet) and Activate, which stays quiet until a key can be activated and then becomes the orange pill. Sign In… is an inline accent-text link. "Start Using Halo" is the blue default, so skipping reads as the default. Uses `LicenceActivationModel` directly with the same strings as Settings › Account |
| About | Centred big icon with an iris glow, system buttons, tertiary text | A heat strip across the top (pale end on the left so the window buttons stay legible), "HALO" set at 64 pt top left with the icon at the right, version (selectable), the open-source line and link, credits in a charcoal tile with a display "BUILT WITH" header, Licences… as the orange pill, copyright in `text.secondary` |

Behaviour is unchanged: every accessibility identifier (`onboarding.continue`, `.finish`, `.skip`,
`.back`, `.signIn`, `.hint`, `.updateChecks`, `.finderShortcut`, `.progress`, `.demoStage`, `.result`,
`.tryAgain`, `about.source`, `about.licences`) is kept; `onboarding.activate` is new. The demo's state
machine, tap rule, key monitor, VoiceOver actions and staging are untouched; only the stage size and
home/result positions moved to fit the new stage.

## Polish list: where it is still short of a top-tier Mac app

| Gap | Status |
|---|---|
| The app icon (About, Dock) is still the old iris/mint icon, which now clashes with the heat/cobalt palette | Not mine to change (asset owned by branding); flagged |
| Permission rows (`PermissionsCoachList`) keep their own tinted-circle icons and system "Open System Settings" buttons, so the permissions tile mixes two styles | Shared component in Permissions/, outside this area; it should take pills and drop the circles |
| `LaunchAtLoginRow` and the snapshot switch (`HaloSwitchStyle`) are system-styled; the off switch reads grey-on-charcoal in renders | Shared controls (HaloControls / Permissions), outside this area |
| The demo wheel is a black disc in light mode too (like a record on a light tile). If the real wheel gets a light variant, the demo should follow it | Kept dark on purpose for now; revisit with the wheel area's light look |
| The real `RadialMenuView` isn't wired through `OnboardingHooks.demoWheel` yet, so the demo draws its own ring (`DemoWheelRing`) | The fallback matches the board; wiring the real wheel removes the duplication |
| Band colours: each band fades vertically into its neighbour (the `BandGradient` recipe), so the column reads softer than the board's hard stripes | Token recipe is shared; left as is |
| Stroked capsules render uneven ends at small sizes in offscreen renders, so key pills and the key field draw their hairline as two fills (`PillBorder`) | Worked around locally; the shared pill/preset chips show the same artefact on the board |
| Activate has no visible "valid key" preview before pressing; validity only shows after Activate | Model behaviour, unchanged |
| Headline lines use `minimumScaleFactor(0.5)`, so a long translation shrinks rather than re-breaking | Translators set the breaks with `\n`; acceptable |
| No onboarding UI test runs unattended (B-003); behaviour is covered by `OnboardingDemoTests` and the offscreen renders | Unchanged |
