---
title: TypeScript SDK
description: Use @anyfmt/sdk to upload, convert, wait and download with the anyfmt HTTP API from Node 18 or later, with typed errors, safe retries and webhook verification.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

`@anyfmt/sdk` is the TypeScript client for the anyfmt HTTP API. It uploads files, creates conversions, waits for them and downloads the results, with typed errors, safe automatic retries and webhook verification. It has no runtime dependencies and runs on Node 18.17 or later.

## Install

The SDK isn't on npm yet. Build it from the anyfmt repository:

```bash title="Terminal"
cd sdk/typescript && npm ci && npm run build   # → dist/
```

## Quick start

```ts title="convert.ts"
import { Anyfmt } from '@anyfmt/sdk';

const anyfmt = new Anyfmt({ apiKey: process.env.ANYFMT_API_KEY!, baseUrl: 'https://api.anyfmt.app' });

const file = await anyfmt.files.upload('photo.heic');               // a path, a Blob or a File
const conversion = await anyfmt.conversions.create({
  input: { fileId: file.id },
  target: 'webp',
  options: { quality: 80, maxDimension: 2048 },                    // anyfmt option keys
  metadata: { order: 'A-1009' },
});
const done = await anyfmt.conversions.wait(conversion.id, { timeoutMs: 60_000 });
await anyfmt.files.download(done.output!.id, 'photo.webp');
```

`baseUrl` is the server's origin. The SDK adds `/v1` to every path itself. Until the hosted API has its domain, always pass `baseUrl`. Against the mock, use `http://127.0.0.1:8787`, and get a key with `curl -s -X POST http://127.0.0.1:8787/__mock/api-keys -d '{}' | jq -r .secret`.

## The client

```ts
new Anyfmt({ apiKey, baseUrl, maxRetries?, retryBaseMs?, maxRetryDelayMs?, headers?, fetch? })
```

| Option | Meaning | Default |
|---|---|---|
| `apiKey` | An `anyfmt_sk_…` key. It's never logged or serialised | Required |
| `baseUrl` | The server origin, such as `https://api.anyfmt.app` or `http://127.0.0.1:8787` | Pass it |
| `maxRetries` | Retries after a `429`, a `5xx` or a connection error | 3 |
| `retryBaseMs` | The first backoff step when the server sends no `Retry-After`. Doubles each retry | 500 ms |
| `maxRetryDelayMs` | The longest single wait, `Retry-After` included | 60 000 ms |
| `headers` | Extra headers on every request | |
| `fetch` | Another `fetch`, for tests or proxies | The global one |

## Methods

| Method | Does |
|---|---|
| `files.upload(pathOrBlob, { filename?, contentType?, resumable?, chunkSize? })` | Up to 100 MB goes in one `POST /v1/files`. Bigger files, or `resumable: true`, use the chunked upload flow, which resumes from the server's `Upload-Offset` after a drop. Returns the file object |
| `files.download(id, destPath, { resume? })` | Streams to `destPath.part`, then renames it. An existing `.part` is resumed with `Range` |
| `files.read(id, { start, end? }?)` | Returns the bytes in memory, optionally a byte range |
| `conversions.create(params, { idempotencyKey? })` | Always sends an `Idempotency-Key`: a random UUID unless you pass one. Retries never start a second conversion |
| `conversions.get(id)` | The conversion |
| `conversions.cancel(id)` | Safe to repeat. Cancelling a finished conversion throws `AnyfmtConflictError` (`already_finished`) |
| `conversions.list({ limit?, cursor?, status? })` | One page |
| `conversions.iterate({ … })` | An async iterator over every page |
| `conversions.wait(idOrConversion, { timeoutMs?, minPollMs?, signal? })` | Polls every `pollAfterMs`. Resolves on `succeeded`. Throws `AnyfmtConversionFailedError` (with `.conversion`) on `failed` or `cancelled`, and `AnyfmtTimeoutError` when time runs out |
| `formats.list({ input? })` | Targets per input, with `hops`, `via` and `optionsSchema` |
| `schema.get()` | The registry document |
| `webhooks.create({ url, events })` | Returns the signing `secret` once. Not retried after a `5xx`, because it isn't idempotent |
| `webhooks.list()`, `webhooks.delete(id)` | List or remove endpoints |
| `webhooks.verify(rawBody, header, secret, { toleranceSec? })` | Verifies a delivery. Also available as `verifyWebhook(…)` |
| `usage.get({ period? })` | One month's usage, `YYYY-MM`. Defaults to the current month |

