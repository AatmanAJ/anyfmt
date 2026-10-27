---
title: Command reference
description: Every anyfmt command and flag, convert, tool, targets, formats, options, route, presets, jobs, doctor, schema and mcp, with what each one prints.
---

This is the reference for every `anyfmt` command, its flags and what it prints. All commands accept `--json`. For the NDJSON stream that `convert` and `tool` print, and for exit codes, see [JSON events and exit codes](/docs/json-output).

## Synopsis

```text
anyfmt convert <file>... --to <format> [--opt key=value]... [--preset <id|title>]
        [--out-dir <dir>] [--overwrite rename|never] [--metadata keep|private|strip] [--dry-run]
anyfmt targets <file>...
anyfmt formats [--from <format>] [--markdown]
anyfmt options <format>
anyfmt tool <tool-id> <file>... [--opt key=value]... [--out-dir <dir>] [--metadata keep|private|strip]
anyfmt tools
anyfmt presets [list [--format <f>] [--all] | show <id|title> | add --format <f> --title <t> --opt k=v... | rm <id|title>]
anyfmt jobs
anyfmt doctor
anyfmt schema
anyfmt route <from> <to>
anyfmt mcp
anyfmt version
anyfmt help
```

Every command takes `--json`. `--out` still works as an alias of `--out-dir`. Format ids are lowercase, such as `jpg`, `heic`, `mp4` and `gz`; run `anyfmt formats` for the full list.

## convert

Converts files to another format.

```bash title="Terminal"
anyfmt convert IMG_0042.heic --to jpg --opt quality=85
anyfmt convert clip.mov --to gif --preset "Small · 10 fps · 480 w" --out-dir ~/Desktop/gifs
anyfmt convert *.png --to webp --dry-run --json
anyfmt convert report.docx --to pdf --overwrite never --json
```

| Flag | Meaning |
|---|---|
| `--to <format>` | Required. The target format id |
| `--opt key=value` | An option for the target. Repeat for several. Check ids with `anyfmt options <format>` |
| `--preset <id\|title>` | A preset id (`builtin.jpg.web`) or its title, in any case. `--opt` values override the preset's |
| `--out-dir <dir>` | Put outputs here instead of beside each original |
| `--overwrite rename\|never` | `rename` (default) picks a Finder-style free name. `never` fails that file with `output_exists` if the name is taken |
| `--metadata keep\|private\|strip` | Keep metadata (default), remove private details (location, device, author), or remove all |
| `--dry-run` | Plan only. Prints each file's route and output path, and writes nothing |
| `--json` | NDJSON events on stdout; with `--dry-run`, one JSON document |

How it behaves:

- Each file is converted on its own, in order.
- When the target is an archive and you pass several items, they all go into one archive called `Archive`.
- Files already in the target format are skipped with a `skip` event. A skip isn't a failure.
- `--opt cloud=true` exits with 8: the CLI only converts on this Mac.

The dry-run document:

```json title="anyfmt convert photo.png --to jpg --opt quality=70 --dry-run --json"
{
  "dryRun" : true,
  "errors" : [],
  "exitCode" : 0,
  "jobs" : [
    {
      "from" : "png",
      "inputs" : ["/Users/me/photo.png"],
      "output" : "/Users/me/photo.jpg",
      "outputIsFolder" : false,
      "route" : {
        "from" : "png",
        "hops" : [ { "engine" : "imageio", "from" : "png", "to" : "jpg" } ],
        "shownByDefault" : true,
        "to" : "jpg"
      },
      "to" : "jpg"
    }
  ],
  "options" : { "quality" : 70 },
  "skipped" : [],
  "to" : "jpg"
}
```

The `output` path is predicted with the same naming rules as a real run. It can still change if another file takes that name first. `outputIsFolder` is `true` when the route makes several files, such as PDF pages to PNG, which go into a folder named `photo (PNG)`.

## targets

Lists the formats that every given file can become.

```bash title="Terminal"
anyfmt targets ~/Pictures/trip/*.heic --json | jq -r '.targets[].format'
```

For each target you get its `format`, `kind` and `label`, the route per input format (hops and engines), `multiHop`, and `shownByDefault`. `"shownByDefault": false` means the route works but the wheel offers it only after you switch it on in **Settings › Formats**.

## formats

Lists every input format with its targets and hop counts, plus the total number of conversion options.

| Flag | Meaning |
|---|---|
| `--from <format>` | Only the targets of one input format |
| `--markdown` | Print the formats table as Markdown |

```bash title="Terminal"
anyfmt formats --from heic --json
```

## options

Prints the options for converting *to* a format: the same list the options panel, presets and **Settings › Formats** use.

```bash title="Terminal"
anyfmt options gif --json | jq -c '.options[] | {id, default, choices: [.choices[]?.id]}'
```

Each option has:

| Field | Meaning |
|---|---|
| `id`, `label` | The key for `--opt`, and its name in the app |
| `kind` | `slider`, `integer`, `decimal`, `toggle`, `choice`, `fileSize`, `color`, `text` and others |
| `min`, `max`, `step`, `unit` | Where they apply |
| `choices` | For `choice`: each `id` and `label`. Pass the `id` |
| `default` | A typed default value |
| `help` | A sentence of help, when there is one |
| `visibleWhen` | Which other option's value makes this one matter |

Options that belong to a single job, such as page ranges, crop rectangles and `cloud`, aren't listed. Routes still accept them through `--opt`.

