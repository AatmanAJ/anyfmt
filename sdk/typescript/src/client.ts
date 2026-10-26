import { createHash, randomUUID } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { open, readFile, rename, stat } from 'node:fs/promises';
import { basename } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import {
  AnyfmtConnectionError,
  AnyfmtConversionFailedError,
  AnyfmtError,
  AnyfmtTimeoutError,
  errorFromResponse,
} from './errors.js';
import { verifyWebhook, type VerifyOptions } from './webhooks.js';
import type {
  Conversion,
  ConversionCreate,
  ConversionPage,
  ConversionStatus,
  FormatList,
  AnyfmtSchema,
  StoredFile,
  Upload,
  Usage,
  WebhookCreate,
  WebhookEndpoint,
  WebhookEndpointCreated,
  WebhookEvent,
} from './types.js';

/** Placeholder until the hosted service has a domain (see Server/README.md). Pass `baseUrl`. */
export const DEFAULT_BASE_URL = 'https://cloud.example.invalid';
/** Files above this go through the resumable `/v1/uploads` flow. */
export const DIRECT_UPLOAD_MAX_BYTES = 100 * 1024 * 1024;

export interface AnyfmtOptions {
  /** `anyfmt_sk_…` from `POST /v1/api-keys` (Settings › Account › API keys). */
  apiKey: string;
  /** Server origin, e.g. `https://anyfmt.example.com` or `http://127.0.0.1:8787`. */
  baseUrl?: string;
  /** Retries after 429 / 5xx / connection errors. Default 3. */
  maxRetries?: number;
  /** First backoff step when the server sends no Retry-After. Default 500 ms (doubles each retry). */
  retryBaseMs?: number;
  /** Upper bound for any single wait, including Retry-After. Default 60 000 ms. */
  maxRetryDelayMs?: number;
  /** Extra headers on every request. */
  headers?: Record<string, string>;
  /** Swap in another fetch (tests, proxies). Defaults to the global one (Node 18+). */
  fetch?: typeof fetch;
}

interface RequestOptions {
  query?: Record<string, string | number | undefined | null>;
  json?: unknown;
  body?: Blob | Uint8Array | string;
  headers?: Record<string, string>;
  /** Safe to repeat after a 5xx or a dropped connection (429s are always retried). */
  idempotent?: boolean;
  /** Return non-2xx responses instead of throwing (used by the upload resume loop). */
  allowStatus?: number[];
  signal?: AbortSignal;
}

const sleep = (ms: number, signal?: AbortSignal) => new Promise<void>((resolve, reject) => {
  if (signal?.aborted) { reject(signal.reason); return; }
  const t = setTimeout(() => { signal?.removeEventListener('abort', onAbort); resolve(); }, ms);
  const onAbort = () => { clearTimeout(t); reject(signal?.reason); };
  signal?.addEventListener('abort', onAbort, { once: true });
});

/** Parses Retry-After (delta-seconds or HTTP-date) into ms. */
export function parseRetryAfter(value: string | null, nowMs = Date.now()): number | undefined {
  if (value == null || value.trim() === '') return undefined;
  if (/^\d+$/.test(value.trim())) return Number(value.trim()) * 1000;
  const at = Date.parse(value);
  return Number.isNaN(at) ? undefined : Math.max(0, at - nowMs);
}

const TERMINAL: ConversionStatus[] = ['succeeded', 'failed', 'cancelled'];

/**
 * Client for the anyfmt pay-per-use conversion API.
 *
 * ```ts
 * const anyfmt = new Anyfmt({ apiKey: process.env.ANYFMT_API_KEY!, baseUrl: 'https://anyfmt.example.com' });
 * const file = await anyfmt.files.upload('photo.heic');
 * const c = await anyfmt.conversions.create({ input: { fileId: file.id }, target: 'webp', options: { quality: 80 } });
 * const done = await anyfmt.conversions.wait(c.id, { timeoutMs: 60_000 });
 * await anyfmt.files.download(done.output!.id, 'photo.webp');
 * ```
 */
export class Anyfmt {
  readonly baseUrl: string;
  readonly files: Files;
  readonly conversions: Conversions;
  readonly formats: Formats;
  readonly schema: SchemaApi;
  readonly webhooks: Webhooks;
  readonly usage: UsageApi;

