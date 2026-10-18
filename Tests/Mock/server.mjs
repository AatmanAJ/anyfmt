#!/usr/bin/env node
// Halo Cloud mock server.
//
// An in-memory implementation of Server/openapi.yaml for the app's cloud
// tests. Node built-ins only (http, crypto, util): no npm install, ever.
//
//   node Tests/Mock/server.mjs --port 0      → prints "LISTENING <port>" on stdout
//
// Everything under /__mock/ is a test-control endpoint (reset, seed users,
// inject faults, read the request log). See Tests/Mock/README.md.
// This is test scaffolding, not a server to deploy: no persistence, no real
// rate limiting (headers, plus the X-Mock-Rate-Limit test hook), no real
// conversions (public API outputs are the input bytes renamed), passwords
// hashed with scrypt only to keep the shape honest. The public pay-per-use
// API (docs/API.md) is implemented in the "public API" section below.

import http from 'node:http';
import crypto from 'node:crypto';
import { parseArgs } from 'node:util';

const { values: argv } = parseArgs({
  options: {
    port: { type: 'string', default: '0' },
    host: { type: 'string', default: '127.0.0.1' },
    quiet: { type: 'boolean', default: false },
    // Exit when stdin closes (the test host passes this so a crashed test run
    // never leaves an orphaned server behind).
    'watch-stdin': { type: 'boolean', default: false },
  },
});

const MiB = 1024 * 1024;
const DEFAULT_CONFIG = Object.freeze({
  maxChunkSize: 8 * MiB,
  accessTokenTTL: 3600,
  refreshTokenTTL: 60 * 24 * 3600,
  // Polls of GET /v1/jobs/{id} before a job succeeds.
  jobPolls: 3,
  pollAfterMs: 20,
  // Every job fails instead of succeeding.
  failJobs: false,
  // Who signs in next through /v1/auth/authorize (simulated magic link).
  nextEmail: 'aj@example.com',
  nextPlan: 'pro',
  // false: /v1/auth/authorize shows the HTML form instead of redirecting.
  autoApprove: true,
  // Host used for signed download URLs. Differs from the API host on purpose
  // so clients prove they never send the bearer token to another origin.
  signedHost: 'localhost',
  rateLimit: 600,
  // Public API: a conversion succeeds this many ms after it was created
  // (queued for the first quarter, then running).
  conversionMs: 200,
  // Every conversion fails instead of succeeding.
  failConversions: false,
  // Webhook retry delays (ms) after a failed delivery; one retry per entry.
  webhookRetryMs: [50, 100, 200],
  webhookTimeoutMs: 2000,
  // Largest body POST /v1/files accepts.
  directUploadMaxBytes: 100 * MiB,
});

// Seeded licence for POST /v1/licences/activate (more via POST /__mock/licences).
const MOCK_LICENCE = Object.freeze({ id: 'lic_mockpro0001', key: 'HALO-MOCK-PRO0-0001', plan: 'pro', status: 'active', maxDevices: 2, expiresAt: null });

const PLANS = {
  free: {
    features: ['shareLink'],
    quotas: { shareLinksPerMonth: 5, shareLinkMaxExpiryHours: 72, shareLinkMaxDownloads: 50, maxUploadBytes: 250 * MiB, storageBytes: 1024 * MiB, cloudJobMinutesPerMonth: 0, pollIntervalSeconds: 300 },
  },
  pro: {
    features: ['shareLink', 'cloudJobs', 'sync', 'inbox', 'transcription', 'upscale', 'backgroundRemovalHQ'],
    quotas: { shareLinksPerMonth: null, shareLinkMaxExpiryHours: null, shareLinkMaxDownloads: null, maxUploadBytes: 10 * 1024 * MiB, storageBytes: 200 * 1024 * MiB, cloudJobMinutesPerMonth: 600, pollIntervalSeconds: 300 },
  },
  team: {
    features: ['shareLink', 'shareLinkCustomDomain', 'cloudJobs', 'sync', 'inbox', 'transcription', 'upscale', 'backgroundRemovalHQ'],
    quotas: { shareLinksPerMonth: null, shareLinkMaxExpiryHours: null, shareLinkMaxDownloads: null, maxUploadBytes: 50 * 1024 * MiB, storageBytes: 2 * 1024 * 1024 * MiB, cloudJobMinutesPerMonth: 6000, pollIntervalSeconds: 60 },
  },
};

const TOOL_FEATURES = {
  'cloud.transcribe': 'transcription',
  'cloud.upscale': 'upscale',
  'cloud.removeBackgroundHQ': 'backgroundRemovalHQ',
};

let state = freshState();
let listenPort = 0;
const publicBase = () => `http://${argv.host}:${listenPort}`;
const signedBase = () => `http://${state.config.signedHost}:${listenPort}`;

function freshState(config = {}) {
  return {
    config: { ...DEFAULT_CONFIG, ...config },
    users: new Map(),
    codes: new Map(),
    lastCode: null,
    access: new Map(),
    refresh: new Map(),
    devices: new Map(),
    uploads: new Map(),
    links: new Map(),
    jobs: new Map(),
    files: new Map(),
    sync: new Map(),
    inbox: new Map(),
    faults: [],
    requests: [],
    rate: new Map(),
    // public API
    apiKeys: new Map(),          // secret → key record
    conversions: new Map(),      // id → conversion (insertion order = creation order)
    idempotency: new Map(),      // `${email}\n${key}` → { hash, conversionId }
    webhooks: new Map(),         // id → endpoint
    deliveries: [],
    licences: new Map([[MOCK_LICENCE.key, { ...MOCK_LICENCE, devices: [] }]]),
    testRate: new Map(),
    timers: new Set(),
  };
}

/// setTimeout that dies with the state it belongs to (reset clears it).
function later(ms, fn) {
  const owner = state;
  const t = setTimeout(() => { owner.timers.delete(t); if (state === owner) fn(); }, ms);
  owner.timers.add(t);
  return t;
}

// ---------------------------------------------------------------- helpers

const id = (prefix) => `${prefix}_${crypto.randomBytes(9).toString('base64url')}`;
const now = () => new Date();
const iso = (d) => d.toISOString();
const sha256hex = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const b64url = (buf) => Buffer.from(buf).toString('base64url');

function user(email, plan) {
  let u = state.users.get(email);
  if (!u) {
    u = { id: id('usr'), email, name: null, plan: plan ?? state.config.nextPlan, customDomains: [], linksUsed: 0, jobMinutesUsed: 0, storageUsed: 0 };
    state.users.set(email, u);
  } else if (plan) {
    u.plan = plan;
  }
  return u;
}

function entitlements(u) {
  const plan = PLANS[u.plan] ?? PLANS.free;
  const resets = new Date(Date.UTC(now().getUTCFullYear(), now().getUTCMonth() + 1, 1));
  return {
    plan: u.plan,
    features: [...plan.features],
    quotas: {
      ...plan.quotas,
      shareLinksUsed: u.linksUsed,
      storageUsedBytes: u.storageUsed,
      cloudJobMinutesUsed: u.jobMinutesUsed,
      periodResetsAt: iso(resets),
    },
    customDomains: plan.features.includes('shareLinkCustomDomain') ? [...u.customDomains] : [],
  };
}

const hasFeature = (u, f) => (PLANS[u.plan] ?? PLANS.free).features.includes(f);

function headers(res, extra = {}) {
  for (const [k, v] of Object.entries(extra)) res.setHeader(k, v);
}

function send(res, status, body, extra = {}) {
  headers(res, extra);
  if (body === undefined || status === 204 || status === 304) {
    res.writeHead(status);
    res.end();
    return;
  }
  const data = Buffer.from(JSON.stringify(body));
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': data.length });
  res.end(data);
}

function sendError(res, status, code, message, details, extraBody = {}, extraHeaders = {}) {
  const error = { code, message, requestId: res.getHeader('X-Request-Id') };
  if (details) error.details = details;
  send(res, status, { error, ...extraBody }, extraHeaders);
}

function readBody(req, limit = 2 * MiB) {
  return new Promise((resolve, reject) => {
    const parts = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(Object.assign(new Error('too large'), { status: 413 })); req.destroy(); return; }
      parts.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(parts)));
    req.on('error', reject);
  });
}

async function readJSON(req, res, limit) {
  try {
    const buf = await readBody(req, limit);
    if (buf.length === 0) return {};
    return JSON.parse(buf.toString('utf8'));
  } catch (e) {
    if (e.status === 413) sendError(res, 413, 'payload_too_large', 'That request is too large.', { maxBytes: limit });
    else sendError(res, 400, 'validation_failed', 'The request body isn’t valid JSON.');
    return null;
  }
}

async function readForm(req) {
  const buf = await readBody(req, 64 * 1024);
  return Object.fromEntries(new URLSearchParams(buf.toString('utf8')));
}

/// Bearer auth. Returns the user or sends 401 and returns null.
function authenticate(req, res) {
  const h = req.headers.authorization ?? '';
  const m = /^Bearer (.+)$/.exec(h);
  if (!m) {
    sendError(res, 401, 'unauthorized', 'Sign in to continue.', null, {}, { 'WWW-Authenticate': 'Bearer' });
    return null;
  }
  const t = state.access.get(m[1]);
  if (!t) {
    sendError(res, 401, 'unauthorized', 'Your session isn’t valid. Sign in again.', null, {}, { 'WWW-Authenticate': 'Bearer error="invalid_token"' });
    return null;
  }
  if (t.exp <= Date.now()) {
    sendError(res, 401, 'token_expired', 'Your session expired.', null, {}, { 'WWW-Authenticate': 'Bearer error="invalid_token", error_description="expired"' });
    return null;
  }
  const d = state.devices.get(t.deviceId);
  if (d) d.lastSeenAt = iso(now());
  return state.users.get(t.email);
}

function rateHeaders(req, res) {
  const key = req.headers.authorization ?? req.socket.remoteAddress ?? 'anon';
  // Test hook: `X-Mock-Rate-Limit: N` allows N requests per 1-second window
  // for this credential and answers 429 + Retry-After beyond that.
  const testLimit = Number(req.headers['x-mock-rate-limit']);
  if (Number.isInteger(testLimit) && testLimit > 0) {
    const second = Math.floor(Date.now() / 1000);
    const r = state.testRate.get(key);
    const entry = r && r.window === second ? r : { window: second, used: 0 };
    entry.used += 1;
    state.testRate.set(key, entry);
    const resetSec = Math.max(1, Math.ceil(((second + 1) * 1000 - Date.now()) / 1000));
    headers(res, {
      'RateLimit-Limit': String(testLimit),
      'RateLimit-Remaining': String(Math.max(0, testLimit - entry.used)),
      'RateLimit-Reset': String(resetSec),
    });
    if (entry.used > testLimit) { res.setHeader('Retry-After', String(resetSec)); return false; }
    return true;
  }
  const window = Math.floor(Date.now() / 60000);
  const r = state.rate.get(key);
  const entry = r && r.window === window ? r : { window, used: 0 };
  entry.used += 1;
  state.rate.set(key, entry);
  const reset = 60 - Math.floor((Date.now() / 1000) % 60);
  headers(res, {
    'RateLimit-Limit': String(state.config.rateLimit),
    'RateLimit-Remaining': String(Math.max(0, state.config.rateLimit - entry.used)),
    'RateLimit-Reset': String(reset),
  });
  return true;
}

