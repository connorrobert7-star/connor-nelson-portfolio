/**
 * POST /order-abandon
 *
 * Body: { order_id }
 *
 * For when the cart link was opened and nothing was bought. Writes nothing to
 * the pantry, and puts any restock rows that were pulled into this cart back on
 * the pending list -- a dismissed cart must not silently wipe the restock list.
 */

import { serviceClient } from '../_shared/db.ts';
import { HttpError, ok, readJsonBody, serveHandler } from '../_shared/http.ts';
import { loadOrder, releaseRestockRows, transitionOrder } from '../_shared/orders.ts';
import { requireUuid } from '../_shared/validation.ts';

export const handler = serveHandler(async (request: Request): Promise<Response> => {
  const body = await readJsonBody(request);
  const orderId = requireUuid(body, 'order_id');

  const client = serviceClient();
  const order = await loadOrder(client, orderId);

  if (order.status === 'confirmed_purchased') {
    throw new HttpError(
      'conflict',
      'That order is already confirmed as purchased. Abandoning it would leave the pantry ' +
        'rows it created with nothing to explain them.',
    );
  }

  const moved = await transitionOrder(client, orderId, ['cart_created', 'abandoned'], 'abandoned');
  if (!moved) {
    throw new HttpError('conflict', 'That order changed state a moment ago; reload and try again.');
  }

  const restock = await releaseRestockRows(client, orderId);

  return ok({
    order_id: orderId,
    status: 'abandoned',
    restock_restored: restock.restored,
    restock_discarded_as_duplicate: restock.discardedAsDuplicate,
  });
});

const denoGlobal = (globalThis as { Deno?: { serve?: (h: (r: Request) => Promise<Response>) => unknown } }).Deno;
if (denoGlobal?.serve) denoGlobal.serve(handler);
