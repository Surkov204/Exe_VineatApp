begin;

-- History is append-only from clients. Trusted transactional RPCs below the
-- data boundary remain able to write while members can only read it.
drop policy if exists "inventory events member access" on public.inventory_events;
create policy "members read inventory events" on public.inventory_events
  for select using (public.is_household_member(household_id));

drop policy if exists "receipts member access" on public.receipts;
create policy "members read receipts" on public.receipts
  for select using (public.is_household_member(household_id));

drop policy if exists "receipt items member access" on public.receipt_items;
create policy "members read receipt items" on public.receipt_items
  for select using (exists (
    select 1 from public.receipts r
    where r.id = receipt_id and public.is_household_member(r.household_id)
  ));

drop policy if exists "members create recipe cook events" on public.recipe_cook_events;

create or replace function public.record_inventory_event(
  p_household_id uuid,
  p_inventory_item_id uuid,
  p_event_type text,
  p_quantity numeric,
  p_value_vnd integer,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_unit text;
  v_event_id uuid;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  if p_event_type is null
     or p_event_type not in ('added', 'updated', 'removed')
     or p_quantity is null or p_quantity < 0
     or p_value_vnd is null or p_value_vnd < 0 then
    raise exception 'Invalid inventory event' using errcode = '22023';
  end if;
  if p_inventory_item_id is not null then
    select name, unit into v_name, v_unit
      from public.inventory_items
      where id = p_inventory_item_id and household_id = p_household_id;
    if not found then
      raise exception 'Inventory item not found' using errcode = '42501';
    end if;
  end if;
  insert into public.inventory_events (
    household_id, inventory_item_id, event_type, quantity, value_vnd,
    actor_id, metadata
  ) values (
    p_household_id, p_inventory_item_id, p_event_type, p_quantity,
    p_value_vnd, auth.uid(), coalesce(p_metadata, '{}'::jsonb)
      || jsonb_strip_nulls(jsonb_build_object('name', v_name, 'unit', v_unit))
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;

revoke all on function public.record_inventory_event(uuid, uuid, text, numeric, integer, jsonb)
  from public, anon;
grant execute on function public.record_inventory_event(uuid, uuid, text, numeric, integer, jsonb)
  to authenticated;

-- A household-scoped row cannot be reassigned by a member of two households.
create or replace function public.prevent_household_scope_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.household_id is distinct from old.household_id then
    raise exception 'household_id is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger inventory_items_household_immutable
  before update of household_id on public.inventory_items
  for each row execute function public.prevent_household_scope_change();
create trigger shopping_items_household_immutable
  before update of household_id on public.shopping_items
  for each row execute function public.prevent_household_scope_change();
create trigger inventory_events_household_immutable
  before update of household_id on public.inventory_events
  for each row execute function public.prevent_household_scope_change();
create trigger receipts_household_immutable
  before update of household_id on public.receipts
  for each row execute function public.prevent_household_scope_change();

commit;
