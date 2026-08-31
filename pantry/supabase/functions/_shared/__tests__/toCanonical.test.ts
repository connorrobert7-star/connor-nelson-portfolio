import { describe, expect, it } from 'vitest';
import { toCanonical, toCanonicalFromText } from '../units/toCanonical.ts';

/**
 * The awkward cases named in the spec. If these are right the rest of the
 * project is straightforward; if they are wrong nothing downstream can be
 * trusted, because every quantity in the system passes through here.
 */
describe('toCanonical - the awkward cases', () => {
  const cases: Array<{
    text: string;
    quantity: number;
    unit: string;
    confidence: string;
    why: string;
  }> = [
    { text: '1 bunch cilantro', quantity: 45, unit: 'g', confidence: 'low', why: 'a bunch is inherently fuzzy' },
    { text: '2 cloves garlic', quantity: 10, unit: 'g', confidence: 'medium', why: 'cloves vary by head' },
    { text: '1 lb chicken breast', quantity: 453.59, unit: 'g', confidence: 'high', why: 'a pound is a definition' },
    { text: '2 chicken breasts', quantity: 350, unit: 'g', confidence: 'medium', why: 'breasts run 150-225g' },
    { text: '1/2 cup flour', quantity: 60, unit: 'g', confidence: 'high', why: 'standard reference density' },
    { text: '3 tbsp olive oil', quantity: 44.36, unit: 'ml', confidence: 'high', why: 'pure volume arithmetic' },
    { text: '1 can black beans', quantity: 425, unit: 'g', confidence: 'high', why: 'a 15oz can is standardized' },
    { text: 'a pinch of salt', quantity: 0.36, unit: 'g', confidence: 'low', why: 'a pinch is a pinch' },
    { text: '1 head of lettuce', quantity: 300, unit: 'g', confidence: 'low', why: 'heads vary enormously' },
    { text: '2 large eggs', quantity: 2, unit: 'count', confidence: 'high', why: 'eggs are counted, not weighed' },
  ];

  it.each(cases)('$text -> $quantity $unit ($confidence: $why)', ({ text, quantity, unit, confidence }) => {
    const result = toCanonicalFromText(text);
    expect(result.canonicalQuantity).toBeCloseTo(quantity, 1);
    expect(result.canonicalUnit).toBe(unit);
    expect(result.confidence).toBe(confidence);
  });
});

describe('toCanonical - the invariant that makes the pantry work', () => {
  it('lands a purchase unit and a recipe unit on the same canonical unit', () => {
    // Bought "1 lb chicken breast", cooked "2 chicken breasts". If these two do
    // not agree on a unit, the subtraction in Phase 5 is meaningless.
    const bought = toCanonicalFromText('1 lb chicken breast');
    const cooked = toCanonicalFromText('2 chicken breasts');

    expect(bought.canonicalUnit).toBe(cooked.canonicalUnit);
    expect(bought.canonicalQuantity - cooked.canonicalQuantity).toBeCloseTo(103.59, 1);
  });

  it('never asks you to subtract a tablespoon from a bunch', () => {
    const bought = toCanonicalFromText('1 bunch cilantro');
    const used = toCanonicalFromText('2 tbsp chopped cilantro');

    expect(bought.canonicalUnit).toBe('g');
    expect(used.canonicalUnit).toBe('g');
    expect(used.canonicalQuantity).toBeCloseTo(2, 1);
    expect(bought.canonicalQuantity - used.canonicalQuantity).toBeCloseTo(43, 1);
  });

  it('keeps eggs in counts on both sides', () => {
    const bought = toCanonicalFromText('1 dozen eggs');
    const used = toCanonicalFromText('3 eggs');

    expect(bought).toMatchObject({ canonicalQuantity: 12, canonicalUnit: 'count' });
    expect(used).toMatchObject({ canonicalQuantity: 3, canonicalUnit: 'count' });
  });

  it('does not let volume arithmetic answer for a weight-measured item', () => {
    // A cup of spinach is 30 g of spinach, not 236 ml of spinach.
    const result = toCanonical('spinach', 1, 'cup');
    expect(result.canonicalUnit).toBe('g');
    expect(result.canonicalQuantity).toBeCloseTo(30, 1);
    expect(result.path).toBe('item-rule');
  });
});

