/**
 * POST /low-stock-check
 *
 * Sweeps the pantry for anything that has fallen below its low-stock threshold
 * and puts it on the restock list.
 *
 * MUST be idempotent: this runs daily from cron, and running it every day for a
 * week must not leave seven rows for the same jar of mustard. That is
 * guaranteed on two levels -- a partial unique index allows only one pending
 * row per item name, and addToRestockList() merges into any existing row rather
 * than inserting a second.
 */

import { serviceClient, type PantryItemRow } from '../_shared/db.ts';
import { ok, serveHandler } from '../_shared/http.ts';
import { addToRestockList, type RestockOutcome } from '../_shared/restock.ts';

/** How far back to look for things that ran out and were never replaced. */
const RECENTLY_DEPLETED_DAYS = 30;

/**
 * How much to suggest buying. The median of past purchases is the best answer;
 * failing that, whatever this lot originally was.
 */
function suggestedQuantity(item: PantryItemRow): number {
  const typical = Number(item.typical_purchase_canonical);
  if (Number.isFinite(typical) && typical > 0) return typical;
  const original = Number(item.canonical_quantity_original);
  return Number.isFinite(original) && original > 0 ? original : 0;
}

export const handler = serveHandler(async (): Promise<Response> => {
  const client = serviceClient();
  const outcomes: RestockOutcome[] = [];
  const scanned: Array<Record<string, unknown>> = [];

  // --- still in the pantry, but low ---------------------------------------
  const { data: active, error: activeError } = await client
    .from('pantry_items')
    .select('*')
    .is('depleted_at', null)
    .eq('is_staple', false)
    .not('low_stock_threshold_canonical', 'is', null);

  if (activeError) throw new Error(`Failed to scan the pantry: ${activeError.message}`);

  // Several lots of the same item are one stock level, not several. Summing
  // first stops two half-empty bags of rice both reading as "running low".
  const byName = new Map<string, PantryItemRow[]>();
  for (const row of (active ?? []) as PantryItemRow[]) {
    byName.set(row.name, [...(byName.get(row.name) ?? []), row]);
  }

  for (const [name, lots] of byName) {
    const totalRemaining = lots.reduce((sum, lot) => sum + Number(lot.canonical_quantity_remaining), 0);
    const threshold = Math.max(
      ...lots.map((lot) => Number(lot.low_stock_threshold_canonical ?? 0)),
    );
    const newest = lots[lots.length - 1] as PantryItemRow;

    if (!(threshold > 0) || totalRemaining >= threshold) continue;

    scanned.push({ name, total_remaining: totalRemaining, threshold, unit: newest.canonical_unit });

    outcomes.push(
      await addToRestockList(client, {
        name,
        displayName: newest.display_name,
        pantryItemId: newest.id,
        suggestedQuantityCanonical: suggestedQuantity(newest),
        suggestedCanonicalUnit: newest.canonical_unit,
        reason: totalRemaining <= 0 ? 'ran_out' : 'running_low',
      }),
    );
  }

  // --- ran out entirely and has not been replaced -------------------------
  // Without this, "I finished the rice" never reaches the restock list at all:
  // the lot is depleted, so the scan above cannot see it.
  const cutoff = new Date();
  cutoff.setUTCDate(cutoff.getUTCDate() - RECENTLY_DEPLETED_DAYS);

  const { data: depleted, error: depletedError } = await client
    .from('pantry_items')
    .select('*')
    .not('depleted_at', 'is', null)
    .eq('is_staple', false)
    .gte('depleted_at', cutoff.toISOString());

  if (depletedError) throw new Error(`Failed to scan depleted items: ${depletedError.message}`);

  const activeNames = new Set((active ?? []).map((row) => (row as PantryItemRow).name));

  for (const row of (depleted ?? []) as PantryItemRow[]) {
    if (activeNames.has(row.name)) continue; // replaced already
    if (byName.has(row.name)) continue;
    // Discarded items are handled by /mark-discarded, which knows whether the
    // user actually wants a replacement.
    if (row.discarded) continue;

    scanned.push({ name: row.name, total_remaining: 0, threshold: null, unit: row.canonical_unit });

    outcomes.push(
      await addToRestockList(client, {
        name: row.name,
        displayName: row.display_name,
        // The lot is gone, so the restock row stands on its own.
        pantryItemId: null,
        suggestedQuantityCanonical: suggestedQuantity(row),
        suggestedCanonicalUnit: row.canonical_unit,
        reason: 'ran_out',
      }),
    );
  }

  return ok({
    scanned: scanned.length,
    created: outcomes.filter((o) => o.action === 'created').length,
    merged: outcomes.filter((o) => o.action === 'merged').length,
    unchanged: outcomes.filter((o) => o.action === 'unchanged').length,
    items: scanned,
  });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
