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
// This is test scaffolding, not a server to deploy: no persistence, no
// rate limiting beyond headers, passwords hashed with scrypt only to keep the
// shape honest.

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
});

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
  };
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
  return { id: u.id, filename: u.filename, size: u.size, offset: u.offset, status: u.status, maxChunkSize: state.config.maxChunkSize, sha256: u.sha256, expiresAt: u.expiresAt };
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
  const u = authenticate(req, res); if (!u) return;
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
  const u = authenticate(req, res); if (!u) return null;
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

// ---------------------------------------------------------------- test control

const control = [];
const ctl = (method, pattern, handler) => {
  const keys = [];
  const re = new RegExp('^/__mock' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
  control.push({ method, re, keys, handler });
};

ctl('POST', '/reset', async (req, res) => {
  const body = await readJSON(req, res); if (!body) return;
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
  };
  state.requests.push(entry);
  res.on('finish', () => { entry.status = res.statusCode; });
  if (path.startsWith('/v1/') && path !== '/v1/health') rateHeaders(req, res);

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