function issueTokens(email, deviceId, family) {
  const access = id('at');
  const refresh = id('rt');
  state.access.set(access, { email, exp: Date.now() + state.config.accessTokenTTL * 1000, deviceId, family });
  state.refresh.set(refresh, { email, deviceId, family, rotated: false, exp: Date.now() + state.config.refreshTokenTTL * 1000 });
  return { access_token: access, token_type: 'Bearer', expires_in: state.config.accessTokenTTL, refresh_token: refresh, scope: 'cloud', device_id: deviceId };
}

function revokeFamily(family) {
  for (const [k, v] of state.access) if (v.family === family) state.access.delete(k);
  for (const [k, v] of state.refresh) if (v.family === family) state.refresh.delete(k);
}

/// Returns the first armed fault that matches this request, consuming one use.
function takeFault(req, path) {
  for (const f of state.faults) {
    if (f.method && f.method !== req.method) continue;
    if (f.pathPrefix && !path.startsWith(f.pathPrefix)) continue;
    if (f.skip > 0) { f.skip -= 1; continue; }
    if (f.times <= 0) continue;
    f.times -= 1;
    return f;
  }
  return null;
}

function uploadJSON(u) {
  return { id: u.id, filename: u.filename, size: u.size, offset: u.offset, status: u.status, maxChunkSize: state.config.maxChunkSize, sha256: u.sha256, expiresAt: u.expiresAt, fileId: u.fileId ?? null };
}

function linkJSON(l) {
  return {
    id: l.id, url: l.url, title: l.title, createdAt: l.createdAt, expiresAt: l.expiresAt, maxDownloads: l.maxDownloads,
    downloads: l.downloads, hasPassword: Boolean(l.passwordHash), customDomain: l.customDomain, revoked: l.revoked,
    files: l.files.map((f) => ({ name: f.name, size: f.size })),
  };
}

function jobJSON(j) {
  const out = {
    id: j.id, status: j.status, progress: j.progress, stage: j.stage, etaSeconds: null, createdAt: j.createdAt,
    finishedAt: j.finishedAt, pollAfterMs: state.config.pollAfterMs, operation: j.operation, results: j.results,
  };
  if (j.error) out.error = j.error;
  return out;
}

function addFile(buf, name, contentType, owner) {
  const fileId = id('fil');
  const sig = crypto.randomBytes(16).toString('hex');
  state.files.set(fileId, { buf, name, contentType, owner, sig });
  return { fileId, url: `${signedBase()}/v1/files/${fileId}?sig=${sig}` };
}

function stem(name) {
  const i = name.lastIndexOf('.');
  return i > 0 ? name.slice(0, i) : name;
}

const CANNED_SRT = `1
00:00:00,000 --> 00:00:02,500
Hello from the Halo mock server.

2
00:00:02,500 --> 00:00:05,000
This transcript is canned.
`;

const CANNED_VTT = `WEBVTT

00:00:00.000 --> 00:00:02.500
Hello from the Halo mock server.

00:00:02.500 --> 00:00:05.000
This transcript is canned.
`;

function completeJob(j) {
  const up = state.uploads.get(j.uploadId);
  const input = up?.data ?? Buffer.alloc(0);
  const base = stem(up?.filename ?? 'file');
  let buf; let name; let contentType = 'application/octet-stream';
  const op = j.operation;
  if (op.type === 'convert') {
    buf = input; name = `${base}.${op.target}`;
  } else if (op.tool === 'cloud.transcribe') {
    const target = op.target ?? 'srt';
    buf = Buffer.from(target === 'vtt' ? CANNED_VTT : CANNED_SRT, 'utf8');
    name = `${base}.${target}`; contentType = target === 'vtt' ? 'text/vtt' : 'application/x-subrip';
  } else {
    buf = input; name = `${base}.${op.target ?? 'png'}`; contentType = 'image/png';
  }
  const f = addFile(buf, name, contentType, j.owner);
  j.status = 'succeeded'; j.progress = 1; j.stage = null; j.finishedAt = iso(now());
  j.results = [{ name, size: buf.length, sha256: sha256hex(buf), contentType, downloadUrl: f.url, expiresAt: iso(new Date(Date.now() + 24 * 3600e3)) }];
}

function advanceJob(j) {
  if (['succeeded', 'failed', 'cancelled'].includes(j.status)) return;
  j.polls += 1;
  if (state.config.failJobs && j.polls >= 1) {
    j.status = 'failed'; j.finishedAt = iso(now());
    j.error = { code: 'internal', message: 'The cloud worker couldn’t process this file.' };
    return;
  }
  if (j.polls >= state.config.jobPolls) { completeJob(j); return; }
  j.status = 'running';
  j.stage = j.operation.type === 'convert' ? 'Converting' : 'Processing';
  j.progress = Math.min(0.99, j.polls / state.config.jobPolls);
}

function syncStore(email) {
  let m = state.sync.get(email);
  if (!m) { m = new Map(); state.sync.set(email, m); }
  return m;
}

function inboxStore(email) {
  let l = state.inbox.get(email);
  if (!l) { l = []; state.inbox.set(email, l); }
  return l;
}

function inboxJSON(i) {
  return { id: i.id, name: i.name, size: i.size, sha256: i.sha256, contentType: i.contentType, source: i.source, note: i.note, status: i.status, createdAt: i.createdAt, expiresAt: i.expiresAt, downloadUrl: i.downloadUrl };
}

const NAMESPACE = /^[a-z][a-z0-9.-]{0,63}$/;
const SHA = /^[0-9a-f]{64}$/;

function parseVersionTag(h) {
  if (!h) return null;
  const m = /^(?:W\/)?"?(\d+)"?$/.exec(h.trim());
  return m ? Number(m[1]) : NaN;
}

// ---------------------------------------------------------------- routes

const routes = [];
const route = (method, pattern, handler) => {
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
  routes.push({ method, re, keys, handler });
};

// meta
route('GET', '/v1/health', (req, res) => send(res, 200, {
  status: 'ok', api: '1', name: 'Halo Mock', version: 'mock-1', selfHosted: true,
  capabilities: ['shareLink', 'shareLinkCustomDomain', 'cloudJobs', 'sync', 'inbox', 'transcription', 'upscale', 'backgroundRemovalHQ'],
}));

// auth
route('GET', '/v1/auth/authorize', (req, res, { query }) => {
  const redirect = query.get('redirect_uri') ?? '';
  const ok = query.get('response_type') === 'code' && /-mac$/.test(query.get('client_id') ?? '') &&
    /^[a-z][a-z0-9+.-]*:\/\/auth\/callback$/.test(redirect) && query.get('code_challenge_method') === 'S256' &&
    (query.get('code_challenge') ?? '').length >= 43 && (query.get('state') ?? '').length >= 16;
  if (!ok) {
    res.writeHead(400, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<!doctype html><title>Sign-in error</title><p>This sign-in link is invalid.</p>');
    return;
  }
  const code = id('code');
  state.codes.set(code, {
    email: state.config.nextEmail, challenge: query.get('code_challenge'), redirect, clientId: query.get('client_id'),
    exp: Date.now() + 10 * 60e3, used: false,
  });
  state.lastCode = { code, state: query.get('state'), redirectUri: redirect };
  if (!state.config.autoApprove) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<!doctype html><title>Sign in</title><form><label>Email <input name=email type=email></label><button>Send magic link</button></form>');
    return;
  }
  const target = `${redirect}?code=${encodeURIComponent(code)}&state=${encodeURIComponent(query.get('state'))}`;
  res.writeHead(302, { Location: target });
  res.end();
});

route('POST', '/v1/auth/token', async (req, res) => {
  const form = await readForm(req);
  const fail = (error, description) => send(res, 400, { error, error_description: description }, { 'Cache-Control': 'no-store' });
  if (form.grant_type === 'authorization_code') {
    const c = state.codes.get(form.code ?? '');
    if (!c || c.used || c.exp < Date.now()) return fail('invalid_grant', 'The sign-in code is invalid or expired.');
    if (c.redirect !== form.redirect_uri || c.clientId !== form.client_id) return fail('invalid_grant', 'Redirect or client mismatch.');
    const challenge = b64url(crypto.createHash('sha256').update(form.code_verifier ?? '').digest());
    if (challenge !== c.challenge) return fail('invalid_grant', 'PKCE verification failed.');
    c.used = true;
    const u = user(c.email);
    const deviceId = id('dev');
    state.devices.set(deviceId, { id: deviceId, email: u.email, name: form.device_name || 'Mac', createdAt: iso(now()), lastSeenAt: iso(now()) });
    return send(res, 200, issueTokens(u.email, deviceId, id('fam')), { 'Cache-Control': 'no-store' });
  }
  if (form.grant_type === 'refresh_token') {
    const r = state.refresh.get(form.refresh_token ?? '');
    if (!r || r.exp < Date.now()) return fail('invalid_grant', 'Refresh token is invalid.');
    if (r.rotated) { revokeFamily(r.family); return fail('invalid_grant', 'Refresh token was already used.'); }
    r.rotated = true;
    return send(res, 200, issueTokens(r.email, r.deviceId, r.family), { 'Cache-Control': 'no-store' });
  }
  return fail('unsupported_grant_type', 'Unsupported grant type.');
});

route('POST', '/v1/auth/revoke', async (req, res) => {
  const form = await readForm(req);
  const r = state.refresh.get(form.token ?? '');
  if (r) { revokeFamily(r.family); state.devices.delete(r.deviceId); }
  const a = state.access.get(form.token ?? '');
  if (a) revokeFamily(a.family);
  send(res, 200, {});
});

route('GET', '/v1/devices', (req, res) => {
  const u = authenticate(req, res); if (!u) return;
  const auth = state.access.get((req.headers.authorization ?? '').slice(7));
  const items = [...state.devices.values()].filter((d) => d.email === u.email).map((d) => ({ ...d, email: undefined, current: d.id === auth?.deviceId }));
  send(res, 200, { items });
});

route('DELETE', '/v1/devices/:deviceId', (req, res, { params }) => {
  const u = authenticate(req, res); if (!u) return;
  const d = state.devices.get(params.deviceId);
  if (!d || d.email !== u.email) return sendError(res, 404, 'not_found', 'That device isn’t signed in.');
  for (const [k, v] of state.refresh) if (v.deviceId === d.id) revokeFamily(v.family);
  state.devices.delete(d.id);
  send(res, 204);
});

// account
route('GET', '/v1/me', (req, res) => {
  const u = authenticate(req, res); if (!u) return;
  send(res, 200, { user: { id: u.id, email: u.email, name: u.name, teamName: u.plan === 'team' ? 'Mock Team' : null }, entitlements: entitlements(u) });
});

// uploads
route('POST', '/v1/uploads', async (req, res) => {
  const u = authenticateAny(req, res, 'convert'); if (!u) return;
  const body = await readJSON(req, res); if (!body) return;
  const errors = [];
  if (typeof body.filename !== 'string' || !body.filename || body.filename.length > 255) errors.push('filename');
  if (!Number.isInteger(body.size) || body.size < 0) errors.push('size');
  if (typeof body.sha256 !== 'string' || !SHA.test(body.sha256)) errors.push('sha256');
  if (errors.length) return sendError(res, 422, 'validation_failed', 'Some upload details are missing or invalid.', { fields: errors });
  const max = (PLANS[u.plan] ?? PLANS.free).quotas.maxUploadBytes;
  if (body.size > max) return sendError(res, 413, 'payload_too_large', 'That file is larger than your plan allows.', { maxBytes: max });
  const up = {
    id: id('upl'), owner: u.email, filename: body.filename, size: body.size, sha256: body.sha256,
    contentType: body.contentType ?? 'application/octet-stream', purpose: body.purpose ?? 'share',
    offset: 0, parts: [], data: null, status: 'pending', putCount: 0, expiresAt: iso(new Date(Date.now() + 24 * 3600e3)),
  };
  state.uploads.set(up.id, up);
  send(res, 201, uploadJSON(up), { Location: `/v1/uploads/${up.id}` });
});

