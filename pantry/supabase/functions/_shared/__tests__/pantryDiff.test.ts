import { describe, expect, it } from 'vitest';
import type { PantryItemRow } from '../db.ts';
import type { GeneratedIngredient } from '../recipeSchema.ts';
import {
  applyCoverageToIngredients,
  coverageForIngredient,
  diffAgainstPantry,
} from '../pantryDiff.ts';
import type { CanonicalUnit, PantryCategory } from '../units/types.ts';

let lotCounter = 0;

function lot(overrides: {
  name: string;
  remaining: number;
  unit?: CanonicalUnit;
  original?: number;
  category?: PantryCategory;
  isStaple?: boolean;
  expiry?: string | null;
  depletedAt?: string | null;
}): PantryItemRow {
  lotCounter += 1;
  const original = overrides.original ?? overrides.remaining;
  return {
    id: `lot-${lotCounter}`,
    name: overrides.name,
    display_name: overrides.name,
    category: overrides.category ?? 'other',
    purchase_quantity: 1,
    purchase_unit: 'package',
    canonical_quantity_original: original,
    canonical_quantity_remaining: overrides.remaining,
    canonical_unit: overrides.unit ?? 'g',
    quantity_confidence: 'medium',
    acquired_at: '2026-08-01T00:00:00Z',
    storage_location: 'pantry',
    estimated_expiry: overrides.expiry ?? null,
    expiry_confidence: 'medium',
    source: 'manual_entry',
    order_id: null,
    is_staple: overrides.isStaple ?? false,
    depleted_at: overrides.depletedAt ?? null,
    discarded: false,
    low_stock_threshold_canonical: null,
    typical_purchase_canonical: null,
    notes: null,
  };
}

function ingredient(
  name: string,
  quantity: number | string,
  unit: string,
  category: PantryCategory = 'other',
): GeneratedIngredient {
  return {
    name,
    display_name: name,
    quantity,
    unit,
    category,
    // Deliberately the WRONG guess in every fixture, to prove the database wins.
    likely_already_have: true,
  };
}

