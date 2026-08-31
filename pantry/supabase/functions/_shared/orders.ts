/**
 * Order state transitions and the pantry writes they trigger.
 *
 * The Instacart API cannot place an order, so a cart_created row means nothing
 * has been bought. Only an explicit confirmation writes into the pantry, and it
 * must be safe to press "yes I bought it" twice.
 */

import type { SupabaseClient } from './db.ts';
import { HttpError, notFound } from './http.ts';
import { buildPantryRow, median, type PantryInsert, type PurchasedItem } from './pantryWrite.ts';

export interface OrderRow {
  id: string;
  recipe_id: string | null;
  instacart_url: string;
  status: 'cart_created' | 'confirmed_purchased' | 'abandoned';
  items_json: unknown;
  created_at: string;
  confirmed_at: string | null;
}

export async function loadOrder(client: SupabaseClient, orderId: string): Promise<OrderRow> {
  const { data, error } = await client.from('orders').select('*').eq('id', orderId).maybeSingle();
  if (error) throw new Error(`Failed to load order ${orderId}: ${error.message}`);
  if (!data) throw notFound(`No order with id ${orderId}.`);
  return data as OrderRow;
}

/**
 * Compare-and-set the order status.
 *
 * Returns false when the row was not in `from` -- which is how double
 * confirmation is caught. Doing this as a guarded UPDATE rather than a
 * read-then-write means two concurrent confirmations cannot both win and write
 * the pantry rows twice.
 */
export async function transitionOrder(
  client: SupabaseClient,
  orderId: string,
  from: OrderRow['status'][],
  to: OrderRow['status'],
): Promise<boolean> {
  const { data, error } = await client
    .from('orders')
    .update({
      status: to,
      confirmed_at: to === 'confirmed_purchased' ? new Date().toISOString() : null,
    })
    .eq('id', orderId)
    .in('status', from)
    .select('id');

  if (error) throw new Error(`Failed to move order ${orderId} to ${to}: ${error.message}`);
  return (data ?? []).length > 0;
}

export interface ConfirmResult {
  inserted: Array<{ id: string; name: string; display_name: string; canonical_quantity_original: number; canonical_unit: string; estimated_expiry: string | null; expiry_confidence: string; quantity_confidence: string }>;
  rejected: Array<{ item: PurchasedItem; reason: string }>;
  warnings: string[];
}

/**
 * Write the purchased items into the pantry.
 *
 * An item that cannot be converted to a usable quantity is REJECTED and
 * reported rather than silently dropped or inserted as zero: a lot with no
 * amount cannot be depleted or reconciled, so it would quietly corrupt the
 * pantry.
 */
export async function writePurchasedItems(
  client: SupabaseClient,
  items: PurchasedItem[],
  context: { source: PantryInsert['source']; orderId: string | null; acquiredAt?: Date },
): Promise<ConfirmResult> {
  const acquiredAt = context.acquiredAt ?? new Date();
  const rows: PantryInsert[] = [];
  const rejected: ConfirmResult['rejected'] = [];
  const warnings: string[] = [];

  for (const item of items) {
    try {
      const built = buildPantryRow(item, { acquiredAt, source: context.source, orderId: context.orderId });
      rows.push(built.row);
      warnings.push(...built.warnings);
    } catch (error) {
      rejected.push({ item, reason: error instanceof Error ? error.message : String(error) });
    }
  }

  if (rows.length === 0) {
    return { inserted: [], rejected, warnings };
  }

  const { data, error } = await client.from('pantry_items').insert(rows).select();
  if (error) throw new Error(`Failed to insert pantry items: ${error.message}`);

  await recomputeTypicalPurchase(client, [...new Set(rows.map((row) => row.name))]);

  return {
    inserted: (data ?? []) as ConfirmResult['inserted'],
    rejected,
    warnings,
  };
}

/**
 * Recompute typical_purchase_canonical (the median amount bought historically)
 * for the given item names.
 *
 * Deliberately does NOT touch low_stock_threshold_canonical: that is set once
 * at insert and is user-overridable, and silently rewriting an override every
 * time you shop would be maddening.
 */
export async function recomputeTypicalPurchase(
  client: SupabaseClient,
  names: string[],
): Promise<void> {
  for (const name of names) {
    const { data, error } = await client
      .from('pantry_items')
      .select('canonical_quantity_original')
      .eq('name', name);

    if (error) {
      console.error(`Could not recompute typical purchase for "${name}": ${error.message}`);
      continue;
    }

    const typical = median((data ?? []).map((row) => Number(row.canonical_quantity_original)));
    if (typical === null) continue;

    const { error: updateError } = await client
      .from('pantry_items')
      .update({ typical_purchase_canonical: typical })
      .eq('name', name);

    if (updateError) {
      console.error(`Could not store typical purchase for "${name}": ${updateError.message}`);
    }
  }
}

/**
 * Put restock rows back to pending when their cart is abandoned.
 *
 * A dismissed cart must not silently wipe the restock list. If an identical
 * pending row has appeared in the meantime the unique index rejects the update,
 * and the right answer is to drop this row -- the need is already represented.
 */
export async function releaseRestockRows(
  client: SupabaseClient,
  orderId: string,
): Promise<{ restored: number; discardedAsDuplicate: number }> {
  const { data, error } = await client
    .from('restock_list')
    .select('id, name')
    .eq('order_id', orderId)
    .eq('status', 'added_to_cart');

  if (error) throw new Error(`Failed to load restock rows for order ${orderId}: ${error.message}`);

  let restored = 0;
  let discardedAsDuplicate = 0;

  for (const row of data ?? []) {
    const { error: updateError } = await client
      .from('restock_list')
      .update({ status: 'pending', resolved_at: null, order_id: null })
      .eq('id', row.id);

    if (!updateError) {
      restored += 1;
      continue;
    }

    // 23505 is unique_violation: a pending row for this name already exists.
    if ((updateError as { code?: string }).code === '23505') {
      const { error: deleteError } = await client.from('restock_list').delete().eq('id', row.id);
      if (deleteError) {
        console.error(`Could not drop duplicate restock row ${row.id}: ${deleteError.message}`);
      } else {
        discardedAsDuplicate += 1;
      }
      continue;
    }

    throw new HttpError(
      'internal_error',
      `Failed to restore restock row ${row.id}: ${updateError.message}`,
    );
  }

  return { restored, discardedAsDuplicate };
}
