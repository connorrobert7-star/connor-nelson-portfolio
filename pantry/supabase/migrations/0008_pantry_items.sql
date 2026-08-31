-- 0008_pantry_items.sql
-- What is actually at home right now.
--
-- A row is a LOT, not an item type: buying cilantro twice makes two rows, which
-- is what lets Phase 5 deplete the one expiring soonest first (FEFO). `name` is
-- therefore deliberately not unique.
--
-- Two invariants this table exists to protect:
--   * Buying is not consuming. A row is inserted at full quantity when an order
--     is CONFIRMED, and canonical_quantity_remaining only ever goes down via a
--     consumption_events row.
--   * All arithmetic runs on canonical_quantity_*, never on purchase_quantity.
--     purchase_quantity / purchase_unit are kept verbatim for display only.

create table pantry_items (
  id           uuid primary key default gen_random_uuid(),
  -- Normalized, lowercase, singular. This is the join key used to match recipe
  -- ingredients to pantry lots. Produced by src/units/itemNames.ts.
  name         text not null check (name = lower(name) and length(trim(name)) > 0),
  display_name text not null,
  category     pantry_category not null,

  -- What was actually bought, verbatim, for display: "1 bunch", "1 lb".
  purchase_quantity numeric check (purchase_quantity > 0),
  purchase_unit     text,

  -- The numbers everything else runs on.
  canonical_quantity_original  numeric not null check (canonical_quantity_original > 0),
  canonical_quantity_remaining numeric not null check (canonical_quantity_remaining >= 0),
  canonical_unit               canonical_unit not null,
  quantity_confidence          confidence_level not null default 'medium',

  acquired_at       timestamptz not null default now(),
  storage_location  storage_location not null default 'pantry',
  estimated_expiry  date,
  expiry_confidence confidence_level not null default 'medium',

  source   pantry_source not null,
  -- Traceability from a confirmed order back to the rows it created.
  order_id uuid references orders (id) on delete set null,

  -- Staples (salt, flour, oil, spices) are exempt from BOTH expiry nagging and
  -- quantity depletion. A recipe calling for "a pinch of salt" must not
  -- decrement anything.
  is_staple boolean not null default false,

  depleted_at timestamptz,
  -- True when it was thrown out rather than eaten. Drives the waste log.
  discarded   boolean not null default false,

  -- Below this remaining amount, tell me I am running low. Defaulted by category
  -- on insert (see src/units/thresholds.ts), overridable per item.
  low_stock_threshold_canonical numeric check (low_stock_threshold_canonical >= 0),
  -- Median canonical amount across past purchases of this item; used to suggest
  -- a sensible restock quantity. Recomputed on each confirmed order.
  typical_purchase_canonical    numeric check (typical_purchase_canonical > 0),

  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint pantry_items_remaining_within_original
    check (canonical_quantity_remaining <= canonical_quantity_original),
  -- Something can only be discarded if it is also marked gone.
  constraint pantry_items_discarded_implies_depleted
    check (not discarded or depleted_at is not null)
);

-- The hot path: "what do I currently have?" Almost every query filters on
-- depleted_at is null, so the useful indexes are partial.
create index pantry_items_active_name_idx on pantry_items (name)
  where depleted_at is null;
create index pantry_items_active_expiry_idx on pantry_items (estimated_expiry)
  where depleted_at is null and estimated_expiry is not null;
create index pantry_items_active_category_idx on pantry_items (category)
  where depleted_at is null;
-- Drives /low-stock-check.
create index pantry_items_low_stock_idx on pantry_items (name)
  where depleted_at is null and is_staple = false and low_stock_threshold_canonical is not null;
-- Drives the Waste screen.
create index pantry_items_discarded_idx on pantry_items (depleted_at desc)
  where discarded = true;
create index pantry_items_order_id_idx on pantry_items (order_id)
  where order_id is not null;

create trigger pantry_items_set_updated_at
  before update on pantry_items
  for each row execute function set_updated_at();