  readonly #apiKey: string;
  readonly #maxRetries: number;
  readonly #retryBaseMs: number;
  readonly #maxRetryDelayMs: number;
  readonly #headers: Record<string, string>;
  readonly #fetch: typeof fetch;

  constructor(options: AnyfmtOptions) {
    if (!options?.apiKey || !options.apiKey.startsWith('anyfmt_sk_')) {
      throw new TypeError('Anyfmt: apiKey must be a anyfmt_sk_… key');
    }
    this.#apiKey = options.apiKey;
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/+$/, '');
    this.#maxRetries = options.maxRetries ?? 3;
    this.#retryBaseMs = options.retryBaseMs ?? 500;
    this.#maxRetryDelayMs = options.maxRetryDelayMs ?? 60_000;
    this.#headers = { ...(options.headers ?? {}) };
    const f = options.fetch ?? globalThis.fetch;
    if (typeof f !== 'function') throw new TypeError('Anyfmt: no fetch available (needs Node 18+)');
    this.#fetch = f;
    this.files = new Files(this);
    this.conversions = new Conversions(this);
    this.formats = new Formats(this);
    this.schema = new SchemaApi(this);
    this.webhooks = new Webhooks(this);
    this.usage = new UsageApi(this);
  }

  /** Never prints the key. */
  toJSON() { return { baseUrl: this.baseUrl }; }

  /** @internal Sends one request with retries; returns the Response (body unread). */
  async request(method: string, path: string, options: RequestOptions = {}): Promise<Response> {
    const url = new URL(this.baseUrl + path);
    for (const [k, v] of Object.entries(options.query ?? {})) if (v != null) url.searchParams.set(k, String(v));
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'User-Agent': 'anyfmt-sdk-js/0.1.0',
      ...this.#headers,
      ...(options.headers ?? {}),
      Authorization: `Bearer ${this.#apiKey}`,
    };
    let body: RequestInit["body"];
    if (options.json !== undefined) {
      body = JSON.stringify(options.json);
      headers['Content-Type'] = 'application/json';
    } else if (options.body !== undefined) {
      body = options.body as RequestInit["body"];
    }

    for (let attempt = 0; ; attempt += 1) {
      const canRetry = attempt < this.#maxRetries;
      let res: Response;
      try {
        res = await this.#fetch(url, { method, headers, body, signal: options.signal, redirect: 'follow' });
      } catch (cause) {
        if (options.signal?.aborted) throw cause;
        if (canRetry && options.idempotent) { await sleep(this.#backoff(attempt), options.signal); continue; }
        throw new AnyfmtConnectionError(`Couldn’t reach ${url.origin}: ${(cause as Error)?.message ?? cause}`, { code: 'connection_failed', cause });
      }
      if (res.ok || res.status === 304 || options.allowStatus?.includes(res.status)) return res;
      const retryAfter = parseRetryAfter(res.headers.get('retry-after'));
      const retryable = res.status === 429 || (res.status >= 500 && options.idempotent === true);
      if (retryable && canRetry) {
        await res.body?.cancel().catch(() => undefined);
        await sleep(Math.min(retryAfter ?? this.#backoff(attempt), this.#maxRetryDelayMs), options.signal);
        continue;
      }
      throw await errorFromResponse(res, retryAfter);
    }
  }

  /** @internal */
  async json<T>(method: string, path: string, options: RequestOptions = {}): Promise<T> {
    const res = await this.request(method, path, options);
    if (res.status === 204) return undefined as T;
    return (await res.json()) as T;
  }

  #backoff(attempt: number): number {
    const base = this.#retryBaseMs * 2 ** attempt;
    return Math.min(this.#maxRetryDelayMs, base + Math.random() * this.#retryBaseMs);
  }
}

// ---------------------------------------------------------------- files

export interface UploadOptions {
  /** Display name; required for a Blob without a name. Defaults to the path's basename. */
  filename?: string;
  contentType?: string;
  /** Force the resumable flow (automatic above 100 MB). */
  resumable?: boolean;
  /** Resumable chunk size; capped by the server's `maxChunkSize`. Default 8 MiB. */
  chunkSize?: number;
  signal?: AbortSignal;
}

export interface DownloadResult { path: string; bytes: number; resumed: boolean }

type Source = { kind: 'path'; path: string; size: number } | { kind: 'blob'; blob: Blob; size: number };

async function sha256Of(src: Source): Promise<string> {
  const h = createHash('sha256');
  if (src.kind === 'path') {
    for await (const chunk of createReadStream(src.path)) h.update(chunk as Buffer);
  } else {
    h.update(new Uint8Array(await src.blob.arrayBuffer()));
  }
  return h.digest('hex');
}

async function readSlice(src: Source, start: number, length: number): Promise<Uint8Array> {
  if (src.kind === 'blob') return new Uint8Array(await src.blob.slice(start, start + length).arrayBuffer());
  const fh = await open(src.path, 'r');
  try {
    const buf = Buffer.alloc(length);
    const { bytesRead } = await fh.read(buf, 0, length, start);
    return buf.subarray(0, bytesRead);
  } finally {
    await fh.close();
  }
}

export class Files {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }

  /**
   * Uploads a file (path or Blob/File) and returns its id for `conversions.create`.
   * ≤ 100 MB goes in one `POST /v1/files`; bigger files (or `resumable: true`)
   * use the chunked `/v1/uploads` flow, which resumes from the server's
   * committed offset after a dropped connection.
   */
  async upload(input: string | Blob, options: UploadOptions = {}): Promise<StoredFile> {
    let src: Source;
    let filename = options.filename;
    let contentType = options.contentType;
    if (typeof input === 'string') {
      const st = await stat(input);
      if (!st.isFile()) throw new TypeError(`files.upload: ${input} is not a file`);
      src = { kind: 'path', path: input, size: st.size };
      filename ??= basename(input);
    } else if (typeof Blob !== 'undefined' && input instanceof Blob) {
      src = { kind: 'blob', blob: input, size: input.size };
      filename ??= (input as Blob & { name?: string }).name || undefined;
      contentType ??= input.type || undefined;
    } else {
      throw new TypeError('files.upload: pass a file path or a Blob');
    }
    if (!filename) throw new TypeError('files.upload: a filename is required for a Blob without a name');

    if (options.resumable || src.size > DIRECT_UPLOAD_MAX_BYTES) {
      return this.#uploadResumable(src, filename, contentType, options);
    }
    const blob = src.kind === 'blob' ? src.blob : new Blob([await readFile(src.path)]);
    return this.#anyfmt.json<StoredFile>('POST', '/v1/files', {
      query: { filename },
      body: blob,
      headers: { 'Content-Type': contentType ?? 'application/octet-stream' },
      idempotent: true,
      signal: options.signal,
    });
  }

  async #uploadResumable(src: Source, filename: string, contentType: string | undefined, options: UploadOptions): Promise<StoredFile> {
    const anyfmt = this.#anyfmt;
    const sha256 = await sha256Of(src);
    const created = await anyfmt.json<Upload>('POST', '/v1/uploads', {
      json: { filename, size: src.size, sha256, contentType: contentType ?? 'application/octet-stream', purpose: 'job' },
      idempotent: false,
      signal: options.signal,
    });
    const chunk = Math.max(1, Math.min(options.chunkSize ?? 8 * 1024 * 1024, created.maxChunkSize));
    let offset = created.offset;
    let stalls = 0;
    const path = `/v1/uploads/${encodeURIComponent(created.id)}`;
    while (offset < src.size) {
      const bytes = await readSlice(src, offset, Math.min(chunk, src.size - offset));
      const last = offset + bytes.length - 1;
      let next: number | undefined;
      try {
        const res = await anyfmt.request('PUT', path, {
          body: bytes,
          headers: { 'Content-Type': 'application/octet-stream', 'Content-Range': `bytes ${offset}-${last}/${src.size}` },
          allowStatus: [409],
          signal: options.signal,
        });
        const header = res.headers.get('upload-offset');
        await res.body?.cancel().catch(() => undefined);
        next = header != null ? Number(header) : undefined;
      } catch (e) {
        if (options.signal?.aborted || !(e instanceof AnyfmtError) || (e.status !== 0 && e.status < 500)) throw e;
        next = undefined;
      }
      if (next === undefined) {
        // Connection dropped or the server hiccuped: ask where it really is.
        const probe = await anyfmt.request('HEAD', path, { idempotent: true, signal: options.signal });
        next = Number(probe.headers.get('upload-offset') ?? offset);
      }
      if (next <= offset) {
        stalls += 1;
        if (stalls > 5) throw new AnyfmtError('Upload made no progress after 5 attempts.', { code: 'upload_stalled' });
      } else {
        stalls = 0;
      }
      offset = next;
    }
    const done = await anyfmt.json<Upload>('POST', `${path}/complete`, { json: { sha256 }, idempotent: true, signal: options.signal });
    if (!done.fileId) throw new AnyfmtError('The server completed the upload but returned no fileId.', { code: 'missing_file_id' });
    return {
      id: done.fileId, name: filename, size: src.size, sha256, contentType: contentType ?? 'application/octet-stream',
      format: null, createdAt: new Date().toISOString(), expiresAt: done.expiresAt,
    };
  }

  /**
   * Streams a file to `dest`. Bytes land in `dest + '.part'` first and are
   * renamed when complete; an existing `.part` is resumed with a Range request.
   */
  async download(fileId: string, dest: string, options: { resume?: boolean; signal?: AbortSignal } = {}): Promise<DownloadResult> {
    const part = `${dest}.part`;
    let have = 0;
    if (options.resume !== false) {
      try { have = (await stat(part)).size; } catch { have = 0; }
    }
    const res = await this.#anyfmt.request('GET', `/v1/files/${encodeURIComponent(fileId)}/content`, {
      headers: { Accept: '*/*', ...(have > 0 ? { Range: `bytes=${have}-` } : {}) },
      idempotent: true,
      allowStatus: have > 0 ? [416] : [],
      signal: options.signal,
    });
    let resumed = false;
    if (res.status === 416) {
      // The .part is already the whole file (or longer than it): start again.
      await res.body?.cancel().catch(() => undefined);
      return this.download(fileId, dest, { ...options, resume: false });
    }
    if (res.status === 206) resumed = true;
    if (!res.body) throw new AnyfmtError('Empty download body.', { status: res.status, code: 'empty_body' });
    await pipeline(Readable.fromWeb(res.body as never), createWriteStream(part, { flags: resumed ? 'a' : 'w' }));
    await rename(part, dest);
    return { path: dest, bytes: (await stat(dest)).size, resumed };
  }

  /** Reads a file (or a byte range of it, inclusive) into memory. */
  async read(fileId: string, range?: { start: number; end?: number }, options: { signal?: AbortSignal } = {}): Promise<Uint8Array> {
    const headers: Record<string, string> = { Accept: '*/*' };
    if (range) headers.Range = `bytes=${range.start}-${range.end ?? ''}`;
    const res = await this.#anyfmt.request('GET', `/v1/files/${encodeURIComponent(fileId)}/content`, { headers, idempotent: true, signal: options.signal });
    return new Uint8Array(await res.arrayBuffer());
  }
}

