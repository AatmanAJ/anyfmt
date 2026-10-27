---
title: Self-host the server
description: The planned anyfmt server for share links, cloud jobs, sync and the inbox, with its docker-compose services, environment variables and the Server URL setting.
---

You can run your own anyfmt server, so share links, cloud jobs, sync and the inbox work for your own users with every feature on, at no cost. This page describes the planned server: its services, its settings, and how to point the Mac app at it.

> [!PREVIEW]
> The server isn't built yet. The Mac client, the API contract (`Server/openapi.yaml`) and a mock server that implements all of it are done and tested. Everything below about the server itself is the plan, and image names, variables and defaults may change before it ships.

## What the server is for

Everything that runs on a Mac is free and never talks to a server. The server exists only for features that need one:

| Feature | Endpoints |
|---|---|
| Sign-in | `/v1/auth/*`, `/v1/me`, `/v1/devices`. A browser magic link, then an OAuth 2.0 code flow with PKCE back to `anyfmt://auth/callback` |
| Share links | `/v1/uploads/*`, `/v1/links/*`, and the `/s/{slug}` page. Resumable uploads, expiry, password, download cap, custom domains |
| Cloud jobs | `/v1/jobs/*`, `/v1/files/*`. Heavy video, transcription to SRT or VTT, upscaling, HQ background removal |
| Sync | `/v1/sync/documents/*`. Versioned JSON documents with conditional writes |
| Inbox | `/v1/inbox/*`. Files sent from a phone or browser land in a folder on the Mac |
| Public conversion API | `/v1/api-keys`, `/v1/files`, `/v1/conversions/*`, `/v1/formats`, `/v1/schema`, `/v1/webhooks/*`, `/v1/usage`. See [HTTP API overview](/docs/api) |
| Licences | `/v1/licences/*` |

## Planned services

The recommended stack is a TypeScript API (Hono) with Postgres, a Postgres-backed job queue, and S3-compatible storage, so a self-hosted install is Postgres, object storage and two containers. Media work runs in separate worker containers.

```yaml title="docker-compose.yml (planned)"
services:
  api:
    image: ghcr.io/aatmanaj/anyfmt-server:latest
    env_file: .env
    ports: ["8080:8080"]
    depends_on: [db, storage]
  worker-media:
    image: ghcr.io/aatmanaj/anyfmt-worker-media:latest
    env_file: .env
  worker-gpu:            # optional
    image: ghcr.io/aatmanaj/anyfmt-worker-gpu:latest
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

| Service | Role |
|---|---|
| `api` | The HTTP API the app and the public API call |
| `worker-media` | CPU video conversion and compression, with a pinned ffmpeg and the app's own video options, so results match local conversions |
| `worker-gpu` | Optional. Transcription, upscaling and HQ background removal. Without a GPU, leave it out, and the server stops advertising those features |
| `db` | Postgres |
| `storage` | S3-compatible object storage. MinIO here; AWS S3, Cloudflare R2 or Backblaze B2 work too |

## Planned environment variables

| Variable | Example | Purpose |
|---|---|---|
| `PUBLIC_URL` | `https://anyfmt.example.com` | What users type into the app's Server URL field. Must be `https` |
| `SHARE_URL` | `https://dl.example.com` | A separate origin for share-link pages and downloads |
| `DATABASE_URL` | `postgres://…` | Postgres |
| `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | | Object storage |
| `SMTP_URL`, `MAIL_FROM` | `smtps://user:pass@smtp.example.com` | Sending magic-link emails |
| `SIGNUPS` | `open`, `invite` or `domain:example.com` | Who may sign in |
| `DEFAULT_PLAN` | `team` | Self-hosted servers default to everything on |
| `MAX_UPLOAD_BYTES` | `10737418240` | The per-file cap, reported to the app as `quotas.maxUploadBytes` |
| `RETENTION_HOURS` | `168` | Default retention for share links and inbox items |
| `WORKER_CONCURRENCY` | `2` | Media jobs per worker |
| `WHISPER_MODEL` | `large-v3` | GPU worker only |
| `TOKEN_PEPPER` | 32 random bytes | For hashing access and refresh tokens at rest |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | | Hosted service only; not needed to self-host |

## Point the app at your server

1. Open **Settings › Account**.
2. Under **Server**, type your server's address into **Server URL**, for example `https://anyfmt.example.com`.
3. Choose **Validate**. The app calls `GET /v1/health`, the only request it makes before you sign in, and only when you press the button.
4. Choose **Use This Server**.
5. Choose **Sign In…**.

Each server keeps its own sign-in, stored in your Keychain per host. **Reset to Default** switches back. The app accepts plain `http://` only for addresses on the Mac itself, such as `localhost` and `127.0.0.1`, for development servers.

## Try the flow today with the mock

The mock server implements the whole contract in memory, with Node.js built-ins only. It auto-approves sign-in, so you can walk through every Pro flow in the app:

```bash title="Terminal"
node Tests/Mock/server.mjs --port 8787
```

Then set **Settings › Account › Server URL** to `http://127.0.0.1:8787`, choose **Validate**, **Use This Server** and **Sign In…**. The browser redirects straight back to the app. The mock keeps nothing on disk, sends no email, and its conversions return the input's bytes. It's for testing, not for real use.

## Security the server must keep

- **TLS everywhere.** The app refuses plain-http servers that aren't on the Mac itself.
- **Sign-in**: PKCE `S256` only, an exact redirect match, single-use codes with a 10-minute lifetime, and single-use magic links with a 15-minute lifetime.
- **Tokens**: random 256-bit strings stored hashed. Access tokens last 1 hour; refresh tokens last 60 days and rotate on every use, and reusing an old one revokes the whole family.
- **Share links** are served from the separate `SHARE_URL` origin as downloads, so uploaded HTML can never run on the API or sign-in origin. Passwords are hashed with argon2id, and stats are counts only, with no viewer IPs.
- **Logs** keep to method, route, status, latency and request id: never tokens, codes, link passwords or file names next to IPs.
- **No analytics or third-party scripts** on any page the server renders.
- **Retention**: job inputs and results are deleted when they expire, inbox items after the Mac confirms receipt, and unfinished uploads after 24 hours.
