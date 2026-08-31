/**
 * Building a pantry_items row from something that was bought.
 *
 * Pure: takes a purchased item, returns the row to insert plus an account of
 * how every derived field was reached. No database, so it can be tested against
 * the awkward cases directly.
 *
 * The invariant this enforces: canonical_quantity_original and
 * canonical_quantity_remaining are both populated by toCanonical() and are
 * EQUAL at insert time. Buying is not consuming.
 */

import { inferCategory, inferIsStaple } from './categorize.ts';
import { estimateExpiry, defaultStorageFor, type StorageLocation } from './shelfLife.ts';
import { normalizeItemName } from './units/itemNames.ts';
import { defaultLowStockThreshold } from './units/thresholds.ts';
import { toCanonical } from './units/toCanonical.ts';
import type { CanonicalUnit, Confidence, PantryCategory } from './units/types.ts';

export interface PurchasedItem {
  name: string;
  quantity: number | string;
  unit: string | null;
  /** Optional overrides, when the client knows better than the inference. */
  category?: PantryCategory;
  is_staple?: boolean;
  storage_location?: StorageLocation;
  display_name?: string;
  notes?: string;
}

export interface PantryInsert {
  name: string;
  display_name: string;
  category: PantryCategory;
  purchase_quantity: number;
  purchase_unit: string | null;
  canonical_quantity_original: number;
  canonical_quantity_remaining: number;
  canonical_unit: CanonicalUnit;
  quantity_confidence: Confidence;
  acquired_at: string;
  storage_location: StorageLocation;
  estimated_expiry: string | null;
  expiry_confidence: Confidence;
  source: 'instacart_order' | 'manual_entry' | 'receipt_scan';
  order_id: string | null;
  is_staple: boolean;
  low_stock_threshold_canonical: number | null;
  notes: string | null;
}

export interface BuildPantryRowResult {
  row: PantryInsert;
  warnings: string[];
  /** How each derived field was arrived at. Useful in the response and in logs. */
  derivation: {
    conversion: string;
    expiry: string;
    categorySource: 'given' | 'inferred' | 'default';
  };
}

export class UnusableQuantityError extends Error {
  override readonly name = 'UnusableQuantityError';
}

export function buildPantryRow(
  item: PurchasedItem,
  context: {
    acquiredAt: Date;
    source: PantryInsert['source'];
    orderId?: string | null;
  },
): BuildPantryRowResult {
  const warnings: string[] = [];

  const normalized = normalizeItemName(item.name);
  if (normalized === '') {
    throw new UnusableQuantityError(
      `"${item.name}" does not normalize to a usable item name.`,
    );
  }

  let categorySource: 'given' | 'inferred' | 'default' = 'given';
  let category = item.category;
  if (!category) {
    const inferred = inferCategory(item.name);
    if (inferred) {
      category = inferred;
      categorySource = 'inferred';
    } else {
      category = 'other';
      categorySource = 'default';
      warnings.push(
        `Could not work out a category for "${item.name}"; filed as "other". ` +
          'Expiry and low-stock estimates for it will be poor until you correct it.',
      );
    }
  }

  const converted = toCanonical(item.name, item.quantity, item.unit, { category });
  warnings.push(...converted.warnings);

  if (!(converted.canonicalQuantity > 0)) {
    // The DB rejects a non-positive original quantity, and rightly so: a lot
    // with no amount cannot be depleted, reconciled, or reported on.
    throw new UnusableQuantityError(
      `"${item.quantity} ${item.unit ?? ''} ${item.name}" converted to ` +
        `${converted.canonicalQuantity} ${converted.canonicalUnit}, which is not a usable amount.`,
    );
  }

  const isStaple = item.is_staple ?? inferIsStaple(item.name, category);
  const storage = item.storage_location ?? defaultStorageFor(category);

  const expiry = estimateExpiry(item.name, category, context.acquiredAt, { storage });

  // Staples are exempt from expiry nagging, so an estimate for them is noise.
  const estimatedExpiry = isStaple ? null : expiry.estimatedExpiry;

  const purchaseQuantity = Number(item.quantity);

  return {
    row: {
      name: normalized,
      display_name: item.display_name?.trim() || item.name.trim(),
      category,
      purchase_quantity: Number.isFinite(purchaseQuantity) && purchaseQuantity > 0 ? purchaseQuantity : converted.parsedQuantity,
      purchase_unit: item.unit?.trim() || null,
      canonical_quantity_original: converted.canonicalQuantity,
      // Equal at insert. Buying is not consuming.
      canonical_quantity_remaining: converted.canonicalQuantity,
      canonical_unit: converted.canonicalUnit,
      quantity_confidence: converted.confidence,
      acquired_at: context.acquiredAt.toISOString(),
      storage_location: storage,
      estimated_expiry: estimatedExpiry,
      expiry_confidence: expiry.confidence,
      source: context.source,
      order_id: context.orderId ?? null,
      is_staple: isStaple,
      low_stock_threshold_canonical: defaultLowStockThreshold(category, converted.canonicalQuantity),
      notes: item.notes?.trim() || null,
    },
    warnings,
    derivation: {
      conversion: converted.explanation,
      expiry: isStaple ? 'Staple: exempt from expiry tracking.' : expiry.explanation,
      categorySource,
    },
  };
}

/** Median, for typical_purchase_canonical. Robust to one odd bulk buy. */
export function median(values: number[]): number | null {
  const sorted = values.filter((value) => Number.isFinite(value) && value > 0).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const middle = Math.floor(sorted.length / 2);
  const value =
    sorted.length % 2 === 1
      ? (sorted[middle] as number)
      : ((sorted[middle - 1] as number) + (sorted[middle] as number)) / 2;
  return Number(value.toFixed(4));
}
