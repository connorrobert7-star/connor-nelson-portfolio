/**
 * Shelf-life reference data.
 *
 * READ THIS BEFORE SHOWING A DATE TO A USER: every number here is an ESTIMATE.
 * They are typical "best quality" windows from food-safety guidance, and real
 * food ignores them constantly -- a bag of spinach can turn in two days or last
 * nine. Nothing derived from this table may be phrased as if the app knows when
 * something actually expires. The `confidence` column exists so the UI can mark
 * the shaky ones, and the spec requires every displayed date to be visually
 * flagged as an estimate regardless of confidence.
 *
 * `null` means "not a sensible way to store this": raw chicken has no pantry
 * shelf life, and there is no honest number to put there.
 */

import type { Confidence, PantryCategory } from '../units/types.ts';

export interface ShelfLifeEntry {
  category: PantryCategory;
  /** Null for the category default. Matched as a whole word against the normalized name. */
  itemNamePattern: string | null;
  daysRefrigerated: number | null;
  daysPantry: number | null;
  daysFrozen: number | null;
  confidence: Confidence;
  notes?: string;
  seedKey: string;
}

type EntryInput = {
  pattern: string | null;
  fridge?: number | null;
  pantry?: number | null;
  frozen?: number | null;
  confidence?: Confidence;
  notes?: string;
};

function entries(category: PantryCategory, list: EntryInput[]): ShelfLifeEntry[] {
  return list.map((item) => ({
    category,
    itemNamePattern: item.pattern,
    daysRefrigerated: item.fridge ?? null,
    daysPantry: item.pantry ?? null,
    daysFrozen: item.frozen ?? null,
    confidence: item.confidence ?? 'medium',
    ...(item.notes !== undefined ? { notes: item.notes } : {}),
    seedKey: `shelf:${category}:${item.pattern ?? '__default__'}`,
  }));
}

