import { describe, expect, it } from 'vitest';
import { planDepletion } from '../consumption.ts';

const lot = (original: number, remaining: number, isStaple = false) => ({
  canonical_quantity_original: original,
  canonical_quantity_remaining: remaining,
  is_staple: isStaple,
});

describe('planDepletion', () => {
  it('subtracts a normal amount', () => {
    expect(planDepletion(lot(500, 500), 200)).toMatchObject({
      newRemaining: 300,
      applied: 200,
      shortfall: 0,
      depleted: false,
      skipped: false,
    });
  });

  it('skips staples entirely', () => {
    // "A pinch of salt" must not decrement anything.
    expect(planDepletion(lot(737, 700, true), 6)).toMatchObject({
      newRemaining: 700,
      applied: 0,
      skipped: true,
    });
  });

  it('clamps at zero and reports the shortfall instead of going negative', () => {
    // Going negative means the pantry data has drifted, which is real
    // information -- it is recorded, not silently floored away.
    const plan = planDepletion(lot(500, 80), 200);
    expect(plan.newRemaining).toBe(0);
    expect(plan.applied).toBe(80);
    expect(plan.shortfall).toBe(120);
    expect(plan.depleted).toBe(true);
  });

  it('treats the last 5% as gone', () => {
    // Nobody cooks with 4 g of leftover onion, and a sliver left behind
    // lingers forever and pollutes every feasibility check.
    const plan = planDepletion(lot(150, 150), 146);
    expect(plan.applied).toBe(146);
    expect(plan.newRemaining).toBe(0);
    expect(plan.depleted).toBe(true);
  });

  it('does not deplete when comfortably above the floor', () => {
    const plan = planDepletion(lot(150, 150), 100);
    expect(plan.newRemaining).toBe(50);
    expect(plan.depleted).toBe(false);
  });

  it('handles taking exactly everything', () => {
    expect(planDepletion(lot(200, 200), 200)).toMatchObject({
      newRemaining: 0,
      applied: 200,
      shortfall: 0,
      depleted: true,
    });
  });

  it('is a no-op for a zero or negative request', () => {
    expect(planDepletion(lot(200, 200), 0).applied).toBe(0);
    expect(planDepletion(lot(200, 200), -50).applied).toBe(0);
  });

  it('handles an already-empty lot without inventing a negative', () => {
    const plan = planDepletion(lot(200, 0), 50);
    expect(plan.applied).toBe(0);
    expect(plan.shortfall).toBe(50);
    expect(plan.newRemaining).toBe(0);
  });

  it('keeps fractional counts sane', () => {
    const plan = planDepletion(lot(12, 12), 3);
    expect(plan.newRemaining).toBe(9);
    expect(plan.depleted).toBe(false);
  });
});
