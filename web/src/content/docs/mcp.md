---
title: MCP server
description: Run anyfmt mcp to give AI agents local file conversion over the Model Context Protocol, with setup for Claude Code, Claude Desktop and Cursor.
---

`anyfmt mcp` is a [Model Context Protocol](https://modelcontextprotocol.io) server that lets an AI agent convert, compress and inspect files on your Mac. It speaks JSON-RPC over stdin and stdout, opens no socket or port, and uses the same code paths as the `anyfmt` command, so nothing leaves the Mac.

## Before you start

The `anyfmt` command must be installed: link it from **Settings › Advanced › Command-line tool**, or install it with Homebrew. See [Command line](/docs/cli). Check it with:

```bash title="Terminal"
anyfmt doctor
```

## Connect a client

### Claude Code

```bash title="Terminal"
claude mcp add anyfmt -- anyfmt mcp
```

### Claude Desktop

Add anyfmt to `mcpServers` in `claude_desktop_config.json`, then restart Claude Desktop:

```json title="claude_desktop_config.json"
{
  "mcpServers": {
    "anyfmt": { "command": "anyfmt", "args": ["mcp"] }
  }
}
```

If Claude Desktop can't find `anyfmt` on its `PATH` and the server doesn't start, use the full path to the binary inside the app:

```json title="claude_desktop_config.json"
{
  "mcpServers": {
    "anyfmt": { "command": "/Applications/anyfmt.app/Contents/Helpers/anyfmt", "args": ["mcp"] }
  }
}
```

### Cursor

Add the same entry to `.cursor/mcp.json` in your project:

```json title=".cursor/mcp.json"
{
  "mcpServers": {
    "anyfmt": { "command": "anyfmt", "args": ["mcp"] }
  }
}
```

Most other clients that read a `.mcp.json` file take this same shape.

## Tools

The server offers seven tools, always in this order.

| Tool | Arguments | Returns | Writes files |
|---|---|---|---|
| `convert` | `files` (absolute paths), `to`, `options`, `preset`, `outDir`, `overwrite` (`rename` or `never`), `metadata` (`keep`, `private` or `strip`), `dryRun` | With `dryRun`, the plan: routes and output paths. Otherwise `{succeeded, failed, skipped, exitCode, results}`, each result with `outputs` and `route`, or an `error` | Yes, never overwriting |
| `estimate` | `file`, `to`, `options` | `{bytes, inputBytes, duration, frames, width, height, isExact}`, using the real encoder settings and a short sample for audio and video | No |
| `formats` | `from` (optional) | Every format, or the targets of one input format with hop counts | No |
| `options` | `format` | The options for converting to that format, as `anyfmt options <format> --json` | No |
| `presets` | `format` (optional) | Presets, as `anyfmt presets list --json` | No |
| `run_tool` | `tool` (any local tool id), `files`, `options`, `outDir` | The same shape as `convert` | Yes, never overwriting |
| `targets` | `files` | What every given file can become, with routes, as `anyfmt targets --json` | No |

`options` values can be strings, numbers or booleans. Each is checked against the option's kind, exactly as `--opt` is on the command line. Cloud tools aren't offered.

## How an agent should use it

The server's own instructions tell the model to plan first:

1. Call `targets` with the files to see what they can become.
2. Call `options` for the chosen target.
3. Call `convert` with `"dryRun": true` to see the routes and exact output paths.
4. Call `convert` for real.

Call `estimate` to tune options before converting. It returns the expected size, frames and pixel size without writing anything.

## Results and errors

Every tool result carries `content: [{type: "text", text: <compact JSON>}]`, the same object in `structuredContent`, and `isError`.

```json title="convert result"
{
  "exitCode": 0, "failed": 0, "skipped": 0, "succeeded": 1,
  "results": [{
    "file": "/Users/me/photo.png",
    "outputs": ["/Users/me/out/photo.jpg"],
    "route": { "from": "png", "to": "jpg", "hops": [{ "engine": "imageio", "from": "png", "to": "jpg" }], "shownByDefault": true }
  }]
}
```

Problems inside a tool, such as a bad option, a missing file, no route or an engine failure, come back as a result with `isError: true`, so the model can correct itself. The result holds `{"error": {code, exitCode, message}}`, or per-file `results[].error`. The codes and exit codes are the same as the CLI's; see [JSON events and exit codes](/docs/json-output).

Protocol errors use JSON-RPC codes:

| Code | Meaning |
|---|---|
| `-32700` | Parse error (id `null`) |
| `-32600` | Invalid request, including batches and ids that aren't strings or numbers |
| `-32601` | Method not found |
| `-32602` | Invalid params, or an unknown tool |
| `-32022` | Unsupported protocol version |

## Progress and cancellation

- Send `_meta.progressToken` with a `tools/call` to get `notifications/progress` messages: `{progressToken, progress, total: 1, message}`, where `progress` is the overall fraction across the call's files, always increasing.
- Send `notifications/cancelled` with the request id to stop a running `convert`. Its engines stop, temporary files are deleted, and no response is sent for that request.
- When stdin closes, the server finishes the requests already running and exits with 0.

## Protocol versions

Messages are newline-delimited JSON-RPC 2.0, one per line. Logs go to stderr and batches are rejected.

| Era | Versions | How a client opens |
|---|---|---|
| Modern, stateless | **2026-07-28** | No handshake. Every request carries `_meta["io.modelcontextprotocol/protocolVersion"]` and `_meta["io.modelcontextprotocol/clientCapabilities"]`. `server/discover` returns the supported versions, capabilities and instructions |
| Legacy, session | **2025-11-25**, 2025-06-18, 2025-03-26 | `initialize`, then `notifications/initialized` |

- With `initialize`, the server answers with your version if it's one of the legacy ones, and otherwise with 2025-11-25. Asking for 2026-07-28 through `initialize` also gets 2025-11-25, because that version has no `initialize`.
- A modern request naming a version the server doesn't support gets `-32022`, with the supported versions in `data`.
- `ping` works in legacy sessions only.
- The server offers tools, progress and cancellation. It doesn't offer logging, resources, prompts, tasks or subscriptions.

## Check it with the MCP Inspector

```bash title="Terminal"
npx @modelcontextprotocol/inspector --cli anyfmt mcp --method tools/list
```

The official Inspector 2.11.0 passes `tools/list` and `tools/call`. It uses the legacy handshake.