describe('the three-way answer', () => {
  it('reports have_enough and keeps it out of the cart', () => {
    const result = coverageForIngredient(ingredient('rice', 1, 'cup', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 500, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_enough');
    expect(result.needsPurchase).toBe(false);
    expect(result.shortfallCanonical).toBe(0);
  });

  it('reports have_some with the shortfall, and still buys it', () => {
    // The spec's own example: "you have 80g rice, need 200g".
    const result = coverageForIngredient(ingredient('rice', 200, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 80, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_some');
    expect(result.requiredCanonical).toBeCloseTo(200, 1);
    expect(result.availableCanonical).toBeCloseTo(80, 1);
    expect(result.shortfallCanonical).toBeCloseTo(120, 1);
    // Partial coverage must still add the item to the cart.
    expect(result.needsPurchase).toBe(true);
  });

  it('reports have_none when nothing matches', () => {
    const result = coverageForIngredient(ingredient('saffron', 1, 'pinch', 'spice'), [
      lot({ name: 'rice', remaining: 500 }),
    ]);
    expect(result.status).toBe('have_none');
    expect(result.availableCanonical).toBe(0);
    expect(result.needsPurchase).toBe(true);
  });
});

describe('matching pantry lots to ingredients', () => {
  it('sums several lots of the same item', () => {
    const result = coverageForIngredient(ingredient('rice', 400, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 150, category: 'pantry_dry' }),
      lot({ name: 'rice', remaining: 300, category: 'pantry_dry' }),
    ]);
    expect(result.availableCanonical).toBeCloseTo(450, 1);
    expect(result.status).toBe('have_enough');
  });

  it('matches a more specific pantry name to a general ingredient', () => {
    // Recipe says "rice"; the cupboard holds "jasmine rice".
    const result = coverageForIngredient(ingredient('rice', 100, 'g', 'pantry_dry'), [
      lot({ name: 'jasmine rice', remaining: 500, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_enough');
    expect(result.matchedLots).toHaveLength(1);
  });

  it('matches a general pantry name to a specific ingredient', () => {
    const result = coverageForIngredient(ingredient('jasmine rice', 100, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 500, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_enough');
  });

  it('does not match two different items that share a word', () => {
    const result = coverageForIngredient(ingredient('black bean', 200, 'g', 'canned'), [
      lot({ name: 'green bean', remaining: 500, category: 'produce' }),
    ]);
    expect(result.status).toBe('have_none');
    expect(result.matchedLots).toEqual([]);
  });

  it('prefers exact name matches over loose ones', () => {
    const result = coverageForIngredient(ingredient('rice', 100, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 500, category: 'pantry_dry' }),
      lot({ name: 'wild rice', remaining: 900, category: 'pantry_dry' }),
    ]);
    expect(result.matchedLots).toHaveLength(1);
    expect(result.matchedLots[0]?.name).toBe('rice');
  });

  it('orders matched lots by expiry, soonest first, for FEFO in Phase 5', () => {
    const result = coverageForIngredient(ingredient('cilantro', 10, 'g', 'produce'), [
      lot({ name: 'cilantro', remaining: 45, expiry: null, category: 'produce' }),
      lot({ name: 'cilantro', remaining: 45, expiry: '2026-09-10', category: 'produce' }),
      lot({ name: 'cilantro', remaining: 45, expiry: '2026-09-02', category: 'produce' }),
    ]);
    expect(result.matchedLots.map((row) => row.estimated_expiry)).toEqual([
      '2026-09-02',
      '2026-09-10',
      null, // unknown expiry goes last, not first
    ]);
  });

  it('ignores depleted lots entirely', () => {
    const diff = diffAgainstPantry(
      [ingredient('rice', 100, 'g', 'pantry_dry')],
      [lot({ name: 'rice', remaining: 500, depletedAt: '2026-08-20T00:00:00Z', category: 'pantry_dry' })],
    );
    expect(diff.coverage[0]?.status).toBe('have_none');
  });
});

describe('unit safety', () => {
  it('refuses to count a lot measured in a different canonical unit', () => {
    // The pantry has 12 eggs by count; a recipe asking for grams of egg must
    // not silently consume them. This is the exact class of bug the canonical
    // unit layer exists to prevent.
    const result = coverageForIngredient(
      { ...ingredient('egg', 200, 'g', 'dairy') },
      [lot({ name: 'egg', remaining: 12, unit: 'count', category: 'dairy' })],
    );
    expect(result.unitMismatch).toBe(true);
    expect(result.availableCanonical).toBe(0);
    expect(result.status).toBe('have_none');
    expect(result.warnings.join(' ')).toMatch(/not counted/i);
  });

  it('compares a purchase unit against a recipe unit correctly', () => {
    // Bought a pound of chicken breast; the recipe wants two breasts.
    const result = coverageForIngredient(ingredient('chicken breast', 2, '', 'meat'), [
      lot({ name: 'chicken breast', remaining: 453.59, category: 'meat' }),
    ]);
    expect(result.canonicalUnit).toBe('g');
    expect(result.requiredCanonical).toBeCloseTo(350, 0);
    expect(result.status).toBe('have_enough');
  });
});

describe('staples', () => {
  it('never asks you to buy a staple', () => {
    // Staples are exempt from depletion, so their remaining figure never moves
    // and comparing against it would be meaningless.
    const result = coverageForIngredient(ingredient('salt', 1, 'pinch', 'spice'), [
      lot({ name: 'salt', remaining: 5, original: 737, isStaple: true, category: 'spice' }),
    ]);
    expect(result.isStaple).toBe(true);
    expect(result.status).toBe('have_enough');
    expect(result.needsPurchase).toBe(false);
  });
});

describe('tolerance', () => {
  it('does not call a 1% gap a shortfall', () => {
    // Needing 200 g and having 198 g is not a shopping trip.
    const result = coverageForIngredient(ingredient('rice', 200, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 198, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_enough');
  });

  it('does call a 20% gap a shortfall', () => {
    const result = coverageForIngredient(ingredient('rice', 200, 'g', 'pantry_dry'), [
      lot({ name: 'rice', remaining: 160, category: 'pantry_dry' }),
    ]);
    expect(result.status).toBe('have_some');
  });
});

describe('scaling', () => {
  it('scales requirements for a different number of servings', () => {
    const pantry = [lot({ name: 'rice', remaining: 300, category: 'pantry_dry' })];
    const single = coverageForIngredient(ingredient('rice', 200, 'g', 'pantry_dry'), pantry);
    const doubled = coverageForIngredient(ingredient('rice', 200, 'g', 'pantry_dry'), pantry, { scale: 2 });

    expect(single.status).toBe('have_enough');
    expect(doubled.requiredCanonical).toBeCloseTo(400, 1);
    expect(doubled.status).toBe('have_some');
    expect(doubled.shortfallCanonical).toBeCloseTo(100, 1);
  });
});

describe('diffAgainstPantry', () => {
  const pantry = [
    lot({ name: 'rice', remaining: 80, category: 'pantry_dry' }),
    lot({ name: 'chicken breast', remaining: 500, category: 'meat' }),
    lot({ name: 'salt', remaining: 300, isStaple: true, category: 'spice' }),
  ];
  const ingredients = [
    ingredient('rice', 200, 'g', 'pantry_dry'),
    ingredient('chicken breast', 2, '', 'meat'),
    ingredient('salt', 1, 'tsp', 'spice'),
    ingredient('saffron', 1, 'pinch', 'spice'),
  ];

  it('buckets every ingredient into exactly one group', () => {
    const diff = diffAgainstPantry(ingredients, pantry);
    expect(diff.haveEnough.map((c) => c.normalizedName).sort()).toEqual(['chicken breast', 'salt']);
    expect(diff.haveSome.map((c) => c.normalizedName)).toEqual(['rice']);
    expect(diff.haveNone.map((c) => c.normalizedName)).toEqual(['saffron']);
    expect(diff.needToBuy.map((c) => c.normalizedName).sort()).toEqual(['rice', 'saffron']);
    expect(
      diff.haveEnough.length + diff.haveSome.length + diff.haveNone.length,
    ).toBe(ingredients.length);
  });

  it('overrides whatever the model guessed about the pantry', () => {
    // Every fixture claims likely_already_have: true. The database disagrees.
    const applied = applyCoverageToIngredients(diffAgainstPantry(ingredients, pantry));
    expect(applied.map((entry) => entry.likely_already_have)).toEqual([false, true, true, false]);
    expect(applied[0]).toMatchObject({
      coverage_status: 'have_some',
      required_canonical: 200,
      available_canonical: 80,
      shortfall_canonical: 120,
      canonical_unit: 'g',
    });
  });

  it('handles an empty pantry without special-casing', () => {
    const diff = diffAgainstPantry(ingredients, []);
    expect(diff.needToBuy).toHaveLength(ingredients.length);
    expect(diff.haveEnough).toHaveLength(0);
  });

  it('handles a recipe with no ingredients', () => {
    const diff = diffAgainstPantry([], pantry);
    expect(diff.coverage).toEqual([]);
    expect(diff.needToBuy).toEqual([]);
  });
});
