import { createHmac, timingSafeEqual } from 'node:crypto';
import { HaloWebhookSignatureError } from './errors.js';
import type { WebhookEvent } from './types.js';

export interface VerifyOptions {
  /** Largest allowed |now − t| in seconds. Default 300 (5 minutes). */
  toleranceSec?: number;
  /** Override the clock (unix seconds). For tests. */
  nowSec?: number;
}

/** Computes the `v1` signature: hex HMAC-SHA256(secret, `${t}.${body}`). */
export function signWebhookPayload(body: string | Uint8Array, secret: string, t: number): string {
  const mac = createHmac('sha256', secret);
  mac.update(`${t}.`);
  mac.update(typeof body === 'string' ? body : Buffer.from(body.buffer, body.byteOffset, body.byteLength));
  return mac.digest('hex');
}

/** Builds a `Halo-Signature` header value. Useful for testing your webhook handler. */
export function webhookSignatureHeader(body: string | Uint8Array, secret: string, t = Math.floor(Date.now() / 1000)): string {
  return `t=${t},v1=${signWebhookPayload(body, secret, t)}`;
}

/**
 * Verifies a webhook delivery and returns the parsed event.
 *
 * Pass the **raw** request body exactly as received (string or bytes), not a
 * re-serialised object: any change to the bytes breaks the signature.
 * Throws `HaloWebhookSignatureError` (reason `malformed`, `expired` or
 * `mismatch`); answer those requests with 400.
 */
export function verifyWebhook(body: string | Uint8Array, header: string | null | undefined, secret: string, options: VerifyOptions = {}): WebhookEvent {
  const tolerance = options.toleranceSec ?? 300;
  if (!secret) throw new TypeError('verifyWebhook: secret is required');
  if (!header) throw new HaloWebhookSignatureError('malformed', 'Missing Halo-Signature header.');

  let t: number | undefined;
  const signatures: string[] = [];
  for (const part of header.split(',')) {
    const i = part.indexOf('=');
    if (i <= 0) continue;
    const key = part.slice(0, i).trim();
    const value = part.slice(i + 1).trim();
    if (key === 't' && /^\d+$/.test(value)) t = Number(value);
    else if (key === 'v1' && /^[0-9a-f]{64}$/i.test(value)) signatures.push(value.toLowerCase());
  }
  if (t === undefined || signatures.length === 0) {
    throw new HaloWebhookSignatureError('malformed', 'Halo-Signature must look like t=<unix>,v1=<hex>.');
  }
  const now = options.nowSec ?? Math.floor(Date.now() / 1000);
  if (Math.abs(now - t) > tolerance) {
    throw new HaloWebhookSignatureError('expired', `Webhook timestamp is ${Math.abs(now - t)} s away from now (tolerance ${tolerance} s).`);
  }
  const expected = Buffer.from(signWebhookPayload(body, secret, t), 'hex');
  const ok = signatures.some((s) => {
    const got = Buffer.from(s, 'hex');
    return got.length === expected.length && timingSafeEqual(got, expected);
  });
  if (!ok) throw new HaloWebhookSignatureError('mismatch', 'Webhook signature does not match. Check the secret, and pass the raw body.');

  const text = typeof body === 'string' ? body : Buffer.from(body.buffer, body.byteOffset, body.byteLength).toString('utf8');
  try {
    return JSON.parse(text) as WebhookEvent;
  } catch {
    throw new HaloWebhookSignatureError('malformed', 'Webhook body is signed but is not JSON.');
  }
}
