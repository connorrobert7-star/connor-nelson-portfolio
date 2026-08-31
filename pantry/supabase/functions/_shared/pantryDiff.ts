/**
 * Comparing what a recipe needs against what is actually in the pantry.
 *
 * This is a THREE-way answer, not a boolean, and that is the whole point:
 *   have_enough  - do not buy it
 *   have_some    - buy it anyway, and say how short you are
 *   have_none    - buy it
 *
 * "have_some" is the case that makes the app worth using. Being told "you have
 * rice" when you have 80 g and need 200 g is worse than being told nothing,
 * because you skip it at the shop and find out mid-recipe.
 *
 * Pure by construction: rows in, verdicts out, no database and no network, so
 * it can be tested exhaustively. Phase 5's /recipe-feasibility calls the same
 * function with a servings scale.
 */

import type { PantryItemRow } from './db.ts';
import type { GeneratedIngredient } from './recipeSchema.ts';
import { normalizeItemName } from './units/itemNames.ts';
import { patternMatchesName, toCanonical } from './units/toCanonical.ts';
import type { CanonicalUnit, Confidence } from './units/types.ts';

/**
 * How much of a shortfall to forgive. Needing 200 g of rice and having 198 g is
 * not a shopping trip, and reporting it as one trains you to ignore the app.
 */
export const SUFFICIENCY_TOLERANCE = 0.02;

export type CoverageStatus = 'have_enough' | 'have_some' | 'have_none';

export interface IngredientCoverage {
  ingredient: GeneratedIngredient;
  /** The pantry join key. */
  normalizedName: string;

  requiredCanonical: number;
  canonicalUnit: CanonicalUnit;
  /** Confidence in the REQUIRED figure, from the unit conversion. */
  conversionConfidence: Confidence;

  availableCanonical: number;
  shortfallCanonical: number;

  status: CoverageStatus;
  /** True unless we already have enough. Drives what goes in the cart. */
  needsPurchase: boolean;

  /** Pantry lots that matched, expiring soonest first. */
  matchedLots: PantryItemRow[];
  isStaple: boolean;
  /**
   * Set when a lot matched by name but is measured in a different canonical
   * unit (pantry has 12 eggs by count, recipe asks for 200 g of egg). Such lots
   * are NOT counted -- subtracting across units is the bug this whole layer
   * exists to prevent -- so the item is reported as missing and flagged.
   */
  unitMismatch: boolean;
  warnings: string[];
}

export interface DiffOptions {
  /** Multiply every required quantity, for "can I make this for 4?". */
  scale?: number;
}

/** Lots for one ingredient, expiring soonest first (FEFO), nulls last. */
function matchingLots(normalizedName: string, pantry: PantryItemRow[]): PantryItemRow[] {
  if (normalizedName === '') return [];

  const exact = pantry.filter((row) => row.name === normalizedName);
  const candidates =
    exact.length > 0
      ? exact
      : pantry.filter(
          (row) =>
            patternMatchesName(row.name, normalizedName) ||
            patternMatchesName(normalizedName, row.name),
        );

  return [...candidates].sort((a, b) => {
    if (a.estimated_expiry === b.estimated_expiry) return 0;
    if (a.estimated_expiry === null) return 1;
    if (b.estimated_expiry === null) return -1;
    return a.estimated_expiry < b.estimated_expiry ? -1 : 1;
  });
}

