# @halo/sdk

A TypeScript client for the Halo pay-per-use conversion API
([docs/API.md](../../docs/API.md), contract in
[Server/openapi.yaml](../../Server/openapi.yaml)).

- No runtime dependencies. It uses Node 18+ `fetch` and `node:crypto` / `node:fs`.
- The types are generated from the OpenAPI file, and a thin hand-written client sits on top.
- It retries `429` and `5xx` responses up to 3 times and respects `Retry-After`.

> **No Halo server exists yet.** The SDK is tested against the in-memory mock
> in `Tests/Mock/server.mjs`. Until a hosted domain is chosen, always pass
> `baseUrl`.

## Install

Not on npm yet. From this repo:

```bash
cd packages/sdk && npm ci && npm run build   # → dist/
```

## Quick start

```ts
import { Halo } from '@halo/sdk';

const halo = new Halo({ apiKey: process.env.HALO_API_KEY!, baseUrl: 'https://halo.example.com' });

const file = await halo.files.upload('photo.heic');               // a path, a Blob or a File
const conversion = await halo.conversions.create({
  input: { fileId: file.id },
  target: 'webp',
  options: { quality: 80, maxDimension: 2048 },                    // Halo option keys
  metadata: { order: 'A-1009' },
});
const done = await halo.conversions.wait(conversion.id, { timeoutMs: 60_000 });
await halo.files.download(done.output!.id, 'photo.webp');
```

## API

| | |
|---|---|
| `new Halo({ apiKey, baseUrl, maxRetries?, retryBaseMs?, maxRetryDelayMs?, headers?, fetch? })` | `apiKey` must be a `halo_sk_…` key. The key is never logged or serialised |
| `files.upload(pathOrBlob, { filename?, contentType?, resumable?, chunkSize? })` | Up to 100 MB goes in one `POST /v1/files`. Bigger files, or `resumable: true`, use the chunked `/v1/uploads` flow, which resumes from the server's `Upload-Offset` after a drop. Returns a `StoredFile` |
| `files.download(id, destPath, { resume? })` | Streams to `dest.part`, then renames it. An existing `.part` is resumed with `Range` |
| `files.read(id, { start, end? }?)` | Bytes in memory, optionally a byte range |
| `conversions.create(params, { idempotencyKey? })` | Always sends an `Idempotency-Key` (a random UUID unless you give one), so retries never start a second conversion |
| `conversions.get(id)` / `conversions.cancel(id)` | `cancel` is idempotent. Cancelling a finished conversion throws `HaloConflictError` (`already_finished`) |
| `conversions.list({ limit?, cursor?, status? })` / `conversions.iterate({ … })` | One page, or an async iterator over every page |
| `conversions.wait(idOrConversion, { timeoutMs?, minPollMs?, signal? })` | Polls every `pollAfterMs`. Resolves on `succeeded`. Throws `HaloConversionFailedError` (`.conversion`) on `failed`/`cancelled`, and `HaloTimeoutError` when time runs out |
| `formats.list({ input? })` | Targets per input, with `hops`, `via` and `optionsSchema` |
| `schema.get()` | The registry document (`halo schema --json` shape) |
| `webhooks.create({ url, events })` / `.list()` / `.delete(id)` | `create` returns the signing `secret` once. It isn't retried after a 5xx, because it isn't idempotent |
| `webhooks.verify(rawBody, header, secret, { toleranceSec? })` | Also `Webhooks.verify(…)` and `verifyWebhook(…)`. Returns the parsed event or throws `HaloWebhookSignatureError` (`reason`: `malformed`, `expired` or `mismatch`) |
| `usage.get({ period? })` | `YYYY-MM`; defaults to the current month |

### Errors

