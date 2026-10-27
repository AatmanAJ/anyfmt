---
title: Errors
description: How the anyfmt HTTP API reports errors. One JSON envelope, a stable code to branch on, every status and code, and the matching TypeScript SDK error classes.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

Every 4xx and 5xx response from the anyfmt API has the same JSON envelope, with a stable `code` to branch on and a `message` you can show to a person. This page lists every status and code, and how a failed conversion differs from an HTTP error.

## The envelope

```json
{ "error": { "code": "validation_failed", "message": "Some options aren’t valid for this conversion.",
             "requestId": "req_…", "details": { "fields": ["options.quality"],
             "problems": [{ "field": "options.quality", "reason": "out_of_range", "min": 1, "max": 100 }] } } }
```

| Field | Meaning |
|---|---|
| `code` | A stable, machine-readable code. Branch on this |
| `message` | A sentence written for people. Never branch on it |
| `requestId` | The same id as the `X-Request-Id` header. Include it when you report a problem |
| `details` | Extra facts for some codes, listed below |

If you get a code you don't know, fall back on the HTTP status. New codes can be added within v1.

## Status codes and error codes

| Status | Codes |
|---|---|
| 400 | `validation_failed` (the body isn't JSON) |
| 401 | `invalid_api_key`, `unauthorized`, `token_expired` |
| 402 | `quota_exceeded` |
| 403 | `insufficient_scope`, `forbidden`, `feature_not_in_plan` |
| 404 | `not_found`, `licence_invalid` |
| 409 | `idempotency_conflict`, `already_finished`, `licence_device_limit`, `licence_revoked`, and the app's `offset_mismatch`, `upload_incomplete`, `version_conflict` |
| 413 | `payload_too_large` |
| 416 | `range_not_satisfiable` |
| 422 | `validation_failed`, `unsupported_route`, `input_unavailable`, `checksum_mismatch`, `unsupported_operation` |
| 428 | `precondition_required` |
| 429 | `rate_limited` |
| 500, 503 | `internal`, `server_busy`, `maintenance` |

## Codes you'll see most

| Code | What it means | What to do |
|---|---|---|
| `invalid_api_key` | The key is unknown, revoked or expired, or you sent an app token to the public API | Check the key; create a new one if needed |
| `insufficient_scope` | The key lacks a scope. `details.scope` names it | Use a key with `read` or `convert` as needed |
| `validation_failed` | Bad options or fields. `details.fields` and `details.problems` say which, with `reason`, `min` and `max` | Fix the request; don't retry it unchanged |
| `unsupported_route` | No route from the input to the target. `details.targets` lists what's possible | Pick a target from `details.targets` |
| `payload_too_large` | The body is over the limit. `details.maxBytes` gives it | Use the resumable upload flow |
| `range_not_satisfiable` | The `Range` is outside the file | Request a range inside the file's `size` |
| `idempotency_conflict` | You reused an `Idempotency-Key` with a different body | Use a new key for a new request |
| `already_finished` | You cancelled a conversion that had already finished | Nothing to do |
| `offset_mismatch` | A resumable chunk didn't start at the committed offset | Continue from `Upload-Offset` |
| `checksum_mismatch` | The SHA-256 at upload completion didn't match | Upload again |
| `rate_limited` | Too many requests | Wait for `Retry-After`; see [Rate limits and retries](/docs/api-limits) |
| `server_busy`, `maintenance` | The server can't take the request now | Retry later, respecting `Retry-After` if present |

## A failed conversion isn't an HTTP error

When a conversion fails, `GET /v1/conversions/{id}` still returns `200`. The conversion has `status: "failed"` and an `error` object:

```json
{ "id": "cnv_…", "status": "failed", "error": { "code": "conversion_failed", "message": "…" }, … }
```

Conversion error codes include `conversion_failed` and `input_unavailable`. Failed conversions aren't billed.

## SDK error classes

The [TypeScript SDK](/docs/sdk) throws one class per kind of failure. All of them extend `AnyfmtError`, which carries `status`, `code`, `requestId` and `details`.

| Class | When |
|---|---|
| `AnyfmtAuthenticationError` | 401 |
| `AnyfmtPermissionError` | 403 |
| `AnyfmtNotFoundError` | 404 |
| `AnyfmtConflictError` | 409 |
| `AnyfmtValidationError` | 413, 416 and 422 |
| `AnyfmtRateLimitError` | 429, after retries |
| `AnyfmtServerError` | 5xx, after retries |
| `AnyfmtConnectionError` | No response at all |
| `AnyfmtTimeoutError` | `conversions.wait` ran out of time |
| `AnyfmtConversionFailedError` | `conversions.wait` saw `failed` or `cancelled` |
| `AnyfmtWebhookSignatureError` | `verifyWebhook` rejected a delivery |

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

## Test errors with the mock

The mock answers with the same codes. To force failures:

- Send `X-Mock-Outcome: fail` when creating a conversion, and it fails.
- `POST /__mock/faults` arms a fault for matching requests: `status` answers with a status code (503 by default; 429 adds `Retry-After`), `reset` drops the connection, and `truncate` commits part of an upload chunk, then drops it.
