/**
 * The conversion dataset.
 *
 * This file is the single source of truth. `unit_conversions` in Postgres is a
 * projection of it (see conversionRules.ts + scripts/seed.ts), which means the
 * table is inspectable and hand-editable but never silently diverges from what
 * the code believes.
 *
 * Three tiers, most specific first:
 *   ITEM_PROFILES     - "1 bunch cilantro is 45 g"
 *   CATEGORY_FALLBACKS- "some produce, sold by the bunch, call it 60 g"
 *   UNIVERSAL_RULES   - "a pound is 453.59 g", true of everything
 *
 * Every profile declares ONE canonical unit and every rule derived from it lands
 * on that unit. That invariant is what makes the arithmetic safe: an item bought
 * as "1 lb chicken breast" and cooked as "2 breasts" both become grams, so the
 * subtraction is meaningful. A test enforces it; do not add a profile that mixes.
 *
 * Numbers are typical values from standard kitchen references, rounded to the
 * precision the domain actually supports. A tomato is not 120 g; a tomato is
 * about 120 g, which is why confidence travels alongside every one of them.
 */

import type { CanonicalUnit, Confidence, PantryCategory } from './types.ts';

export interface ItemProfile {
  /** Normalized item name fragment, matched by substring. Longest match wins. */
  pattern: string;
  category: PantryCategory;
  /** Every rule derived from this profile lands here. No exceptions. */
  canonicalUnit: CanonicalUnit;
  /**
   * Canonical amount in one US cup. Present only where density matters --
   * a cup of flour is 120 g but a cup of rice is 185 g, and treating either as
   * 236 ml is how you end up putting twice the flour in.
   */
  perCup?: number;
  /** Explicit conversions for countable/descriptive units. */
  countUnits?: Record<string, number>;
  /**
   * What a bare "1 <item>" means. "1 chicken breast" is one breast; "1 cilantro"
   * is one bunch. Emitted as an explicit `count` rule so lookup stays uniform.
   */
  naturalCountUnit?: string;
  defaultConfidence?: Confidence;
  unitConfidence?: Record<string, Confidence>;
  notes?: string;
}

export interface CategoryFallback {
  canonicalUnit: CanonicalUnit;
  units: Record<string, number>;
  /**
   * Canonical units per millilitre, for the last-ditch volume conversion when
   * the item is unknown. Always low confidence -- it is a category average, and
   * the spec is explicit that guessing must never be dressed up as knowledge.
   */
  perMl?: number;
  unitConfidence?: Record<string, Confidence>;
}

// ---------------------------------------------------------------------------
// Item profiles
// ---------------------------------------------------------------------------

