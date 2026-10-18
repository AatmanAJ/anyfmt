import type { Conversion, ErrorCode } from './types.js';

/** Base class for every error the SDK throws. */
export class HaloError extends Error {
  override name = 'HaloError';
  /** HTTP status, or 0 when no response arrived. */
  readonly status: number;
  /** Stable machine code from the error envelope (`error.code`), or an SDK code such as `connection_failed`. */
  readonly code: ErrorCode | (string & {});
  /** `error.requestId` / `X-Request-Id`, for support. */
  readonly requestId: string | undefined;
  /** `error.details` as sent by the server. */
  readonly details: Record<string, unknown> | undefined;

  constructor(message: string, init: { status?: number; code: string; requestId?: string | undefined; details?: Record<string, unknown> | undefined; cause?: unknown }) {
    super(message, init.cause === undefined ? undefined : { cause: init.cause });
    this.status = init.status ?? 0;
    this.code = init.code;
    this.requestId = init.requestId;
    this.details = init.details;
  }
}

/** 401: missing, unknown, revoked or expired API key. */
export class HaloAuthenticationError extends HaloError { override name = 'HaloAuthenticationError'; }
/** 403: the key lacks a scope (`insufficient_scope`) or the account can't do this. */
export class HaloPermissionError extends HaloError { override name = 'HaloPermissionError'; }
/** 404 */
export class HaloNotFoundError extends HaloError { override name = 'HaloNotFoundError'; }
/** 409: `idempotency_conflict`, `already_finished`, … */
export class HaloConflictError extends HaloError { override name = 'HaloConflictError'; }
/** 422: `validation_failed` (see `details.fields`), `unsupported_route`, `input_unavailable`. */
export class HaloValidationError extends HaloError { override name = 'HaloValidationError'; }
/** 429 after the SDK's retries ran out. */
export class HaloRateLimitError extends HaloError {
  override name = 'HaloRateLimitError';
  /** What the server asked for in `Retry-After`, in ms (undefined when absent). */
  retryAfterMs: number | undefined;
}
/** 5xx after the SDK's retries ran out. */
export class HaloServerError extends HaloError { override name = 'HaloServerError'; }
/** No HTTP response (DNS, refused, reset, aborted). */
export class HaloConnectionError extends HaloError { override name = 'HaloConnectionError'; }
/** `conversions.wait` gave up. */
export class HaloTimeoutError extends HaloError { override name = 'HaloTimeoutError'; }

/** `conversions.wait` saw the conversion fail or get cancelled. */
export class HaloConversionFailedError extends HaloError {
  override name = 'HaloConversionFailedError';
  readonly conversion: Conversion;
  constructor(conversion: Conversion) {
    const message = conversion.status === 'cancelled'
      ? `Conversion ${conversion.id} was cancelled.`
      : `Conversion ${conversion.id} failed: ${conversion.error?.message ?? 'unknown error'}`;
    super(message, { status: 0, code: conversion.error?.code ?? (conversion.status === 'cancelled' ? 'cancelled' : 'conversion_failed') });
    this.conversion = conversion;
  }
}

/** `webhooks.verify` rejected a delivery. Answer the request with 400. */
export class HaloWebhookSignatureError extends HaloError {
  override name = 'HaloWebhookSignatureError';
  /** `malformed` (header unparsable), `expired` (outside the tolerance) or `mismatch` (no v1 matched). */
  readonly reason: 'malformed' | 'expired' | 'mismatch';
  constructor(reason: 'malformed' | 'expired' | 'mismatch', message: string) {
    super(message, { status: 0, code: `webhook_signature_${reason}` });
    this.reason = reason;
  }
}

const byStatus: Record<number, typeof HaloError> = {
  401: HaloAuthenticationError,
  403: HaloPermissionError,
  404: HaloNotFoundError,
  409: HaloConflictError,
  413: HaloValidationError,
  416: HaloValidationError,
  422: HaloValidationError,
  429: HaloRateLimitError,
};

/** Builds the typed error for a non-2xx response (reads the body). */
export async function errorFromResponse(res: Response, retryAfterMs?: number): Promise<HaloError> {
  let envelope: { error?: { code?: string; message?: string; requestId?: string; details?: Record<string, unknown> } } | undefined;
  try {
    const text = await res.text();
    envelope = text ? JSON.parse(text) : undefined;
  } catch {
    envelope = undefined;
  }
  const e = envelope?.error;
  const Cls = byStatus[res.status] ?? (res.status >= 500 ? HaloServerError : HaloError);
  const err = new Cls(e?.message ?? `HTTP ${res.status}`, {
    status: res.status,
    code: e?.code ?? `http_${res.status}`,
    requestId: e?.requestId ?? res.headers.get('x-request-id') ?? undefined,
    details: e?.details,
  });
  if (err instanceof HaloRateLimitError) err.retryAfterMs = retryAfterMs;
  return err;
}
