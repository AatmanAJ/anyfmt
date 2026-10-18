# Lane D: Image + PDF

Owner of `Sources/Engine/Image/**`, `Tests/Unit/Core/Image/`, `Tests/Fixtures/lanes/images.sh`
(+ its helper `images-fixtures.swift`). Verified on macOS 27.0.1, Xcode 27.1, M5 Max.

## What's built

Four engines (`ImageEngines.all`), all stateless `Sendable` structs with honest runtime `isAvailable`:

| Engine | Id | Does | Availability check |
|---|---|---|---|
| `ImageIOEngine` | `imageio` | Decodes every raster input. Encodes JPG, PNG, HEIC, HEIF, TIFF (LZW), BMP, JP2, PSD, TGA, EXR, AVIF; our own ICO, ICNS and PDF writers; image → TXT (Vision OCR); GIF (fallback only) | source UTI in `CGImageSourceCopyTypeIdentifiers`, target UTI in `CGImageDestinationCopyTypeIdentifiers` (this is what gates AVIF) |
| `FFmpegImageEngine` | `ffmpeg-image` | WebP stills + animations (libwebp / libwebp_anim), palette GIF stills + animations (palettegen/paletteuse), AVIF fallback stills (libaom) and animated GIF → animated AVIF | bundled `ffmpeg` present + ImageIO can decode the source |
| `ResvgEngine` | `resvg` | SVG → PNG at 2× intrinsic size (or `maxDimension` on the longest edge), transparent, DPI tagged 72×scale | bundled `resvg` present |
| `PDFKitEngine` | `pdfkit` | PDF → PNG/JPG/HEIC/WebP/TIFF/AVIF/BMP at 72–600 DPI (36–1200 accepted) for all pages or a range; PDF → TXT with OCR for scanned pages | WebP needs ffmpeg; AVIF needs ImageIO AVIF or ffmpeg |

Internal building blocks (all `internal`, in `Sources/Engine/Image/`):

- `ImageInput`: opens a file once (type, chosen index, properties, orientation, alpha, animation timing).
  Icon files use their **largest** size; HEIF uses the primary image; GIF/TIFF index 0.
