---
title: Install anyfmt
description: Install anyfmt on a Mac with Apple silicon and macOS 13 or later, from the DMG, with Homebrew, as the command-line tool alone, or from source.
---

anyfmt runs on a Mac with Apple silicon and macOS 13 Ventura or later. You can install the app from the DMG or Homebrew, install only the `anyfmt` command-line tool, or build everything from source.

> [!NOTE]
> The first public release of anyfmt is on its way. The steps below describe installing it once that build ships.

## Requirements

| | |
|---|---|
| Mac | Apple silicon (arm64) |
| macOS | 13 Ventura or later |
| Download | 27 MB DMG |
| On disk | 63 MB, engines included |
| Other software | None. ffmpeg, x264/x265, VP9, AV1, Opus, WebP and the SVG renderer ship inside the app, so you never need Homebrew or ffmpeg of your own |

Every binary in the app targets macOS 13. So far the full test suite and the conversion matrix have run on macOS 27 only; checks on macOS 13, 14 and 15 are still to do.

## Download the DMG

1. Download the DMG from [anyfmt.app/download](https://anyfmt.app/download).
2. Open `anyfmt-x.y.z.dmg` and drag **anyfmt** to **Applications**.
3. Open anyfmt from Applications.
4. The welcome window opens. It walks you through a live demo of the wheel, permissions (none are needed), launch at login and update checks.

anyfmt appears as an icon in the menu bar. It has no Dock icon and no main window.

## Install with Homebrew

```bash title="Terminal"
brew install --cask aiwithaj/tap/anyfmt
```

The cask installs the app and links the `anyfmt` command onto your `PATH`.

## Install only the command-line tool

If you want the CLI and the MCP server without the app:

```bash title="Terminal"
brew install aiwithaj/tap/anyfmt-cli
```

This installs `anyfmt`, its framework and the bundled engines (ffmpeg, ffprobe, resvg), and no app. Install either the cask or this formula, not both: each one puts `anyfmt` on your `PATH`.

Check what it found:

```bash title="Terminal"
anyfmt doctor
```

## Build from source

You need Xcode 16 or later (Swift 6) and Rust, which builds the SVG renderer.

```bash title="Terminal"
git clone https://github.com/AatmanAJ/anyfmt && cd anyfmt
make bootstrap   # build-machine tools (xcodegen, meson, ninja, nasm)
make engines     # ffmpeg/ffprobe/resvg from pinned, checksummed sources
make build
make test
make matrix      # every conversion on a generated fixture
make dmg         # styled DMG
```

`make engines` takes about 10 minutes the first time. `make dmg` signs and notarizes only when Developer ID credentials are present; otherwise it makes an ad-hoc signed DMG. Every feature works the same in both.

## Put `anyfmt` on your PATH

The command-line tool ships inside the app at `/Applications/anyfmt.app/Contents/Helpers/anyfmt`. If you installed the DMG, link it once:

1. Open **Settings › Advanced**.
2. Next to **Command-line tool**, choose **Install**.

anyfmt links the tool into the first writable folder on your `PATH` (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin` or `~/bin`), with no password. If that fails, choose **Copy Command** and run the `ln -s` line it copies in Terminal.

The Homebrew cask and formula do this for you. See [Command line](/docs/cli) for what to do next.

## Updates

Update checks are off until you turn them on, in the welcome window or in **Settings › General › Check for updates automatically**. When they're on, anyfmt fetches an update feed once a day and sends nothing else. **Check Now** asks once, even with automatic checks off.

## What it costs

Every conversion, tool and action is free, including commercial use, however you install anyfmt. Building from source is free. The Desktop licence ($19 once) pays for the signed, notarized app and every update, on up to 3 Macs. See [pricing](/pricing).

## Next

- [Your first conversion](/docs/first-conversion)
- [Permissions](/docs/permissions)
- [Uninstall](/docs/uninstall)
