begin;

-- Household managers can see names and roles, but not email addresses or
-- private profile preferences. Mutations remain transactional and role-checked.
create or replace function public.list_household_members(p_household_id uuid)
returns table(user_id uuid, display_name text, member_role text)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  return query
    select m.user_id, coalesce(p.display_name, 'Thành viên'), m.member_role
    from public.household_members m
    left join public.profiles p on p.id = m.user_id
    where m.household_id = p_household_id
    order by (m.member_role = 'owner') desc, m.joined_at;
end;
$$;

create or replace function public.set_household_member_role(
  p_household_id uuid, p_user_id uuid, p_member_role text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only a household owner may change member roles'
      using errcode = '42501';
  end if;
  if p_member_role not in ('adult', 'member') then
    raise exception 'Unsupported household member role' using errcode = '22023';
  end if;
  update public.household_members
    set member_role = p_member_role
    where household_id = p_household_id
      and user_id = p_user_id and member_role <> 'owner';
  return found;
end;
$$;

revoke all on function public.list_household_members(uuid) from public, anon;
revoke all on function public.set_household_member_role(uuid, uuid, text) from public, anon;
grant execute on function public.list_household_members(uuid) to authenticated;
grant execute on function public.set_household_member_role(uuid, uuid, text) to authenticated;

-- The import is an explicit, one-time choice per household. One member's
-- confirmation applies to the entire family and cannot create duplicate stock.
alter table public.demo_imports
  drop constraint if exists demo_imports_user_id_household_id_import_key_key;
create unique index if not exists demo_imports_household_import_key_unique
  on public.demo_imports (household_id, import_key);
drop policy if exists "members read household imports" on public.demo_imports;
drop policy if exists "users confirm their own imports" on public.demo_imports;
create policy "members read household imports" on public.demo_imports
  for select using (public.is_household_member(household_id));

create or replace function public.import_demo_inventory(
  p_household_id uuid,
  p_import_key text,
  p_items jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line jsonb;
  v_name text;
  v_quantity numeric(12, 3);
  v_unit text;
  v_price integer;
  v_expiry date;
  v_image_index integer;
  v_item_id uuid;
  v_count integer := 0;
  v_claimed integer := 0;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  if auth.uid() is null or nullif(btrim(p_import_key), '') is null
     or p_import_key <> 'local-demo-v1'
     or jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items) > 100 then
    raise exception 'Invalid demo import payload' using errcode = '22023';
  end if;

  insert into public.demo_imports (user_id, household_id, import_key)
    values (auth.uid(), p_household_id, btrim(p_import_key))
    on conflict (household_id, import_key) do nothing;
  get diagnostics v_claimed = row_count;
  if v_claimed = 0 then return 0; end if;

  for v_line in select value from jsonb_array_elements(p_items) loop
    v_name := nullif(btrim(v_line->>'name'), '');
    v_quantity := coalesce((v_line->>'quantity')::numeric, 1);
    v_unit := coalesce(nullif(btrim(v_line->>'unit'), ''), 'phần');
    v_price := greatest(coalesce((v_line->>'price_vnd')::integer, 0), 0);
    v_expiry := nullif(v_line->>'expiry_date', '')::date;
    v_image_index := greatest(coalesce((v_line->>'image_index')::integer, 0), 0);
    if v_name is null or length(v_name) > 120 or v_quantity <= 0
       or length(v_unit) > 32 then
      raise exception 'Invalid demo inventory item' using errcode = '22023';
    end if;
    insert into public.inventory_items (
      household_id, name, quantity, unit, price_vnd, expiry_date,
      image_index, source, created_by
    ) values (
      p_household_id, v_name, v_quantity, v_unit, v_price, v_expiry,
      v_image_index, 'template', auth.uid()
    ) returning id into v_item_id;
    insert into public.inventory_events (
      household_id, inventory_item_id, event_type, quantity, value_vnd,
      actor_id, metadata
    ) values (
      p_household_id, v_item_id, 'added', v_quantity, v_price, auth.uid(),
      jsonb_build_object('name', v_name, 'unit', v_unit, 'source', 'one_time_demo_import')
    );
    v_count := v_count + 1;
  end loop;

  update public.demo_imports
    set imported_items = v_count
    where household_id = p_household_id and import_key = btrim(p_import_key);
  return v_count;
end;
$$;

revoke all on function public.import_demo_inventory(uuid, text, jsonb) from public, anon;
grant execute on function public.import_demo_inventory(uuid, text, jsonb) to authenticated;

commit;
