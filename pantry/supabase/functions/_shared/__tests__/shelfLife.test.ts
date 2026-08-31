import { describe, expect, it } from 'vitest';
import { DEFAULT_STORAGE_BY_CATEGORY, SHELF_LIFE_REFERENCE } from '../data/shelfLife.ts';
import { PANTRY_CATEGORIES } from '../units/types.ts';

describe('shelf life reference data', () => {
  it('has unique seed keys so re-seeding is idempotent', () => {
    const keys = new Set(SHELF_LIFE_REFERENCE.map((entry) => entry.seedKey));
    expect(keys.size).toBe(SHELF_LIFE_REFERENCE.length);
  });

  it('has exactly one category default per category', () => {
    // The migration enforces this with a partial unique index; catching it here
    // means a bad dataset fails in a test run rather than mid-seed.
    const defaults = SHELF_LIFE_REFERENCE.filter((entry) => entry.itemNamePattern === null);
    expect(defaults).toHaveLength(PANTRY_CATEGORIES.length);
    expect(new Set(defaults.map((entry) => entry.category)).size).toBe(PANTRY_CATEGORIES.length);
  });

  it('gives every row at least one usable storage duration', () => {
    for (const entry of SHELF_LIFE_REFERENCE) {
      const durations = [entry.daysRefrigerated, entry.daysPantry, entry.daysFrozen];
      expect(durations.some((days) => days !== null), entry.seedKey).toBe(true);
      for (const days of durations) {
        if (days !== null) expect(days, entry.seedKey).toBeGreaterThan(0);
      }
    }
  });

  it('covers the reference set named in the spec', () => {
    const find = (pattern: string) =>
      SHELF_LIFE_REFERENCE.find((entry) => entry.itemNamePattern === pattern);

    expect(find('spinach')?.daysRefrigerated).toBe(5); // leafy greens ~5d
    expect(find('carrot')?.daysRefrigerated).toBe(30); // root veg ~30d
    expect(find('strawberry')?.daysRefrigerated).toBe(5); // berries ~5d
    expect(find('lemon')?.daysRefrigerated).toBe(21); // citrus ~21d
    expect(find('banana')?.daysPantry).toBe(5);
    expect(find('tomato')?.daysRefrigerated).toBe(7);
    expect(find('avocado')?.daysRefrigerated).toBe(4);
    expect(find('chicken')?.daysRefrigerated).toBe(2); // raw poultry
    expect(find('ground beef')?.daysRefrigerated).toBe(2);
    expect(find('beef')?.daysRefrigerated).toBe(4); // whole cuts
    expect(find('fish')?.daysRefrigerated).toBe(2);
    expect(find('milk')?.daysRefrigerated).toBe(7);
    expect(find('yogurt')?.daysRefrigerated).toBe(14);
    expect(find('feta')?.daysRefrigerated).toBe(10); // soft cheese
    expect(find('cheddar')?.daysRefrigerated).toBe(30); // hard cheese
    expect(find('egg')?.daysRefrigerated).toBe(28);
    expect(find('bread')?.daysPantry).toBe(5);
    expect(find('deli meat')?.daysRefrigerated).toBe(4);
    expect(find('leftover')?.daysRefrigerated).toBe(4);
    expect(find('rice')?.daysPantry).toBeGreaterThanOrEqual(365);
    expect(find('pasta')?.daysPantry).toBeGreaterThanOrEqual(365);
    expect(find('bean')?.daysPantry).toBeGreaterThanOrEqual(365);
    expect(
      SHELF_LIFE_REFERENCE.find((e) => e.category === 'canned' && e.itemNamePattern === null)?.daysPantry,
    ).toBeGreaterThanOrEqual(365);
    expect(
      SHELF_LIFE_REFERENCE.find((e) => e.category === 'spice' && e.itemNamePattern === null)?.daysPantry,
    ).toBe(730);
  });

  it('assumes refrigeration for the perishable categories', () => {
    expect(DEFAULT_STORAGE_BY_CATEGORY.produce).toBe('refrigerated');
    expect(DEFAULT_STORAGE_BY_CATEGORY.dairy).toBe('refrigerated');
    expect(DEFAULT_STORAGE_BY_CATEGORY.meat).toBe('refrigerated');
    expect(DEFAULT_STORAGE_BY_CATEGORY.seafood).toBe('refrigerated');
    expect(DEFAULT_STORAGE_BY_CATEGORY.pantry_dry).toBe('pantry');
    expect(DEFAULT_STORAGE_BY_CATEGORY.canned).toBe('pantry');
  });
});
