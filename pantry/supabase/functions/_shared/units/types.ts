/**
 * Shared types for the unit conversion layer.
 *
 * The whole project rests on one rule: nothing does arithmetic on a quantity
 * until it has been converted into one of exactly three canonical units.
 * If you find yourself subtracting a tablespoon from a bunch, the bug is here.
 */

export const PANTRY_CATEGORIES = [
  'produce',
  'dairy',
  'meat',
  'seafood',
  'frozen',
  'pantry_dry',
  'canned',
  'condiment',
  'spice',
  'bakery',
  'beverage',
  'other',
] as const;

export type PantryCategory = (typeof PANTRY_CATEGORIES)[number];

export const CANONICAL_UNITS = ['g', 'ml', 'count'] as const;
export type CanonicalUnit = (typeof CANONICAL_UNITS)[number];

export const CONFIDENCE_LEVELS = ['high', 'medium', 'low'] as const;
export type Confidence = (typeof CONFIDENCE_LEVELS)[number];

/** How a source unit is measured. Drives which conversion path is legal. */
export type Dimension = 'weight' | 'volume' | 'count';

/**
 * A flat conversion rule. Mirrors the `unit_conversions` table row-for-row so
 * the seed script is a straight projection and the DB stays inspectable/editable.
 */
export interface ConversionRule {
  /** Matched with substring/ILIKE against the normalized item name. */
  itemNamePattern: string | null;
  /** Fallback scope. Only consulted when itemNamePattern is null. */
  category: PantryCategory | null;
  /** Already normalized by normalizeUnit(). */
  fromUnit: string;
  toCanonicalUnit: CanonicalUnit;
  multiplier: number;
  confidence: Confidence;
  notes?: string;
  /** Stable identity for idempotent seeding. */
  seedKey: string;
}

/** What toCanonical() returns. */
export interface ToCanonicalResult {
  canonicalQuantity: number;
  canonicalUnit: CanonicalUnit;
  confidence: Confidence;

  // --- diagnostics -------------------------------------------------------
  // Not part of the contract the spec asked for, but every caller that writes a
  // pantry row wants to log HOW a number was arrived at, and the tests assert
  // on the path taken rather than only the output.

  /** Normalized item name used for rule lookup. */
  normalizedName: string;
  /** Numeric quantity after parsing "1 1/2", "half", "a couple", etc. */
  parsedQuantity: number;
  /** Source unit after alias normalization. */
  normalizedUnit: string;
  /** Which resolution path produced the answer. */
  path:
    | 'item-rule'
    | 'item-density'
    | 'universal'
    | 'category-rule'
    | 'category-density'
    | 'identity'
    | 'unresolved';
  /** Human-readable explanation, safe to show in a debug UI. */
  explanation: string;
  /** Non-fatal problems: fuzzy units, ambiguous "oz", unknown items. */
  warnings: string[];
}

export interface ToCanonicalOptions {
  /** Known category, when the caller has one. Improves fallback quality. */
  category?: PantryCategory;
  /** Override the rule set. Used by tests and by the DB-backed loader. */
  rules?: ConversionRule[];
}

/** Ordering helper: confidence only ever degrades as it flows through a pipeline. */
const CONFIDENCE_RANK: Record<Confidence, number> = { high: 3, medium: 2, low: 1 };

export function minConfidence(...levels: Confidence[]): Confidence {
  let worst: Confidence = 'high';
  for (const level of levels) {
    if (CONFIDENCE_RANK[level] < CONFIDENCE_RANK[worst]) worst = level;
  }
  return worst;
}

export function isCanonicalUnit(value: string): value is CanonicalUnit {
  return (CANONICAL_UNITS as readonly string[]).includes(value);
}

export function isPantryCategory(value: string): value is PantryCategory {
  return (PANTRY_CATEGORIES as readonly string[]).includes(value);
}
