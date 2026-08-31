import { describe, expect, it } from 'vitest';
import { buildConversionRules } from '../units/conversionRules.js';
import { ITEM_PROFILES } from '../units/conversionData.js';
import { CANONICAL_UNITS, PANTRY_CATEGORIES } from '../units/types.js';
import { COUNT_UNITS, VOLUME_UNITS_IN_ML, WEIGHT_UNITS_IN_G } from '../units/unitAliases.js';

const rules = buildConversionRules();

describe('conversion rule dataset invariants', () => {
  it('builds without a duplicate (scope, unit) pair', () => {
    // buildConversionRules throws on duplicates; getting here is the assertion.
    expect(rules.length).toBeGreaterThan(400);
  });

  it('gives every item pattern exactly one canonical unit', () => {
    // This is the invariant the whole project rests on. An item whose rules
    // disagree about grams vs millilitres produces arithmetic that is wrong in
    // a way no downstream check can catch.
    const byPattern = new Map<string, Set<string>>();
    for (const rule of rules) {
      if (rule.itemNamePattern === null) continue;
      const set = byPattern.get(rule.itemNamePattern) ?? new Set<string>();
      set.add(rule.toCanonicalUnit);
      byPattern.set(rule.itemNamePattern, set);
    }
    for (const [pattern, units] of byPattern) {
      expect(units, `item "${pattern}" resolves to more than one canonical unit`).toHaveLength(1);
    }
  });

  it('gives every category exactly one canonical unit', () => {
    const byCategory = new Map<string, Set<string>>();
    for (const rule of rules) {
      if (rule.itemNamePattern !== null || rule.category === null) continue;
      const set = byCategory.get(rule.category) ?? new Set<string>();
      set.add(rule.toCanonicalUnit);
      byCategory.set(rule.category, set);
    }
    for (const [category, units] of byCategory) {
      expect(units, `category "${category}" resolves to more than one canonical unit`).toHaveLength(1);
    }
    expect(byCategory.size).toBe(PANTRY_CATEGORIES.length);
  });

  it('has unique seed keys so re-seeding is idempotent', () => {
    const keys = new Set(rules.map((rule) => rule.seedKey));
    expect(keys.size).toBe(rules.length);
  });

  it('has only positive multipliers and valid canonical units', () => {
    for (const rule of rules) {
      expect(rule.multiplier, rule.seedKey).toBeGreaterThan(0);
      expect(Number.isFinite(rule.multiplier), rule.seedKey).toBe(true);
      expect(CANONICAL_UNITS).toContain(rule.toCanonicalUnit);
    }
  });

  it('only uses units the normalizer can actually produce', () => {
    // A rule for a unit no input can ever normalize to is dead weight that
    // looks like coverage.
    const known = new Set([
      ...Object.keys(WEIGHT_UNITS_IN_G),
      ...Object.keys(VOLUME_UNITS_IN_ML),
      ...COUNT_UNITS,
    ]);
    for (const rule of rules) {
      expect(known.has(rule.fromUnit), `unknown from_unit "${rule.fromUnit}" in ${rule.seedKey}`).toBe(true);
    }
  });

  it('never claims better than low confidence on a category fallback', () => {
    for (const rule of rules) {
      if (rule.itemNamePattern === null && rule.category !== null) {
        expect(rule.confidence, rule.seedKey).toBe('low');
      }
    }
  });

  it('covers every unit named in the spec', () => {
    const universal = new Map(
      rules.filter((r) => r.itemNamePattern === null && r.category === null).map((r) => [r.fromUnit, r]),
    );
    expect(universal.get('oz')?.multiplier).toBeCloseTo(28.35, 2);
    expect(universal.get('lb')?.multiplier).toBeCloseTo(453.59, 2);
    expect(universal.get('cup')?.multiplier).toBeCloseTo(236.59, 2);
    expect(universal.get('tbsp')?.multiplier).toBeCloseTo(14.79, 2);
    expect(universal.get('tsp')?.multiplier).toBeCloseTo(4.93, 2);
    expect(universal.get('fl_oz')?.multiplier).toBeCloseTo(29.57, 2);

    const item = (pattern: string, unit: string): number | undefined =>
      rules.find((r) => r.itemNamePattern === pattern && r.fromUnit === unit)?.multiplier;

    expect(item('garlic', 'clove')).toBe(5);
    expect(item('onion', 'count')).toBe(150);
    expect(item('cilantro', 'bunch')).toBe(45);
    expect(item('scallion', 'bunch')).toBe(100);
    expect(item('garlic', 'head')).toBe(45);
    expect(item('romaine', 'head')).toBe(300);
    expect(item('tomato', 'count')).toBe(120);
    expect(item('bell pepper', 'count')).toBe(120);
    expect(item('lemon', 'count')).toBe(60);
    expect(item('avocado', 'count')).toBe(150);
    expect(item('chicken breast', 'breast')).toBe(175);
    expect(item('egg', 'count')).toBe(1);
    expect(item('black bean', 'can')).toBe(425);
    expect(item('tomato', 'can')).toBe(400);
    expect(item('flour', 'cup')).toBe(120);
    expect(item('rice', 'cup')).toBe(185);
    expect(item('sugar', 'cup')).toBe(200);
  });

  it('declares no duplicate item patterns', () => {
    const patterns = ITEM_PROFILES.map((profile) => profile.pattern);
    expect(new Set(patterns).size).toBe(patterns.length);
  });
});
