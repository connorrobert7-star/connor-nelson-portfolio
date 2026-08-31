/**
 * Low-stock threshold defaults.
 *
 * Referenced by the pantry_items migration. Kept in code rather than as a column
 * default because the number depends on the category AND on how much was bought,
 * which SQL defaults cannot see.
 *
 * The percentages come straight from the spec: staples and condiments at 20% of
 * a typical purchase, proteins and produce at 25%, spices exempt.
 */

import type { PantryCategory } from './types.js';

const THRESHOLD_FRACTION: Record<PantryCategory, number | null> = {
  produce: 0.25,
  meat: 0.25,
  seafood: 0.25,
  dairy: 0.25,
  frozen: 0.25,
  pantry_dry: 0.2,
  canned: 0.2,
  condiment: 0.2,
  bakery: 0.25,
  beverage: 0.2,
  // Exempt. Nobody wants a notification about being low on cumin.
  spice: null,
  other: 0.2,
};

/**
 * Default low-stock threshold in canonical units, or null when the category is
 * exempt from low-stock nagging.
 *
 * `isStaple` does not exempt an item here: a staple is exempt from expiry
 * nagging and from depletion, but running out of flour is still worth knowing.
 * The spec puts staples at 20%, which is what pantry_dry/condiment already are.
 */
export function defaultLowStockThreshold(
  category: PantryCategory,
  canonicalQuantity: number,
): number | null {
  const fraction = THRESHOLD_FRACTION[category];
  if (fraction === null) return null;
  if (!Number.isFinite(canonicalQuantity) || canonicalQuantity <= 0) return null;
  return Number((canonicalQuantity * fraction).toFixed(4));
}

/**
 * The "effectively gone" floor from Phase 5. Below 5% of the original amount an
 * item is treated as depleted -- nobody cooks with 4 g of leftover onion.
 */
export const DEPLETION_FLOOR_FRACTION = 0.05;

export function isEffectivelyDepleted(remaining: number, original: number): boolean {
  if (original <= 0) return true;
  return remaining <= original * DEPLETION_FLOOR_FRACTION;
}
