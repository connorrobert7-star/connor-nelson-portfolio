/**
 * toCanonical() -- the conversion engine.
 *
 * Everything in this project that touches a number goes through here first.
 * The contract: given how a thing was bought or how a recipe asks for it, return
 * an amount in g, ml, or count, plus an honest confidence.
 *
 * Resolution order, most specific to least:
 *   1. item rule       "1 bunch cilantro is 45 g"
 *   2. item density    "1 cup of flour is 120 g, so 1 pint is 240 g"
 *   3. universal       "1 lb is 453.59 g" -- but only if it lands on the unit
 *                      this item is measured in
 *   4. category rule   "produce sold by the head averages 400 g" -> forced low
 *   5. category density
 *   6. unresolved      -> count, low, and a warning
 *
 * The "only if it lands on the right unit" clause in step 3 is the important
 * one. A cup of spinach is not 236 ml of spinach; it is 30 g of spinach. Letting
 * universal volume math answer for a weight-measured item is precisely the bug
 * that turns a pantry into fiction.
 */

import { buildConversionRules } from './conversionRules.ts';
import { normalizeItemName, parseIngredientText } from './itemNames.ts';
import { parseQuantity } from './quantity.ts';
import {
  VOLUME_UNITS_IN_ML,
  WEIGHT_UNITS_IN_G,
  dimensionOf,
  isFuzzyUnit,
  normalizeUnit,
} from './unitAliases.ts';
import {
  minConfidence,
  type CanonicalUnit,
  type Confidence,
  type ConversionRule,
  type PantryCategory,
  type ToCanonicalOptions,
  type ToCanonicalResult,
} from './types.ts';

/**
 * Does `pattern` appear in `name` as a whole word (or whole word sequence)?
 *
 * Substring matching would have "egg" match "eggplant" and "pea" match "peach",
 * which is not a hypothetical -- both are in the dataset.
 */