- `StillPipeline` + `ImageOps`: decode → orient → downscale → HDR tone-map → flatten → colour convert.
- `ImageMetadata`: per-policy destination properties and XMP tree.
- `ImageFormatTraits`: per-target facts (UTI, colour handling, alpha, bit depth, lossy, metadata).
- `IconWriter` (ICO + ICNS containers), `ImagePDFWriter`, `WebPContainer` (RIFF chunks), `GIFTiming`
  (GCE delay/loop patcher), `ExifBlob` (EXIF TIFF structure for WebP), `TextRecognizer` (Vision OCR),
  `PageRange` (page-range parser), `SVGSize` (intrinsic size), `WorkFolder` (scratch dir in the request's output dir).

Public API added: the four engine structs, `ImageRoutes.{rows, rasterInputs, primaryOutputs, extraOutputs,
pdfImageOutputs, opaqueLosslessSchema}`.

## Routes shipped

- **277 rows**, **265 distinct conversion options** (router `optionCount` over lane D inputs);
  **174** of those have no hidden hop (default wheel).
- Inputs (17): JPG PNG WebP HEIC HEIF TIFF AVIF BMP GIF JP2 PSD ICO ICNS TGA EXR + SVG + PDF.
- Raster outputs: JPG PNG WebP HEIC TIFF AVIF BMP GIF PDF ICO ICNS on the wheel; HEIF JP2 PSD TGA EXR and
  TXT (OCR) are `.hiddenByDefault` (CLI, matrix, "more" ring).
- SVG: one row (→ PNG, `.lossless`); every other SVG target is a 2-hop route through PNG (16 more options).
- PDF: → PNG JPG HEIC WebP TIFF AVIF BMP (`.multiOutput`, `pdfRender` schema) and → TXT
  (`.terminalOnly` + `.lossyStructure`). PDF → DOCX/PPTX/XLSX/EPUB/MD/HTML/RTF/ODT/Pages are lane F's.
- Priorities: ImageIO 100; ffmpeg-image GIF 90 (beats ImageIO GIF at 40), WebP 60 (only encoder),
  AVIF 60 (fallback; ImageIO row wins when the OS encodes AVIF); resvg 90; PDFKit 100.
- `.lossless`: PNG, TIFF, BMP, PSD, TGA (pixel-exact for 8-bit sRGB), SVG → PNG.
- Schemas: JPG `imageOpaque`; HEIC/HEIF/AVIF/JP2 `imageLossy`; WebP `imageLosslessCapable`;
  PNG/TIFF/GIF/PSD/TGA/EXR/ICO/ICNS `imageLossless` (`maxDimension` caps the largest icon size);
  BMP lane-local `image.opaque.lossless` (background + max size, see contract changes); PDF `toPDF`;
  PDF pages `pdfRender`.

## Decisions (ready for DECISIONS.md)

**D-D1 ImageIO first, gated at runtime.** Zero size cost. Every ImageIO row checks the live
decoder/encoder lists, never an OS version (AVIF encode exists on 27, unverified on 13–15).

**D-D2 Our own ICO and ICNS writers.** ImageIO's ICO writer refuses more than 6 images and any size it
doesn't like (24 px, 20 px); its ICNS writer silently drops 64 px and 1024 px. ICO: 16, 24, 32, 48, 64, 128
as 32-bit BGRA DIBs with AND masks (every Windows), 256 as PNG (Vista+). ICNS: PNG payloads for all 11
element types (`icp4 icp5 icp6 ic07…ic14`) with a TOC; `iconutil --convert iconset` accepts it. Non-square
sources are centred on a transparent square; small sources are upscaled so the icon set is complete.

**D-D3 Colour.** Keep the source ICC profile for JPG/PNG/HEIC/HEIF/AVIF/TIFF/PSD/WebP (WebP: we write the
ICCP chunk). For BMP/GIF/TGA/JP2/ICO/ICNS we convert pixels to sRGB ourselves: ImageIO *relabels* P3 as
sRGB for TGA and JPEG 2000 (verified: P3 (193,131,86) came back unchanged instead of (204,128,77)).
EXR: ImageIO converts to extended linear sRGB correctly. CMYK stays CMYK for JPG/TIFF/PSD, else sRGB.

**D-D4 Metadata policy.** Orientation is always baked into pixels and reset to 1 (except D-D8).
`keep`: all EXIF/TIFF/GPS/IPTC/maker-note groups + the full XMP tree (`CGImageDestinationAddImageAndMetadata`
with properties as options, verified to keep GPS/IPTC/XMP/DPI across JPG/PNG/HEIC/TIFF). Encoding tags
(compression, tiles, photometric, EXIF ColorSpace) are dropped so they can't leak (HEIC's tile tags made TIFFs
uncompressed and tiled before this). `stripPrivate`: removes GPS, maker notes, ExifAux, DNG, make, model,
software, host, artist, owner, serial numbers, lens make/model/serial, unique id, user comment, IPTC
by-line/credit/contact/place fields; keeps capture date and settings, keywords, caption, copyright notice,
DPI and the colour profile; XMP is rebuilt by ImageIO from the filtered properties (custom XMP dropped,
tested: no author/place strings left in XMP). `stripAll`: no properties at all, and wide-gamut pixels are
converted to sRGB so no device profile remains.

**D-D5 WebP through ffmpeg/libwebp, metadata by us.** ImageIO never encodes WebP. Pixels come from our
pipeline as an 8-bit PNG in a private work folder (`-pix_fmt bgra` so libwebp does its own sharper YUV
conversion). ffmpeg writes bare bitstreams, so `WebPContainer` adds VP8X + ICCP + EXIF (a TIFF structure lifted
from an ImageIO-written APP1) + XMP per policy, written from the WebP container spec. Animations: frames
decoded by ImageIO (composited) and fed at 1 frame/ms, then every ANMF duration is rewritten from the source
delays (libwebp merges identical frames into an n-ms frame = n source frames; ffmpeg guesses the last frame's
duration). Loop count kept. Licence: libwebp BSD-3 inside the GPL ffmpeg build (D-020).