## route

Shows the route the router would plan between two format ids.

```bash title="Terminal"
anyfmt route heic jpg
```

```text
heic → jpg(imageio)  (cost 1.0)
```

If there's no route, it exits with 3.

## tool

Runs a tool on files.

```bash title="Terminal"
anyfmt tool image.compress *.png --opt sizeMode=size --opt targetSize=500000
anyfmt tool meta.strip IMG_0042.jpg --json
```

| Flag | Meaning |
|---|---|
| `<tool-id>` | Required. A tool id from `anyfmt tools`, such as `image.resize` |
| `--opt key=value` | A tool option. Repeat for several |
| `--out-dir <dir>` | Put outputs here instead of beside each original |
| `--metadata keep\|private\|strip` | As for `convert` |
| `--json` | NDJSON events on stdout |

Tool outputs get the tool's suffix (`photo-compressed.png`) and are always renamed, never overwritten. `--overwrite` isn't available, because a tool's output extension isn't known before it runs. A tool that doesn't apply to the files exits with 3. A cloud tool exits with 8. See [Tools](/docs/tools) for every id.

## tools

Lists every tool: its `id`, `title`, the `kinds` and `formats` it applies to, its `arity` (`perFile`, or `combine` with a `minimum`), its output `suffix`, whether it's `available` in this build, and its `options` in the same shape as `anyfmt options`. Cloud tools are listed with `"cloud": true`.

```bash title="Terminal"
anyfmt tools --json | jq -r '.tools[] | select(.available) | .id'
```

## presets

Manages presets in the same `presets.json` the app uses.

| Subcommand | Does |
|---|---|
| `list [--format <f>] [--all]` | Your presets first, in your order, then the visible built-ins, by format. `--all` adds hidden built-ins (`"hidden": true`). `presets` on its own does the same |
| `show <id\|title>` | Prints one preset |
| `add --format <f> --title <t> --opt k=v...` | Saves a preset. Values are checked against `anyfmt options <f>`. Prints the new id, or with `--json` the whole preset |
| `rm <id\|title>` | Deletes one of your presets. A built-in preset is hidden instead, as in the app |

```bash title="Terminal"
anyfmt presets list --format jpg --json
anyfmt presets add --format jpg --title Tiny --opt quality=40 --json
anyfmt presets rm Tiny
```

```json title="anyfmt presets add --format jpg --title Tiny --opt quality=40 --json"
{
  "builtIn" : false,
  "format" : "jpg",
  "hidden" : false,
  "id" : "6C0D9C4A-…",
  "title" : "Tiny",
  "values" : {
    "quality" : 40
  }
}
```

The app and the CLI each re-read the file when the other has changed it, so neither overwrites the other's edits.

## jobs

Lists the app's recent conversions: the last 10, newest first, with entries whose files were deleted left out. It's the same list as the menu bar's **Recent Conversions**. The CLI doesn't add its own runs. With no history, it prints an empty list.

```json title="anyfmt jobs --json"
{
  "jobs" : [
    {
      "date" : "2026-10-18T12:00:00Z",
      "id" : "3F2A…",
      "outputs" : ["/Users/me/photo.png"],
      "title" : "photo.png → PNG"
    }
  ],
  "limit" : 10,
  "source" : "/Users/me/Library/Application Support/anyfmt/recents.json"
}
```

## doctor

Shows what this install can do, and why. It runs nothing beyond each engine's `-version` and `/usr/bin/codesign -dv`.

| It shows | Details |
|---|---|
| Paths | The CLI binary and the app bundle it's inside |
| Signature | `signed`, `ad-hoc` or `unsigned`, with the signing authority and team |
| Engines | ffmpeg, ffprobe and resvg: found or missing, where from (`bundled`, `ANYFMT_ENGINES_DIR`, …), the first `-version` line, and any other copy on your `PATH`, which the CLI doesn't use |
| Packs | Whether LibreOffice and pandoc are installed, and where |
| Data | The presets and recents folder, the number of conversion options, and how many table rows this build can't serve |
| Permissions | The ones that can matter. The CLI itself needs none |

```bash title="Terminal"
anyfmt doctor --json | jq '.engines[] | {name, found, source}'
```

## schema

Prints everything in one versioned document, so an agent can plan without running any other command.

| Key | Contents |
|---|---|
| `schemaVersion` | `1`. Goes up on any breaking change to this document or to the events |
| `cli` | `name`, `version`, `licence` |
| `exitCodes` | `[{code, name, meaning}]` |
| `events` | NDJSON event names and their fields |
| `formats` | `[{id, label, name, kind, extensions, input, output}]` |
| `routes` | `[{from, to, hops: [{from, to, engine}], shownByDefault}]`, every planned route |
| `options` | `{format: {schema, format, options: […]}}` for every target |
| `tools` | The `anyfmt tools` list |
| `presets` | Every preset, hidden built-ins included |
| `mcp` | `{protocolVersions, tools}` |

```bash title="Terminal"
anyfmt schema --json | jq '.routes | length'     # 793
```

## mcp

Starts the Model Context Protocol server on stdin and stdout. It opens no socket. See [MCP server](/docs/mcp).

## version and help

`anyfmt version` prints the version and licence, for example `anyfmt 0.1.0 (AGPL-3.0-only)`. With `--json` it also includes `schemaVersion`. `anyfmt help` prints the synopsis and a one-line summary of the exit codes.
