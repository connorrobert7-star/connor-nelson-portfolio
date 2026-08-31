/**
 * Materializes the conversion dataset into flat rules.
 *
 * The flat shape is exactly the `unit_conversions` table, which is the point:
 * the engine reads flat rules and does not care whether they came from this file
 * or from Postgres. That is what lets a hand-edited row in the DB override a
 * built-in number without touching code, and what lets the tests run the real
 * engine with no database at all.
 */

import {
  CATEGORY_FALLBACKS,
  ITEM_PROFILES,
  UNIVERSAL_FUZZY_UNITS,
  type ItemProfile,
} from './conversionData.js';
import type { ConversionRule, PantryCategory } from './types.js';
import { PANTRY_CATEGORIES } from './types.js';
import { VOLUME_UNITS_IN_ML, WEIGHT_UNITS_IN_G, isFuzzyUnit } from './unitAliases.js';

const ML_PER_CUP = VOLUME_UNITS_IN_ML.cup as number;

function ruleConfidence(profile: ItemProfile, unit: string): ConversionRule['confidence'] {
  const explicit = profile.unitConfidence?.[unit];
  if (explicit) return explicit;
  // A bunch is a bunch no matter how confident we are about the item.
  if (isFuzzyUnit(unit)) return 'low';
  return profile.defaultConfidence ?? 'medium';
}

function itemRules(profile: ItemProfile): ConversionRule[] {
  const rules: ConversionRule[] = [];
  const seen = new Set<string>();

  const push = (fromUnit: string, multiplier: number, notes?: string): void => {
    if (seen.has(fromUnit)) {
      throw new Error(
        `Conversion dataset defines "${fromUnit}" twice for item "${profile.pattern}". ` +
          'Two rules for the same (item, unit) pair make resolution order-dependent.',
      );
    }
    seen.add(fromUnit);
    rules.push({
      itemNamePattern: profile.pattern,
      category: null,
      fromUnit,
      toCanonicalUnit: profile.canonicalUnit,
      multiplier,
      confidence: ruleConfidence(profile, fromUnit),
      ...(notes !== undefined ? { notes } : profile.notes ? { notes: profile.notes } : {}),
      seedKey: `item:${profile.pattern}:${fromUnit}`,
    });
  };

  // Explicit count units first so they win over anything derived.
  for (const [unit, multiplier] of Object.entries(profile.countUnits ?? {})) {
    push(unit, multiplier);
  }

  // "1 chicken breast" has to mean something, and it is not "1 count of nothing".
  const natural = profile.naturalCountUnit;
  if (natural && !seen.has('count')) {
    const multiplier = profile.countUnits?.[natural];
    if (multiplier === undefined) {
      throw new Error(
        `Item "${profile.pattern}" declares naturalCountUnit "${natural}" with no matching countUnits entry.`,
      );
    }
    push('count', multiplier, `A bare count of ${profile.pattern} means one ${natural}.`);
  }

  // Density. Only emitted where it actually differs from plain volume, i.e.
  // where the item's canonical unit is weight but the unit given is volume.
  if (profile.perCup !== undefined && profile.canonicalUnit !== 'ml') {
    const perMl = profile.perCup / ML_PER_CUP;
    const derived = `Derived from density: 1 cup of ${profile.pattern} is about ${profile.perCup} ${profile.canonicalUnit}.`;
    if (!seen.has('cup')) push('cup', profile.perCup, derived);
    if (!seen.has('tbsp')) push('tbsp', profile.perCup / 16, derived);
    if (!seen.has('tsp')) push('tsp', profile.perCup / 48, derived);
    if (!seen.has('fl_oz')) push('fl_oz', profile.perCup / 8, derived);
    // The density row. Any volume unit not listed above is converted to ml by
    // universal arithmetic and then multiplied through this.
    if (!seen.has('ml')) {
      push('ml', perMl, `Density: 1 cup of ${profile.pattern} is about ${profile.perCup} ${profile.canonicalUnit}.`);
    }
  }

  return rules;
}

