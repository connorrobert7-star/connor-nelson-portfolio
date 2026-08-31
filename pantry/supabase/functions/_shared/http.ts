/**
 * HTTP helpers for the Edge Functions.
 *
 * One envelope shape for every response so the Expo client has exactly one
 * thing to parse:
 *   success -> { ok: true,  data: ... }
 *   failure -> { ok: false, error: { code, message, details? } }
 */

import { ConfigurationError } from './env.ts';

export const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export type ErrorCode =
  | 'bad_request'
  | 'not_found'
  | 'conflict'
  | 'upstream_error'
  | 'upstream_timeout'
  | 'configuration_error'
  | 'internal_error';

const STATUS_BY_CODE: Record<ErrorCode, number> = {
  bad_request: 400,
  not_found: 404,
  conflict: 409,
  upstream_error: 502,
  upstream_timeout: 504,
  configuration_error: 500,
  internal_error: 500,
};

/** An error with a known HTTP shape. Anything else becomes a 500. */
export class HttpError extends Error {
  override readonly name = 'HttpError';
  readonly code: ErrorCode;
  readonly details: unknown;

  constructor(code: ErrorCode, message: string, details?: unknown) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

export function badRequest(message: string, details?: unknown): HttpError {
  return new HttpError('bad_request', message, details);
}

export function notFound(message: string): HttpError {
  return new HttpError('not_found', message);
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

export function ok<T>(data: T): Response {
  return jsonResponse({ ok: true, data });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return jsonResponse(
      {
        ok: false,
        error: {
          code: error.code,
          message: error.message,
          ...(error.details !== undefined ? { details: error.details } : {}),
        },
      },
      STATUS_BY_CODE[error.code],
    );
  }

  if (error instanceof ConfigurationError) {
    return jsonResponse(
      { ok: false, error: { code: 'configuration_error', message: error.message } },
      500,
    );
  }

  // Deliberately generic: an unexpected error may carry a connection string or
  // a key in its message, and this response goes to a client.
  const message = error instanceof Error ? error.message : String(error);
  console.error('Unhandled error:', message, error instanceof Error ? error.stack : '');
  return jsonResponse(
    { ok: false, error: { code: 'internal_error', message: 'Something went wrong. Check the function logs.' } },
    500,
  );
}

/** Parse and validate the request envelope: POST, JSON body, object. */
export async function readJsonBody(request: Request): Promise<Record<string, unknown>> {
  if (request.method !== 'POST') {
    throw badRequest(`Expected POST, got ${request.method}.`);
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    throw badRequest('Request body is not valid JSON.');
  }

  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw badRequest('Request body must be a JSON object.');
  }
  return raw as Record<string, unknown>;
}

/**
 * Standard wrapper: CORS preflight, error envelope, and a guarantee that no
 * handler can throw a raw stack trace at the client.
 */
export function serveHandler(handler: (request: Request) => Promise<Response>) {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    try {
      return await handler(request);
    } catch (error) {
      return errorResponse(error);
    }
  };
}
