import { describe, expect, it } from 'vitest';
import type { PantryItemRow } from '../db.ts';
import { DEFAULT_WEIGHTS, rankByWasteUrgency, scoreWasteUrgency } from '../wasteScore.ts';

const TODAY = new Date('2026-09-01T12:00:00Z');
let counter = 0;

function lot(o: {
  name: string;
  remaining: number;
  original: number;
  expiry?: string | null;
  isStaple?: boolean;
  depletedAt?: string | null;
}): PantryItemRow {
  counter += 1;
  return {
    id: `lot-${counter}`,
    name: o.name,
    display_name: o.name,
    category: 'produce',
    purchase_quantity: 1,
    purchase_unit: 'bag',
    canonical_quantity_original: o.original,
    canonical_quantity_remaining: o.remaining,
    canonical_unit: 'g',
    quantity_confidence: 'medium',
    acquired_at: '2026-08-25T00:00:00Z',
    storage_location: 'refrigerated',
    estimated_expiry: o.expiry === undefined ? '2026-09-05' : o.expiry,
    expiry_confidence: 'medium',
    source: 'manual_entry',
    order_id: null,
    is_staple: o.isStaple ?? false,
    depleted_at: o.depletedAt ?? null,
    discarded: false,
    low_stock_threshold_canonical: null,
    typical_purchase_canonical: null,
    notes: null,
    created_at: '2026-08-25T00:00:00Z',
    updated_at: '2026-08-25T00:00:00Z',
  };
}

describe('scoreWasteUrgency', () => {
  it('ranks a nearly-full bag expiring in 2 days above a nearly-empty jar expiring in 3 months', () => {
    // This is the spec's own example, and the whole reason the score exists.
    const spinach = scoreWasteUrgency(
      lot({ name: 'spinach', remaining: 135, original: 142, expiry: '2026-09-03' }),
      TODAY,
    );
    const mustard = scoreWasteUrgency(
      lot({ name: 'mustard', remaining: 15, original: 250, expiry: '2026-12-01' }),
      TODAY,
    );
    expect(spinach.score).toBeGreaterThan(mustard.score * 10);
  });

  it('halves urgency every half-life', () => {
    const atThreeDays = scoreWasteUrgency(lot({ name: 'a', remaining: 100, original: 100, expiry: '2026-09-04' }), TODAY);
    const atSixDays = scoreWasteUrgency(lot({ name: 'b', remaining: 100, original: 100, expiry: '2026-09-07' }), TODAY);
    expect(atThreeDays.urgency).toBeCloseTo(0.5, 2);
    expect(atSixDays.urgency).toBeCloseTo(0.25, 2);
  });

  it('scores something already past its estimated date at maximum urgency', () => {
    const scored = scoreWasteUrgency(lot({ name: 'a', remaining: 100, original: 100, expiry: '2026-08-30' }), TODAY);
    expect(scored.urgency).toBe(DEFAULT_WEIGHTS.expiredScore);
    expect(scored.daysLeft).toBeLessThan(0);
  });

  it('weights by how much is left', () => {
    const full = scoreWasteUrgency(lot({ name: 'a', remaining: 100, original: 100, expiry: '2026-09-03' }), TODAY);
    const nearlyGone = scoreWasteUrgency(lot({ name: 'b', remaining: 10, original: 100, expiry: '2026-09-03' }), TODAY);
    expect(full.score).toBeCloseTo(nearlyGone.score * 10, 2);
  });

  it('barely scores an item with no expiry estimate', () => {
    const scored = scoreWasteUrgency(lot({ name: 'a', remaining: 100, original: 100, expiry: null }), TODAY);
    expect(scored.urgency).toBe(DEFAULT_WEIGHTS.unknownExpiryUrgency);
    expect(scored.reason).toMatch(/no expiry estimate/i);
  });

  it('never flags a staple', () => {
    // Staples are exempt from expiry nagging, so they cannot be at risk.
    const scored = scoreWasteUrgency(
      lot({ name: 'olive oil', remaining: 500, original: 500, expiry: '2026-09-02', isStaple: true }),
      TODAY,
    );
    expect(scored.score).toBe(0);
  });

  it('respects tuned weights', () => {
    // The whole point of exposing the weights is that they will want tuning.
    const item = lot({ name: 'a', remaining: 50, original: 100, expiry: '2026-09-04' });
    const flat = scoreWasteUrgency(item, TODAY, { ...DEFAULT_WEIGHTS, quantityExponent: 0 });
    const steep = scoreWasteUrgency(item, TODAY, { ...DEFAULT_WEIGHTS, quantityExponent: 2 });
    expect(flat.score).toBeGreaterThan(steep.score);
  });
});

describe('rankByWasteUrgency', () => {
  it('sorts most urgent first and drops what cannot be saved', () => {
    const ranked = rankByWasteUrgency(
      [
        // Not at risk in any useful sense; excluded by minScore.
        lot({ name: 'rice', remaining: 900, original: 900, expiry: '2028-01-01' }),
        lot({ name: 'spinach', remaining: 135, original: 142, expiry: '2026-09-02' }),
        lot({ name: 'feta', remaining: 100, original: 200, expiry: '2026-09-06' }),
        // Below the 5% floor: there is nothing left to save.
        lot({ name: 'scraps', remaining: 2, original: 200, expiry: '2026-09-02' }),
        lot({ name: 'salt', remaining: 700, original: 737, expiry: '2026-09-02', isStaple: true }),
        lot({ name: 'eaten', remaining: 0, original: 200, expiry: '2026-09-02', depletedAt: '2026-08-30T00:00:00Z' }),
      ],
      TODAY,
    );

    expect(ranked.map((entry) => entry.item.name)).toEqual(['spinach', 'feta']);
    expect(ranked[0]!.score).toBeGreaterThan(ranked[1]!.score);
  });

  it('returns an empty list when nothing is at risk', () => {
    expect(rankByWasteUrgency([], TODAY)).toEqual([]);
    // A full cupboard of long-life goods is not a leftovers problem.
    expect(
      rankByWasteUrgency([lot({ name: 'rice', remaining: 900, original: 900, expiry: '2028-01-01' })], TODAY),
    ).toEqual([]);
  });

  it('lets minScore be tuned to widen the net', () => {
    const distant = [lot({ name: 'rice', remaining: 900, original: 900, expiry: '2028-01-01' })];
    expect(rankByWasteUrgency(distant, TODAY, { ...DEFAULT_WEIGHTS, minScore: 0 })).toHaveLength(1);
  });
});
