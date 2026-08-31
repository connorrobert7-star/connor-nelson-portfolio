/**
 * "Can I actually make this right now?"
 *
 * Runs the same canonical comparison as recipe generation, but callable at any
 * time -- the pantry changes underneath saved recipes, so a recipe seen last
 * week may no longer be makeable, and the answer has to be recomputed rather
 * than remembered.
 *
 * Shortfalls come back in PURCHASE units, never grams. "You'll need about
 * another half a bunch of cilantro" is actionable; "47 g short" is not.
 */

import { describeAmount } from './humanize.ts';
import type { IngredientCoverage, PantryDiff } from './pantryDiff.ts';

export type FeasibilityVerdict = 'fully_makeable' | 'makeable_scaled_down' | 'blocked';

export interface IngredientFeasibility {
  name: string;
  display_name: string;
  status: 'sufficient' | 'short' | 'missing';
  /** The shortfall in the units the item is bought in. */
  shortfall_description: string | null;
  shortfall_canonical: number;
  required_canonical: number;
  available_canonical: number;
  canonical_unit: string;
  confidence: string;
}

export interface FeasibilityReport {
  verdict: FeasibilityVerdict;
  /** One sentence, ready to show as a banner. */
  headline: string;
  servings_requested: number;
  /** Largest number of servings the pantry actually supports, when short. */
  servings_possible: number | null;
  ingredients: IngredientFeasibility[];
  blocked_on: string[];
  short_on: string[];
}

/** The purchase-unit context for an ingredient, taken from its matched lot. */
function purchaseContext(entry: IngredientCoverage) {
  const lot = entry.matchedLots[0];
  return lot
    ? {
        purchaseQuantity: lot.purchase_quantity,
        purchaseUnit: lot.purchase_unit,
        canonicalOriginal: lot.canonical_quantity_original,
      }
    : {};
}

function describeIngredient(entry: IngredientCoverage): IngredientFeasibility {
  const status =
    entry.status === 'have_enough' ? 'sufficient' : entry.status === 'have_some' ? 'short' : 'missing';

  let shortfallDescription: string | null = null;
  if (status === 'short') {
    shortfallDescription = describeAmount(
      entry.shortfallCanonical,
      entry.canonicalUnit,
      purchaseContext(entry),
    );
  } else if (status === 'missing') {
    // Nothing on hand, so there is no purchase unit to describe it in. Use the
    // recipe's own wording, which is what a person would write on a list.
    const { quantity, unit, display_name } = entry.ingredient;
    shortfallDescription = unit
      ? `${quantity} ${unit} ${display_name}`.trim()
      : `${quantity} ${display_name}`.trim();
  }

  return {
    name: entry.normalizedName,
    display_name: entry.ingredient.display_name,
    status,
    shortfall_description: shortfallDescription,
    shortfall_canonical: entry.shortfallCanonical,
    required_canonical: entry.requiredCanonical,
    available_canonical: entry.availableCanonical,
    canonical_unit: entry.canonicalUnit,
    confidence: entry.conversionConfidence,
  };
}

/** A readable list: "rice", "rice and soy sauce", "rice, soy sauce and eggs". */
function joinNames(names: string[], limit = 3): string {
  const shown = names.slice(0, limit);
  const extra = names.length - shown.length;
  const joined =
    shown.length <= 1
      ? (shown[0] ?? '')
      : `${shown.slice(0, -1).join(', ')} and ${shown[shown.length - 1]}`;
  return extra > 0 ? `${joined} and ${extra} more` : joined;
}

export function summarizeFeasibility(diff: PantryDiff, servingsRequested: number): FeasibilityReport {
  const ingredients = diff.coverage.map(describeIngredient);
  const blockedOn = diff.haveNone.map((entry) => entry.ingredient.display_name);
  const shortOn = diff.haveSome.map((entry) => entry.ingredient.display_name);

  if (blockedOn.length > 0) {
    return {
      verdict: 'blocked',
      headline:
        blockedOn.length === 1
          ? `You can't make this yet -- you have no ${joinNames(blockedOn)}.`
          : `You can't make this yet -- you're missing ${blockedOn.length} things: ${joinNames(blockedOn)}.`,
      servings_requested: servingsRequested,
      servings_possible: null,
      ingredients,
      blocked_on: blockedOn,
      short_on: shortOn,
    };
  }

  if (shortOn.length === 0) {
    return {
      verdict: 'fully_makeable',
      headline: 'You can make this right now.',
      servings_requested: servingsRequested,
      servings_possible: servingsRequested,
      ingredients,
      blocked_on: [],
      short_on: [],
    };
  }

  // Every shortfall is partial, so the recipe scales down to whatever the
  // tightest ingredient allows.
  const tightestRatio = Math.min(
    ...diff.haveSome.map((entry) =>
      entry.requiredCanonical > 0 ? entry.availableCanonical / entry.requiredCanonical : 0,
    ),
  );
  const servingsPossible = Math.floor(servingsRequested * tightestRatio);

  const shortDescriptions = diff.haveSome.map((entry) => {
    const described = describeAmount(entry.shortfallCanonical, entry.canonicalUnit, purchaseContext(entry));
    return `${described} of ${entry.ingredient.display_name}`;
  });

  const headline =
    servingsPossible >= 1
      ? `You can make this, but you'll need ${joinNames(shortDescriptions, 2)} for ${servingsRequested} servings ` +
        `-- or make ${servingsPossible} serving${servingsPossible === 1 ? '' : 's'} with what you have.`
      : `You're short on ${joinNames(shortOn, 2)}: you'll need ${joinNames(shortDescriptions, 2)}.`;

  // When the shortfall is severe enough that not even one serving is possible,
  // the verdict is 'blocked' -- and the items responsible belong in blocked_on,
  // or the "blocked on N items" headline would name a count with nothing behind
  // it.
  if (servingsPossible >= 1) {
    return {
      verdict: 'makeable_scaled_down',
      headline,
      servings_requested: servingsRequested,
      servings_possible: servingsPossible,
      ingredients,
      blocked_on: [],
      short_on: shortOn,
    };
  }

  return {
    verdict: 'blocked',
    headline,
    servings_requested: servingsRequested,
    servings_possible: null,
    ingredients,
    blocked_on: shortOn,
    short_on: shortOn,
  };
}
