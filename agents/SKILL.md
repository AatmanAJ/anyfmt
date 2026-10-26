---
name: anyfmt
description: Convert, compress and inspect local files (images, video, audio, PDFs, documents, ebooks, subtitles, archives) on macOS with the `anyfmt` CLI or its MCP server. Use when a task needs a file in another format, a smaller file, stripped metadata, or a size estimate, and the files are on this Mac. Everything runs locally, and outputs never overwrite anything.
---

# Using anyfmt from an agent

`anyfmt` is the command-line tool of the anyfmt app. It converts files on this
Mac with the same routes, engines, options and presets as the app. Nothing is
uploaded. The full contract is in [docs/CLI.md](../docs/CLI.md).

## Rules of thumb

1. **Plan before converting.** Use `anyfmt targets <file> --json` to see what a
   file can become, or read `anyfmt schema --json` once for everything (formats,
   routes, options, tools, presets, exit codes).
2. **Dry-run first.** `anyfmt convert … --dry-run --json` shows the route and
   the exact output path, and writes nothing.
3. **Always pass `--json`.** Parse stdout only; stderr is for people.
   `convert` and `tool` print NDJSON (one event per line).
4. **Branch on the exit code**, not on message text.
5. **Never expect an overwrite.** Outputs land beside the original (or in
   `--out-dir`) as `name.ext`, then `name 2.ext`. Read the real path from the
   `output` event. Use `--overwrite never` to fail instead of renaming.
6. **Use exact option ids and values** from `anyfmt options <format> --json`.
   An unknown key or a bad value is exit 2, with the valid choices in the
   message.

## Exit codes

| code | meaning | what to do |
|---|---|---|
| 0 | ok | read the `output` events |
| 2 | usage | fix the command: format id, option id or value (the message lists the valid ones) |
| 3 | unsupported route | pick another target from `anyfmt targets` |
| 4 | input missing, unreadable or of an unknown kind | check the path; the file may be damaged |
| 5 | engine failed | try other options or another target; `anyfmt doctor` checks the engines |
| 6 | partial batch (or the name was taken with `--overwrite never`) | read the `error` events, retry only those files |
| 7 | cancelled | nothing was placed for the cancelled job |
| 8 | needs the cloud (Pro) | not available from the CLI; convert locally instead |

## NDJSON events (convert, tool)

```
{"event":"start","jobs":2}
{"event":"progress","file":"/abs/a.heic","fraction":0.42}
{"event":"output","file":"/abs/a.heic","path":"/abs/a.jpg"}
{"event":"error","file":"/abs/b.heic","code":"input_missing","message":"…"}
{"event":"skip","file":"/abs/c.jpg","reason":"already JPG"}
{"event":"done","succeeded":1,"failed":1,"skipped":1,"exitCode":6}
```

`code` is one of `usage`, `unsupported_route`, `input_missing`,
`engine_failed`, `output_exists`, `cancelled`, `cloud_unavailable`. Failures
found while planning come right after `start`. The last line is always
`done`, and its `exitCode` matches the process exit code.

## Worked examples

### 1. "Make these HEIC photos into JPGs for the web"

```sh
anyfmt targets ~/Pictures/trip/*.heic --json | jq -r '.targets[].format'   # jpg is listed
anyfmt options jpg --json | jq '.options[] | {id, default, min, max}'      # quality 1…100, default 85
anyfmt presets list --format jpg --json | jq -r '.presets[] | "\(.id)  \(.title)"'
#   builtin.jpg.web   Web · 80 %
anyfmt convert ~/Pictures/trip/*.heic --to jpg --preset builtin.jpg.web --out-dir ~/Pictures/trip/web --dry-run --json \
  | jq -r '.jobs[] | "\(.inputs[0]) → \(.output)"'
anyfmt convert ~/Pictures/trip/*.heic --to jpg --preset builtin.jpg.web --out-dir ~/Pictures/trip/web --json \
  | jq -r 'select(.event=="output") | .path'
echo "exit $?"   # with a pipe, use ${PIPESTATUS[0]} in bash for anyfmt's code
```

### 2. "Turn this screen recording into a small GIF"

```sh
anyfmt options gif --json | jq -c '.options[] | {id, default, choices: [.choices[]?.id]}'
#   gifWidth 640 [0 960 720 640 480 320], fps 15 [10 15 24 30], gifLoop, gifColors, gifDither
anyfmt convert ~/Desktop/demo.mov --to gif --opt gifWidth=480 --opt fps=10 --opt gifColors=64 --json
```

Over MCP, call `estimate` first (`{"file": "…/demo.mov", "to": "gif",
"options": {"gifWidth": 480, "fps": 10}}`). It returns the expected `bytes`,
`frames` and pixel size without writing anything, so you can tune options
before converting.

### 3. Batch with partial failure

```sh
out=$(anyfmt convert *.docx --to pdf --json); code=$?
echo "$out" | jq -c 'select(.event=="error") | {file, code}'
[ "$code" -eq 6 ] && echo "some failed; retry those"
```

### 4. Tools (compress, strip metadata, …)

```sh
anyfmt tools --json | jq -r '.tools[] | select(.available) | .id'
anyfmt tool image.compress big.png --opt sizeMode=size --opt targetSize=500000 --json
anyfmt tool meta.strip IMG_0042.jpg --json          # → IMG_0042-clean.jpg
```

### 5. Save a preset the app will also show

```sh
anyfmt presets add --format mp4 --title "Slack · 720p" --opt videoQuality=small --opt resolution=720 --json
anyfmt convert talk.mov --to mp4 --preset "Slack · 720p" --json
```

The app picks up presets made here on its next wheel (they share one file).

## MCP

Add the server to Claude Code:

```sh
claude mcp add anyfmt -- anyfmt mcp
```

Or as JSON (`.mcp.json`, Claude Desktop and similar):

```json
{
  "mcpServers": {
    "anyfmt": { "command": "anyfmt", "args": ["mcp"] }
  }
}
```

If `anyfmt` isn't on `PATH`, use `/Applications/anyfmt.app/Contents/Helpers/anyfmt`.

Tools: `targets`, `options`, `formats`, `presets`, `estimate` (read-only), and
`convert` and `run_tool` (write new files, never overwrite). Use the same flow
as on the CLI: `targets` → `options` → `convert` with `"dryRun": true` →
`convert`. Results come as JSON text plus `structuredContent`. A failure is
`isError: true` with `error.code` / `exitCode`, or per-file `results[].error`.
Send a `progressToken` to get progress notifications, and
`notifications/cancelled` to stop a running convert.

Supported protocol versions: 2026-07-28 (stateless, `_meta` per request,
`server/discover`) and 2025-11-25, 2025-06-18, 2025-03-26 (`initialize`).

## Troubleshooting

- `anyfmt doctor --json` shows the engines found (ffmpeg, ffprobe, resvg) and
  their versions, the optional packs, the binary's signature, and the
  permissions that can matter. The CLI itself needs none.
- A route missing from `targets` may need an optional pack (LibreOffice or
  pandoc, installed from the app), and `doctor` shows whether it's there.
- Files in Desktop, Documents or Downloads may trigger a macOS
  Files-and-Folders prompt for your terminal. Grant it there; anyfmt can't.