export const ITEM_PROFILES: ItemProfile[] = [
  // --- produce: alliums & herbs -------------------------------------------
  {
    pattern: 'garlic',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 136,
    countUnits: { clove: 5, head: 45, bulb: 45 },
    naturalCountUnit: 'clove',
    unitConfidence: { clove: 'medium', head: 'low' },
    notes: 'A clove varies a lot by head size; 5 g is the common reference.',
  },
  {
    pattern: 'garlic powder',
    category: 'spice',
    canonicalUnit: 'g',
    perCup: 149,
    countUnits: { jar: 90 },
  },
  {
    pattern: 'onion',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 160,
    countUnits: { count: 150 },
    unitConfidence: { count: 'medium' },
    notes: 'Medium yellow onion. Size words scale this.',
  },
  { pattern: 'shallot', category: 'produce', canonicalUnit: 'g', perCup: 160, countUnits: { count: 40 } },
  {
    pattern: 'scallion',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 100,
    countUnits: { bunch: 100, count: 15 },
  },
  {
    pattern: 'green onion',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 100,
    countUnits: { bunch: 100, count: 15 },
  },
  { pattern: 'leek', category: 'produce', canonicalUnit: 'g', perCup: 104, countUnits: { count: 240 } },
  {
    pattern: 'cilantro',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 16,
    countUnits: { bunch: 45 },
    naturalCountUnit: 'bunch',
    notes: 'Chopped, loosely packed, for the cup figure.',
  },
  {
    pattern: 'parsley',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 16,
    countUnits: { bunch: 60 },
    naturalCountUnit: 'bunch',
  },
  {
    pattern: 'basil',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 24,
    countUnits: { bunch: 60, leaf: 0.5 },
    naturalCountUnit: 'bunch',
  },
  {
    pattern: 'dill',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 12,
    countUnits: { bunch: 40, sprig: 1 },
    naturalCountUnit: 'bunch',
  },
  {
    pattern: 'mint',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 12,
    countUnits: { bunch: 40, sprig: 1, leaf: 0.2 },
    naturalCountUnit: 'bunch',
  },
  {
    pattern: 'thyme',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 40,
    countUnits: { bunch: 25, sprig: 1 },
    naturalCountUnit: 'sprig',
  },
  {
    pattern: 'rosemary',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 45,
    countUnits: { bunch: 25, sprig: 2 },
    naturalCountUnit: 'sprig',
  },
  {
    pattern: 'sage',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 30,
    countUnits: { bunch: 25, sprig: 1.5, leaf: 0.3 },
    naturalCountUnit: 'sprig',
  },
  { pattern: 'chive', category: 'produce', canonicalUnit: 'g', perCup: 48, countUnits: { bunch: 30 } },
  { pattern: 'ginger', category: 'produce', canonicalUnit: 'g', perCup: 96, countUnits: { knob: 15, count: 15, root: 60 } },

  // --- produce: fruiting vegetables & fruit --------------------------------
  {
    pattern: 'tomato',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 180,
    countUnits: { count: 120, can: 400 },
    unitConfidence: { count: 'medium', can: 'high' },
    notes: 'A 14.5 oz can of tomatoes is ~400 g; fresh medium tomato ~120 g.',
  },
  { pattern: 'cherry tomato', category: 'produce', canonicalUnit: 'g', perCup: 150, countUnits: { count: 17, pint: 300 } },
  { pattern: 'tomato paste', category: 'canned', canonicalUnit: 'g', perCup: 262, countUnits: { can: 170, tube: 156 } },
  { pattern: 'tomato sauce', category: 'canned', canonicalUnit: 'g', perCup: 245, countUnits: { can: 425, jar: 680 } },
  {
    pattern: 'bell pepper',
    category: 'produce',
    canonicalUnit: 'g',
    perCup: 150,
    countUnits: { count: 120 },
    unitConfidence: { count: 'medium' },
  },
  { pattern: 'jalapeno', category: 'produce', canonicalUnit: 'g', perCup: 90, countUnits: { count: 15 } },
  { pattern: 'serrano', category: 'produce', canonicalUnit: 'g', perCup: 90, countUnits: { count: 6 } },
  { pattern: 'cucumber', category: 'produce', canonicalUnit: 'g', perCup: 133, countUnits: { count: 300 } },
  { pattern: 'zucchini', category: 'produce', canonicalUnit: 'g', perCup: 124, countUnits: { count: 200 } },
  { pattern: 'eggplant', category: 'produce', canonicalUnit: 'g', perCup: 82, countUnits: { count: 450 } },
  { pattern: 'avocado', category: 'produce', canonicalUnit: 'g', perCup: 150, countUnits: { count: 150 }, unitConfidence: { count: 'medium' } },
  { pattern: 'lemon', category: 'produce', canonicalUnit: 'g', perCup: 180, countUnits: { count: 60 }, unitConfidence: { count: 'medium' } },
  { pattern: 'lime', category: 'produce', canonicalUnit: 'g', perCup: 180, countUnits: { count: 45 }, unitConfidence: { count: 'medium' } },
  { pattern: 'orange', category: 'produce', canonicalUnit: 'g', perCup: 180, countUnits: { count: 130 } },
  { pattern: 'apple', category: 'produce', canonicalUnit: 'g', perCup: 125, countUnits: { count: 180 } },
  { pattern: 'banana', category: 'produce', canonicalUnit: 'g', perCup: 150, countUnits: { count: 120 } },
  { pattern: 'strawberry', category: 'produce', canonicalUnit: 'g', perCup: 144, countUnits: { count: 12, pint: 340, container: 454 } },
  { pattern: 'blueberry', category: 'produce', canonicalUnit: 'g', perCup: 148, countUnits: { pint: 340, container: 170 } },
  { pattern: 'raspberry', category: 'produce', canonicalUnit: 'g', perCup: 123, countUnits: { pint: 340, container: 170 } },
  { pattern: 'grape', category: 'produce', canonicalUnit: 'g', perCup: 151, countUnits: { bag: 907 } },

  // --- produce: roots, leaves, brassicas -----------------------------------
  { pattern: 'carrot', category: 'produce', canonicalUnit: 'g', perCup: 128, countUnits: { count: 60, bunch: 350, bag: 907 } },
  { pattern: 'celery', category: 'produce', canonicalUnit: 'g', perCup: 101, countUnits: { stalk: 40, count: 40, bunch: 400, rib: 40 } },
  { pattern: 'potato', category: 'produce', canonicalUnit: 'g', perCup: 150, countUnits: { count: 170, bag: 2270 } },
  { pattern: 'sweet potato', category: 'produce', canonicalUnit: 'g', perCup: 133, countUnits: { count: 130 } },
  { pattern: 'lettuce', category: 'produce', canonicalUnit: 'g', perCup: 47, countUnits: { head: 300, count: 300 } },
  { pattern: 'romaine', category: 'produce', canonicalUnit: 'g', perCup: 47, countUnits: { head: 300, count: 300 } },
  { pattern: 'cabbage', category: 'produce', canonicalUnit: 'g', perCup: 89, countUnits: { head: 900, count: 900 } },
  { pattern: 'broccoli', category: 'produce', canonicalUnit: 'g', perCup: 91, countUnits: { head: 500, count: 500, floret: 12, bunch: 500 } },
  { pattern: 'cauliflower', category: 'produce', canonicalUnit: 'g', perCup: 107, countUnits: { head: 600, count: 600, floret: 13 } },
  { pattern: 'spinach', category: 'produce', canonicalUnit: 'g', perCup: 30, countUnits: { bunch: 200, bag: 142, container: 142 } },
  { pattern: 'kale', category: 'produce', canonicalUnit: 'g', perCup: 21, countUnits: { bunch: 150, bag: 142 } },
  { pattern: 'arugula', category: 'produce', canonicalUnit: 'g', perCup: 20, countUnits: { bunch: 125, bag: 142, container: 142 } },
  { pattern: 'mushroom', category: 'produce', canonicalUnit: 'g', perCup: 70, countUnits: { count: 20, container: 227, package: 227 } },
  { pattern: 'corn', category: 'produce', canonicalUnit: 'g', perCup: 145, countUnits: { ear: 90, count: 90, can: 400 } },
  { pattern: 'green bean', category: 'produce', canonicalUnit: 'g', perCup: 110, countUnits: { bag: 340, can: 400 } },
  { pattern: 'asparagus', category: 'produce', canonicalUnit: 'g', perCup: 134, countUnits: { bunch: 450, count: 16 } },
  { pattern: 'pea', category: 'produce', canonicalUnit: 'g', perCup: 145, countUnits: { bag: 340, can: 400 } },

  // --- meat ----------------------------------------------------------------
  {
    pattern: 'chicken breast',
    category: 'meat',
    canonicalUnit: 'g',
    countUnits: { breast: 175, count: 175 },
    naturalCountUnit: 'breast',
    unitConfidence: { breast: 'medium', count: 'medium' },
    notes: 'Boneless skinless breast. Real ones run 150-225 g, hence medium.',
  },
  { pattern: 'chicken thigh', category: 'meat', canonicalUnit: 'g', countUnits: { thigh: 110, count: 110 }, naturalCountUnit: 'thigh', unitConfidence: { thigh: 'medium' } },
  { pattern: 'chicken drumstick', category: 'meat', canonicalUnit: 'g', countUnits: { drumstick: 100, count: 100 }, naturalCountUnit: 'drumstick' },
  { pattern: 'chicken wing', category: 'meat', canonicalUnit: 'g', countUnits: { wing: 90, count: 90 }, naturalCountUnit: 'wing' },
  { pattern: 'whole chicken', category: 'meat', canonicalUnit: 'g', countUnits: { count: 1600 } },
  { pattern: 'ground beef', category: 'meat', canonicalUnit: 'g', perCup: 226, countUnits: { package: 454 } },
  { pattern: 'ground turkey', category: 'meat', canonicalUnit: 'g', perCup: 226, countUnits: { package: 454 } },
  { pattern: 'ground pork', category: 'meat', canonicalUnit: 'g', perCup: 226, countUnits: { package: 454 } },
  { pattern: 'bacon', category: 'meat', canonicalUnit: 'g', countUnits: { slice: 20, strip: 20, count: 20, package: 340 }, unitConfidence: { slice: 'medium', strip: 'medium' } },
  { pattern: 'sausage', category: 'meat', canonicalUnit: 'g', countUnits: { link: 75, count: 75, package: 450 } },
  { pattern: 'steak', category: 'meat', canonicalUnit: 'g', countUnits: { count: 280 } },
  { pattern: 'pork chop', category: 'meat', canonicalUnit: 'g', countUnits: { count: 170 } },
  { pattern: 'deli meat', category: 'meat', canonicalUnit: 'g', countUnits: { slice: 20, package: 227 } },

  // --- seafood -------------------------------------------------------------
  { pattern: 'salmon', category: 'seafood', canonicalUnit: 'g', countUnits: { fillet: 170, count: 170 }, naturalCountUnit: 'fillet', unitConfidence: { fillet: 'medium' } },
  { pattern: 'cod', category: 'seafood', canonicalUnit: 'g', countUnits: { fillet: 170, count: 170 }, naturalCountUnit: 'fillet' },
  { pattern: 'shrimp', category: 'seafood', canonicalUnit: 'g', perCup: 145, countUnits: { count: 10, bag: 454 } },
  { pattern: 'tuna', category: 'seafood', canonicalUnit: 'g', countUnits: { can: 140, fillet: 170 }, unitConfidence: { can: 'high' } },
  { pattern: 'scallop', category: 'seafood', canonicalUnit: 'g', countUnits: { count: 15 } },

  // --- dairy & eggs --------------------------------------------------------
  {
    pattern: 'egg',
    category: 'dairy',
    canonicalUnit: 'count',
    countUnits: { count: 1, dozen: 12, carton: 12 },
    naturalCountUnit: 'count',
    defaultConfidence: 'high',
    notes: 'Eggs are bought and cooked by count, so count IS the canonical unit. Never convert eggs to grams -- it makes "3 eggs" minus "1 dozen" meaningless.',
  },
  { pattern: 'milk', category: 'dairy', canonicalUnit: 'ml', countUnits: { carton: 1890, bottle: 1000, container: 1890 }, defaultConfidence: 'high' },
  { pattern: 'heavy cream', category: 'dairy', canonicalUnit: 'ml', countUnits: { carton: 473, container: 473 } },
  { pattern: 'butter', category: 'dairy', canonicalUnit: 'g', perCup: 227, countUnits: { stick: 113, package: 454 }, unitConfidence: { stick: 'high' } },
  { pattern: 'cheese', category: 'dairy', canonicalUnit: 'g', perCup: 113, countUnits: { slice: 20, block: 226, bag: 226, package: 226 }, notes: 'perCup is shredded.' },
  { pattern: 'parmesan', category: 'dairy', canonicalUnit: 'g', perCup: 100, countUnits: { block: 226, container: 226 } },
  { pattern: 'feta', category: 'dairy', canonicalUnit: 'g', perCup: 150, countUnits: { block: 200, container: 200 } },
  { pattern: 'mozzarella', category: 'dairy', canonicalUnit: 'g', perCup: 112, countUnits: { ball: 125, block: 226, bag: 226 } },
  { pattern: 'yogurt', category: 'dairy', canonicalUnit: 'g', perCup: 245, countUnits: { container: 170, tub: 907 } },
  { pattern: 'sour cream', category: 'dairy', canonicalUnit: 'g', perCup: 240, countUnits: { container: 454, tub: 454 } },
  { pattern: 'cream cheese', category: 'dairy', canonicalUnit: 'g', perCup: 232, countUnits: { block: 226, package: 226 } },

  // --- dry goods -----------------------------------------------------------
  { pattern: 'flour', category: 'pantry_dry', canonicalUnit: 'g', perCup: 120, countUnits: { bag: 2270 }, defaultConfidence: 'high', notes: 'All-purpose, spooned and levelled. Scooping gives ~140 g -- this is the standard reference figure.' },
  { pattern: 'rice', category: 'pantry_dry', canonicalUnit: 'g', perCup: 185, countUnits: { bag: 907 }, defaultConfidence: 'high', notes: 'Uncooked long-grain.' },
  { pattern: 'cooked rice', category: 'pantry_dry', canonicalUnit: 'g', perCup: 158, notes: 'Kept distinct from dry rice on purpose: they are not interchangeable.' },
  { pattern: 'sugar', category: 'pantry_dry', canonicalUnit: 'g', perCup: 200, countUnits: { bag: 1814 }, defaultConfidence: 'high' },
  { pattern: 'brown sugar', category: 'pantry_dry', canonicalUnit: 'g', perCup: 213, countUnits: { bag: 454 }, defaultConfidence: 'high' },
  { pattern: 'powdered sugar', category: 'pantry_dry', canonicalUnit: 'g', perCup: 120, countUnits: { bag: 454 } },
  { pattern: 'oat', category: 'pantry_dry', canonicalUnit: 'g', perCup: 90, countUnits: { container: 1190, bag: 1190 } },
  { pattern: 'pasta', category: 'pantry_dry', canonicalUnit: 'g', perCup: 105, countUnits: { box: 454, bag: 454, package: 454 }, notes: 'Dry.' },
  { pattern: 'quinoa', category: 'pantry_dry', canonicalUnit: 'g', perCup: 170, countUnits: { bag: 454 } },
  { pattern: 'lentil', category: 'pantry_dry', canonicalUnit: 'g', perCup: 192, countUnits: { bag: 454, can: 425 } },
  { pattern: 'breadcrumb', category: 'pantry_dry', canonicalUnit: 'g', perCup: 108, countUnits: { container: 425 } },
  { pattern: 'cornmeal', category: 'pantry_dry', canonicalUnit: 'g', perCup: 160, countUnits: { bag: 907 } },
  { pattern: 'cornstarch', category: 'pantry_dry', canonicalUnit: 'g', perCup: 128, countUnits: { container: 454 } },
  { pattern: 'cocoa', category: 'pantry_dry', canonicalUnit: 'g', perCup: 85, countUnits: { container: 227 } },
  { pattern: 'chocolate chip', category: 'pantry_dry', canonicalUnit: 'g', perCup: 170, countUnits: { bag: 340 } },
  { pattern: 'almond', category: 'pantry_dry', canonicalUnit: 'g', perCup: 143, countUnits: { bag: 454 } },
  { pattern: 'walnut', category: 'pantry_dry', canonicalUnit: 'g', perCup: 117, countUnits: { bag: 454 } },
  { pattern: 'peanut', category: 'pantry_dry', canonicalUnit: 'g', perCup: 146, countUnits: { bag: 454 } },
  { pattern: 'raisin', category: 'pantry_dry', canonicalUnit: 'g', perCup: 145, countUnits: { bag: 425 } },
  { pattern: 'baking powder', category: 'pantry_dry', canonicalUnit: 'g', perCup: 220, countUnits: { container: 227 } },
  { pattern: 'baking soda', category: 'pantry_dry', canonicalUnit: 'g', perCup: 230, countUnits: { box: 454 } },

  // --- canned --------------------------------------------------------------
  { pattern: 'bean', category: 'canned', canonicalUnit: 'g', perCup: 190, countUnits: { can: 425, bag: 454 }, unitConfidence: { can: 'high' }, notes: 'Generic fallback; a standard 15 oz can drains to ~425 g gross.' },
  { pattern: 'black bean', category: 'canned', canonicalUnit: 'g', perCup: 190, countUnits: { can: 425, bag: 454 }, unitConfidence: { can: 'high' } },
  { pattern: 'chickpea', category: 'canned', canonicalUnit: 'g', perCup: 164, countUnits: { can: 425, bag: 454 }, unitConfidence: { can: 'high' } },
  { pattern: 'kidney bean', category: 'canned', canonicalUnit: 'g', perCup: 177, countUnits: { can: 425, bag: 454 }, unitConfidence: { can: 'high' } },
  { pattern: 'coconut milk', category: 'canned', canonicalUnit: 'ml', countUnits: { can: 400 }, unitConfidence: { can: 'high' } },
  { pattern: 'broth', category: 'canned', canonicalUnit: 'ml', countUnits: { can: 400, carton: 946, box: 946 }, unitConfidence: { carton: 'high' } },
  { pattern: 'stock', category: 'canned', canonicalUnit: 'ml', countUnits: { can: 400, carton: 946, box: 946 } },

  // --- condiments & oils ---------------------------------------------------
  { pattern: 'olive oil', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 500 }, defaultConfidence: 'high', notes: 'Volume units are universal; only the bottle size is a guess.' },
  { pattern: 'vegetable oil', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 1000 } },
  { pattern: 'canola oil', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 1000 } },
  { pattern: 'sesame oil', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 250 } },
  { pattern: 'soy sauce', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 500, packet: 6 } },
  { pattern: 'vinegar', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 500 } },
  { pattern: 'hot sauce', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 150 } },
  { pattern: 'ketchup', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 570, packet: 9 } },
  { pattern: 'mustard', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 250, jar: 250, packet: 6 } },
  { pattern: 'mayonnaise', category: 'condiment', canonicalUnit: 'ml', countUnits: { jar: 440, bottle: 440 } },
  { pattern: 'maple syrup', category: 'condiment', canonicalUnit: 'ml', countUnits: { bottle: 355 } },
  { pattern: 'honey', category: 'condiment', canonicalUnit: 'g', perCup: 340, countUnits: { jar: 340, bottle: 340 }, notes: 'Honey is sold and used by weight often enough that grams is the safer canonical unit; perCup carries the density.' },
  { pattern: 'peanut butter', category: 'condiment', canonicalUnit: 'g', perCup: 258, countUnits: { jar: 454 } },
  { pattern: 'salsa', category: 'condiment', canonicalUnit: 'g', perCup: 245, countUnits: { jar: 454 } },

  // --- spices --------------------------------------------------------------
  {
    pattern: 'salt',
    category: 'spice',
    canonicalUnit: 'g',
    perCup: 292,
    countUnits: { pinch: 0.36, container: 737 },
    unitConfidence: { pinch: 'low' },
    notes: 'Table salt. Kosher salt is much less dense -- see its own profile.',
  },
  { pattern: 'kosher salt', category: 'spice', canonicalUnit: 'g', perCup: 218, countUnits: { pinch: 0.27, box: 1360 } },
  { pattern: 'black pepper', category: 'spice', canonicalUnit: 'g', perCup: 110, countUnits: { pinch: 0.14, jar: 60 } },
  { pattern: 'cinnamon', category: 'spice', canonicalUnit: 'g', perCup: 124, countUnits: { jar: 60, stick: 2 } },
  { pattern: 'paprika', category: 'spice', canonicalUnit: 'g', perCup: 108, countUnits: { jar: 60 } },
  { pattern: 'cumin', category: 'spice', canonicalUnit: 'g', perCup: 96, countUnits: { jar: 50 } },
  { pattern: 'oregano', category: 'spice', canonicalUnit: 'g', perCup: 48, countUnits: { jar: 20, bunch: 25 } },
  { pattern: 'bay leaf', category: 'spice', canonicalUnit: 'g', countUnits: { leaf: 0.2, count: 0.2, jar: 5 } },
  { pattern: 'chili flake', category: 'spice', canonicalUnit: 'g', perCup: 96, countUnits: { jar: 30 } },

  // --- bakery --------------------------------------------------------------
  { pattern: 'bread', category: 'bakery', canonicalUnit: 'g', countUnits: { loaf: 500, slice: 30, count: 500 }, unitConfidence: { slice: 'medium', loaf: 'medium' } },
  { pattern: 'tortilla', category: 'bakery', canonicalUnit: 'g', countUnits: { count: 45, package: 450, bag: 450 }, unitConfidence: { count: 'medium' } },
  { pattern: 'bagel', category: 'bakery', canonicalUnit: 'g', countUnits: { count: 100, bag: 600 } },
  { pattern: 'bun', category: 'bakery', canonicalUnit: 'g', countUnits: { count: 60, package: 480 } },
  { pattern: 'pita', category: 'bakery', canonicalUnit: 'g', countUnits: { count: 60, package: 360 } },

  // --- beverages -----------------------------------------------------------
  { pattern: 'juice', category: 'beverage', canonicalUnit: 'ml', countUnits: { bottle: 1890, carton: 1890 } },
  { pattern: 'wine', category: 'beverage', canonicalUnit: 'ml', countUnits: { bottle: 750 }, defaultConfidence: 'high' },
  { pattern: 'beer', category: 'beverage', canonicalUnit: 'ml', countUnits: { can: 355, bottle: 355 }, defaultConfidence: 'high' },
  { pattern: 'soda', category: 'beverage', canonicalUnit: 'ml', countUnits: { can: 355, bottle: 2000 } },

  // --- frozen --------------------------------------------------------------
  { pattern: 'frozen pea', category: 'frozen', canonicalUnit: 'g', perCup: 145, countUnits: { bag: 340 } },
  { pattern: 'frozen berry', category: 'frozen', canonicalUnit: 'g', perCup: 140, countUnits: { bag: 340 } },
  { pattern: 'frozen corn', category: 'frozen', canonicalUnit: 'g', perCup: 145, countUnits: { bag: 340 } },
  { pattern: 'ice cream', category: 'frozen', canonicalUnit: 'ml', countUnits: { container: 1420, tub: 1420, pint: 473 } },
  { pattern: 'tofu', category: 'other', canonicalUnit: 'g', countUnits: { block: 400, package: 400, container: 400 }, unitConfidence: { block: 'high' } },
];

