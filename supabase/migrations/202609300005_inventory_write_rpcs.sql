-- Keep direct table writes blocked. Validate membership and write atomically.
create or replace function public.save_inventory_item(p_item jsonb, p_event_type text default 'updated')
returns uuid language plpgsql security definer set search_path = '' as $$
declare item_id uuid := (p_item->>'id')::uuid;
household uuid := (p_item->>'household_id')::uuid;
existing public.inventory_items; saved public.inventory_items;
begin
  if auth.uid() is null or not public.is_household_member(household) then
    raise exception 'Household membership required' using errcode='42501';
  end if;
  if p_event_type not in ('added','updated') or nullif(btrim(p_item->>'name'),'') is null
    or length(p_item->>'name') > 200 or (p_item->>'quantity')::numeric <= 0
    or (p_item->>'price_vnd')::integer < 0 then
    raise exception 'Invalid inventory values' using errcode='22023';
  end if;
  select * into existing from public.inventory_items where id=item_id for update;
  if found then
    if existing.household_id <> household then
      raise exception 'Inventory belongs to another household' using errcode='42501';
    end if;
    if p_event_type='added' then return item_id; end if;
    update public.inventory_items set name=p_item->>'name', quantity=(p_item->>'quantity')::numeric,
      unit=p_item->>'unit', price_vnd=(p_item->>'price_vnd')::integer,
      expiry_date=(p_item->>'expiry_date')::date, image_index=(p_item->>'image_index')::integer,
      image_path=p_item->>'image_path', note=p_item->>'note'
      where id=item_id returning * into saved;
  else
    if p_event_type <> 'added' then raise exception 'Inventory not found' using errcode='22023'; end if;
    insert into public.inventory_items(id,household_id,name,quantity,unit,price_vnd,purchase_date,
      expiry_date,image_index,image_path,note,source,created_by)
    values(item_id,household,p_item->>'name',(p_item->>'quantity')::numeric,p_item->>'unit',
      (p_item->>'price_vnd')::integer,(p_item->>'purchase_date')::date,(p_item->>'expiry_date')::date,
      (p_item->>'image_index')::integer,p_item->>'image_path',p_item->>'note','manual',auth.uid())
    returning * into saved;
  end if;
  perform public.record_inventory_event(household,item_id,p_event_type,saved.quantity,saved.price_vnd,
    jsonb_build_object('name',saved.name,'unit',saved.unit));
  return item_id;
end;
$$;
revoke all on function public.save_inventory_item(jsonb,text) from public,anon;
grant execute on function public.save_inventory_item(jsonb,text) to authenticated;

create or replace function public.remove_inventory_item(p_item_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare item public.inventory_items;
begin
  select * into item from public.inventory_items where id=p_item_id for update;
  if not found then return; end if;
  if auth.uid() is null or not public.is_household_member(item.household_id) then
    raise exception 'Household membership required' using errcode='42501';
  end if;
  perform public.record_inventory_event(item.household_id,item.id,'removed',item.quantity,item.price_vnd,
    jsonb_build_object('name',item.name,'unit',item.unit));
  delete from public.inventory_items where id=item.id;
end;
$$;
revoke all on function public.remove_inventory_item(uuid) from public,anon;
grant execute on function public.remove_inventory_item(uuid) to authenticated;