function ownedUpload(req, res, params, quiet = false) {
  const u = authenticateAny(req, res, 'convert'); if (!u) return null;
  const up = state.uploads.get(params.uploadId);
  if (!up || up.owner !== u.email) {
    if (quiet) { res.writeHead(404); res.end(); } else sendError(res, 404, 'not_found', 'That upload doesn’t exist or has expired.');
    return null;
  }
  return up;
}

route('HEAD', '/v1/uploads/:uploadId', (req, res, { params }) => {
  const up = ownedUpload(req, res, params, true); if (!up) return;
  res.writeHead(204, { 'Upload-Offset': String(up.offset), 'Upload-Length': String(up.size), 'Upload-Expires': up.expiresAt, 'Cache-Control': 'no-store' });
  res.end();
});

route('GET', '/v1/uploads/:uploadId', (req, res, { params }) => {
  const up = ownedUpload(req, res, params); if (!up) return;
  send(res, 200, uploadJSON(up), { 'Upload-Offset': String(up.offset) });
});

route('PUT', '/v1/uploads/:uploadId', async (req, res, { params, fault }) => {
  const up = ownedUpload(req, res, params); if (!up) { req.resume(); return; }
  up.putCount += 1;
  const m = /^bytes (\d+)-(\d+)\/(\d+)$/.exec(req.headers['content-range'] ?? '');
  if (!m) { req.resume(); return sendError(res, 422, 'validation_failed', 'Content-Range is missing or malformed.', { fields: ['Content-Range'] }); }
  const [first, last, total] = [Number(m[1]), Number(m[2]), Number(m[3])];
  if (total !== up.size || last < first || last >= total) { req.resume(); return sendError(res, 422, 'validation_failed', 'Content-Range doesn’t match the upload.'); }
  if (up.status === 'complete' || first !== up.offset) {
    req.resume();
    return sendError(res, 409, 'offset_mismatch', 'The upload is at a different position.', null, { offset: up.offset }, { 'Upload-Offset': String(up.offset) });
  }
  const length = last - first + 1;
  if (length > state.config.maxChunkSize) { req.resume(); return sendError(res, 413, 'payload_too_large', 'Chunk too large.', { maxBytes: state.config.maxChunkSize }); }

  // Commit bytes as they arrive, the way a real resumable server does, so a
  // dropped connection leaves the offset mid-chunk.
  let received = 0;
  const keep = fault?.mode === 'truncate' ? Math.max(1, Math.min(length - 1, fault.keepBytes ?? Math.floor(length / 2))) : Infinity;
  const commit = (buf) => {
    const room = Math.min(buf.length, length - received, keep - received);
    if (room <= 0 || fault?.mode === 'reset' || fault?.mode === 'status') { received += buf.length; return false; }
    up.parts.push(buf.subarray(0, room));
    up.offset += room;
    received += room;
    return received < keep;
  };
  if (fault?.mode === 'reset') { req.socket.destroy(); return; }
  await new Promise((resolve) => {
    req.on('data', (c) => {
      if (!commit(c) && fault?.mode === 'truncate') { req.socket.destroy(); resolve(); }
    });
    req.on('end', resolve);
    req.on('close', resolve);
    req.on('error', resolve);
  });
  if (fault?.mode === 'truncate') { req.socket.destroy(); return; }
  if (fault?.mode === 'status') {
    return sendError(res, fault.status ?? 503, fault.status === 429 ? 'rate_limited' : 'server_busy', 'The server is busy. Try again shortly.', null, {}, { 'Retry-After': String(fault.retryAfter ?? 0) });
  }
  if (received !== length) return sendError(res, 422, 'validation_failed', 'Body length doesn’t match Content-Range.');
  send(res, 200, uploadJSON(up), { 'Upload-Offset': String(up.offset) });
});

route('DELETE', '/v1/uploads/:uploadId', (req, res, { params }) => {
  const up = ownedUpload(req, res, params); if (!up) return;
  state.uploads.delete(up.id);
  send(res, 204);
});

route('POST', '/v1/uploads/:uploadId/complete', async (req, res, { params }) => {
  const up = ownedUpload(req, res, params); if (!up) return;
  const body = await readJSON(req, res); if (!body) return;
  if (up.status === 'complete') return send(res, 200, uploadJSON(up));
  if (up.offset < up.size) return sendError(res, 409, 'upload_incomplete', 'The upload isn’t finished yet.', { offset: up.offset, size: up.size });
  const data = Buffer.concat(up.parts);
  const actual = sha256hex(data);
  if (body.sha256 !== up.sha256 || actual !== up.sha256) {
    state.uploads.delete(up.id);
    return sendError(res, 422, 'checksum_mismatch', 'The uploaded file was damaged in transit. Please try again.', { expected: up.sha256, actual });
  }
  up.data = data; up.parts = []; up.status = 'complete';
  up.fileId = storeFile(data, up.filename, up.contentType, up.owner).id;
  const u = state.users.get(up.owner); if (u) u.storageUsed += data.length;
  send(res, 200, uploadJSON(up));
});

// share links
route('GET', '/v1/links', (req, res, { query }) => {
  const u = authenticate(req, res); if (!u) return;
  const all = query.get('include') === 'all';
  const items = [...state.links.values()].filter((l) => l.owner === u.email && (all || !l.revoked)).reverse().map(linkJSON);
  send(res, 200, { items, nextCursor: null });
});

route('POST', '/v1/links', async (req, res) => {
  const u = authenticate(req, res); if (!u) return;
  const body = await readJSON(req, res); if (!body) return;
  if (!hasFeature(u, 'shareLink')) return sendError(res, 403, 'feature_not_in_plan', 'Share links aren’t part of your plan.', { feature: 'shareLink' });
  const plan = PLANS[u.plan] ?? PLANS.free;
  if (!Array.isArray(body.uploadIds) || body.uploadIds.length === 0) return sendError(res, 422, 'validation_failed', 'Choose at least one file.', { fields: ['uploadIds'] });
  if (body.customDomain != null) {
    if (!hasFeature(u, 'shareLinkCustomDomain')) return sendError(res, 403, 'feature_not_in_plan', 'Custom domains need the Team plan.', { feature: 'shareLinkCustomDomain' });
    if (!u.customDomains.includes(body.customDomain)) return sendError(res, 422, 'validation_failed', 'That domain isn’t verified for your account.', { fields: ['customDomain'] });
  }
  const limit = plan.quotas.shareLinksPerMonth;
  if (limit != null && u.linksUsed >= limit) {
    return sendError(res, 402, 'quota_exceeded', `You’ve used this month’s ${limit} free share links.`, { quota: 'shareLinksPerMonth', resetsAt: entitlements(u).quotas.periodResetsAt });
  }
  const maxHours = plan.quotas.shareLinkMaxExpiryHours;
  const hours = body.expiresInHours ?? null;
  if (hours !== null && (!Number.isInteger(hours) || hours < 1)) return sendError(res, 422, 'validation_failed', 'Expiry must be at least an hour.', { fields: ['expiresInHours'] });
  if (maxHours != null && (hours === null || hours > maxHours)) {
    return sendError(res, 422, 'validation_failed', `Links on your plan expire within ${maxHours} hours.`, { fields: ['expiresInHours'], maxHours });
  }
  if (body.maxDownloads != null && (!Number.isInteger(body.maxDownloads) || body.maxDownloads < 1)) return sendError(res, 422, 'validation_failed', 'Download limit must be at least 1.', { fields: ['maxDownloads'] });
  if (body.password != null && (typeof body.password !== 'string' || body.password.length < 4)) return sendError(res, 422, 'validation_failed', 'Passwords need at least 4 characters.', { fields: ['password'] });
  const files = [];
  for (const uid of body.uploadIds) {
    const up = state.uploads.get(uid);
    if (!up || up.owner !== u.email) return sendError(res, 404, 'not_found', 'One of the files is no longer available.');
    if (up.status !== 'complete') return sendError(res, 409, 'upload_incomplete', 'One of the files hasn’t finished uploading.');
    files.push({ name: up.filename, size: up.size, uploadId: up.id });
  }
  const slug = crypto.randomBytes(6).toString('base64url');
  const host = body.customDomain ? `https://${body.customDomain}` : publicBase();
  let passwordHash = null;
  if (body.password) {
    const salt = crypto.randomBytes(16);
    passwordHash = `${salt.toString('hex')}:${crypto.scryptSync(body.password, salt, 32).toString('hex')}`;
  }
  const l = {
    id: id('lnk'), slug, owner: u.email, url: `${host}/s/${slug}`, title: body.title ?? null, createdAt: iso(now()),
    expiresAt: hours === null ? null : iso(new Date(Date.now() + hours * 3600e3)), maxDownloads: body.maxDownloads ?? null,
    downloads: 0, views: 0, passwordHash, customDomain: body.customDomain ?? null, revoked: false, files,
  };
  state.links.set(l.id, l);
  u.linksUsed += 1;
  send(res, 201, linkJSON(l));
});

function ownedLink(req, res, params) {
  const u = authenticate(req, res); if (!u) return null;
  const l = state.links.get(params.linkId);
  if (!l || l.owner !== u.email) { sendError(res, 404, 'not_found', 'That link doesn’t exist.'); return null; }
  return l;
}

route('GET', '/v1/links/:linkId', (req, res, { params }) => { const l = ownedLink(req, res, params); if (l) send(res, 200, linkJSON(l)); });
route('DELETE', '/v1/links/:linkId', (req, res, { params }) => { const l = ownedLink(req, res, params); if (!l) return; l.revoked = true; send(res, 204); });
route('GET', '/v1/links/:linkId/stats', (req, res, { params }) => {
  const l = ownedLink(req, res, params); if (!l) return;
  send(res, 200, { linkId: l.id, views: l.views, downloads: l.downloads, lastDownloadAt: l.lastDownloadAt ?? null, byDay: [] });
});