// ---------------------------------------------------------------------------
// Category fallbacks
// ---------------------------------------------------------------------------

/**
 * Used only when no item profile matches. Everything resolved through here comes
 * back at LOW confidence regardless of the numbers below -- these are category
 * averages, and the whole point of the confidence field is to keep an average
 * from being mistaken for a measurement.
 */
export const CATEGORY_FALLBACKS: Record<PantryCategory, CategoryFallback> = {
  produce: {
    canonicalUnit: 'g',
    perMl: 0.6,
    units: {
      bunch: 60,
      head: 400,
      stalk: 40,
      rib: 40,
      sprig: 2,
      leaf: 5,
      clove: 5,
      floret: 12,
      ear: 90,
      count: 120,
      handful: 30,
      piece: 100,
      bag: 340,
      package: 340,
      container: 340,
      wedge: 30,
    },
  },
  meat: {
    canonicalUnit: 'g',
    perMl: 1.0,
    units: {
      breast: 175,
      thigh: 110,
      drumstick: 100,
      wing: 90,
      fillet: 170,
      slice: 25,
      strip: 20,
      link: 75,
      patty: 113,
      count: 150,
      piece: 120,
      package: 450,
    },
  },
  seafood: {
    canonicalUnit: 'g',
    perMl: 1.0,
    units: { fillet: 170, can: 140, count: 20, piece: 120, package: 450, bag: 454 },
  },
  dairy: {
    canonicalUnit: 'g',
    perMl: 1.03,
    units: {
      stick: 113,
      slice: 20,
      block: 226,
      ball: 125,
      container: 450,
      tub: 450,
      carton: 946,
      package: 226,
      count: 100,
    },
  },
  frozen: {
    canonicalUnit: 'g',
    perMl: 0.7,
    units: { bag: 340, box: 283, package: 340, container: 473, count: 100 },
  },
  pantry_dry: {
    canonicalUnit: 'g',
    perMl: 0.6,
    units: { bag: 454, box: 454, package: 454, container: 500, can: 425, count: 454 },
  },
  canned: {
    canonicalUnit: 'g',
    perMl: 1.0,
    units: { can: 400, jar: 450, count: 400, package: 400, container: 400 },
  },
  condiment: {
    canonicalUnit: 'ml',
    perMl: 1.0,
    units: { bottle: 500, jar: 350, packet: 10, can: 400, count: 350, container: 350, sachet: 10 },
  },
  spice: {
    canonicalUnit: 'g',
    perMl: 0.5,
    units: { jar: 45, container: 45, count: 45, pinch: 0.36, dash: 0.36, packet: 5 },
  },
  bakery: {
    canonicalUnit: 'g',
    perMl: 0.35,
    units: { loaf: 500, slice: 30, count: 80, package: 400, bag: 500, box: 400 },
  },
  beverage: {
    canonicalUnit: 'ml',
    perMl: 1.0,
    units: { bottle: 500, can: 355, carton: 1890, count: 355, container: 500 },
  },
  other: {
    canonicalUnit: 'count',
    units: { count: 1, package: 1, container: 1, piece: 1, bag: 1, box: 1 },
  },
};

/**
 * Fuzzy units that are true of anything, used when the item and category are
 * both unknown. All low confidence, by definition.
 */
export const UNIVERSAL_FUZZY_UNITS: Array<{
  unit: string;
  canonicalUnit: CanonicalUnit;
  multiplier: number;
  notes: string;
}> = [
  { unit: 'pinch', canonicalUnit: 'g', multiplier: 0.36, notes: 'About 1/16 tsp of a fine dry ingredient.' },
  { unit: 'dash', canonicalUnit: 'ml', multiplier: 0.6, notes: 'About 1/8 tsp.' },
  { unit: 'splash', canonicalUnit: 'ml', multiplier: 15, notes: 'Roughly a tablespoon.' },
  { unit: 'drizzle', canonicalUnit: 'ml', multiplier: 10, notes: 'Roughly two teaspoons.' },
  { unit: 'handful', canonicalUnit: 'g', multiplier: 30, notes: 'Depends entirely on the hand and the food.' },
  { unit: 'knob', canonicalUnit: 'g', multiplier: 15, notes: 'A knob of butter or ginger.' },
];