## Iterate over every conversion

```ts title="list.ts"
for await (const c of anyfmt.conversions.iterate({ status: 'failed' })) {
  console.log(c.id, c.error?.code);
}
```

## Make retries safe across restarts

Pass your own idempotency key, such as an order id, so a retry after a crash finds the same conversion instead of starting a new one:

```ts title="order.ts"
const conversion = await anyfmt.conversions.create(
  { input: { fileId }, target: 'pdf' },
  { idempotencyKey: `order-${order.id}` },
);
```

## Errors

Every error extends `AnyfmtError`, with `status`, `code` (the server's `error.code`), `requestId` and `details`.

```ts title="errors.ts"
import { AnyfmtValidationError, AnyfmtRateLimitError } from '@anyfmt/sdk';

try {
  await anyfmt.conversions.create({ input: { fileId }, target: 'webp', options: { quality: 101 } });
} catch (e) {
  if (e instanceof AnyfmtValidationError) console.error(e.code, e.details?.fields); // validation_failed ['options.quality']
  else if (e instanceof AnyfmtRateLimitError) console.error('slow down; server asked for', e.retryAfterMs, 'ms');
  else throw e;
}
```

| Class | When |
|---|---|
| `AnyfmtAuthenticationError` | 401 (`invalid_api_key`) |
| `AnyfmtPermissionError` | 403 (`insufficient_scope`) |
| `AnyfmtNotFoundError` | 404 |
| `AnyfmtConflictError` | 409 (`idempotency_conflict`, `already_finished`) |
| `AnyfmtValidationError` | 413, 416, 422 |
| `AnyfmtRateLimitError` | 429 after retries, with `retryAfterMs` |
| `AnyfmtServerError` | 5xx after retries |
| `AnyfmtConnectionError` | No response at all |
| `AnyfmtTimeoutError`, `AnyfmtConversionFailedError` | From `conversions.wait` |
| `AnyfmtWebhookSignatureError` | From `webhooks.verify`, with a `reason` of `malformed`, `expired` or `mismatch` |

## Retries

A `429` is always retried. A `5xx` or a dropped connection is retried only for idempotent calls: `GET`, `DELETE`, uploads, and `conversions.create`, because it always sends an `Idempotency-Key`. The SDK waits for `Retry-After` when the server sends it, and otherwise backs off from `retryBaseMs`, doubling each time with jitter, capped at `maxRetryDelayMs`. See [Rate limits and retries](/docs/api-limits).

## Webhook handlers

With Express, take the raw body:

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

With Node's built-in HTTP server:

```ts title="hook-node.ts"
import { createServer } from 'node:http';
import { verifyWebhook } from '@anyfmt/sdk';

createServer(async (req, res) => {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  const event = verifyWebhook(Buffer.concat(chunks), req.headers['anyfmt-signature'] as string, secret);
  res.writeHead(204).end();
}).listen(3000);
```

Dedupe on `event.id`: a retried delivery keeps its id. See [Webhooks](/docs/api-webhooks).

## Types and tests

The types are generated from the OpenAPI contract, with a thin hand-written client on top, and the SDK follows semver. Its tests run against the mock server: uploads, resumable uploads with a dropped chunk, conversions, idempotency, option validation, ranges and resumed downloads, webhook signing and delivery, retries, and the error envelope. Its licence is AGPL-3.0-only, like the rest of anyfmt.
