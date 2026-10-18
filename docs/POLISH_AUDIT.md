# Polish audit

## v2 (phase 2 redesign, 2026-10-18)

The question again, after the redesign: **where is each surface still worse than
a top-tier Mac app, and what did we do about it?** Per-area notes, with
before/after tables, are in `docs/redesign/`, and the side-by-side page is
`docs/REDESIGN.md`.

Legend as below: ✅ equal or better · 🔧 fixed in this pass · ⚖️ accepted, with
the reason · 👁 needs hands on real hardware (BLOCKERS B-001)

### System-wide

| Item | Status |
|---|---|
| One token system (primitives → semantic → component). No literal colours, font sizes or radii in UI code: `scripts/check-tokens.sh` runs in `make test` (148 hits at baseline, 0 now) | 🔧 |
| Palette: cobalt / orange / flame on near-black. No purple, no green, no gold. Errors always carry an icon and a label | 🔧 |
| Type: Inter Display for format names, headlines and numerals (OFL, D-039); SF Pro everywhere else | 🔧 |
| Two radii (tile, pill) plus the wheel's segment corner. One elevation shadow. No glow, no glass on the wheel | 🔧 |
| Motion: named curves (`DesignTokens.Curve`: snap, glide, settle, exit) through `HaloMotion`. Reduce Motion becomes a ≤ 120 ms crossfade on every surface | 🔧 |
| Increased Contrast / Reduce Transparency: bands become flat fills and outlines appear, on the wheel, cards, onboarding and cloud screens | 🔧 |
| Contrast: every semantic text pair is AA. White on orange (2.2:1, as in the reference) is never used; orange takes black text | 🔧 |
| App icon, menu bar glyph and DMG background in the new palette, with small icon sizes redrawn rather than scaled | 🔧 |
| Strokes on rounded shapes notch in offscreen renders on this macOS, so borders that matter are drawn as fills (`haloBorder`, `PillBorder`). Live rendering is unaffected | ⚖️ |
| Focus rings on custom pills use SwiftUI's ring in the system accent. Visible, but not cobalt; matching the user's accent is also what Mac apps do | ⚖️ |
| Settings screenshots render light and dark only; cloud screens also render Increased Contrast | ⚖️ |

### Wheel and options

| Item | Status |
|---|---|
| Aiming vs configuring on one pointer: sticky selection (30 % / 10° + 60 ms), ⌥-tap lock, the tune lip and ⌥-drop open a pinned panel after the drop (D-038) | 🔧 |
| The new look: black disc, charcoal wedges, display-type names, heat-band hover with black text, cobalt lock/lip/chips (D-042) | 🔧 |
| Presets: chips on the wheel, Last used, Settings editing, shared with the CLI, synced | 🔧 |
| The options panel shows live size, duration and frame estimates (Estimator: GIF −8…0 %, video +2…5 %, images exact ≤ 4 MP) | 🔧 |
| How the hysteresis numbers, lock, lip and chips feel mid-drag | 👁 |
| Haptics mid-drag: macOS drops haptics from an inactive app | ⚖️ |

### Onboarding and About

| Item | Status |
|---|---|
| Editorial pages, one band each, display headlines, pills; the demo wheel matches the real one | 🔧 |
| Permission rows used tinted circles; they now share the Settings glyph tile | 🔧 |
| The demo draws its own wheel (`DemoWheelRing`) instead of hosting `RadialMenuView`. It matches visually; wiring the real view would remove the duplication | ⚖️ |
| Long translations shrink the headline (scale factor 0.5) rather than re-breaking; translators set the line breaks | ⚖️ |
| Full-flow UI test needs Automation Mode (B-003); the logic is covered offscreen | ⚖️ |

### Progress, toasts, menu bar, Float, Move

| Item | Status |
|---|---|
| Cards: big numeral, cobalt band bar, human errors, Copy details with engines, the **quoted command line**, stderr tail and `~` redaction | 🔧 |
| Card hover tests read the real pointer (flaky); a `tracksPointer` switch makes them deterministic | 🔧 |
| The board's "1080p ·" spec in the running detail needs the job to expose an options summary; it shows the ETA for now | ⚖️ |
| The numeral doesn't tick (`numericText` needs macOS 14) | ⚖️ |
| Five stacked 420 pt cards on a 13″ display | 👁 |

