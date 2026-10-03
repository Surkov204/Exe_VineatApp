-- Existing event types use "updated" for deletions; retain explicit action.
create or replace function public.remove_inventory_item(p_item_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare item public.inventory_items;
begin
  select * into item from public.inventory_items where id=p_item_id for update;
  if not found then return; end if;
  if auth.uid() is null or not public.is_household_member(item.household_id) then
    raise exception 'Household membership required' using errcode='42501';
  end if;
  perform public.record_inventory_event(item.household_id,item.id,'updated',item.quantity,item.price_vnd,
    jsonb_build_object('name',item.name,'unit',item.unit,'action','removed'));
  delete from public.inventory_items where id=item.id;
end;
$$;