// ---------------------------------------------------------------- conversions

export interface ListConversionsParams { limit?: number; cursor?: string; status?: ConversionStatus }
export interface WaitOptions {
  /** Give up after this long. Default 10 minutes. */
  timeoutMs?: number;
  /** Poll at least this far apart (the server's `pollAfterMs` wins if larger). Default 0. */
  minPollMs?: number;
  signal?: AbortSignal;
}

export class Conversions {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }

  /**
   * Starts a conversion. An `Idempotency-Key` is always sent (a random UUID
   * unless you pass one), so the SDK's automatic retries can never start the
   * same conversion twice. Pass your own key to make retries across process
   * restarts safe too.
   */
  create(params: ConversionCreate, options: { idempotencyKey?: string; signal?: AbortSignal } = {}): Promise<Conversion> {
    return this.#anyfmt.json<Conversion>('POST', '/v1/conversions', {
      json: params,
      headers: { 'Idempotency-Key': options.idempotencyKey ?? randomUUID() },
      idempotent: true,
      signal: options.signal,
    });
  }

  get(id: string, options: { signal?: AbortSignal } = {}): Promise<Conversion> {
    return this.#anyfmt.json<Conversion>('GET', `/v1/conversions/${encodeURIComponent(id)}`, { idempotent: true, signal: options.signal });
  }

  /** One page, newest first. Pass `nextCursor` back as `cursor` for the next. */
  list(params: ListConversionsParams = {}, options: { signal?: AbortSignal } = {}): Promise<ConversionPage> {
    return this.#anyfmt.json<ConversionPage>('GET', '/v1/conversions', {
      query: { limit: params.limit, cursor: params.cursor, status: params.status },
      idempotent: true,
      signal: options.signal,
    });
  }

  /** Every conversion, following cursors. */
  async *iterate(params: Omit<ListConversionsParams, 'cursor'> = {}): AsyncGenerator<Conversion> {
    let cursor: string | undefined;
    do {
      const page = await this.list({ ...params, cursor });
      yield* page.items;
      cursor = page.nextCursor ?? undefined;
    } while (cursor);
  }

  /** Cancels a queued/running conversion (idempotent). A finished one is a `AnyfmtConflictError` (`already_finished`). */
  cancel(id: string, options: { signal?: AbortSignal } = {}): Promise<Conversion> {
    return this.#anyfmt.json<Conversion>('DELETE', `/v1/conversions/${encodeURIComponent(id)}`, { idempotent: true, signal: options.signal });
  }

  /**
   * Polls until the conversion is terminal. Resolves with it when it
   * succeeded; throws `AnyfmtConversionFailedError` when it failed or was
   * cancelled and `AnyfmtTimeoutError` after `timeoutMs`.
   */
  async wait(idOrConversion: string | Conversion, options: WaitOptions = {}): Promise<Conversion> {
    const id = typeof idOrConversion === 'string' ? idOrConversion : idOrConversion.id;
    const deadline = Date.now() + (options.timeoutMs ?? 600_000);
    let c = typeof idOrConversion === 'string' ? await this.get(id, options) : idOrConversion;
    while (!TERMINAL.includes(c.status)) {
      const left = deadline - Date.now();
      if (left <= 0) {
        throw new AnyfmtTimeoutError(`Conversion ${id} is still ${c.status} after ${options.timeoutMs ?? 600_000} ms.`, { code: 'wait_timeout', details: { status: c.status, progress: c.progress } });
      }
      await sleep(Math.min(left, Math.max(options.minPollMs ?? 0, c.pollAfterMs ?? 1000)), options.signal);
      if (Date.now() >= deadline) continue;
      c = await this.get(id, options);
    }
    if (c.status !== 'succeeded') throw new AnyfmtConversionFailedError(c);
    return c;
  }
}

