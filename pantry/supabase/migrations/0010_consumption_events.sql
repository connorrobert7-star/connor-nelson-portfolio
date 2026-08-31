-- 0010_consumption_events.sql
-- The audit trail for every quantity change.
--
-- Hard rule: never mutate pantry_items.canonical_quantity_remaining without
-- writing a row here. The point is to be able to reconstruct why the number is
-- what it is, months later, when it looks wrong.

create table consumption_events (
  id             uuid primary key default gen_random_uuid(),
  pantry_item_id uuid not null references pantry_items (id) on delete cascade,
  recipe_id      uuid references recipes (id) on delete set null,
  -- Negative for consumption, positive for an upward correction. Never zero:
  -- a no-op is not an event.
  canonical_amount numeric not null check (canonical_amount <> 0),
  reason           consumption_reason not null,
  -- Set when the requested depletion exceeded what was on hand and the value was
  -- clamped at zero. That means the pantry data has drifted, which is real
  -- information -- it is surfaced, not silently floored.
  shortfall_canonical numeric check (shortfall_canonical > 0),
  notes            text,
  created_at       timestamptz not null default now()
);

create index consumption_events_item_idx on consumption_events (pantry_item_id, created_at desc);
create index consumption_events_recipe_idx on consumption_events (recipe_id)
  where recipe_id is not null;
create index consumption_events_created_at_idx on consumption_events (created_at desc);
create index consumption_events_drift_idx on consumption_events (created_at desc)
  where shortfall_canonical is not null;
