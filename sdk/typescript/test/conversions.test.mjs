import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import {
  Anyfmt, AnyfmtAuthenticationError, AnyfmtConflictError, AnyfmtConversionFailedError, AnyfmtNotFoundError,
  AnyfmtPermissionError, AnyfmtTimeoutError, AnyfmtValidationError,
} from '../dist/index.js';
import { startMock, startReceiver } from './helpers.mjs';

let mock; let anyfmt; let dir;
const sha = (b) => createHash('sha256').update(b).digest('hex');

before(async () => {
  mock = await startMock();
  dir = await mkdtemp(join(tmpdir(), 'anyfmt-sdk-'));
});
after(async () => { await mock.stop(); await rm(dir, { recursive: true, force: true }); });
beforeEach(async () => {
  await mock.reset();
  anyfmt = new Anyfmt({ apiKey: await mock.apiKey(), baseUrl: mock.baseUrl, retryBaseMs: 10 });
});

test('constructor rejects keys that are not anyfmt_sk_ and never serialises the key', () => {
  assert.throws(() => new Anyfmt({ apiKey: 'at_oauth_token' }), TypeError);
  const h = new Anyfmt({ apiKey: 'anyfmt_sk_x', baseUrl: 'http://127.0.0.1:1/' });
  assert.equal(h.baseUrl, 'http://127.0.0.1:1');
  assert.ok(!JSON.stringify(h).includes('anyfmt_sk_'));
});

test('files.upload from a path, then convert, wait and download', async () => {
  const path = join(dir, 'photo.png');
  const bytes = Buffer.from('not really a png, the mock copies bytes');
  await writeFile(path, bytes);
  const file = await anyfmt.files.upload(path);
  assert.equal(file.name, 'photo.png');
  assert.equal(file.size, bytes.length);
  assert.equal(file.sha256, sha(bytes));
  assert.equal(file.format, 'png');

  const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'webp', options: { quality: 80 } });
  assert.equal(c.status, 'queued');
  assert.equal(c.target, 'webp');
  assert.equal(c.optionsSchema, 'image.webp');
  assert.deepEqual(c.options, { quality: 80, lossless: false, maxDimension: 0 }, 'defaults filled in');

  const done = await anyfmt.conversions.wait(c.id, { timeoutMs: 5000 });
  assert.equal(done.status, 'succeeded');
  assert.equal(done.progress, 1);
  assert.equal(done.output.name, 'photo.webp');
  assert.equal(done.usage.billable, true);
  assert.equal(done.usage.inputBytes, bytes.length);

  const dest = join(dir, 'out.webp');
  const r = await anyfmt.files.download(done.output.id, dest);
  assert.equal(r.bytes, bytes.length);
  assert.equal(r.resumed, false);
  assert.deepEqual(await readFile(dest), bytes);
});

test('files.upload from a Blob needs a filename; a File carries its own', async () => {
  await assert.rejects(anyfmt.files.upload(new Blob(['x'])), TypeError);
  const f = await anyfmt.files.upload(new Blob(['subtitle'], { type: 'application/x-subrip' }), { filename: 'talk.srt' });
  assert.equal(f.format, 'srt');
  assert.equal(f.contentType, 'application/x-subrip');
  if (typeof File !== 'undefined') {
    const g = await anyfmt.files.upload(new File(['abc'], 'clip.mov'));
    assert.equal(g.name, 'clip.mov');
    assert.equal(g.format, 'mov');
  }
});

test('conversion input by URL', async () => {
  const origin = await startReceiver(() => [200, 'remote bytes', { 'Content-Type': 'image/jpeg' }]);
  try {
    const c = await anyfmt.conversions.create({ input: { url: `${origin.url}/pics/cat.jpg` }, target: 'png' });
    assert.equal(c.input.format, 'jpg');
    assert.equal(c.input.name, 'cat.jpg');
    const done = await anyfmt.conversions.wait(c);
    assert.equal(Buffer.from(await anyfmt.files.read(done.output.id)).toString(), 'remote bytes');
  } finally { await origin.close(); }
  await assert.rejects(
    anyfmt.conversions.create({ input: { url: 'http://127.0.0.1:1/nope.png' }, target: 'jpg' }),
    (e) => e instanceof AnyfmtValidationError && e.code === 'input_unavailable',
  );
});

