-- 0009_restock_list.sql
-- A running list of things to buy, built up automatically between orders.

create table restock_list (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (name = lower(name) and length(trim(name)) > 0),
  display_name text not null,
  -- Null when the item was fully used up and its pantry lot is already depleted,
  -- or when it was added manually and was never in the pantry to begin with.
  pantry_item_id uuid references pantry_items (id) on delete set null,

  suggested_quantity_canonical numeric not null check (suggested_quantity_canonical > 0),
  suggested_canonical_unit     canonical_unit not null,

  reason               restock_reason not null,
  -- Set when a specific recipe is what made me short, so the digest can say
  -- "more jasmine rice -- you were short for the stir-fry".
  triggering_recipe_id uuid references recipes (id) on delete set null,
  -- Merged reasons when duplicate pending rows collapse into one (see the unique
  -- index below); kept so the digest can explain a line item with two causes.
  merged_reasons       restock_reason[] not null default '{}',

  status      restock_status not null default 'pending',
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,

  -- 'pending' means unresolved; anything else must record when it resolved.
  constraint restock_resolved_at_matches_status check (
    (status = 'pending') = (resolved_at is null)
  )
);

-- Deduplication is enforced here rather than left to application discipline: if
-- two different recipes both need more rice that is ONE line item, not two.
-- /low-stock-check running daily must therefore be idempotent by construction.
create unique index restock_one_pending_per_name_idx on restock_list (name)
  where status = 'pending';

create index restock_status_idx on restock_list (status, created_at desc);
create index restock_pending_idx on restock_list (created_at desc) where status = 'pending';
create index restock_triggering_recipe_idx on restock_list (triggering_recipe_id)
  where triggering_recipe_id is not null;
create index restock_pantry_item_idx on restock_list (pantry_item_id)
  where pantry_item_id is not null;