Every error extends `HaloError` with `status`, `code` (the server's `error.code`), `requestId` and `details`:

```ts
import { HaloValidationError, HaloRateLimitError, HaloConversionFailedError } from '@halo/sdk';

try {
  await halo.conversions.create({ input: { fileId }, target: 'webp', options: { quality: 101 } });
} catch (e) {
  if (e instanceof HaloValidationError) console.error(e.code, e.details?.fields); // validation_failed ['options.quality']
  else if (e instanceof HaloRateLimitError) console.error('slow down; server asked for', e.retryAfterMs, 'ms');
  else throw e;
}
```

| Class | When |
|---|---|
| `HaloAuthenticationError` | 401 (`invalid_api_key`) |
| `HaloPermissionError` | 403 (`insufficient_scope`) |
| `HaloNotFoundError` | 404 |
| `HaloConflictError` | 409 (`idempotency_conflict`, `already_finished`) |
| `HaloValidationError` | 413, 416, 422 |
| `HaloRateLimitError` | 429 after retries (`retryAfterMs`) |
| `HaloServerError` | 5xx after retries |
| `HaloConnectionError` | No response at all |
| `HaloTimeoutError`, `HaloConversionFailedError` | From `conversions.wait` |
| `HaloWebhookSignatureError` | From `webhooks.verify` |

### Retries

A `429` is always retried. A `5xx` or a dropped connection is retried only
for idempotent calls: `GET`, `DELETE`, uploads, and `conversions.create`
(because it always sends an Idempotency-Key). The SDK waits for
`Retry-After` when the server sends it. Otherwise it backs off from
`retryBaseMs` (500 ms), doubling each time with jitter, capped at
`maxRetryDelayMs`. It retries at most `maxRetries` times (3).

### Webhook handler (Express)

```ts
import express from 'express';
import { verifyWebhook, HaloWebhookSignatureError } from '@halo/sdk';

const app = express();
app.post('/halo-hook', express.raw({ type: 'application/json' }), (req, res) => {
  try {
    const event = verifyWebhook(req.body, req.get('Halo-Signature'), process.env.HALO_WEBHOOK_SECRET!);
    res.sendStatus(204);                         // acknowledge fast, then work
    if (event.type === 'conversion.succeeded') queue.push(event.data.conversion.id);
  } catch (e) {
    res.sendStatus(e instanceof HaloWebhookSignatureError ? 400 : 500);
  }
});
```

Dedupe on `event.id`: a retried delivery keeps its id.

### Node's built-in HTTP server

```ts
import { createServer } from 'node:http';
createServer(async (req, res) => {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  const event = verifyWebhook(Buffer.concat(chunks), req.headers['halo-signature'] as string, secret);
  res.writeHead(204).end();
}).listen(3000);
```

## Development

```bash
npm ci
npm run generate        # regenerate src/generated/openapi.ts after editing Server/openapi.yaml
npm test                # build, check the generated types are current, lint the OpenAPI file,
                        # type-check test/types.ts, then node:test against a spawned mock server
```

From the repo root, `make sdk-test` runs `npm ci && npm test`, and it's part of `make test`.

| Test file | Covers |
|---|---|
| `test/conversions.test.mjs` | Upload (path, Blob, File), create/get/list/iterate/cancel/wait, URL inputs, idempotency, option validation, Range reads and resumed downloads, formats, schema, usage, scopes |
| `test/uploads.test.mjs` | Resumable uploads: chunking, a mid-chunk drop resumed from `Upload-Offset`, a 503 on a chunk, the 100 MB direct limit |
| `test/webhooks.test.mjs` | Signature verify (valid, rotation, expired, tampered, malformed), endpoint CRUD, end-to-end signed delivery with a retry, routing, dropped retries |
| `test/retry.test.mjs` | 429 with `Retry-After`, the 3-retry limit, 5xx on idempotent vs non-idempotent calls, connection resets, `RateLimit-*` headers |
| `test/contract.test.mjs` | Raw-HTTP checks of API-key management (app sign-in only), licence activation, credential separation, the error envelope, and every mock error code being in the contract enum |
| `test/types.ts` | Compile-only: the public surface is typed, and misuse fails to compile |

License: AGPL-3.0-only, like the rest of Halo.