test('get, list with cursor pagination and status filter, iterate', async () => {
  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.mp4' });
  const ids = [];
  for (let i = 0; i < 5; i += 1) ids.push((await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'webm', metadata: { n: String(i) } })).id);
  const got = await anyfmt.conversions.get(ids[2]);
  assert.equal(got.metadata.n, '2');

  const p1 = await anyfmt.conversions.list({ limit: 2 });
  assert.deepEqual(p1.items.map((c) => c.id), [ids[4], ids[3]], 'newest first');
  assert.ok(p1.nextCursor);
  const p2 = await anyfmt.conversions.list({ limit: 2, cursor: p1.nextCursor });
  assert.deepEqual(p2.items.map((c) => c.id), [ids[2], ids[1]]);
  const p3 = await anyfmt.conversions.list({ limit: 2, cursor: p2.nextCursor });
  assert.deepEqual(p3.items.map((c) => c.id), [ids[0]]);
  assert.equal(p3.nextCursor, null);

  const all = [];
  for await (const c of anyfmt.conversions.iterate({ limit: 2 })) all.push(c.id);
  assert.deepEqual(all, [...ids].reverse());

  await anyfmt.conversions.wait(ids[4]);
  await anyfmt.conversions.wait(ids[0]);
  const queued = await anyfmt.conversions.list({ status: 'succeeded', limit: 100 });
  assert.ok(queued.items.every((c) => c.status === 'succeeded'));
  await assert.rejects(anyfmt.conversions.list({ cursor: 'garbage' }), AnyfmtValidationError);
});

test('idempotency: same key + body replays, different body conflicts', async () => {
  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.wav' });
  const body = { input: { fileId: file.id }, target: 'mp3', options: { bitrate: '192' } };
  const a = await anyfmt.conversions.create(body, { idempotencyKey: 'order-42' });
  const b = await anyfmt.conversions.create({ target: 'mp3', options: { bitrate: '192' }, input: { fileId: file.id } }, { idempotencyKey: 'order-42' });
  assert.equal(b.id, a.id, 'key order in JSON does not matter');
  const page = await anyfmt.conversions.list();
  assert.equal(page.items.length, 1, 'only one conversion was created');
  await assert.rejects(
    anyfmt.conversions.create({ ...body, target: 'flac', options: {} }, { idempotencyKey: 'order-42' }),
    (e) => e instanceof AnyfmtConflictError && e.code === 'idempotency_conflict',
  );
  // Without a key, each call is a new conversion (the SDK sends a fresh UUID).
  const c = await anyfmt.conversions.create(body);
  const d = await anyfmt.conversions.create(body);
  assert.notEqual(c.id, d.id);
  const reqs = (await mock.requests()).filter((r) => r.method === 'POST' && r.path === '/v1/conversions');
  assert.equal(reqs.length, 5);
});

test('cancel: queued → cancelled, idempotent, finished ones conflict', async () => {
  await mock.config({ conversionMs: 3000 });
  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.mov' });
  const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'mp4' });
  const x = await anyfmt.conversions.cancel(c.id);
  assert.equal(x.status, 'cancelled');
  assert.equal(x.usage.billable, false, 'cancelled while queued is free');
  const y = await anyfmt.conversions.cancel(c.id);
  assert.equal(y.status, 'cancelled');
  await assert.rejects(anyfmt.conversions.wait(c.id), (e) => e instanceof AnyfmtConversionFailedError && e.conversion.status === 'cancelled');

  await mock.config({ conversionMs: 50 });
  const d = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'mp4' });
  await anyfmt.conversions.wait(d.id);
  await assert.rejects(anyfmt.conversions.cancel(d.id), (e) => e instanceof AnyfmtConflictError && e.code === 'already_finished');
  await assert.rejects(anyfmt.conversions.cancel('cnv_missing'), AnyfmtNotFoundError);
});

