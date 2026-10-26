// Spawns Tests/Mock/server.mjs on a free port for one test file and offers
// small helpers for its /__mock control endpoints.

import { spawn } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
export const MOCK_SCRIPT = join(here, '..', '..', '..', 'Tests', 'Mock', 'server.mjs');

export async function startMock() {
  const child = spawn(process.execPath, [MOCK_SCRIPT, '--port', '0', '--quiet', '--watch-stdin'], { stdio: ['pipe', 'pipe', 'inherit'] });
  const port = await new Promise((resolve, reject) => {
    let out = '';
    const onData = (d) => {
      out += d;
      const m = /LISTENING (\d+)/.exec(out);
      if (m) { child.stdout.off('data', onData); resolve(Number(m[1])); }
    };
    child.stdout.on('data', onData);
    child.once('exit', (code) => reject(new Error(`mock exited early (${code})`)));
    setTimeout(() => reject(new Error('mock did not start')), 10_000).unref();
  });
  const baseUrl = `http://127.0.0.1:${port}`;

  async function ctl(method, path, body) {
    const res = await fetch(`${baseUrl}/__mock${path}`, {
      method, headers: { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 204) return undefined;
    const json = await res.json();
    if (!res.ok) throw new Error(`control ${method} ${path} → ${res.status} ${JSON.stringify(json)}`);
    return json;
  }

  return {
    baseUrl,
    ctl,
    reset: (config) => ctl('POST', '/reset', config ? { config } : {}),
    config: (c) => ctl('POST', '/config', c),
    /** Creates an API key directly (as if made in the dashboard). */
    apiKey: async (opts = {}) => (await ctl('POST', '/api-keys', opts)).secret,
    fault: (f) => ctl('POST', '/faults', f),
    requests: async () => (await ctl('GET', '/requests')).items,
    clearRequests: () => ctl('DELETE', '/requests'),
    deliveries: async () => (await ctl('GET', '/webhooks/deliveries')).items,
    stop: () => new Promise((resolve) => { child.once('exit', resolve); child.stdin.end(); child.kill('SIGTERM'); }),
  };
}

/** A local HTTP server that records requests; `respond(req, body)` returns [status, body]. */
export async function startReceiver(respond = () => [200, 'ok']) {
  const received = [];
  const waiters = [];
  const server = createServer((req, res) => {
    const parts = [];
    req.on('data', (c) => parts.push(c));
    req.on('end', () => {
      const body = Buffer.concat(parts);
      const entry = { method: req.method, url: req.url, headers: req.headers, body: body.toString('utf8') };
      received.push(entry);
      const [status, text, headers] = respond(entry, received.length);
      res.writeHead(status, headers ?? { 'Content-Type': 'text/plain' });
      res.end(text);
      for (const w of [...waiters]) if (w.pred(received)) { waiters.splice(waiters.indexOf(w), 1); w.resolve(received); }
    });
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${server.address().port}`;
  return {
    url,
    received,
    /** Resolves once `pred(received)` is true (or rejects after `ms`). */
    waitFor: (pred, ms = 5000) => new Promise((resolve, reject) => {
      if (pred(received)) { resolve(received); return; }
      const w = { pred, resolve };
      waiters.push(w);
      setTimeout(() => { const i = waiters.indexOf(w); if (i >= 0) { waiters.splice(i, 1); reject(new Error(`timed out; got ${received.length} requests`)); } }, ms).unref();
    }),
    close: () => new Promise((r) => { server.closeAllConnections?.(); server.close(r); }),
  };
}

/** Signs in through the mock's OAuth + PKCE flow and returns an app access token. */
export async function appAccessToken(baseUrl, email = 'aj@example.com') {
  await fetch(`${baseUrl}/__mock/config`, { method: 'POST', body: JSON.stringify({ nextEmail: email }) });
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  const q = new URLSearchParams({
    response_type: 'code', client_id: 'anyfmt-mac', redirect_uri: 'anyfmt://auth/callback',
    code_challenge: challenge, code_challenge_method: 'S256', state: randomBytes(12).toString('hex'),
  });
  const auth = await fetch(`${baseUrl}/v1/auth/authorize?${q}`, { redirect: 'manual' });
  const code = new URL(auth.headers.get('location')).searchParams.get('code');
  const tok = await fetch(`${baseUrl}/v1/auth/token`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'authorization_code', code, code_verifier: verifier, redirect_uri: 'anyfmt://auth/callback', client_id: 'anyfmt-mac' }),
  });
  return (await tok.json()).access_token;
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