function categoryRules(category: PantryCategory): ConversionRule[] {
  const fallback = CATEGORY_FALLBACKS[category];
  const rules: ConversionRule[] = [];

  for (const [fromUnit, multiplier] of Object.entries(fallback.units)) {
    rules.push({
      itemNamePattern: null,
      category,
      fromUnit,
      toCanonicalUnit: fallback.canonicalUnit,
      multiplier,
      // Category rules are averages over a whole aisle. The spec is explicit
      // that this path must never claim better than low confidence.
      confidence: 'low',
      notes: `Category average for ${category}; no item-specific rule matched.`,
      seedKey: `cat:${category}:${fromUnit}`,
    });
  }

  if (fallback.perMl !== undefined && fallback.canonicalUnit !== 'ml') {
    rules.push({
      itemNamePattern: null,
      category,
      fromUnit: 'ml',
      toCanonicalUnit: fallback.canonicalUnit,
      multiplier: fallback.perMl,
      confidence: 'low',
      notes: `Average density for ${category}; a genuine guess, flagged as such.`,
      seedKey: `cat:${category}:ml`,
    });
  }

  return rules;
}

function universalRules(): ConversionRule[] {
  const rules: ConversionRule[] = [];

  const push = (
    fromUnit: string,
    toCanonicalUnit: ConversionRule['toCanonicalUnit'],
    multiplier: number,
    confidence: ConversionRule['confidence'],
    notes?: string,
  ): void => {
    rules.push({
      itemNamePattern: null,
      category: null,
      fromUnit,
      toCanonicalUnit,
      multiplier,
      confidence,
      ...(notes !== undefined ? { notes } : {}),
      seedKey: `uni:${fromUnit}`,
    });
  };

  // Pure arithmetic. These are definitions, not estimates, so they are the only
  // rules in the whole system that are unconditionally high confidence.
  for (const [unit, grams] of Object.entries(WEIGHT_UNITS_IN_G)) {
    push(unit, 'g', grams, 'high', 'Exact unit definition.');
  }
  for (const [unit, ml] of Object.entries(VOLUME_UNITS_IN_ML)) {
    push(unit, 'ml', ml, 'high', 'Exact unit definition (US measure).');
  }

  push('count', 'count', 1, 'high');
  push('dozen', 'count', 12, 'high', 'Exact by definition.');

  for (const fuzzy of UNIVERSAL_FUZZY_UNITS) {
    push(fuzzy.unit, fuzzy.canonicalUnit, fuzzy.multiplier, 'low', fuzzy.notes);
  }

  return rules;
}

let cached: ConversionRule[] | null = null;

/** The full rule set. Memoized -- it is derived, not read from anywhere. */
export function buildConversionRules(): ConversionRule[] {
  if (cached) return cached;

  const rules: ConversionRule[] = [];
  for (const profile of ITEM_PROFILES) rules.push(...itemRules(profile));
  for (const category of PANTRY_CATEGORIES) rules.push(...categoryRules(category));
  rules.push(...universalRules());

  // Guard the invariant the migration's unique indexes also enforce: one rule
  // per (scope, unit). A duplicate here means resolution depends on array order,
  // which is exactly the kind of bug that silently halves a quantity.
  const seen = new Map<string, ConversionRule>();
  for (const rule of rules) {
    const scope =
      rule.itemNamePattern !== null
        ? `item:${rule.itemNamePattern}`
        : rule.category !== null
          ? `cat:${rule.category}`
          : 'universal';
    const key = `${scope}|${rule.fromUnit}`;
    const existing = seen.get(key);
    if (existing) {
      throw new Error(`Duplicate conversion rule for ${key} (seed keys ${existing.seedKey} and ${rule.seedKey}).`);
    }
    seen.set(key, rule);
  }

  cached = rules;
  return rules;
}

/** Test hook. Never call this from application code. */
export function resetConversionRuleCache(): void {
  cached = null;
}
