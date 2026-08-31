/**
 * The restock list.
 *
 * Deduplicated on name while pending: if two different recipes both need more
 * rice, that is ONE line item, not two. The unique index enforces it at the
 * database level, and this module implements the merge -- keep the larger
 * suggested quantity, and remember every reason that contributed, so the daily
 * digest can say "more jasmine rice -- you were short for the stir-fry" even
 * when a low-stock sweep also flagged it.
 *
 * Because of that, running the daily sweep repeatedly is a no-op rather than a
 * source of duplicates.
 */

import type { SupabaseClient } from './db.ts';
import type { CanonicalUnit } from './units/types.ts';

export type RestockReason = 'ran_out' | 'running_low' | 'recipe_shortfall' | 'manual_add';

export interface RestockRequest {
  name: string;
  displayName: string;
  pantryItemId?: string | null;
  suggestedQuantityCanonical: number;
  suggestedCanonicalUnit: CanonicalUnit;
  reason: RestockReason;
  triggeringRecipeId?: string | null;
}

export interface RestockOutcome {
  name: string;
  action: 'created' | 'merged' | 'unchanged';
  id: string | null;
  suggestedQuantityCanonical: number;
}

interface ExistingRow {
  id: string;
  suggested_quantity_canonical: number;
  suggested_canonical_unit: CanonicalUnit;
  reason: RestockReason;
  merged_reasons: RestockReason[];
  triggering_recipe_id: string | null;
}

/**
 * Add to the restock list, merging into any pending row for the same item.
 *
 * Idempotent: calling this twice with the same request leaves one row with the
 * same quantity, and reports 'unchanged' the second time.
 */
export async function addToRestockList(
  client: SupabaseClient,
  request: RestockRequest,
): Promise<RestockOutcome> {
  if (!(request.suggestedQuantityCanonical > 0)) {
    return { name: request.name, action: 'unchanged', id: null, suggestedQuantityCanonical: 0 };
  }

  const { data: existing, error: selectError } = await client
    .from('restock_list')
    .select('id, suggested_quantity_canonical, suggested_canonical_unit, reason, merged_reasons, triggering_recipe_id')
    .eq('name', request.name)
    .eq('status', 'pending')
    .maybeSingle();

  if (selectError) {
    throw new Error(`Failed to check the restock list for "${request.name}": ${selectError.message}`);
  }

  if (existing) {
    return mergeInto(client, existing as ExistingRow, request);
  }

  const { data, error } = await client
    .from('restock_list')
    .insert({
      name: request.name,
      display_name: request.displayName,
      pantry_item_id: request.pantryItemId ?? null,
      suggested_quantity_canonical: request.suggestedQuantityCanonical,
      suggested_canonical_unit: request.suggestedCanonicalUnit,
      reason: request.reason,
      merged_reasons: [request.reason],
      triggering_recipe_id: request.triggeringRecipeId ?? null,
    })
    .select('id')
    .single();

  if (error) {
    // 23505: another caller inserted a pending row for this name in between.
    // Merge into theirs rather than failing the user's action.
    if ((error as { code?: string }).code === '23505') {
      const { data: raced } = await client
        .from('restock_list')
        .select('id, suggested_quantity_canonical, suggested_canonical_unit, reason, merged_reasons, triggering_recipe_id')
        .eq('name', request.name)
        .eq('status', 'pending')
        .maybeSingle();
      if (raced) return mergeInto(client, raced as ExistingRow, request);
    }
    throw new Error(`Failed to add "${request.name}" to the restock list: ${error.message}`);
  }

  return {
    name: request.name,
    action: 'created',
    id: (data as { id: string }).id,
    suggestedQuantityCanonical: request.suggestedQuantityCanonical,
  };
}

async function mergeInto(
  client: SupabaseClient,
  existing: ExistingRow,
  request: RestockRequest,
): Promise<RestockOutcome> {
  const sameUnit = existing.suggested_canonical_unit === request.suggestedCanonicalUnit;
  // Quantities in different canonical units cannot be compared, so the existing
  // one stands rather than being silently replaced by an incomparable number.
  const nextQuantity = sameUnit
    ? Math.max(Number(existing.suggested_quantity_canonical), request.suggestedQuantityCanonical)
    : Number(existing.suggested_quantity_canonical);

  const reasons = new Set<RestockReason>(existing.merged_reasons ?? []);
  reasons.add(existing.reason);
  reasons.add(request.reason);

  const patch: Record<string, unknown> = {};
  if (nextQuantity !== Number(existing.suggested_quantity_canonical)) {
    patch.suggested_quantity_canonical = nextQuantity;
  }
  if (reasons.size !== (existing.merged_reasons ?? []).length) {
    patch.merged_reasons = [...reasons];
  }
  // Keep the first recipe that caused the shortfall; it is the one the digest
  // will name, and the first is the most likely to still be on the user's mind.
  if (existing.triggering_recipe_id === null && request.triggeringRecipeId) {
    patch.triggering_recipe_id = request.triggeringRecipeId;
  }

  if (Object.keys(patch).length === 0) {
    return { name: request.name, action: 'unchanged', id: existing.id, suggestedQuantityCanonical: nextQuantity };
  }

  const { error } = await client.from('restock_list').update(patch).eq('id', existing.id);
  if (error) throw new Error(`Failed to merge restock row for "${request.name}": ${error.message}`);

  return { name: request.name, action: 'merged', id: existing.id, suggestedQuantityCanonical: nextQuantity };
}
