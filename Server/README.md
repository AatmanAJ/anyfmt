# Halo Cloud server

**Not built in this repo yet.** This folder holds the contract the Mac app
already speaks ([`openapi.yaml`](openapi.yaml)) and the plan for the server
that will implement it. A complete in-memory implementation used by the
app's tests lives in [`Tests/Mock/server.mjs`](../Tests/Mock/server.mjs);
read it alongside the contract when building the real thing.

## What the server is for

Everything that runs on a Mac is free and never talks to this server. The
server exists only for features that cost servers (BUILD.md §9b):

| Feature | Endpoints | Notes |
|---|---|---|
| Sign-in | `/v1/auth/*`, `/v1/me`, `/v1/devices` | Browser magic link + OAuth 2.0 code flow with PKCE back to `halo://auth/callback` |
| Share links | `/v1/uploads/*`, `/v1/links/*`, `/s/{slug}` page | Resumable uploads, expiry, password, download cap, custom domains (Team) |
| Cloud jobs | `/v1/jobs/*`, `/v1/files/*` | Heavy video conversions, transcription → SRT/VTT, upscale, HQ background removal |
| Sync | `/v1/sync/documents/*` | Opaque JSON documents with versions and conditional PUT |
| Inbox | `/v1/inbox/*` | Files sent from a phone or browser land in a folder on the Mac |
| Public conversion API | `/v1/api-keys`, `/v1/files`, `/v1/conversions/*`, `/v1/formats`, `/v1/schema`, `/v1/webhooks/*`, `/v1/usage` | Pay-per-use, API-key auth. Narrative docs and curl examples: [`docs/API.md`](../docs/API.md); TypeScript SDK: [`sdk/typescript`](../sdk/typescript) |
| Licences | `/v1/licences/*` | Optional Pro licence activation for the Mac app (seat count per key) |

The app also links to two **web pages** (not API): the sign-in page
`/v1/auth/authorize` and the plan page `/account/plan`.

## Contract essentials

- `/v1` prefix; additive changes only within v1. JSON is camelCase.
  `/v1/auth/token` and `/v1/auth/revoke` follow RFC 6749/7636/7009 to the
  letter (form-encoded, snake_case) so an off-the-shelf OAuth library works.
- Errors: `{"error": {"code", "message", "requestId", "details"}}`. `message`
  is shown to people verbatim, so write it like a human.
- Every response: `X-Request-Id`. Authenticated responses: `RateLimit-Limit`,
  `RateLimit-Remaining`, `RateLimit-Reset`; `429`/`503` add `Retry-After`.
- Uploads: `POST /v1/uploads` (size + SHA-256) → `PUT` chunks with
  `Content-Range` → on any interruption the client asks `HEAD` for
  `Upload-Offset` and continues from there → `POST …/complete` with the
  SHA-256, which the server verifies. Committing partial chunks is optional:
  a server backed by S3 multipart can commit only whole parts (8 MiB chunks
  are ≥ the 5 MiB part minimum) and report that offset. The client accepts
  any committed offset.
- Sync: `If-Match: "<version>"` or `If-None-Match: *` is mandatory on PUT
  (`428` otherwise). A failed precondition is `409 version_conflict` **with
  the current document in the body**, so the client resolves without another
  round trip.
- Jobs: the client polls `GET /v1/jobs/{id}` no faster than `pollAfterMs`.
  `GET /v1/jobs/{id}/events` (SSE) is optional; the shipped client polls.
- Result and inbox downloads may be pre-signed object-storage URLs on another
  host. The client sends its bearer token **only** to the server's own origin.
- Two credentials, never interchangeable: the app's OAuth token
  (`bearerAuth`) and public API keys (`apiKeyAuth`, `Bearer halo_sk_…`,
  scopes `read`/`convert`). Keys are managed only with the app token; the
  public API rejects app tokens (`401 invalid_api_key`). Exceptions:
  `/v1/usage` takes either, and the resumable `/v1/uploads` flow takes
  either (completed uploads carry a `fileId` for conversions).
