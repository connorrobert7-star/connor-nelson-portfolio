/**
 * Item name normalization.
 *
 * The normalized name is the join key between a recipe ingredient and a pantry
 * lot, so "2 tbsp finely chopped fresh cilantro, divided" and "1 bunch cilantro"
 * have to collapse to the same string or the pantry diff silently reports a
 * shortfall for something already in the fridge.
 *
 * The hard part is knowing which adjectives are noise and which are identity.
 * "chopped" is noise. "ground" is not: ground beef and beef keep for different
 * lengths of time and are not substitutes. The two lists below encode that, and
 * the bias is deliberate -- when unsure, KEEP the word. A false non-match shows
 * up as "you need to buy this", which is annoying but visible. A false match
 * silently decrements the wrong thing.
 */

/** Noise: prep state and marketing words that never change what the product is. */
const STRIP_WORDS = new Set<string>([
  'chopped',
  'minced',
  'diced',
  'sliced',
  'shredded',
  'grated',
  'crushed',
  'julienned',
  'cubed',
  'halved',
  'quartered',
  'peeled',
  'seeded',
  'deseeded',
  'stemmed',
  'destemmed',
  'trimmed',
  'rinsed',
  'drained',
  'packed',
  'divided',
  'softened',
  'melted',
  'beaten',
  'thinly',
  'thickly',
  'roughly',
  'finely',
  'coarsely',
  'freshly',
  'fresh',
  'ripe',
  'organic',
  'raw',
  'boneless',
  'skinless',
  'bone',
  'skin',
  'tiny',
  'small',
  'medium',
  'large',
  'jumbo',
  'virgin',
  'unsalted',
  'salted',
  'toasted',
  'optional',
  'good',
  'quality',
  'best',
  'plain',
  'plus',
  'more',
  'extra',
  'about',
  'approximately',
  'preferably',
]);

/**
 * Identity: words that change the product. Never stripped, even though they look
 * like adjectives.
 *   ground beef !== beef        (different shelf life, not substitutable)
 *   dried oregano !== oregano   (fresh herbs last days, dried last years)
 *   frozen peas !== peas
 */
const KEEP_WORDS = new Set<string>([
  'ground',
  'dried',
  'frozen',
  'smoked',
  'canned',
  'cooked',
  'sweetened',
  'unsweetened',
  'nonfat',
  'skim',
  'heavy',
  'light',
  'dark',
  'white',
  'brown',
  'black',
  'green',
  'red',
  'yellow',
  'wild',
  'instant',
  'quick',
  'rolled',
  'steel',
  'powdered',
  'confectioners',
  'granulated',
]);

/** Multi-word noise phrases, removed before tokenizing. */
const STRIP_PHRASES = [
  'extra virgin',
  'extra-virgin',
  'room temperature',
  'at room temperature',
  'to taste',
  'for serving',
  'for garnish',
  'for garnishing',
  'for drizzling',
  'for frying',
  'plus more',
  'or more',
  'or so',
  'store bought',
  'store-bought',
  'free range',
  'free-range',
  'grass fed',
  'grass-fed',
  'skin on',
  'skin-on',
  'bone in',
  'bone-in',
  'cut into',
];

/** Irregular plurals worth spelling out. */
const IRREGULAR_SINGULARS: Record<string, string> = {
  leaves: 'leaf',
  loaves: 'loaf',
  halves: 'half',
  knives: 'knife',
  potatoes: 'potato',
  tomatoes: 'tomato',
  mangoes: 'mango',
  avocados: 'avocado',
  radishes: 'radish',
  squashes: 'squash',
  geese: 'goose',
  feet: 'foot',
  teeth: 'tooth',
  children: 'child',
  sheep: 'sheep',
  fish: 'fish',
  shrimp: 'shrimp',
  scallops: 'scallop',
};

/** Words that end in -s but are already singular (or have no singular form). */
const NEVER_SINGULARIZE = new Set<string>([
  'molasses',
  'hummus',
  'couscous',
  'asparagus',
  'greens',
  'grits',
  'brussels',
  'chard',
  'watercress',
  'cress',
  'bass',
  'swiss',
  'grass',
  'glass',
  'gas',
  'bus',
  'is',
  'as',
  'has',
]);

