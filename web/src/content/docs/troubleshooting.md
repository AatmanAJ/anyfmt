---
title: Troubleshooting
description: Fixes for common anyfmt problems, from a wheel that won't open, Photos drags and Gatekeeper warnings to missing engines, packs and Files and Folders prompts.
---

Each entry below starts with what you see and ends with what to do. If your problem isn't here, start with `anyfmt doctor`, which checks the engines, packs, signature and permissions in one go.

## Start with doctor

```bash title="Terminal"
anyfmt doctor
```

It shows where the CLI and the app are, whether the binary is signed, which engines it found and their versions, whether the optional packs are installed, how many conversion options this build has, and the permissions that can matter. It only runs each engine's `-version` and `codesign`, so it's safe to run any time. Add `--json` to paste the output into a bug report.

For problems in the app, **Settings › Advanced › Copy Diagnostics** copies versions, macOS, engines and settings, with no file names or paths.

## The wheel doesn't open when I press Shift

- **Check that the drag carries files.** Drags of text, or of an image that isn't a file, are ignored.
- **Move away from the top of the screen.** The wheel doesn't open in the top 24 points, where the menu bar and Mission Control take drags.
- **Check the key.** Open **Settings › Keys** and see which key opens Convert. If **Only on a quick tap** is chosen, a hold doesn't count; switch to **When the key goes down (tap or hold)**.
- **Press the key after the drag starts.** A key you were already holding when you started dragging is ignored.
- **Check that anyfmt is running.** Its icon should be in the menu bar.

## Dragging from Photos or Mail doesn't open the wheel

Some drags from Photos and Mail end within a second, before a wheel can open. This is a known issue and isn't fixed yet.

- Press ⌃⌥Space first to open the drop ring, then drag the photo or attachment onto it. The ring accepts files from Photos and Mail.
- Or drag the item to the Desktop first, then drag that file.

## Holding ⌘ to move a file in Finder opens the Tools wheel

By default, pressing a trigger key mid-drag opens its wheel, and ⌘ Command opens Tools. Dropping anywhere off the wheel still moves the file. To keep ⌘ for Finder, choose **Settings › Keys › Open the wheel › Only on a quick tap**, or give Tools another key under **Wheels**. Holding ⌘ before you start the drag always works as Finder's move.

## Return in Finder doesn't open the wheel

The Return shortcut is off by default and needs three permissions: Accessibility, Input Monitoring, and Automation for Finder.

1. Open **Settings › Keys › Finder** and turn on **Return opens the wheel for the Finder selection**.
2. Grant each permission listed under it. Each button opens the right pane of System Settings, and anyfmt notices the grant without a restart.
3. Make sure Finder is in front, files are selected, and you aren't renaming a file.

If you'd rather grant nothing, right-click the files and choose **Services › Open in anyfmt Wheel**.

## A Files and Folders prompt appears when I use the CLI

Converting files in Desktop, Documents or Downloads from Terminal can make macOS ask for access. macOS asks on behalf of your terminal app, not anyfmt. Allow it for the terminal, or change it later in **System Settings › Privacy & Security › Files and Folders**. The CLI needs no permission of its own.

## macOS says anyfmt can't be opened

The release DMG is signed with a Developer ID and notarized by Apple, so Gatekeeper opens it without a warning. If you see a warning, you're likely running a build that isn't the release, such as an ad-hoc build made with `make dmg` without signing credentials.

- Run `anyfmt doctor` and look at **signature**. A release build says `signed`, with a Developer ID authority. A local build says `ad-hoc`.
- Install the signed app from [anyfmt.app/download](https://anyfmt.app/download) or with Homebrew.
- If it's a build you made yourself and trust, macOS lets you open it from **System Settings › Privacy & Security** with **Open Anyway**.

## A conversion I expect isn't on the wheel

- **It may be opt-in.** Some routes, such as a photo to DOCX, are hidden by default. Select the target in **Settings › Formats** and turn on **Also offer it for other kinds of files**. The CLI offers every route: `anyfmt targets <file>`.
- **The format may be hidden.** Check **Show on the wheel** for that format in **Settings › Formats**.
- **It may need a pack.** Legacy PPT, Keynote and ODP slides need the Office pack. See below.
- **It may not be supported.** JPEG XL, camera RAW, WMA output, Excel 95 files and ASS subtitles aren't. See [How routes work](/docs/routes#known-gaps).

## The Office pack won't install

The Office pack (LibreOffice) can't be installed yet. The installer accepts only a file that matches a pinned SHA-256, and that checksum isn't pinned in this build, so **Install** is refused. The pandoc pack is pinned and installs normally.

Packs are never downloaded by anyfmt. **Install** in **Settings › Engines** opens the official download page in your browser; then you choose the downloaded file.

## An engine is missing

If `anyfmt doctor` shows ffmpeg, ffprobe or resvg as missing, audio, video and SVG routes disappear.

- Run the CLI from the app (`/Applications/anyfmt.app/Contents/Helpers/anyfmt`) or through the link from **Settings › Advanced › Command-line tool**. The CLI looks for its engines in its own `Helpers` folder, even through a link.
- Unset `ANYFMT_ENGINES_DIR` unless you're developing anyfmt.
- Copies of ffmpeg elsewhere on your `PATH` are never used, so installing one doesn't help.

## A conversion failed

The progress card shows a plain message. Choose **Copy details** to copy the app version, macOS version, the job, the route with its engines, the options and the technical error. File names are included, but never full paths. Choose **Retry** to try again with your current settings. The original file is never touched.

From the CLI, exit code 5 means an engine failed. Try other options or another target. Exit code 4 means the input is missing, unreadable or damaged.

## Encrypted archives won't open

Password-protected archives aren't supported. anyfmt refuses them with a message rather than producing a broken result.

## Remove background only works on people

On macOS 13, the local Remove background tool can cut out people only. On macOS 14 and later it works on any subject.

## I don't feel haptic ticks on the wheel

macOS doesn't deliver haptics to an app that isn't in front, and during a Finder drag Finder is in front. The setting is **Settings › General › Haptic feedback**.

## Still stuck

Turn on **Settings › Advanced › Detailed logging**, reproduce the problem, then use **Copy Command** next to **Read the log in Terminal** to read the last hour of logs. Send the log with the output of **Copy Diagnostics** to support@anyfmt.app.