**D-D6 GIF through palettegen/paletteuse.** ImageIO's GIF encoder bands badly (≈30 levels on a grey ramp,
odd pattern dithering). ffmpeg with `palettegen=stats_mode=full` + `paletteuse=dither=sierra2_4a` keeps
>150 of 256 grey levels and transparency (`reserve_transparent`, `alpha_threshold=128`). Animations use one
global palette with `diff_mode=rectangle`, frames at 1 per centisecond, then `GIFTiming` writes the real
delays and loop count into each Graphic Control Extension (walks the block structure; if ffmpeg ever changes the frame count it falls back to ImageIO’s writer).
ImageIO GIF stays as the priority-40 fallback (also animated, timing kept).

**D-D7 AVIF.** ImageIO when `public.avif` is a destination type (keeps alpha and P3). Otherwise libaom
still-picture (`-crf` from quality: 85 → 13), 4:2:0 main profile, sRGB tags, alpha as the second AV1 image
via `alphaextract`; no EXIF/XMP and pixels converted to sRGB (documented limitation). Animated GIF → AVIF
always goes to ffmpeg straight from the GIF demuxer (exact timing); ImageIO's AVIF row delegates.

**D-D8 HDR.** Gain-map photos (Apple `HDRGainMap`, ISO 21496-1 `ISOGainMap` on 15+) → JPG/HEIC/HEIF with
`keep`, no resize and no flattening: the untouched base image is written and the gain map auxiliary data is
copied (`CGImageDestinationAddAuxiliaryDataInfo`; `kCGImageDestinationPreserveGainMap` only worked
HEIC → HEIC, not → JPEG). In that path orientation stays a tag (JPEG/HEIC viewers honour it) because the gain
map can't be rotated without re-rendering. Any other change re-renders SDR. Float/extended sources (EXR) going
to integer targets get an extended-Reinhard luminance curve with the white point at the 99.9th percentile
(`kCGImageSourceDecodeToSDR` does nothing for EXR, so highlights used to clip). EXR → EXR stays float.
PQ/HLG HDR HEIC/AVIF decode to SDR (ImageIO default) and are written SDR.

**D-D9 SVG via resvg at 2×.** The PNG is tagged 144 DPI (72 × scale) so SVG → PDF pages come out at the
SVG's own size (320×200 SVG → 320×200 pt page). Intrinsic size parsed from the root element (units, viewBox,
percentages); default render capped at 8192 px. resvg licence Apache-2.0 OR MIT, 2.9 MB (D-021).

**D-D10 PDF page renders.** PDFKit `draw(with: .cropBox, to:)` (applies rotation and box origin itself; adding
`transform(_:for:)` double-rotates). White paper background for every format (a transparent PNG of a page is
unreadable in dark mode), sRGB, DPI written into the file. One-page PDF → `name.png`; longer → `name-001.png`…
by real page number (padded to ≥3 digits). Longest edge capped at 16 384 px. Encrypted PDFs try the empty
user password, else a human error ("…is password-protected. Open it in Preview, remove the password…").
Page ranges: `""`/`all`, `1-3,5`, `7-`, `-2`, whitespace ignored, de-duplicated, ascending, past-the-end pages
dropped; `0`, `3-1`, junk → `invalidOption`; nothing left → `invalidOption`.

**D-D11 Text.** PDF → TXT: page texts joined by a form feed on its own line (pdftotext convention; TextEdit
shows a page break). Pages with no text layer are OCR'd with Vision (`VNRecognizeTextRequest`, accurate,
language correction, automatic language detection) at 200 DPI. No text anywhere → human error. Image → TXT
uses the same OCR (rows hidden by default).

