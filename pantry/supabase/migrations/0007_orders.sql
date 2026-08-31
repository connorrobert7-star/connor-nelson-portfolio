-- 0007_orders.sql
-- A cart session. IMPORTANT: the Instacart API cannot place an order -- it
-- returns a hosted cart URL and checkout happens on Instacart Marketplace.
-- So a row here starting life as 'cart_created' means nothing has been bought.
-- Only the flip to 'confirmed_purchased' is allowed to write into pantry_items.

create table orders (
  id             uuid primary key default gen_random_uuid(),
  -- Nullable: a restock-only cart has no originating recipe.
  recipe_id      uuid references recipes (id) on delete set null,
  instacart_url  text not null,
  status         order_status not null default 'cart_created',
  -- Exactly what was sent to Instacart, verbatim, so a bad product match can be
  -- traced back to the request that caused it.
  items_json     jsonb not null default '[]'::jsonb,
  created_at     timestamptz not null default now(),
  confirmed_at   timestamptz,

  constraint orders_items_is_array check (jsonb_typeof(items_json) = 'array'),
  -- confirmed_at is set if and only if the order was actually purchased.
  constraint orders_confirmed_at_matches_status check (
    (status = 'confirmed_purchased') = (confirmed_at is not null)
  )
);

create index orders_status_idx on orders (status);
create index orders_created_at_idx on orders (created_at desc);
create index orders_recipe_id_idx on orders (recipe_id) where recipe_id is not null;