function singularizeWord(word: string): string {
  if (word.length <= 2) return word;
  if (NEVER_SINGULARIZE.has(word)) return word;
  const irregular = IRREGULAR_SINGULARS[word];
  if (irregular) return irregular;
  if (word.endsWith('ies') && word.length > 4) return `${word.slice(0, -3)}y`;
  if (word.endsWith('ves') && word.length > 4) return `${word.slice(0, -3)}f`;
  if (/(ch|sh|ss|x|z)es$/.test(word)) return word.slice(0, -2);
  if (word.endsWith('oes')) return word.slice(0, -2);
  if (word.endsWith('s') && !word.endsWith('ss') && !word.endsWith('us')) return word.slice(0, -1);
  return word;
}

/**
 * "whole" is usually a quantity word ("1 whole onion") but occasionally identity
 * ("whole milk", "whole wheat flour"). Keep it only in front of these.
 */
const WHOLE_IS_IDENTITY = new Set(['milk', 'wheat', 'grain', 'chicken', 'turkey', 'bean', 'egg']);

/**
 * Normalize an item name to its pantry key: lowercase, singular, prep words and
 * parentheticals removed.
 */
export function normalizeItemName(raw: string | null | undefined): string {
  if (!raw) return '';

  let text = raw.toLowerCase();

  // "cilantro, finely chopped" -> "cilantro". Recipe convention puts the
  // ingredient before the comma and the prep instruction after it.
  const commaIndex = text.indexOf(',');
  if (commaIndex > 0) text = text.slice(0, commaIndex);

  // Parentheticals are always asides: "(about 2 cups)", "(optional)".
  text = text.replace(/\([^)]*\)/g, ' ');

  for (const phrase of STRIP_PHRASES) {
    text = text.split(phrase).join(' ');
  }

  text = text
    .replace(/[^a-z0-9\s'&/-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const tokens = text.split(' ').filter(Boolean);
  const kept: string[] = [];

  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i] as string;

    if (token === 'of' || token === 'the' || token === 'a' || token === 'an') continue;
    if (/^\d+([./]\d+)?$/.test(token)) continue;

    if (token === 'whole') {
      const next = tokens[i + 1];
      if (next && WHOLE_IS_IDENTITY.has(singularizeWord(next))) kept.push(token);
      continue;
    }

    if (KEEP_WORDS.has(token)) {
      kept.push(token);
      continue;
    }
    if (STRIP_WORDS.has(token)) continue;

    kept.push(token);
  }

  if (kept.length === 0) return '';

  // Only the head noun is pluralized in English food names: "chicken breasts",
  // "black beans". Singularizing every token would turn "greens" into "green".
  const last = kept[kept.length - 1] as string;
  kept[kept.length - 1] = singularizeWord(last);

  return kept.join(' ').trim();
}

/**
 * Split a free-text ingredient line into its three parts.
 *
 * Used by the tests (so they can be written against the exact strings in the
 * spec) and by Phase 2 when a web recipe arrives as unstructured text. The LLM
 * path returns quantity/unit/name already separated and should not come through
 * here.
 */
