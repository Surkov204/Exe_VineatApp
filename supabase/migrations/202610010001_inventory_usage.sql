-- Planning/shopping never writes inventory. Explicit usage is atomic and retry-safe.
begin;
create table if not exists public.inventory_usage_operations (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  actor_id uuid not null references auth.users(id),
  request jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.inventory_usage_operations enable row level security;
drop policy if exists usage_operations_read on public.inventory_usage_operations;
create policy usage_operations_read on public.inventory_usage_operations
  for select to authenticated using (public.is_household_member(household_id));
revoke all on public.inventory_usage_operations from anon, authenticated;
grant select on public.inventory_usage_operations to authenticated;

create or replace function public.confirm_inventory_usage(
  p_operation uuid, p_household uuid, p_items jsonb,
  p_dish_name text default null, p_people integer default 1
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_request jsonb; v_previous public.inventory_usage_operations%rowtype;
  v_line jsonb; v_item public.inventory_items%rowtype;
  v_quantity numeric; v_value integer; v_name text; v_cook uuid;
  v_actor text; v_inserted integer;
begin
  if auth.uid() is null or not public.is_household_member(p_household) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  if p_operation is null or p_people is null or p_people < 1 or p_people > 30
    or p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Invalid usage' using errcode = '22023';
  end if;
  if jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 100 then
    raise exception 'Invalid item count' using errcode = '22023';
  end if;
  v_name := nullif(btrim(p_dish_name), '');
  if length(v_name) > 100 then raise exception 'Dish name too long' using errcode = '22023'; end if;
  if exists(select 1 from jsonb_array_elements(p_items) x
    where jsonb_typeof(x->'quantity') is distinct from 'number' or nullif(x->>'inventory_item_id','') is null or nullif(x->>'unit','') is null) then
    raise exception 'Invalid quantity or item' using errcode = '22023';
  end if;
  if (select count(distinct x->>'inventory_item_id') from jsonb_array_elements(p_items) x) <> jsonb_array_length(p_items) then
    raise exception 'Duplicate inventory lot' using errcode = '22023';
  end if;
  v_request := jsonb_build_object('dish',v_name,'people',p_people,'items',
    (select jsonb_agg(x order by x->>'inventory_item_id') from jsonb_array_elements(p_items) x));
  insert into public.inventory_usage_operations(id,household_id,actor_id,request)
    values(p_operation,p_household,auth.uid(),v_request) on conflict(id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select * into v_previous from public.inventory_usage_operations where id=p_operation;
    if v_previous.household_id <> p_household or v_previous.actor_id <> auth.uid() or v_previous.request <> v_request then
      raise exception 'Operation does not match original request' using errcode = '22023';
    end if;
    return p_operation;
  end if;
  select nullif(btrim(display_name),'') into v_actor from public.profiles where id=auth.uid();
  -- Stable lock order prevents deadlocks between simultaneous family members.
  for v_line in select x from jsonb_array_elements(p_items) x order by x->>'inventory_item_id' loop
    v_quantity := (v_line->>'quantity')::numeric;
    if v_quantity < 0.001 or v_quantity > 1000000000 or v_quantity <> round(v_quantity,3) then
      raise exception 'Invalid consumed quantity' using errcode = '22023';
    end if;
    select * into v_item from public.inventory_items
      where id=(v_line->>'inventory_item_id')::uuid and household_id=p_household for update;
    if not found or v_item.quantity < v_quantity or v_item.consumed_at is not null or v_item.discarded_at is not null
      or (v_line->>'unit') is distinct from v_item.unit then
      raise exception 'Insufficient inventory quantity' using errcode = '22023';
    end if;
  end loop;
  if v_name is not null then
    insert into public.recipe_cook_events(household_id,recipe_name,servings,cooked_by)
      values(p_household,v_name,p_people,auth.uid()) returning id into v_cook;
  end if;
  for v_line in select x from jsonb_array_elements(p_items) x order by x->>'inventory_item_id' loop
    v_quantity := (v_line->>'quantity')::numeric;
    select * into v_item from public.inventory_items where id=(v_line->>'inventory_item_id')::uuid;
    v_value := round(v_item.price_vnd * v_quantity / v_item.quantity)::integer;
    update public.inventory_items set quantity=quantity-v_quantity,
      price_vnd=greatest(price_vnd-v_value,0),
      consumed_at=case when quantity-v_quantity=0 then now() else consumed_at end,
      updated_by=auth.uid()
      where id=v_item.id;
    insert into public.inventory_events(household_id,inventory_item_id,event_type,quantity,value_vnd,actor_id,metadata)
      values(p_household,v_item.id,'consumed',v_quantity,v_value,auth.uid(),jsonb_build_object(
        'name',v_item.name,'unit',v_item.unit,'actor_name',coalesce(v_actor,'Thành viên'),
        'usage_id',p_operation,'source',case when v_name is null then 'manual' else 'dish' end,
        'recipe_name',v_name,'remaining_quantity',v_item.quantity-v_quantity));
    if v_cook is not null then
      insert into public.recipe_cook_event_items(cook_event_id,inventory_item_id,item_name,quantity,unit,value_vnd)
        values(v_cook,v_item.id,v_item.name,v_quantity,v_item.unit,v_value);
    end if;
  end loop;
  return p_operation;
end $$;
revoke all on function public.confirm_inventory_usage(uuid,uuid,jsonb,text,integer) from public,anon;
grant execute on function public.confirm_inventory_usage(uuid,uuid,jsonb,text,integer) to authenticated;
commit;
