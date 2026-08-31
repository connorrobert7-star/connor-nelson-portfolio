/**
 * Unit normalization.
 *
 * Free text goes in ("Tbsp.", "tablespoons", "fluid ounces", "cloves"), one
 * canonical alias token comes out ("tbsp", "tbsp", "fl_oz", "clove"). Every
 * lookup in the conversion table happens on these tokens, so this file is the
 * only place that has to know how many ways there are to spell "tablespoon".
 */

import type { Dimension } from './types.js';

/** Weight units convertible to grams by pure arithmetic. */
export const WEIGHT_UNITS_IN_G: Record<string, number> = {
  mg: 0.001,
  g: 1,
  kg: 1000,
  oz: 28.349523125,
  lb: 453.59237,
};

/** Volume units convertible to millilitres by pure arithmetic (US measures). */
export const VOLUME_UNITS_IN_ML: Record<string, number> = {
  ml: 1,
  l: 1000,
  tsp: 4.92892159375,
  tbsp: 14.78676478125,
  fl_oz: 29.5735295625,
  cup: 236.5882365,
  pint: 473.176473,
  quart: 946.352946,
  gallon: 3785.411784,
};

/**
 * Units that describe a countable or vaguely-sized thing. They carry no
 * dimension of their own -- "1 bunch" only becomes grams via a conversion rule,
 * never via arithmetic.
 */
export const COUNT_UNITS = new Set<string>([
  'count',
  'dozen',
  'pinch',
  'dash',
  'splash',
  'drizzle',
  'handful',
  'bunch',
  'clove',
  'head',
  'stalk',
  'sprig',
  'leaf',
  'ear',
  'can',
  'jar',
  'bottle',
  'carton',
  'package',
  'bag',
  'box',
  'container',
  'tub',
  'tube',
  'slice',
  'strip',
  'fillet',
  'breast',
  'thigh',
  'drumstick',
  'wing',
  'stick',
  'loaf',
  'block',
  'knob',
  'sheet',
  'packet',
  'scoop',
  'rib',
  'floret',
  'wedge',
  'segment',
  'piece',
  'ball',
  'link',
  'patty',
  'bar',
  'sachet',
  'bulb',
  'kernel',
  'pod',
  'root',
]);

/**
 * Spelling variants -> alias token. Plurals and trailing periods are stripped
 * before lookup, so only genuinely different spellings need an entry here.
 */
const ALIASES: Record<string, string> = {
  // weight
  milligram: 'mg',
  mgs: 'mg',
  gram: 'g',
  gramme: 'g',
  gr: 'g',
  gm: 'g',
  gms: 'g',
  kilogram: 'kg',
  kilo: 'kg',
  kgs: 'kg',
  ounce: 'oz',
  ozs: 'oz',
  pound: 'lb',
  lbs: 'lb',
  '#': 'lb',

  // volume
  milliliter: 'ml',
  millilitre: 'ml',
  mls: 'ml',
  cc: 'ml',
  liter: 'l',
  litre: 'l',
  teaspoon: 'tsp',
  tsps: 'tsp',
  tspn: 'tsp',
  ts: 'tsp',
  tablespoon: 'tbsp',
  tbsps: 'tbsp',
  tbs: 'tbsp',
  tbl: 'tbsp',
  tblsp: 'tbsp',
  'fluid ounce': 'fl_oz',
  floz: 'fl_oz',
  'fl oz': 'fl_oz',
  'fl. oz': 'fl_oz',
  'fluid oz': 'fl_oz',
  cups: 'cup',
  pt: 'pint',
  qt: 'quart',
  gal: 'gallon',

  // count / descriptive
  each: 'count',
  ea: 'count',
  whole: 'count',
  unit: 'count',
  item: 'count',
  no: 'count',
  x: 'count',
  doz: 'dozen',
  bnch: 'bunch',
  pkg: 'package',
  pkt: 'packet',
  pack: 'package',
  btl: 'bottle',
  ct: 'count',
  cn: 'can',
  tin: 'can',
  bundle: 'bunch',
  clv: 'clove',
  fillets: 'fillet',
  filet: 'fillet',
  cube: 'block',
  chunk: 'piece',
};

/** Size adjectives that sometimes arrive in the unit slot ("2 large eggs"). */
export const SIZE_WORDS: Record<string, number> = {
  tiny: 0.6,
  small: 0.75,
  medium: 1,
  regular: 1,
  standard: 1,
  large: 1.3,
  jumbo: 1.5,
  extra_large: 1.45,
};

