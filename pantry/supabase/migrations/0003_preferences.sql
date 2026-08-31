-- 0003_preferences.sql
-- Standing food preferences. Single-row table by construction: the primary key
-- is pinned to 1 by a check constraint so there can never be a second row to
-- disagree with the first.

create table preferences (
  id                integer primary key default 1 check (id = 1),
  dislikes          text[] not null default '{}',
  dietary_notes     text not null default '',
  default_servings  integer not null default 2 check (default_servings > 0),
  default_store_zip text,
  spice_tolerance   text not null default 'medium',
  updated_at        timestamptz not null default now()
);

create trigger preferences_set_updated_at
  before update on preferences
  for each row execute function set_updated_at();
