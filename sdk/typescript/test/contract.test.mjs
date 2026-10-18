// Contract checks for the operations the SDK doesn't wrap: API-key
// management (app sign-in only) and licence activation, plus the rules that
// keep the two credential types apart. Raw fetch, no SDK.

import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { appAccessToken, startMock } from './helpers.mjs';

let mock; let token;
before(async () => { mock = await startMock(); });
after(async () => { await mock.stop(); });
beforeEach(async () => { await mock.reset(); token = await appAccessToken(mock.baseUrl); });

async function call(method, path, { auth, body, headers = {} } = {}) {
  const res = await fetch(mock.baseUrl + path, {
    method,
    headers: { ...(auth ? { Authorization: `Bearer ${auth}` } : {}), ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, headers: res.headers, json: text ? JSON.parse(text) : undefined };
}

function assertEnvelope(r, status, code) {
  assert.equal(r.status, status);
  assert.equal(r.json.error.code, code);
  assert.equal(typeof r.json.error.message, 'string');
  assert.equal(r.json.error.requestId, r.headers.get('x-request-id'));
}

test('API keys: create (secret once), list (prefix only), revoke', async () => {
  const created = await call('POST', '/v1/api-keys', { auth: token, body: { name: 'CI', scopes: ['convert', 'read'] } });
  assert.equal(created.status, 201);
  const { apiKey, secret } = created.json;
  assert.match(secret, /^halo_sk_[A-Za-z0-9_-]{32,}$/);
  assert.equal(apiKey.prefix, secret.slice(0, 12));
  assert.deepEqual(apiKey.scopes, ['convert', 'read']);

  const list = await call('GET', '/v1/api-keys', { auth: token });
  assert.equal(list.status, 200);
  assert.equal(list.json.items.length, 1);
  assert.ok(!JSON.stringify(list.json).includes(secret), 'secret never listed');

  assert.equal((await call('GET', '/v1/conversions', { auth: secret })).status, 200);
  assert.equal((await call('DELETE', `/v1/api-keys/${apiKey.id}`, { auth: token })).status, 204);
  assertEnvelope(await call('GET', '/v1/conversions', { auth: secret }), 401, 'invalid_api_key');
  const after = await call('GET', '/v1/api-keys', { auth: token });
  assert.ok(after.json.items[0].revokedAt);
  assertEnvelope(await call('DELETE', '/v1/api-keys/key_missing', { auth: token }), 404, 'not_found');
});

test('API keys: validation, expiry and lastUsedAt', async () => {
  assertEnvelope(await call('POST', '/v1/api-keys', { auth: token, body: { name: '', scopes: ['admin'] } }), 422, 'validation_failed');
  const past = await call('POST', '/v1/api-keys', { auth: token, body: { name: 'x', scopes: ['read'], expiresAt: '2001-01-01T00:00:00Z' } });
  assert.deepEqual(past.json.error.details.fields, ['expiresAt']);
  const k = (await call('POST', '/v1/api-keys', { auth: token, body: { name: 'r', scopes: ['read'] } })).json;
  assert.equal(k.apiKey.lastUsedAt, null);
  await call('GET', '/v1/usage', { auth: k.secret });
  const listed = (await call('GET', '/v1/api-keys', { auth: token })).json.items.find((x) => x.id === k.apiKey.id);
  assert.ok(listed.lastUsedAt);
  // Expired keys stop working.
  const soon = new Date(Date.now() + 300).toISOString();
  const e = (await call('POST', '/v1/api-keys', { auth: token, body: { name: 'e', scopes: ['read'], expiresAt: soon } })).json;
  assert.equal((await call('GET', '/v1/usage', { auth: e.secret })).status, 200);
  await new Promise((r) => setTimeout(r, 400));
  assertEnvelope(await call('GET', '/v1/usage', { auth: e.secret }), 401, 'invalid_api_key');
});

test('credentials stay apart: keys can’t manage keys, app tokens can’t call the public API', async () => {
  const secret = await mock.apiKey();
  assertEnvelope(await call('GET', '/v1/api-keys', { auth: secret }), 401, 'unauthorized');
  assertEnvelope(await call('POST', '/v1/api-keys', { auth: secret, body: { name: 'x', scopes: ['read'] } }), 401, 'unauthorized');
  assertEnvelope(await call('GET', '/v1/conversions', { auth: token }), 401, 'invalid_api_key');
  assertEnvelope(await call('GET', '/v1/conversions'), 401, 'invalid_api_key');
  // /v1/usage takes either.
  assert.equal((await call('GET', '/v1/usage', { auth: token })).status, 200);
  assert.equal((await call('GET', '/v1/usage', { auth: secret })).status, 200);
  // /v1/formats and /v1/schema need no credentials.
  assert.equal((await call('GET', '/v1/formats')).status, 200);
  const schema = await fetch(`${mock.baseUrl}/v1/schema`);
  const etag = schema.headers.get('etag');
  await schema.arrayBuffer();
  assert.equal((await fetch(`${mock.baseUrl}/v1/schema`, { headers: { 'If-None-Match': etag } })).status, 304);
  // Resumable uploads accept a key with the convert scope, not a read-only one.
  const body = { filename: 'a.bin', size: 1, sha256: '0'.repeat(64) };
  assert.equal((await call('POST', '/v1/uploads', { auth: secret, body })).status, 201);
  assertEnvelope(await call('POST', '/v1/uploads', { auth: await mock.apiKey({ scopes: ['read'] }), body }), 403, 'insufficient_scope');
  // …and the app token still works there exactly as before.
  assert.equal((await call('POST', '/v1/uploads', { auth: token, body })).status, 201);
});

test('licences: activate, idempotent per device, device limit, deactivate', async () => {
  const key = 'HALO-MOCK-PRO0-0001';
  const a = await call('POST', '/v1/licences/activate', { body: { key, deviceId: 'device-aaaa-0001', deviceName: 'Studio' } });
  assert.equal(a.status, 200);
  assert.equal(a.json.licence.plan, 'pro');
  assert.equal(a.json.licence.status, 'active');
  assert.equal(a.json.devices.length, 1);
  assert.ok(a.headers.get('ratelimit-limit'));
  const again = await call('POST', '/v1/licences/activate', { body: { key: key.toLowerCase(), deviceId: 'device-aaaa-0001' } });
  assert.equal(again.json.devices.length, 1, 'same device twice is a no-op');
  await call('POST', '/v1/licences/activate', { body: { key, deviceId: 'device-bbbb-0002' } });
  const full = await call('POST', '/v1/licences/activate', { body: { key, deviceId: 'device-cccc-0003' } });
  assertEnvelope(full, 409, 'licence_device_limit');
  assert.equal(full.json.error.details.devices.length, 2);

  const id = a.json.licence.id;
  assertEnvelope(await call('POST', `/v1/licences/${id}/deactivate`, { body: { key: 'HALO-WRONG-KEY-0000', deviceId: 'device-aaaa-0001' } }), 404, 'licence_invalid');
  const d = await call('POST', `/v1/licences/${id}/deactivate`, { body: { key, deviceId: 'device-aaaa-0001' } });
  assert.equal(d.status, 200);
  assert.deepEqual(d.json.devices.map((x) => x.deviceId), ['device-bbbb-0002']);
  assert.equal((await call('POST', '/v1/licences/activate', { body: { key, deviceId: 'device-cccc-0003' } })).status, 200);

  assertEnvelope(await call('POST', '/v1/licences/activate', { body: { key: 'HALO-NOPE-NOPE-NOPE', deviceId: 'device-aaaa-0001' } }), 404, 'licence_invalid');
  assertEnvelope(await call('POST', '/v1/licences/activate', { body: { key: 'x', deviceId: 'y' } }), 422, 'validation_failed');
  const revoked = await mock.ctl('POST', '/licences', { key: 'HALO-REVOKED-0001', status: 'revoked' });
  assertEnvelope(await call('POST', '/v1/licences/activate', { body: { key: revoked.key, deviceId: 'device-aaaa-0001' } }), 409, 'licence_revoked');
});

test('unknown endpoints and bad JSON use the error envelope', async () => {
  assertEnvelope(await call('GET', '/v1/nope'), 404, 'not_found');
  const res = await fetch(`${mock.baseUrl}/v1/conversions`, { method: 'POST', headers: { Authorization: `Bearer ${await mock.apiKey()}`, 'Content-Type': 'application/json' }, body: '{nope' });
  const json = await res.json();
  assert.equal(res.status, 400);
  assert.equal(json.error.code, 'validation_failed');
});

test('every error code the mock emits is in the contract’s enum', async () => {
  const spec = await readFile(new URL('../../../Server/openapi.yaml', import.meta.url), 'utf8');
  const enumBlock = /code:\n\s+type: string\n\s+description: Stable machine code[^\n]*\n\s+enum:\n((?:\s+- \w+\n)+)/.exec(spec);
  assert.ok(enumBlock, 'found the Error.code enum');
  const codes = new Set([...enumBlock[1].matchAll(/- (\w+)/g)].map((m) => m[1]));
  const server = await readFile(new URL('../../../Tests/Mock/server.mjs', import.meta.url), 'utf8');
  const emitted = new Set([...server.matchAll(/sendError\(res, \d+, '(\w+)'/g)].map((m) => m[1]));
  for (const c of emitted) assert.ok(codes.has(c), `${c} is missing from Error.code in openapi.yaml`);
});
