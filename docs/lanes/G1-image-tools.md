# Lane G1: image tools (1–11) and metadata tools (23–24)

Branch `worktree-agent-aeaf0131c4d47a3e4`. Everything here is local and free:
no runner or editor consults `Entitlements` (`scripts/check-entitlements.sh` passes).

## What's built

### Runners (HaloCore, `Sources/Tools/Core/Image/`)

`ImageToolRunners.all` registers 13 runners; all write only into
`request.outputDirectory` (a hidden `.halo-scratch-*` folder for ffmpeg round
trips is removed before returning) and never overwrite.

| # | Tool | Runner | Output |
|---|---|---|---|
| 1 | Compress | `CompressImageRunner` (`Compress/`) | same format |
| 2 | Resize | `ResizeImageRunner` (`Transform/`) | same format |
| 3 | Crop | `CropImageRunner` | same format |
| 4 | Adjust | `AdjustImageRunner` | same format |
| 5 | Annotate | `AnnotateImageRunner` (`Annotate/`) | same format |
| 6 | Redact | `RedactImageRunner` (`Redact/`) | same format |
| 7 | Remove background | `RemoveBackgroundRunner` (`Background/`) | PNG with alpha |
| 8 | Add background | `AddBackgroundRunner` | same format |
| 9 | Collage | `CollageRunner` (`Combine/`) | first input's format if JPG/HEIC/PNG/TIFF, else PNG |
| 10 | Images → PDF | `ImagesToPDFRunner` | PDF |
| 11 | Read QR / barcodes | `ReadCodesRunner` (`Codes/`) | TXT |
| 23 | Edit metadata | `EditMetadataRunner` (`Metadata/`) | same format |
| 24 | Strip metadata | `StripMetadataRunner` | same format |

"Same format" means `ToolImageFormats.outputFormat(for:)`: the input format when we
can write it (ImageIO, or the bundled ffmpeg for WebP and for AVIF where the OS
has no encoder), RAW → JPG, ICO/ICNS/JXL/anything unwritable → PNG.

Public API the app (and the wheel) can use:

- `ToolDecodedImage`, `ToolImageSupport` (`decode`, `thumbnail`, `pixelSize`, `properties`, `resample`, `colorSpace`, `managedContext`)
- `ToolImageFormats.outputFormat(for:)`, `ToolImageFormats.canWrite(_:)`
- `ResizePlan.targetSize(for:options:)`, `CropGeometry` (parse/format/aspect/pixel rects)
- `ImageAdjustments` (options ⇄ struct, `apply(to: CIImage)`, `render(_:)`)
- `Annotation` (Codable; `decodeList`/`encodeList`), `AnnotationRenderer` (draw into any CGContext, bounds, hit test, render)
- `Redactor` (`parseRegions`, `format`, `apply(_:regions:style:fill:referenceSize:)`)
- `SubjectMasker` (`mask`, `cutout`, method `.automatic` / `.personOnly`)
- `BackdropStyle` + `BackgroundComposer` (named `Backdrop…` because SwiftUI owns `BackgroundStyle`)
- `CollageStyle`, `CollageLayout.make(aspects:style:)`, `OrderOption` (1-based "order" lists)
- `ToolOrientationTransform`, `PDFPagePlan.page(for:dpi:pageSize:)`
- `CodeReadResult`, `CodeReader` (`read`, `text(for:)`, `parse(_:)`, `parse(fileAt:)`)
- `MetadataField`, `MetadataSnapshot`, `MetadataReader.read(_:locator:)`, `MetadataChanges` (`parse`, `encode`, `diff`)
- `OptionColor` ("#RRGGBB[AA]" option strings ⇄ CGColor)

### Editors (app, `Sources/Tools/Editors/Image/`)

`ImageEditors.open(_:inputs:onSave:) -> Bool` opens, inside the shared
`EditorShell`, the editors for crop, adjust, annotate, redact, add background,
collage, images → PDF and edit metadata (images, audio, video and PDF). It
returns false for any other tool or for inputs the tool doesn't apply to.
`ImageEditors.make(_:inputs:)` builds the same editors without a window (used
by screenshots). Each editor has a `ToolEditorModel`:

