/**
 * Inferring a category and staple status from an item name.
 *
 * A confirmed order gives us { name, quantity, unit } and nothing else, but
 * pantry_items.category is NOT NULL and drives both the expiry estimate and the
 * low-stock threshold. Rather than ask the user to categorise every purchase,
 * reuse the conversion dataset -- it already knows that cilantro is produce and
 * a can of chickpeas is canned.
 */

import { ITEM_PROFILES } from './units/conversionData.ts';
import { normalizeItemName } from './units/itemNames.ts';
import { patternMatchesName } from './units/toCanonical.ts';
import type { PantryCategory } from './units/types.ts';

/** Longest matching profile wins, same precedence as the conversion engine. */
export function inferCategory(rawName: string): PantryCategory | null {
  const name = normalizeItemName(rawName);
  if (name === '') return null;

  let best: { pattern: string; category: PantryCategory } | null = null;
  for (const profile of ITEM_PROFILES) {
    if (!patternMatchesName(name, profile.pattern)) continue;
    if (best === null || profile.pattern.length > best.pattern.length) {
      best = { pattern: profile.pattern, category: profile.category };
    }
  }
  return best?.category ?? null;
}

/**
 * Staples are exempt from BOTH expiry nagging and quantity depletion, so this
 * list is deliberately short. Getting it wrong in the generous direction means
 * an item silently never depletes, which corrupts the pantry quietly -- far
 * worse than being nagged about olive oil.
 *
 * Note what is NOT here: rice, flour and sugar are bought in trackable
 * quantities and a recipe using 2 cups of flour really should decrement it.
 * The spec calls flour a staple; it is treated as one for low-stock purposes
 * (20% threshold, via its pantry_dry category) but not exempted from
 * depletion, because "how much flour is left" is a question worth answering.
 */
const STAPLE_PATTERNS = [
  'salt',
  'kosher salt',
  'black pepper',
  'olive oil',
  'vegetable oil',
  'canola oil',
  'sesame oil',
  'vinegar',
  'baking powder',
  'baking soda',
];

export function inferIsStaple(rawName: string, category: PantryCategory | null): boolean {
  const name = normalizeItemName(rawName);
  if (name === '') return false;
  // Every spice is a staple: a recipe calling for "a pinch of cumin" must not
  // decrement anything measurable.
  if (category === 'spice') return true;
  return STAPLE_PATTERNS.some((pattern) => patternMatchesName(name, pattern));
}