// public landing page (not used by the app; keeps links clickable in manual testing)
route('GET', '/s/:slug', (req, res, { params }) => {
  const l = [...state.links.values()].find((x) => x.slug === params.slug);
  if (!l || l.revoked) { res.writeHead(404, { 'Content-Type': 'text/html' }); res.end('<p>This link is gone.</p>'); return; }
  l.views += 1;
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><title>Shared files</title><ul>${l.files.map((f) => `<li>${f.name.replace(/[<>&]/g, '')} (${f.size} bytes)</li>`).join('')}</ul>`);
});

// jobs
route('POST', '/v1/jobs', async (req, res) => {
  const u = authenticate(req, res); if (!u) return;
  const body = await readJSON(req, res); if (!body) return;
  const op = body.operation ?? {};
  let feature;
  if (op.type === 'convert' && typeof op.target === 'string') feature = 'cloudJobs';
  else if (op.type === 'tool' && TOOL_FEATURES[op.tool]) feature = TOOL_FEATURES[op.tool];
  else return sendError(res, 422, 'unsupported_operation', 'This server can’t run that operation.');
  if (!hasFeature(u, feature)) return sendError(res, 403, 'feature_not_in_plan', 'That needs a Pro plan.', { feature });
  const up = state.uploads.get(body.uploadId ?? '');
  if (!up || up.owner !== u.email) return sendError(res, 404, 'not_found', 'The uploaded file is no longer available.');
  if (up.status !== 'complete') return sendError(res, 409, 'upload_incomplete', 'The file hasn’t finished uploading.');
  if (body.clientReference) {
    const existing = [...state.jobs.values()].find((j) => j.owner === u.email && j.clientReference === body.clientReference);
    if (existing) return send(res, 202, jobJSON(existing));
  }
  const j = {
    id: id('job'), owner: u.email, uploadId: up.id, operation: op, clientReference: body.clientReference ?? null,
    status: 'queued', progress: 0, stage: null, polls: 0, createdAt: iso(now()), finishedAt: null, results: [], cancelRequested: false,
  };
  state.jobs.set(j.id, j);
  send(res, 202, jobJSON(j));
});

function ownedJob(req, res, params) {
  const u = authenticate(req, res); if (!u) return null;
  const j = state.jobs.get(params.jobId);
  if (!j || j.owner !== u.email) { sendError(res, 404, 'not_found', 'That job doesn’t exist.'); return null; }
  return j;
}

route('GET', '/v1/jobs/:jobId', (req, res, { params }) => {
  const j = ownedJob(req, res, params); if (!j) return;
  advanceJob(j);
  send(res, 200, jobJSON(j));
});

route('GET', '/v1/jobs/:jobId/events', (req, res, { params }) => {
  const j = ownedJob(req, res, params); if (!j) return;
  res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', Connection: 'keep-alive' });
  const tick = () => {
    advanceJob(j);
    const done = ['succeeded', 'failed', 'cancelled'].includes(j.status);
    res.write(`event: ${done ? 'done' : 'progress'}\ndata: ${JSON.stringify(jobJSON(j))}\n\n`);
    if (done) { clearInterval(timer); res.end(); }
  };
  const timer = setInterval(tick, Math.max(10, state.config.pollAfterMs));
  req.on('close', () => clearInterval(timer));
});

route('POST', '/v1/jobs/:jobId/cancel', (req, res, { params }) => {
  const j = ownedJob(req, res, params); if (!j) return;
  j.cancelRequested = true;
  if (!['succeeded', 'failed', 'cancelled'].includes(j.status)) { j.status = 'cancelled'; j.finishedAt = iso(now()); }
  send(res, 200, jobJSON(j));
});

// files
route('GET', '/v1/files/:fileId', (req, res, { params, query }) => {
  const f = state.files.get(params.fileId);
  if (!f) return sendError(res, 404, 'not_found', 'That file has expired.');
  if (query.get('sig') !== f.sig) {
    const u = authenticate(req, res); if (!u) return;
    if (u.email !== f.owner) return sendError(res, 404, 'not_found', 'That file has expired.');
  }
  res.writeHead(200, {
    'Content-Type': f.contentType ?? 'application/octet-stream', 'Content-Length': f.buf.length,
    Digest: `sha-256=${crypto.createHash('sha256').update(f.buf).digest('base64')}`,
  });
  res.end(f.buf);
});

// sync
function syncUser(req, res) {
  const u = authenticate(req, res); if (!u) return null;
  if (!hasFeature(u, 'sync')) { sendError(res, 403, 'feature_not_in_plan', 'Sync needs a Pro plan.', { feature: 'sync' }); return null; }
  return u;
}
const head = (d) => ({ namespace: d.namespace, version: d.version, updatedAt: d.updatedAt, updatedBy: d.updatedBy, size: d.size });
const full = (d) => ({ ...head(d), data: d.data });

route('GET', '/v1/sync/documents', (req, res) => {
  const u = syncUser(req, res); if (!u) return;
  send(res, 200, { items: [...syncStore(u.email).values()].map(head) });
});

route('GET', '/v1/sync/documents/:namespace', (req, res, { params }) => {
  const u = syncUser(req, res); if (!u) return;
  if (!NAMESPACE.test(params.namespace)) return sendError(res, 422, 'validation_failed', 'Invalid namespace.');
  const d = syncStore(u.email).get(params.namespace);
  if (!d) return sendError(res, 404, 'not_found', 'No document yet.');
  if (parseVersionTag(req.headers['if-none-match']) === d.version) { res.writeHead(304, { ETag: `"${d.version}"` }); res.end(); return; }
  send(res, 200, full(d), { ETag: `"${d.version}"` });
});

route('PUT', '/v1/sync/documents/:namespace', async (req, res, { params }) => {
  const u = syncUser(req, res); if (!u) { req.resume(); return; }
  if (!NAMESPACE.test(params.namespace)) return sendError(res, 422, 'validation_failed', 'Invalid namespace.');
  const body = await readJSON(req, res, 256 * 1024); if (!body) return;
  if (!('data' in body)) return sendError(res, 422, 'validation_failed', 'Missing data.', { fields: ['data'] });
  const store = syncStore(u.email);
  const current = store.get(params.namespace) ?? null;
  const ifMatch = req.headers['if-match'];
  const ifNone = req.headers['if-none-match'];
  if (!ifMatch && ifNone !== '*') return sendError(res, 428, 'precondition_required', 'Send If-Match or If-None-Match.');
  const conflict = () => sendError(res, 409, 'version_conflict', 'This changed somewhere else first.', null, { current: current ? full(current) : null });
  if (ifNone === '*' && current) return conflict();
  if (ifMatch) {
    const v = parseVersionTag(ifMatch);
    if (!current || v !== current.version) return conflict();
  }
  const size = Buffer.byteLength(JSON.stringify(body.data));
  const doc = { namespace: params.namespace, version: (current?.version ?? 0) + 1, updatedAt: iso(now()), updatedBy: body.deviceName ?? null, size, data: body.data };
  store.set(params.namespace, doc);
  send(res, current ? 200 : 201, full(doc), { ETag: `"${doc.version}"` });
});

route('DELETE', '/v1/sync/documents/:namespace', (req, res, { params }) => {
  const u = syncUser(req, res); if (!u) return;
  const store = syncStore(u.email);
  const current = store.get(params.namespace);
  if (!current) return sendError(res, 404, 'not_found', 'No document.');
  if (parseVersionTag(req.headers['if-match']) !== current.version) return sendError(res, 409, 'version_conflict', 'This changed somewhere else first.', null, { current: full(current) });
  store.delete(params.namespace);
  send(res, 204);
});

// inbox
function inboxUser(req, res) {
  const u = authenticate(req, res); if (!u) return null;
  if (!hasFeature(u, 'inbox')) { sendError(res, 403, 'feature_not_in_plan', 'The inbox needs a Pro plan.', { feature: 'inbox' }); return null; }
  return u;
}

function addInboxItem(email, buf, name, { source = 'phone', note = null, contentType = 'application/octet-stream' } = {}) {
  const f = addFile(buf, name, contentType, email);
  const item = {
    id: id('inb'), name, size: buf.length, sha256: sha256hex(buf), contentType, source, note, status: 'pending',
    createdAt: iso(now()), expiresAt: iso(new Date(Date.now() + 7 * 24 * 3600e3)), downloadUrl: f.url,
  };
  inboxStore(email).push(item);
  return item;
}

route('GET', '/v1/inbox', (req, res, { query }) => {
  const u = inboxUser(req, res); if (!u) return;
  const all = query.get('status') === 'all';
  send(res, 200, { items: inboxStore(u.email).filter((i) => all || i.status === 'pending').map(inboxJSON), nextCursor: null });
});

route('POST', '/v1/inbox', async (req, res) => {
  const u = inboxUser(req, res); if (!u) return;
  const body = await readJSON(req, res); if (!body) return;
  const up = state.uploads.get(body.uploadId ?? '');
  if (!up || up.owner !== u.email || up.status !== 'complete') return sendError(res, 404, 'not_found', 'Upload not found.');
  send(res, 201, inboxJSON(addInboxItem(u.email, up.data, up.filename, { source: 'api', note: body.note ?? null, contentType: up.contentType })));
});

route('POST', '/v1/inbox/:itemId/ack', async (req, res, { params }) => {
  const u = inboxUser(req, res); if (!u) return;
  await readBody(req).catch(() => null);
  const item = inboxStore(u.email).find((i) => i.id === params.itemId);
  if (!item) return sendError(res, 404, 'not_found', 'That item is gone.');
  item.status = 'delivered';
  send(res, 204);
});

route('DELETE', '/v1/inbox/:itemId', (req, res, { params }) => {
  const u = inboxUser(req, res); if (!u) return;
  const list = inboxStore(u.email);
  const i = list.findIndex((x) => x.id === params.itemId);
  if (i < 0) return sendError(res, 404, 'not_found', 'That item is gone.');
  list.splice(i, 1);
  send(res, 204);
});

// ---------------------------------------------------------------- public API
//
// Pay-per-use conversion API: API keys, direct uploads, conversions,
// formats/schema, webhooks, usage, and licence activation for the app.
// Conversions are fake: they finish after `config.conversionMs` and the
// output is the input bytes under the target's extension.

const API_KEY_PREFIX = 'halo_sk_';
const SCOPES = ['convert', 'read'];
const EVENT_TYPES = ['conversion.succeeded', 'conversion.failed'];
const TERMINAL = ['succeeded', 'failed', 'cancelled'];
const SCHEMA_VERSION = 1;

function bearer(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
  return m ? m[1] : null;
}

/// API-key auth for the public API. Returns the user, or sends 401/403 and returns null.
function authenticateKey(req, res, scope) {
  const token = bearer(req);
  if (!token || !token.startsWith(API_KEY_PREFIX)) {
    sendError(res, 401, 'invalid_api_key', 'This endpoint needs an API key: Authorization: Bearer halo_sk_…', null, {}, { 'WWW-Authenticate': 'Bearer realm="halo-api"' });
    return null;
  }
  const k = state.apiKeys.get(token);
  if (!k || k.revokedAt || (k.expiresAt && Date.parse(k.expiresAt) <= Date.now())) {
    sendError(res, 401, 'invalid_api_key', 'That API key is unknown, revoked or expired.', null, {}, { 'WWW-Authenticate': 'Bearer realm="halo-api", error="invalid_token"' });
    return null;
  }
  if (scope && !k.scopes.includes(scope)) {
    sendError(res, 403, 'insufficient_scope', `This API key doesn’t have the “${scope}” scope.`, { scope });
    return null;
  }
  k.lastUsedAt = iso(now());
  return user(k.email);
}

/// Either credential: API keys (with a scope) or the app's OAuth token.
function authenticateAny(req, res, scope) {
  const token = bearer(req);
  if (token && token.startsWith(API_KEY_PREFIX)) return authenticateKey(req, res, scope);
  return authenticate(req, res);
}

function apiKeyJSON(k) {
  return { id: k.id, name: k.name, scopes: [...k.scopes], prefix: k.secret.slice(0, 12), createdAt: k.createdAt, lastUsedAt: k.lastUsedAt, expiresAt: k.expiresAt, revokedAt: k.revokedAt };
}

function createApiKey(email, { name = 'Mock key', scopes = SCOPES, expiresAt = null } = {}) {
  const secret = API_KEY_PREFIX + crypto.randomBytes(24).toString('base64url');
  const k = { id: id('key'), secret, email, name, scopes: [...scopes], createdAt: iso(now()), lastUsedAt: null, expiresAt, revokedAt: null };
  state.apiKeys.set(secret, k);
  return { apiKey: apiKeyJSON(k), secret };
}

// ------------------------------------------------ registry (formats + schemas)
// A server-side copy of the app's registry: a subset of Sources/Shared/Options.swift
// (StandardSchemas) and the capability routes, in the `halo schema --json` shape.

const slider = (id, label, min, max, def, unit = null) => ({ id, label, kind: 'slider', default: def, min, max, step: 1, unit, help: null });
const integer = (id, label, min, max, def, unit = null, help = null) => ({ id, label, kind: 'integer', default: def, min, max, unit, help });
const toggle = (id, label, def) => ({ id, label, kind: 'toggle', default: def, help: null });
const choice = (id, label, choices, def) => ({ id, label, kind: 'choice', default: def, choices: choices.map(([cid, clabel]) => ({ id: cid, label: clabel })), help: null });
const color = (id, label, def) => ({ id, label, kind: 'color', default: def, help: null });
const pageRange = (id, label, def, help) => ({ id, label, kind: 'pageRange', default: def, help });

const MAX_DIM = integer('maxDimension', 'Max size', 0, 32768, 0, 'px', 'Longest edge in pixels. 0 keeps the original size.');
const QUALITY = slider('quality', 'Quality', 1, 100, 85, '%');
const CHANNELS = choice('channels', 'Channels', [['keep', 'Keep'], ['mono', 'Mono'], ['stereo', 'Stereo']], 'keep');

const OPTION_SCHEMAS = [
  { id: 'none', options: [] },
  { id: 'image.lossy', options: [QUALITY, MAX_DIM] },
  { id: 'image.webp', options: [QUALITY, toggle('lossless', 'Lossless', false), MAX_DIM] },
  { id: 'image.lossless', options: [MAX_DIM] },
  { id: 'image.opaque', options: [QUALITY, color('background', 'Background for transparency', '#FFFFFF'), MAX_DIM] },
  { id: 'image.opaque.lossless', options: [color('background', 'Background for transparency', '#FFFFFF'), MAX_DIM] },
  { id: 'pdf.render', options: [
    choice('dpi', 'Resolution', [['72', '72 DPI'], ['150', '150 DPI'], ['300', '300 DPI'], ['600', '600 DPI']], '300'),
    pageRange('pages', 'Pages', '', 'Leave empty for all pages, or e.g. 1-3,5'),
    slider('quality', 'Quality', 1, 100, 90, '%'),
  ] },
  { id: 'to.pdf', options: [choice('pageSize', 'Page size', [['fit', 'Fit content'], ['a4', 'A4'], ['letter', 'US Letter']], 'fit')] },
  { id: 'audio.lossy', options: [
    choice('bitrate', 'Bitrate', [['96', '96 kbps'], ['128', '128 kbps'], ['192', '192 kbps'], ['256', '256 kbps'], ['320', '320 kbps']], '256'),
    choice('sampleRate', 'Sample rate', [['0', 'Keep'], ['44100', '44.1 kHz'], ['48000', '48 kHz']], '0'),
    CHANNELS,
  ] },
  { id: 'audio.lossless', options: [
    choice('sampleRate', 'Sample rate', [['0', 'Keep'], ['44100', '44.1 kHz'], ['48000', '48 kHz'], ['96000', '96 kHz']], '0'),
    choice('bitDepth', 'Bit depth', [['keep', 'Keep'], ['16', '16-bit'], ['24', '24-bit']], 'keep'),
    CHANNELS,
  ] },
  { id: 'video', options: [
    choice('videoQuality', 'Quality', [['high', 'High'], ['balanced', 'Balanced'], ['small', 'Small file']], 'balanced'),
    choice('resolution', 'Resolution', [['0', 'Keep'], ['2160', '4K'], ['1080', '1080p'], ['720', '720p'], ['480', '480p']], '0'),
    choice('fps', 'Frame rate', [['0', 'Keep'], ['60', '60 fps'], ['30', '30 fps'], ['24', '24 fps']], '0'),
    toggle('hardware', 'Use hardware encoder when faster', true),
    choice('audio', 'Audio', [['keep', 'Keep'], ['remove', 'Remove']], 'keep'),
  ] },
  { id: 'gif', options: [
    choice('gifWidth', 'Width', [['0', 'Keep'], ['960', '960 px'], ['640', '640 px'], ['480', '480 px'], ['320', '320 px']], '640'),
    choice('fps', 'Frame rate', [['10', '10 fps'], ['15', '15 fps'], ['24', '24 fps'], ['30', '30 fps']], '15'),
  ] },
  { id: 'archive', options: [slider('compression', 'Compression', 0, 9, 6)] },
  { id: 'subtitle.txt', options: [toggle('timestamps', 'Include timestamps', false)] },
  { id: 'tool.transcribe', options: [
    choice('format', 'Format', [['srt', 'SRT'], ['vtt', 'WebVTT'], ['txt', 'Plain text']], 'srt'),
    choice('language', 'Language', [['auto', 'Detect automatically'], ['en', 'English'], ['es', 'Español'], ['fr', 'Français'], ['de', 'Deutsch'], ['ja', '日本語']], 'auto'),
  ] },
  { id: 'tool.upscale', options: [choice('scale', 'Scale', [['2', '2×'], ['4', '4×']], '2')] },
];
const OPTION_SCHEMA_BY_ID = new Map(OPTION_SCHEMAS.map((o) => [o.id, o]));

const FORMATS = [
  ['png', 'image', 'PNG image', ['png'], ['image/png']],
  ['jpg', 'image', 'JPEG image', ['jpg', 'jpeg'], ['image/jpeg']],
  ['webp', 'image', 'WebP image', ['webp'], ['image/webp']],
  ['heic', 'image', 'HEIC image', ['heic', 'heif'], ['image/heic']],
  ['gif', 'image', 'GIF image', ['gif'], ['image/gif']],
  ['pdf', 'document', 'PDF document', ['pdf'], ['application/pdf']],
  ['mp4', 'video', 'MP4 video', ['mp4', 'm4v'], ['video/mp4']],
  ['mov', 'video', 'QuickTime movie', ['mov'], ['video/quicktime']],
  ['webm', 'video', 'WebM video', ['webm'], ['video/webm']],
  ['mp3', 'audio', 'MP3 audio', ['mp3'], ['audio/mpeg']],
  ['m4a', 'audio', 'AAC audio (M4A)', ['m4a'], ['audio/mp4']],
  ['wav', 'audio', 'WAV audio', ['wav'], ['audio/wav']],
  ['flac', 'audio', 'FLAC audio', ['flac'], ['audio/flac']],
  ['srt', 'subtitle', 'SubRip subtitles', ['srt'], ['application/x-subrip']],
  ['vtt', 'subtitle', 'WebVTT subtitles', ['vtt'], ['text/vtt']],
  ['txt', 'document', 'Plain text', ['txt'], ['text/plain']],
].map(([fid, kind, label, extensions, mimeTypes]) => ({ id: fid, kind, label, extensions, mimeTypes }));
const FORMAT_BY_ID = new Map(FORMATS.map((f) => [f.id, f]));

const IMAGE_TARGET_SCHEMA = { png: 'image.lossless', jpg: 'image.opaque', webp: 'image.webp', heic: 'image.lossy', gif: 'image.lossless', pdf: 'to.pdf' };
const AUDIO_TARGET_SCHEMA = { mp3: 'audio.lossy', m4a: 'audio.lossy', wav: 'audio.lossless', flac: 'audio.lossless' };

/// Routes out of one input format: [{ id, hops, via, optionsSchema }].
function targetsFor(input) {
  const t = (tid, optionsSchema, via = []) => ({ id: tid, hops: via.length + 1, via, optionsSchema });
  const f = FORMAT_BY_ID.get(input);
  if (!f) return [];
  if (f.kind === 'image') {
    return Object.entries(IMAGE_TARGET_SCHEMA).filter(([tid]) => tid !== input)
      // HEIC goes to PDF through JPEG: the one multi-hop route, so clients see `via`.
      .map(([tid, sch]) => (input === 'heic' && tid === 'pdf' ? t(tid, sch, ['jpg']) : t(tid, sch)));
  }
  if (f.id === 'pdf') return [t('png', 'pdf.render'), t('jpg', 'pdf.render')];
  if (f.kind === 'video') {
    return [...['mp4', 'mov', 'webm'].filter((v) => v !== input).map((v) => t(v, 'video')), t('gif', 'gif'),
      ...Object.entries(AUDIO_TARGET_SCHEMA).map(([a, sch]) => t(a, sch))];
  }
  if (f.kind === 'audio') return Object.entries(AUDIO_TARGET_SCHEMA).filter(([a]) => a !== input).map(([a, sch]) => t(a, sch));
  if (f.id === 'srt') return [t('vtt', 'none'), t('txt', 'subtitle.txt')];
  if (f.id === 'vtt') return [t('srt', 'none'), t('txt', 'subtitle.txt')];
  return [];
}

const formatInfo = (f) => ({ ...f, extensions: [...f.extensions], mimeTypes: [...f.mimeTypes], targets: targetsFor(f.id) });

function registry() {
  const images = FORMATS.filter((f) => f.kind === 'image').map((f) => f.id);
  const media = FORMATS.filter((f) => f.kind === 'video' || f.kind === 'audio').map((f) => f.id);
  return {
    schemaVersion: SCHEMA_VERSION,
    generator: 'halo-mock 1',
    formats: FORMATS.map(formatInfo),
    optionSchemas: OPTION_SCHEMAS,
    tools: [
      { id: 'cloud.transcribe', label: 'Transcribe', inputs: media, optionsSchema: 'tool.transcribe', cloud: true },
      { id: 'cloud.upscale', label: 'Upscale', inputs: images, optionsSchema: 'tool.upscale', cloud: true },
      { id: 'cloud.removeBackgroundHQ', label: 'Remove background (HQ)', inputs: images, optionsSchema: 'none', cloud: true },
    ],
    presets: [
      { id: 'web-image', label: 'Web image', target: 'webp', options: { quality: 80, maxDimension: 2048 } },
      { id: 'small-video', label: 'Small video', target: 'mp4', options: { videoQuality: 'small', resolution: '720' } },
    ],
  };
}

function detectFormat(name, contentType) {
  const ext = (name ?? '').toLowerCase().match(/\.([a-z0-9]+)$/)?.[1];
  const byExt = ext && FORMATS.find((f) => f.extensions.includes(ext));
  if (byExt) return byExt.id;
  const byMime = contentType && FORMATS.find((f) => f.mimeTypes.includes(contentType.split(';')[0].trim()));
  return byMime?.id ?? null;
}

/// Validates option values against an option schema. Returns { values, problems }.
function validateOptions(schemaId, options) {
  const schema = OPTION_SCHEMA_BY_ID.get(schemaId) ?? { id: 'none', options: [] };
  const problems = [];
  const values = {};
  for (const spec of schema.options) values[spec.id] = spec.default;
  if (options == null) return { values, problems };
  if (typeof options !== 'object' || Array.isArray(options)) return { values, problems: [{ field: 'options', reason: 'not_an_object' }] };
  for (const [key, v] of Object.entries(options)) {
    const spec = schema.options.find((o) => o.id === key);
    const field = `options.${key}`;
    if (!spec) { problems.push({ field, reason: 'unknown_option', schema: schema.id }); continue; }
    const bad = (reason, extra = {}) => problems.push({ field, reason, ...extra });
    switch (spec.kind) {
      case 'slider': case 'integer': case 'fileSize':
        if (!Number.isInteger(v)) { bad('expected_integer'); break; }
        if ((spec.min != null && v < spec.min) || (spec.max != null && v > spec.max)) { bad('out_of_range', { min: spec.min, max: spec.max }); break; }
        values[key] = v; break;
      case 'decimal':
        if (typeof v !== 'number' || !Number.isFinite(v)) { bad('expected_number'); break; }
        if (v < spec.min || v > spec.max) { bad('out_of_range', { min: spec.min, max: spec.max }); break; }
        values[key] = v; break;
      case 'toggle':
        if (typeof v !== 'boolean') { bad('expected_boolean'); break; }
        values[key] = v; break;
      case 'choice': {
        const s = typeof v === 'number' ? String(v) : v;
        if (typeof s !== 'string' || !spec.choices.some((c) => c.id === s)) { bad('not_a_choice', { choices: spec.choices.map((c) => c.id) }); break; }
        values[key] = s; break;
      }
      case 'color':
        if (typeof v !== 'string' || !/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v)) { bad('expected_color'); break; }
        values[key] = v; break;
      case 'pageRange':
        if (typeof v !== 'string' || !/^(|\d+(-\d+)?(,\d+(-\d+)?)*)$/.test(v)) { bad('expected_page_range'); break; }
        values[key] = v; break;
      default:
        if (typeof v !== 'string') { bad('expected_string'); break; }
        values[key] = v;
    }
  }
  return { values, problems };
}

// ------------------------------------------------ files

/// Stores bytes as a file (owner = account email) and returns the record.
function storeFile(buf, name, contentType, owner) {
  const { fileId } = addFile(buf, name, contentType, owner);
  const f = state.files.get(fileId);
  Object.assign(f, { id: fileId, sha256: sha256hex(buf), format: detectFormat(name, contentType), createdAt: iso(now()), expiresAt: iso(new Date(Date.now() + 24 * 3600e3)) });
  return f;
}

const fileJSON = (f) => ({ id: f.id, name: f.name, size: f.buf.length, sha256: f.sha256, contentType: f.contentType, format: f.format, createdAt: f.createdAt, expiresAt: f.expiresAt });

route('POST', '/v1/files', async (req, res, { query }) => {
  const u = authenticateKey(req, res, 'convert'); if (!u) { req.resume(); return; }
  const filename = query.get('filename');
  if (!filename || filename.length > 255) { req.resume(); return sendError(res, 422, 'validation_failed', 'Add ?filename= with the file’s name.', { fields: ['filename'] }); }
  const max = state.config.directUploadMaxBytes;
  const declared = Number(req.headers['content-length'] ?? NaN);
  if (declared > max) { req.resume(); return sendError(res, 413, 'payload_too_large', 'Direct uploads are limited to 100 MB. Use /v1/uploads for bigger files.', { maxBytes: max }); }
  let buf;
  try { buf = await readBody(req, max); } catch (e) {
    if (e.status === 413) return sendError(res, 413, 'payload_too_large', 'Direct uploads are limited to 100 MB. Use /v1/uploads for bigger files.', { maxBytes: max });
    throw e;
  }
  const f = storeFile(buf, filename, req.headers['content-type'] ?? 'application/octet-stream', u.email);
  send(res, 201, fileJSON(f), { Location: `/v1/files/${f.id}/content` });
});

route('GET', '/v1/files/:fileId/content', (req, res, { params }) => {
  const u = authenticateKey(req, res, 'read'); if (!u) return;
  const f = state.files.get(params.fileId);
  if (!f || f.owner !== u.email) return sendError(res, 404, 'not_found', 'That file doesn’t exist or has expired.');
  const size = f.buf.length;
  const common = {
    'Accept-Ranges': 'bytes', 'Content-Type': f.contentType ?? 'application/octet-stream',
    'Content-Disposition': `attachment; filename="${String(f.name).replace(/["\\\r\n]/g, '_')}"`, 'X-Content-Type-Options': 'nosniff',
  };
  const range = req.headers.range;
  if (range) {
    const m = /^bytes=(\d*)-(\d*)$/.exec(range.trim());
    let start; let end;
    if (m && (m[1] !== '' || m[2] !== '')) {
      if (m[1] === '') { const n = Number(m[2]); start = Math.max(0, size - n); end = size - 1; if (n === 0) start = size; }
      else { start = Number(m[1]); end = m[2] === '' ? size - 1 : Math.min(Number(m[2]), size - 1); }
    }
    if (start === undefined || start >= size || end < start) {
      return sendError(res, 416, 'range_not_satisfiable', 'That byte range is outside the file.', { size }, {}, { 'Content-Range': `bytes */${size}` });
    }
    const part = f.buf.subarray(start, end + 1);
    res.writeHead(206, { ...common, 'Content-Range': `bytes ${start}-${end}/${size}`, 'Content-Length': part.length });
    return res.end(part);
  }
  res.writeHead(200, { ...common, 'Content-Length': size, Digest: `sha-256=${crypto.createHash('sha256').update(f.buf).digest('base64')}` });
  res.end(f.buf);
});

