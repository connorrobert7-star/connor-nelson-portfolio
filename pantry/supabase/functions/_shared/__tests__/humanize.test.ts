import { describe, expect, it } from 'vitest';
import { describeAmount, describeDaysUntil, describeProportion, daysUntil } from '../humanize.ts';

describe('describeAmount - shortfalls in purchase units, never grams', () => {
  // 1 bunch of cilantro was bought and came to 45 g.
  const cilantro = { purchaseQuantity: 1, purchaseUnit: 'bunch', canonicalOriginal: 45 };

  it('says "about half a bunch" rather than "22 g"', () => {
    expect(describeAmount(22, 'g', cilantro)).toBe('about half a bunch');
  });

  it('handles quarters and three quarters', () => {
    expect(describeAmount(11, 'g', cilantro)).toBe('about a quarter of a bunch');
    expect(describeAmount(34, 'g', cilantro)).toBe('about three quarters of a bunch');
  });

  it('pluralizes irregular units correctly', () => {
    expect(describeAmount(90, 'g', cilantro)).toBe('about 2 bunches');
    expect(describeAmount(45, 'g', cilantro)).toBe('about 1 bunch');
  });

  it('describes a sliver without pretending to precision', () => {
    expect(describeAmount(3, 'g', cilantro)).toBe('a little bunch');
  });

  it('falls back to canonical units when there is nothing to convert against', () => {
    expect(describeAmount(120, 'g')).toBe('120 g');
    expect(describeAmount(1500, 'g')).toBe('1.5 kg');
    expect(describeAmount(2, 'count')).toBe('2 items');
  });

  it('does not dress up a canonical purchase unit as a fraction', () => {
    // Bought "500 g", so "about half a g" would be nonsense.
    expect(describeAmount(250, 'g', { purchaseQuantity: 500, purchaseUnit: 'g', canonicalOriginal: 500 })).toBe('250 g');
  });

  it('handles a multi-unit purchase', () => {
    // Bought 2 lb of chicken = 907 g, so 453 g is about 1 lb.
    const chicken = { purchaseQuantity: 2, purchaseUnit: 'lb', canonicalOriginal: 907 };
    expect(describeAmount(453, 'g', chicken)).toBe('about 1 lb');
  });

  it('never returns a negative or nonsense amount', () => {
    expect(describeAmount(0, 'g', cilantro)).toBe('no g');
    expect(describeAmount(Number.NaN, 'g', cilantro)).toBe('no g');
  });
});

describe('describeProportion', () => {
  it('reads as a proportion rather than a bare gram count', () => {
    expect(describeProportion(60, 100)).toBe('~60% left');
    expect(describeProportion(100, 100)).toBe('unopened');
    expect(describeProportion(0, 100)).toBe('none left');
    expect(describeProportion(50, 0)).toBe('unknown');
  });
});

describe('describeDaysUntil', () => {
  it('reads naturally around today', () => {
    expect(describeDaysUntil(0)).toBe('today');
    expect(describeDaysUntil(1)).toBe('tomorrow');
    expect(describeDaysUntil(3)).toBe('in about 3 days');
    expect(describeDaysUntil(-1)).toBe('yesterday');
    expect(describeDaysUntil(-4)).toBe('about 4 days ago');
    expect(describeDaysUntil(null)).toBe('no estimate');
  });
});

describe('daysUntil', () => {
  const today = new Date('2026-09-01T18:30:00Z');

  it('counts calendar days, not elapsed hours', () => {
    // 18:30 today to 00:00 tomorrow is under 6 hours but is still "1 day".
    expect(daysUntil('2026-09-02', today)).toBe(1);
    expect(daysUntil('2026-09-01', today)).toBe(0);
    expect(daysUntil('2026-08-30', today)).toBe(-2);
  });

  it('returns null for a missing or unparseable date', () => {
    expect(daysUntil(null, today)).toBeNull();
    expect(daysUntil('not-a-date', today)).toBeNull();
  });
});
