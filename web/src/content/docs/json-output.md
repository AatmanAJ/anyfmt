---
title: JSON events and exit codes
description: The NDJSON events anyfmt convert and tool print with --json, the error codes inside them, and what every exit code means, with jq examples.
---

With `--json`, `anyfmt convert` and `anyfmt tool` print one JSON event per line on stdout, and every command exits with a stable code. Parse stdout, branch on the exit code, and never on message text.

## A sample stream

Two files, one of them missing:

```bash title="Terminal"
anyfmt convert photo.png gone.png --to jpg --json
```

```json
{"event":"start","jobs":2}
{"code":"input_missing","event":"error","file":"/Users/me/gone.png","message":"no such file or not readable: /Users/me/gone.png"}
{"event":"output","file":"/Users/me/photo.png","path":"/Users/me/photo.jpg"}
{"event":"done","exitCode":6,"failed":1,"skipped":0,"succeeded":1}
```

Each line is one compact object with its keys sorted. The process exits with 6, the same as the `done` event's `exitCode`.

A file that's already in the target format is skipped, and the run still exits with 0:

```json
{"event":"start","jobs":0}
{"event":"skip","file":"/Users/me/photo.png","reason":"already PNG"}
{"event":"done","exitCode":0,"failed":0,"skipped":1,"succeeded":0}
```

## Events

| Event | Fields | When |
|---|---|---|
| `start` | `jobs` | Always the first line. The number of jobs, including ones that already failed while planning |
| `progress` | `file`, `fraction` | While a job runs. `fraction` goes from 0 to 1 with two decimals, at most one event per whole percent, always increasing, ending at 1 |
| `output` | `file`, `path` | Each placed output: one per job. A result with several files is one folder |
| `skip` | `file`, `reason` | The input is already in the target format |
| `error` | `file`, `code`, `message` | A file failed. `code` is one of the error codes below |
| `done` | `succeeded`, `failed`, `skipped`, `exitCode` | Always the last line. `exitCode` matches the process exit code |

- `file` is the absolute input path, or `"N items"` for a combined archive.
- Failures found while planning, such as a missing file, no route, or a taken name with `--overwrite never`, come right after `start`, before any job runs.
- Read the real output path from the `output` event. Don't build it yourself: a taken name gets a number added.
- Progress events depend on timing, so don't count them.

## Error codes

These appear as `code` in `error` events, in MCP tool results, and in the error document below.

| Code | Meaning |
|---|---|
| `usage` | A bad command line: unknown command, flag, format, option or value, or a missing argument |
| `unsupported_route` | No route from the input to the target, or the tool doesn't apply |
| `input_missing` | The input is missing, unreadable or of an unknown kind |
| `engine_failed` | An engine ran and failed. The original is untouched |
| `output_exists` | The output name was taken and you passed `--overwrite never` |
| `cancelled` | The job was cancelled |
| `cloud_unavailable` | The request needs the cloud, which the CLI never uses |

## Exit codes

| Code | Name | Meaning |
|---|---|---|
| 0 | `ok` | Every file converted, or nothing needed converting |
| 2 | `usage` | Unknown command, flag, format, option or value; missing argument |
| 3 | `unsupported_route` | No route from the input to the target, or the tool doesn't apply |
| 4 | `input_missing` | An input is missing, unreadable or of an unknown kind. Engines report damaged files this way too |
| 5 | `engine_failed` | An engine ran and failed; the original is untouched |
| 6 | `partial` | A batch where some files failed, or failures of different kinds. Also `output_exists` |
| 7 | `cancelled` | SIGINT (^C) or MCP cancellation. The job stops, temporary files go, and nothing is placed |
| 8 | `cloud_unavailable` | The request needs the cloud (Pro), which the CLI never uses |

When every job fails the same way, the exit code is that failure's code: one missing file exits with 4. When some files succeed, or the failures differ, it's 6. A second ^C exits at once with 7.

### What to do with each code

| Code | Next step |
|---|---|
| 0 | Read the `output` events |
| 2 | Fix the command. The message lists the valid format ids, option ids or values |
| 3 | Pick another target from `anyfmt targets` |
| 4 | Check the path. The file may be damaged |
| 5 | Try other options or another target. `anyfmt doctor` checks the engines |
| 6 | Read the `error` events and retry only those files |
| 7 | Nothing was placed for the cancelled job |
| 8 | Convert locally instead |

### Codes from earlier builds

Earlier builds used sysexits codes plus 1. They map like this:

| Old | Was | Now |
|---|---|---|
| 64 | Usage, unknown command, unknown format | 2 |
| 65 | Can't detect the file's kind | 4 |
| 65 | The tool doesn't apply to these files | 3 |
| 66 | No such file | 4 |
| 69 | The tool runs in the cloud | 8 |
| 69 | The tool isn't in this build | 3 |
| 1 | Any conversion failure, or `route` without a route | 3, 4, 5 or 6 by cause; `route` gives 3 |

## Failures before any work starts

If a command fails before it does any work, for example with an unknown flag or a bad option value, `--json` prints one error document on stdout instead of events. The message also goes to stderr.

```json title="anyfmt convert photo.png --to jpg --opt quality=loud --json"
{
  "error" : {
    "code" : "usage",
    "exitCode" : 2,
    "message" : "bad value “loud” for option quality"
  }
}
```

Without `--json`, the message goes to stderr and stdout stays empty:

```text
$ anyfmt convert photo.png --to jpg --opt bogus=1
error: unknown option “bogus” for JPG. Valid: quality, background, maxDimension, dpi
```

## Parse it with jq

Keep only outputs and errors:

```bash title="Terminal"
anyfmt convert a.heic b.heic missing.heic --to jpg --json \
  | jq -c 'select(.event == "output" or .event == "error")'
```

Print the new paths, then the exit code. In a pipe, `$?` is jq's code, so use `PIPESTATUS` in bash:

```bash title="convert.sh"
anyfmt convert ~/Pictures/trip/*.heic --to jpg --json \
  | jq -r 'select(.event == "output") | .path'
echo "anyfmt exited with ${PIPESTATUS[0]}"
```

Retry only the files that failed:

```bash title="retry.sh"
out=$(anyfmt convert *.docx --to pdf --json); code=$?
if [ "$code" -eq 6 ]; then
  echo "$out" | jq -r 'select(.event == "error") | .file' \
    | while read -r f; do anyfmt convert "$f" --to pdf --json; done
fi
```

## The same codes over MCP

The MCP server's `convert` and `run_tool` results use the same shape: `{succeeded, failed, skipped, exitCode, results}`, where each result has `outputs` or an `error` with one of the codes above. A failed call has `isError: true`. See [MCP server](/docs/mcp).
