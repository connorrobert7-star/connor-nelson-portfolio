/**
 * Structured logging to the `logs` table.
 *
 * Used when an outbound call fails, so a bad response can be inspected later
 * without reproducing it. Logging must never be the reason a request fails:
 * every write here is best-effort and swallows its own errors.
 */

import type { SupabaseClient } from './db.ts';

export interface LogEntry {
  source: 'anthropic' | 'instacart' | 'edge-function';
  level?: 'debug' | 'info' | 'warn' | 'error';
  event: string;
  orderId?: string | null;
  recipeId?: string | null;
  httpStatus?: number | null;
  requestBody?: unknown;
  responseBody?: unknown;
  errorMessage?: string | null;
}

export async function writeLog(client: SupabaseClient, entry: LogEntry): Promise<void> {
  try {
    const { error } = await client.from('logs').insert({
      source: entry.source,
      level: entry.level ?? 'error',
      event: entry.event,
      order_id: entry.orderId ?? null,
      recipe_id: entry.recipeId ?? null,
      http_status: entry.httpStatus ?? null,
      request_body: entry.requestBody ?? null,
      response_body: entry.responseBody ?? null,
      error_message: entry.errorMessage ?? null,
    });
    if (error) console.error('Failed to write log row:', error.message);
  } catch (error) {
    console.error('Failed to write log row:', error instanceof Error ? error.message : error);
  }
}
