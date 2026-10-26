# anyfmt conversion API (public, pay-per-use)

> **Not built yet: server.** This is a contract, a mock and a client. There is
> no anyfmt server running anywhere, and this repo doesn't contain one. What
> exists today:
>
> - the contract, [`Server/openapi.yaml`](../Server/openapi.yaml) (OpenAPI 3.1, lint-clean under `redocly lint`);
> - an in-memory mock that implements every operation, [`Tests/Mock/server.mjs`](../Tests/Mock/server.mjs). Its conversions are fake: the output is the input bytes renamed;
> - a TypeScript SDK, [`sdk/typescript`](../sdk/typescript), tested against the mock (`make sdk-test`).
>
> The hosted domain isn't chosen yet. Every example below uses
> `https://anyfmt.example.com`. To try them for real, run the mock and use
> `http://127.0.0.1:8787` (see [Try it against the mock](#try-it-against-the-mock)).

The same conversions the Mac app runs locally, offered as an HTTP API for
scripts, CI and other apps. You pay per conversion and per media minute.
Formats, routes and option keys come from the app's own registry, so an option
that works in the wheel (`quality`, `maxDimension`, `videoQuality`…) works the
same way here.

## Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Endpoints](#endpoints): [API keys](#api-keys), [Files](#files), [Conversions](#conversions), [Formats and schema](#formats-and-schema), [Webhooks](#webhooks-endpoints), [Usage](#usage), [Licences](#licences)
- [Webhooks](#webhooks)
- [Errors](#errors)
- [Rate limits and retries](#rate-limits-and-retries)
- [Idempotency](#idempotency)
- [The schema document (`anyfmt schema --json`)](#the-schema-document-anyfmt-schema---json)
- [Versioning policy](#versioning-policy)
- [Try it against the mock](#try-it-against-the-mock)

## Overview

```
upload ──► POST /v1/files ──► fileId
                                │
create ──► POST /v1/conversions {input:{fileId}, target, options} ──► cnv_… (queued)
                                │
          poll GET /v1/conversions/{id}   or   receive conversion.succeeded webhook
                                │
fetch ───► GET /v1/files/{output.id}/content  (Range supported)
```

- Base URL: `https://<server>/v1`. JSON is UTF-8 and camelCase. Timestamps are RFC 3339 UTC.
- IDs are opaque strings (`fil_…`, `cnv_…`, `whk_…`, `key_…`). Don't parse them.
- Every response carries `X-Request-Id`. Include it when you report a problem.
- Inputs and outputs expire (`expiresAt`, 24 h by default) and are then deleted.

## Authentication

There are two credentials. Each one works only where it's meant to:

| Credential | Header | Used for |
|---|---|---|
| **API key** (`apiKeyAuth`) | `Authorization: Bearer anyfmt_sk_…` | The public API: `/v1/files`, `/v1/conversions`, `/v1/formats`, `/v1/schema`, `/v1/webhooks`, `/v1/usage`, and the resumable `/v1/uploads` flow |
| **App sign-in** (`bearerAuth`) | `Authorization: Bearer <OAuth access token>` | The Mac app's endpoints, and **managing API keys** (`/v1/api-keys`). Also accepted by `/v1/usage` |

- Create keys while signed in (the dashboard, or the app's Settings › Account
  once that UI exists). The secret is shown **once**. Afterwards you only see
  its `prefix` (`anyfmt_sk_AbCd`).
- An API key can't create, list or revoke API keys, so a leaked key can't
  mint more of them. An app token is rejected by the public API with
  `401 invalid_api_key`.
- Scopes:

  | Scope | Allows |
  |---|---|
  | `read` | Every `GET`: conversions, file downloads, formats, schema, webhooks, usage |
  | `convert` | Everything that creates or changes something: uploads, conversions, cancel, webhook registration |

  A missing scope returns `403 insufficient_scope`, and `error.details.scope` names it.
- An unknown, revoked or expired key returns `401 invalid_api_key`. Keys never refresh.
- `/v1/formats` and `/v1/schema` also answer without a key.

## Endpoints

All requests in the examples assume:

```bash
export ANYFMT=https://anyfmt.example.com
export ANYFMT_API_KEY=anyfmt_sk_...        # from POST /v1/api-keys
```

### API keys

Authenticated with the **app sign-in** token (`$ANYFMT_TOKEN`), never with an API key.

| Method | Path | |
|---|---|---|
| `POST` | `/v1/api-keys` | Create. `{name, scopes: ["convert","read"], expiresAt?}` → `201 {apiKey, secret}` |
| `GET` | `/v1/api-keys` | List (never includes secrets; revoked keys show `revokedAt`) |
| `DELETE` | `/v1/api-keys/{id}` | Revoke now. `204`. Idempotent |

```bash
curl -s -X POST $ANYFMT/v1/api-keys \
  -H "Authorization: Bearer $ANYFMT_TOKEN" -H 'Content-Type: application/json' \
  -d '{"name": "CI pipeline", "scopes": ["convert", "read"]}'
# {"apiKey":{"id":"key_…","name":"CI pipeline","scopes":["convert","read"],"prefix":"anyfmt_sk_AbCd",…},
#  "secret":"anyfmt_sk_AbCd…"}            ← shown once

curl -s $ANYFMT/v1/api-keys -H "Authorization: Bearer $ANYFMT_TOKEN"
curl -s -X DELETE $ANYFMT/v1/api-keys/key_123 -H "Authorization: Bearer $ANYFMT_TOKEN"
```

### Files

**Which upload to use.** The contract has both:

- **`POST /v1/files` (new)**: a direct upload of the raw body, at most **100 MB**. Use it for almost everything.
- **The existing resumable `/v1/uploads` operations (reused)**: for anything bigger, or on bad networks. They now accept API keys (`convert` scope). A completed `Upload` carries a new `fileId`, which you use as the conversion input. The flow is unchanged from the app: `POST /v1/uploads` with size and SHA-256, then `PUT` chunks with `Content-Range`. After a drop, `HEAD` gives you `Upload-Offset` and you continue from there. Finish with `POST …/complete`.

The SDK picks the right one: direct up to 100 MB, resumable above that or when you pass `resumable: true`.

| Method | Path | |
|---|---|---|
| `POST` | `/v1/files?filename=photo.heic` | Direct upload (≤ 100 MB). Body is the file. `201 StoredFile` |
| `GET` | `/v1/files/{id}/content` | Download. Supports a single `Range` (`bytes=0-1023`, `bytes=1024-`, `bytes=-512`) → `206`; out-of-range → `416 range_not_satisfiable` |
| `POST`/`HEAD`/`PUT`/`DELETE` | `/v1/uploads…` | Resumable flow for larger files (see `Server/openapi.yaml`) |

```bash
curl -s -X POST "$ANYFMT/v1/files?filename=photo.heic" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: image/heic' \
  --data-binary @photo.heic
# {"id":"fil_…","name":"photo.heic","size":2481233,"sha256":"…","format":"heic","expiresAt":"…"}

curl -s -o photo.webp "$ANYFMT/v1/files/fil_out/content" -H "Authorization: Bearer $ANYFMT_API_KEY"
curl -s -H 'Range: bytes=0-1023' "$ANYFMT/v1/files/fil_out/content" -H "Authorization: Bearer $ANYFMT_API_KEY" -o head.bin
curl -s -C - -o big.mp4 "$ANYFMT/v1/files/fil_out/content" -H "Authorization: Bearer $ANYFMT_API_KEY"   # resume
```

The input format is detected from the file name's extension, or from the
`Content-Type`. Pass `input.format` on the conversion to override it.

### Conversions

| Method | Path | |
|---|---|---|
| `POST` | `/v1/conversions` | Start. Send an `Idempotency-Key` header. `202 Conversion` (or `200` + `Idempotent-Replayed: true` on a replay) |
| `GET` | `/v1/conversions/{id}` | Status, progress, output, error, usage |
| `DELETE` | `/v1/conversions/{id}` | Cancel. Idempotent. A finished conversion returns `409 already_finished` |
| `GET` | `/v1/conversions?limit=50&cursor=…&status=succeeded` | List, newest first, cursor pagination |

Request body:

| Field | |
|---|---|
| `input` | Exactly one of `{fileId}` or `{url}` (public http(s), ≤ 100 MB), plus an optional `format` |
| `target` | Output format id from `GET /v1/formats`, e.g. `webp`, `mp4`, `mp3`, `srt` |
| `options` | anyfmt option keys for the route's option schema (`optionsSchema` in `/v1/formats`). Missing keys use the defaults. Unknown keys, wrong types and values out of range return `422 validation_failed` with `details.fields` and `details.problems` |
| `webhook` | Optional. Also notify this URL about this conversion. It must be the URL of a webhook endpoint you registered, because that endpoint's secret signs the delivery |
| `metadata` | Optional. Up to 20 string → string pairs, echoed back and included in webhooks |

`Conversion`:

| Field | |
|---|---|
| `status` | `queued` → `running` → `succeeded` \| `failed` \| `cancelled` |
| `progress` | 0 to 1 |
| `options`, `optionsSchema`, `hops` | The options after defaults were applied, the schema id they were checked against, and how many engine steps the route takes |
| `output` | A `StoredFile` once `succeeded`; download it with `/v1/files/{output.id}/content` |
| `error` | `{code, message}` once `failed` (e.g. `conversion_failed`) |
| `usage` | `{inputBytes, outputBytes, mediaMinutes, billable}`; final once terminal |
| `pollAfterMs` | How long to wait before polling again |

```bash
curl -s -X POST $ANYFMT/v1/conversions \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"input": {"fileId": "fil_123"}, "target": "webp",
       "options": {"quality": 80, "maxDimension": 2048},
       "metadata": {"order": "A-1009"}}'
# 202 {"id":"cnv_…","status":"queued","progress":0,"optionsSchema":"image.webp",
#      "options":{"quality":80,"lossless":false,"maxDimension":2048},"hops":1,…}

curl -s $ANYFMT/v1/conversions/cnv_123 -H "Authorization: Bearer $ANYFMT_API_KEY"
curl -s -X DELETE $ANYFMT/v1/conversions/cnv_123 -H "Authorization: Bearer $ANYFMT_API_KEY"
curl -s "$ANYFMT/v1/conversions?limit=20&status=failed" -H "Authorization: Bearer $ANYFMT_API_KEY"
# {"items":[…], "nextCursor":"eyJhZnRlciI6…"}   → pass back as ?cursor=

# From a URL instead of an upload:
curl -s -X POST $ANYFMT/v1/conversions -H "Authorization: Bearer $ANYFMT_API_KEY" \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuidgen)" \
  -d '{"input": {"url": "https://example.com/talk.mov"}, "target": "mp3", "options": {"bitrate": "192"}}'
```

Billing: a succeeded conversion is billable. A failed one is not. A cancelled
one is billable only if it had already started running.

### Formats and schema

| Method | Path | |
|---|---|---|
| `GET` | `/v1/formats` (optional `?input=heic`) | Every input format with its targets: `{id, hops, via, optionsSchema}` |
| `GET` | `/v1/schema` | The whole registry: formats, option schemas, tools and presets. Sends an `ETag`, so you can use `If-None-Match` |

```bash
curl -s "$ANYFMT/v1/formats?input=heic"
# {"schemaVersion":1,"items":[{"id":"heic","kind":"image","label":"HEIC image",
#   "extensions":["heic","heif"],"targets":[{"id":"webp","hops":1,"via":[],"optionsSchema":"image.webp"},
#   {"id":"pdf","hops":2,"via":["jpg"],"optionsSchema":"to.pdf"},…]}]}

curl -s $ANYFMT/v1/schema | jq '.optionSchemas[] | select(.id=="image.webp")'
```

### Webhooks (endpoints)

| Method | Path | |
|---|---|---|
| `POST` | `/v1/webhooks` | `{url, events: ["conversion.succeeded","conversion.failed"], description?}` → `201` with `secret` (`whsec_…`, shown once) |
| `GET` | `/v1/webhooks` | List (no secrets) |
| `DELETE` | `/v1/webhooks/{id}` | Remove. Pending retries are dropped |

```bash
curl -s -X POST $ANYFMT/v1/webhooks -H "Authorization: Bearer $ANYFMT_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com/anyfmt-hook", "events": ["conversion.succeeded", "conversion.failed"]}'
```

URLs must be `https`. The server refuses URLs that resolve to private,
loopback or link-local addresses. The mock also accepts `http://127.0.0.1`
and `localhost`, so tests can receive deliveries.

### Usage

`GET /v1/usage?period=2026-10` (UTC calendar month; defaults to the current one).

```bash
curl -s "$ANYFMT/v1/usage?period=2026-10" -H "Authorization: Bearer $ANYFMT_API_KEY"
# {"period":{"id":"2026-10","start":"2026-10-01T00:00:00Z","end":"2026-11-01T00:00:00Z"},
#  "conversions":{"total":42,"succeeded":40,"failed":1,"cancelled":1,"billable":40},
#  "mediaMinutes":93.5,"bytes":{"input":1834201190,"output":901233004},
#  "limits":{"conversionsPerMonth":null,"mediaMinutesPerMonth":null,"maxFileBytes":104857600}}
```

`mediaMinutes` counts audio and video duration processed, rounded up to 0.01
per conversion. Other kinds count 0. The mock fakes the duration as 1 minute
per MiB.

### Licences

These are for the Mac app's optional Pro activation, not the conversion API.
The licence key is the credential, so no sign-in is needed.

| Method | Path | |
|---|---|---|
| `POST` | `/v1/licences/activate` | `{key, deviceId, deviceName?}` → `{licence, devices}`. Activating the same device again is a no-op. When all seats are taken: `409 licence_device_limit` with `details.devices` |
| `POST` | `/v1/licences/{id}/deactivate` | `{key, deviceId}` → `{licence, devices}`. Idempotent. The key must match the licence |

```bash
curl -s -X POST $ANYFMT/v1/licences/activate -H 'Content-Type: application/json' \
  -d '{"key": "ANYFMT-MOCK-PRO0-0001", "deviceId": "7c0f3c4e-…", "deviceName": "Studio"}'
# {"licence":{"id":"lic_…","plan":"pro","status":"active","maxDevices":2,"expiresAt":null},
#  "devices":[{"deviceId":"7c0f3c4e-…","name":"Studio","activatedAt":"…"}]}
```

`deviceId` is a random id generated once per install, never a hardware
serial. Other errors: `404 licence_invalid` and `409 licence_revoked`.

## Webhooks

Two event types: `conversion.succeeded` and `conversion.failed`. A delivery is a `POST` with a JSON body:

```json
{ "id": "evt_…", "type": "conversion.succeeded", "createdAt": "2026-10-18T12:00:00Z",
  "data": { "conversion": { "id": "cnv_…", "status": "succeeded", "output": { "id": "fil_…" }, … } } }
```

Headers:

| Header | |
|---|---|
| `Anyfmt-Signature` | `t=<unix seconds>,v1=<hex HMAC-SHA256(secret, t + "." + rawBody)>` |
| `Anyfmt-Webhook-Id` | The endpoint id |
| `Anyfmt-Delivery-Attempt` | 1, 2, 3, … |

**Verifying.** Use the raw body bytes, not a re-serialised object.

1. Split the header on `,`. Take `t` and every `v1`.
2. Reject the delivery if `|now − t| > 300` seconds. The 5-minute tolerance stops replays.
3. Compute `HMAC-SHA256(secret, t + "." + body)` as hex and compare it in constant time with each `v1`. Accept if any one matches; there can be two during a secret rotation.
4. Answer `2xx` within 10 seconds, then do the real work asynchronously.

```js
import { verifyWebhook } from '@anyfmt/sdk';
// Express: app.post('/anyfmt-hook', express.raw({ type: 'application/json' }), …)
const event = verifyWebhook(req.body, req.get('Anyfmt-Signature'), process.env.ANYFMT_WEBHOOK_SECRET);
```

Or by hand:

```bash
t=${HEADER#t=}; t=${t%%,*}
printf '%s.%s' "$t" "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex
```

**Retries.** Any response other than `2xx`, or no answer within 10 seconds,
counts as a failed delivery. Failed deliveries are retried with exponential
backoff at about 1 min, 5 min, 30 min, 2 h, 6 h, 12 h and 24 h after the
first attempt: 8 attempts over roughly two days, after which the delivery
is dropped. The mock uses 50/100/200 ms
(`webhookRetryMs`). Deliveries can repeat and arrive out of order. Dedupe on
`event.id`, which stays the same across retries, and treat
`data.conversion.status` as the truth. If a delivery is missed, you can
always fall back to `GET /v1/conversions/{id}`.

**Routing.** An endpoint receives the event types it subscribed to for every
conversion on the account. A conversion's `webhook` field adds one more
registered URL for that conversion only. A URL gets each event once, even
if both rules match.

## Errors

Every 4xx and 5xx response has the same envelope:

```json
{ "error": { "code": "validation_failed", "message": "Some options aren’t valid for this conversion.",
             "requestId": "req_…", "details": { "fields": ["options.quality"],
             "problems": [{ "field": "options.quality", "reason": "out_of_range", "min": 1, "max": 100 }] } } }
```

`message` is a sentence you can show to a person. Branch on `code`, never on
`message`. If you get a code you don't know, fall back on the HTTP status.

| Status | Codes |
|---|---|
| 400 | `validation_failed` (body isn't JSON) |
| 401 | `invalid_api_key`, `unauthorized`, `token_expired` |
| 402 | `quota_exceeded` |
| 403 | `insufficient_scope`, `forbidden`, `feature_not_in_plan` |
| 404 | `not_found`, `licence_invalid` |
| 409 | `idempotency_conflict`, `already_finished`, `licence_device_limit`, `licence_revoked`, plus the app's `offset_mismatch`, `upload_incomplete`, `version_conflict` |
| 413 | `payload_too_large` (`details.maxBytes`) |
| 416 | `range_not_satisfiable` |
| 422 | `validation_failed`, `unsupported_route` (`details.targets` lists what is possible), `input_unavailable`, `checksum_mismatch`, `unsupported_operation` |
| 428 | `precondition_required` |
| 429 | `rate_limited` |
| 500 / 503 | `internal`, `server_busy`, `maintenance` |

A conversion that fails does so with `200` on `GET`, `status: "failed"` and
`error.code` (`conversion_failed`, `input_unavailable`…). It's not an HTTP error.

SDK error classes: `AnyfmtAuthenticationError` (401), `AnyfmtPermissionError`
(403), `AnyfmtNotFoundError` (404), `AnyfmtConflictError` (409),
`AnyfmtValidationError` (413/416/422), `AnyfmtRateLimitError` (429),
`AnyfmtServerError` (5xx), `AnyfmtConnectionError`, `AnyfmtTimeoutError`,
`AnyfmtConversionFailedError` and `AnyfmtWebhookSignatureError`. All of them
extend `AnyfmtError {status, code, requestId, details}`.

## Rate limits and retries

- Every `/v1` response except `/v1/health` carries `RateLimit-Limit`,
  `RateLimit-Remaining` and `RateLimit-Reset` (seconds until the window resets;
  IETF draft-ietf-httpapi-ratelimit-headers). This includes error responses.
- Over the limit, you get `429 rate_limited` with `Retry-After` (seconds). Wait at least that long.
- `503` may also carry `Retry-After`.
- What clients should do (and the SDK does): retry `429` always, and retry `5xx` or a dropped
  connection only for idempotent requests (`GET`, `DELETE`, uploads, and
  `POST /v1/conversions` with an `Idempotency-Key`). Respect `Retry-After`;
  without it, back off exponentially from 500 ms with jitter. Stop after 3
  retries.
- Limits are per API key. The hosted numbers aren't set yet. The mock allows
  600 a minute and, for tests, `X-Mock-Rate-Limit: N` (N per second).

## Idempotency

`POST /v1/conversions` accepts `Idempotency-Key` (1–255 chars; a UUID is ideal).

- Same key and same body within 24 h: you get the original conversion back
  with `200` and `Idempotent-Replayed: true`. Nothing new starts and nothing
  is billed twice. The body is compared by value, so key order doesn't matter.
- Same key, different body: `409 idempotency_conflict`.
- Keys are scoped to the account.

The SDK sends a random UUID on every `conversions.create`, so its own
automatic retries are always safe. Pass `idempotencyKey` yourself (an order
id, a job id) to make retries safe across process restarts too.

## The schema document (`anyfmt schema --json`)

`GET /v1/schema` returns the same document the CLI's planned
`anyfmt schema --json` will print (phase G). It's defined once, as
`AnyfmtSchema` in `Server/openapi.yaml`, so the server, the CLI and the SDK
can't drift apart.

```jsonc
{
  "schemaVersion": 1,                  // bumps only on a breaking change to this shape
  "generator": "anyfmt 1.0.0",           // or "anyfmt-cloud …" / "anyfmt-mock 1"
  "formats": [{
    "id": "heic", "kind": "image",     // kind: image|video|audio|document|subtitle|archive|data
    "label": "HEIC image",
    "extensions": ["heic", "heif"], "mimeTypes": ["image/heic"],
    "targets": [
      { "id": "webp", "hops": 1, "via": [],      "optionsSchema": "image.webp" },
      { "id": "pdf",  "hops": 2, "via": ["jpg"], "optionsSchema": "to.pdf", "cloudOnly": false }
    ]
  }],
  "optionSchemas": [{
    "id": "image.webp",                // = OptionsSchema.id in Sources/Shared/Options.swift
    "options": [
      { "id": "quality", "label": "Quality", "kind": "slider", "default": 85, "min": 1, "max": 100, "step": 1, "unit": "%" },
      { "id": "lossless", "label": "Lossless", "kind": "toggle", "default": false },
      { "id": "maxDimension", "label": "Max size", "kind": "integer", "default": 0, "min": 0, "max": 32768, "unit": "px",
        "help": "Longest edge in pixels. 0 keeps the original size." }
    ]
  }, {
    "id": "audio.lossy",
    "options": [{ "id": "bitrate", "label": "Bitrate", "kind": "choice", "default": "256",
                  "choices": [{ "id": "128", "label": "128 kbps" }, { "id": "256", "label": "256 kbps" }] }]
  }],
  "tools":   [{ "id": "cloud.transcribe", "label": "Transcribe", "inputs": ["mp4", "mp3"], "optionsSchema": "tool.transcribe", "cloud": true }],
  "presets": [{ "id": "web-image", "label": "Web image", "target": "webp", "options": { "quality": 80, "maxDimension": 2048 } }]
}
```

Option `kind` mirrors `OptionKind`:

| `kind` | Value type | Extra fields |
|---|---|---|
| `slider` | integer | `min`, `max`, `step`, `unit` |
| `integer` | integer | `min`, `max`, `unit` |
| `decimal` | number | `min`, `max`, `step` |
| `toggle` | boolean | |
| `choice` | string: the choice `id`, even when it looks like a number (`"256"`) | `choices[{id,label}]` |
| `fileSize` | integer bytes | |
| `pageRange` | string, `"1-3,5"` or `""` for all pages | |
| `timeRange` | string, `"start-end"` in seconds | |
| `color` | string, `#RRGGBB` or `#RRGGBBAA` | |
| `rect` | string, `"x,y,w,h"` normalised 0–1 | |
| `text` | string | |

`visibleWhen` (optional) says an option only matters when other options
have certain values. A server may publish a subset of the app's registry: it
leaves out app-only keys such as `cloud`, and routes it can't run.

## Versioning policy

- Everything is under `/v1`. Within v1, changes are **additive only**: new
  endpoints, new optional request fields, new response fields, new enum
  values (event types, error codes, formats, option kinds) and new headers.
  Clients must ignore fields they don't know, and must handle unknown enum
  values (an unknown error code falls back on the HTTP status).
- Breaking changes get `/v2`. `/v1` keeps working for at least 12 months
  after `/v2` ships, with `Deprecation` and `Sunset` headers (RFC 9745 /
  RFC 8594) on v1 responses during that time.
- `schemaVersion` in `/v1/schema` and `/v1/formats` versions the registry
  document independently. It goes up only when that document's shape breaks.
  New formats, routes and options don't change it.
- Webhook payloads follow the same rule as responses: fields are only added.
  A breaking payload change would be a new event type.
- The SDK follows semver. Its types are generated from `Server/openapi.yaml`,
  and `npm test` fails if the committed generated file is stale.

## Try it against the mock

```bash
node Tests/Mock/server.mjs --port 8787 &
export ANYFMT=http://127.0.0.1:8787
export ANYFMT_API_KEY=$(curl -s -X POST $ANYFMT/__mock/api-keys -d '{}' | jq -r .secret)
curl -s -X POST "$ANYFMT/v1/files?filename=a.png" -H "Authorization: Bearer $ANYFMT_API_KEY" --data-binary @a.png
```

The `/__mock/…` control endpoints (keys, faults, webhook delivery log,
licences) are listed in [`Tests/Mock/README.md`](../Tests/Mock/README.md).
Conversions finish about 200 ms after creation (`conversionMs`), and their
output is the input bytes under the target's extension.

What the real server still needs, beyond what `Server/README.md` already
lists: API-key hashing and storage, idempotency records (24 h), a durable
webhook delivery queue with the retry schedule above, SSRF-safe fetching for
`input.url` and webhook URLs, metering for usage and billing, and licence
issuance.
