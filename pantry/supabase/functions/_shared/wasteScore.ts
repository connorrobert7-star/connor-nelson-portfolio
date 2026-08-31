/**
 * Waste urgency scoring.
 *
 * Ranks what is at risk of being thrown away, so /leftovers-suggest can build
 * recipes around the things that actually matter. A nearly-full bag of spinach
 * expiring in two days must outrank a nearly-empty jar of mustard expiring in
 * three months.
 *
 * Kept as a separate pure function with the weights exposed, because the
 * weighting is a matter of taste and will want tuning.
 */

import type { PantryItemRow } from './db.ts';
import { daysUntil } from './humanize.ts';
import { DEPLETION_FLOOR_FRACTION } from './units/thresholds.ts';

export interface WasteScoreWeights {
  /**
   * Days until urgency halves. At 3, something due today scores 1.0, in 3 days
   * 0.5, in a week 0.2, in a fortnight 0.04 -- which matches how much a person
   * actually cares.
   */
  urgencyHalfLifeDays: number;
  /**
   * Exponent on the proportion remaining. 1 is linear. Above 1 punishes
   * near-empty items harder; below 1 flattens the difference.
   */
  quantityExponent: number;
  /** Score for something already past its estimated date. */
  expiredScore: number;
  /** Urgency for an item with no expiry estimate at all. */
  unknownExpiryUrgency: number;
  /**
   * Below this, an item is not "at risk" and is dropped from the ranking.
   * Explicit rather than emergent: without it the cutoff was wherever the
   * score happened to round to zero, which is not a decision anyone made.
   * At the default half-life this excludes anything roughly 30+ days out.
   */
  minScore: number;
}

export const DEFAULT_WEIGHTS: WasteScoreWeights = {
  urgencyHalfLifeDays: 3,
  quantityExponent: 1,
  expiredScore: 1,
  unknownExpiryUrgency: 0.05,
  minScore: 0.001,
};

export interface WasteScore {
  item: PantryItemRow;
  score: number;
  daysLeft: number | null;
  proportionRemaining: number;
  urgency: number;
  /** Why this scored what it did, for the UI and for tuning. */
  reason: string;
}

/** Exponential decay: urgency halves every `halfLife` days. */
function urgencyFromDays(days: number | null, weights: WasteScoreWeights): number {
  if (days === null) return weights.unknownExpiryUrgency;
  if (days <= 0) return weights.expiredScore;
  return Math.pow(2, -days / weights.urgencyHalfLifeDays);
}

export function scoreWasteUrgency(
  item: PantryItemRow,
  today: Date,
  weights: WasteScoreWeights = DEFAULT_WEIGHTS,
): WasteScore {
  const original = Number(item.canonical_quantity_original);
  const remaining = Number(item.canonical_quantity_remaining);
  const proportion = original > 0 ? Math.max(0, Math.min(1, remaining / original)) : 0;
  const days = daysUntil(item.estimated_expiry, today);

  // Staples are exempt from expiry nagging, so they can never be at risk.
  if (item.is_staple) {
    return { item, score: 0, daysLeft: days, proportionRemaining: proportion, urgency: 0, reason: 'Staple: exempt from expiry tracking.' };
  }

  const urgency = urgencyFromDays(days, weights);
  const score = urgency * Math.pow(proportion, weights.quantityExponent);

  const reason =
    days === null
      ? `No expiry estimate; ${Math.round(proportion * 100)}% left.`
      : days <= 0
        ? `Estimated past its best; ${Math.round(proportion * 100)}% left.`
        : `About ${days} days left, ${Math.round(proportion * 100)}% of it unused.`;

  return { item, score: round(score), daysLeft: days, proportionRemaining: round(proportion), urgency: round(urgency), reason };
}

/**
 * Rank the pantry by how much would be wasted if nothing changed.
 * Items below the 5% "effectively gone" floor are dropped: there is nothing
 * left to save.
 */
export function rankByWasteUrgency(
  items: PantryItemRow[],
  today: Date,
  weights: WasteScoreWeights = DEFAULT_WEIGHTS,
): WasteScore[] {
  return items
    .filter((item) => item.depleted_at === null && !item.is_staple)
    .filter((item) => {
      const original = Number(item.canonical_quantity_original);
      const remaining = Number(item.canonical_quantity_remaining);
      return original > 0 && remaining > original * DEPLETION_FLOOR_FRACTION;
    })
    .map((item) => scoreWasteUrgency(item, today, weights))
    .filter((scored) => scored.score >= weights.minScore)
    .sort((a, b) => b.score - a.score);
}

function round(value: number): number {
  return Number.isFinite(value) ? Number(value.toFixed(4)) : 0;
}