test('wait: running progress, timeout, and failure', async () => {
  await mock.config({ conversionMs: 1500 });
  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.png' });
  const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg' });
  await assert.rejects(anyfmt.conversions.wait(c.id, { timeoutMs: 600 }), (e) => e instanceof AnyfmtTimeoutError && e.code === 'wait_timeout');
  const mid = await anyfmt.conversions.get(c.id);
  assert.equal(mid.status, 'running');
  assert.ok(mid.progress > 0 && mid.progress < 1);

  await mock.config({ conversionMs: 50, failConversions: true });
  const f = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg' });
  await assert.rejects(anyfmt.conversions.wait(f.id), (e) => {
    assert.ok(e instanceof AnyfmtConversionFailedError);
    assert.equal(e.conversion.status, 'failed');
    assert.equal(e.conversion.error.code, 'conversion_failed');
    assert.equal(e.conversion.usage.billable, false);
    return true;
  });
});

test('options are validated against the route\'s schema id', async () => {
  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.png' });
  await assert.rejects(anyfmt.conversions.create({ input: { fileId: file.id }, target: 'webp', options: { quality: 101, bogus: 1, lossless: 'yes' } }), (e) => {
    assert.ok(e instanceof AnyfmtValidationError);
    assert.equal(e.code, 'validation_failed');
    assert.equal(e.status, 422);
    assert.ok(e.requestId?.startsWith('req_'));
    assert.deepEqual([...e.details.fields].sort(), ['options.bogus', 'options.lossless', 'options.quality']);
    assert.equal(e.details.optionsSchema, 'image.webp');
    return true;
  });
  await assert.rejects(anyfmt.conversions.create({ input: { fileId: file.id }, target: 'mp3' }), (e) => e.code === 'unsupported_route' && e.details.targets.includes('webp'));
  // A choice takes its id as a string (numbers matching an id are accepted).
  const ok = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'pdf', options: { pageSize: 'a4' } });
  assert.equal(ok.options.pageSize, 'a4');
  const heic = await anyfmt.files.upload(new Blob(['h']), { filename: 'x.heic' });
  const twoHop = await anyfmt.conversions.create({ input: { fileId: heic.id }, target: 'pdf' });
  assert.equal(twoHop.hops, 2);
  await assert.rejects(anyfmt.conversions.create({ input: { fileId: 'fil_nope' }, target: 'png' }), AnyfmtNotFoundError);
});

test('files.read supports byte ranges; download resumes a .part with Range', async () => {
  const data = Buffer.from('0123456789abcdefghij');
  const file = await anyfmt.files.upload(new Blob([data]), { filename: 'r.txt' });
  assert.equal(Buffer.from(await anyfmt.files.read(file.id, { start: 2, end: 5 })).toString(), '2345');
  assert.equal(Buffer.from(await anyfmt.files.read(file.id, { start: 15 })).toString(), 'fghij');
  await assert.rejects(anyfmt.files.read(file.id, { start: 100 }), (e) => e.status === 416 && e.code === 'range_not_satisfiable');

  const dest = join(dir, 'resume.txt');
  await writeFile(`${dest}.part`, data.subarray(0, 7));
  const r = await anyfmt.files.download(file.id, dest);
  assert.equal(r.resumed, true);
  assert.equal((await mock.requests()).filter((x) => x.range).at(-1).range, 'bytes=7-');
  assert.deepEqual(await readFile(dest), data);

  // A stale .part that is already complete is thrown away and fetched again.
  await writeFile(`${dest}.part`, data);
  const again = await anyfmt.files.download(file.id, dest);
  assert.equal(again.resumed, false);
  assert.deepEqual(await readFile(dest), data);
});

