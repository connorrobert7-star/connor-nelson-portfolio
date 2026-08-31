/**
 * Public surface of the conversion layer.
 *
 * Every other phase imports from here. Nothing outside this directory should
 * reach into the individual modules -- the resolution order is an implementation
 * detail and will keep changing as the dataset grows.
 */

export { toCanonical, toCanonicalFromText, patternMatchesName } from './toCanonical.js';
export { normalizeItemName, parseIngredientText } from './itemNames.js';
export { parseQuantity } from './quantity.js';
export { normalizeUnit, dimensionOf, isFuzzyUnit } from './unitAliases.js';
export { buildConversionRules } from './conversionRules.js';
export { ITEM_PROFILES, CATEGORY_FALLBACKS } from './conversionData.js';
export {
  PANTRY_CATEGORIES,
  CANONICAL_UNITS,
  CONFIDENCE_LEVELS,
  minConfidence,
  isCanonicalUnit,
  isPantryCategory,
} from './types.js';
export type {
  CanonicalUnit,
  Confidence,
  ConversionRule,
  Dimension,
  PantryCategory,
  ToCanonicalOptions,
  ToCanonicalResult,
} from './types.js';
