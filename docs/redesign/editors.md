# Editors: phase 2 redesign

Area: `Sources/Tools/Editors/**` (the shared shell and kits, plus every editor: crop,
annotate, adjust, redact, add background, collage, images to PDF, metadata, the Read QR
result panel, the image/media option popovers, trim / split / join / crop / snapshot
video, trim audio, bleep, organize PDF). Component tokens live in
`Sources/App/Shared/DesignTokens+Editors.swift` (`DesignTokens.Component.Editor`).

Direction: PLAN-PHASE2 §2 and `docs/screens/after/direction/`.

## What changed

**Shell (`EditorShell`, `EditorChrome.swift`)**

- The window is the chrome: near-black (`bg.window`) in dark, white in light, up into
  a transparent title bar. The canvas sits in a well (pure black / `#F2F2F2`) with the
  tile radius.
- The sidebar opens with the editor's name in Inter Display Black ("CROP", "TRIM",
  "BLEEP", "PAGES" …) and the file name under it, left-aligned.
- Every sidebar group is a charcoal tile (`EditorSection`) with a small uppercase caption.
  Dividers between groups are gone.
- Cancel is a quiet text button, Save copy the blue primary pill (Return). Esc and B keep
  working.
- Before / After is a chip that turns cobalt when on (and says so to VoiceOver).
- Segmented pickers became chip rows (`EditorChoiceChips`): selected is cobalt + white
  + bold, so selection never rides on colour alone. Small actions are raised chips
  (`EditorChipButtonStyle`), destructive ones use the error colour. Large choices
  (aspect ratios, annotate tools) use `EditorCellButtonStyle`.
- Switches are drawn (`EditorSwitchStyle`): cobalt track when on and the knob moves.
  They read the same live and in offscreen renders, with a native Toggle for VoiceOver.

**Canvas marks**

- Crop frames, selections, handles, the playhead and the lossless "ghost" are drawn as
  a dark anyfmt + white rim + cobalt core (`OverlayStroke`, `OverlayHandle`), so they
  read over bright, dark and blue footage alike. Increased Contrast thickens the core
  and makes the anyfmt opaque.
- Crop shows a live size badge on the frame and the size as a big numeral in the sidebar.
- No drop shadows: images get a hairline edge instead; the lifted collage photo is
  outlined in cobalt instead of floating on a shadow.

**Timelines**

