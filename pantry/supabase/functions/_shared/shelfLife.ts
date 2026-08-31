/**
 * Expiry ESTIMATION.
 *
 * Everything this module returns is a guess with a confidence attached, and the
 * UI is required to present it as such. It answers "roughly when should I worry
 * about this", never "when does this expire".
 *
 * Lookup precedence, matching the spec:
 *   1. item-specific pattern within the item's own category (longest wins)
 *   2. item-specific pattern in any category (longest wins)
 *   3. the category default
 */

import { DEFAULT_STORAGE_BY_CATEGORY, SHELF_LIFE_REFERENCE, type ShelfLifeEntry } from './data/shelfLife.ts';
import { normalizeItemName } from './units/itemNames.ts';
import { patternMatchesName } from './units/toCanonical.ts';
import { minConfidence, type Confidence, type PantryCategory } from './units/types.ts';

export type StorageLocation = 'refrigerated' | 'pantry' | 'frozen';

export function defaultStorageFor(category: PantryCategory): StorageLocation {
  return DEFAULT_STORAGE_BY_CATEGORY[category];
}

export function resolveShelfLife(
  rawName: string,
  category: PantryCategory,
  reference: ShelfLifeEntry[] = SHELF_LIFE_REFERENCE,
): ShelfLifeEntry | null {
  const name = normalizeItemName(rawName);

  const patterned = reference.filter(
    (entry) => entry.itemNamePattern !== null && patternMatchesName(name, entry.itemNamePattern),
  );

  const longest = (entries: ShelfLifeEntry[]): ShelfLifeEntry | null =>
    entries.length === 0
      ? null
      : entries.reduce((best, entry) =>
          (entry.itemNamePattern?.length ?? 0) > (best.itemNamePattern?.length ?? 0) ? entry : best,
        );

  return (
    longest(patterned.filter((entry) => entry.category === category)) ??
    longest(patterned) ??
    reference.find((entry) => entry.category === category && entry.itemNamePattern === null) ??
    null
  );
}

export interface ExpiryEstimate {
  /** ISO date (YYYY-MM-DD), or null when nothing sensible can be said. */
  estimatedExpiry: string | null;
  confidence: Confidence;
  storageLocation: StorageLocation;
  /** Human-readable account of how the date was reached. */
  explanation: string;
}

/**
 * Estimate when an item stops being good.
 *
 * If the assumed storage has no figure (raw chicken has no pantry shelf life),
 * fall back to whatever the entry does have and drop the confidence -- a rough
 * date is more useful than no date, as long as it is labelled rough.
 */
export function estimateExpiry(
  rawName: string,
  category: PantryCategory,
  acquiredAt: Date,
  options: { storage?: StorageLocation; reference?: ShelfLifeEntry[] } = {},
): ExpiryEstimate {
  const storage = options.storage ?? defaultStorageFor(category);
  const entry = resolveShelfLife(rawName, category, options.reference);

  if (!entry) {
    return {
      estimatedExpiry: null,
      confidence: 'low',
      storageLocation: storage,
      explanation: `No shelf-life reference matched "${rawName}" or the ${category} category.`,
    };
  }

  const byStorage: Record<StorageLocation, number | null> = {
    refrigerated: entry.daysRefrigerated,
    pantry: entry.daysPantry,
    frozen: entry.daysFrozen,
  };

  let days = byStorage[storage];
  let confidence = entry.confidence;
  let explanation =
    `${entry.itemNamePattern ?? `${category} (category default)`}: ` +
    `about ${days} days ${storage}.`;

  if (days === null) {
    const fallback = (['refrigerated', 'pantry', 'frozen'] as StorageLocation[])
      .filter((location) => location !== storage)
      .map((location) => ({ location, days: byStorage[location] }))
      .find((candidate) => candidate.days !== null);

    if (!fallback || fallback.days === null) {
      return {
        estimatedExpiry: null,
        confidence: 'low',
        storageLocation: storage,
        explanation: `No shelf-life figure for "${rawName}" in any storage location.`,
      };
    }

    days = fallback.days;
    confidence = 'low';
    explanation =
      `No figure for ${storage}; used the ${fallback.location} figure of ` +
      `about ${days} days instead. Treat this as a rough guess.`;
  }

  const expiry = new Date(acquiredAt.getTime());
  expiry.setUTCDate(expiry.getUTCDate() + days);

  return {
    estimatedExpiry: expiry.toISOString().slice(0, 10),
    // A date built on a category default is never better than low.
    confidence: entry.itemNamePattern === null ? minConfidence(confidence, 'low') : confidence,
    storageLocation: storage,
    explanation,
  };
}
