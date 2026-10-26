import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { Anyfmt, AnyfmtConnectionError, AnyfmtRateLimitError, AnyfmtServerError, parseRetryAfter } from '../dist/index.js';
import { startMock } from './helpers.mjs';

let mock; let key;
before(async () => { mock = await startMock(); });
after(async () => { await mock.stop(); });
beforeEach(async () => { await mock.reset(); key = await mock.apiKey(); });

const client = (extra = {}) => new Anyfmt({ apiKey: key, baseUrl: mock.baseUrl, retryBaseMs: 10, ...extra });
// The mock's test limiter uses 1-second windows; start just after a boundary
// so two quick requests land in the same window.
const alignToSecond = () => new Promise((r) => setTimeout(r, 1000 - (Date.now() % 1000) + 20));
const count = async (method, path) => (await mock.requests()).filter((r) => r.method === method && r.path === path).length;

test('parseRetryAfter: seconds and HTTP dates', () => {
  assert.equal(parseRetryAfter('3'), 3000);
  assert.equal(parseRetryAfter(null), undefined);
  assert.equal(parseRetryAfter('soon'), undefined);
  const now = Date.parse('2026-10-18T00:00:00Z');
  assert.equal(parseRetryAfter('Sun, 18 Oct 2026 00:00:05 GMT', now), 5000);
});

test('429 from the rate limiter (X-Mock-Rate-Limit) is retried after Retry-After and succeeds', async () => {
  const anyfmt = client({ headers: { 'X-Mock-Rate-Limit': '1' } });
  await alignToSecond();
  await anyfmt.formats.list();
  const t0 = Date.now();
  const r = await anyfmt.conversions.list();
  const waited = Date.now() - t0;
  assert.deepEqual(r.items, []);
  assert.ok(waited >= 400, `waited ${waited} ms for the window to reset`);
  const log = (await mock.requests()).filter((x) => x.path === '/v1/conversions');
  assert.deepEqual(log.map((x) => x.status), [429, 200]);
});

test('Retry-After is respected', async () => {
  await mock.fault({ method: 'GET', pathPrefix: '/v1/schema', times: 1, mode: 'status', status: 429, retryAfter: 1 });
  const t0 = Date.now();
  await client().schema.get();
  assert.ok(Date.now() - t0 >= 950, 'waited about a second');
  assert.equal(await count('GET', '/v1/schema'), 2);
});

test('gives up after 3 retries: AnyfmtRateLimitError carries retryAfterMs', async () => {
  await mock.fault({ method: 'GET', pathPrefix: '/v1/formats', times: 10, mode: 'status', status: 429, retryAfter: 0 });
  await assert.rejects(client().formats.list(), (e) => {
    assert.ok(e instanceof AnyfmtRateLimitError);
    assert.equal(e.status, 429);
    assert.equal(e.code, 'rate_limited');
    assert.equal(e.retryAfterMs, 0);
    return true;
  });
  assert.equal(await count('GET', '/v1/formats'), 4, '1 try + 3 retries');
});

test('5xx is retried for idempotent calls, then AnyfmtServerError', async () => {
  await mock.fault({ method: 'GET', pathPrefix: '/v1/usage', times: 2, mode: 'status', status: 503, retryAfter: 0 });
  const u = await client().usage.get();
  assert.equal(u.conversions.total, 0);
  assert.equal(await count('GET', '/v1/usage'), 3);

  await mock.clearRequests();
  await mock.fault({ method: 'GET', pathPrefix: '/v1/usage', times: 9, mode: 'status', status: 500 });
  await assert.rejects(client({ maxRetries: 2 }).usage.get(), (e) => e instanceof AnyfmtServerError && e.status === 500);
  assert.equal(await count('GET', '/v1/usage'), 3, 'maxRetries is configurable');
});

test('conversions.create retries a 500 safely thanks to its Idempotency-Key', async () => {
  const anyfmt = client();
  const file = await anyfmt.files.upload(new Blob(['x']), { filename: 'a.png' });
  await mock.fault({ method: 'POST', pathPrefix: '/v1/conversions', times: 1, mode: 'status', status: 500 });
  const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg' });
  assert.ok(c.id);
  assert.equal((await anyfmt.conversions.list()).items.length, 1);
  const posts = (await mock.requests()).filter((r) => r.method === 'POST' && r.path === '/v1/conversions');
  assert.deepEqual(posts.map((r) => r.status), [500, 202]);
  assert.ok(posts[0].idempotencyKey, 'a key is always sent');
  assert.equal(posts[1].idempotencyKey, posts[0].idempotencyKey, 'the retry reuses it');
});

test('non-idempotent webhooks.create is not retried after a 5xx, but is after a 429', async () => {
  const anyfmt = client();
  await mock.fault({ method: 'POST', pathPrefix: '/v1/webhooks', times: 1, mode: 'status', status: 502 });
  await assert.rejects(anyfmt.webhooks.create({ url: 'https://h.example.com', events: ['conversion.succeeded'] }), AnyfmtServerError);
  assert.equal(await count('POST', '/v1/webhooks'), 1);
  await mock.fault({ method: 'POST', pathPrefix: '/v1/webhooks', times: 1, mode: 'status', status: 429, retryAfter: 0 });
  await anyfmt.webhooks.create({ url: 'https://h.example.com', events: ['conversion.succeeded'] });
  assert.equal(await count('POST', '/v1/webhooks'), 3);
});

test('dropped connections are retried for GETs and surface as AnyfmtConnectionError when nothing answers', async () => {
  await mock.fault({ method: 'GET', pathPrefix: '/v1/conversions', times: 1, mode: 'reset' });
  assert.deepEqual((await client().conversions.list()).items, []);
  const dead = new Anyfmt({ apiKey: key, baseUrl: 'http://127.0.0.1:1', retryBaseMs: 1, maxRetries: 1 });
  await assert.rejects(dead.formats.list(), (e) => e instanceof AnyfmtConnectionError && e.status === 0);
});

test('RateLimit headers are on every public API response, including errors', async () => {
  for (const [method, path] of [['GET', '/v1/formats'], ['GET', '/v1/conversions'], ['GET', '/v1/conversions/nope'], ['POST', '/v1/conversions']]) {
    const res = await fetch(mock.baseUrl + path, { method, headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }, body: method === 'POST' ? '{}' : undefined });
    for (const h of ['ratelimit-limit', 'ratelimit-remaining', 'ratelimit-reset', 'x-request-id']) assert.ok(res.headers.get(h), `${method} ${path} has ${h}`);
    if (!res.ok) {
      const body = await res.json();
      assert.equal(typeof body.error.code, 'string');
      assert.equal(typeof body.error.message, 'string');
      assert.equal(body.error.requestId, res.headers.get('x-request-id'));
    } else await res.arrayBuffer();
  }
  await alignToSecond();
  const limited = await fetch(`${mock.baseUrl}/v1/formats`, { headers: { Authorization: `Bearer ${key}`, 'X-Mock-Rate-Limit': '1' } });
  await limited.arrayBuffer();
  const res = await fetch(`${mock.baseUrl}/v1/formats`, { headers: { Authorization: `Bearer ${key}`, 'X-Mock-Rate-Limit': '1' } });
  assert.equal(res.status, 429);
  assert.ok(Number(res.headers.get('retry-after')) >= 1);
  assert.equal(res.headers.get('ratelimit-remaining'), '0');
  assert.equal((await res.json()).error.code, 'rate_limited');
});