export function patternMatchesName(name: string, pattern: string): boolean {
  if (pattern === '') return false;
  const nameTokens = name.split(' ').filter(Boolean);
  const patternTokens = pattern.split(' ').filter(Boolean);
  if (patternTokens.length === 0 || patternTokens.length > nameTokens.length) return false;

  for (let start = 0; start + patternTokens.length <= nameTokens.length; start += 1) {
    let matched = true;
    for (let offset = 0; offset < patternTokens.length; offset += 1) {
      if (nameTokens[start + offset] !== patternTokens[offset]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

interface RuleIndex {
  /** Item rule groups, longest (most specific) pattern first. */
  itemGroups: Array<{ pattern: string; canonicalUnit: CanonicalUnit; byUnit: Map<string, ConversionRule> }>;
  byCategory: Map<PantryCategory, { canonicalUnit: CanonicalUnit; byUnit: Map<string, ConversionRule> }>;
  universal: Map<string, ConversionRule>;
}

const indexCache = new WeakMap<ConversionRule[], RuleIndex>();

function indexRules(rules: ConversionRule[]): RuleIndex {
  const existing = indexCache.get(rules);
  if (existing) return existing;

  const itemMap = new Map<string, { canonicalUnit: CanonicalUnit; byUnit: Map<string, ConversionRule> }>();
  const byCategory: RuleIndex['byCategory'] = new Map();
  const universal = new Map<string, ConversionRule>();

  for (const rule of rules) {
    if (rule.itemNamePattern !== null) {
      let group = itemMap.get(rule.itemNamePattern);
      if (!group) {
        group = { canonicalUnit: rule.toCanonicalUnit, byUnit: new Map() };
        itemMap.set(rule.itemNamePattern, group);
      }
      group.byUnit.set(rule.fromUnit, rule);
    } else if (rule.category !== null) {
      let group = byCategory.get(rule.category);
      if (!group) {
        group = { canonicalUnit: rule.toCanonicalUnit, byUnit: new Map() };
        byCategory.set(rule.category, group);
      }
      group.byUnit.set(rule.fromUnit, rule);
    } else {
      universal.set(rule.fromUnit, rule);
    }
  }

  const itemGroups = [...itemMap.entries()]
    .map(([pattern, group]) => ({ pattern, ...group }))
    .sort((a, b) => b.pattern.length - a.pattern.length);

  const index: RuleIndex = { itemGroups, byCategory, universal };
  indexCache.set(rules, index);
  return index;
}

function roundCanonical(value: number): number {
  if (!Number.isFinite(value)) return 0;
  const magnitude = Math.abs(value);
  const decimals = magnitude >= 100 ? 2 : magnitude >= 1 ? 3 : 4;
  return Number(value.toFixed(decimals));
}

/** Convert any volume unit to millilitres by pure arithmetic. */
function toMilliliters(unit: string, quantity: number): number | null {
  const factor = VOLUME_UNITS_IN_ML[unit];
  return factor === undefined ? null : quantity * factor;
}

/** Convert any weight unit to grams by pure arithmetic. */
function toGrams(unit: string, quantity: number): number | null {
  const factor = WEIGHT_UNITS_IN_G[unit];
  return factor === undefined ? null : quantity * factor;
}

export function toCanonical(
  itemName: string,
  quantity: number | string | null | undefined,
  unit: string | null | undefined,
  options: ToCanonicalOptions = {},
): ToCanonicalResult {
  const rules = options.rules ?? buildConversionRules();
  const index = indexRules(rules);

  const normalizedName = normalizeItemName(itemName);
  const parsed = parseQuantity(quantity);
  const unitInfo = normalizeUnit(unit);
  const warnings = [...parsed.warnings, ...unitInfo.warnings];

  // No unit at all means "N of the thing": "2 eggs", "1 onion".
  let sourceUnit = unitInfo.unit;
  if (sourceUnit === '') {
    sourceUnit = 'count';
    warnings.push('No unit given; treated as a count of whole items.');
  }

  const category = options.category;

  // --- what unit is this item measured in? --------------------------------
  const matchedGroups = index.itemGroups.filter((group) =>
    patternMatchesName(normalizedName, group.pattern),
  );
  const categoryGroup = category ? index.byCategory.get(category) : undefined;

  const targetUnit: CanonicalUnit =
    matchedGroups[0]?.canonicalUnit ??
    categoryGroup?.canonicalUnit ??
    (dimensionOf(sourceUnit) === 'weight' ? 'g' : dimensionOf(sourceUnit) === 'volume' ? 'ml' : 'count');

  // "16 oz olive oil" is sixteen FLUID ounces. Bare "oz" on something measured
  // by volume is a labelling convention, not a weight.
  let effectiveUnit = sourceUnit;
  if (
    sourceUnit === 'oz' &&
    targetUnit === 'ml' &&
    !matchedGroups.some((group) => group.byUnit.has('oz'))
  ) {
    effectiveUnit = 'fl_oz';
    warnings.push('Interpreted "oz" as fluid ounces because this item is measured by volume.');
  }

  const sourceDimension = dimensionOf(effectiveUnit);

  const finish = (
    rawAmount: number,
    canonicalUnit: CanonicalUnit,
    confidence: Confidence,
    path: ToCanonicalResult['path'],
    explanation: string,
    extraWarnings: string[] = [],
  ): ToCanonicalResult => {
    let amount = rawAmount;
    let finalConfidence = minConfidence(confidence, parsed.confidence);
    const allWarnings = [...warnings, ...extraWarnings];

    // A "large onion" really is heavier than a medium one, but only when the
    // count is being turned into weight. Two large eggs are still two eggs.
    if (unitInfo.sizeMultiplier !== 1 && sourceDimension === 'count' && canonicalUnit !== 'count') {
      amount *= unitInfo.sizeMultiplier;
      allWarnings.push(
        `Scaled by ${unitInfo.sizeMultiplier}x for the stated size; sizes vary, so this is an estimate.`,
      );
      finalConfidence = minConfidence(finalConfidence, 'medium');
    }

    if (canonicalUnit !== targetUnit) {
      allWarnings.push(
        `Resolved to ${canonicalUnit} but "${normalizedName || itemName}" is normally measured in ${targetUnit}. ` +
          'Do not subtract this from a pantry lot without checking the units match.',
      );
      finalConfidence = 'low';
    }

    if (isFuzzyUnit(effectiveUnit) && canonicalUnit !== 'count') {
      finalConfidence = 'low';
    }

    return {
      canonicalQuantity: roundCanonical(amount),
      canonicalUnit,
      confidence: finalConfidence,
      normalizedName,
      parsedQuantity: parsed.value,
      normalizedUnit: effectiveUnit,
      path,
      explanation,
      warnings: allWarnings,
    };
  };

  // --- 1. exact item rule --------------------------------------------------
  for (const group of matchedGroups) {
    const rule = group.byUnit.get(effectiveUnit);
    if (rule) {
      return finish(
        parsed.value * rule.multiplier,
        rule.toCanonicalUnit,
        rule.confidence,
        'item-rule',
        `1 ${effectiveUnit} of "${group.pattern}" = ${rule.multiplier} ${rule.toCanonicalUnit}.`,
      );
    }
  }

  // --- 2. item density -----------------------------------------------------
  // The item has a known density, so an unlisted volume unit is still answerable:
  // convert to ml by arithmetic, then apply the density.
  if (sourceDimension === 'volume') {
    for (const group of matchedGroups) {
      const density = group.byUnit.get('ml');
      if (density && density.toCanonicalUnit !== 'ml') {
        const ml = toMilliliters(effectiveUnit, parsed.value);
        if (ml !== null) {
          return finish(
            ml * density.multiplier,
            density.toCanonicalUnit,
            density.confidence,
            'item-density',
            `${parsed.value} ${effectiveUnit} = ${roundCanonical(ml)} ml, and "${group.pattern}" is ` +
              `${density.multiplier} ${density.toCanonicalUnit} per ml.`,
          );
        }
      }
    }
  }

  // --- 3. universal arithmetic --------------------------------------------
  // Only valid when it lands on the unit this item is actually measured in.
  const universalRule = index.universal.get(effectiveUnit);
  if (universalRule && universalRule.toCanonicalUnit === targetUnit) {
    return finish(
      parsed.value * universalRule.multiplier,
      universalRule.toCanonicalUnit,
      universalRule.confidence,
      'universal',
      `1 ${effectiveUnit} = ${universalRule.multiplier} ${universalRule.toCanonicalUnit}.`,
    );
  }

  // --- 4. category rule ----------------------------------------------------
  if (categoryGroup) {
    const rule = categoryGroup.byUnit.get(effectiveUnit);
    if (rule) {
      return finish(
        parsed.value * rule.multiplier,
        rule.toCanonicalUnit,
        'low',
        'category-rule',
        `No rule for "${normalizedName}"; used the ${category} average of ${rule.multiplier} ` +
          `${rule.toCanonicalUnit} per ${effectiveUnit}.`,
        [`No item-specific conversion for "${normalizedName}"; used a ${category} category average.`],
      );
    }

    // --- 5. category density ----------------------------------------------
    const density = categoryGroup.byUnit.get('ml');
    if (sourceDimension === 'volume' && density && density.toCanonicalUnit !== 'ml') {
      const ml = toMilliliters(effectiveUnit, parsed.value);
      if (ml !== null) {
        return finish(
          ml * density.multiplier,
          density.toCanonicalUnit,
          'low',
          'category-density',
          `No rule for "${normalizedName}"; used the average ${category} density of ` +
            `${density.multiplier} ${density.toCanonicalUnit} per ml.`,
          [`Converted by ${category} average density; this is a guess.`],
        );
      }
    }

    // A weight unit on a volume-measured category (or vice versa) with no
    // density anywhere. Fall through rather than inventing a number.
  }

  // --- 3b. universal, wrong dimension --------------------------------------
  // Nothing better exists. Returning grams for something normally in ml is
  // still more useful than returning nothing, as long as it is flagged -- and
  // finish() forces the confidence to low when the units disagree.
  if (universalRule) {
    return finish(
      parsed.value * universalRule.multiplier,
      universalRule.toCanonicalUnit,
      universalRule.confidence,
      'universal',
      `1 ${effectiveUnit} = ${universalRule.multiplier} ${universalRule.toCanonicalUnit}, ` +
        'though that is not the unit this item is normally measured in.',
    );
  }

  const grams = sourceDimension === 'weight' ? toGrams(effectiveUnit, parsed.value) : null;
  if (grams !== null) {
    return finish(grams, 'g', 'high', 'universal', `1 ${effectiveUnit} = ${WEIGHT_UNITS_IN_G[effectiveUnit]} g.`);
  }

  // --- 6. unresolved -------------------------------------------------------
  return finish(
    parsed.value,
    'count',
    'low',
    'unresolved',
    `No conversion known for "${effectiveUnit}" of "${normalizedName || itemName}".`,
    [
      `Could not convert "${effectiveUnit}" of "${normalizedName || itemName}"; recorded as a raw count. ` +
        'Add a unit_conversions row for this item to fix it properly.',
    ],
  );
}

/**
 * Convenience wrapper for free-text ingredient lines: "1 bunch cilantro".
 * Phase 2 gets quantity/unit/name separately from the model and should call
 * toCanonical() directly.
 */
export function toCanonicalFromText(
  text: string,
  options: ToCanonicalOptions = {},
): ToCanonicalResult {
  const parts = parseIngredientText(text);
  return toCanonical(parts.name, parts.quantity, parts.unit, options);
}

