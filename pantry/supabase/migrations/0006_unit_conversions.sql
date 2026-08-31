-- 0006_unit_conversions.sql
-- The translation layer between how food is bought and how it is cooked.
-- This is the backbone of the whole project: nothing may do arithmetic on a
-- quantity until it has passed through here into g / ml / count.
--
-- Resolution order (implemented in src/units/toCanonical.ts):
--   1. item_name_pattern rule for this exact from_unit  (longest pattern wins)
--   2. density-derived conversion for this item          (volume <-> weight)
--   3. universal dimensional rule                        (item_name_pattern and
--                                                         category both null)
--   4. category fallback rule                            -> confidence forced low
-- An item-specific rule always beats a category rule, which always beats nothing.

create table unit_conversions (
  id                  uuid primary key default gen_random_uuid(),
  -- Matched with ILIKE '%pattern%' against the normalized item name. Null means
  -- this is a category fallback or (with category also null) a universal rule.
  item_name_pattern   text,
  category            pantry_category,
  -- Free-form source unit, already normalized to a canonical alias by
  -- src/units/unitAliases.ts before lookup: 'bunch', 'clove', 'breast', 'can',
  -- 'head', 'stalk', 'tbsp', 'cup', 'lb', 'oz', ...
  from_unit           text not null,
  to_canonical_unit   canonical_unit not null,
  multiplier          numeric not null check (multiplier > 0),
  confidence          confidence_level not null default 'medium',
  notes               text,
  seed_key            text unique,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Lookup paths.
create index unit_conversions_item_idx on unit_conversions (item_name_pattern, from_unit)
  where item_name_pattern is not null;
create index unit_conversions_category_idx on unit_conversions (category, from_unit)
  where item_name_pattern is null and category is not null;
create index unit_conversions_universal_idx on unit_conversions (from_unit)
  where item_name_pattern is null and category is null;

-- A given (scope, from_unit) may only resolve one way, or resolution becomes
-- order-dependent and therefore untestable. These three partial unique indexes
-- cover the three mutually exclusive scopes.
create unique index unit_conversions_item_unique_idx
  on unit_conversions (item_name_pattern, from_unit)
  where item_name_pattern is not null;
create unique index unit_conversions_category_unique_idx
  on unit_conversions (category, from_unit)
  where item_name_pattern is null and category is not null;
create unique index unit_conversions_universal_unique_idx
  on unit_conversions (from_unit)
  where item_name_pattern is null and category is null;

create trigger unit_conversions_set_updated_at
  before update on unit_conversions
  for each row execute function set_updated_at();
