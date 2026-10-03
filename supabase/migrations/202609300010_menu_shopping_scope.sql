begin;
alter table public.shopping_items add column if not exists menu_day date;
drop function public.confirm_menu_shopping(uuid,date,integer,jsonb);
create function public.confirm_menu_shopping(p_household uuid,p_week date,p_revision integer,p_items jsonb,p_day date default null)
returns void language plpgsql security definer set search_path='' as $$
declare plan public.meal_plans; item jsonb; item_day date;
begin
  if auth.uid() is null or not public.is_household_member(p_household) then raise exception 'Membership required' using errcode='42501'; end if;
  select * into plan from public.meal_plans where household_id=p_household and week_start=p_week for update;
  if not found or plan.revision is distinct from p_revision then raise exception 'Menu changed; reload' using errcode='40001'; end if;
  if p_day is not null and (p_day < p_week or p_day >= p_week+7) then raise exception 'Invalid menu day' using errcode='22023'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)>300 then raise exception 'Invalid shopping list' using errcode='22023'; end if;
  delete from public.shopping_items where household_id=p_household and menu_plan_id=plan.id and checked_at is null
    and (p_day is null or menu_day=p_day);
  for item in select value from jsonb_array_elements(p_items) loop
    item_day := coalesce((item->>'menu_day')::date,(item->>'needed_date')::date);
    if item_day is null or item_day < p_week or item_day >= p_week+7 or (p_day is not null and item_day <> p_day)
      or nullif(btrim(item->>'name'),'') is null or length(item->>'name')>200
      or coalesce((item->>'quantity')::numeric,0)<=0 or length(item->>'note')>8000 then raise exception 'Invalid menu ingredient' using errcode='22023'; end if;
    insert into public.shopping_items(household_id,name,quantity,unit,note,priority,category,created_by,menu_plan_id,needed_date,menu_day)
      values(p_household,item->>'name',(item->>'quantity')::numeric,item->>'unit',item->>'note',
        case when item_day <= current_date+1 then 'urgent' else 'normal' end,
        'other',auth.uid(),plan.id,item_day,item_day);
  end loop;
end;
$$;
revoke all on function public.confirm_menu_shopping(uuid,date,integer,jsonb,date) from public,anon;
grant execute on function public.confirm_menu_shopping(uuid,date,integer,jsonb,date) to authenticated;
commit;
