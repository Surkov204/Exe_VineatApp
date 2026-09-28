begin;

-- Household changes must include household_id in update/delete payloads so
-- clients can safely filter their realtime subscription to the active home.
alter table public.inventory_items replica identity full;
alter table public.shopping_items replica identity full;
alter table public.inventory_events replica identity full;
alter table public.recipe_cook_events replica identity full;

do $$
declare
  table_name text;
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise exception 'The supabase_realtime publication is required for household sync.';
  end if;

  foreach table_name in array array[
    'inventory_items',
    'shopping_items',
    'inventory_events',
    'recipe_cook_events'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end;
$$;

commit;
