alter table public.shopping_items add column if not exists menu_plan_id uuid references public.meal_plans(id) on delete set null;
alter table public.shopping_items add column if not exists needed_date date;
create or replace function public.confirm_menu_shopping(p_household uuid,p_week date,p_revision integer,p_items jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare plan public.meal_plans; item jsonb;
begin
  if auth.uid() is null or not public.is_household_member(p_household) then raise exception 'Membership required' using errcode='42501'; end if;
  select * into plan from public.meal_plans where household_id=p_household and week_start=p_week for update;
  if not found or plan.revision <> p_revision then raise exception 'Menu changed; reload' using errcode='40001'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)>100 then raise exception 'Invalid shopping list' using errcode='22023'; end if;
  -- Reconfirming replaces only this menu's unpurchased items, never manual items or purchase history.
  delete from public.shopping_items where household_id=p_household and menu_plan_id=plan.id and checked_at is null;
  for item in select value from jsonb_array_elements(p_items) loop
    if nullif(btrim(item->>'name'),'') is null or length(item->>'name')>200 or coalesce((item->>'quantity')::numeric,0)<=0
      or (item->>'needed_date')::date < p_week or (item->>'needed_date')::date >= p_week+7
      or length(item->>'note')>8000 then raise exception 'Invalid menu ingredient' using errcode='22023'; end if;
    insert into public.shopping_items(household_id,name,quantity,unit,note,priority,category,created_by,menu_plan_id,needed_date)
      values(p_household,item->>'name',(item->>'quantity')::numeric,item->>'unit',item->>'note',
        case when (item->>'needed_date')::date <= current_date+1 then 'urgent' else 'normal' end,
        'other',auth.uid(),plan.id,(item->>'needed_date')::date);
  end loop;
end;
$$;
revoke all on function public.confirm_menu_shopping(uuid,date,integer,jsonb) from public,anon;
grant execute on function public.confirm_menu_shopping(uuid,date,integer,jsonb) to authenticated;
