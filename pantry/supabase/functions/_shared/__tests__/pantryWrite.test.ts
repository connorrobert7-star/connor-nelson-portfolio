import { describe, expect, it } from 'vitest';
import { inferCategory, inferIsStaple } from '../categorize.ts';
import { UnusableQuantityError, buildPantryRow, median } from '../pantryWrite.ts';
import { estimateExpiry, resolveShelfLife } from '../shelfLife.ts';

const ACQUIRED = new Date('2026-09-01T12:00:00Z');
const ctx = { acquiredAt: ACQUIRED, source: 'instacart_order' as const, orderId: 'order-1' };

describe('inferCategory', () => {
  it('reuses the conversion dataset so purchases need no manual filing', () => {
    expect(inferCategory('cilantro')).toBe('produce');
    expect(inferCategory('boneless skinless chicken breasts')).toBe('meat');
    expect(inferCategory('canned black beans')).toBe('canned');
    expect(inferCategory('extra virgin olive oil')).toBe('condiment');
    expect(inferCategory('all purpose flour')).toBe('pantry_dry');
  });

  it('returns null rather than guessing when nothing matches', () => {
    expect(inferCategory('dragonfruit')).toBeNull();
    expect(inferCategory('')).toBeNull();
  });
});

describe('inferIsStaple', () => {
  it('treats spices and the short staple list as staples', () => {
    expect(inferIsStaple('salt', 'spice')).toBe(true);
    expect(inferIsStaple('cumin', 'spice')).toBe(true);
    expect(inferIsStaple('olive oil', 'condiment')).toBe(true);
  });

  it('does not treat trackable bulk goods as staples', () => {
    // Being wrong in the generous direction means an item silently never
    // depletes, which corrupts the pantry quietly.
    expect(inferIsStaple('rice', 'pantry_dry')).toBe(false);
    expect(inferIsStaple('flour', 'pantry_dry')).toBe(false);
    expect(inferIsStaple('chicken breast', 'meat')).toBe(false);
  });
});

describe('resolveShelfLife precedence', () => {
  it('prefers an item pattern over the category default', () => {
    expect(resolveShelfLife('spinach', 'produce')?.itemNamePattern).toBe('spinach');
  });

  it('prefers the longest matching pattern', () => {
    expect(resolveShelfLife('ground beef', 'meat')?.itemNamePattern).toBe('ground beef');
    expect(resolveShelfLife('beef', 'meat')?.itemNamePattern).toBe('beef');
  });

  it('falls back to the category default', () => {
    expect(resolveShelfLife('dragonfruit', 'produce')?.itemNamePattern).toBeNull();
  });
});

describe('estimateExpiry', () => {
  it('dates perishables from the refrigerated figure', () => {
    const result = estimateExpiry('spinach', 'produce', ACQUIRED);
    expect(result.storageLocation).toBe('refrigerated');
    expect(result.estimatedExpiry).toBe('2026-09-06'); // 5 days
  });

  it('dates dry goods from the pantry figure', () => {
    const result = estimateExpiry('rice', 'pantry_dry', ACQUIRED);
    expect(result.storageLocation).toBe('pantry');
    expect(result.estimatedExpiry).toBe('2028-08-31'); // 730 days
  });

  it('distinguishes ground meat from whole cuts', () => {
    expect(estimateExpiry('ground beef', 'meat', ACQUIRED).estimatedExpiry).toBe('2026-09-03');
    expect(estimateExpiry('beef', 'meat', ACQUIRED).estimatedExpiry).toBe('2026-09-05');
  });

  it('falls back to another storage figure at low confidence', () => {
    // Raw chicken has no pantry shelf life; a rough date beats no date, as long
    // as it is labelled rough.
    const result = estimateExpiry('chicken', 'meat', ACQUIRED, { storage: 'pantry' });
    expect(result.estimatedExpiry).not.toBeNull();
    expect(result.confidence).toBe('low');
    expect(result.explanation).toMatch(/rough guess/i);
  });

  it('never claims better than low confidence from a category default', () => {
    expect(estimateExpiry('dragonfruit', 'produce', ACQUIRED).confidence).toBe('low');
  });
});

