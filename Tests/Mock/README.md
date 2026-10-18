# Halo Cloud mock server

An in-memory implementation of [`Server/openapi.yaml`](../../Server/openapi.yaml)
that the app's cloud tests run against. Node.js built-ins only (`http`,
`crypto`, `util`); there is no `package.json` and nothing to install.

```bash
node Tests/Mock/server.mjs --port 0          # prints "LISTENING <port>" on stdout
node Tests/Mock/server.mjs --port 8787       # fixed port for poking at it by hand
```

| Flag | Default | |
|---|---|---|
| `--port` | `0` | `0` picks a free port; the chosen port is printed as `LISTENING <port>` |
| `--host` | `127.0.0.1` | Bind address |
| `--quiet` | off | No stderr banner |
| `--watch-stdin` | off | Exit when stdin closes. The test host passes this so a crashed run never leaves a server behind |

To point a debug build of the app at it: Settings › Account › Server URL →
`http://127.0.0.1:8787` (plain http is allowed only for loopback hosts) →
Validate → Sign In…. Sign-in auto-approves (see `autoApprove`), so the
browser redirects straight back to `halo://auth/callback`.

## Behaviour

- **Sign-in:** `GET /v1/auth/authorize` validates the PKCE parameters, issues
  a code for `config.nextEmail` and 302-redirects to the callback (a simulated
  magic-link click). With `autoApprove: false` it returns an HTML form
  instead; `GET /__mock/auth/latest` then reveals the code (the "opened the
  link on another device" path). Codes are single-use; refresh tokens rotate
  and **reuse revokes the token family**.
- **Plans:** `free` (share links only, 5/month, 72 h max expiry, 50 downloads),
  `pro` (everything except custom domains), `team` (everything). Features and
  quotas come back from `GET /v1/me`.
- **Uploads:** bytes are committed as they arrive, so a dropped connection
  leaves the offset mid-chunk, exactly what the client's resume logic must
  handle. `maxChunkSize` defaults to 8 MiB.
- **Jobs** succeed after `config.jobPolls` polls (default 3) and return a
  generated result: conversions and image tools echo the input bytes,
  `cloud.transcribe` returns a canned SRT or VTT. `failJobs: true` makes them
  fail. `GET /v1/jobs/{id}/events` streams SSE.
- **Downloads** are signed URLs on `config.signedHost` (default `localhost`,
  deliberately a different origin from `127.0.0.1`) so tests can prove the
  client never sends its bearer token to another host.
- **Sync** enforces `If-Match` / `If-None-Match: *` and returns `409` with the
  current document.
- Every `/v1` response carries `X-Request-Id` and the `RateLimit-*` headers.
- **Public API** ([`docs/API.md`](../../docs/API.md)): API keys
  (`halo_sk_…`, scopes `read`/`convert`; managed with the app token, or minted
  directly with `POST /__mock/api-keys`), `POST /v1/files` (≤
  `directUploadMaxBytes`), `GET /v1/files/{id}/content` with `Range`, and
  conversions that are `queued` for the first quarter of `conversionMs`
  (default 200 ms), then `running`, then `succeeded` with the input bytes
  copied under the target's extension (`failConversions: true` or the request
  header `X-Mock-Outcome: fail` makes them fail). Options are validated
  against a copy of the app's option schemas; `Idempotency-Key` replays and
  conflicts like the contract says. Input URLs are really fetched.
- **Webhooks** are really delivered (POST to the registered URL, signed with
  `Halo-Signature`), retried after `webhookRetryMs` (default 50/100/200 ms)
  on any non-2xx or network error; every attempt is logged.
- **Rate limiting:** the request header `X-Mock-Rate-Limit: N` allows N
  requests per 1-second window for that credential and then answers
  `429 rate_limited` with `Retry-After`. Faults with `status: 429` work too.
- **Licences:** `HALO-MOCK-PRO0-0001` (pro, 2 devices) is seeded; add more
  with `POST /__mock/licences`.

## Test-control endpoints (`/__mock/…`, never logged)

| Method + path | Body / query | Does |
|---|---|---|
| `POST /__mock/reset` | `{config?}` | Fresh state, optional config overrides |
| `POST /__mock/config` | any config keys | Merge config (`jobPolls`, `pollAfterMs`, `failJobs`, `nextEmail`, `nextPlan`, `autoApprove`, `maxChunkSize`, `accessTokenTTL`, `signedHost`, `rateLimit`, `conversionMs`, `failConversions`, `webhookRetryMs`, `webhookTimeoutMs`, `directUploadMaxBytes`) |
| `POST /__mock/users` | `{email, plan, customDomains?, linksUsed?}` | Create/update a user |
| `POST /__mock/faults` | `{method, pathPrefix, skip, times, mode, status?, keepBytes?, retryAfter?}` | Arm a fault for the next matching request(s) after `skip` |
| `DELETE /__mock/faults` | | Disarm all faults |
| `GET` / `DELETE /__mock/requests` | | Request log: method, path, `hasAuth`, host, Content-Range, If-Match, If-None-Match, User-Agent, Idempotency-Key, Range, status |
| `POST /__mock/expire-tokens` | | Expire every access token (forces a 401 → refresh) |
| `GET /__mock/auth/latest` | | Last issued `{code, state, redirectUri}` |
| `POST /__mock/sync` | `{namespace, data, deviceName?, email?}` | Another Mac writes a sync document (bumps the version) |
| `GET /__mock/sync` | `?email=` | All sync documents with data |
| `POST /__mock/inbox` | `{name, content \| contentBase64, source?, note?, email?}` | Seed an inbox item as if sent from a phone |
| `GET /__mock/inbox` | `?email=` | Inbox items with status |
| `GET /__mock/jobs`, `/__mock/jobs/{id}` | | Jobs including `polls` and `cancelRequested` |
| `GET /__mock/uploads` | | Uploads including `putCount` |
| `GET /__mock/links` | | Links (password shown only as `set`) |
| `GET /__mock/state` | | Users and token counts |
| `POST /__mock/api-keys` | `{email?, scopes?, name?, expiresAt?, plan?}` | Mint an API key; returns `{apiKey, secret}` |
| `GET /__mock/api-keys` | | All keys with owner email (no secrets) |
| `GET /__mock/conversions` | | Conversions including owner and `fail` |
| `GET /__mock/webhooks/deliveries` | | Every delivery attempt: `webhookId, eventId, type, url, attempt, status, error` |
| `POST /__mock/webhooks/sign` | `{secret, body, t?}` | The `Halo-Signature` the mock would send |
| `POST /__mock/licences` | `{key?, plan?, status?, maxDevices?, expiresAt?}` | Seed a licence |
| `GET /__mock/licences` | | Licences with keys and devices |

Fault modes:

| `mode` | Effect |
|---|---|
| `truncate` | (PUT upload) commit the first `keepBytes` of the chunk, then drop the connection |
| `reset` | drop the connection immediately (nothing committed) |
| `status` | answer with `status` (default 503; 429 adds `Retry-After`) |

## Not a real server

No persistence, no email, no TLS, no real rate limiting (headers plus the
`X-Mock-Rate-Limit` test hook), no real conversions. It's
test scaffolding; the server design lives in [`Server/README.md`](../../Server/README.md).
