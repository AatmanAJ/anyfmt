---
title: Tools
description: Every anyfmt tool, from Compress and Crop to Trim, Normalize and Merge PDF, with its key options and output suffix, plus the three Pro cloud tools.
---

Tools change a file instead of converting it: compress it, crop it, trim it, strip its metadata. Press ⌘ Command mid-drag to open the Tools wheel, which lists only the tools that apply to the files you're holding. All 26 local tools are free and run on your Mac.

## How tools run

- **Instant tools** run straight away with your defaults, for example Compress or Strip metadata.
- **Editor tools** open a window with a live preview, a **Before / After** toggle (press B), an options sidebar, **Save copy** (Return) and **Cancel** (Esc). Crop, Trim and Redact work this way.
- **Every result is a new file** named with the tool's suffix: `photo.jpg` becomes `photo-compressed.jpg`. If that name is taken, you get `photo-compressed 2.jpg`. The original is never touched.
- **Tool results are dated now.** Unlike conversions, they don't copy the original's dates.
- **Some tools combine files.** Collage, Images to PDF, Join, and Merge / split / reorder take several files and make one result. The others run once per file.

To hide a tool from the wheel, open **Settings › Formats**, switch to **Tools**, and turn it off. To run a tool from Terminal, see [Run tools from the command line](#run-tools-from-the-command-line).

## Image tools

| Tool | What it does | Key options | Suffix |
|---|---|---|---|
| Compress `image.compress` | Makes JPG, HEIC, AVIF, WebP and PNG files smaller. The result is never larger than the original. Instant | Mode (Quality, Target size, Percentage), Quality, Target size, Percentage of original | `compressed` |
| Resize `image.resize` | Scales to a preset width, an exact size or a percentage. Instant | Mode (Preset, Exact size, Percentage), Preset (3840 to 512 px), Width, Height (0 keeps the aspect ratio), Scale | `resized` |
| Crop `image.crop` | Crops with handles in an editor | Crop, Aspect (Free, Square, 4:3, 3:2, 16:9, 9:16) | `cropped` |
| Adjust `image.adjust` | Tunes the picture with a live preview | Exposure, Contrast, Saturation, Warmth | `adjusted` |
| Annotate `image.annotate` | Adds arrows, boxes, highlights, freehand lines and text. Text is typed in the sidebar, not on the image | Annotations | `annotated` |
| Redact `image.redact` | Hides regions for good. Tests check it can't be undone | Style (Blur, Pixelate, Solid), Fill colour, Regions | `redacted` |
| Remove background `image.removeBackground` | Cuts out the subject. Works on any subject on macOS 14 and later, on people only on macOS 13. Instant | None | `cutout` |
| Add background `image.addBackground` | Puts an image on a solid, gradient or picture background | Fill (Solid, Gradient, Image), Colour, Second colour, Gradient angle, Background image, Padding, Corner radius, Shadow | `background` |
| Collage `image.collage` | Combines 2 or more images. Rows are sized so nothing is cropped | Layout (Grid, Row, Column), Gap, Background, Output width, Order | `collage` |
| Images to PDF `image.toPDF` | Combines 1 or more images into a PDF. JPEGs go in without recompression | Page size (Fit each image, A4, US Letter), Order | `combined` |
| Read QR / barcode `image.readCodes` | Reads codes in an image and shows them with a Copy button. Links open only after you confirm. Instant | None | `codes` |

## Video tools

| Tool | What it does | Key options | Suffix |
|---|---|---|---|
| Trim `video.trim` | Cuts to an in and out point. A lossless keyframe cut when possible, otherwise a frame-exact re-encode | Range, Lossless when possible | `trimmed` |
| Crop video `video.crop` | Crops the frame. Rotated phone video is shown the right way up | Crop, Aspect (Free, Square, 4:3, 3:2, 16:9, 9:16) | `cropped` |
| Change speed `video.speed` | Speeds up or slows down. Instant | Speed (0.25×, 0.5×, 0.75×, 1.25×, 1.5×, 2×, 4×), Keep audio pitch | `speed` |
| Split `video.split` | Splits at chosen times or every N seconds | Split (At times, Every N seconds), Split points (s), Segment length | `part` |
| Join `video.join` | Joins 2 or more clips. Lossless when they match, otherwise one re-encode with letterboxing | None | `joined` |
| Snapshot frame `video.snapshot` | Saves exact frames as images. With no times, it takes the middle frame | Times (s), Format (PNG, JPG) | `frame` |
| Compress video `video.compress` | Makes a video smaller by preset or to a target size (two passes). Instant | Mode (Preset, Target size), Preset (High, Balanced, Small file), Target size, Resolution (Keep, 1080p, 720p, 480p) | `compressed` |

## Audio tools

| Tool | What it does | Key options | Suffix |
|---|---|---|---|
| Trim audio `audio.trim` | Cuts to an in and out point on a waveform | Range, Lossless when possible | `trimmed` |
| Normalize `audio.normalize` | Brings loudness to a target (EBU R128, two passes, within 1 LUFS in tests). Works on audio and video. Instant | Loudness target (−14 LUFS streaming, −16 LUFS podcast, −23 LUFS EBU R128 broadcast) | `normalized` |
| Bleep `audio.bleep` | Covers marked ranges with a tone or silence, with 5 ms edges | Ranges, Replace with (1 kHz tone, Silence) | `bleeped` |
| Change channels `audio.channels` | Makes audio mono or stereo, or swaps left and right. Instant | Channels (Mono, Stereo, Swap left/right) | `channels` |

## Metadata tools

These work on images, audio, video and PDFs.

| Tool | What it does | Key options | Suffix |
|---|---|---|---|
| Edit metadata `meta.edit` | Shows and edits EXIF, IPTC, ID3, video tags and PDF info. GIF, BMP, TGA, EXR and ICO are read-only | Fields | `edited` |
| Strip metadata `meta.strip` | Removes all metadata. JPEGs stay lossless, audio and video streams are copied, PDFs are rewritten. Instant | None | `clean` |

## PDF tools

| Tool | What it does | Key options | Suffix |
|---|---|---|---|
| Merge / split / reorder `pdf.organize` | Merges PDFs, reorders, rotates and deletes pages in a thumbnail grid, or splits into single pages. Vectors and bookmarks are kept | Page order, Split into single pages | `organized` |
| Compress PDF `pdf.compress` | Shrinks the images inside a PDF while text stays vector. Instant | Mode (Preset, Target size), Image quality, Image resolution (72 to 300 DPI), Target size | `compressed` |

On the test fixture, Compress PDF took a 4.1 MB file to 315 KB with the text still vector.

## Pro cloud tools

Three tools need GPUs, so they run on a server. They appear on the Tools wheel with a cloud glyph and a **Pro** chip.

| Tool | Works on | Suffix |
|---|---|---|
| Transcribe `cloud.transcribe` | Audio and video, giving an SRT or VTT transcript | `transcript` |
| Upscale `cloud.upscale` | Images | `upscaled` |
| Remove background HQ `cloud.removeBackgroundHQ` | Images | `cutout-hq` |

The local **Remove background** tool stays free. The Mac side of the cloud tools is built and tested against a mock server, but the hosted server isn't live yet, so these tools can't run today. From the command line, cloud tools are listed with `"cloud": true` and exit with code 8. See [What Pro adds](/docs/pro).

## Run tools from the command line

```bash title="Terminal"
anyfmt tools                                                       # every tool with its options
anyfmt tool image.compress *.png --opt sizeMode=size --opt targetSize=500000
anyfmt tool meta.strip IMG_0042.jpg --json                         # → IMG_0042-clean.jpg
anyfmt tool audio.normalize episode.wav --opt target=-14
```

Target sizes are in bytes. Tool outputs are always renamed, never overwritten, so `--overwrite` isn't available for tools. See [Command reference](/docs/cli-reference#tool).
