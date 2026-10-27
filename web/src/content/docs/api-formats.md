---
title: Formats and schema
description: Discover what the anyfmt HTTP API can convert. GET /v1/formats lists targets per input, and GET /v1/schema returns formats, option schemas, tools and presets.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

Two endpoints describe what the API can do. `GET /v1/formats` lists every input format with its targets, and `GET /v1/schema` returns the whole registry: formats, option schemas, tools and presets. Both answer without an API key, so a client can plan before it uploads anything.

## Endpoints

| Method | Path | Returns |
|---|---|---|
| `GET` | `/v1/formats` | Every input format with its targets. Add `?input=heic` for one format; an unknown format gets `404` |
| `GET` | `/v1/schema` | The registry document. Sends an `ETag`, so you can use `If-None-Match` |

## List formats

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1
curl -s "$ANYFMT_API/formats?input=heic"
```

```json title="200 OK"
{"schemaVersion":1,"items":[{"id":"heic","kind":"image","label":"HEIC image",
  "extensions":["heic","heif"],"targets":[{"id":"webp","hops":1,"via":[],"optionsSchema":"image.webp"},
  {"id":"pdf","hops":2,"via":["jpg"],"optionsSchema":"to.pdf"},…]}]}
```

| Field | Meaning |
|---|---|
| `id`, `label` | The format id, such as `heic`, and its name |
| `kind` | `image`, `video`, `audio`, `document`, `subtitle`, `archive` or `data` |
| `extensions`, `mimeTypes` | How files of this format are recognised |
| `targets[].id` | A format it converts to |
| `targets[].hops` | 1 for one engine step; 2 or more go through `via` |
| `targets[].via` | The intermediate formats, in order |
| `targets[].optionsSchema` | The option schema id for this route, or `none` |
| `targets[].cloudOnly` | `true` when only the server can run it, not the app |

## Get the schema

```bash title="Terminal"
curl -s "$ANYFMT_API/schema" | jq '.optionSchemas[] | select(.id == "image.webp")'
```

The document has these keys:

| Key | Contents |
|---|---|
| `schemaVersion` | The document's version, `1`. It goes up only on a breaking change to this shape |
| `generator` | Who produced it, such as an anyfmt server version, or `anyfmt-mock 1` |
| `formats` | The same objects as `/v1/formats` |
| `optionSchemas` | `[{id, options: […]}]`, one per schema id |
| `tools` | `[{id, label, inputs, optionsSchema, cloud}]` |
| `presets` | `[{id, label, target, options}]` |

A server may publish a subset of what the app can do: it leaves out app-only keys such as `cloud`, and routes it can't run.

## Option specs

Each entry in `optionSchemas[].options` describes one option:

```json
{ "id": "quality", "label": "Quality", "kind": "slider", "default": 85, "min": 1, "max": 100, "step": 1, "unit": "%" }
```

| `kind` | Value type | Extra fields |
|---|---|---|
| `slider` | integer | `min`, `max`, `step`, `unit` |
| `integer` | integer | `min`, `max`, `unit` |
| `decimal` | number | `min`, `max`, `step` |
| `toggle` | boolean | |
| `choice` | string: the choice `id`, even when it looks like a number (`"256"`) | `choices: [{id, label}]` |
| `fileSize` | integer bytes | |
| `pageRange` | string such as `"1-3,5"`, or `""` for all pages | |
| `timeRange` | string `"start-end"` in seconds | |
| `color` | string, `#RRGGBB` or `#RRGGBBAA` | |
| `rect` | string `"x,y,w,h"`, each 0 to 1 | |
| `text` | string | |

An option can also have `help`, and `visibleWhen`: the other options' values that make it matter. For example, a compress tool's `targetSize` matters only when `sizeMode` is `size`.

## Cache it

`/v1/schema` sends an `ETag`, which changes whenever any part of the registry changes. Keep a copy of the document and send its `ETag` back as `If-None-Match` on the next request:

```http
GET /v1/schema HTTP/1.1
Host: api.anyfmt.app
If-None-Match: "…"
```

New formats, routes and options don't change `schemaVersion`. Treat unknown formats, option kinds and fields as additions and ignore what you don't use.

## The same registry everywhere

The formats, option keys and schema ids are the app's own. The same option works on the wheel, with `anyfmt convert --opt`, and in a conversion's `options`. On a Mac, `anyfmt schema --json` prints the app's full registry with every local route. See [Command reference](/docs/cli-reference#schema).
