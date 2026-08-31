import { describe, expect, it } from 'vitest';
import { defaultLowStockThreshold, isEffectivelyDepleted } from '../units/thresholds.ts';

describe('defaultLowStockThreshold', () => {
  it('uses 25% for proteins and produce', () => {
    expect(defaultLowStockThreshold('produce', 400)).toBe(100);
    expect(defaultLowStockThreshold('meat', 400)).toBe(100);
  });

  it('uses 20% for dry goods and condiments', () => {
    expect(defaultLowStockThreshold('pantry_dry', 1000)).toBe(200);
    expect(defaultLowStockThreshold('condiment', 500)).toBe(100);
  });

  it('exempts spices entirely', () => {
    expect(defaultLowStockThreshold('spice', 45)).toBeNull();
  });

  it('returns null rather than a nonsense threshold for a bad quantity', () => {
    expect(defaultLowStockThreshold('produce', 0)).toBeNull();
    expect(defaultLowStockThreshold('produce', Number.NaN)).toBeNull();
  });
});

describe('isEffectivelyDepleted', () => {
  it('treats the last 5% as gone', () => {
    // Nobody cooks with 4 g of leftover onion.
    expect(isEffectivelyDepleted(4, 150)).toBe(true);
    expect(isEffectivelyDepleted(40, 150)).toBe(false);
    expect(isEffectivelyDepleted(0, 150)).toBe(true);
  });
});