describe('toCanonical - density path', () => {
  it('uses an item density for a volume unit it has no explicit rule for', () => {
    // No "pint of flour" rule exists; it goes pint -> ml -> grams via density.
    const result = toCanonical('flour', 1, 'pint');
    expect(result.path).toBe('item-density');
    expect(result.canonicalUnit).toBe('g');
    expect(result.canonicalQuantity).toBeCloseTo(240, 0);
  });

  it('distinguishes a cup of flour from a cup of rice from a cup of sugar', () => {
    expect(toCanonical('flour', 1, 'cup').canonicalQuantity).toBeCloseTo(120, 1);
    expect(toCanonical('rice', 1, 'cup').canonicalQuantity).toBeCloseTo(185, 1);
    expect(toCanonical('sugar', 1, 'cup').canonicalQuantity).toBeCloseTo(200, 1);
  });

  it('reads bare "oz" as fluid ounces for a volume-measured item', () => {
    // A 16 oz bottle of olive oil is 16 FLUID ounces.
    const result = toCanonical('olive oil', 16, 'oz');
    expect(result.canonicalUnit).toBe('ml');
    expect(result.canonicalQuantity).toBeCloseTo(473.18, 1);
    expect(result.warnings.join(' ')).toMatch(/fluid ounces/i);
  });

  it('still reads bare "oz" as weight for a weight-measured item', () => {
    const result = toCanonical('cheddar cheese', 8, 'oz');
    expect(result.canonicalUnit).toBe('g');
    expect(result.canonicalQuantity).toBeCloseTo(226.8, 1);
  });
});

describe('toCanonical - fallbacks degrade honestly', () => {
  it('falls back to a category average at low confidence, never higher', () => {
    const result = toCanonical('dragonfruit', 1, 'count', { category: 'produce' });
    expect(result.path).toBe('category-rule');
    expect(result.canonicalUnit).toBe('g');
    expect(result.canonicalQuantity).toBeCloseTo(120, 1);
    expect(result.confidence).toBe('low');
    expect(result.warnings.join(' ')).toMatch(/category average/i);
  });

  it('still does exact arithmetic for an unknown item in a known unit', () => {
    // Not knowing what "flarn" is does not make a pound stop being 453.59 g.
    const result = toCanonical('flarn', 2, 'oz');
    expect(result).toMatchObject({ canonicalUnit: 'g', confidence: 'high', path: 'universal' });
    expect(result.canonicalQuantity).toBeCloseTo(56.7, 1);
  });

  it('records an unresolvable unit as a raw count and says what is missing', () => {
    const result = toCanonical('flarn', 3, 'smidgen');
    expect(result).toMatchObject({ canonicalUnit: 'count', confidence: 'low', path: 'unresolved' });
    expect(result.canonicalQuantity).toBe(3);
    expect(result.warnings.join(' ')).toMatch(/unit_conversions/);
  });

  it('propagates a low-confidence quantity parse into the result', () => {
    const result = toCanonical('garlic', 'a few', 'cloves');
    expect(result.canonicalQuantity).toBeCloseTo(15, 1);
    // The rule is medium but the quantity was a guess, so the answer is a guess.
    expect(result.confidence).toBe('low');
  });
});

describe('toCanonical - size words', () => {
  it('scales a count-to-weight conversion by the stated size', () => {
    const medium = toCanonical('onion', 1, 'medium');
    const large = toCanonical('onion', 1, 'large');
    expect(medium.canonicalQuantity).toBeCloseTo(150, 1);
    expect(large.canonicalQuantity).toBeGreaterThan(medium.canonicalQuantity);
  });

  it('ignores size when the canonical unit is a count', () => {
    // Two large eggs are still two eggs.
    expect(toCanonical('egg', 2, 'large').canonicalQuantity).toBe(2);
    expect(toCanonical('egg', 2, 'small').canonicalQuantity).toBe(2);
  });
});

describe('toCanonical - word-boundary matching', () => {
  it('does not match an item pattern inside a longer word', () => {
    // 'egg' must not match 'eggplant'; 'pea' must not match 'peach'.
    expect(toCanonical('eggplant', 1, 'count').canonicalQuantity).toBeCloseTo(450, 1);
    const peach = toCanonical('peach', 1, 'count', { category: 'produce' });
    expect(peach.path).not.toBe('item-rule');
  });

  it('prefers the most specific matching pattern', () => {
    // 'black bean' beats 'bean'; 'cherry tomato' beats 'tomato'.
    expect(toCanonical('black beans', 1, 'cup').canonicalQuantity).toBeCloseTo(190, 1);
    expect(toCanonical('cherry tomatoes', 1, 'count').canonicalQuantity).toBeCloseTo(17, 1);
    expect(toCanonical('tomatoes', 1, 'count').canonicalQuantity).toBeCloseTo(120, 1);
  });
});

describe('toCanonical - never throws', () => {
  it('survives anything the model or a web page can hand it', () => {
    const inputs: Array<[string, unknown, unknown]> = [
      ['', '', ''],
      ['   ', null, null],
      ['salt', 'to taste', undefined],
      ['???', '???', '???'],
      ['cilantro', -1, 'bunch'],
      ['flour', Number.NaN, 'cup'],
      ['a'.repeat(500), 1, 'cup'],
    ];

    for (const [name, quantity, unit] of inputs) {
      const result = toCanonical(name, quantity as never, unit as never);
      expect(Number.isFinite(result.canonicalQuantity)).toBe(true);
      expect(result.canonicalQuantity).toBeGreaterThanOrEqual(0);
      expect(['g', 'ml', 'count']).toContain(result.canonicalUnit);
    }
  });
});