// ------------------------------------------------ API keys (app sign-in only)

route('GET', '/v1/api-keys', (req, res) => {
  const u = authenticate(req, res); if (!u) return;
  const items = [...state.apiKeys.values()].filter((k) => k.email === u.email).reverse().map(apiKeyJSON);
  send(res, 200, { items });
});

route('POST', '/v1/api-keys', async (req, res) => {
  const u = authenticate(req, res); if (!u) { req.resume(); return; }
  const body = await readJSON(req, res); if (!body) return;
  const fields = [];
  if (typeof body.name !== 'string' || !body.name.trim() || body.name.length > 100) fields.push('name');
  if (!Array.isArray(body.scopes) || body.scopes.length === 0 || body.scopes.some((s) => !SCOPES.includes(s)) || new Set(body.scopes).size !== body.scopes.length) fields.push('scopes');
  if (body.expiresAt != null && (typeof body.expiresAt !== 'string' || Number.isNaN(Date.parse(body.expiresAt)) || Date.parse(body.expiresAt) <= Date.now())) fields.push('expiresAt');
  if (fields.length) return sendError(res, 422, 'validation_failed', 'Give the key a name and at least one scope (convert, read).', { fields });
  send(res, 201, createApiKey(u.email, { name: body.name, scopes: body.scopes, expiresAt: body.expiresAt ?? null }));
});

