/**
 * POST /pantry-reconcile
 *
 * Drift correction. The pantry's numbers are estimates built on estimates, and
 * they wander. This is how they get pulled back to reality.
 *
 * Body:
 *   { action: "list" }                         -> what needs checking
 *   { items: [{ id, observed_remaining_canonical }] }  -> record what is there
 *
 * Every correction writes a consumption_events row with reason
 * 'reconciliation', so the audit trail still explains every number.
 */

import { setRemaining } from '../_shared/consumption.ts';
import { serviceClient, type PantryItemRow } from '../_shared/db.ts';
import { badRequest, notFound, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { describeProportion } from '../_shared/humanize.ts';

/** Low-confidence items untouched for this long are worth a second look. */
const STALE_DAYS = 10;

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const client = serviceClient();

  if (body.action === 'list') {
    const cutoff = new Date();
    cutoff.setUTCDate(cutoff.getUTCDate() - STALE_DAYS);

    // The spec's rule: prompt for anything whose quantity was a guess to begin
    // with and that has not been touched in 10+ days. Those are exactly the
    // rows most likely to be wrong by now.
    const { data, error } = await client
      .from('pantry_items')
      .select('*')
      .is('depleted_at', null)
      .eq('quantity_confidence', 'low')
      .lt('updated_at', cutoff.toISOString())
      .order('updated_at', { ascending: true });

    if (error) throw new Error(`Failed to find items needing reconciliation: ${error.message}`);

    return ok({
      action: 'list',
      stale_after_days: STALE_DAYS,
      items: ((data ?? []) as PantryItemRow[]).map((item) => ({
        id: item.id,
        display_name: item.display_name,
        canonical_unit: item.canonical_unit,
        remaining_canonical: Number(item.canonical_quantity_remaining),
        original_canonical: Number(item.canonical_quantity_original),
        proportion: describeProportion(
          Number(item.canonical_quantity_remaining),
          Number(item.canonical_quantity_original),
        ),
        purchase_quantity: item.purchase_quantity,
        purchase_unit: item.purchase_unit,
        last_touched: item.updated_at,
      })),
    });
  }

  if (!Array.isArray(body.items) || body.items.length === 0) {
    throw badRequest('"items" is required and must be a non-empty array, or pass { "action": "list" }.');
  }

  const results = [];

  for (const [index, entry] of body.items.entries()) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
      throw badRequest(`items[${index}] must be an object.`);
    }
    const item = entry as Record<string, unknown>;
    const id = typeof item.id === 'string' ? item.id : '';
    if (id === '') throw badRequest(`items[${index}].id is required.`);

    const observed = Number(item.observed_remaining_canonical);
    if (!Number.isFinite(observed) || observed < 0) {
      throw badRequest(`items[${index}].observed_remaining_canonical must be a number of 0 or more.`);
    }

    const { data, error } = await client.from('pantry_items').select('*').eq('id', id).maybeSingle();
    if (error) throw new Error(`Failed to load pantry item ${id}: ${error.message}`);
    if (!data) throw notFound(`No pantry item with id ${id}.`);

    const row = data as PantryItemRow;
    const result = await setRemaining(client, row, observed, {
      reason: 'reconciliation',
      notes:
        typeof item.notes === 'string' && item.notes.trim() !== ''
          ? item.notes.trim()
          : 'Reconciled against what was actually in the cupboard.',
    });

    // A reconciled figure was observed, not inferred, so it is no longer a
    // low-confidence guess.
    if (row.quantity_confidence !== 'high') {
      await client.from('pantry_items').update({ quantity_confidence: 'high' }).eq('id', id);
    }

    results.push({
      id,
      display_name: row.display_name,
      previous_remaining: Number(row.canonical_quantity_remaining),
      observed_remaining: Number(result.item.canonical_quantity_remaining),
      delta: result.delta,
      canonical_unit: row.canonical_unit,
      now_depleted: result.item.depleted_at !== null,
      event_id: result.eventId,
    });
  }

  return ok({ reconciled: results.length, items: results });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
