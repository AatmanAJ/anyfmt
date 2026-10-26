import type { Conversion, ErrorCode } from './types.js';

/** Base class for every error the SDK throws. */
export class AnyfmtError extends Error {
  override name = 'AnyfmtError';
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
export class AnyfmtAuthenticationError extends AnyfmtError { override name = 'AnyfmtAuthenticationError'; }
/** 403: the key lacks a scope (`insufficient_scope`) or the account can't do this. */
export class AnyfmtPermissionError extends AnyfmtError { override name = 'AnyfmtPermissionError'; }
/** 404 */
export class AnyfmtNotFoundError extends AnyfmtError { override name = 'AnyfmtNotFoundError'; }
/** 409: `idempotency_conflict`, `already_finished`, … */
export class AnyfmtConflictError extends AnyfmtError { override name = 'AnyfmtConflictError'; }
/** 422: `validation_failed` (see `details.fields`), `unsupported_route`, `input_unavailable`. */
export class AnyfmtValidationError extends AnyfmtError { override name = 'AnyfmtValidationError'; }
/** 429 after the SDK's retries ran out. */
export class AnyfmtRateLimitError extends AnyfmtError {
  override name = 'AnyfmtRateLimitError';
  /** What the server asked for in `Retry-After`, in ms (undefined when absent). */
  retryAfterMs: number | undefined;
}
/** 5xx after the SDK's retries ran out. */
export class AnyfmtServerError extends AnyfmtError { override name = 'AnyfmtServerError'; }
/** No HTTP response (DNS, refused, reset, aborted). */
export class AnyfmtConnectionError extends AnyfmtError { override name = 'AnyfmtConnectionError'; }
/** `conversions.wait` gave up. */
export class AnyfmtTimeoutError extends AnyfmtError { override name = 'AnyfmtTimeoutError'; }

/** `conversions.wait` saw the conversion fail or get cancelled. */
export class AnyfmtConversionFailedError extends AnyfmtError {
  override name = 'AnyfmtConversionFailedError';
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
export class AnyfmtWebhookSignatureError extends AnyfmtError {
  override name = 'AnyfmtWebhookSignatureError';
  /** `malformed` (header unparsable), `expired` (outside the tolerance) or `mismatch` (no v1 matched). */
  readonly reason: 'malformed' | 'expired' | 'mismatch';
  constructor(reason: 'malformed' | 'expired' | 'mismatch', message: string) {
    super(message, { status: 0, code: `webhook_signature_${reason}` });
    this.reason = reason;
  }
}

const byStatus: Record<number, typeof AnyfmtError> = {
  401: AnyfmtAuthenticationError,
  403: AnyfmtPermissionError,
  404: AnyfmtNotFoundError,
  409: AnyfmtConflictError,
  413: AnyfmtValidationError,
  416: AnyfmtValidationError,
  422: AnyfmtValidationError,
  429: AnyfmtRateLimitError,
};

/** Builds the typed error for a non-2xx response (reads the body). */
export async function errorFromResponse(res: Response, retryAfterMs?: number): Promise<AnyfmtError> {
  let envelope: { error?: { code?: string; message?: string; requestId?: string; details?: Record<string, unknown> } } | undefined;
  try {
    const text = await res.text();
    envelope = text ? JSON.parse(text) : undefined;
  } catch {
    envelope = undefined;
  }
  const e = envelope?.error;
  const Cls = byStatus[res.status] ?? (res.status >= 500 ? AnyfmtServerError : AnyfmtError);
  const err = new Cls(e?.message ?? `HTTP ${res.status}`, {
    status: res.status,
    code: e?.code ?? `http_${res.status}`,
    requestId: e?.requestId ?? res.headers.get('x-request-id') ?? undefined,
    details: e?.details,
  });
  if (err instanceof AnyfmtRateLimitError) err.retryAfterMs = retryAfterMs;
  return err;
}