**D-D12 Images → PDF.** One page per image (all pages of a multi-page TIFF). `fit`: page = image size at its
DPI; A4/Letter: paper turns to match the image, ½-inch margins, the image only ever shrinks. Lossy sources
(JPEG/HEIC/AVIF/WebP/JP2) without alpha are embedded as JPEG q 0.92 so Quartz writes DCT (a 1200×900 photo
PDF stays under 3× the JPEG); lossless sources stay lossless.

**D-D13 TIFF output is LZW** (lossless, roughly half the size of raw; 16-bit and alpha kept).

**D-D14 Specialist outputs hidden by default** (HEIF, JP2, PSD, TGA, EXR, image → TXT) so the image wheel
shows 11 targets (8–12 is what the reference shows, INTERACTION_NOTES).

**D-D15 Multi-frame rules.** Animated GIF/WebP/APNG/AVIS → static targets: first frame. → GIF and → WebP:
animated with timing and loop. → AVIF: animated from GIF only. TIFF pages: first page, except → PDF (all pages).

## Not shipped (for PARITY.md)

| Gap | Why | What it would take |
|---|---|---|
| JPEG XL **input** | ImageIO decodes it (14+) but nothing on a stock Mac encodes it, so there's no fixture (lane rule) | Bundle `cjxl` (libjxl, BSD-3) as a build-time fixture tool, or add libjxl to ffmpeg |
| JPEG XL output | No encoder in ImageIO or our ffmpeg | libjxl in the ffmpeg build (+~2 MB) |
| Camera RAW input | ImageIO's RAW decoder ignores hand-written DNGs: LinearRaw IFD0, CFA IFD0 and preview+CFA SubIFD layouts are all classified as plain TIFF on macOS 27 (`CIRAWFilter` reports 0×0) | A real CC0 camera DNG under 1 MB checked in as a fixture, then rows `raw → *` (ImageIO decodes real DNG/CR3/NEF/ARW…) |
| Animated WebP/APNG → animated AVIF | Only GIF goes through ffmpeg's demuxer with exact timing | Frame sequence + concat with timestamps (concat demuxer timing was off by a frame in tests) |
| AVIF fallback metadata | ffmpeg's AVIF muxer writes no EXIF/XMP; we convert to sRGB | Write the `Exif` item + `colr` ICC box ourselves (ISOBMFF) |
| HDR (PQ/HLG) outputs | Out of scope; we write SDR (gain maps are preserved, D-D8) | `kCGImageDestinationEncodeToISOGainmap` on 15+ from `DecodeToHDR` pixels |
| Combine many images into one PDF | Not a per-file route; it's a tool (lane G) | `.combine` row or a tool using `ImagePDFWriter` |

## Contract change requests

See `docs/contract-changes/D-image.md`: add `StandardSchemas.imageOpaqueLossless`; reserve `EngineIDs.pdfKit`
for lane D; let tests see `HALO_ENGINES_DIR`; matrix note for animated AVIF; new localisable strings.

## Tests (Tests/Unit/Core/Image, target CoreTests)

77 tests in CoreTests pass (61 lane D + 16 Router/OutputNamer), ~21 s for the whole target:

- `ImageIOEngineTests` (25): orientation pixel check across PNG/JPG/HEIC/BMP/TGA; maxDimension (and no
  upscaling); P3 kept for JPG/HEIC/TIFF/PNG/PSD/AVIF; real sRGB conversion for TGA/JP2/BMP/GIF; alpha flattened
  onto the `background` colour (JPG red, BMP green, default white), alpha kept for TIFF; 16-bit kept for TIFF;
  metadata keep / stripPrivate (GPS, make, model, artist, serial, lens, city, by-line gone; date, keywords, DPI,
  P3, orientation fine; no author/place in XMP) / stripAll (sRGB, nothing left); quality vs size (JPG, HEIC);
  ICO sizes 16…256 square and padded; ICNS 16…1024 and `iconutil` round trip; icon input uses largest size;
  GIF → still first frame; TIFF first page vs PDF all pages; animated WebP → GIF timing; image → PDF page sizes
  (fit/A4/Letter); compact photo PDF; every ImageIO target decodes; AVIF round trip with alpha; HDR roll-off;
  gain map survives HEIC → JPG (macOS 15+); TIFF from HEIC is LZW and untiled; OCR; unreadable input error.