- Filmstrip and waveform: tile-radius strips, cobalt selection frame with a white inner
  rim, cobalt playhead with a knob, and labelled trim handles ("In 0:02.40", "Out
  0:08.60"; "Start" / "End" for audio) pinned so they never cover each other.
- Split / snapshot markers are orange with black text (9.6:1); bleep ranges are flame
  with black numbers (6.3:1). The old white-on-orange labels (2.2:1) are gone.

**States**

- Image editors: a file that can't be decoded shows "Can't open this image" with plain
  copy (and Save copy stays off) instead of a spinner that never ends. New render:
  `docs/screens/editor-state-unreadable*.png`, covered by `testUnreadableImageState`.
- Media editors: loading is a tile with a spinner and the step ("Opening…",
  "Preparing preview…"); failure is "Can't open this file" with the engine's message
  and "Your file hasn't been changed."
- Metadata: loading and "Can't read the metadata" states in the same style.
- Organize PDF: a banner names files that can't be opened (locked or damaged) and says
  how to save the rest; when none open, "No pages to show".
- Read QR: "No codes found" with a hint; the panel now has a display header ("2 CODES").

**Tokens**

Every editor file reports zero hits in `scripts/check-tokens.sh --report`. Literal
colours left are the user's paint swatches (annotate defaults, swatch names) marked
`// token-ok`, and the allow-listed background / collage / redact swatches. Radii are
`Shape.tile` or pills (capsules) only; thumbnails are square-cornered content.

## Before / after

| Editor | Before | After (light) | After (dark) |
|---|---|---|---|
| Crop image | ![](../screens/before/editor-crop.png) | ![](../screens/editor-crop.png) | ![](../screens/editor-crop-dark.png) |
| Adjust | ![](../screens/before/editor-adjust.png) | ![](../screens/editor-adjust.png) | ![](../screens/editor-adjust-dark.png) |
| Annotate | ![](../screens/before/editor-annotate.png) | ![](../screens/editor-annotate.png) | ![](../screens/editor-annotate-dark.png) |
| Redact | ![](../screens/before/editor-redact.png) | ![](../screens/editor-redact.png) | ![](../screens/editor-redact-dark.png) |
| Add background | ![](../screens/before/editor-addbackground.png) | ![](../screens/editor-addbackground.png) | ![](../screens/editor-addbackground-dark.png) |
| Collage | ![](../screens/before/editor-collage.png) | ![](../screens/editor-collage.png) | ![](../screens/editor-collage-dark.png) |
| Images to PDF | ![](../screens/before/editor-imagestopdf.png) | ![](../screens/editor-imagestopdf.png) | ![](../screens/editor-imagestopdf-dark.png) |
| Metadata | ![](../screens/before/editor-metadata.png) | ![](../screens/editor-metadata.png) | ![](../screens/editor-metadata-dark.png) |
| Read QR result | ![](../screens/before/editor-readcodes.png) | ![](../screens/editor-readcodes.png) | ![](../screens/editor-readcodes-dark.png) |
| Trim video | ![](../screens/before/editor-trim.png) | ![](../screens/editor-trim.png) | ![](../screens/editor-trim-dark.png) |
| Crop video | ![](../screens/before/editor-crop-video.png) | ![](../screens/editor-crop-video.png) | ![](../screens/editor-crop-video-dark.png) |
| Split | ![](../screens/before/editor-split.png) | ![](../screens/editor-split.png) | ![](../screens/editor-split-dark.png) |
| Join | ![](../screens/before/editor-join.png) | ![](../screens/editor-join.png) | ![](../screens/editor-join-dark.png) |
| Snapshot | ![](../screens/before/editor-snapshot.png) | ![](../screens/editor-snapshot.png) | ![](../screens/editor-snapshot-dark.png) |
| Trim audio | ![](../screens/before/editor-trim-audio.png) | ![](../screens/editor-trim-audio.png) | ![](../screens/editor-trim-audio-dark.png) |
| Bleep | ![](../screens/before/editor-bleep.png) | ![](../screens/editor-bleep.png) | ![](../screens/editor-bleep-dark.png) |
| Organize PDF | ![](../screens/before/editor-organize-pdf.png) | ![](../screens/editor-organize-pdf.png) | ![](../screens/editor-organize-pdf-dark.png) |
| Unreadable image (new) | n/a | ![](../screens/editor-state-unreadable.png) | ![](../screens/editor-state-unreadable-dark.png) |

Regenerate: `TEST_RUNNER_HALO_SCREENSHOTS=1 TEST_RUNNER_HALO_EDITOR_SCREENS=1 xcodebuild … test
-only-testing:AppTests/ImageEditorScreenshotTests -only-testing:AppTests/MediaEditorScreenshotTests`.

## Polish list (not done yet)

1. Text fields (timecodes, pixel sizes, metadata, annotate text) are still the system
   rounded-border style; a pill-shaped field token would match the chips.
2. The zoom slider under the waveform and the PDF quality slider are system sliders
   (tinted cobalt); the drawn `ValueSlider` could replace them.
3. Join's list rows sit a few points in from the "JOIN ORDER" caption (List insets).
4. The dark canvas well (pure black) is only just distinguishable from the window
   (`#0A0A0A`); deliberate, but worth a look on a real display.
5. No banded gradient is used in the editors yet. A candidate is a heat-band backing on
   the crop size numeral or the trim duration, once per window.
6. The Read QR panel and the wheel's option popovers (`ImageCompressOptionsView`,
   `MediaOptionsPanel`) use editor chips but are hosted by other areas; their
   backgrounds follow the host.
7. Reduce Motion: the collage drag lift is turned off and switch/selection motion uses
   the snap curve or none, but the media reorder springs (organize PDF, join) still use
   the existing spring when motion is allowed.
8. Live feel (cursor hover on handles, drag of labelled trim handles near the ends) has
   only been checked in offscreen renders, not by hand.
