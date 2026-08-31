-- 0002_shared_functions.sql
-- Shared trigger helpers used by several tables.

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
