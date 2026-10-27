---
title: The wheel
description: How the anyfmt wheel works. Open the Convert, Tools and Actions wheels mid-drag, aim and lock a segment, page through targets, or open it without dragging.
---

The wheel is the ring of choices that opens around the pointer while you drag files. There are three wheels, Convert, Tools and Actions, and each one shows only what applies to the files you're holding.

## Open a wheel

Start dragging files in Finder, then press a trigger key while you hold the mouse button.

| Key (default) | Wheel | Shows |
|---|---|---|
| ⇧ Shift | Convert | The formats this file, or every file in the drag, can become |
| ⌘ Command | Tools | Tools for this kind of file: compress, resize, crop, trim and more |
| ⌃ Control | Actions | AirDrop, Float, Copy, Move, Copy Path and Terminal |

- The wheel opens the moment the key goes down, so a tap and a hold both work.
- Once it's open, let go of the key and keep dragging. The wheel stays open until you drop or cancel.
- Press another trigger key to switch wheels without letting go of the file.
- A key you were already holding when the drag started doesn't count, so Finder's own ⌘ (move) and ⌥ (copy) drag modifiers keep working when you hold them first.

Pressing ⌘ Command after the drag has started opens Tools rather than Finder's move. If you rely on ⌘ mid-drag, choose **Only on a quick tap** in **Settings › Keys › Open the wheel**, or give Tools another key. See [Keys and shortcuts](/docs/keyboard).

## Aim and drop

- **The whole wedge is the target.** The segment is picked by the angle from the centre, so you don't need to land on the label.
- **Aim is sticky.** A highlighted segment stays highlighted until you're clearly inside the next wedge, so a small wobble doesn't change your choice.
- **The centre cancels.** Move back to the middle and let go, and nothing happens to the file.
- **Near a screen edge**, the wheel is pushed inward so it's never clipped.

**Lock a segment** by tapping ⌥ Option mid-drag. An outline appears and the pill in the centre reads, for example, "GIF · Locked". Drift and even the centre can't change the target now: drop anywhere on the wheel and GIF runs. Tap ⌥ Option again to release it. If you make ⌥ Option a trigger key, the lock is off.

## What the wheel shows

- **The centre** shows the file's icon or thumbnail, and its size or "3 files".
- **Order.** On the Convert wheel, your favourite formats come first, in the order set in **Settings › Formats**, then formats of the file's own kind (a video's MP4 before MP3), then the rest.
- **More than 8 choices.** Targets 9 to 20 sit on an outer ring that fills from the top. Beyond 20, the outer ring pages. Mid-drag, hover on its **More** segment for half a second to flip; otherwise click it, press Page Up or Page Down, or scroll.
- **Several files.** Convert shows only targets every file can reach. Files already in the chosen format are skipped and reported.
- **Nothing to convert.** The Actions wheel opens instead, and the centre says "No conversions".
- **Opt-in formats** stay off the wheel until you switch them on. See [How routes work](/docs/routes).

Hide formats and tools from the wheel in **Settings › Formats**.

## Set options, then convert

To change quality, frame rate or other settings first, drop on the **tune lip**, the outer edge of a segment that has options (the pill reads "GIF · Options"), or hold ⌥ Option as you drop. The options panel opens once the drag is over.

Lock a segment, or rest on it for about 0.4 seconds, and up to three **preset chips** appear outside the rim. Drop on one to convert with that preset. See [Options and presets](/docs/options-presets).

## Open the wheel without dragging

- **Services menu.** Right-click files in Finder › **Services › Open in anyfmt Wheel**. Give it a shortcut in **System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders**.
- **Drop ring.** Press ⌃⌥Space and an empty ring opens at the pointer. Drag files onto it and it becomes the Convert wheel. With nothing dropped, it closes after 12 seconds.
- **Menu bar.** Click the anyfmt icon › **Open Wheel for Finder Selection**. macOS asks for Automation for Finder the first time.
- **Return in Finder.** Opt-in, with three permissions. See [Permissions](/docs/permissions).

A wheel opened this way takes the keyboard: arrows move, Return applies, Escape cancels. Right-click a segment for its options.

## Where it doesn't open

- In the top 24 points of the screen, where the menu bar and Mission Control take drags. Move the pointer lower before you press the key.
- For drags that carry no files, such as selected text or a window being moved.

## Speed and accessibility

On the build machine (M5 Max, Release build), the wheel appeared a median 37.6 ms after the key went down, 48.3 ms at most, against a 50 ms budget. Idle, anyfmt uses 0.05 % of one core and 30 MB of memory.

Every segment has a VoiceOver label, Reduce Motion swaps movement for fades, and Increase Contrast and Reduce Transparency get a flat, high-contrast highlight.
