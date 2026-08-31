/**
 * POST /pantry-edit
 *
 * Manual pantry corrections. "I will need to correct this constantly, and if
 * editing is painful the whole system rots."
 *
 * Body: { action: "add" | "update" | "delete", ... }
 *
 *   add:    { items: [{ name, quantity, unit, ... }] }
 *   update: { id, display_name?, category?, remaining_canonical?, purchase_quantity?,
 *             purchase_unit?, estimated_expiry?, is_staple?, storage_location?,
 *             low_stock_threshold_canonical?, notes?, discarded? }
 *   delete: { id }        -- for a row that should never have existed
 *
 * Any change to the remaining quantity goes through setRemaining(), which
 * writes a consumption_events row. Nothing here bypasses the audit trail.
 */

import { serviceClient, type PantryItemRow } from '../_shared/db.ts';
import { badRequest, notFound, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { setRemaining } from '../_shared/consumption.ts';
import { recomputeTypicalPurchase, writePurchasedItems } from '../_shared/orders.ts';
import {
  optionalPositiveNumber,
  parsePurchasedItems,
  requireCategory,
  requireUuid,
} from '../_shared/validation.ts';

const STORAGE_LOCATIONS = ['refrigerated', 'pantry', 'frozen'] as const;
const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

async function loadItem(client: ReturnType<typeof serviceClient>, id: string): Promise<PantryItemRow> {
  const { data, error } = await client.from('pantry_items').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(`Failed to load pantry item ${id}: ${error.message}`);
  if (!data) throw notFound(`No pantry item with id ${id}.`);
  return data as PantryItemRow;
}

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const action = typeof body.action === 'string' ? body.action : '';
  const client = serviceClient();

  if (action === 'add') {
    const items = parsePurchasedItems(body.items, 'items');
    const result = await writePurchasedItems(client, items, {
      source: 'manual_entry',
      orderId: null,
    });
    return ok({
      action,
      added: result.inserted,
      rejected: result.rejected,
      warnings: result.warnings,
    });
  }

  if (action === 'delete') {
    // A genuine mistake, not "I ate it" -- that is a consumption event.
    const id = requireUuid(body, 'id');
    await loadItem(client, id);
    const { error } = await client.from('pantry_items').delete().eq('id', id);
    if (error) throw new Error(`Failed to delete pantry item ${id}: ${error.message}`);
    return ok({ action, id, deleted: true });
  }

  if (action !== 'update') {
    throw badRequest('"action" must be one of: add, update, delete.');
  }

  const id = requireUuid(body, 'id');
  const item = await loadItem(client, id);

  // --- fields that do not touch the quantity ------------------------------
  const patch: Record<string, unknown> = {};

  if (typeof body.display_name === 'string' && body.display_name.trim() !== '') {
    patch.display_name = body.display_name.trim();
  }
  if (body.category !== undefined && body.category !== null) {
    patch.category = requireCategory(body.category, 'category');
  }
  if (body.is_staple !== undefined && body.is_staple !== null) {
    if (typeof body.is_staple !== 'boolean') throw badRequest('"is_staple" must be a boolean.');
    patch.is_staple = body.is_staple;
  }
  if (body.storage_location !== undefined && body.storage_location !== null) {
    if (
      typeof body.storage_location !== 'string' ||
      !(STORAGE_LOCATIONS as readonly string[]).includes(body.storage_location)
    ) {
      throw badRequest(`"storage_location" must be one of: ${STORAGE_LOCATIONS.join(', ')}.`);
    }
    patch.storage_location = body.storage_location;
  }
  if (body.estimated_expiry !== undefined) {
    if (body.estimated_expiry === null) {
      patch.estimated_expiry = null;
    } else if (typeof body.estimated_expiry === 'string' && ISO_DATE_RE.test(body.estimated_expiry)) {
      patch.estimated_expiry = body.estimated_expiry;
      // A date the user typed is not an estimate any more.
      patch.expiry_confidence = 'high';
    } else {
      throw badRequest('"estimated_expiry" must be a YYYY-MM-DD date or null.');
    }
  }
  if (body.low_stock_threshold_canonical !== undefined) {
    patch.low_stock_threshold_canonical =
      body.low_stock_threshold_canonical === null
        ? null
        : optionalPositiveNumber(body.low_stock_threshold_canonical, 'low_stock_threshold_canonical');
  }
  if (body.purchase_quantity !== undefined && body.purchase_quantity !== null) {
    patch.purchase_quantity = optionalPositiveNumber(body.purchase_quantity, 'purchase_quantity');
  }
  if (typeof body.purchase_unit === 'string') {
    patch.purchase_unit = body.purchase_unit.trim() || null;
  }
  if (body.notes !== undefined) {
    patch.notes = typeof body.notes === 'string' && body.notes.trim() !== '' ? body.notes.trim() : null;
  }

  if (body.discarded === true) {
    patch.discarded = true;
    patch.depleted_at = item.depleted_at ?? new Date().toISOString();
  }

  let updated = item;
  if (Object.keys(patch).length > 0) {
    const { data, error } = await client
      .from('pantry_items')
      .update(patch)
      .eq('id', id)
      .select()
      .single();
    if (error) throw new Error(`Failed to update pantry item ${id}: ${error.message}`);
    updated = data as PantryItemRow;
  }

  // --- the quantity, which always goes through the audit trail ------------
  let quantityChange: { delta: number; event_id: string | null } | null = null;

  if (body.remaining_canonical !== undefined && body.remaining_canonical !== null) {
    const observed = Number(body.remaining_canonical);
    if (!Number.isFinite(observed) || observed < 0) {
      throw badRequest('"remaining_canonical" must be a number of 0 or more.');
    }
    const result = await setRemaining(client, updated, observed, {
      reason: 'manual_adjustment',
      notes: typeof body.reason === 'string' ? body.reason.trim() : 'Manual pantry edit.',
    });
    updated = result.item;
    quantityChange = { delta: result.delta, event_id: result.eventId };

    if (result.item.canonical_quantity_original !== item.canonical_quantity_original) {
      await recomputeTypicalPurchase(client, [item.name]);
    }
  }

  return ok({ action, item: updated, quantity_change: quantityChange });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