export const SHELF_LIFE_REFERENCE: ShelfLifeEntry[] = [
  // --- produce -------------------------------------------------------------
  ...entries('produce', [
    { pattern: null, fridge: 7, pantry: 5, frozen: 240, confidence: 'low', notes: 'Category default; produce varies enormously.' },

    // Leafy greens and soft herbs: the fastest-spoiling thing most people buy.
    { pattern: 'lettuce', fridge: 7 },
    { pattern: 'romaine', fridge: 7 },
    { pattern: 'spinach', fridge: 5, frozen: 240 },
    { pattern: 'kale', fridge: 5 },
    { pattern: 'arugula', fridge: 5 },
    { pattern: 'cilantro', fridge: 7, notes: 'Longer if stood in water; this assumes the bag it came in.' },
    { pattern: 'parsley', fridge: 10 },
    { pattern: 'basil', fridge: 5, confidence: 'low', notes: 'Hates the fridge; blackens fast.' },
    { pattern: 'dill', fridge: 7 },
    { pattern: 'mint', fridge: 7 },
    { pattern: 'chive', fridge: 7 },

    // Berries.
    { pattern: 'strawberry', fridge: 5, frozen: 240 },
    { pattern: 'blueberry', fridge: 10, frozen: 240 },
    { pattern: 'raspberry', fridge: 3, frozen: 240 },
    { pattern: 'blackberry', fridge: 3, frozen: 240 },

    // Citrus keeps far longer than people expect.
    { pattern: 'lemon', fridge: 21, pantry: 7, confidence: 'high' },
    { pattern: 'lime', fridge: 21, pantry: 7, confidence: 'high' },
    { pattern: 'orange', fridge: 21, pantry: 7, confidence: 'high' },
    { pattern: 'grapefruit', fridge: 21, pantry: 7 },

    { pattern: 'banana', pantry: 5, fridge: 7, confidence: 'medium', notes: 'The fridge blackens the skin but keeps the flesh.' },
    { pattern: 'avocado', fridge: 4, pantry: 3, confidence: 'low', notes: 'Depends entirely on ripeness at purchase.' },
    { pattern: 'tomato', fridge: 7, pantry: 5, notes: 'Pantry is better for flavour; fridge for longevity.' },
    { pattern: 'apple', fridge: 30, pantry: 7, confidence: 'high' },
    { pattern: 'grape', fridge: 7 },

    // Roots and alliums: the long-lived end of the produce aisle.
    { pattern: 'carrot', fridge: 30, confidence: 'high' },
    { pattern: 'potato', pantry: 60, confidence: 'high', notes: 'Cool and dark. Refrigeration turns the starch sweet.' },
    { pattern: 'sweet potato', pantry: 40 },
    { pattern: 'onion', pantry: 45, fridge: 60, confidence: 'high' },
    { pattern: 'shallot', pantry: 30 },
    { pattern: 'garlic', pantry: 90, confidence: 'high' },
    { pattern: 'ginger', fridge: 21, frozen: 180 },
    { pattern: 'beet', fridge: 30 },
    { pattern: 'turnip', fridge: 30 },
    { pattern: 'radish', fridge: 14 },
    { pattern: 'leek', fridge: 14 },
    { pattern: 'scallion', fridge: 10 },
    { pattern: 'green onion', fridge: 10 },

    { pattern: 'celery', fridge: 21 },
    { pattern: 'cucumber', fridge: 7 },
    { pattern: 'zucchini', fridge: 7 },
    { pattern: 'eggplant', fridge: 7 },
    { pattern: 'bell pepper', fridge: 12 },
    { pattern: 'jalapeno', fridge: 14 },
    { pattern: 'mushroom', fridge: 7, notes: 'Paper bag, not plastic.' },
    { pattern: 'broccoli', fridge: 7, frozen: 240 },
    { pattern: 'cauliflower', fridge: 7, frozen: 240 },
    { pattern: 'cabbage', fridge: 30, confidence: 'high' },
    { pattern: 'green bean', fridge: 7, frozen: 240 },
    { pattern: 'asparagus', fridge: 4 },
    { pattern: 'corn', fridge: 5, frozen: 240 },
    { pattern: 'pea', fridge: 5, frozen: 240 },
  ]),

  // --- meat ----------------------------------------------------------------
  ...entries('meat', [
    { pattern: null, fridge: 3, frozen: 180, confidence: 'low' },
    { pattern: 'chicken', fridge: 2, frozen: 270, confidence: 'high', notes: 'Raw poultry. USDA says 1-2 days.' },
    { pattern: 'turkey', fridge: 2, frozen: 270, confidence: 'high' },
    { pattern: 'ground beef', fridge: 2, frozen: 120, confidence: 'high', notes: 'Ground meat spoils faster than whole cuts: more surface area.' },
    { pattern: 'ground pork', fridge: 2, frozen: 120, confidence: 'high' },
    { pattern: 'ground turkey', fridge: 2, frozen: 120, confidence: 'high' },
    { pattern: 'ground chicken', fridge: 2, frozen: 120, confidence: 'high' },
    { pattern: 'beef', fridge: 4, frozen: 270, confidence: 'high', notes: 'Whole cuts.' },
    { pattern: 'steak', fridge: 4, frozen: 270, confidence: 'high' },
    { pattern: 'pork', fridge: 4, frozen: 180, confidence: 'high' },
    { pattern: 'lamb', fridge: 4, frozen: 270 },
    { pattern: 'bacon', fridge: 7, frozen: 30 },
    { pattern: 'sausage', fridge: 2, frozen: 60 },
    { pattern: 'deli meat', fridge: 4, frozen: 60, confidence: 'high' },
    { pattern: 'ham', fridge: 5, frozen: 60 },
    { pattern: 'hot dog', fridge: 14, frozen: 60 },
  ]),

  // --- seafood -------------------------------------------------------------
  ...entries('seafood', [
    { pattern: null, fridge: 2, frozen: 180, confidence: 'medium' },
    { pattern: 'salmon', fridge: 2, frozen: 90, confidence: 'high' },
    { pattern: 'cod', fridge: 2, frozen: 180 },
    { pattern: 'tuna', fridge: 2, frozen: 90 },
    { pattern: 'shrimp', fridge: 2, frozen: 180, confidence: 'high' },
    { pattern: 'scallop', fridge: 2, frozen: 90 },
    { pattern: 'fish', fridge: 2, frozen: 180, confidence: 'high' },
  ]),

  // --- dairy ---------------------------------------------------------------
  ...entries('dairy', [
    { pattern: null, fridge: 14, frozen: 90, confidence: 'low' },
    { pattern: 'milk', fridge: 7, frozen: 90, confidence: 'high', notes: 'From opening, or roughly the printed date.' },
    { pattern: 'heavy cream', fridge: 10, frozen: 120 },
    { pattern: 'butter', fridge: 30, frozen: 270, confidence: 'high' },
    { pattern: 'yogurt', fridge: 14, confidence: 'high' },
    { pattern: 'sour cream', fridge: 21 },
    { pattern: 'cream cheese', fridge: 14 },
    { pattern: 'cottage cheese', fridge: 10 },
    { pattern: 'cheese', fridge: 30, frozen: 180, confidence: 'medium', notes: 'Hard cheese. Soft cheeses have their own rows.' },
    { pattern: 'cheddar', fridge: 30, frozen: 180, confidence: 'high' },
    { pattern: 'parmesan', fridge: 60, confidence: 'high' },
    { pattern: 'feta', fridge: 10, notes: 'Soft cheese; longer if kept in brine.' },
    { pattern: 'mozzarella', fridge: 10 },
    { pattern: 'ricotta', fridge: 7 },
    { pattern: 'brie', fridge: 10 },
    { pattern: 'egg', fridge: 28, confidence: 'high', notes: 'Refrigerated, in the shell, from purchase.' },
  ]),

  // --- bakery --------------------------------------------------------------
  ...entries('bakery', [
    { pattern: null, fridge: 10, pantry: 5, frozen: 90, confidence: 'low' },
    { pattern: 'bread', pantry: 5, fridge: 14, frozen: 90, confidence: 'high', notes: 'The fridge extends it but stales it faster.' },
    { pattern: 'tortilla', fridge: 30, pantry: 7, frozen: 180 },
    { pattern: 'bagel', pantry: 5, frozen: 90 },
    { pattern: 'bun', pantry: 5, frozen: 90 },
    { pattern: 'pita', pantry: 5, frozen: 90 },
    { pattern: 'cake', fridge: 4, pantry: 2 },
  ]),

  // --- dry goods -----------------------------------------------------------
  ...entries('pantry_dry', [
    { pattern: null, pantry: 365, confidence: 'medium' },
    { pattern: 'rice', pantry: 730, confidence: 'high', notes: 'White rice. Brown rice has oils and turns in ~180 days.' },
    { pattern: 'pasta', pantry: 730, confidence: 'high' },
    { pattern: 'flour', pantry: 365, confidence: 'high' },
    { pattern: 'sugar', pantry: 1095, confidence: 'high' },
    { pattern: 'bean', pantry: 730, confidence: 'high', notes: 'Dry beans. They stay safe far longer but stop softening properly.' },
    { pattern: 'lentil', pantry: 730, confidence: 'high' },
    { pattern: 'oat', pantry: 365, confidence: 'high' },
    { pattern: 'quinoa', pantry: 730 },
    { pattern: 'almond', pantry: 180, fridge: 365, notes: 'Nuts go rancid; the fridge roughly doubles them.' },
    { pattern: 'walnut', pantry: 120, fridge: 365 },
    { pattern: 'peanut', pantry: 180, fridge: 365 },
    { pattern: 'breadcrumb', pantry: 180 },
    { pattern: 'cornstarch', pantry: 730 },
    { pattern: 'baking powder', pantry: 365, confidence: 'high', notes: 'Still safe after this, but stops lifting.' },
    { pattern: 'baking soda', pantry: 730 },
    { pattern: 'chocolate chip', pantry: 365 },
  ]),

  // --- canned --------------------------------------------------------------
  ...entries('canned', [
    { pattern: null, pantry: 730, fridge: 4, confidence: 'medium', notes: 'Pantry figure is unopened; fridge figure is after opening.' },
    { pattern: 'coconut milk', pantry: 730, fridge: 5 },
    { pattern: 'broth', pantry: 365, fridge: 4, confidence: 'high' },
    { pattern: 'stock', pantry: 365, fridge: 4, confidence: 'high' },
    { pattern: 'tomato paste', pantry: 730, fridge: 5 },
    { pattern: 'tomato sauce', pantry: 730, fridge: 5 },
    { pattern: 'chickpea', pantry: 1095, fridge: 4 },
    { pattern: 'black bean', pantry: 1095, fridge: 4 },
    { pattern: 'kidney bean', pantry: 1095, fridge: 4 },
  ]),

  // --- condiments ----------------------------------------------------------
  ...entries('condiment', [
    { pattern: null, fridge: 180, pantry: 365, confidence: 'low', notes: 'Opened condiments vary wildly; this is a placeholder.' },
    { pattern: 'ketchup', fridge: 180, confidence: 'high' },
    { pattern: 'mustard', fridge: 365, confidence: 'high' },
    { pattern: 'mayonnaise', fridge: 60, confidence: 'high', notes: 'From opening.' },
    { pattern: 'soy sauce', fridge: 730, pantry: 365, confidence: 'high' },
    { pattern: 'hot sauce', fridge: 365, pantry: 180 },
    { pattern: 'olive oil', pantry: 540, confidence: 'high', notes: 'Unopened. Once opened, about 4 months before it tastes flat.' },
    { pattern: 'vegetable oil', pantry: 365 },
    { pattern: 'canola oil', pantry: 365 },
    { pattern: 'sesame oil', pantry: 365, fridge: 730 },
    { pattern: 'vinegar', pantry: 1095, confidence: 'high', notes: 'Essentially indefinite.' },
    { pattern: 'honey', pantry: 1825, confidence: 'high', notes: 'Does not spoil. Crystallizing is not spoiling.' },
    { pattern: 'maple syrup', fridge: 365 },
    { pattern: 'peanut butter', pantry: 90, fridge: 180 },
    { pattern: 'jam', fridge: 180 },
    { pattern: 'salsa', fridge: 14, notes: 'From opening.' },
  ]),

  // --- spices --------------------------------------------------------------
  ...entries('spice', [
    { pattern: null, pantry: 730, confidence: 'medium', notes: 'Ground spices lose potency long before they become unsafe.' },
    { pattern: 'salt', pantry: 3650, confidence: 'high', notes: 'Does not expire.' },
    { pattern: 'black pepper', pantry: 1095 },
    { pattern: 'cinnamon', pantry: 1095 },
    { pattern: 'paprika', pantry: 730 },
    { pattern: 'cumin', pantry: 730 },
    { pattern: 'oregano', pantry: 730 },
    { pattern: 'bay leaf', pantry: 730 },
    { pattern: 'chili flake', pantry: 730 },
    { pattern: 'vanilla extract', pantry: 1460, confidence: 'high' },
  ]),

  // --- beverages -----------------------------------------------------------
  ...entries('beverage', [
    { pattern: null, fridge: 10, pantry: 180, confidence: 'low' },
    { pattern: 'juice', fridge: 10, notes: 'From opening.' },
    { pattern: 'wine', pantry: 1095, fridge: 5, notes: 'Pantry is unopened; fridge is after opening.' },
    { pattern: 'beer', fridge: 180, pantry: 180 },
    { pattern: 'soda', pantry: 270, fridge: 270 },
  ]),

  // --- frozen --------------------------------------------------------------
  ...entries('frozen', [
    { pattern: null, frozen: 240, confidence: 'medium' },
    { pattern: 'frozen pea', frozen: 240 },
    { pattern: 'frozen berry', frozen: 240 },
    { pattern: 'frozen corn', frozen: 240 },
    { pattern: 'ice cream', frozen: 60, confidence: 'high', notes: 'Safe far longer; this is when it goes icy.' },
  ]),

  // --- other ---------------------------------------------------------------
  ...entries('other', [
    { pattern: null, fridge: 7, pantry: 30, frozen: 180, confidence: 'low' },
    { pattern: 'leftover', fridge: 4, frozen: 90, confidence: 'high', notes: 'USDA guidance for cooked leftovers.' },
    { pattern: 'tofu', fridge: 7, frozen: 150, notes: 'From opening; unopened lasts to its printed date.' },
    { pattern: 'hummus', fridge: 7 },
  ]),
];

/**
 * Where a category is assumed to live when nothing else is known. Phase 4 uses
 * this: refrigerate produce, dairy, meat and seafood; everything else goes in
 * the cupboard.
 */
export const DEFAULT_STORAGE_BY_CATEGORY: Record<
  PantryCategory,
  'refrigerated' | 'pantry' | 'frozen'
> = {
  produce: 'refrigerated',
  dairy: 'refrigerated',
  meat: 'refrigerated',
  seafood: 'refrigerated',
  frozen: 'frozen',
  pantry_dry: 'pantry',
  canned: 'pantry',
  condiment: 'pantry',
  spice: 'pantry',
  bakery: 'pantry',
  beverage: 'pantry',
  other: 'pantry',
};