export function coverageForIngredient(
  ingredient: GeneratedIngredient,
  pantry: PantryItemRow[],
  options: DiffOptions = {},
): IngredientCoverage {
  const scale = options.scale !== undefined && options.scale > 0 ? options.scale : 1;
  const normalizedName = normalizeItemName(ingredient.name);

  const converted = toCanonical(ingredient.name, ingredient.quantity, ingredient.unit, {
    category: ingredient.category,
  });
  const requiredCanonical = converted.canonicalQuantity * scale;
  const canonicalUnit = converted.canonicalUnit;
  const warnings = [...converted.warnings];

  const allLots = matchingLots(normalizedName, pantry);
  const usableLots = allLots.filter((row) => row.canonical_unit === canonicalUnit);
  const mismatchedLots = allLots.filter((row) => row.canonical_unit !== canonicalUnit);

  if (mismatchedLots.length > 0) {
    warnings.push(
      `Pantry has "${mismatchedLots[0]?.display_name}" measured in ` +
        `${mismatchedLots[0]?.canonical_unit}, but this recipe asks for ${canonicalUnit}. ` +
        'Not counted -- fix the pantry entry or add a unit_conversions row.',
    );
  }

  const isStaple = allLots.some((row) => row.is_staple);
  const availableCanonical = usableLots.reduce(
    (total, row) => total + Number(row.canonical_quantity_remaining),
    0,
  );

  // Staples (salt, flour, oil, spices) are always considered sufficient. They
  // are exempt from depletion, so their remaining figure never goes down and
  // comparing against it would be meaningless.
  let status: CoverageStatus;
  let shortfallCanonical = 0;

  if (isStaple) {
    status = 'have_enough';
  } else if (availableCanonical <= 0) {
    status = 'have_none';
    shortfallCanonical = requiredCanonical;
  } else if (availableCanonical >= requiredCanonical * (1 - SUFFICIENCY_TOLERANCE)) {
    status = 'have_enough';
  } else {
    status = 'have_some';
    shortfallCanonical = requiredCanonical - availableCanonical;
  }

  return {
    ingredient,
    normalizedName,
    requiredCanonical: round(requiredCanonical),
    canonicalUnit,
    conversionConfidence: converted.confidence,
    availableCanonical: round(availableCanonical),
    shortfallCanonical: round(shortfallCanonical),
    status,
    // Partial coverage still goes in the cart.
    needsPurchase: status !== 'have_enough',
    matchedLots: usableLots,
    isStaple,
    unitMismatch: mismatchedLots.length > 0,
    warnings,
  };
}

export interface PantryDiff {
  coverage: IngredientCoverage[];
  haveEnough: IngredientCoverage[];
  haveSome: IngredientCoverage[];
  haveNone: IngredientCoverage[];
  /** Everything that should end up in the cart. */
  needToBuy: IngredientCoverage[];
}

export function diffAgainstPantry(
  ingredients: GeneratedIngredient[],
  pantry: PantryItemRow[],
  options: DiffOptions = {},
): PantryDiff {
  // Only things actually in the house count. A depleted lot is a historical
  // record, not an ingredient.
  const active = pantry.filter((row) => row.depleted_at === null);
  const coverage = ingredients.map((ingredient) => coverageForIngredient(ingredient, active, options));

  return {
    coverage,
    haveEnough: coverage.filter((entry) => entry.status === 'have_enough'),
    haveSome: coverage.filter((entry) => entry.status === 'have_some'),
    haveNone: coverage.filter((entry) => entry.status === 'have_none'),
    needToBuy: coverage.filter((entry) => entry.needsPurchase),
  };
}

/**
 * Apply the diff back onto the ingredient list, overriding whatever the model
 * guessed about what is already in the fridge. The model cannot know; the
 * database does.
 */
export function applyCoverageToIngredients(diff: PantryDiff): Array<
  GeneratedIngredient & {
    coverage_status: CoverageStatus;
    required_canonical: number;
    available_canonical: number;
    shortfall_canonical: number;
    canonical_unit: CanonicalUnit;
    conversion_confidence: Confidence;
  }
> {
  return diff.coverage.map((entry) => ({
    ...entry.ingredient,
    likely_already_have: entry.status === 'have_enough',
    coverage_status: entry.status,
    required_canonical: entry.requiredCanonical,
    available_canonical: entry.availableCanonical,
    shortfall_canonical: entry.shortfallCanonical,
    canonical_unit: entry.canonicalUnit,
    conversion_confidence: entry.conversionConfidence,
  }));
}

function round(value: number): number {
  if (!Number.isFinite(value)) return 0;
  const magnitude = Math.abs(value);
  const decimals = magnitude >= 100 ? 2 : magnitude >= 1 ? 3 : 4;
  return Number(value.toFixed(decimals));
}
