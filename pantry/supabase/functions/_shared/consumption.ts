/**
 * The ONLY path that changes pantry_items.canonical_quantity_remaining.
 *
 * Every change writes a consumption_events row. That is a hard rule from the
 * spec and the reason the audit trail is worth anything: months from now, when
 * a number looks wrong, it must be possible to reconstruct why it is what it is.
 *
 * The arithmetic is split out as a pure function so the awkward cases -- going
 * negative, the 5% floor, staples -- can be tested without a database.
 */

import type { PantryItemRow, SupabaseClient } from './db.ts';
import { DEPLETION_FLOOR_FRACTION } from './units/thresholds.ts';

export type ConsumptionReason =
  | 'recipe_cooked'
  | 'manual_adjustment'
  | 'discarded_expired'
  | 'reconciliation';

export interface DepletionPlan {
  /** What remaining becomes. Never negative. */
  newRemaining: number;
  /** How much was actually taken off (may be less than requested). */
  applied: number;
  /**
   * How much MORE was asked for than existed. Non-zero means the pantry data
   * has drifted -- real information, so it is recorded and surfaced, not
   * silently floored away.
   */
  shortfall: number;
  /** True when this change empties the lot. */
  depleted: boolean;
  /** True when the lot is a staple and nothing should change at all. */
  skipped: boolean;
}

/**
 * Work out the effect of taking `requested` units off a lot.
 *
 * A staple is skipped entirely: salt, oil and spices are exempt from depletion,
 * so "a pinch of salt" must not decrement anything.
 *
 * Anything at or below 5% of the original is treated as gone -- nobody cooks
 * with 4 g of leftover onion, and leaving a sliver behind means it lingers in
 * the pantry forever and pollutes every feasibility check.
 */
export function planDepletion(
  item: Pick<PantryItemRow, 'canonical_quantity_original' | 'canonical_quantity_remaining' | 'is_staple'>,
  requested: number,
): DepletionPlan {
  const original = Number(item.canonical_quantity_original);
  const remaining = Number(item.canonical_quantity_remaining);

  if (item.is_staple) {
    return { newRemaining: remaining, applied: 0, shortfall: 0, depleted: false, skipped: true };
  }

  const want = Math.max(0, requested);
  const applied = Math.min(want, remaining);
  const shortfall = round(want - applied);
  let newRemaining = round(remaining - applied);

  const floor = original * DEPLETION_FLOOR_FRACTION;
  const depleted = newRemaining <= floor;
  if (depleted) newRemaining = 0;

  return { newRemaining, applied: round(applied), shortfall, depleted, skipped: false };
}

export interface ApplyResult extends DepletionPlan {
  item: PantryItemRow;
  eventId: string | null;
}

/**
 * Apply a depletion to one lot and record it.
 *
 * The UPDATE is guarded on the remaining value we read, so a concurrent change
 * loses rather than being silently overwritten -- otherwise cooking two recipes
 * at once could double-spend the same 200 g of rice.
 */
export async function applyDepletion(
  client: SupabaseClient,
  item: PantryItemRow,
  requested: number,
  context: { reason: ConsumptionReason; recipeId?: string | null; notes?: string },
): Promise<ApplyResult> {
  const plan = planDepletion(item, requested);

  if (plan.skipped || plan.applied === 0) {
    return { ...plan, item, eventId: null };
  }

  const { data: updated, error: updateError } = await client
    .from('pantry_items')
    .update({
      canonical_quantity_remaining: plan.newRemaining,
      depleted_at: plan.depleted ? new Date().toISOString() : null,
    })
    .eq('id', item.id)
    .eq('canonical_quantity_remaining', item.canonical_quantity_remaining)
    .select()
    .maybeSingle();

  if (updateError) {
    throw new Error(`Failed to update pantry item ${item.id}: ${updateError.message}`);
  }
  if (!updated) {
    throw new Error(
      `Pantry item ${item.id} changed while it was being depleted. Nothing was written; retry.`,
    );
  }

  const eventId = await recordEvent(client, {
    pantryItemId: item.id,
    recipeId: context.recipeId ?? null,
    canonicalAmount: -plan.applied,
    reason: context.reason,
    shortfallCanonical: plan.shortfall > 0 ? plan.shortfall : null,
    notes: context.notes ?? null,
  });

  return { ...plan, item: updated as PantryItemRow, eventId };
}

/**
 * Set a lot's remaining amount outright, for manual corrections and
 * reconciliation. Writes the delta as an event, in whichever direction.
 */
export async function setRemaining(
  client: SupabaseClient,
  item: PantryItemRow,
  observedRemaining: number,
  context: { reason: ConsumptionReason; notes?: string },
): Promise<{ item: PantryItemRow; delta: number; eventId: string | null }> {
  const original = Number(item.canonical_quantity_original);
  const previous = Number(item.canonical_quantity_remaining);

  // The DB forbids remaining > original, so an upward correction past the
  // original raises the original too: finding more than you thought you bought
  // means the original was wrong, not that the constraint should bend.
  const clamped = Math.max(0, round(observedRemaining));
  const newOriginal = clamped > original ? clamped : original;
  const delta = round(clamped - previous);

  const floor = newOriginal * DEPLETION_FLOOR_FRACTION;
  const depleted = clamped <= floor;

  const { data: updated, error } = await client
    .from('pantry_items')
    .update({
      canonical_quantity_original: newOriginal,
      canonical_quantity_remaining: depleted ? 0 : clamped,
      depleted_at: depleted ? new Date().toISOString() : null,
    })
    .eq('id', item.id)
    .select()
    .single();

  if (error) throw new Error(`Failed to correct pantry item ${item.id}: ${error.message}`);

  const eventId =
    delta === 0
      ? null
      : await recordEvent(client, {
          pantryItemId: item.id,
          recipeId: null,
          canonicalAmount: delta,
          reason: context.reason,
          shortfallCanonical: null,
          notes: context.notes ?? null,
        });

  return { item: updated as PantryItemRow, delta, eventId };
}

interface EventInput {
  pantryItemId: string;
  recipeId: string | null;
  canonicalAmount: number;
  reason: ConsumptionReason;
  shortfallCanonical: number | null;
  notes: string | null;
}

async function recordEvent(client: SupabaseClient, event: EventInput): Promise<string | null> {
  // A zero-amount event is a no-op and the DB rejects it by design.
  if (event.canonicalAmount === 0) return null;

  const { data, error } = await client
    .from('consumption_events')
    .insert({
      pantry_item_id: event.pantryItemId,
      recipe_id: event.recipeId,
      canonical_amount: event.canonicalAmount,
      reason: event.reason,
      shortfall_canonical: event.shortfallCanonical,
      notes: event.notes,
    })
    .select('id')
    .single();

  if (error) {
    // The quantity has already moved. Losing the audit row is bad enough to
    // shout about, but not a reason to fail the user's action.
    console.error(`Failed to write consumption event for ${event.pantryItemId}: ${error.message}`);
    return null;
  }
  return (data as { id: string }).id;
}

function round(value: number): number {
  if (!Number.isFinite(value)) return 0;
  const magnitude = Math.abs(value);
  const decimals = magnitude >= 100 ? 2 : magnitude >= 1 ? 3 : 4;
  return Number(value.toFixed(decimals));
}