- Public API conversions take `Idempotency-Key` (24 h, per account; same
  body → `200` + `Idempotent-Replayed: true`, different body →
  `409 idempotency_conflict`). Webhooks are signed
  `Halo-Signature: t=<unix>,v1=<hex HMAC-SHA256(secret, t.body)>` with a
  5-minute tolerance and retried with backoff for about two days.

## Stack options

| | A. TypeScript (Hono) | B. Swift (Vapor) | C. Go |
|---|---|---|---|
| API | Hono on Node 22/Bun, Zod validation, generated types from `openapi.yaml` | Vapor 4, `swift-openapi-generator` server stubs from `openapi.yaml` | chi/echo, `oapi-codegen` |
| DB | Postgres + Drizzle/Kysely | Postgres + Fluent | Postgres + sqlc |
| Queue | `pg-boss` (jobs in Postgres: one less service) | Vapor Queues (Redis) or Postgres polling | River (Postgres) |
| Pros | Biggest ecosystem; same language as the web dashboard and the phone/browser upload page (likely a PWA); easy hiring; Cap's web side is TS | Same language as the app; can share wire types with `Sources/Cloud`; strong typing end to end | One static binary is the nicest self-host story; low memory |
| Cons | Two languages in the org (Swift app + TS server) | Smaller server ecosystem; Linux Swift builds are slower; Redis for queues | Another language; less shared code |

Whatever the API language, the **workers** are best as separate containers:

- `worker-media` (CPU): pinned ffmpeg (same build flags as `Engines/`, GPL) for
  video conversion/compression. Mirror the app's options schema
  (`StandardSchemas.video`) so results match local conversions.
- `worker-gpu` (optional, Python): faster-whisper / whisper.cpp for
  transcription, Real-ESRGAN for upscaling, BiRefNet/rembg-class models for
  HQ background removal. Self-hosters without a GPU leave it out and
  `/v1/health.capabilities` stops advertising those features.

**Recommendation:** A, with `pg-boss` so a self-host is Postgres + S3 + two
containers. Generate request/response types from `openapi.yaml` and run the
app's cloud test suite's scenarios as contract tests (see "What to build next").

## Storage

S3-compatible object storage (AWS S3, Cloudflare R2, Backblaze B2, MinIO for
self-hosting). Buckets/prefixes: `uploads/` (incomplete multipart parts,
lifecycle-expire after 24 h), `files/` (job results, inbox items, share-link
files). Downloads are short-lived pre-signed GETs (≤ 15 min) or streamed
through `/v1/files/{id}`. Serve shared files from a **separate download
domain** with `Content-Disposition: attachment` and
`X-Content-Type-Options: nosniff`, so user-uploaded HTML can never run on the
API or sign-in origin.

## Self-hosting

Self-hosting is in the free column of the business model: a self-hosted
server unlocks every feature for its own users.

```yaml
# docker-compose.yml (sketch)
services:
  api:
    image: ghcr.io/aiwithaj/halo-server:latest
    env_file: .env
    ports: ["8080:8080"]
    depends_on: [db, storage]
  worker-media:
    image: ghcr.io/aiwithaj/halo-worker-media:latest
    env_file: .env
  worker-gpu:            # optional
    image: ghcr.io/aiwithaj/halo-worker-gpu:latest
    env_file: .env
    deploy: { resources: { reservations: { devices: [{ capabilities: [gpu] }] } } }
  db:
    image: postgres:17
    volumes: [db:/var/lib/postgresql/data]
    environment: { POSTGRES_PASSWORD: change-me }
  storage:
    image: minio/minio
    command: server /data
    volumes: [storage:/data]
volumes: { db: {}, storage: {} }
```

Environment:

| Variable | Example | Purpose |
|---|---|---|
| `PUBLIC_URL` | `https://halo.example.com` | What users type into the app's Server URL field (must be https) |
| `SHARE_URL` | `https://dl.example.com` | Separate origin for share-link pages and downloads |
| `DATABASE_URL` | `postgres://…` | Postgres |
| `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | | Object storage |
| `SMTP_URL`, `MAIL_FROM` | `smtps://user:pass@smtp.example.com` | Magic-link email |
| `SIGNUPS` | `open` \| `invite` \| `domain:example.com` | Who may sign in |
| `DEFAULT_PLAN` | `team` | Self-hosts default to everything on |
| `MAX_UPLOAD_BYTES` | `10737418240` | Per-file cap reported as `quotas.maxUploadBytes` |
| `RETENTION_HOURS` | `168` | Default share-link/inbox retention |
| `WORKER_CONCURRENCY` | `2` | Media jobs per worker |
| `WHISPER_MODEL` | `large-v3` | GPU worker only |
| `TOKEN_PEPPER` | random 32 bytes | Hashing access/refresh tokens at rest |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | | Hosted service only |

