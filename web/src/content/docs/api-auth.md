---
title: Authentication
description: Authenticate to the anyfmt HTTP API with anyfmt_sk_ API keys, choose read and convert scopes, and create, list and revoke keys with your app sign-in.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

The public API authenticates with API keys, sent as a bearer token: `Authorization: Bearer anyfmt_sk_…`. Keys have scopes, and you manage them with your app sign-in, never with another key.

## Two credentials

| Credential | Header | Used for |
|---|---|---|
| **API key** | `Authorization: Bearer anyfmt_sk_…` | The public API: `/v1/files`, `/v1/conversions`, `/v1/formats`, `/v1/schema`, `/v1/webhooks`, `/v1/usage`, and the resumable `/v1/uploads` flow |
| **App sign-in** | `Authorization: Bearer <OAuth access token>` | The Mac app's own endpoints, and managing API keys (`/v1/api-keys`). Also accepted by `/v1/usage` |

The two never stand in for each other:

- An API key can't create, list or revoke API keys, so a leaked key can't mint more.
- The public API rejects an app token with `401 invalid_api_key`.

`GET /v1/formats` and `GET /v1/schema` also answer without any key.

## Scopes

| Scope | Allows |
|---|---|
| `read` | Every `GET`: conversions, file downloads, formats, schema, webhooks and usage |
| `convert` | Everything that creates or changes something: uploads, conversions, cancelling, and registering webhooks |

A key usually has both. A request without the scope it needs gets `403 insufficient_scope`, and `error.details.scope` names the missing scope.

## Send a key

```http
GET /v1/conversions/cnv_123 HTTP/1.1
Host: api.anyfmt.app
Authorization: Bearer anyfmt_sk_AbCd...
```

An unknown, revoked or expired key gets `401 invalid_api_key`. Keys never refresh.

## Manage keys

These endpoints take the **app sign-in** token, not an API key.

| Method | Path | Does |
|---|---|---|
| `POST` | `/v1/api-keys` | Creates a key. Body: `{name, scopes: ["convert", "read"], expiresAt?}`. Returns `201 {apiKey, secret}` |
| `GET` | `/v1/api-keys` | Lists keys. Never includes secrets; revoked keys show `revokedAt` |
| `DELETE` | `/v1/api-keys/{id}` | Revokes a key now. Returns `204`. Safe to repeat |

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1

curl -s -X POST "$ANYFMT_API/api-keys" \
  -H "Authorization: Bearer $ANYFMT_TOKEN" -H 'Content-Type: application/json' \
  -d '{"name": "CI pipeline", "scopes": ["convert", "read"]}'
# {"apiKey":{"id":"key_…","name":"CI pipeline","scopes":["convert","read"],"prefix":"anyfmt_sk_AbCd",…},
#  "secret":"anyfmt_sk_AbCd…"}

curl -s "$ANYFMT_API/api-keys" -H "Authorization: Bearer $ANYFMT_TOKEN"
curl -s -X DELETE "$ANYFMT_API/api-keys/key_123" -H "Authorization: Bearer $ANYFMT_TOKEN"
```

- **The secret is shown once**, in the `POST` response. Store it straight away. Afterwards you only see its `prefix`, such as `anyfmt_sk_AbCd`, so you can tell keys apart.
- `name` is 1 to 100 characters. `expiresAt` is optional; `null` means the key never expires.
- Each key also reports `createdAt` and `lastUsedAt`.

## The API key object

| Field | Meaning |
|---|---|
| `id` | `key_…` |
| `name` | Your label for it |
| `scopes` | `read`, `convert` or both |
| `prefix` | The first 12 characters of the secret |
| `createdAt`, `lastUsedAt` | Timestamps; `lastUsedAt` can be `null` |
| `expiresAt` | When it stops working, or `null` for never |
| `revokedAt` | When it was revoked, or `null` |

## Keys for testing

The mock mints keys directly, without an app sign-in:

```bash title="Terminal"
curl -s -X POST http://127.0.0.1:8787/__mock/api-keys -d '{}' | jq -r .secret
```

It also accepts `scopes`, `name`, `expiresAt` and `plan` in the body, so you can test a key without the `convert` scope.

## Keep keys safe

- Keep keys in an environment variable or a secret store, never in source code.
- Give each system its own key, so you can revoke one without breaking the others.
- Create a key with only `read` for dashboards and monitoring.
- The [TypeScript SDK](/docs/sdk) never logs or serialises the key it's given.
