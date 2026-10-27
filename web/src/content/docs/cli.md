---
title: Command line
description: Use the anyfmt command to convert files from Terminal and scripts, with the same routes, options and presets as the wheel, JSON output and stable exit codes.
---

`anyfmt` is the command-line side of the app. It reads the same capability table, engines, tools, option schemas and presets as the wheel, so whatever the wheel can do, `anyfmt` can do, and the other way round. It runs only on your Mac: neither the CLI nor its MCP server opens a socket or a port.

## Install

| How | What you get |
|---|---|
| **Settings › Advanced › Command-line tool › Install** | A link to `anyfmt.app/Contents/Helpers/anyfmt` in the first writable folder on your `PATH`: `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin` or `~/bin` |
| `brew install --cask aatmanaj/tap/anyfmt` | The app, plus the same `anyfmt` link |
| `brew install aatmanaj/tap/anyfmt-cli` | The CLI, its framework and its engines only, with no app |

The CLI finds ffmpeg, ffprobe and resvg in its own `Helpers` folder, even when you run it through a link. It never uses another copy on your `PATH`. Check what it found:

```bash title="Terminal"
anyfmt doctor
```

## First commands

```bash title="Terminal"
anyfmt targets IMG_0042.heic                         # what this file can become
anyfmt convert IMG_0042.heic --to jpg --opt quality=85
anyfmt convert clip.mov --to gif --preset "Small · 10 fps · 480 w" --out-dir ~/Desktop/gifs
anyfmt tool image.compress *.png --opt sizeMode=size --opt targetSize=500000
anyfmt formats                                       # every conversion, with hop counts
```

The full list of commands and flags is in the [Command reference](/docs/cli-reference).

## What scripts can rely on

Golden tests fail the build on any accidental change to these rules.

- **`--json` on every command.** It prints one JSON document on stdout, pretty-printed with sorted keys. `convert` and `tool` stream [NDJSON events](/docs/json-output) instead, one compact object per line.
- **stdout is data, stderr is for people.** Without `--json`, stdout carries only results (output paths, list rows) and messages go to stderr. With `--json`, stdout is pure JSON. A failure before any work starts prints `{"error":{"code","exitCode","message"}}`.
- **It never prompts** and doesn't assume a terminal. The progress line is drawn only when stderr is a terminal.
- **It never overwrites.** Outputs go beside each original, or into `--out-dir`. A taken name gets a Finder-style one: `photo.jpg`, then `photo 2.jpg`. With `--overwrite never`, a taken name fails that file instead (exit 6).
- **Options are typed and checked.** Each `--opt key=value` is checked against the target's options. An unknown key or a bad value is a usage error (exit 2), and the message lists the valid keys or choices. Nothing is silently dropped.
- **Stable [exit codes](/docs/json-output#exit-codes)**, with the same meaning across every command.

## Where outputs go

- Each file is converted on its own, in order. Files already in the target format are skipped, and a skip isn't a failure.
- A route that makes several files, such as PDF pages to PNG, puts them together in a folder named `photo (PNG)`.
- When the target is an archive and you pass several items, they all go into one archive called `Archive`, as Finder does.
- Tool outputs get the tool's suffix, such as `photo-compressed.png`, and are always renamed, never overwritten.
- `--dry-run` writes nothing. It prints the route and the output path each file would get.

```bash title="Terminal"
anyfmt convert *.png --to webp --dry-run --json
```

## Shared with the app

- **Presets.** The CLI reads and writes the same `presets.json` as the app (`~/Library/Application Support/anyfmt/presets.json`). A preset you add with `anyfmt presets add` appears on the wheel next time it opens, with no relaunch.
- **History.** `anyfmt jobs` lists the app's recent conversions, the same list as the menu bar's **Recent Conversions**. The CLI doesn't add its own runs to it; the NDJSON stream is the CLI's record of a run.

## What the CLI won't do

- **Use the cloud.** Pro features run in the app only. `--opt cloud=true` and the cloud tools exit with code 8.
- **Ask for permissions.** The CLI needs no macOS permission. Converting files in Desktop, Documents or Downloads can show a Files and Folders prompt, which macOS raises for your terminal app, not anyfmt.

## Environment variables

| Variable | Effect |
|---|---|
| `ANYFMT_ENGINES_DIR` | A folder containing `Helpers/` with ffmpeg, ffprobe and resvg, for development and tests. Leave it unset in normal use |
| `ANYFMT_SUPPORT_DIR` | Where `presets.json` and `recents.json` are read and written, instead of `~/Library/Application Support/anyfmt`. Useful for tests and sandboxes |
| `ANYFMT_TEST_DELAY_MS` | Test hook: every conversion or tool job waits this long first, and the wait can be cancelled |

## Next

- [Command reference](/docs/cli-reference): every command and flag.
- [JSON events and exit codes](/docs/json-output): parse the output and branch on the result.
- [MCP server](/docs/mcp): the same features for AI agents.