Pointing the app at it: **Settings › Account › Server URL** →
`https://halo.example.com` → **Validate** (calls `GET /v1/health`, the only
request the app makes before sign-in, and only when the button is pressed) →
**Use This Server** → **Sign In…**. Each server keeps its own sign-in
(Keychain item per host). `http://` is accepted only for `localhost`/`127.0.0.1`
development servers.

## Security notes

- **TLS everywhere.** The app refuses plain-http servers that aren't on the Mac itself.
- **Auth:** PKCE `S256` only; exact `redirect_uri` match per `client_id`
  (`halo-mac` → `halo://auth/callback`; both follow the brand, see BUILD.md);
  `state` echoed untouched; authorization codes single-use, 10-minute TTL,
  bound to the challenge. Magic-link tokens single-use, 15-minute TTL, and the
  link page shows the code for the "opened on another device" case.
- **Tokens:** opaque 256-bit random strings, stored hashed (SHA-256 + pepper).
  Access 1 h; refresh 60 days, rotated on every use, **reuse revokes the whole
  family** (the mock implements this). `/v1/auth/revoke` on sign-out.
- **Never log** tokens, codes, share-link passwords, signed-URL query strings
  or file names in plain text alongside IPs. Keep request logs to method,
  route, status, latency, request id.
- **Share links:** passwords hashed with argon2id; rate-limit password
  attempts per link; `maxDownloads` enforced atomically; revocation deletes
  the objects. Stats are counts only: no viewer IPs or fingerprints.
- **Abuse:** public links make the hosted service a file host; plan for a
  report link on the landing page, hash-matching for known-bad content, and
  takedown tooling before launch.
- **Data retention:** job inputs and results deleted when results expire;
  inbox items deleted after `ack`; incomplete uploads after 24 h.
- **No analytics or third-party scripts** on any server-rendered page
  (sign-in, share landing, inbox upload page).
- **Rate limits** per token and per IP for auth endpoints; return the
  `RateLimit-*` headers the contract lists.

## What AJ needs to build next

1. Pick the hosted domain and replace **one constant**:
   `CloudConfig.defaultServer` in `Sources/Cloud/CloudConfig.swift`
   (currently `https://cloud.example.invalid`, which can never resolve).
2. Auth: sign-in page, magic-link email, code issuance + `/v1/auth/token`,
   refresh rotation, revoke, `/v1/me` with plan → features/quotas.
3. Uploads (S3 multipart behind the chunk API) + share links + the landing
   page on the separate download domain.
4. `worker-media` (ffmpeg) for cloud conversions; then `worker-gpu` for
   transcription, upscale and HQ background removal.
5. Sync documents and the inbox, plus the phone/browser upload page (PWA)
   that calls `POST /v1/uploads` + `POST /v1/inbox`.
6. Billing (Stripe) and `/account/plan`; Free = 5 links/month, 72 h expiry,
   share links only (what the mock serves). Self-hosts: `DEFAULT_PLAN=team`.
7. Contract tests: port the scenarios in `Tests/Unit/App/Cloud/*Tests.swift`
   (they drive `Tests/Mock/server.mjs`) into server-side tests, and diff
   responses against `openapi.yaml` with a schema validator in CI.
8. Docker images + `docker-compose.yml` + a self-host guide.
9. The public conversion API ([`docs/API.md`](../docs/API.md)): API keys
   stored hashed (show the secret once), idempotency records, a durable
   webhook delivery queue with the documented retry schedule, SSRF-safe
   fetching for `input.url` and webhook URLs (refuse private/loopback/
   link-local addresses after DNS resolution), usage metering for billing,
   and licence issuance. Run `sdk/typescript`'s tests against the real server
   (they only need `baseUrl` and a way to mint a key) as its contract test.