export function parseIngredientText(text: string): {
  quantity: string;
  unit: string;
  name: string;
} {
  const UNICODE_FRACTION_RE = /[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒]/;
  const working = text.trim();

  // Leading quantity: digits, fractions, mixed numbers, ranges, or number words.
  const quantityRe = new RegExp(
    String.raw`^\s*(` +
      String.raw`(?:\d+\s+\d+\s*/\s*\d+)` + // 1 1/2
      String.raw`|(?:\d+\s*/\s*\d+)` + // 1/2
      String.raw`|(?:\d*\.?\d+\s*(?:-|–|to)\s*\d*\.?\d+)` + // 2-3
      String.raw`|(?:\d*\.?\d+\s*[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒])` + // 1½
      String.raw`|[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒]` + // ½
      String.raw`|\d*\.?\d+` + // 2
      String.raw`|(?:a couple of|a couple|a few|several|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|dozen|half a|half|quarter)\b` +
      String.raw`)\s*`,
    'i',
  );

  const quantityMatch = quantityRe.exec(working);
  const quantity = (quantityMatch?.[1] ?? '').trim();
  let rest = working.slice(quantityMatch?.[0].length ?? 0).trim();

  rest = rest.replace(/^of\s+/i, '');

  // Unit slot: try the two-word form first so "fl oz" and "extra large" work.
  const words = rest.split(/\s+/).filter(Boolean);
  let unit = '';
  let consumed = 0;

  const twoWord = words.slice(0, 2).join(' ').toLowerCase().replace(/[.,]/g, '');
  const oneWord = (words[0] ?? '').toLowerCase().replace(/[.,]/g, '');

  if (words.length >= 2 && isKnownUnitWord(twoWord)) {
    unit = twoWord;
    consumed = 2;
  } else if (words.length >= 1 && isKnownUnitWord(oneWord)) {
    // A bare unit word with nothing after it is the item itself, not a unit:
    // "2 eggs" is two eggs, not two egg-units of nothing.
    if (words.length > 1) {
      unit = oneWord;
      consumed = 1;
    }
  }

  const name = words.slice(consumed).join(' ').replace(/^of\s+/i, '');

  return {
    quantity: quantity || (UNICODE_FRACTION_RE.test(working) ? working[0] ?? '' : ''),
    unit,
    name,
  };
}

/**
 * Does this word occupy the unit slot? Imported lazily to keep the module graph
 * acyclic -- unitAliases has no dependency on this file.
 */
function isKnownUnitWord(word: string): boolean {
  return KNOWN_UNIT_WORDS.has(word);
}

/**
 * The set of words that may appear in the unit slot. Kept in sync with
 * unitAliases.ts by a test, not by hand.
 */
export const KNOWN_UNIT_WORDS = new Set<string>([
  'mg',
  'milligram',
  'milligrams',
  'g',
  'gram',
  'grams',
  'gm',
  'gms',
  'kg',
  'kilogram',
  'kilograms',
  'kilo',
  'oz',
  'ounce',
  'ounces',
  'lb',
  'lbs',
  'pound',
  'pounds',
  'ml',
  'milliliter',
  'milliliters',
  'millilitre',
  'millilitres',
  'l',
  'liter',
  'liters',
  'litre',
  'litres',
  'tsp',
  'tsps',
  'teaspoon',
  'teaspoons',
  'tbsp',
  'tbsps',
  'tbs',
  'tablespoon',
  'tablespoons',
  'fl oz',
  'floz',
  'fluid ounce',
  'fluid ounces',
  'cup',
  'cups',
  'pint',
  'pints',
  'pt',
  'quart',
  'quarts',
  'qt',
  'gallon',
  'gallons',
  'gal',
  'dozen',
  'pinch',
  'pinches',
  'dash',
  'dashes',
  'splash',
  'drizzle',
  'handful',
  'handfuls',
  'bunch',
  'bunches',
  'clove',
  'cloves',
  'head',
  'heads',
  'stalk',
  'stalks',
  'sprig',
  'sprigs',
  'leaf',
  'leaves',
  'ear',
  'ears',
  'can',
  'cans',
  'jar',
  'jars',
  'bottle',
  'bottles',
  'carton',
  'cartons',
  'package',
  'packages',
  'pack',
  'packet',
  'packets',
  'bag',
  'bags',
  'box',
  'boxes',
  'container',
  'containers',
  'tub',
  'tubs',
  'slice',
  'slices',
  'strip',
  'strips',
  'fillet',
  'fillets',
  'filet',
  'filets',
  'breast',
  'breasts',
  'thigh',
  'thighs',
  'drumstick',
  'drumsticks',
  'wing',
  'wings',
  'stick',
  'sticks',
  'loaf',
  'loaves',
  'block',
  'blocks',
  'knob',
  'sheet',
  'sheets',
  'scoop',
  'scoops',
  'rib',
  'ribs',
  'floret',
  'florets',
  'wedge',
  'wedges',
  'piece',
  'pieces',
  'ball',
  'balls',
  'link',
  'links',
  'patty',
  'patties',
  'bar',
  'bars',
  'bulb',
  'bulbs',
  'pod',
  'pods',
  'small',
  'medium',
  'large',
  'jumbo',
  'extra large',
]);
