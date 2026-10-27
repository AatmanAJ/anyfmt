---
title: HTTP API overview
description: The anyfmt HTTP API runs the app's conversions for scripts, CI and other apps. Learn the upload, convert and download flow, conventions and pricing.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

The anyfmt HTTP API offers the same conversions the Mac app runs locally, for scripts, CI and other apps. Formats, routes and option keys come from the app's own registry, so an option that works on the wheel, such as `quality`, `maxDimension` or `videoQuality`, works the same way here. You pay per conversion and per media minute.

## How it works

```text
upload ──► POST /v1/files ──► fileId
                                │
create ──► POST /v1/conversions {input: {fileId}, target, options} ──► cnv_… (queued)
                                │
wait ────► GET /v1/conversions/{id}   or   a conversion.succeeded webhook
                                │
fetch ───► GET /v1/files/{output.id}/content   (Range supported)
```

## Quick start

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1
export ANYFMT_API_KEY=anyfmt_sk_...

# 1. Upload
curl -s -X POST "$ANYFMT_API/files?filename=photo.heic" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: image/heic' \
  --data-binary @photo.heic
# {"id":"fil_…","name":"photo.heic","size":2481233,"sha256":"…","format":"heic","expiresAt":"…"}

# 2. Convert
curl -s -X POST "$ANYFMT_API/conversions" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"input": {"fileId": "fil_123"}, "target": "webp", "options": {"quality": 80}}'
# 202 {"id":"cnv_…","status":"queued","progress":0,…}

# 3. Poll until status is "succeeded"
curl -s "$ANYFMT_API/conversions/cnv_123" -H "Authorization: Bearer $ANYFMT_API_KEY"

# 4. Download the output
curl -s -o photo.webp "$ANYFMT_API/files/fil_out/content" -H "Authorization: Bearer $ANYFMT_API_KEY"
```

## Try it against the mock

```bash title="Terminal"
node Tests/Mock/server.mjs --port 8787 &
export ANYFMT_API=http://127.0.0.1:8787/v1
export ANYFMT_API_KEY=$(curl -s -X POST http://127.0.0.1:8787/__mock/api-keys -d '{}' | jq -r .secret)
curl -s -X POST "$ANYFMT_API/files?filename=a.png" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" --data-binary @a.png
```

The mock needs only Node.js, with nothing to install. Its conversions are fake: about 200 ms after you create one, it succeeds, and the output is the input's bytes under the target's extension. Options are still checked against the real option schemas, and idempotency, webhooks and rate-limit headers behave as the contract says.

## Conventions

- **Base URL**: `https://api.anyfmt.app/v1` (planned). Every path is under `/v1`.
- **JSON** is UTF-8 and camelCase. Timestamps are RFC 3339 in UTC.
- **IDs** are opaque strings with a prefix: `fil_…`, `cnv_…`, `whk_…`, `key_…`. Don't parse them.
- **Every response** carries `X-Request-Id`. Include it when you report a problem.
- **Files expire.** Inputs and outputs have an `expiresAt`, 24 hours by default, and are then deleted.
- **Errors** share one envelope with a stable `code`. See [Errors](/docs/api-errors).

## Endpoints

| Area | Endpoints | Page |
|---|---|---|
| API keys | `POST`, `GET /v1/api-keys`, `DELETE /v1/api-keys/{id}` | [Authentication](/docs/api-auth) |
| Files | `POST /v1/files`, `GET /v1/files/{id}/content`, the resumable `/v1/uploads` flow | [Files](/docs/api-files) |
| Conversions | `POST`, `GET /v1/conversions`, `GET`, `DELETE /v1/conversions/{id}` | [Conversions](/docs/api-conversions) |
| Formats and schema | `GET /v1/formats`, `GET /v1/schema` | [Formats and schema](/docs/api-formats) |
| Webhooks | `POST`, `GET /v1/webhooks`, `DELETE /v1/webhooks/{id}` | [Webhooks](/docs/api-webhooks) |
| Usage | `GET /v1/usage?period=2026-10` | [Conversions](/docs/api-conversions#usage) |

The full contract is an OpenAPI 3.1 file, `Server/openapi.yaml`, in the anyfmt repository.

## Pricing

The API is pay-per-use. The proposed prices are:

| | Price |
|---|---|
| Each conversion | $0.01 |
| Each minute of audio or video processed | $0.02 |

- A conversion that succeeds is billable. A failed one is free.
- A cancelled conversion is billable only if it had already started running.
- Media minutes count the audio and video duration processed, rounded up to 0.01 minute per conversion. Other kinds count 0.

See [pricing](/pricing).

## Versioning

- Everything is under `/v1`. Within v1, changes are **additive only**: new endpoints, new optional request fields, new response fields, new enum values (event types, error codes, formats, option kinds) and new headers.
- Ignore fields you don't know, and handle enum values you don't know. An unknown error code falls back on the HTTP status.
- Breaking changes get `/v2`. `/v1` keeps working for at least 12 months after `/v2` ships, with `Deprecation` and `Sunset` headers on v1 responses during that time.
- `schemaVersion` in `/v1/formats` and `/v1/schema` versions the registry document on its own. It goes up only when that document's shape breaks; new formats, routes and options don't change it.
- Webhook payloads follow the same rule. A breaking payload change would be a new event type.

## Next

- [Authentication](/docs/api-auth): API keys and scopes.
- [TypeScript SDK](/docs/sdk): upload, convert, wait and download in a few lines.
