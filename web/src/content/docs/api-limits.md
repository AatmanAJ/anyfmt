---
title: Rate limits and retries
description: Rate-limit headers on the anyfmt HTTP API, what a 429 means, which requests are safe to retry, and the backoff the TypeScript SDK uses by default.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

The anyfmt API limits requests per API key and tells you where you stand on every response. This page covers the rate-limit headers, what to do on a `429` or a `5xx`, which requests are safe to retry, and the size and time limits.

## Rate-limit headers

Every `/v1` response except `/v1/health` carries these headers, error responses included:

| Header | Meaning |
|---|---|
| `RateLimit-Limit` | Requests allowed in the current window |
| `RateLimit-Remaining` | Requests left in the current window |
| `RateLimit-Reset` | Seconds until the window resets |

They follow the IETF draft for rate-limit headers (`draft-ietf-httpapi-ratelimit-headers`).

## Limits

| | Limit |
|---|---|
| Requests | Per API key. The hosted numbers aren't set yet. The mock allows 600 a minute |
| Direct upload | 100 MB; use the resumable flow for bigger files |
| URL input | 100 MB, fetched within 30 seconds |
| File retention | 24 hours by default, then deleted |
| Idempotency keys | Remembered for 24 hours |
| Webhook answer | 10 seconds |

Your account's limits for the month, such as `maxFileBytes`, are in `GET /v1/usage` under `limits`. A `null` limit means none. Going over a quota returns `402 quota_exceeded`.

## When you get a 429

Over the limit, you get `429 rate_limited` with a `Retry-After` header in seconds. Wait at least that long before the next request. A `503` may carry `Retry-After` too.

## What to retry

| Response | Retry? |
|---|---|
| `429` | Always, after `Retry-After` |
| `5xx`, or a dropped connection | Only for idempotent requests |
| Any other `4xx` | No. Fix the request first |

Idempotent requests are:

- `GET` and `DELETE`
- Uploads: the direct upload and the resumable chunks, which resume from `Upload-Offset`
- `POST /v1/conversions` **with** an `Idempotency-Key`. A replay returns the original conversion, so nothing starts or bills twice

`POST /v1/webhooks` isn't idempotent: retrying it after a `5xx` could register the endpoint twice.

## Backoff

When the server sends `Retry-After`, wait that long. Otherwise back off exponentially from 500 ms, doubling each time, with jitter. Stop after 3 retries.

```ts title="retry.ts"
async function withRetry(call: () => Promise<Response>): Promise<Response> {
  for (let attempt = 0; ; attempt++) {
    const res = await call();
    const retryable = res.status === 429 || res.status >= 500;
    if (!retryable || attempt === 3) return res;
    const after = Number(res.headers.get('Retry-After'));
    const wait = after > 0 ? after * 1000 : 500 * 2 ** attempt * (0.5 + Math.random());
    await new Promise((r) => setTimeout(r, wait));
  }
}
```

Use a helper like this only for idempotent requests, and always send an `Idempotency-Key` with `POST /v1/conversions`.

## The SDK does this for you

The [TypeScript SDK](/docs/sdk) retries `429` always, and `5xx` or a dropped connection only for idempotent calls. It always sends an `Idempotency-Key` on `conversions.create`, so that's covered. It respects `Retry-After`, and otherwise backs off from `retryBaseMs` (500 ms), doubling with jitter, capped at `maxRetryDelayMs` (60 seconds), for at most `maxRetries` (3) retries. After the last retry it throws `AnyfmtRateLimitError` with `retryAfterMs`, or `AnyfmtServerError`.

```ts title="client.ts"
const anyfmt = new Anyfmt({
  apiKey: process.env.ANYFMT_API_KEY!,
  baseUrl: 'https://api.anyfmt.app',
  maxRetries: 5,
  retryBaseMs: 250,
});
```

## Test rate limits with the mock

Send `X-Mock-Rate-Limit: N` to allow N requests per second for that credential. Past that, the mock answers `429 rate_limited` with `Retry-After`. You can also arm a fault with `POST /__mock/faults` and `"status": 429`.

```bash title="Terminal"
for i in 1 2 3; do
  curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Mock-Rate-Limit: 2' \
    -H "Authorization: Bearer $ANYFMT_API_KEY" http://127.0.0.1:8787/v1/usage
done
# 200, 200, then 429 within the same second
```
