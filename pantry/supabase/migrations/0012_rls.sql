-- 0012_rls.sql
-- Row Level Security.
--
-- This is a single-user app, so these policies are not doing multi-tenant
-- isolation work. They exist so that the anon key -- which ships inside the Expo
-- bundle and must be assumed public -- cannot read or write anything. All access
-- goes through Edge Functions holding the service role key, or through an
-- authenticated session.
--
-- If this ever becomes multi-user, every table needs a user_id column and these
-- policies need a `using (user_id = auth.uid())` predicate. Adding that later is
-- a migration; forgetting RLS now is a data leak, hence enabling it up front.

do $$
declare
  t text;
begin
  foreach t in array array[
    'preferences',
    'recipes',
    'shelf_life_reference',
    'unit_conversions',
    'orders',
    'pantry_items',
    'restock_list',
    'consumption_events',
    'logs'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);

    -- Edge Functions run as service_role and do all the real work.
    execute format($p$
      create policy %I on %I
        for all
        to service_role
        using (true)
        with check (true)
    $p$, t || '_service_role_all', t);

    -- The single signed-in user, for direct client reads/writes.
    execute format($p$
      create policy %I on %I
        for all
        to authenticated
        using (true)
        with check (true)
    $p$, t || '_authenticated_all', t);
  end loop;
end;
$$;

-- Note: no policy is created for the `anon` role anywhere. With RLS enabled and
-- no matching policy, anon reads return zero rows and anon writes are rejected.