- `FFmpegImageEngineTests` (13): WebP size/alpha/ICC/colour; orientation + maxDimension; lossless is
  pixel-exact, quality vs size; WebP metadata per policy; animated GIF → WebP durations exactly
  [100,200,300,400,500] ms + ffprobe 5 frames; merged duplicate frames keep total time and loop count; AVIF
  fallback with alpha and colour; animated GIF → AVIF (direct and via ImageIO delegation); palette GIF keeps
  >150 grey levels + transparency; animated WebP → GIF exact centisecond delays; APNG with duplicate frames → GIF keeps total time; `GIFTiming` guards; work folder
  cleaned up.
- `ResvgEngineTests` (5): 2× default + transparency + DPI; maxDimension wide/tall; SVG → JPG/PDF/WebP/ICO via
  PNG and SVG → PDF page size end to end; broken SVG → unreadable; intrinsic size parser.
- `PDFKitEngineTests` (10): page-range parser; DPI → pixels (72/150/300); numbered multi-page names and
  ranges; white JPG background; rotated page renders landscape; every page target decodes; invalid ranges;
  PDF → TXT with form feeds; OCR of a scanned page; password-protected message.
- `ImageRoutesTests` (6): lane table integrity (no duplicates, identity, unknown formats, orphan engines);
  coverage of every input × output; flags/schemas/priorities; AVIF row selection follows the OS encoder;
  router paths (no PDF render chaining, palette GIF preferred, SVG through PNG); option count.
- `ImageRouteSweepTests` (1): lane mini-matrix. Runs `images.sh` (≈10 s, contract < 30 s), checks a fixture
  exists for every shipped input, then executes **all 277 rows plus the 16 SVG hop routes (293 runs, 0 failures,
  7.6 s total)** and validates every output by opening it (ImageIO decode, icon size count, PDFKit page counts,
  TIFF → PDF 2 pages, PDF → images 3 files, OCR text, GIF → WebP/AVIF still animated per ffprobe). Slowest:
  PDF → WebP 3 pages at 300 DPI 0.97 s; PDF → PNG 0.38 s.
- `ImagePerfTests` (1): **12 MP (4032×3024) HEIC → JPG: median 34 ms upright, 109 ms with orientation 6
  (rotated by the thumbnail decoder)**, Debug build, M5 Max. Budget 400 ms.

Run: `xcodebuild … test -only-testing:CoreTests/ImageIOEngineTests` (and the other class names). Tests find the
bundled engines through `HALO_ENGINES_DIR` or by walking up from the test file to `Engines/dist`.

## Fixtures

`Tests/Fixtures/lanes/images.sh` → `images-fixtures.swift` (run with `swift`, module cache in a temp dir) writes
640×480 Display P3 test cards (colour bars, gradient band, top-left orientation marker, half-transparent band,
text) as sample.jpg/png/heic (orientation 6, GPS, make/model/serial, artist, IPTC city/keywords, 144 DPI),
sample.heif, a 2-page sample.tiff (16-bit page + 8-bit page), sample.avif (ImageIO, else ffmpeg), bmp, jp2,
psd, tga, exr, multi-size sample.ico/.icns, a 5-frame looping sample.gif (100…500 ms), a 3-page A4 sample.pdf
(text + vector), edge-rotated.pdf, edge-scanned.pdf (image-only page) and a hand-written sample.svg; ffmpeg
then makes sample.webp (alpha) and edge-animated.webp. Deterministic, no network, ≈10 s.

## Blockers

None needing a human. Unverified here (needs other machines): AVIF encode and Vision OCR behaviour on real
macOS 13–15 (rows are gated at runtime, so worst case they disappear or fall back to ffmpeg).
