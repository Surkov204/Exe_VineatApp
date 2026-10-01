alter table public.meal_plans add column if not exists revision integer not null default 0;
alter table public.meal_plan_entries add column if not exists dish_name text;
alter table public.meal_plan_entries add column if not exists recipe_key text;
alter table public.meal_plan_entries add column if not exists ingredients jsonb not null default '[]';

create or replace function public.save_week_menu(p_household uuid, p_week date, p_revision integer, p_items jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare plan public.meal_plans; entry jsonb;
begin
  if auth.uid() is null or not public.is_household_member(p_household) then
    raise exception 'Household membership required' using errcode='42501';
  end if;
  if extract(isodow from p_week) <> 1 or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 100 then
    raise exception 'Invalid weekly menu' using errcode='22023';
  end if;
  insert into public.meal_plans(household_id,week_start,created_by)
    values(p_household,p_week,auth.uid()) on conflict(household_id,week_start) do nothing;
  select * into plan from public.meal_plans where household_id=p_household and week_start=p_week for update;
  if plan.revision <> p_revision then
    raise exception 'Menu changed; reload before saving' using errcode='40001';
  end if;
  delete from public.meal_plan_entries where meal_plan_id=plan.id;
  for entry in select value from jsonb_array_elements(p_items) loop
    if nullif(btrim(entry->>'name'),'') is null or length(entry->>'name') > 200
      or (entry->>'date')::date < p_week or (entry->>'date')::date >= p_week+7
      or entry->>'slot' not in ('breakfast','lunch','dinner')
      or jsonb_typeof(entry->'ingredients') <> 'array' then
      raise exception 'Invalid meal entry' using errcode='22023';
    end if;
    insert into public.meal_plan_entries(meal_plan_id,planned_date,meal_slot,dish_name,recipe_key,ingredients)
      values(plan.id,(entry->>'date')::date,entry->>'slot',entry->>'name',entry->>'recipe_key',entry->'ingredients');
  end loop;
  update public.meal_plans set revision=revision+1 where id=plan.id;
  return plan.revision+1;
end;
$$;
revoke all on function public.save_week_menu(uuid,date,integer,jsonb) from public,anon;
grant execute on function public.save_week_menu(uuid,date,integer,jsonb) to authenticated;
