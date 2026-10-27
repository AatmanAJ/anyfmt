---
title: Conversions
description: Create, poll, list and cancel conversions with the anyfmt HTTP API, pass options and metadata, use idempotency keys, and read monthly usage.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

A conversion turns one input file into one output in a target format, with anyfmt's own option keys. You create it, then poll it or wait for a webhook, then download its output. This page covers every conversion endpoint, the request and response fields, idempotency and usage.

## Endpoints

| Method | Path | Does |
|---|---|---|
| `POST` | `/v1/conversions` | Starts a conversion. Send an `Idempotency-Key`. Returns `202` with the conversion, or `200` with `Idempotent-Replayed: true` on a replay |
| `GET` | `/v1/conversions/{id}` | Status, progress, output, error and usage |
| `DELETE` | `/v1/conversions/{id}` | Cancels. Safe to repeat. A finished conversion returns `409 already_finished` |
| `GET` | `/v1/conversions?limit=50&cursor=…&status=succeeded` | Lists conversions, newest first, with cursor pagination |

## Create a conversion

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1

curl -s -X POST "$ANYFMT_API/conversions" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"input": {"fileId": "fil_123"}, "target": "webp",
       "options": {"quality": 80, "maxDimension": 2048},
       "metadata": {"order": "A-1009"}}'
```

```json title="202 Accepted"
{"id":"cnv_…","status":"queued","progress":0,"optionsSchema":"image.webp",
 "options":{"quality":80,"lossless":false,"maxDimension":2048},"hops":1,…}
```

Or convert straight from a URL, without uploading:

```bash title="Terminal"
curl -s -X POST "$ANYFMT_API/conversions" -H "Authorization: Bearer $ANYFMT_API_KEY" \
  -H 'Content-Type: application/json' -H "Idempotency-Key: $(uuidgen)" \
  -d '{"input": {"url": "https://example.com/talk.mov"}, "target": "mp3", "options": {"bitrate": "192"}}'
```

### Request body

| Field | Required | Meaning |
|---|---|---|
| `input` | Yes | Exactly one of `{fileId}` or `{url}`, plus an optional `format` that overrides detection. `fileId` comes from `POST /v1/files` or a completed upload. `url` is a public `https` URL the server fetches, at most 100 MB, within 30 seconds |
| `target` | Yes | The output format id from `GET /v1/formats`, such as `webp`, `mp4`, `mp3` or `srt` |
| `options` | No | anyfmt option keys for the route's option schema. Missing keys use the defaults |
| `webhook` | No | Also notify this URL about this conversion. It must be the URL of a webhook endpoint you registered, because that endpoint's secret signs the delivery |
| `metadata` | No | Up to 20 string pairs (keys up to 40 characters, values up to 500), echoed back and included in webhooks |

### Options

Option keys and values are the same as in the app and the CLI. See [Options and presets](/docs/options-presets) for each target, or read `optionsSchema` from [`GET /v1/formats`](/docs/api-formats).

- A `choice` value is its choice id as a string, even when it looks like a number: `"bitrate": "192"`.
- Unknown keys, wrong types and values out of range return `422 validation_failed`, with `details.fields` and `details.problems`.
- The response's `options` show the values after defaults were applied.

## The conversion object

| Field | Meaning |
|---|---|
| `id` | `cnv_…` |
| `status` | `queued`, then `running`, then `succeeded`, `failed` or `cancelled` |
| `progress` | 0 to 1 |
| `input` | `{fileId, url, format, name, size}` |
| `target` | The output format id |
| `options` | The options after defaults were applied |
| `optionsSchema` | The schema id the options were checked against, such as `image.webp` |
| `hops` | How many engine steps the route takes |
| `output` | A file object once `succeeded`. Download it with `GET /v1/files/{output.id}/content` |
| `error` | `{code, message}` once `failed`, for example `conversion_failed` or `input_unavailable` |
| `usage` | `{inputBytes, outputBytes, mediaMinutes, billable}`. Final once the conversion is finished |
| `webhook`, `metadata` | As sent |
| `pollAfterMs` | How long to wait before polling again |
| `createdAt`, `startedAt`, `finishedAt` | Timestamps |

A failed conversion isn't an HTTP error. `GET` returns `200` with `status: "failed"` and an `error.code`.

## Wait for the result

Poll `GET /v1/conversions/{id}`, waiting `pollAfterMs` between requests, until `status` is `succeeded`, `failed` or `cancelled`. Or register a [webhook](/docs/api-webhooks) for `conversion.succeeded` and `conversion.failed`, and keep polling as a fallback.

```bash title="Terminal"
curl -s "$ANYFMT_API/conversions/cnv_123" -H "Authorization: Bearer $ANYFMT_API_KEY"
```

## List conversions

```bash title="Terminal"
curl -s "$ANYFMT_API/conversions?limit=20&status=failed" -H "Authorization: Bearer $ANYFMT_API_KEY"
# {"items":[…], "nextCursor":"eyJhZnRlciI6…"}
```

Pass `nextCursor` back as `?cursor=` for the next page. It's `null` on the last page.

## Cancel

```bash title="Terminal"
curl -s -X DELETE "$ANYFMT_API/conversions/cnv_123" -H "Authorization: Bearer $ANYFMT_API_KEY"
```

Cancelling is safe to repeat. Cancelling a conversion that already finished returns `409 already_finished`.

## Idempotency

`POST /v1/conversions` accepts an `Idempotency-Key` header of 1 to 255 characters. A UUID is ideal.

- **Same key, same body, within 24 hours**: you get the original conversion back with `200` and `Idempotent-Replayed: true`. Nothing new starts, and nothing is billed twice. The body is compared by value, so key order doesn't matter.
- **Same key, different body**: `409 idempotency_conflict`.
- Keys are scoped to your account.

With an `Idempotency-Key`, a retry after a timeout or a `5xx` is safe. Use your own id, such as an order or job id, to make retries safe across process restarts too. The [SDK](/docs/sdk) sends a random UUID on every create.

## Billing

- A conversion that succeeds is billable. A failed one is free.
- A cancelled conversion is billable only if it had already started running.
- `usage.billable` says which applies.

The proposed prices are $0.01 per conversion and $0.02 per minute of audio or video. See [pricing](/pricing).

## Usage

`GET /v1/usage?period=2026-10` returns one UTC calendar month. Leave out `period` for the current month. It takes an API key or an app sign-in token.

```bash title="Terminal"
curl -s "$ANYFMT_API/usage?period=2026-10" -H "Authorization: Bearer $ANYFMT_API_KEY"
```

```json title="200 OK"
{"period":{"id":"2026-10","start":"2026-10-01T00:00:00Z","end":"2026-11-01T00:00:00Z"},
 "conversions":{"total":42,"succeeded":40,"failed":1,"cancelled":1,"billable":40},
 "mediaMinutes":93.5,"bytes":{"input":1834201190,"output":901233004},
 "limits":{"conversionsPerMonth":null,"mediaMinutesPerMonth":null,"maxFileBytes":104857600}}
```

`mediaMinutes` counts audio and video duration processed, rounded up to 0.01 per conversion. Other kinds count 0. The period's `end` is exclusive, and a `null` limit means none. The mock fakes the duration as 1 minute per MiB.