### Settings and cloud

| Item | Status |
|---|---|
| Native Settings window on the token surfaces; display type in three deliberate places; pills for primary actions; empty, loading and error states per pane | 🔧 |
| Key caps are pill-shaped at 22 pt (the tile radius is more than half their height); a squarer cap would need a third radius | ⚖️ |
| The share-link sheet still uses a grouped Form inside the editorial panel | ⚖️ |

### Editors

| Item | Status |
|---|---|
| Shell, display-type headers, tiles, chips, cobalt handles with a dark and light double rim that reads on any image; unreadable, loading and failure states everywhere | 🔧 |
| Text fields and two sliders are system-styled (cobalt tint) | ⚖️ |
| The reorder springs in Organize PDF and Join still run when motion is allowed (they honour Reduce Motion) | ⚖️ |
| How the handles and labelled trim handles feel in use | 👁 |

---

## v1 (phase 1)

Every screen and interaction, checked against the reference measurements in
`research/INTERACTION_NOTES.md` and against our own screenshots in
`docs/screens/` (rendered by `make gallery`). The question for each row: **is
there any spot where we're worse?** Every item is either fixed or justified.

Legend: ✅ equal or better · 🔧 was worse, fixed in this pass · ⚖️ worse in a way
we accept, with the reason · 👁 needs the real-hardware look (BLOCKERS B-001)

## The wheel

| Moment | Reference | Halo | Verdict |
|---|---|---|---|
| Open | ≈ 100–130 ms, whole wheel scales up from ≈ 0.5 + fade | ≤ 150 ms, segments stagger out from the hub (8 ms apart), first segment at once; Reduce Motion → 120 ms crossfade | ✅ Reads as fanning out, not a blob growing. Within budget. |
| Key tap → visible | not measurable | ≈ 30 ms p95 (D-001, lane B) | ✅ |
| Segment count | 5–8, single ring | 1–8 on one ring; 9–20 add an outer arc; > 20 pages with dots + "More" | ✅ Images have 11 targets; the reference shows ≤ 8 |
| Hover | instant orange fill, no visible lift | spring lift (1.06 scale, 5 pt outward) + iris fill; hysteresis prevents flicker | ✅ |
| Hover haptics | n/a | called on segment change; macOS ignores it while Halo isn't the active app, which is always the case mid-drag | ⚖️ Platform limit; the only workaround is private API. Works in selection/drop-ring modes. |
| Wheel switch (⇧ → ⌘ → ⌃) | ≈ 100 ms crossfade in place | 160 ms morph: wedges interpolate angles, labels crossfade | ✅ |
| Hub | thumbnail + label pill (hovered name / file size) | QuickLook thumbnail, stacked badge for multi-file, pill shows hovered target / size / "No conversions" | ✅ |
| Multi-hop targets | not shown | subtle "via PNG" subtitle | ✅ |
| Pro segments | n/a | cloud glyph + "Pro" chip; signed-out tap → calm explainer; never in local flows | 🔧 The compact chip overhung outer-ring wedges by a few px; now sits inside (`fix(radialmenu)`) |
| Drop confirm | wheel disappears | 90 ms fill pulse, then dissolve toward the drop point | ✅ |
| Screen edges | not shown | pushed inward on any display; nothing selectable until the pointer moves 8 pt | ✅ |
| Material | light frosted wedges over wallpaper | behind-window vibrancy masked per wedge, hairline inner stroke, light/dark/contrast/opaque variants | 👁 Masks and shapes were verified from our own window captures, but the backdrop can't be captured without Screen Recording. Check `.popover` vs `.hudWindow` live. |
| Options | not shown | hover-hold mid-drag (0.6 s; right-click only in keyboard mode, since the button is held during a drag) → schema-driven popover; the popover is itself a drop target. Phase 2 replaces the mid-drag dwell (PLAN-PHASE2 §B) | ✅ |
| Keyboard | Enter on selection, arrows, Enter, Escape | + Tab cycles wheels, 1–9 jump, Page Up/Down, VoiceOver radio buttons | ✅ |
| Accessibility | not shown | Reduce Motion, Increase Contrast, Reduce Transparency, VoiceOver labels per segment | ✅ |

