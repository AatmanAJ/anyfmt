---
title: anyfmt documentation
description: A map of the anyfmt docs. Find the right guide for the Mac app, the command line, MCP and agents, the HTTP API preview, Pro and self-hosting.
---

anyfmt is an open-source (AGPL-3.0) file converter that lives in the menu bar of a Mac with Apple silicon. Start dragging a file in Finder, tap ⇧ Shift, and a wheel of every format that file can become opens around the pointer; drop on one and a converted copy appears beside the original.

Everything that runs on your Mac is free and works offline. The pages below are grouped by what you want to do.

## Use the app

Start here if you want to convert files by dragging them.

- [Install anyfmt](/docs/install): the DMG, Homebrew, the CLI on its own, or a build from source.
- [Your first conversion](/docs/first-conversion): drag, press ⇧ Shift, drop.
- [Permissions](/docs/permissions): why the wheel needs none, and what the two optional extras ask for.
- [The wheel](/docs/wheel): the Convert, Tools and Actions wheels, aiming, locking and the drop ring.
- [Options and presets](/docs/options-presets): quality, size, frame rate and the presets you can drop on.
- [Tools](/docs/tools): the 26 local tools, from Compress to Merge / split / reorder.
- [Actions and Float](/docs/actions): AirDrop, Float, Copy, Move, Copy Path and Terminal.
- [Keys and shortcuts](/docs/keyboard): every key, mid-drag and with a wheel in focus.
- [How routes work](/docs/routes): how anyfmt gets from one format to another, and the 793 tested routes.
- [Settings](/docs/settings): all seven panes, setting by setting.

To see which formats convert to which, open the [formats explorer](/formats).

## Script it

The `anyfmt` command does everything the wheel does, with JSON output and stable exit codes.

- [Command line](/docs/cli): install it, and what scripts can rely on.
- [Command reference](/docs/cli-reference): every command and flag.
- [JSON events and exit codes](/docs/json-output): the NDJSON stream and what each exit code means.

## Give it to an agent

- [MCP server](/docs/mcp): run `anyfmt mcp` and connect Claude Code, Claude Desktop or Cursor.
- [Agent recipes](/docs/agent-recipes): worked examples an agent can follow, from planning to batch conversions.

## Call the HTTP API (preview)

The hosted API isn't live yet. The contract is final for v1, and every example runs against the open-source mock today.

- [API overview](/docs/api): the upload, convert, fetch flow and pay-per-use pricing.
- [Authentication](/docs/api-auth), [Files](/docs/api-files), [Conversions](/docs/api-conversions), [Formats and schema](/docs/api-formats)
- [Webhooks](/docs/api-webhooks), [Errors](/docs/api-errors), [Rate limits and retries](/docs/api-limits)
- [TypeScript SDK](/docs/sdk): `@anyfmt/sdk`.

## Pro and self-hosting

- [What Pro adds](/docs/pro): share links, cloud jobs, sync, inbox and GPU tools. Nothing local is ever behind a paywall.
- [Self-host the server](/docs/self-host): the planned server, its containers and settings, and how to point the app at it.
- [Licence keys](/docs/licence-keys): what an `ANYFMT1-…` key proves, and what it never changes.

Prices are on the [pricing page](/pricing).

## Help

- [Troubleshooting](/docs/troubleshooting): symptoms and fixes, starting with `anyfmt doctor`.
- [Uninstall](/docs/uninstall): remove the app, the CLI and everything they store.

## Status

The first public build of the app is on its way. The Pro features and the HTTP API have a finished Mac client, contract, mock server and SDK, but the hosted server isn't built yet. Pages that describe server features say so at the top.
