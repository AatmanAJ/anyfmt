# Interaction notes (reference study)

Reference-only study of the two public demo videos of the commercial
drag-to-convert app we benchmark against. **No frames, video or copy from it are
in this repo.** Media lives in gitignored `research/videos/` and
`research/frames/`. This file holds measurements and our own conclusions.

Scope note: the long frame-by-frame study agent was stopped partway, before it
wrote anything. This shorter pass uses contact sheets (5 fps landing, 1 fps
demo) and a 30 fps strip around the wheel opening. Numbers marked ≈ are
estimates from compressed marketing video.

## Sources

| Video | Resolution | fps | Duration | Character |
|---|---|---|---|---|
| landing demo | 3130 × 2160 | 60 | 4.0 s | Zoomed, stylised close-up (scale unknown) |
| product demo | 1316 × 1080 | 60 | 22.5 s | Screen recording on a gradient wallpaper |

Absolute size uses the Finder desktop icon as a ruler: assuming the default
64 pt icon, the product demo shows ≈ 2.2 px per pt.

## Wheel geometry

| Measure | Observed | In points (≈) |
|---|---|---|
| Outer diameter | ≈ 455 px (demo) | **≈ 205 pt → radius ≈ 102 pt** |
| Hub (inner disc) | ≈ 0.30 × outer diameter | radius ≈ 31 pt |
| Segment band | ≈ 0.34R → 1.0R | ≈ 66 pt deep |
| Segments seen | 5 (video→MP4/MKV/GIF/MP3/M4A), 6 (audio), 8 (video tools) | |
| Max segments seen | 8 | |
| Segment shape | Equal wedges, ~2–3° gaps, generously rounded outer corners, soft drop shadow per wedge | |
| Second ring / paging | Not seen in either video | |
| Hub contents | The dragged file's thumbnail sits over the hub. A **pill label** in the hub repeats the hovered segment's name ("SPEED", "TRIM", "MP3"); idle hub shows the **file size** ("2.4 MB") | |
| Labels | Uppercase, bold, ≈ 11–12 pt on conversions; tools add a ≈ 16 pt glyph above a ≈ 8 pt caps label | |

## Material and colour

- Light, frosted, translucent wedges over the wallpaper (vibrancy-like), with a
  faint outer rim. Unhovered wedges are near-white at ~70–80 % opacity.
- **Hover = solid brand-orange fill** of the whole wedge. No scale change is
  visible at 30 fps, so if there's a lift it's under 2 pt.
- The progress window is a light frosted card with a brand-orange bar.
- Only a light appearance appears in either video. Dark mode isn't shown.

## Timing (30 fps strip, 33 ms/frame)

| Event | Frames | ms (≈) | Style |
|---|---|---|---|
| Key tap → first wheel pixel | 1 | ≤ 33 | |
| Open | 3–4 | **100–130** | Whole wheel scales up from ≈ 0.5 with a fade-in; labels fade in about one frame behind the wedges. No per-segment stagger visible. |
| Hover change | 1 | ≤ 33 | Instant fill swap, no visible tween |
| Wheel switch (conversions → tools) | ≈ 3 | ≈ 100 | Crossfade in place; the ring keeps its size |
| Drop → progress card | ≈ 3–6 | 100–200 | Wheel disappears; card fades in |
| Success → output visible | ≤ 1 s | | New file appears beside the original |

## Progress window

- Wide, short card (≈ 260 × 70 pt): ✕ close at top-left, bold title
  ("Converting to MP4" / "Cropping video"), file name + percentage, full-width bar.
- Position varies: top-centre of the screen in one shot, near the drop point and
  screen edge in another. Not stacked in either video.
- No ETA and no explicit success state visible: the card disappears and the
  file appears.

## Editor windows (crop video shown)

- A compact floating card (≈ 290 × 390 pt), not a full window. Title centred, ✕ at top-left.
- Preview thumbnail with drag handles; "Aspect ratio" popup (Freeform…), Reset,
  live pixel size ("960 × 1,152 px"), Width/Height % sliders, a scrubber with
  start/end timecodes (0:00.00 … 0:05.41), and an orange **Apply** button at bottom right.
- No before/after toggle visible.

## Keyboard

- On-screen keycaps in the videos show: Shift → conversion wheel;
  Option + Shift (shown together) → tools wheel. Our spec uses Command (BUILD.md §1);
  the key is remappable either way.

## Where we can do better (measurable)

1. **Open under 120 ms with structure**: a 6–8 ms per-segment stagger out from the
   hub reads as "fanning out" instead of a blob scaling up, still under the
   180 ms budget. Reduce Motion falls back to a 120 ms crossfade.
2. **Hover with depth**: a spring lift (≈ 1.06 scale + 4–6 pt outward) plus the
   fill, so the target is obvious in peripheral vision while dragging.
3. **More than 8 targets without overflow**: a second ring beyond 8 (they never
   show more than 8). Images have 8–12 targets.
4. **Progress window with ETA, stacking and a success tick**, anchored near the
   drop point and pushed on-screen. Theirs shows no ETA and doesn't stack.
5. **Before/after in every editor** (theirs has none), plus "Save copy" wording
   that makes never-overwrite explicit.
6. **Dark mode, increased contrast and reduce transparency** treated as first-class.
   Only light mode is shown for theirs.
7. **Hub states**: file size idle → hovered target name, plus a predicted output
   size where we can estimate it (lossy image/video targets).

## Spec numbers for our wheel (our design, informed by the above)

| Token | Value | Why |
|---|---|---|
| Hub radius | 40 pt | Room for a 56 pt QuickLook thumbnail + label pill |
| Hub dead zone (cancel) | 34 pt | Slightly inside the hub so the edge isn't twitchy |
| Inner ring | 52 → 124 pt | ≈ 20 % larger than reference: easier mid-drag targeting |
| Outer (second) ring | 130 → 192 pt | Only when > 8 targets |
| Max per ring | 8 inner, 12 outer | 8 matches the densest reference wheel; 12 keeps wedges ≥ 30° |
| Segment gap | 2° | Reference ≈ 2–3° |
| Corner radius | 8 pt | |
| Hover | scale 1.06, lift 5 pt, spring response 0.25 / damping 0.8 | |
| Open | 150 ms total; 8 ms stagger per segment; wedges scale 0.6 → 1 + fade | |
| Close | 110 ms collapse to drop point | |
| Wheel switch morph | 160 ms; segments interpolate angles; labels crossfade | |
| Drop confirm | 90 ms fill pulse | |
| Label | 11.5 pt semibold, caps for format labels; tools: 18 pt glyph + 9.5 pt label | |