test('formats.list and schema.get', async () => {
  const all = await anyfmt.formats.list();
  assert.equal(all.schemaVersion, 1);
  const heic = all.items.find((f) => f.id === 'heic');
  assert.ok(heic.extensions.includes('heif'));
  const pdf = heic.targets.find((t) => t.id === 'pdf');
  assert.deepEqual({ hops: pdf.hops, via: pdf.via }, { hops: 2, via: ['jpg'] });
  const one = await anyfmt.formats.list({ input: 'mp4' });
  assert.equal(one.items.length, 1);
  assert.ok(one.items[0].targets.some((t) => t.id === 'gif' && t.optionsSchema === 'gif'));
  await assert.rejects(anyfmt.formats.list({ input: 'xyz' }), AnyfmtNotFoundError);

  const schema = await anyfmt.schema.get();
  assert.equal(schema.schemaVersion, 1);
  const webp = schema.optionSchemas.find((s) => s.id === 'image.webp');
  const quality = webp.options.find((o) => o.id === 'quality');
  assert.deepEqual({ kind: quality.kind, min: quality.min, max: quality.max, default: quality.default }, { kind: 'slider', min: 1, max: 100, default: 85 });
  // Every route's optionsSchema exists in optionSchemas.
  const ids = new Set(schema.optionSchemas.map((s) => s.id));
  for (const f of schema.formats) for (const t of f.targets) assert.ok(ids.has(t.optionsSchema), `${f.id}→${t.id}`);
  assert.ok(schema.tools.some((t) => t.id === 'cloud.transcribe'));
  assert.ok(schema.presets.length > 0);
});

test('usage.get sums billable conversions for the period', async () => {
  const file = await anyfmt.files.upload(new Blob([Buffer.alloc(1024 * 1024)]), { filename: 'a.mov' });
  await anyfmt.conversions.wait(await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'mp4' }));
  await mock.config({ conversionMs: 5000 });
  await anyfmt.conversions.cancel((await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'mp4' })).id);
  const u = await anyfmt.usage.get();
  assert.equal(u.conversions.total, 2);
  assert.equal(u.conversions.succeeded, 1);
  assert.equal(u.conversions.cancelled, 1);
  assert.equal(u.conversions.billable, 1);
  assert.equal(u.mediaMinutes, 1);
  assert.deepEqual(u.bytes, { input: 1024 * 1024, output: 1024 * 1024 });
  const past = await anyfmt.usage.get({ period: '2020-01' });
  assert.equal(past.conversions.total, 0);
  assert.equal(past.period.start, '2020-01-01T00:00:00.000Z');
  await assert.rejects(anyfmt.usage.get({ period: '2020-13' }), AnyfmtValidationError);
});

test('auth: unknown key 401, read-only key 403 on writes, accounts are isolated', async () => {
  const bad = new Anyfmt({ apiKey: 'anyfmt_sk_doesnotexist', baseUrl: mock.baseUrl });
  await assert.rejects(bad.formats.list().then(() => bad.conversions.list()), (e) => e instanceof AnyfmtAuthenticationError && e.code === 'invalid_api_key');
  const reader = new Anyfmt({ apiKey: await mock.apiKey({ scopes: ['read'] }), baseUrl: mock.baseUrl });
  await reader.conversions.list();
  await assert.rejects(reader.files.upload(new Blob(['a']), { filename: 'a.png' }), (e) => e instanceof AnyfmtPermissionError && e.details.scope === 'convert');

  const file = await anyfmt.files.upload(new Blob(['a']), { filename: 'a.png' });
  const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg' });
  const other = new Anyfmt({ apiKey: await mock.apiKey({ email: 'someone@example.com' }), baseUrl: mock.baseUrl });
  await assert.rejects(other.conversions.get(c.id), AnyfmtNotFoundError);
  await assert.rejects(other.files.read(file.id), AnyfmtNotFoundError);
  await assert.rejects(other.conversions.create({ input: { fileId: file.id }, target: 'jpg' }), AnyfmtNotFoundError);
});