## Progress windows

| Moment | Reference | Halo | Verdict |
|---|---|---|---|
| Card | ≈ 260 × 70: ✕, title, file name + %, bar | 288 × 70: icon/thumbnail, title, bar, "42% · About 12 s left", ✕ | ✅ adds ETA + thumbnail |
| Placement | top-centre or near the file | just below the drop point, kept on that display | ✅ |
| Several jobs | not shown | up to 5 stacked + "+N more"; batches are one card ("4 of 12 · 2 already JPG") | ✅ |
| Success | card vanishes, file appears | ✓ morph, new name, "Saved beside the original", Finder reveal (merged), auto-close 1.6 s (paused on hover) | ✅ |
| Failure | not shown | human message, Copy details (no full paths), Retry, Close | ✅ |
| Per-file list inside a batch | not shown | not built; Copy details lists every failed file | ⚖️ Optional in the brief. The aggregate card covers the need. |
| Lossless-trim snap note on the success card | n/a | the editor shows the snapped times before saving; the card doesn't repeat them | ⚖️ Trim and split always go through their editor, where the note is shown. |

## Editors

| Moment | Reference | Halo | Verdict |
|---|---|---|---|
| Shell | compact floating card (≈ 290 × 390), Apply | standard window, live preview, options sidebar, **Before / After** (B), "Save copy", Esc | ✅ "Save copy" says out loud that nothing is overwritten |
| Crop video | aspect popup, size readout, W/H sliders, scrubber | rect overlay on the real frame, aspect presets, W/H readout, scrubber; 4:3 really is 4:3 | ✅ |
| Trim | not shown | filmstrip, frame stepping, I/O keys, dashed outline of where a lossless cut lands | ✅ |
| Before / After | none | toggle (B / click) | 🔧 The tooltip promised hold-to-compare; reworded to "Compare with the original (B)" |
| Annotate text | not shown | typed in the sidebar, not on the canvas | ⚖️ Arrows, boxes, highlight and freehand are direct on the canvas. Inline text is a follow-up. |
| Add background | "add a background" screenshot | solid / gradient (presets, angle) / image, padding, radius, shadow, live | ✅ |
| Remove background on macOS 13 | n/a | people only (Vision limit); plain error otherwise | ⚖️ Platform limit; full subject masks need macOS 14 |

## Actions and Float

| Moment | Reference | Halo | Verdict |
|---|---|---|---|
| Control wheel | 6 actions | 6 actions + Pro share link (chip) | ✅ |
| Float shelf | "Float" | pile with count, hover grid, drag-out (⌥ keeps), drop-in, menus, physics, VoiceOver | ✅ |
| Shelf Quick Look / arrow keys | unknown | not built | ⚖️ VoiceOver navigation works. Quick Look needs `QLPreviewPanel` from a non-activating panel, a follow-up. |
| Feedback | unknown | confirmation HUD near the drop ("Copied 3 items") | ✅ |

## App shell

| Moment | Reference | Halo | Verdict |
|---|---|---|---|
| Menu bar | menu | our template ring glyph; recents (10), Float toggle, Settings, updates (opt-in), About; ⌥ shows Wheel Gallery | ✅ |
| Onboarding | not shown | 4 screens; live demo where you drag a sample and tap the real keys; permissions coach with live grant detection; login item; update opt-in | ✅ |
| Settings | not shown | native preference-style toolbar, 7 panes, schema-driven defaults, live key-tap tester | ✅ |
| Accent | brand orange | iris `AccentColor` asset (switches, selections) | 🔧 Added the asset catalog accent, so system controls use iris and not the system blue |
| Strings | n/a | 1,388 strings in two String Catalogs, synced on every build | 🔧 The command line didn't sync catalogs; added `scripts/sync-strings.py` |

## Still to see on real hardware (B-001)

Live vibrancy over a busy wallpaper (light + dark), clicking ✕ on a lower stacked
progress card, and drag-out from the Float shelf into third-party apps. All are
covered by unit tests and offscreen renders; none can be watched without input
synthesis and Screen Recording.