describe('buildPantryRow', () => {
  it('sets original and remaining equal at insert -- buying is not consuming', () => {
    const { row } = buildPantryRow({ name: 'cilantro', quantity: 1, unit: 'bunch' }, ctx);
    expect(row.canonical_quantity_original).toBeCloseTo(45, 1);
    expect(row.canonical_quantity_remaining).toBe(row.canonical_quantity_original);
  });

  it('keeps the purchase unit verbatim for display and converts separately', () => {
    const { row } = buildPantryRow({ name: 'chicken breast', quantity: 1, unit: 'lb' }, ctx);
    expect(row.purchase_quantity).toBe(1);
    expect(row.purchase_unit).toBe('lb');
    expect(row.canonical_quantity_original).toBeCloseTo(453.59, 1);
    expect(row.canonical_unit).toBe('g');
  });

  it('normalizes the name to the pantry join key', () => {
    const { row } = buildPantryRow({ name: 'Organic Boneless Chicken Breasts', quantity: 2, unit: '' }, ctx);
    expect(row.name).toBe('chicken breast');
    expect(row.display_name).toBe('Organic Boneless Chicken Breasts');
  });

  it('infers category, staple status and storage', () => {
    const { row } = buildPantryRow({ name: 'whole milk', quantity: 1, unit: 'carton' }, ctx);
    expect(row.category).toBe('dairy');
    expect(row.storage_location).toBe('refrigerated');
    expect(row.is_staple).toBe(false);
  });

  it('exempts staples from expiry tracking', () => {
    const { row, derivation } = buildPantryRow({ name: 'salt', quantity: 1, unit: 'container' }, ctx);
    expect(row.is_staple).toBe(true);
    expect(row.estimated_expiry).toBeNull();
    expect(derivation.expiry).toMatch(/exempt/i);
  });

  it('sets a low-stock threshold from the category fraction', () => {
    const { row } = buildPantryRow({ name: 'rice', quantity: 1000, unit: 'g' }, ctx);
    expect(row.low_stock_threshold_canonical).toBeCloseTo(200, 1); // pantry_dry: 20%
  });

  it('leaves spices with no low-stock threshold', () => {
    const { row } = buildPantryRow({ name: 'cumin', quantity: 1, unit: 'jar' }, ctx);
    expect(row.low_stock_threshold_canonical).toBeNull();
  });

  it('accepts explicit overrides over inference', () => {
    const { row, derivation } = buildPantryRow(
      { name: 'dragonfruit', quantity: 2, unit: '', category: 'produce', is_staple: false, storage_location: 'frozen' },
      ctx,
    );
    expect(row.category).toBe('produce');
    expect(row.storage_location).toBe('frozen');
    expect(derivation.categorySource).toBe('given');
  });

  it('warns loudly when it has to file something as "other"', () => {
    const { row, warnings } = buildPantryRow({ name: 'dragonfruit', quantity: 2, unit: '' }, ctx);
    expect(row.category).toBe('other');
    expect(warnings.join(' ')).toMatch(/could not work out a category/i);
  });

  it('rejects an item whose quantity cannot be made usable', () => {
    // A lot with no amount can never be depleted or reconciled, so it must not
    // reach the database at all.
    expect(() => buildPantryRow({ name: '', quantity: 1, unit: 'bunch' }, ctx)).toThrow(
      UnusableQuantityError,
    );
  });

  it('records the acquisition time it was given', () => {
    const { row } = buildPantryRow({ name: 'rice', quantity: 1, unit: 'bag' }, ctx);
    expect(row.acquired_at).toBe(ACQUIRED.toISOString());
    expect(row.order_id).toBe('order-1');
    expect(row.source).toBe('instacart_order');
  });
});

describe('median for typical_purchase_canonical', () => {
  it('is robust to one odd bulk buy', () => {
    expect(median([400, 450, 500, 5000])).toBeCloseTo(475, 1);
  });

  it('handles odd and single-element sets', () => {
    expect(median([400, 500, 900])).toBe(500);
    expect(median([907])).toBe(907);
  });

  it('ignores junk and returns null when nothing is usable', () => {
    expect(median([])).toBeNull();
    expect(median([0, -5, Number.NaN])).toBeNull();
  });
});
