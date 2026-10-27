---
title: Agent recipes
description: Worked examples for AI agents that use anyfmt, plan with targets and dry runs, convert photos and screen recordings, handle partial batches and save presets.
---

These recipes show an agent how to use anyfmt safely, through the command line or the MCP server. Each one follows the same pattern: find out what's possible, dry-run, convert, then read the real output paths. Everything runs on the Mac, and outputs never overwrite anything.

## Rules of thumb

1. **Plan before converting.** Run `anyfmt targets <file> --json` to see what a file can become, or read `anyfmt schema --json` once for everything: formats, routes, options, tools, presets and exit codes.
2. **Dry-run first.** `anyfmt convert … --dry-run --json` shows the route and the exact output path, and writes nothing.
3. **Always pass `--json`.** Parse stdout only; stderr is for people. `convert` and `tool` print one JSON event per line.
4. **Branch on the exit code**, never on message text. See [JSON events and exit codes](/docs/json-output).
5. **Don't expect an overwrite.** Outputs land beside the original, or in `--out-dir`, as `name.ext`, then `name 2.ext`. Read the real path from the `output` event. Pass `--overwrite never` to fail instead of renaming.
6. **Use exact option ids and values** from `anyfmt options <format> --json`. An unknown key or a bad value exits with 2, and the message lists the valid choices.

## Make HEIC photos into JPGs for the web

```bash title="Terminal"
anyfmt targets ~/Pictures/trip/*.heic --json | jq -r '.targets[].format'     # jpg is listed
anyfmt options jpg --json | jq '.options[] | {id, default, min, max}'        # quality 1–100, default 85
anyfmt presets list --format jpg --json | jq -r '.presets[] | "\(.id)  \(.title)"'
#   builtin.jpg.web   Web · 80 %

anyfmt convert ~/Pictures/trip/*.heic --to jpg --preset builtin.jpg.web \
  --out-dir ~/Pictures/trip/web --dry-run --json \
  | jq -r '.jobs[] | "\(.inputs[0]) → \(.output)"'

anyfmt convert ~/Pictures/trip/*.heic --to jpg --preset builtin.jpg.web \
  --out-dir ~/Pictures/trip/web --json \
  | jq -r 'select(.event == "output") | .path'
echo "exit ${PIPESTATUS[0]}"
```

In a pipe, `$?` is the last command's code, so read anyfmt's from `${PIPESTATUS[0]}` in bash.

## Turn a screen recording into a small GIF

```bash title="Terminal"
anyfmt options gif --json | jq -c '.options[] | {id, default, choices: [.choices[]?.id]}'
#   gifWidth 640 [0 960 720 640 480 320], fps 15 [10 15 24 30], gifLoop, gifColors, gifDither
anyfmt convert ~/Desktop/demo.mov --to gif --opt gifWidth=480 --opt fps=10 --opt gifColors=64 --json
```

Over MCP, call `estimate` first. It returns the expected `bytes`, `frames` and pixel size without writing anything, so you can tune the options before converting:

```json title="estimate arguments"
{ "file": "/Users/me/Desktop/demo.mov", "to": "gif", "options": { "gifWidth": 480, "fps": 10 } }
```

## Handle a batch where some files fail

```bash title="Terminal"
out=$(anyfmt convert *.docx --to pdf --json); code=$?
echo "$out" | jq -c 'select(.event == "error") | {file, code}'
[ "$code" -eq 6 ] && echo "some files failed; retry only those"
```

Exit code 6 means some files succeeded and some didn't, or the failures differ. Read the `error` events and retry only those files. If every file failed the same way, the exit code is that failure's code, such as 4 for missing inputs.

## Compress images or strip metadata

```bash title="Terminal"
anyfmt tools --json | jq -r '.tools[] | select(.available) | .id'
anyfmt tool image.compress big.png --opt sizeMode=size --opt targetSize=500000 --json
anyfmt tool meta.strip IMG_0042.jpg --json          # → IMG_0042-clean.jpg
```

Target sizes are in bytes. Tool outputs always get the tool's suffix, such as `-compressed` or `-clean`.

## Save a preset the app will show too

```bash title="Terminal"
anyfmt presets add --format mp4 --title "Slack · 720p" --opt videoQuality=small --opt resolution=720 --json
anyfmt convert talk.mov --to mp4 --preset "Slack · 720p" --json
```

The app and the CLI share one presets file, so the new preset appears on the wheel the next time it opens.

## The same flow over MCP

With the [MCP server](/docs/mcp) connected, an agent calls tools instead of commands:

1. `targets` with `{"files": ["/abs/path/photo.heic"]}`.
2. `options` with `{"format": "jpg"}`.
3. `convert` with `{"files": […], "to": "jpg", "options": {"quality": 80}, "dryRun": true}`.
4. `convert` again without `dryRun`.

Paths must be absolute. A failure comes back as a result with `isError: true` and an `error.code`, or a per-file `results[].error`, so the agent can fix the call and try again. Send a `progressToken` for progress notifications, and `notifications/cancelled` to stop a long conversion.

## When something's missing

- `anyfmt doctor --json` shows the engines it found and their versions, the optional packs, the binary's signature, and the permissions that can matter. The CLI itself needs none.
- A route missing from `targets` may need an optional pack (pandoc or LibreOffice), installed from the app's **Settings › Engines**. `doctor` shows whether it's there.
- Files in Desktop, Documents or Downloads can trigger a macOS Files and Folders prompt for your terminal app. Grant it there; anyfmt can't.
- Exit code 8 means the request asked for a cloud feature, which the CLI never uses. Convert locally instead.

The repository also ships these rules as an agent skill file, `agents/SKILL.md`, that you can give to an agent directly.
