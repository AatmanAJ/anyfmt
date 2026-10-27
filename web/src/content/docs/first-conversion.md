---
title: Your first conversion
description: Convert your first file with anyfmt. Drag it in Finder, press Shift mid-drag, drop it on a format, and find the new copy beside the original.
---

This page takes you from a fresh install to a converted file. You start dragging a file in Finder, press ⇧ Shift while you hold the mouse button, and drop the file on the format you want.

## The welcome window

The first time anyfmt opens, a short welcome window walks you through:

1. **Welcome**: what anyfmt does.
2. **A live demo**: drag the sample photo inside the window and try ⇧ Shift, ⌘ Command and ⌃ Control for real.
3. **Permissions**: the wheel needs none. The one optional extra, pressing Return in Finder, is off unless you turn it on.
4. **Launch at login**: start anyfmt with your Mac so the wheel is always there.
5. **Updates**: turn on automatic update checks, or leave them off. Then choose **Start Using anyfmt**.

You can open it again later: hold ⌥ Option while you click the menu bar icon, then choose **Show Welcome…**.

## Convert a file

1. In Finder, start dragging a file, for example a HEIC photo. Keep holding the mouse button.
2. Press ⇧ Shift. You can tap it or hold it. The Convert wheel opens around the pointer, showing only the formats this file can become.
3. Move onto a segment, for example **JPG**. The pill in the centre shows its name.
4. Let go of the mouse button.

The segment flashes, the wheel closes, and a progress card appears near the pointer. When it's done, `photo.jpg` sits next to `photo.heic` and Finder selects it.

To cancel, move back to the centre of the wheel and let go. Nothing happens to the file.

## What you get

- **A new file.** The original is never changed.
- **Never an overwrite.** If `photo.jpg` already exists, the new file is `photo 2.jpg`, as Finder names duplicates.
- **The original's dates.** Converted copies keep the created and modified dates. Turn this off in **Settings › Output**.
- **The original's metadata**, such as camera and location details. To remove it, change **Settings › Output › In converted copies**.
- **A folder for multi-page results.** Converting a three-page `photo.pdf` to PNG gives a folder called `photo (PNG)` with one image per page.

On the build machine (an M5 Max), a 12-megapixel HEIC converts to JPG in about 74 ms.

## Several files at once

Select several files and drag them together. The Convert wheel shows only the formats every file can become. Files already in the target format are skipped, and the progress card says so ("2 already JPG").

When the target is an archive, such as ZIP, everything goes into one archive called `Archive.zip`, as Finder does.

## Try the other wheels

While you're still dragging:

- Press ⌘ Command for **Tools**: compress, resize, crop, trim and more. See [Tools](/docs/tools).
- Press ⌃ Control for **Actions**: AirDrop, Float, Copy, Move, Copy Path and Terminal. See [Actions and Float](/docs/actions).

Press another key to switch wheels without letting go of the file.

## Choose options first

To set quality, size or frame rate before converting, hold ⌥ Option as you drop, or drop on the outer edge of the segment (the pill reads "JPG · Options"). The options panel opens with a live size estimate. See [Options and presets](/docs/options-presets).

## Without dragging

- Right-click files in Finder and choose **Services › Open in anyfmt Wheel**.
- Press ⌃⌥Space to open an empty drop ring at the pointer, then drag files onto it.
- Choose **Open Wheel for Finder Selection** from the menu bar icon.

## From Terminal

```bash title="Terminal"
anyfmt convert IMG_0042.heic --to jpg --opt quality=85
```

See [Command line](/docs/cli).
