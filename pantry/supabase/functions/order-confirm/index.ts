/**
 * POST /order-confirm
 *
 * Body: { order_id, purchased_items: [{ name, quantity, unit, ... }] }
 *
 * This is the ONLY path that writes bought goods into the pantry. The Instacart
 * API cannot place an order, so nothing before this point means anything was
 * actually purchased -- the cart link may have been opened and abandoned.
 *
 * Safe to call twice: the status change is a guarded compare-and-set, so a
 * second confirmation is rejected rather than duplicating every pantry row.
 */

import { serviceClient } from '../_shared/db.ts';
import { HttpError, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { writeLog } from '../_shared/logging.ts';
import { loadOrder, transitionOrder, writePurchasedItems } from '../_shared/orders.ts';
import { parsePurchasedItems, requireUuid } from '../_shared/validation.ts';

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const orderId = requireUuid(body, 'order_id');
  const items = parsePurchasedItems(body.purchased_items, 'purchased_items');

  const client = serviceClient();
  const order = await loadOrder(client, orderId);

  if (order.status === 'confirmed_purchased') {
    throw new HttpError(
      'conflict',
      'That order is already confirmed. Confirming it again would add everything to the pantry twice. ' +
        'Use the manual pantry endpoint if something is missing.',
    );
  }

  // Claim the order first. If two confirmations race, only one gets past this.
  const claimed = await transitionOrder(
    client,
    orderId,
    ['cart_created', 'abandoned'],
    'confirmed_purchased',
  );
  if (!claimed) {
    throw new HttpError('conflict', 'That order was confirmed by something else a moment ago.');
  }

  let result;
  try {
    result = await writePurchasedItems(client, items, {
      source: 'instacart_order',
      orderId,
    });
  } catch (error) {
    // Compensate: leave the order unconfirmed so this can be retried cleanly
    // rather than stranding a confirmed order with no pantry rows behind it.
    await transitionOrder(client, orderId, ['confirmed_purchased'], order.status);
    await writeLog(client, {
      source: 'edge-function',
      event: 'order.confirm.failed',
      orderId,
      requestBody: { purchased_items: items },
      errorMessage: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }

  if (result.rejected.length > 0) {
    await writeLog(client, {
      source: 'edge-function',
      level: 'warn',
      event: 'order.confirm.rejected_items',
      orderId,
      responseBody: { rejected: result.rejected },
    });
  }

  return ok({
    order_id: orderId,
    status: 'confirmed_purchased',
    added_to_pantry: result.inserted,
    // Never silently dropped: an item with no usable quantity would be a lot
    // that can never be depleted or reconciled.
    rejected: result.rejected,
    warnings: result.warnings,
  });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
