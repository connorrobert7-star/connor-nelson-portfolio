import { describe, expect, it } from 'vitest';
import { parseQuantity } from '../units/quantity.js';

describe('parseQuantity', () => {
  it('parses plain numbers at full confidence', () => {
    expect(parseQuantity(2)).toMatchObject({ value: 2, confidence: 'high' });
    expect(parseQuantity('3')).toMatchObject({ value: 3, confidence: 'high' });
    expect(parseQuantity('0.5')).toMatchObject({ value: 0.5, confidence: 'high' });
  });

  it('parses fractions and mixed numbers', () => {
    expect(parseQuantity('1/2').value).toBeCloseTo(0.5);
    expect(parseQuantity('3/4').value).toBeCloseTo(0.75);
    expect(parseQuantity('1 1/2').value).toBeCloseTo(1.5);
    expect(parseQuantity('2 2/3').value).toBeCloseTo(2 + 2 / 3);
  });

  it('parses unicode fractions, including glued ones', () => {
    expect(parseQuantity('½').value).toBeCloseTo(0.5);
    expect(parseQuantity('1½').value).toBeCloseTo(1.5);
    expect(parseQuantity('¾').value).toBeCloseTo(0.75);
  });

  it('collapses a range to its midpoint and says so', () => {
    const result = parseQuantity('2-3');
    expect(result.value).toBeCloseTo(2.5);
    // A midpoint is a choice, not a measurement.
    expect(result.confidence).toBe('medium');
    expect(result.warnings.join(' ')).toMatch(/midpoint/i);
  });

  it('parses number words exactly', () => {
    expect(parseQuantity('two')).toMatchObject({ value: 2, confidence: 'high' });
    expect(parseQuantity('a')).toMatchObject({ value: 1, confidence: 'high' });
    expect(parseQuantity('dozen')).toMatchObject({ value: 12, confidence: 'high' });
    expect(parseQuantity('half').value).toBeCloseTo(0.5);
  });

  it('drops to low confidence for deliberately vague words', () => {
    expect(parseQuantity('a couple')).toMatchObject({ value: 2, confidence: 'low' });
    expect(parseQuantity('a few')).toMatchObject({ value: 3, confidence: 'low' });
    expect(parseQuantity('several')).toMatchObject({ value: 3, confidence: 'low' });
  });

  it('never throws and never returns a non-positive quantity', () => {
    for (const input of [null, undefined, '', '   ', 'lots', 0, -5, Number.NaN, 'to taste']) {
      const result = parseQuantity(input as never);
      expect(result.value).toBeGreaterThan(0);
      expect(result.confidence).toBe('low');
    }
  });
});