// ---------------------------------------------------------------- formats, schema, usage

export class Formats {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }
  /** Every input format with its targets and hop counts (or just `input`). */
  list(params: { input?: string } = {}): Promise<FormatList> {
    return this.#anyfmt.json<FormatList>('GET', '/v1/formats', { query: { input: params.input }, idempotent: true });
  }
}

export class SchemaApi {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }
  /** Formats, routes, option schemas, tools and presets (the `anyfmt schema --json` shape). */
  get(): Promise<AnyfmtSchema> {
    return this.#anyfmt.json<AnyfmtSchema>('GET', '/v1/schema', { idempotent: true });
  }
}

export class UsageApi {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }
  /** Usage for `period` (`YYYY-MM`, default: this month). */
  get(params: { period?: string } = {}): Promise<Usage> {
    return this.#anyfmt.json<Usage>('GET', '/v1/usage', { query: { period: params.period }, idempotent: true });
  }
}

// ---------------------------------------------------------------- webhooks

export class Webhooks {
  readonly #anyfmt: Anyfmt;
  constructor(anyfmt: Anyfmt) { this.#anyfmt = anyfmt; }

  /** Registers an endpoint. Store the returned `secret`: it is shown once. Not retried after 5xx (it isn't idempotent). */
  create(params: WebhookCreate): Promise<WebhookEndpointCreated> {
    return this.#anyfmt.json<WebhookEndpointCreated>('POST', '/v1/webhooks', { json: params, idempotent: false });
  }

  async list(): Promise<WebhookEndpoint[]> {
    const r = await this.#anyfmt.json<{ items: WebhookEndpoint[] }>('GET', '/v1/webhooks', { idempotent: true });
    return r.items;
  }

  async delete(id: string): Promise<void> {
    await this.#anyfmt.json<void>('DELETE', `/v1/webhooks/${encodeURIComponent(id)}`, { idempotent: true });
  }

  /** Same as the standalone `verifyWebhook`. */
  verify(body: string | Uint8Array, header: string | null | undefined, secret: string, options?: VerifyOptions): WebhookEvent {
    return verifyWebhook(body, header, secret, options);
  }

  /** Static form, for handlers that don't hold a client. */
  static verify(body: string | Uint8Array, header: string | null | undefined, secret: string, options?: VerifyOptions): WebhookEvent {
    return verifyWebhook(body, header, secret, options);
  }
}
