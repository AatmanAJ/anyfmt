---
title: Webhooks
description: Get anyfmt conversion results by webhook. Register an endpoint, verify the Anyfmt-Signature HMAC header, answer quickly, and handle retries and duplicates.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

Webhooks tell your server when a conversion finishes, so you don't have to poll. You register an HTTPS endpoint, anyfmt signs every delivery with a secret only you and it know, and failed deliveries are retried for about two days.

## Events

| Event | Sent when |
|---|---|
| `conversion.succeeded` | A conversion finished and its output is ready to download |
| `conversion.failed` | A conversion failed. `data.conversion.error` says why |

## Register an endpoint

| Method | Path | Does |
|---|---|---|
| `POST` | `/v1/webhooks` | Registers `{url, events, description?}`. Returns `201` with the signing `secret` (`whsec_…`), shown once |
| `GET` | `/v1/webhooks` | Lists endpoints, without secrets |
| `DELETE` | `/v1/webhooks/{id}` | Removes an endpoint. Pending retries are dropped |

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1

curl -s -X POST "$ANYFMT_API/webhooks" -H "Authorization: Bearer $ANYFMT_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com/anyfmt-hook", "events": ["conversion.succeeded", "conversion.failed"]}'
```

- The URL must be `https`. The server refuses URLs that resolve to private, loopback or link-local addresses.
- The mock also accepts `http://127.0.0.1` and `localhost`, so tests can receive deliveries.
- `description` is optional, up to 200 characters.

## Routing

An endpoint receives the event types it subscribed to, for every conversion on your account. A conversion's own `webhook` field adds one more registered URL for that conversion only. A URL gets each event once, even when both rules match.

## The delivery

A delivery is a `POST` with a JSON body:

```json
{ "id": "evt_…", "type": "conversion.succeeded", "createdAt": "2026-10-18T12:00:00Z",
  "data": { "conversion": { "id": "cnv_…", "status": "succeeded", "output": { "id": "fil_…" }, … } } }
```

`data.conversion` is the full [conversion object](/docs/api-conversions#the-conversion-object), including your `metadata`.

| Header | Value |
|---|---|
| `Anyfmt-Signature` | `t=<unix seconds>,v1=<hex HMAC-SHA256(secret, t + "." + rawBody)>` |
| `Anyfmt-Webhook-Id` | The endpoint id |
| `Anyfmt-Delivery-Attempt` | 1, 2, 3 and so on |

## Verify the signature

Always verify with the raw body bytes, not a re-serialised object.

1. Split the header on `,`. Take `t` and every `v1`.
2. Reject the delivery if `t` is more than 300 seconds from now. This tolerance stops replays.
3. Compute `HMAC-SHA256(secret, t + "." + body)` as hex, and compare it in constant time with each `v1`. Accept if any one matches. There can be two during a secret rotation.
4. Answer with a `2xx` within 10 seconds, then do the real work asynchronously.

With the SDK and Express:

```ts title="hook.ts"
import express from 'express';
import { verifyWebhook, AnyfmtWebhookSignatureError } from '@anyfmt/sdk';

const app = express();
app.post('/anyfmt-hook', express.raw({ type: 'application/json' }), (req, res) => {
  try {
    const event = verifyWebhook(req.body, req.get('Anyfmt-Signature'), process.env.ANYFMT_WEBHOOK_SECRET!);
    res.sendStatus(204);                         // acknowledge fast, then work
    if (event.type === 'conversion.succeeded') queue.push(event.data.conversion.id);
  } catch (e) {
    res.sendStatus(e instanceof AnyfmtWebhookSignatureError ? 400 : 500);
  }
});
```

By hand, in a shell:

```bash title="verify.sh"
t=${HEADER#t=}; t=${t%%,*}
printf '%s.%s' "$t" "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex
```

`verifyWebhook` returns the parsed event, or throws `AnyfmtWebhookSignatureError` with a `reason` of `malformed`, `expired` or `mismatch`.

## Retries

Any response other than `2xx`, or no answer within 10 seconds, counts as a failed delivery. Failed deliveries are retried with exponential backoff, at about 1 minute, 5 minutes, 30 minutes, 2 hours, 6 hours, 12 hours and 24 hours after the first attempt. That's 8 attempts over roughly two days, after which the delivery is dropped. The mock retries after 50, 100 and 200 ms instead.

## Duplicates and order

- Deliveries can repeat and arrive out of order.
- Dedupe on `event.id`, which stays the same across retries.
- Treat `data.conversion.status` as the truth, not the order events arrived in.
- If you miss a delivery, `GET /v1/conversions/{id}` always has the current state.

## Test webhooks with the mock

The mock really delivers webhooks, signed and with retries. Two control endpoints help:

| Endpoint | Does |
|---|---|
| `GET /__mock/webhooks/deliveries` | Every delivery attempt: endpoint, event, type, URL, attempt, status and error |
| `POST /__mock/webhooks/sign` | Returns the `Anyfmt-Signature` the mock would send for `{secret, body, t?}` |
