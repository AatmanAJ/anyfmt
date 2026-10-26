# `anyfmt` command line and MCP server

`anyfmt` is the command-line face of the app. It reads the same capability
table, router, engines, tools, option schemas and presets as the wheel, so
whatever the wheel can do, `anyfmt` can do, and the other way round.

It runs entirely on this Mac. Neither the CLI nor `anyfmt mcp` opens a socket or a
port. `make netcheck` samples the sockets of the app, the CLI and the engines
during a workload to confirm it.

- [Install](#install)
- [The contract](#the-contract)
- [Commands](#commands)
- [NDJSON events](#ndjson-events)
- [Exit codes](#exit-codes)
- [Environment](#environment)
- [MCP server](#mcp-server-anyfmt-mcp)
- [Tests](#tests)

## Install

| How | What you get |
|---|---|
| Settings › Advanced › Command-line tool | A symlink to `anyfmt.app/Contents/Helpers/anyfmt` in the first writable folder on your `PATH` (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/bin`) |
| `brew install --cask anyfmt` ([cask](../packaging/homebrew/anyfmt.rb)) | The app, plus the same `anyfmt` symlink |
| `brew install anyfmt-cli` ([formula](../packaging/homebrew/anyfmt-cli.rb)) | The CLI, its framework and engines only, no app |

The CLI looks for `ffmpeg`, `ffprobe` and `resvg` in its own `Helpers`
folder, even when you run it through a symlink. Check what it found with
`anyfmt doctor`.

## The contract

Agents and scripts can rely on all of this. Golden tests (`Tests/CLIGolden`)
fail on any accidental change.

- **`--json` on every command.** It prints one JSON document on stdout:
  pretty-printed, keys sorted, slashes left as they are. `convert` and `tool`
  stream [NDJSON events](#ndjson-events) instead, one compact object per line.
- **stdout is data, stderr is for people.** Without `--json`, stdout carries
  only the results (output paths, list rows) and messages go to stderr. With
  `--json`, stdout is pure JSON. A failure that happens before any work starts
  prints `{"error":{"code","exitCode","message"}}`.
- **It never prompts and assumes no TTY.** The progress line is drawn only
  when stderr is a terminal.
- **It never overwrites.** Outputs go beside each original (or into
  `--out-dir`). A taken name gets a Finder-style one: `photo.jpg`, then
  `photo 2.jpg`. With `--overwrite never`, a taken name fails that file
  (`output_exists`, exit 6). It doesn't overwrite.
- **Options are typed and checked.** `--opt key=value` is checked against the
  route's options and `anyfmt options <format>`. An unknown key or a bad value
  is a usage error (exit 2), and the message lists the valid keys or choices.
  Nothing is silently dropped.
- **Stable [exit codes](#exit-codes)** with the same meaning across commands.

## Commands

```
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

All of them accept `--json`. `--out` still works as an alias of `--out-dir`.

### convert

```sh
anyfmt convert IMG_0042.heic --to jpg --opt quality=85
anyfmt convert clip.mov --to gif --preset "Small · 10 fps · 480 w" --out-dir ~/Desktop/gifs
anyfmt convert *.png --to webp --dry-run --json
anyfmt convert report.docx --to pdf --overwrite never --json
```

- Each file is converted on its own, in order. When the target is an archive
  and you pass several items, they all go into one archive called "Archive",
  as Finder does.
- Files already in the target format are skipped (a `skip` event), and a skip
  isn't a failure.
- `--preset` takes a preset id (`builtin.jpg.web`) or its title (any case).
  Options you pass with `--opt` override the preset's.
- `--opt cloud=true` exits with 8. The CLI only converts on this Mac, and
  cloud jobs run in the app.
- `--dry-run` writes nothing. It prints the route (hops and engines) and the
  output path each file would get. With `--json` that's one document:

```json
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

The `output` path is predicted with the same naming rules the placer uses. It
can still change if another file takes that name before the real run.
`outputIsFolder` is true when a route can produce several files (PDF pages →
PNG): they're placed together in a folder named `photo (PNG)`.

### targets, formats, options, route

- `targets <file>...` lists the formats that every given file can become. For
  each target you get the route per input format (hops and engines),
  `multiHop`, and `shownByDefault`. `shownByDefault: false` means the route
  ships, but the wheel only offers it after you switch it on in
  Settings › Formats.
- `formats` lists every input format with its targets and hop counts, plus
  the total number of conversion options. `--markdown` prints the table in
  `docs/FORMATS.md` (`make readme-formats`).
- `options <format>` prints the options for converting to `<format>`, from
  `OptionsSchema.forTarget`: the same list the presets and Settings › Formats
  use. Each option has an `id`, `label`, `kind` (`slider`, `integer`,
  `decimal`, `toggle`, `choice`, `fileSize`, `color`, `text`, …), `min`, `max`,
  `step` and `unit` where they apply, `choices` (`id` and `label`), a typed
  `default`, `help`, and `visibleWhen` (which other option's value makes this
  one matter). Options for a single job (page ranges, crop rects, cloud) are
  left out. Routes still accept them through `--opt`.
- `route <from> <to>` shows the route the router would plan between two
  format ids.

### tool, tools

`tools` lists every tool: its id, title, the kinds and formats it applies to,
its arity (`perFile` or `combine` with a minimum), its output suffix, and its
options in the same format as `options`. Cloud tools are listed with
`"cloud": true`, and running one exits with 8.

```sh
anyfmt tool image.compress *.png --opt sizeMode=size --opt targetSize=500000
anyfmt tool meta.strip IMG_0042.jpg --json
```

Tool outputs get the tool's suffix (`photo-compressed.png`) and are always
renamed, never overwritten. `--overwrite` isn't available for tools, because
a tool's output extension isn't known before it runs.

### presets

Presets live in the same `presets.json` the app uses
(`~/Library/Application Support/anyfmt/presets.json`).

- `list` shows the user's presets first (in their order), then the visible
  built-ins, by format. `--format` filters by format, and `--all` also lists
  hidden built-ins (`"hidden": true`).
- `show <id|title>` prints one preset.
- `add --format f --title t --opt k=v...` saves a preset. Its values are
  checked against `options f`. It prints the new id (with `--json`, the whole
  preset).
- `rm <id|title>` deletes a user preset. A built-in is hidden instead, as in
  the app.

The app and the CLI share `presets.json`. Each re-reads the file when the other
has changed it, so an edit made here shows up on the app's next wheel without
a relaunch, and neither overwrites the other.

### jobs

`jobs` lists the app's recent conversions, the same store as the menu bar's
"Recent conversions" (`recents.json`: the last 10, newest first, with entries
whose files were deleted pruned). The CLI reads the store and doesn't add its
own runs to it, since the NDJSON stream is the CLI's record of a run. With no
history, `jobs` prints an empty list.

### doctor

`doctor` shows:

- the resolved path of the CLI binary and the app bundle it's inside
- its code signature (`signed`, `ad-hoc` or `unsigned`, plus the authority
  and team, from `/usr/bin/codesign -dv`)
- each engine (`ffmpeg`, `ffprobe`, `resvg`): found or missing, where it came
  from (`bundled`, `ANYFMT_ENGINES_DIR`, …), its first `-version` line, and any
  other copy on your `PATH`, which the CLI doesn't use
- the optional packs (LibreOffice, pandoc)
- the presets/recents folder, the conversion count, and how many table rows
  this build can't serve
- the permissions that can matter

The CLI needs **no** macOS permission. Converting files in Desktop,
Documents or Downloads can trigger a Files and Folders prompt, and macOS asks
on behalf of the terminal app, not anyfmt. The opt-in Pages export needs
Automation, and only the app ever asks for it. `doctor` runs nothing beyond
`-version` and `codesign`.

### schema

`schema --json` prints everything in one versioned document, so an agent can
plan without running any other command:

```
schemaVersion  1 (bumped on any breaking change to this document or the events)
cli            name, version, licence
exitCodes      [{code, name, meaning}]
events         NDJSON event names and their fields
formats        [{id, label, name, kind, extensions, input, output}]
routes         [{from, to, hops:[{from, to, engine}], shownByDefault}] (every planned route)
options        {format: {schema, format, options:[…]}} (every target)
tools          the `tools` list
presets        every preset, hidden built-ins included
mcp            {protocolVersions, tools}
```

## NDJSON events

`convert --json` and `tool --json` print one event per line on stdout:

| event | fields | when |
|---|---|---|
| `start` | `jobs` | first line; the number of jobs, planned failures included |
| `progress` | `file`, `fraction` (0…1, two decimals) | while a job runs; at most one per whole percent, strictly increasing, ending at 1 |
| `output` | `file`, `path` | each placed output (one per job; a multi-file result is one folder) |
| `skip` | `file`, `reason` | the input is already in the target format |
| `error` | `file`, `code`, `message` | a file failed; `code` is one of the codes below |
| `done` | `succeeded`, `failed`, `skipped`, `exitCode` | last line; `exitCode` matches the process exit code |

Error codes: `usage`, `unsupported_route`, `input_missing`, `engine_failed`,
`output_exists`, `cancelled`, `cloud_unavailable`.

Failures found while planning (a missing file, no route, a taken name with
`--overwrite never`) come out right after `start`, before any job runs.
`file` is the absolute input path, or `"N items"` for a combined archive.

```sh
anyfmt convert a.heic b.heic missing.heic --to jpg --json \
  | jq -c 'select(.event == "output" or .event == "error")'
```

## Exit codes

| code | name | meaning |
|---|---|---|
| 0 | ok | every file converted (or nothing needed converting) |
| 2 | usage | unknown command, flag, format, option or value; missing argument |
| 3 | unsupported_route | no route from the input to the target, or the tool doesn't apply |
| 4 | input_missing | an input is missing, unreadable or of an unknown kind (engines report damaged files this way too) |
| 5 | engine_failed | an engine ran and failed; the original is untouched |
| 6 | partial | a batch where some files failed, or failures of different kinds; also `output_exists` |
| 7 | cancelled | SIGINT (^C) or MCP cancellation; the job stops, temp files go, nothing is placed |
| 8 | cloud_unavailable | the request needs the cloud (Pro), which the CLI never uses |

When every job fails the same way, the exit code is that failure's code (one
missing file exits with 4). When some files succeed, or failures differ, it's
6. A second ^C exits at once with 7.

**These codes replace the old ones** (sysexits plus 1). They map as follows:

| old | was | now |
|---|---|---|
| 64 | usage / unknown command / unknown format | 2 |
| 65 | can't detect the file's kind | 4 |
| 65 | the tool doesn't apply to these files | 3 |
| 66 | no such file | 4 |
| 69 | the tool runs in the cloud | 8 |
| 69 | the tool isn't in this build | 3 |
| 1 | any conversion failure, or `route` without a route | 3, 4, 5 or 6 (by cause); `route` → 3 |

## Environment

| variable | effect |
|---|---|
| `ANYFMT_ENGINES_DIR` | a folder containing `Helpers/` with ffmpeg, ffprobe and resvg (development, tests). Leave it unset in normal use |
| `ANYFMT_SUPPORT_DIR` | where `presets.json` and `recents.json` are read and written, instead of `~/Library/Application Support/anyfmt` (tests, sandboxes) |
| `ANYFMT_TEST_DELAY_MS` | test hook: each conversion or tool job waits this long first, and the wait can be cancelled. The tests use it to hit SIGINT and MCP cancellation deterministically |

## MCP server (`anyfmt mcp`)

`anyfmt mcp` is a [Model Context Protocol](https://modelcontextprotocol.io)
server on stdin/stdout. It's a small JSON-RPC 2.0 implementation inside the
CLI with no dependencies (see `Sources/CLI/MCPServer.swift` and
`MCPTools.swift`), and it uses the same code paths as the commands above.

### Configure a client

Claude Code:

```sh
claude mcp add anyfmt -- anyfmt mcp
```

Or in JSON (`.mcp.json`, Claude Desktop, and most other clients):

```json
{
  "mcpServers": {
    "anyfmt": { "command": "anyfmt", "args": ["mcp"] }
  }
}
```

If `anyfmt` isn't on the client's `PATH`, use the full path:
`/Applications/anyfmt.app/Contents/Helpers/anyfmt`.

### Protocol versions

The stdio transport is newline-delimited JSON-RPC, one message per line, with
no embedded newlines. Logs go to stderr and batches are rejected. The server
supports two eras of the protocol:

| era | versions | how a client opens |
|---|---|---|
| modern (stateless) | **2026-07-28** | no handshake. Every request carries `_meta["io.modelcontextprotocol/protocolVersion"]` and `_meta["io.modelcontextprotocol/clientCapabilities"]` |
| legacy (session) | **2025-11-25**, 2025-06-18, 2025-03-26 | `initialize`, then `notifications/initialized` |

**Negotiation.**

- *Legacy:* `initialize` gets the client's `protocolVersion` back when it's
  one of the legacy versions. Otherwise the answer is 2025-11-25, the newest
  legacy version, and the client decides whether to continue. Asking for
  2026-07-28 through `initialize` also gets 2025-11-25, because that version
  has no `initialize`.
- *Modern:* a request whose `_meta` names a version the server doesn't
  support gets `-32022 Unsupported protocol version` with
  `data: {supported: [...], requested}`. A modern request missing
  `clientCapabilities` gets `-32602`. `server/discover` returns
  `supportedVersions`, `capabilities`, `instructions`, `ttlMs` and
  `cacheScope`. Modern results carry `resultType: "complete"` and
  `_meta["io.modelcontextprotocol/serverInfo"]`, and `tools/list` adds `ttlMs`
  and `cacheScope`.
- A request with neither `_meta` version nor an earlier `initialize` gets
  `-32600` with a hint (`server/discover` gets `-32602`). A dual-era client's
  `server/discover` probe therefore gets a modern answer or a modern error,
  never a silent fallback.

**Why 2026-07-28 fits.** Its breaking changes are mostly about sessions and
the HTTP transport: no `initialize`, `Mcp-Session-Id`, the HTTP GET stream,
resumability or `ping`; MRTR replaces server-to-client requests; tasks move
into an extension. This server keeps no state between requests (the presets
file is the only persistent state), never sends requests to the client, and
uses only tools, progress and cancellation. Supporting it meant adding the
per-request `_meta` checks, `server/discover`, `resultType`, the cache hints
and the -32022 error. `ping` stays available to legacy sessions only (a
modern `ping` gets -32601), and `logging`, `resources`, `prompts`, `tasks`
and `subscriptions/listen` aren't offered.

### Methods

| method | notes |
|---|---|
| `initialize` / `notifications/initialized` | legacy handshake. Capabilities: `{"tools":{"listChanged":false}}` |
| `server/discover` | modern discovery (also answered inside a legacy session) |
| `ping` | legacy only; returns `{}` |
| `tools/list` | the seven tools below, in a fixed order, each with a JSON Schema `inputSchema` and annotations |
| `tools/call` | runs a tool. The result has `content: [{type: "text", text: <compact JSON>}]`, the same object in `structuredContent`, and `isError` |
| `notifications/progress` (sent) | when the `tools/call` had `_meta.progressToken`: `{progressToken, progress, total: 1, message}`. `progress` is the overall fraction (0…1, strictly increasing) across the call's files |
| `notifications/cancelled` (received) | `{requestId, reason?}` cancels that in-flight `tools/call`: its engines stop, temp files go, and **no response is sent** for it. Unknown or finished ids are ignored |

Errors: `-32700` parse error (id `null`), `-32600` invalid request (including
batches and non-string/number ids), `-32601` method not found, `-32602`
invalid params or an unknown tool, `-32022` unsupported protocol version.
Problems inside a tool, like a bad argument, a missing file, no route or an
engine failure, are tool results with `isError: true` and
`{"error": {code, exitCode, message}}` (or the per-file `results`), so the
model can correct itself.

When stdin closes, the server finishes the requests already running and
exits with 0.

### Tools

| tool | arguments | returns |
|---|---|---|
| `convert` | `files` [paths], `to`, `options` {id: value}, `preset`, `outDir`, `overwrite` rename/never, `metadata` keep/private/strip, `dryRun` | with `dryRun`: the plan (`anyfmt convert --dry-run --json`). Otherwise `{succeeded, failed, skipped, exitCode, results: [{file, outputs, route} or {file, error}]}` |
| `estimate` | `file`, `to`, `options` | `{bytes, inputBytes, duration, frames, width, height, isExact}` from `Estimator` (the same encoder settings, with a short sample for audio/video). Writes nothing |
| `formats` | `from`? | every format, or the targets of one input format |
| `options` | `format` | as `anyfmt options <format> --json` |
| `presets` | `format`? | as `anyfmt presets list --json` |
| `run_tool` | `tool` (enum of local tools), `files`, `options`, `outDir` | as `convert` |
| `targets` | `files` | as `anyfmt targets --json` |

`options` values can be strings, numbers or booleans. Each one is checked
against the option's kind, exactly as `--opt` is.

### Verified with the official Inspector

`npx @modelcontextprotocol/inspector --cli anyfmt mcp --method tools/list` and
`… --method tools/call --tool-name convert --tool-arg files='["/path/photo.png"]' --tool-arg to=jpg --tool-arg dryRun=true`
both work with Inspector 2.11.0 (2026-10-18). The Inspector speaks the legacy
handshake. The modern path is covered by the transcript test below.

## Tests

- `Tests/Unit/Core/CLI/CLIGoldenTests.swift` runs the built binary and
  compares stdout, stderr and the exit code with `Tests/CLIGolden/*.txt`. It
  covers every `--json` document, the NDJSON stream of a real PNG → JPG
  conversion of a generated fixture, `--dry-run`, `--overwrite never`,
  presets add/show/rm, jobs, and every exit code. Exit 5 uses a stand-in
  ffmpeg that always fails, and exit 7 sends a real SIGINT. Temp paths,
  versions, UUIDs, dates and the region-dependent default page size are
  normalised. Progress lines depend on timing, so they're checked by rule
  (increasing, ending at 1) rather than byte for byte. `doctor` is checked by
  shape, because paths and signatures differ per machine.
- `MCPTranscriptTests.swift` drives `anyfmt mcp` through pipes: version
  negotiation, `ping`, `tools/list`, `targets`, `options`, a `convert` dry run,
  a real `convert` with progress, `estimate`, tool errors, unknown tool and
  method, a parse error, modern `server/discover`, -32022, and a cancelled
  `convert` that never answers. It compares the conversation with
  `Tests/CLIGolden/mcp-transcript.txt`.
- When output changes on purpose, re-record:
  `TEST_RUNNER_HALO_RECORD_GOLDEN=1 make test-unit`, then review the diff.