route('DELETE', '/v1/api-keys/:apiKeyId', (req, res, { params }) => {
  const u = authenticate(req, res); if (!u) return;
  const k = [...state.apiKeys.values()].find((x) => x.id === params.apiKeyId && x.email === u.email);
  if (!k) return sendError(res, 404, 'not_found', 'That API key doesn’t exist.');
  k.revokedAt ??= iso(now());
  send(res, 204);
});

// ------------------------------------------------ conversions

const AV = new Set(['video', 'audio']);

function conversionJSON(c) {
  let progress = c.progress;
  if (c.status === 'running') progress = Math.min(0.99, Math.max(0.01, (Date.now() - c.createdMs) / state.config.conversionMs));
  return {
    id: c.id, status: c.status, progress, input: { ...c.input }, target: c.target, options: { ...c.options }, optionsSchema: c.optionsSchema,
    hops: c.hops, output: c.outputId ? fileJSON(state.files.get(c.outputId)) : null, error: c.error, usage: { ...c.usage },
    webhook: c.webhook, metadata: { ...c.metadata }, pollAfterMs: Math.max(10, Math.floor(state.config.conversionMs / 4)),
    createdAt: c.createdAt, startedAt: c.startedAt, finishedAt: c.finishedAt,
  };
}

function stableStringify(v) {
  if (Array.isArray(v)) return `[${v.map(stableStringify).join(',')}]`;
  if (v && typeof v === 'object') return `{${Object.keys(v).sort().map((k) => `${JSON.stringify(k)}:${stableStringify(v[k])}`).join(',')}}`;
  return JSON.stringify(v ?? null);
}

const fakeMinutes = (bytes) => Math.ceil((bytes / MiB) * 100) / 100;

function finishConversion(c) {
  if (TERMINAL.includes(c.status)) return;
  c.finishedAt = iso(now());
  if (c.fail) {
    c.status = 'failed'; c.progress = 1;
    c.error = { code: 'conversion_failed', message: 'The converter couldn’t read this file.' };
    c.usage.billable = false;
  } else {
    const out = storeFile(c.inputBuf, `${stem(c.input.name ?? 'file')}.${c.target}`, FORMAT_BY_ID.get(c.target)?.mimeTypes[0] ?? 'application/octet-stream', c.owner);
    c.outputId = out.id; c.status = 'succeeded'; c.progress = 1;
    c.usage.outputBytes = out.buf.length;
    c.usage.billable = true;
  }
  c.inputBuf = null;
  emitEvent(c, c.status === 'succeeded' ? 'conversion.succeeded' : 'conversion.failed');
}

async function fetchInput(url) {
  let parsed;
  try { parsed = new URL(url); } catch { return { error: 'That input URL isn’t valid.' }; }
  if (!['http:', 'https:'].includes(parsed.protocol)) return { error: 'Input URLs must be http(s).' };
  try {
    const r = await fetch(parsed, { signal: AbortSignal.timeout(5000), redirect: 'follow' });
    if (!r.ok) return { error: `Fetching the input URL returned HTTP ${r.status}.` };
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > state.config.directUploadMaxBytes) return { error: 'The input URL is larger than 100 MB.' };
    const name = decodeURIComponent(parsed.pathname.split('/').pop() || 'download');
    return { buf, name, contentType: r.headers.get('content-type') };
  } catch (e) {
    return { error: `Couldn’t fetch the input URL (${e.name}).` };
  }
}

