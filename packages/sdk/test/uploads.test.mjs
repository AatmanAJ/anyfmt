import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Halo, HaloValidationError } from '../dist/index.js';
import { startMock } from './helpers.mjs';

let mock; let halo; let dir;
before(async () => { mock = await startMock(); dir = await mkdtemp(join(tmpdir(), 'halo-up-')); });
after(async () => { await mock.stop(); await rm(dir, { recursive: true, force: true }); });
beforeEach(async () => {
  await mock.reset({ maxChunkSize: 64 * 1024 });
  halo = new Halo({ apiKey: await mock.apiKey(), baseUrl: mock.baseUrl, retryBaseMs: 10 });
});

const sha = (b) => createHash('sha256').update(b).digest('hex');

test('resumable upload (forced) uses /v1/uploads in chunks and yields a fileId for conversions', async () => {
  const data = randomBytes(200 * 1024 + 17);
  const path = join(dir, 'big.mov');
  await writeFile(path, data);
  const f = await halo.files.upload(path, { resumable: true, chunkSize: 1024 * 1024 });
  assert.equal(f.size, data.length);
  assert.equal(f.sha256, sha(data));
  const puts = (await mock.requests()).filter((r) => r.method === 'PUT' && r.path.startsWith('/v1/uploads/'));
  assert.equal(puts.length, 4, 'chunk size is capped by the server maxChunkSize (64 KiB)');
  assert.deepEqual(puts.map((p) => p.contentRange.split('/')[0]), ['bytes 0-65535', 'bytes 65536-131071', 'bytes 131072-196607', 'bytes 196608-204816']);
  const done = await halo.conversions.wait(await halo.conversions.create({ input: { fileId: f.id }, target: 'mp4' }));
  assert.deepEqual(Buffer.from(await halo.files.read(done.output.id)), data);
});

test('resumes from Upload-Offset after a connection drops mid-chunk', async () => {
  const data = randomBytes(150 * 1024);
  await mock.fault({ method: 'PUT', pathPrefix: '/v1/uploads/', skip: 1, times: 1, mode: 'truncate', keepBytes: 1000 });
  const f = await halo.files.upload(new Blob([data]), { filename: 'clip.mp4', resumable: true });
  assert.equal(f.sha256, sha(data));
  const log = await mock.requests();
  assert.ok(log.some((r) => r.method === 'HEAD' && r.path.startsWith('/v1/uploads/')), 'asked the server for its offset');
  const ranges = log.filter((r) => r.method === 'PUT').map((r) => r.contentRange);
  assert.ok(ranges.includes(`bytes ${65536 + 1000}-${65536 * 2 + 1000 - 1}/${data.length}`), `resumed mid-chunk: ${ranges.join(' | ')}`);
  const bytes = await halo.files.read(f.id);
  assert.equal(sha(Buffer.from(bytes)), sha(data));
});

test('resumes after a 503 on a chunk', async () => {
  const data = randomBytes(100 * 1024);
  await mock.fault({ method: 'PUT', pathPrefix: '/v1/uploads/', times: 1, mode: 'status', status: 503, retryAfter: 0 });
  const f = await halo.files.upload(new Blob([data]), { filename: 'clip.mp4', resumable: true });
  assert.equal(f.size, data.length);
  assert.deepEqual(Buffer.from(await halo.files.read(f.id)), data);
});

test('direct upload above the server limit is a 413 payload_too_large', async () => {
  await mock.config({ directUploadMaxBytes: 10 });
  await assert.rejects(halo.files.upload(new Blob(['01234567890']), { filename: 'a.txt' }), (e) => e instanceof HaloValidationError && e.status === 413 && e.code === 'payload_too_large');
  // The resumable path is not subject to it.
  const f = await halo.files.upload(new Blob(['01234567890']), { filename: 'a.txt', resumable: true });
  assert.equal(f.size, 11);
});

test('direct upload of a path keeps bytes exact', async () => {
  const data = randomBytes(300 * 1024);
  const path = join(dir, 'photo.heic');
  await writeFile(path, data);
  const f = await halo.files.upload(path);
  const dest = join(dir, 'roundtrip.heic');
  await halo.files.download(f.id, dest);
  assert.deepEqual(await readFile(dest), data);
});
