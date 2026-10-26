import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { Anyfmt, AnyfmtValidationError, AnyfmtWebhookSignatureError, Webhooks, verifyWebhook, webhookSignatureHeader } from '../dist/index.js';
import { startMock, startReceiver } from './helpers.mjs';

let mock; let anyfmt;
before(async () => { mock = await startMock(); });
after(async () => { await mock.stop(); });
beforeEach(async () => {
  await mock.reset();
  anyfmt = new Anyfmt({ apiKey: await mock.apiKey(), baseUrl: mock.baseUrl, retryBaseMs: 10 });
});

const SECRET = 'whsec_test_0123456789abcdefghijklmnopqrstuv';
const BODY = JSON.stringify({ id: 'evt_1', type: 'conversion.succeeded', createdAt: '2026-10-18T00:00:00Z', data: { conversion: { id: 'cnv_1' } } });
const now = () => Math.floor(Date.now() / 1000);

test('verify: a valid signature returns the parsed event (string or bytes body)', () => {
  const header = webhookSignatureHeader(BODY, SECRET);
  assert.equal(verifyWebhook(BODY, header, SECRET).id, 'evt_1');
  assert.equal(anyfmt.webhooks.verify(Buffer.from(BODY), header, SECRET).type, 'conversion.succeeded');
  assert.equal(Webhooks.verify(new TextEncoder().encode(BODY), header, SECRET).data.conversion.id, 'cnv_1');
  // Independent HMAC, not the SDK's own signer.
  const t = now();
  const v1 = createHmac('sha256', SECRET).update(`${t}.${BODY}`).digest('hex');
  assert.equal(verifyWebhook(BODY, `t=${t},v1=${v1}`, SECRET).id, 'evt_1');
});

test('verify: during a secret rotation any matching v1 is accepted', () => {
  const t = now();
  const good = createHmac('sha256', SECRET).update(`${t}.${BODY}`).digest('hex');
  const old = createHmac('sha256', 'whsec_old').update(`${t}.${BODY}`).digest('hex');
  assert.equal(verifyWebhook(BODY, `t=${t},v1=${old},v1=${good}`, SECRET).id, 'evt_1');
});

test('verify: expired (older than 5 minutes, or from the future) is rejected', () => {
  const stale = webhookSignatureHeader(BODY, SECRET, now() - 301);
  assert.throws(() => verifyWebhook(BODY, stale, SECRET), (e) => e instanceof AnyfmtWebhookSignatureError && e.reason === 'expired');
  const future = webhookSignatureHeader(BODY, SECRET, now() + 400);
  assert.throws(() => verifyWebhook(BODY, future, SECRET), (e) => e.reason === 'expired');
  // Within a custom tolerance it is fine.
  assert.equal(verifyWebhook(BODY, stale, SECRET, { toleranceSec: 600 }).id, 'evt_1');
  assert.equal(verifyWebhook(BODY, webhookSignatureHeader(BODY, SECRET, 1000), SECRET, { nowSec: 1200 }).id, 'evt_1');
});

test('verify: tampered body, wrong secret, or tampered timestamp is a mismatch', () => {
  const header = webhookSignatureHeader(BODY, SECRET);
  assert.throws(() => verifyWebhook(BODY.replace('cnv_1', 'cnv_2'), header, SECRET), (e) => e.reason === 'mismatch');
  assert.throws(() => verifyWebhook(BODY, header, 'whsec_wrong'), (e) => e.reason === 'mismatch');
  const t = Number(/t=(\d+)/.exec(header)[1]);
  assert.throws(() => verifyWebhook(BODY, header.replace(`t=${t}`, `t=${t - 1}`), SECRET), (e) => e.reason === 'mismatch');
});

test('verify: malformed or missing header', () => {
  for (const h of [undefined, '', 'v1=abc', `t=${now()}`, `t=${now()},v1=nothex`, 'garbage']) {
    assert.throws(() => verifyWebhook(BODY, h, SECRET), (e) => e instanceof AnyfmtWebhookSignatureError && e.reason === 'malformed', String(h));
  }
});

