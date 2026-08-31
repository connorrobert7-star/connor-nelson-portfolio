/**
 * Request field validation shared by the endpoints.
 *
 * Deliberately strict and specific: this app is edited by hand constantly
 * (manual pantry corrections are the thing that keeps the data honest), so a
 * validation message has to say what was wrong, not just that something was.
 */

import { badRequest } from './http.ts';
import { CANONICAL_UNITS, PANTRY_CATEGORIES, type CanonicalUnit, type PantryCategory } from './units/types.ts';
import type { PurchasedItem } from './pantryWrite.ts';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function requireUuid(body: Record<string, unknown>, field: string): string {
  const value = body[field];
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw badRequest(`"${field}" is required and must be a UUID.`);
  }
  return value;
}

export function optionalPositiveNumber(
  value: unknown,
  field: string,
  max = 1_000_000,
): number | undefined {
  if (value === undefined || value === null) return undefined;
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0 || numeric > max) {
    throw badRequest(`"${field}" must be a number between 0 and ${max}.`);
  }
  return numeric;
}

export function requireCategory(value: unknown, field: string): PantryCategory {
  if (typeof value !== 'string' || !(PANTRY_CATEGORIES as readonly string[]).includes(value)) {
    throw badRequest(`"${field}" must be one of: ${PANTRY_CATEGORIES.join(', ')}.`);
  }
  return value as PantryCategory;
}

export function requireCanonicalUnit(value: unknown, field: string): CanonicalUnit {
  if (typeof value !== 'string' || !(CANONICAL_UNITS as readonly string[]).includes(value)) {
    throw badRequest(`"${field}" must be one of: ${CANONICAL_UNITS.join(', ')}.`);
  }
  return value as CanonicalUnit;
}

const STORAGE_LOCATIONS = ['refrigerated', 'pantry', 'frozen'] as const;

export function parsePurchasedItems(value: unknown, field: string): PurchasedItem[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw badRequest(`"${field}" is required and must be a non-empty array.`);
  }
  if (value.length > 200) {
    throw badRequest(`"${field}" has ${value.length} entries; the limit is 200.`);
  }

  return value.map((entry, index) => {
    const where = `${field}[${index}]`;
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
      throw badRequest(`${where} must be an object.`);
    }
    const item = entry as Record<string, unknown>;

    const name = typeof item.name === 'string' ? item.name.trim() : '';
    if (name === '') throw badRequest(`${where}.name is required.`);

    if (item.quantity === undefined || item.quantity === null) {
      throw badRequest(`${where}.quantity is required.`);
    }
    if (typeof item.quantity !== 'number' && typeof item.quantity !== 'string') {
      throw badRequest(`${where}.quantity must be a number or a string like "1 1/2".`);
    }

    const parsed: PurchasedItem = {
      name,
      quantity: item.quantity,
      unit: typeof item.unit === 'string' ? item.unit : null,
    };

    if (item.category !== undefined && item.category !== null) {
      parsed.category = requireCategory(item.category, `${where}.category`);
    }
    if (item.is_staple !== undefined && item.is_staple !== null) {
      if (typeof item.is_staple !== 'boolean') {
        throw badRequest(`${where}.is_staple must be a boolean.`);
      }
      parsed.is_staple = item.is_staple;
    }
    if (item.storage_location !== undefined && item.storage_location !== null) {
      if (
        typeof item.storage_location !== 'string' ||
        !(STORAGE_LOCATIONS as readonly string[]).includes(item.storage_location)
      ) {
        throw badRequest(`${where}.storage_location must be one of: ${STORAGE_LOCATIONS.join(', ')}.`);
      }
      parsed.storage_location = item.storage_location as 'refrigerated' | 'pantry' | 'frozen';
    }
    if (typeof item.display_name === 'string' && item.display_name.trim() !== '') {
      parsed.display_name = item.display_name.trim();
    }
    if (typeof item.notes === 'string' && item.notes.trim() !== '') {
      parsed.notes = item.notes.trim();
    }

    return parsed;
  });
}
