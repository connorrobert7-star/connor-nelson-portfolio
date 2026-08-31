/**
 * Turning canonical numbers back into something a person would say.
 *
 * Grams are the right unit for arithmetic and the wrong unit for a shopping
 * list. "You need another 47 g of cilantro" is not actionable; "about another
 * half a bunch" is. Every shortfall shown in the UI goes through here.
 *
 * The conversion back is derived per lot: if 1 bunch was bought and that came
 * to 45 g, then 22 g is half a bunch OF THAT ITEM. No global table needed, and
 * it stays correct even when the conversion data is wrong, because it is
 * self-consistent with whatever was recorded at purchase time.
 */

import type { CanonicalUnit } from './units/types.ts';

export interface PurchaseUnitContext {
  purchaseQuantity?: number | null;
  purchaseUnit?: string | null;
  canonicalOriginal?: number | null;
}

const IRREGULAR_PLURALS: Record<string, string> = {
  bunch: 'bunches',
  box: 'boxes',
  loaf: 'loaves',
  leaf: 'leaves',
  patty: 'patties',
  inch: 'inches',
};

function pluralize(unit: string, count: number): string {
  if (Math.abs(count - 1) < 0.001) return unit;
  const irregular = IRREGULAR_PLURALS[unit];
  if (irregular) return irregular;
  if (/(s|sh|ch|x|z)$/.test(unit)) return `${unit}es`;
  return `${unit}s`;
}

/** Round to a fraction people actually say. */
function fractionPhrase(count: number, unit: string): string {
  if (count >= 0.9) {
    // Round to the nearest half above 1; whole numbers below 3.
    const rounded = count < 3 ? Math.round(count * 2) / 2 : Math.round(count);
    const label = Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
    return `about ${label} ${pluralize(unit, rounded)}`;
  }
  if (count >= 0.7) return `about three quarters of a ${unit}`;
  if (count >= 0.4) return `about half a ${unit}`;
  if (count >= 0.15) return `about a quarter of a ${unit}`;
  return `a little ${unit}`;
}

function formatCanonical(amount: number, unit: CanonicalUnit): string {
  if (unit === 'count') {
    const rounded = Math.round(amount * 10) / 10;
    return `${rounded} ${rounded === 1 ? 'item' : 'items'}`;
  }
  if (amount >= 1000) return `${(amount / 1000).toFixed(1)} ${unit === 'g' ? 'kg' : 'l'}`;
  return `${Math.round(amount)} ${unit}`;
}

/**
 * Describe a canonical amount in the units the item was actually bought in.
 * Falls back to the canonical figure when there is nothing to convert against.
 */
export function describeAmount(
  amount: number,
  canonicalUnit: CanonicalUnit,
  context: PurchaseUnitContext = {},
): string {
  if (!Number.isFinite(amount) || amount <= 0) return `no ${canonicalUnit === 'count' ? 'items' : canonicalUnit}`;

  const { purchaseQuantity, purchaseUnit, canonicalOriginal } = context;

  const canConvert =
    typeof purchaseQuantity === 'number' &&
    purchaseQuantity > 0 &&
    typeof canonicalOriginal === 'number' &&
    canonicalOriginal > 0 &&
    typeof purchaseUnit === 'string' &&
    purchaseUnit.trim() !== '';

  if (!canConvert) return formatCanonical(amount, canonicalUnit);

  const unit = (purchaseUnit as string).trim().toLowerCase();
  // A purchase unit that IS the canonical unit adds nothing over the number.
  if (unit === canonicalUnit || unit === 'g' || unit === 'ml' || unit === 'count') {
    return formatCanonical(amount, canonicalUnit);
  }

  const canonicalPerPurchaseUnit = (canonicalOriginal as number) / (purchaseQuantity as number);
  if (!(canonicalPerPurchaseUnit > 0)) return formatCanonical(amount, canonicalUnit);

  return fractionPhrase(amount / canonicalPerPurchaseUnit, unit);
}

/**
 * "~60% left" reads better than a bare gram count on the pantry screen, and it
 * is also more honest: the underlying figure is an estimate either way, and a
 * proportion does not pretend otherwise.
 */
export function describeProportion(remaining: number, original: number): string {
  if (!(original > 0)) return 'unknown';
  const percent = Math.round((remaining / original) * 100);
  if (percent <= 0) return 'none left';
  if (percent >= 98) return 'unopened';
  return `~${Math.min(percent, 100)}% left`;
}

/** "in 2 days", "today", "3 days ago". */
export function describeDaysUntil(days: number | null): string {
  if (days === null) return 'no estimate';
  if (days < -1) return `about ${Math.abs(days)} days ago`;
  if (days === -1) return 'yesterday';
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  return `in about ${days} days`;
}

export function daysUntil(isoDate: string | null, today: Date): number | null {
  if (!isoDate) return null;
  const target = new Date(`${isoDate}T00:00:00Z`);
  if (Number.isNaN(target.getTime())) return null;
  const start = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  return Math.round((target.getTime() - start) / 86_400_000);
}