test('create, list and delete endpoints; secret is shown once', async () => {
  const w = await anyfmt.webhooks.create({ url: 'https://hooks.example.com/anyfmt', events: ['conversion.succeeded'], description: 'prod' });
  assert.match(w.secret, /^whsec_/);
  const list = await anyfmt.webhooks.list();
  assert.equal(list.length, 1);
  assert.equal(list[0].id, w.id);
  assert.equal(list[0].secret, undefined, 'list never returns the secret');
  await anyfmt.webhooks.delete(w.id);
  assert.equal((await anyfmt.webhooks.list()).length, 0);
  await assert.rejects(anyfmt.webhooks.create({ url: 'http://evil.example.com/hook', events: ['conversion.succeeded'] }), (e) => e instanceof AnyfmtValidationError && e.details.fields.includes('url'));
  await assert.rejects(anyfmt.webhooks.create({ url: 'https://x.example.com', events: ['conversion.started'] }), (e) => e.details.fields.includes('events'));
});

test('end to end: deliveries are signed, verify with the SDK, and failures are retried', async () => {
  // First delivery attempt answers 500, the retry answers 200.
  const recv = await startReceiver((_req, n) => (n === 1 ? [500, 'boom'] : [200, 'ok']));
  try {
    const w = await anyfmt.webhooks.create({ url: `${recv.url}/hook`, events: ['conversion.succeeded', 'conversion.failed'] });
    const file = await anyfmt.files.upload(new Blob(['x']), { filename: 'a.png' });
    const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg', metadata: { order: '7' } });
    await recv.waitFor((r) => r.length >= 2);
    const [first, second] = recv.received;
    assert.equal(first.headers['anyfmt-delivery-attempt'], '1');
    assert.equal(second.headers['anyfmt-delivery-attempt'], '2');
    assert.equal(second.headers['anyfmt-webhook-id'], w.id);
    const event = anyfmt.webhooks.verify(second.body, second.headers['anyfmt-signature'], w.secret);
    assert.equal(event.type, 'conversion.succeeded');
    assert.equal(event.data.conversion.id, c.id);
    assert.equal(event.data.conversion.status, 'succeeded');
    assert.equal(event.data.conversion.metadata.order, '7');
    assert.equal(JSON.parse(first.body).id, event.id, 'retries keep the event id');
    assert.throws(() => anyfmt.webhooks.verify(second.body, second.headers['anyfmt-signature'], 'whsec_other'), AnyfmtWebhookSignatureError);
    const log = await mock.deliveries();
    assert.deepEqual(log.map((d) => d.status), [500, 200]);
  } finally { await recv.close(); }
});

test('conversion.failed goes only to subscribers; per-conversion webhook must be registered', async () => {
  const succeededOnly = await startReceiver();
  const perConversion = await startReceiver();
  try {
    await anyfmt.webhooks.create({ url: succeededOnly.url, events: ['conversion.succeeded'] });
    const target = await anyfmt.webhooks.create({ url: perConversion.url, events: ['conversion.succeeded'] });
    await mock.config({ failConversions: true });
    const file = await anyfmt.files.upload(new Blob(['x']), { filename: 'a.png' });
    await assert.rejects(
      anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg', webhook: 'https://not-registered.example.com/h' }),
      (e) => e instanceof AnyfmtValidationError && e.details.reason === 'not_registered',
    );
    const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg', webhook: perConversion.url });
    await perConversion.waitFor((r) => r.length >= 1);
    const ev = verifyWebhook(perConversion.received[0].body, perConversion.received[0].headers['anyfmt-signature'], target.secret);
    assert.equal(ev.type, 'conversion.failed');
    assert.equal(ev.data.conversion.id, c.id);
    assert.equal(ev.data.conversion.error.code, 'conversion_failed');
    await new Promise((r) => setTimeout(r, 100));
    assert.equal(succeededOnly.received.length, 0, 'not subscribed to conversion.failed');
    assert.equal(perConversion.received.length, 1, 'one delivery per event and URL');
  } finally { await succeededOnly.close(); await perConversion.close(); }
});

test('deleting an endpoint drops its pending retries', async () => {
  await mock.config({ webhookRetryMs: [300, 300] });
  const recv = await startReceiver(() => [503, 'down']);
  try {
    const w = await anyfmt.webhooks.create({ url: recv.url, events: ['conversion.succeeded'] });
    const file = await anyfmt.files.upload(new Blob(['x']), { filename: 'a.png' });
    await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'jpg' });
    await recv.waitFor((r) => r.length >= 1);
    await anyfmt.webhooks.delete(w.id);
    await new Promise((r) => setTimeout(r, 700));
    assert.equal(recv.received.length, 1);
  } finally { await recv.close(); }
});
