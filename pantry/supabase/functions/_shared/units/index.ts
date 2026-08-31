/**
 * Public surface of the conversion layer.
 *
 * Every other phase imports from here. Nothing outside this directory should
 * reach into the individual modules -- the resolution order is an implementation
 * detail and will keep changing as the dataset grows.
 */

export { toCanonical, toCanonicalFromText, patternMatchesName } from './toCanonical.ts';
export { normalizeItemName, parseIngredientText } from './itemNames.ts';
export { parseQuantity } from './quantity.ts';
export { normalizeUnit, dimensionOf, isFuzzyUnit } from './unitAliases.ts';
export { buildConversionRules } from './conversionRules.ts';
export { ITEM_PROFILES, CATEGORY_FALLBACKS } from './conversionData.ts';
export {
  PANTRY_CATEGORIES,
  CANONICAL_UNITS,
  CONFIDENCE_LEVELS,
  minConfidence,
  isCanonicalUnit,
  isPantryCategory,
} from './types.ts';
export type {
  CanonicalUnit,
  Confidence,
  ConversionRule,
  Dimension,
  PantryCategory,
  ToCanonicalOptions,
  ToCanonicalResult,
} from './types.ts';