| Editor | Model | Highlights |
|---|---|---|
| Crop | `ImageCropModel` | corner + edge handles, drag outside to draw a new frame, rule of thirds, six aspect presets drawn at their real ratio, ←↑→↓ nudge 1 px / ⇧ 10 px |
| Adjust | `ImageAdjustModel` | exposure, contrast, saturation, warmth on a 1400 px preview through the runner's own Core Image chain; sliders fill from neutral, detent at neutral, double-click resets |
| Annotate | `ImageAnnotateModel` | select, arrow, line, box, ellipse, text, highlight, draw; 8 swatches + system colour panel; width/size in px; select/move/handle-drag; Delete; ⌘Z / ⇧⌘Z; ⌥⌘ letter shortcuts; drawn with `AnnotationRenderer`, so the preview is the output |
| Redact | `ImageRedactModel` | draw/move/resize areas, pixelate / blur / solid (+ colour), live preview of the real irreversible effect at preview scale (`referenceSize`), Delete, ⌘Z |
| Add background | `ImageBackgroundModel` | solid / gradient (8 presets, From/To wells, swap, angle) / image (open panel), padding, corner radius, soft shadow, live composite |
| Collage | `ImageCollageModel` | live justified layout; drag tiles in the preview (others reflow live) or rows in the list; layout, gap, background, output width |
| Images → PDF | `ImagesPDFModel` | page cards at true page geometry, drag to reorder (preview or list), sort by name, reverse, Fit / A4 / Letter, page count |
| Metadata | `MetadataEditorModel` | grouped table (IPTC / TIFF / EXIF / GPS / Camera / Image / File, or Tags / Media, or PDF info / Document); editable fields inline, read-only fields locked; change dots, removed values struck through; Revert, Remove location, Clear all |

Also exported:

- `ImageCompressOptionsView(options:originalBytes:)` and `ImageResizeOptionsView(options:sourceSize:)`: 300 pt popovers editing a `Binding<OptionValues>` for the wheel.
- `CodeResultPresenter.present(results:source:copyToClipboard:)` / `present(fileAt:)`: floating panel, one row per code with Copy; links get **Open link…**, which shows the full URL in a confirmation alert first. Presenting copies all payloads (BUILD.md "copies result").
- `ImageEditors.presentResult(_:outputs:)`: call after a tool job succeeds; opens the code list for Read QR, false otherwise (see contract change 2).

All UI uses `DesignTokens`; colours come from the iris/mint/danger palette with
light/dark variants; overlays thicken under Increase Contrast; collage/PDF
reordering animations turn off under Reduce Motion; every control has a
VoiceOver label (sliders are adjustable, list rows have Move up/down actions).
Esc closes (shell), Save copy closes after handing the result over.

Screenshots (light + dark): `docs/screens/editor-{crop,adjust,annotate,redact,addbackground,collage,imagestopdf,metadata,readcodes}.png`,
`docs/screens/popover-{compress,resize}.png`. Regenerate with
`TEST_RUNNER_HALO_SCREENSHOTS=1 xcodebuild … test -only-testing:AppTests/ImageEditorScreenshotTests`
(writing is opt-in because palette-compacting 22 Retina PNGs takes ~1 min in
Debug; without it the test still renders every view).

## Decisions (for DECISIONS.md)

- **G1-1 Compress search.** Size/percent modes binary-search ImageIO's quality
  (8 steps, stop within 3 % under the target) and only then Lanczos-downscale
  (√ratio steps). Results never exceed the target, and never exceed the
  original when the format is unchanged (the original's bytes are reused when
  that is honest: same format, keep-metadata policy, upright). 12 MP JPEG → 1 MB
  in 0.29 s (Release, M5 Max).
