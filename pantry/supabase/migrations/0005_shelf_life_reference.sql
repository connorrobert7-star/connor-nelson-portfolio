-- 0005_shelf_life_reference.sql
-- Lookup table for expiry ESTIMATION. Nothing in here is ground truth; every
-- date derived from it must be presented in the UI as an estimate.
--
-- Matching order (implemented in application code):
--   1. item_name_pattern match against the normalized item name (longest wins)
--   2. category default
-- Item-specific patterns always beat category defaults.

create table shelf_life_reference (
  id                 uuid primary key default gen_random_uuid(),
  category           pantry_category not null,
  -- Null for a category-wide default row. Non-null rows are matched with ILIKE
  -- '%pattern%' against the normalized item name.
  item_name_pattern  text,
  days_refrigerated  integer check (days_refrigerated >= 0),
  days_pantry        integer check (days_pantry >= 0),
  days_frozen        integer check (days_frozen >= 0),
  confidence         confidence_level not null default 'medium',
  notes              text,
  -- Stable identity for the idempotent seed script. Rows added by hand leave
  -- this null and are never touched by re-seeding.
  seed_key           text unique,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint shelf_life_has_some_duration check (
    days_refrigerated is not null or days_pantry is not null or days_frozen is not null
  )
);

create index shelf_life_category_idx on shelf_life_reference (category);
create index shelf_life_pattern_idx on shelf_life_reference (item_name_pattern)
  where item_name_pattern is not null;

-- One category-default row per category, at most.
create unique index shelf_life_one_default_per_category_idx
  on shelf_life_reference (category)
  where item_name_pattern is null;

create trigger shelf_life_set_updated_at
  before update on shelf_life_reference
  for each row execute function set_updated_at();
