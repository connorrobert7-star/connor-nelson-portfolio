import { describe, expect, it } from 'vitest';
import type { PantryItemRow } from '../db.ts';
import { summarizeFeasibility } from '../feasibility.ts';
import { diffAgainstPantry } from '../pantryDiff.ts';
import type { GeneratedIngredient } from '../recipeSchema.ts';
import type { CanonicalUnit, PantryCategory } from '../units/types.ts';

let counter = 0;

function lot(o: {
  name: string;
  remaining: number;
  original?: number;
  unit?: CanonicalUnit;
  category?: PantryCategory;
  purchaseQuantity?: number;
  purchaseUnit?: string;
  isStaple?: boolean;
}): PantryItemRow {
  counter += 1;
  const original = o.original ?? o.remaining;
  return {
    id: `lot-${counter}`,
    name: o.name,
    display_name: o.name,
    category: o.category ?? 'other',
    purchase_quantity: o.purchaseQuantity ?? 1,
    purchase_unit: o.purchaseUnit ?? 'bag',
    canonical_quantity_original: original,
    canonical_quantity_remaining: o.remaining,
    canonical_unit: o.unit ?? 'g',
    quantity_confidence: 'medium',
    acquired_at: '2026-08-25T00:00:00Z',
    storage_location: 'pantry',
    estimated_expiry: null,
    expiry_confidence: 'medium',
    source: 'manual_entry',
    order_id: null,
    is_staple: o.isStaple ?? false,
    depleted_at: null,
    discarded: false,
    low_stock_threshold_canonical: null,
    typical_purchase_canonical: null,
    notes: null,
    created_at: '2026-08-25T00:00:00Z',
    updated_at: '2026-08-25T00:00:00Z',
  };
}

const ing = (
  name: string,
  quantity: number | string,
  unit: string,
  category: PantryCategory = 'other',
): GeneratedIngredient => ({
  name,
  display_name: name,
  quantity,
  unit,
  category,
  likely_already_have: false,
});

describe('summarizeFeasibility', () => {
  it('says plainly when you can make it', () => {
    const diff = diffAgainstPantry(
      [ing('rice', 100, 'g', 'pantry_dry')],
      [lot({ name: 'rice', remaining: 500, category: 'pantry_dry' })],
    );
    const report = summarizeFeasibility(diff, 2);
    expect(report.verdict).toBe('fully_makeable');
    expect(report.headline).toBe('You can make this right now.');
    expect(report.ingredients[0]?.status).toBe('sufficient');
  });

  it('expresses a shortfall in purchase units, not grams', () => {
    // A bunch of cilantro was bought and came to 45 g; 22 g of it is left.
    const diff = diffAgainstPantry(
      [ing('cilantro', 1, 'bunch', 'produce')],
      [
        lot({
          name: 'cilantro',
          remaining: 22,
          original: 45,
          category: 'produce',
          purchaseQuantity: 1,
          purchaseUnit: 'bunch',
        }),
      ],
    );
    const report = summarizeFeasibility(diff, 4);

    expect(report.verdict).toBe('makeable_scaled_down');
    expect(report.ingredients[0]?.status).toBe('short');
    // The point: "about half a bunch", never "23 g".
    expect(report.ingredients[0]?.shortfall_description).toBe('about half a bunch');
    expect(report.headline).toMatch(/half a bunch/);
    expect(report.headline).not.toMatch(/\d+ g\b/);
  });

  it('reports how many servings the pantry actually supports', () => {
    const diff = diffAgainstPantry(
      [ing('rice', 400, 'g', 'pantry_dry')],
      [lot({ name: 'rice', remaining: 200, category: 'pantry_dry' })],
    );
    const report = summarizeFeasibility(diff, 4);
    expect(report.verdict).toBe('makeable_scaled_down');
    expect(report.servings_possible).toBe(2);
    expect(report.headline).toMatch(/2 servings/);
  });

  it('is blocked when something is missing entirely', () => {
    const diff = diffAgainstPantry(
      [ing('rice', 100, 'g', 'pantry_dry'), ing('saffron', 1, 'pinch', 'spice')],
      [lot({ name: 'rice', remaining: 500, category: 'pantry_dry' })],
    );
    const report = summarizeFeasibility(diff, 2);
    expect(report.verdict).toBe('blocked');
    expect(report.blocked_on).toEqual(['saffron']);
    expect(report.headline).toMatch(/no saffron/);
  });

  it('counts the missing items when there are several', () => {
    const diff = diffAgainstPantry(
      [ing('saffron', 1, 'pinch', 'spice'), ing('lamb', 500, 'g', 'meat'), ing('mint', 1, 'bunch', 'produce')],
      [],
    );
    const report = summarizeFeasibility(diff, 2);
    expect(report.verdict).toBe('blocked');
    expect(report.headline).toMatch(/missing 3 things/);
  });

  it('describes a missing ingredient in the recipe’s own words', () => {
    // Nothing on hand means no purchase unit to describe it in, so use what
    // the recipe asked for -- which is what you would write on a list anyway.
    const diff = diffAgainstPantry([ing('garlic', 2, 'cloves', 'produce')], []);
    const report = summarizeFeasibility(diff, 2);
    expect(report.ingredients[0]?.shortfall_description).toBe('2 cloves garlic');
  });

  it('treats a staple as sufficient without mentioning it', () => {
    const diff = diffAgainstPantry(
      [ing('salt', 1, 'pinch', 'spice')],
      [lot({ name: 'salt', remaining: 5, original: 737, category: 'spice', isStaple: true })],
    );
    const report = summarizeFeasibility(diff, 2);
    expect(report.verdict).toBe('fully_makeable');
  });

  it('is blocked when a shortfall is too severe to scale down to one serving', () => {
    const diff = diffAgainstPantry(
      [ing('rice', 400, 'g', 'pantry_dry')],
      [lot({ name: 'rice', remaining: 20, category: 'pantry_dry' })],
    );
    const report = summarizeFeasibility(diff, 2);
    expect(report.verdict).toBe('blocked');
    expect(report.servings_possible).toBeNull();
    // The headline says "blocked", so the list has to back it up.
    expect(report.blocked_on).toEqual(['rice']);
  });

  it('handles a recipe with no ingredients without claiming success falsely', () => {
    const report = summarizeFeasibility(diffAgainstPantry([], []), 2);
    expect(report.verdict).toBe('fully_makeable');
    expect(report.ingredients).toEqual([]);
  });
});
