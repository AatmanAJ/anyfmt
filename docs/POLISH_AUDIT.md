# Polish audit

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
| Options | not shown | right-click / hover-hold → schema-driven popover; the popover is itself a drop target | ✅ |
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
