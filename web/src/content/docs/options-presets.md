---
title: Options and presets
description: Set conversion options in anyfmt, such as quality, size and frame rate, save them as presets, and drop on a preset chip straight from the wheel.
---

Options are the settings for one conversion, such as JPG quality or GIF frame rate. Presets are named sets of options that appear as chips on the wheel, and the app and the command line share them. Every option has a sensible default, so you only open the options panel when you want something different.

## Open the options panel

| Where | How |
|---|---|
| Mid-drag | Drop on the outer edge of a segment (the pill reads "GIF · Options"), or hold ⌥ Option while you drop |
| Keyboard mode (Services, drop ring, menu bar) | Right-click a segment, or highlight it and press ⌥ Return |

The panel shows the target's options and a live estimate of the result: **Estimated size**, plus **Duration** and **Frames** for time-based formats. For files promised by Mail or Photos, the size is known only once the file arrives.

At the bottom:

- **Convert** runs with these values.
- **Save as Preset** saves them as a preset for this format. It's on the wheel next time.
- **Make default for GIF** (or the format you're converting to) makes these the values the wheel uses from now on.
- **Cancel** closes the panel. Nothing happens to the file.

## Options by target format

The options depend on the format you convert *to*. The id in each row is what the command line and the API use. Choice values are passed as their id, which is a string even when it looks like a number, such as `--opt bitrate=192`.

### Images

| Converting to | Options (`id`) | Defaults |
|---|---|---|
| JPG | Quality (`quality`, 1–100 %), Background for transparency (`background`), Max size (`maxDimension`), Resolution (`dpi`) | 85 %, white, original size, 300 DPI |
| HEIC, AVIF | Quality (`quality`), Max size (`maxDimension`), Resolution (`dpi`) | 85 %, original size, 300 DPI |
| WebP | Quality (`quality`), Lossless (`lossless`), Max size (`maxDimension`), Resolution (`dpi`) | 90 %, off, original size, 300 DPI |
| PNG, TIFF | Max size (`maxDimension`), Resolution (`dpi`) | original size, 300 DPI |
| BMP | Background for transparency (`background`), Max size (`maxDimension`), Resolution (`dpi`) | white, original size, 300 DPI |
| HEIF, JP2 | Quality (`quality`), Max size (`maxDimension`) | 85 %, original size |
| ICO, ICNS, PSD, TGA, EXR | Max size (`maxDimension`) | original size |
| GIF | Width (`gifWidth`: Keep, 960, 720, 640, 480, 320 px), Frame rate (`fps`: 10, 15, 24, 30), Loop (`gifLoop`: `forever`, `once`), Colours (`gifColors`: 256, 128, 64, 32), Dither (`gifDither`), Max size (`maxDimension`) | 640 px, 15 fps, forever, 256 colours, on |

- **Max size** is the longest edge in pixels, up to 32768. 0 keeps the original size.
- **Resolution** (72, 150, 300 or 600 DPI) is used only when the source is a PDF.
- For GIF, fewer colours make a smaller file. Turning **Dither** off gives flat colour areas and a smaller file too.

### Video

| Converting to | Options (`id`) | Defaults |
|---|---|---|
| MP4, MOV, M4V, MKV, WebM, AVI, WMV | Quality (`videoQuality`: `high`, `balanced`, `small`), Resolution (`resolution`: Keep, 4K, 1080p, 720p, 480p), Frame rate (`fps`: Keep, 60, 30, 24), Use hardware encoder when faster (`hardware`), Audio (`audio`: `keep`, `remove`) | Balanced, Keep, Keep, on, Keep |

When nothing needs re-encoding, nothing is. A one-minute 1080p H.264 MOV becomes an MP4 by passing its streams through, bit for bit, in 0.23 s on the build machine. When a re-encode is needed and the hardware option is on, anyfmt uses the Mac's hardware encoder, which measured 1.3 to 1.6 times faster than software at the same quality. WebM, AVI and WMV are always software encodes.

### Audio

| Converting to | Options (`id`) | Defaults |
|---|---|---|
| MP3, M4A, OGG, Opus | Bitrate (`bitrate`: 64, 96, 128, 192, 256, 320 kbps), Sample rate (`sampleRate`: Keep, 44.1, 48 kHz), Channels (`channels`: `keep`, `mono`, `stereo`) | 256 kbps, Keep, Keep |
| WAV, FLAC, AIFF, CAF | Sample rate (`sampleRate`: Keep, 44.1, 48, 96 kHz), Bit depth (`bitDepth`: `keep`, 16, 24), Channels (`channels`) | Keep, Keep, Keep |

### Documents, sheets and archives

| Converting to | Options (`id`) | Defaults |
|---|---|---|
| PDF | Page size (`pageSize`: `fit`, `a4`, `letter`) | Fit content |
| DOCX, ODT | Page size (`pageSize`: `a4`, `letter`) | A4 |
| MD | Images (`images`: `embed`, `omit`) | Embed in the file |
| TXT, from subtitles | Include timestamps (`timestamps`) | off |
| CSV, TSV | Sheets (`sheet`: `first`, `all`), Add byte order mark for Excel on Windows (`bom`) | First sheet, off |
| JSON | Sheets (`sheet`) | First sheet |
| ZIP, TAR, GZIP, 7z | Compression (`compression`, 0–9) | 6 |

EPUB, HTML, RTF, RTFD, ODS, XLSX, PPTX, SRT, VTT and Folder have no options.

For the exact ranges, steps and help text, run `anyfmt options <format>` or open a format in the [formats explorer](/formats).

## Change the defaults

The wheel converts with your defaults unless you open the options panel. To change them:

1. Open **Settings › Formats**.
2. Select a format in the list.
3. Change the values under **Defaults for converting to** that format.

**Restore Defaults** puts back the values anyfmt shipped with. You can also tick **Make default for…** in the options panel.

## Presets

A preset is a saved set of options for one target format, such as "Web · 80 %" for JPG.

### On the wheel

Lock a segment with ⌥ Option, or rest on it for about 0.4 seconds, and up to three preset chips appear outside the rim. Move out to a chip and drop to convert with that preset. The preset you used last appears as **Last used** next time.

### Built-in presets

| Format | Preset | Values | Id |
|---|---|---|---|
| JPG | Web · 80 % | quality 80 | `builtin.jpg.web` |
| JPG | Best · 95 % | quality 95 | `builtin.jpg.best` |
| HEIC | Small · 60 % | quality 60 | `builtin.heic.small` |
| HEIC | Best · 90 % | quality 90 | `builtin.heic.best` |
| AVIF | Small · 60 % | quality 60 | `builtin.avif.small` |
| AVIF | Best · 90 % | quality 90 | `builtin.avif.best` |
| WebP | Web · 80 % | quality 80, lossless off | `builtin.webp.web` |
| WebP | Lossless | lossless on | `builtin.webp.lossless` |
| PNG | Screen · 72 dpi | dpi 72 | `builtin.png.screen` |
| PNG | Print · 300 dpi | dpi 300 | `builtin.png.print` |
| GIF | Small · 10 fps · 480 w | fps 10, gifWidth 480 | `builtin.gif.small` |
| GIF | Smooth · 24 fps · 720 w | fps 24, gifWidth 720 | `builtin.gif.smooth` |
| MP4, MOV, WebM | Small · 720p | resolution 720, videoQuality small | `builtin.mp4.small`, `builtin.mov.small`, `builtin.webm.small` |
| MP4, MOV, WebM | Share · 1080p | resolution 1080, videoQuality balanced | `builtin.mp4.share`, `builtin.mov.share`, `builtin.webm.share` |
| MP3, M4A | Voice · 64 kbps mono | bitrate 64, channels mono | `builtin.mp3.voice`, `builtin.m4a.voice` |
| MP3, M4A | Music · 192 kbps | bitrate 192 | `builtin.mp3.music`, `builtin.m4a.music` |

### Save and manage presets

- **From the options panel**: set the values, then choose **Save as Preset**.
- **In Settings**: open **Settings › Formats**, select a format, then **Save Current Defaults as Preset**.
- **From Terminal**: `anyfmt presets add --format mp4 --title "Slack · 720p" --opt videoQuality=small --opt resolution=720`.

In **Settings › Formats › Presets**, each preset has **Use as Defaults**, **Move Up**, **Move Down** and **Delete Preset**. A built-in preset can't be deleted; **Hide Built-in Preset** hides it instead, and **Restore Built-in Presets** brings them all back.

### One file, shared

Presets live in `~/Library/Application Support/anyfmt/presets.json`. The app and the `anyfmt` command read the same file, and each re-reads it when the other changes it, so a preset you add in Terminal is on the wheel the next time it opens, with no relaunch.

## Options from the command line

```bash title="Terminal"
anyfmt options gif --json                       # ids, kinds, ranges, choices, defaults
anyfmt convert clip.mov --to gif --opt gifWidth=480 --opt fps=10
anyfmt convert clip.mov --to gif --preset "Small · 10 fps · 480 w"
```

`--preset` takes a preset id or its title, in any case. Options you pass with `--opt` override the preset's. An unknown option or a bad value stops the command with exit code 2, and the message lists the valid keys or choices. See [Command reference](/docs/cli-reference#convert).