- **G1-2 PNG compression is quantisation, honestly labelled.** PNG has no
  quality knob, so: lossless re-encode → own palette quantiser (exact palette
  when ≤ 256 colours, otherwise variance median cut in premultiplied RGBA +
  2 k-means passes + Floyd–Steinberg at 0.8, full per-entry alpha like
  pngquant) → own palette PNG writer (1/2/4/8-bit packing, tRNS, sRGB/iCCP,
  pHYs, zlib level 6) → downscale. Quality ≥ 95 stays lossless; 70–94 → 256
  colours, then 128/64/32/16. 12 MP quantise 0.23 s. No new dependency (zlib is
  the system's).
- **G1-3 Metadata edits don't touch pixels where the container allows.** JPEG:
  EXIF/IPTC segments are regenerated by ImageIO on a flat "carrier" image of the
  same size and spliced around the original scan data; an existing XMP packet is
  updated in place with `CGImageMetadata`. PNG: metadata chunks swapped, IDAT
  untouched. WebP: EXIF and XMP chunks replaced (a VP8X header is added to
  simple files), bitstream untouched. HEIC/HEIF/AVIF/TIFF/JP2/PSD re-encode (0.92 for lossy) because
  `CGImageDestinationCopyImageSource` dropped or ignored edits on 27.0.1 and
  crashed on HEIC (probed here, matching the AnyDoor note in research §C).
  GIF/BMP/TGA/EXR/ICO: read-only in the editor.
- **G1-13 Animated GIFs** run every pixel tool frame by frame (ImageIO hands
  back composited frames) and keep delays and loop count; compress's target
  size scales all frames together.
- **G1-4 Strip.** JPEG keeps only JFIF, ICC, Adobe APP14 and tables (drops
  EXIF, XMP, IPTC, comments, MPF and trailing gain-map images); a non-up
  orientation is kept as a bare EXIF orientation tag so nothing is re-encoded.
  PNG drops tEXt/zTXt/iTXt/eXIf/tIME; WebP drops EXIF/XMP chunks and their
  VP8X flags; GIF is re-written frame by frame with timing only (animation kept);
  others re-encode upright pixels with no properties (ICC kept). Audio/video:
  `ffmpeg -map 0 -map -0:disp:attached_pic -dn -map_metadata -1 -map_metadata:s -1 -map_chapters -1 -c copy` + bit-exact flags
  (removes QuickTime location, cover art, GPS/timecode data streams). PDF: pages
  re-hosted in a new PDFKit document (annotations and outline rebuilt), because
  PDFKit keeps the catalog XMP when only attributes change. Quartz always adds
  Producer and dates.
- **G1-5 Redaction is destructive by construction.** Blocks ≥ 12 px and ≥ ¼ of
  the region's short side (a text line is ≤ 2 blocks tall), averaged plus ±3
  levels of seeded noise; blur = the same coarse grid reconstructed bilinearly,
  so it looks blurred but carries no more information than the blocks. Tested:
  zero source pixel values survive in the region.
- **G1-6 Background removal.** macOS 14+: `VNGenerateForegroundInstanceMaskRequest`
  + `generateScaledMaskForImage` (full-resolution soft mask) + ~1 px feather.
  macOS 13: `VNGeneratePersonSegmentationRequest(.accurate)`, mask Lanczos-upscaled;
  if under 1 % person coverage, a human error says other subjects need macOS 14.
- **G1-7 Collage never crops.** Grid = justified rows chosen by dynamic
  programming (≈ √n per row, rows as even as possible); row / column are single
  justified strips. P3 canvas when any input is wide-gamut.
- **G1-8 Images → PDF.** JPEGs embed as DCT passthrough (verified: Quartz passes
  ImageIO-sourced JPEGs through); orientation is a CTM, not a re-render. HEIC,
  AVIF and WebP (no PDF filter) are re-encoded once as JPEG 0.9: 3 × 12 MP went
  from 12.8 MB to 4.0 MB. Fit pages use the image's DPI (≥ 72); A4/Letter pages
  turn landscape for landscape images, 24 pt margin, never upscale.
- **G1-9 Adjust maths.** Exposure and temperature in linear light; contrast and
  saturation (CIColorControls) in sRGB-encoded values (wrapped in
  `CILinearToSRGBToneCurve`/`CISRGBToneCurveToLinear`), otherwise shadows clip
  to pure primaries. Warmth −1…1 → target white 8450…4550 K.
- **G1-10 Option conventions.** Normalised rects are "x,y,w,h", origin top-left.
  "order" lists are 1-based (matches `organizePDF`). Gradient angles use CSS
  semantics. Annotation widths/sizes are fractions of the short side, so JSON
  renders identically at any resolution.
- **G1-11 Read codes output.** One block per code, `[Label · Symbology]`, payload
  verbatim (lines starting `[` or `\` escaped with `\`), blank separator;
  `CodeReader.parse` round-trips it exactly. Small images are retried at 2×.
  Links: only http(s), mailto, tel, sms, facetime, never opened automatically.
- **G1-12 Names are prefixed** (`ImageCropModel`, `ImageEditorKit.*` in the app; `Tool…` for HaloCore helpers such as `ToolImageSupport`, `ToolImageEncoder`; no extensions on system types) so
  lanes D and G2 sharing the same modules can’t collide at merge.

## Shipped vs not (for PARITY.md)

Shipped: all 11 image tools and both metadata tools, every editor listed above,
batch-ready (`perFile`) compress/resize/remove background/read codes/strip.

Not shipped / limits:
- Animated GIFs keep every frame and its timing through resize, crop, adjust, annotate, redact, add background, compress (target size scales all frames) and strip. Collage, Images → PDF and Remove background use the first frame. Animated WebP: first frame only (would need an animated WebP encoder path, ffmpeg `libwebp_anim` is bundled).
- Edit metadata for GIF, BMP, TGA, EXR, ICO: read-only (these carry little or no EXIF/IPTC; no writer we trust).
- Writing XMP-only fields (ratings, labels) in PNG/HEIC edits: those formats are rewritten from EXIF/IPTC dictionaries, so XMP-only fields are dropped on edit. JPEG keeps its XMP packet.
- AVIF via ffmpeg (macOS without a native encoder) drops alpha.
- Remove background on macOS 13: people only (Vision limit; research §D).
- Annotate text is edited in the sidebar field, not inline on the canvas.

## Contract change requests

See `docs/contract-changes/G1.md`: (1) declare `annotations`, `angle`, `color`,
`order` in `ToolSchemas`; (2) `EditorFactory.presentResult` forwarder so the
job UI shows Read QR results; (3) optional size on `EditorWindow.present`;
(4) the shell's "Hold to compare" tooltip describes a toggle.

## Tests

- Core (`Tests/Unit/Core/ToolsImage/`, target `CoreTests`): 72 tests —
  `CompressImageTests` 13, `TransformToolTests` 14, `DrawingToolTests` 21,
  `MetadataToolTests` 14, `ContainerMetadataTests` 10. All pass. Covers target
  size ≤ target and ≥ 80 % of it, percent, HEIC/WebP/PNG/AVIF, palette exactness
  and alpha, metadata policy, resize/crop dims, all 8 EXIF orientations against
  ImageIO and Core Image, P3 profile survival, adjust directions, annotate pixels,
  redaction leaves no source values, cut-out alpha (Vision), person-path error,
  padded canvas, gradient direction, collage geometry, PDF page count/order/size/
  DCT passthrough, QR round trip, metadata round trips (JPEG lossless scan,
  JPEG XMP consistency, PNG IDAT identical, HEIC, PDF, MP3, MP4), strips (JPEG,
  PNG, HEIC, WebP chunks, animated GIF, PDF XMP, MP3 tags, MP4 location),
  animated GIF resize/crop/compress keeping frames, ffmpeg AVIF fallback,
  lossless WebP metadata edits (lossy and alpha files) and their strip.
- App-hosted (`Tests/Unit/App/EditorsImage/`, target `AppTests`): 15 model /
  factory tests + 9 render tests. `ImageEditors.open` returns true for all 8
  editor tools (and via `EditorFactory`), false otherwise; Esc closes; every
  model produces the right options; adjust preview re-render worst case < 50 ms
  (measured 24 ms worst in a Debug build, 1400 px preview); typing "b" in a field isn’t eaten by the shell.

Run: `xcodebuild -project Halo.xcodeproj -derivedDataPath build/DerivedData -scheme Halo test -only-testing:CoreTests/CompressImageTests -only-testing:CoreTests/TransformToolTests -only-testing:CoreTests/DrawingToolTests -only-testing:CoreTests/MetadataToolTests -only-testing:CoreTests/ContainerMetadataTests -only-testing:AppTests/ImageEditorsTests -only-testing:AppTests/ImageEditorScreenshotTests`
(the scheme's test target names are `CoreTests` / `AppTests`, not the product
names in LANE_RULES). Tests find ffmpeg via `HALO_ENGINES_DIR` or by walking up
from the test file to a checkout's `Engines/dist` (works from worktrees).

## Performance (Release, M5 Max, 12 MP unless noted)

| Operation | Time |
|---|---|
| Compress JPG at q70 | 67 ms |
| Compress JPG → 1 MB target | 292 ms |
| Compress HEIC → 50 % | 668 ms |
| Compress PNG 3.8 MP at q70 (palette) | 433 ms |
| Compress PNG 3.8 MP → ⅓ size | 1.27 s |
| Resize → 1920 | 65 ms |
| Adjust | 74 ms |
| Redact (2 areas, blur) | 84 ms |
| Add background | 398 ms |
| Collage of 3 | 106 ms |
| Images → PDF, 3 pages (JPG, HEIC, JPG) | 97 ms |
| Strip metadata (JPEG, lossless) | 2 ms |
| Edit metadata (JPEG, lossless) | 8 ms |

## Blockers

None. Not verifiable on this machine: the macOS 13 person-segmentation path
and the AVIF-via-ffmpeg fallback only run on older systems. The person path is
exercised here by forcing `SubjectMasker.Method.personOnly`, the AVIF fallback by `ToolImageEncoder.forceFFmpegAVIF`.