route('POST', '/v1/conversions', async (req, res) => {
  const u = authenticateKey(req, res, 'convert'); if (!u) { req.resume(); return; }
  const body = await readJSON(req, res); if (!body) return;
  const idemKey = req.headers['idempotency-key'];
  const idemSlot = idemKey ? `${u.email}\n${idemKey}` : null;
  const hash = sha256hex(stableStringify(body));
  if (idemKey != null && (idemKey.length < 1 || idemKey.length > 255)) return sendError(res, 422, 'validation_failed', 'Idempotency-Key must be 1–255 characters.', { fields: ['Idempotency-Key'] });
  if (idemSlot && state.idempotency.has(idemSlot)) {
    const prior = state.idempotency.get(idemSlot);
    if (prior.hash !== hash) return sendError(res, 409, 'idempotency_conflict', 'This Idempotency-Key was already used with a different request.');
    return send(res, 200, conversionJSON(state.conversions.get(prior.conversionId)), { 'Idempotent-Replayed': 'true' });
  }

  const fields = [];
  const input = body.input;
  const hasFile = input && typeof input.fileId === 'string';
  const hasUrl = input && typeof input.url === 'string';
  if (!input || typeof input !== 'object' || hasFile === hasUrl) fields.push('input');
  if (typeof body.target !== 'string' || !body.target) fields.push('target');
  if (body.webhook != null && typeof body.webhook !== 'string') fields.push('webhook');
  if (body.metadata != null) {
    const m = body.metadata;
    if (typeof m !== 'object' || Array.isArray(m) || Object.keys(m).length > 20 || Object.entries(m).some(([k, v]) => k.length > 40 || typeof v !== 'string' || v.length > 500)) fields.push('metadata');
  }
  if (fields.length) return sendError(res, 422, 'validation_failed', 'The conversion request is missing or has invalid fields.', { fields });

  let webhook = null;
  if (body.webhook != null) {
    const ep = [...state.webhooks.values()].find((w) => w.owner === u.email && w.url === body.webhook);
    if (!ep) return sendError(res, 422, 'validation_failed', 'Register that webhook URL with POST /v1/webhooks first; its secret signs the delivery.', { fields: ['webhook'], reason: 'not_registered' });
    webhook = body.webhook;
  }

  let src;
  if (hasFile) {
    const f = state.files.get(input.fileId);
    if (!f || f.owner !== u.email) return sendError(res, 404, 'not_found', 'That input file doesn’t exist or has expired.');
    src = { buf: f.buf, name: f.name, contentType: f.contentType, fileId: input.fileId, url: null };
  } else {
    const got = await fetchInput(input.url);
    if (got.error) return sendError(res, 422, 'input_unavailable', got.error, { fields: ['input.url'] });
    src = { ...got, fileId: null, url: input.url };
  }
  const inputFormat = typeof input.format === 'string' ? input.format : detectFormat(src.name, src.contentType);
  if (!inputFormat || !FORMAT_BY_ID.has(inputFormat)) return sendError(res, 422, 'unsupported_route', 'Halo can’t tell what format the input is. Pass input.format.', { fields: ['input.format'] });
  const route_ = targetsFor(inputFormat).find((t) => t.id === body.target);
  if (!route_) return sendError(res, 422, 'unsupported_route', `Halo can’t convert ${inputFormat} to ${body.target}.`, { input: inputFormat, target: body.target, targets: targetsFor(inputFormat).map((t) => t.id) });
  const { values, problems } = validateOptions(route_.optionsSchema, body.options);
  if (problems.length) return sendError(res, 422, 'validation_failed', 'Some options aren’t valid for this conversion.', { fields: problems.map((p) => p.field), problems, optionsSchema: route_.optionsSchema });

  const isAV = AV.has(FORMAT_BY_ID.get(inputFormat).kind) || AV.has(FORMAT_BY_ID.get(body.target)?.kind);
  const c = {
    id: id('cnv'), owner: u.email, status: 'queued', progress: 0,
    input: { fileId: src.fileId, url: src.url, format: inputFormat, name: src.name ?? null, size: src.buf.length },
    inputBuf: src.buf, target: body.target, options: values, optionsSchema: route_.optionsSchema, hops: route_.hops,
    outputId: null, error: null, usage: { inputBytes: src.buf.length, outputBytes: 0, mediaMinutes: isAV ? fakeMinutes(src.buf.length) : 0, billable: false },
    webhook, metadata: body.metadata ?? {}, createdAt: iso(now()), createdMs: Date.now(), startedAt: null, finishedAt: null,
    fail: state.config.failConversions || req.headers['x-mock-outcome'] === 'fail', timers: [],
  };
  state.conversions.set(c.id, c);
  if (idemSlot) state.idempotency.set(idemSlot, { hash, conversionId: c.id });
  const ms = state.config.conversionMs;
  c.timers.push(later(Math.floor(ms / 4), () => { if (c.status === 'queued') { c.status = 'running'; c.startedAt = iso(now()); } }));
  c.timers.push(later(ms, () => finishConversion(c)));
  send(res, 202, conversionJSON(c), { Location: `/v1/conversions/${c.id}` });
});

function ownedConversion(req, res, params, scope) {
  const u = authenticateKey(req, res, scope); if (!u) return null;
  const c = state.conversions.get(params.conversionId);
  if (!c || c.owner !== u.email) { sendError(res, 404, 'not_found', 'That conversion doesn’t exist.'); return null; }
  return c;
}

route('GET', '/v1/conversions/:conversionId', (req, res, { params }) => {
  const c = ownedConversion(req, res, params, 'read'); if (!c) return;
  send(res, 200, conversionJSON(c));
});

route('DELETE', '/v1/conversions/:conversionId', (req, res, { params }) => {
  const c = ownedConversion(req, res, params, 'convert'); if (!c) return;
  if (c.status === 'succeeded' || c.status === 'failed') {
    return sendError(res, 409, 'already_finished', `That conversion already ${c.status}.`, { status: c.status });
  }
  if (c.status !== 'cancelled') {
    for (const t of c.timers) { clearTimeout(t); state.timers.delete(t); }
    c.usage.billable = c.startedAt != null;
    c.status = 'cancelled'; c.finishedAt = iso(now()); c.inputBuf = null;
  }
  send(res, 200, conversionJSON(c));
});

route('GET', '/v1/conversions', (req, res, { query }) => {
  const u = authenticateKey(req, res, 'read'); if (!u) return;
  const limit = query.has('limit') ? Number(query.get('limit')) : 50;
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) return sendError(res, 422, 'validation_failed', 'limit must be 1–100.', { fields: ['limit'] });
  const status = query.get('status');
  if (status && !['queued', 'running', ...TERMINAL].includes(status)) return sendError(res, 422, 'validation_failed', 'Unknown status filter.', { fields: ['status'] });
  let all = [...state.conversions.values()].filter((c) => c.owner === u.email).reverse();
  if (status) all = all.filter((c) => c.status === status);
  let start = 0;
  const cursor = query.get('cursor');
  if (cursor) {
    let after;
    try { after = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')).after; } catch { after = null; }
    const i = all.findIndex((c) => c.id === after);
    if (i < 0) return sendError(res, 422, 'validation_failed', 'That cursor isn’t valid (or its conversion is gone).', { fields: ['cursor'] });
    start = i + 1;
  }
  const page = all.slice(start, start + limit);
  const more = start + limit < all.length;
  const nextCursor = more ? Buffer.from(JSON.stringify({ after: page[page.length - 1].id })).toString('base64url') : null;
  send(res, 200, { items: page.map(conversionJSON), nextCursor });
});

// ------------------------------------------------ formats + schema (key optional)

route('GET', '/v1/formats', (req, res, { query }) => {
  const input = query.get('input');
  if (input) {
    const f = FORMAT_BY_ID.get(input);
    if (!f) return sendError(res, 404, 'not_found', `Halo doesn’t know the format “${input}”.`);
    return send(res, 200, { schemaVersion: SCHEMA_VERSION, items: [formatInfo(f)] });
  }
  send(res, 200, { schemaVersion: SCHEMA_VERSION, items: FORMATS.map(formatInfo) });
});

route('GET', '/v1/schema', (req, res) => {
  const etag = `"schema-${SCHEMA_VERSION}-mock1"`;
  if (req.headers['if-none-match'] === etag) { res.writeHead(304, { ETag: etag }); return res.end(); }
  send(res, 200, registry(), { ETag: etag });
});

// ------------------------------------------------ webhooks

const webhookJSON = (w) => ({ id: w.id, url: w.url, events: [...w.events], description: w.description, createdAt: w.createdAt });

function validWebhookURL(s) {
  let u;
  try { u = new URL(s); } catch { return false; }
  if (u.protocol === 'https:') return true;
  return u.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(u.hostname);
}

route('GET', '/v1/webhooks', (req, res) => {
  const u = authenticateKey(req, res, 'read'); if (!u) return;
  send(res, 200, { items: [...state.webhooks.values()].filter((w) => w.owner === u.email).map(webhookJSON) });
});

route('POST', '/v1/webhooks', async (req, res) => {
  const u = authenticateKey(req, res, 'convert'); if (!u) { req.resume(); return; }
  const body = await readJSON(req, res); if (!body) return;
  const fields = [];
  if (typeof body.url !== 'string' || !validWebhookURL(body.url)) fields.push('url');
  if (!Array.isArray(body.events) || body.events.length === 0 || body.events.some((e) => !EVENT_TYPES.includes(e)) || new Set(body.events).size !== body.events.length) fields.push('events');
  if (body.description != null && (typeof body.description !== 'string' || body.description.length > 200)) fields.push('description');
  if (fields.length) return sendError(res, 422, 'validation_failed', 'Webhooks need an https URL and at least one event type.', { fields, eventTypes: EVENT_TYPES });
  const w = { id: id('whk'), owner: u.email, url: body.url, events: body.events, description: body.description ?? null, createdAt: iso(now()), secret: 'whsec_' + crypto.randomBytes(24).toString('base64url') };
  state.webhooks.set(w.id, w);
  send(res, 201, { ...webhookJSON(w), secret: w.secret });
});

route('DELETE', '/v1/webhooks/:webhookId', (req, res, { params }) => {
  const u = authenticateKey(req, res, 'convert'); if (!u) return;
  const w = state.webhooks.get(params.webhookId);
  if (!w || w.owner !== u.email) return sendError(res, 404, 'not_found', 'That webhook doesn’t exist.');
  state.webhooks.delete(w.id);
  send(res, 204);
});

/// `t=<unix>,v1=<hex hmac-sha256(secret, t + "." + body)>`
function signatureHeader(secret, body, t = Math.floor(Date.now() / 1000)) {
  return `t=${t},v1=${crypto.createHmac('sha256', secret).update(`${t}.${body}`).digest('hex')}`;
}

function emitEvent(c, type) {
  const event = { id: id('evt'), type, createdAt: iso(now()), data: { conversion: conversionJSON(c) } };
  const targets = new Map();
  for (const w of state.webhooks.values()) {
    if (w.owner !== c.owner) continue;
    if (w.events.includes(type) || w.url === c.webhook) targets.set(w.url, w);
  }
  for (const w of targets.values()) deliver(w.id, event, 1);
}

async function deliver(webhookId, event, attempt) {
  const w = state.webhooks.get(webhookId);
  if (!w) return; // deleted: pending retries are dropped
  const body = JSON.stringify(event);
  const record = { webhookId, eventId: event.id, type: event.type, url: w.url, attempt, status: null, error: null, at: iso(now()) };
  state.deliveries.push(record);
  const owner = state;
  try {
    const r = await fetch(w.url, {
      method: 'POST', body, signal: AbortSignal.timeout(state.config.webhookTimeoutMs),
      headers: { 'Content-Type': 'application/json', 'User-Agent': 'Halo-Webhooks/1 (mock)', 'Halo-Signature': signatureHeader(w.secret, body), 'Halo-Webhook-Id': w.id, 'Halo-Delivery-Attempt': String(attempt) },
    });
    record.status = r.status;
    await r.arrayBuffer().catch(() => null);
    if (r.ok) return;
  } catch (e) {
    record.error = e.name ?? String(e);
  }
  if (state !== owner) return;
  const delays = state.config.webhookRetryMs;
  if (attempt <= delays.length) later(delays[attempt - 1], () => deliver(webhookId, event, attempt + 1));
}

// ------------------------------------------------ usage

route('GET', '/v1/usage', (req, res, { query }) => {
  const u = authenticateAny(req, res, 'read'); if (!u) return;
  const period = query.get('period');
  const d = now();
  let year = d.getUTCFullYear(); let month = d.getUTCMonth();
  if (period != null) {
    const m = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(period);
    if (!m) return sendError(res, 422, 'validation_failed', 'period must look like 2026-10.', { fields: ['period'] });
    year = Number(m[1]); month = Number(m[2]) - 1;
  }
  const start = new Date(Date.UTC(year, month, 1));
  const end = new Date(Date.UTC(year, month + 1, 1));
  const mine = [...state.conversions.values()].filter((c) => c.owner === u.email && Date.parse(c.createdAt) >= start.getTime() && Date.parse(c.createdAt) < end.getTime());
  const count = (s) => mine.filter((c) => c.status === s).length;
  const billable = mine.filter((c) => c.usage.billable);
  send(res, 200, {
    period: { id: `${year}-${String(month + 1).padStart(2, '0')}`, start: iso(start), end: iso(end) },
    conversions: { total: mine.length, succeeded: count('succeeded'), failed: count('failed'), cancelled: count('cancelled'), billable: billable.length },
    mediaMinutes: Math.round(billable.reduce((a, c) => a + c.usage.mediaMinutes, 0) * 100) / 100,
    bytes: { input: billable.reduce((a, c) => a + c.usage.inputBytes, 0), output: billable.reduce((a, c) => a + c.usage.outputBytes, 0) },
    limits: { conversionsPerMonth: null, mediaMinutesPerMonth: null, maxFileBytes: state.config.directUploadMaxBytes },
  });
});

