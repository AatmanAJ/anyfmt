---
title: Files
description: Upload files to the anyfmt HTTP API directly up to 100 MB or with resumable chunked uploads, and download results with byte-range requests and resume.
---

> [!PREVIEW]
> The hosted API isn't live yet. The v1 contract is final and changes only by addition, and every example on this page runs today against the open-source mock: `node Tests/Mock/server.mjs --port 8787`, base `http://127.0.0.1:8787`.

Files are the inputs and outputs of conversions. Upload a file of up to 100 MB in one request, use the resumable upload flow for anything bigger, and download results with byte ranges so an interrupted download can resume.

## Which upload to use

| Upload | Use it for |
|---|---|
| `POST /v1/files` | Almost everything. One request with the raw file as the body, up to **100 MB** |
| The resumable `/v1/uploads` flow | Files over 100 MB, or bad networks. Upload in chunks and continue from the last byte the server committed |

You can also skip the upload and pass a public URL as the conversion input. See [Conversions](/docs/api-conversions).

The [TypeScript SDK](/docs/sdk) picks for you: a direct upload up to 100 MB, the resumable flow above that or when you ask for it.

## Direct upload

```bash title="Terminal"
export ANYFMT_API=https://api.anyfmt.app/v1

curl -s -X POST "$ANYFMT_API/files?filename=photo.heic" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -H 'Content-Type: image/heic' \
  --data-binary @photo.heic
```

```json title="201 Created"
{"id":"fil_…","name":"photo.heic","size":2481233,"sha256":"…","format":"heic","expiresAt":"…"}
```

The input format is detected from the file name's extension, or from the `Content-Type`. To override it, pass `input.format` when you create the conversion. A body over the limit gets `413 payload_too_large`, with the limit in `details.maxBytes`.

## The file object

| Field | Meaning |
|---|---|
| `id` | `fil_…`. Use it as `input.fileId`, or to download |
| `name` | The file name |
| `size` | Bytes |
| `sha256` | The SHA-256 of the content |
| `contentType` | The media type |
| `format` | The detected anyfmt format id, such as `png`, or `null` when unknown |
| `createdAt` | When it was stored |
| `expiresAt` | When it will be deleted, 24 hours by default |

## Resumable upload

1. **Declare the file.** `POST /v1/uploads` with `{filename, size, sha256}`. The response is an upload with its `id`, the committed `offset` (0) and the largest chunk the server accepts, `maxChunkSize`.
2. **Send chunks.** `PUT /v1/uploads/{id}` with raw bytes and `Content-Range: bytes {first}-{last}/{total}`. Send chunks of 8 MiB, or `maxChunkSize` if that's smaller. Each chunk must start exactly at the committed offset.
3. **Resume after a drop.** `HEAD /v1/uploads/{id}` returns the committed offset in `Upload-Offset`. Continue from that byte, not from your own chunk boundary: the server commits bytes as they arrive, so a dropped connection can leave the offset in the middle of a chunk.
4. **Finish.** `POST /v1/uploads/{id}/complete` with the SHA-256. The server verifies it, and the completed upload carries a `fileId` to use as a conversion input.

```http
PUT /v1/uploads/upl_123 HTTP/1.1
Host: api.anyfmt.app
Authorization: Bearer anyfmt_sk_...
Content-Type: application/octet-stream
Content-Range: bytes 0-8388607/52428800
```

- A chunk that doesn't start at the committed offset gets `409 offset_mismatch`, with the real offset in the body and in `Upload-Offset`.
- A hash that doesn't match on completion gets `422 checksum_mismatch`.
- `DELETE /v1/uploads/{id}` aborts the upload and deletes its bytes.
- Uploads that are never completed expire after at least 24 hours, and their bytes are deleted.
- The resumable flow accepts an API key with the `convert` scope.

## Download

`GET /v1/files/{id}/content` returns the file. It supports a single `Range`:

| Range | Returns |
|---|---|
| `bytes=0-1023` | The first 1024 bytes, `206 Partial Content` |
| `bytes=1024-` | Everything from byte 1024 |
| `bytes=-512` | The last 512 bytes |
| Out of range | `416 range_not_satisfiable` |

```bash title="Terminal"
curl -s -o photo.webp "$ANYFMT_API/files/fil_out/content" -H "Authorization: Bearer $ANYFMT_API_KEY"
curl -s -H 'Range: bytes=0-1023' "$ANYFMT_API/files/fil_out/content" \
  -H "Authorization: Bearer $ANYFMT_API_KEY" -o head.bin
curl -s -C - -o big.mp4 "$ANYFMT_API/files/fil_out/content" \
  -H "Authorization: Bearer $ANYFMT_API_KEY"     # resume a partial download
```

A conversion's output is a file like any other: once the conversion has `status: "succeeded"`, download `output.id`.

## Limits

| | Limit |
|---|---|
| Direct upload | 100 MB |
| URL input | 100 MB, fetched within 30 seconds |
| Retention | 24 hours by default (`expiresAt`), then deleted |
| Largest file per account | Reported as `limits.maxFileBytes` by `GET /v1/usage` |

See [Rate limits and retries](/docs/api-limits) for request limits.