export interface NormalizedUnit {
  /** Alias token, or '' when no unit was given at all. */
  unit: string;
  /** Size multiplier extracted from a size word in the unit slot. */
  sizeMultiplier: number;
  /** True when the input was a size word only ("2 large"), implying a count. */
  wasSizeOnly: boolean;
  warnings: string[];
}

/** The only -ves plurals that appear in unit names. The generic -ves -> -f
 * rule turns "cloves" into "clof", so it is not used here. */
const IRREGULAR_UNIT_PLURALS: Record<string, string> = {
  cloves: 'clove',
  leaves: 'leaf',
  loaves: 'loaf',
  halves: 'half',
  knives: 'knife',
};

function singularize(token: string): string {
  if (token.length <= 2) return token;
  const irregular = IRREGULAR_UNIT_PLURALS[token];
  if (irregular) return irregular;
  if (token.endsWith('ies')) return `${token.slice(0, -3)}y`;
  if (/(ch|sh|ss|x|z)es$/.test(token)) return token.slice(0, -2);
  if (token.endsWith('oes')) return token.slice(0, -2);
  if (token.endsWith('s') && !token.endsWith('ss')) return token.slice(0, -1);
  return token;
}

/**
 * Normalize a free-text unit.
 *
 * Case matters exactly once, before lowercasing: in recipe shorthand an
 * uppercase "T" is a tablespoon and a lowercase "t" is a teaspoon. Lowercasing
 * first would silently turn a tablespoon of salt into a teaspoon of salt.
 */
export function normalizeUnit(raw: string | null | undefined): NormalizedUnit {
  const warnings: string[] = [];

  if (raw === null || raw === undefined) {
    return { unit: '', sizeMultiplier: 1, wasSizeOnly: false, warnings };
  }

  const trimmed = raw.trim();
  if (trimmed === '') {
    return { unit: '', sizeMultiplier: 1, wasSizeOnly: false, warnings };
  }
  if (trimmed === 'T') return { unit: 'tbsp', sizeMultiplier: 1, wasSizeOnly: false, warnings };
  if (trimmed === 't') return { unit: 'tsp', sizeMultiplier: 1, wasSizeOnly: false, warnings };

  let text = trimmed
    .toLowerCase()
    .replace(/\./g, '')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  // Pull a size word out of the unit slot: "large" in "2 large eggs" is not a
  // unit, it is a scaling hint for whatever count unit applies.
  let sizeMultiplier = 1;
  const sizeMatch = /^(tiny|small|medium|regular|standard|large|jumbo|extra large)\b\s*(.*)$/.exec(
    text,
  );
  if (sizeMatch) {
    const key = (sizeMatch[1] ?? '').replace(/\s+/g, '_');
    sizeMultiplier = SIZE_WORDS[key] ?? 1;
    text = (sizeMatch[2] ?? '').trim();
    if (text === '') {
      return { unit: 'count', sizeMultiplier, wasSizeOnly: true, warnings };
    }
  }

  // Multi-word aliases are checked before singularizing so "fluid ounces" works.
  const multiWord = ALIASES[text];
  if (multiWord) return { unit: multiWord, sizeMultiplier, wasSizeOnly: false, warnings };

  const singular = singularize(text);
  const aliased = ALIASES[singular] ?? ALIASES[text] ?? singular;

  if (
    !(aliased in WEIGHT_UNITS_IN_G) &&
    !(aliased in VOLUME_UNITS_IN_ML) &&
    !COUNT_UNITS.has(aliased)
  ) {
    warnings.push(`Unrecognized unit "${raw}"; treated as a countable thing.`);
  }

  return { unit: aliased, sizeMultiplier, wasSizeOnly: false, warnings };
}

export function dimensionOf(unit: string): Dimension {
  if (unit in WEIGHT_UNITS_IN_G) return 'weight';
  if (unit in VOLUME_UNITS_IN_ML) return 'volume';
  return 'count';
}

/** Is this a unit whose value is inherently fuzzy, regardless of the item? */
export function isFuzzyUnit(unit: string): boolean {
  return (
    unit === 'pinch' ||
    unit === 'dash' ||
    unit === 'splash' ||
    unit === 'drizzle' ||
    unit === 'handful' ||
    unit === 'knob' ||
    unit === 'bunch' ||
    unit === 'head' ||
    unit === 'bulb' ||
    unit === 'piece' ||
    unit === 'chunk'
  );
}