// ------------------------------------------------ licences (no sign-in: the key is the credential)

const licenceState = (l) => ({
  licence: { id: l.id, plan: l.plan, status: l.status, maxDevices: l.maxDevices, expiresAt: l.expiresAt },
  devices: l.devices.map((d) => ({ ...d })),
});

function licenceBody(body, res) {
  const fields = [];
  if (typeof body.key !== 'string' || body.key.length < 8 || body.key.length > 64) fields.push('key');
  if (typeof body.deviceId !== 'string' || body.deviceId.length < 8 || body.deviceId.length > 128) fields.push('deviceId');
  if (body.deviceName != null && (typeof body.deviceName !== 'string' || body.deviceName.length > 100)) fields.push('deviceName');
  if (fields.length) { sendError(res, 422, 'validation_failed', 'Enter the licence key exactly as it appears in your receipt.', { fields }); return false; }
  return true;
}

route('POST', '/v1/licences/activate', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  if (!licenceBody(body, res)) return;
  const l = state.licences.get(body.key.trim().toUpperCase());
  if (!l) return sendError(res, 404, 'licence_invalid', 'That licence key isn’t valid. Check for typos.');
  if (l.status !== 'active') return sendError(res, 409, 'licence_revoked', 'That licence is no longer active.', { status: l.status });
  if (!l.devices.some((d) => d.deviceId === body.deviceId)) {
    if (l.devices.length >= l.maxDevices) {
      return sendError(res, 409, 'licence_device_limit', `This licence is already active on ${l.maxDevices} Macs. Deactivate one first.`, { maxDevices: l.maxDevices, devices: l.devices });
    }
    l.devices.push({ deviceId: body.deviceId, name: body.deviceName ?? null, activatedAt: iso(now()) });
  }
  send(res, 200, licenceState(l));
});

route('POST', '/v1/licences/:licenceId/deactivate', async (req, res, { params }) => {
  const body = await readJSON(req, res); if (!body) return;
  if (!licenceBody(body, res)) return;
  const l = state.licences.get(body.key.trim().toUpperCase());
  if (!l || l.id !== params.licenceId) return sendError(res, 404, 'licence_invalid', 'That licence key doesn’t match this licence.');
  l.devices = l.devices.filter((d) => d.deviceId !== body.deviceId);
  send(res, 200, licenceState(l));
});

// ---------------------------------------------------------------- test control

const control = [];
const ctl = (method, pattern, handler) => {
  const keys = [];
  const re = new RegExp('^/__mock' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
  control.push({ method, re, keys, handler });
};

ctl('POST', '/reset', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  for (const t of state.timers) clearTimeout(t);
  state = freshState(body.config ?? {});
  send(res, 200, { ok: true });
});
ctl('POST', '/config', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  Object.assign(state.config, body);
  send(res, 200, state.config);
});
ctl('POST', '/users', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const u = user(body.email, body.plan);
  if (Array.isArray(body.customDomains)) u.customDomains = body.customDomains;
  if (Number.isInteger(body.linksUsed)) u.linksUsed = body.linksUsed;
  send(res, 200, { ...u, entitlements: entitlements(u) });
});
ctl('POST', '/faults', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const f = { method: body.method ?? null, pathPrefix: body.pathPrefix ?? null, skip: body.skip ?? 0, times: body.times ?? 1, mode: body.mode ?? 'status', status: body.status, keepBytes: body.keepBytes, retryAfter: body.retryAfter };
  state.faults.push(f);
  send(res, 200, f);
});
ctl('DELETE', '/faults', (req, res) => { state.faults = []; send(res, 204); });
ctl('GET', '/requests', (req, res) => send(res, 200, { items: state.requests }));
ctl('DELETE', '/requests', (req, res) => { state.requests = []; send(res, 204); });
ctl('POST', '/expire-tokens', (req, res) => {
  for (const t of state.access.values()) t.exp = Date.now() - 1000;
  send(res, 200, { expired: state.access.size });
});
ctl('GET', '/auth/latest', (req, res) => send(res, 200, state.lastCode ?? {}));
ctl('POST', '/sync', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const store = syncStore(body.email ?? state.config.nextEmail);
  const current = store.get(body.namespace);
  const doc = { namespace: body.namespace, version: (current?.version ?? 0) + 1, updatedAt: iso(now()), updatedBy: body.deviceName ?? 'Other Mac', size: 0, data: body.data };
  doc.size = Buffer.byteLength(JSON.stringify(doc.data));
  store.set(body.namespace, doc);
  send(res, 200, full(doc));
});
ctl('GET', '/sync', (req, res, { query }) => {
  const store = syncStore(query.get('email') ?? state.config.nextEmail);
  send(res, 200, { items: [...store.values()].map(full) });
});
ctl('POST', '/inbox', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const buf = body.contentBase64 != null ? Buffer.from(body.contentBase64, 'base64') : Buffer.from(body.content ?? '', 'utf8');
  const item = addInboxItem(body.email ?? state.config.nextEmail, buf, body.name ?? 'file.bin', { source: body.source ?? 'phone', note: body.note ?? null, contentType: body.contentType });
  send(res, 201, inboxJSON(item));
});
ctl('GET', '/inbox', (req, res, { query }) => send(res, 200, { items: inboxStore(query.get('email') ?? state.config.nextEmail).map(inboxJSON) }));
ctl('GET', '/jobs/:jobId', (req, res, { params }) => {
  const j = state.jobs.get(params.jobId);
  if (!j) return sendError(res, 404, 'not_found', 'no job');
  send(res, 200, { ...jobJSON(j), cancelRequested: j.cancelRequested, polls: j.polls });
});
ctl('GET', '/jobs', (req, res) => send(res, 200, { items: [...state.jobs.values()].map((j) => ({ ...jobJSON(j), cancelRequested: j.cancelRequested, polls: j.polls })) }));
ctl('GET', '/uploads', (req, res) => send(res, 200, { items: [...state.uploads.values()].map((u) => ({ ...uploadJSON(u), putCount: u.putCount })) }));
ctl('GET', '/links', (req, res) => send(res, 200, { items: [...state.links.values()].map((l) => ({ ...linkJSON(l), passwordHash: l.passwordHash ? 'set' : null })) }));
ctl('GET', '/state', (req, res) => send(res, 200, { users: [...state.users.values()], refreshTokens: state.refresh.size, accessTokens: state.access.size, devices: state.devices.size }));

// public API test control
ctl('POST', '/api-keys', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const email = body.email ?? state.config.nextEmail;
  user(email, body.plan);
  send(res, 201, createApiKey(email, { name: body.name ?? 'Mock key', scopes: body.scopes ?? SCOPES, expiresAt: body.expiresAt ?? null }));
});
ctl('GET', '/api-keys', (req, res) => send(res, 200, { items: [...state.apiKeys.values()].map((k) => ({ ...apiKeyJSON(k), email: k.email })) }));
ctl('GET', '/conversions', (req, res) => send(res, 200, { items: [...state.conversions.values()].map((c) => ({ ...conversionJSON(c), owner: c.owner, fail: c.fail })) }));
ctl('GET', '/webhooks/deliveries', (req, res) => send(res, 200, { items: state.deliveries }));
ctl('POST', '/webhooks/sign', async (req, res) => {
  // Signs an arbitrary body the way deliveries are signed (for client tests).
  const body = await readJSON(req, res); if (!body) return;
  send(res, 200, { header: signatureHeader(body.secret, body.body, body.t ?? Math.floor(Date.now() / 1000)) });
});
ctl('POST', '/licences', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
  const key = String(body.key ?? `HALO-${crypto.randomBytes(6).toString('hex').toUpperCase()}`).toUpperCase();
  const l = { id: body.id ?? id('lic'), key, plan: body.plan ?? 'pro', status: body.status ?? 'active', maxDevices: body.maxDevices ?? 2, expiresAt: body.expiresAt ?? null, devices: [] };
  state.licences.set(key, l);
  send(res, 201, { key, ...licenceState(l) });
});
ctl('GET', '/licences', (req, res) => send(res, 200, { items: [...state.licences.values()].map((l) => ({ key: l.key, ...licenceState(l) })) }));

// ---------------------------------------------------------------- server

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://mock.invalid');
  const path = url.pathname;
  res.setHeader('X-Request-Id', id('req'));

  if (path.startsWith('/__mock/')) {
    for (const r of control) {
      const m = r.method === req.method && r.re.exec(path);
      if (!m) continue;
      const params = Object.fromEntries(r.keys.map((k, i) => [k, decodeURIComponent(m[i + 1])]));
      try { await r.handler(req, res, { params, query: url.searchParams }); } catch (e) { send(res, 500, { error: { code: 'internal', message: String(e) } }); }
      return;
    }
    return sendError(res, 404, 'not_found', 'Unknown control endpoint.');
  }

  const entry = {
    method: req.method, path, hasAuth: Boolean(req.headers.authorization), host: req.headers.host ?? '',
    contentRange: req.headers['content-range'] ?? null, ifMatch: req.headers['if-match'] ?? null,
    ifNoneMatch: req.headers['if-none-match'] ?? null, userAgent: req.headers['user-agent'] ?? '', status: 0, at: Date.now(),
    idempotencyKey: req.headers['idempotency-key'] ?? null, range: req.headers.range ?? null,
  };
  state.requests.push(entry);
  res.on('finish', () => { entry.status = res.statusCode; });
  if (path.startsWith('/v1/') && path !== '/v1/health' && !rateHeaders(req, res)) {
    req.resume();
    return sendError(res, 429, 'rate_limited', 'Too many requests. Slow down and try again shortly.', { retryAfter: Number(res.getHeader('Retry-After')) });
  }

  for (const r of routes) {
    if (r.method !== req.method) continue;
    const m = r.re.exec(path);
    if (!m) continue;
    const params = Object.fromEntries(r.keys.map((k, i) => [k, decodeURIComponent(m[i + 1])]));
    const fault = takeFault(req, path);
    if (fault && fault.mode === 'status' && !(req.method === 'PUT' && path.startsWith('/v1/uploads/'))) {
      req.resume();
      return sendError(res, fault.status ?? 503, fault.status === 429 ? 'rate_limited' : 'server_busy', 'The server is busy. Try again shortly.', null, {}, { 'Retry-After': String(fault.retryAfter ?? 0) });
    }
    if (fault && fault.mode === 'reset' && !(req.method === 'PUT' && path.startsWith('/v1/uploads/'))) { req.socket.destroy(); return; }
    try {
      await r.handler(req, res, { params, query: url.searchParams, fault });
    } catch (e) {
      if (!res.headersSent) send(res, 500, { error: { code: 'internal', message: 'Mock server error.', details: { error: String(e?.stack ?? e) } } });
    }
    return;
  }
  sendError(res, 404, 'not_found', 'No such endpoint.');
});

server.keepAliveTimeout = 5000;
server.listen(Number(argv.port), argv.host, () => {
  listenPort = server.address().port;
  process.stdout.write(`LISTENING ${listenPort}\n`);
});

const shutdown = () => server.close(() => process.exit(0));
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
if (argv['watch-stdin']) {
  process.stdin.on('end', () => process.exit(0));
  process.stdin.resume();
}
if (!argv.quiet) process.stderr.write('halo mock server ready\n');
