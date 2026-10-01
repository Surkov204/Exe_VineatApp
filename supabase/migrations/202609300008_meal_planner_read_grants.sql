-- Client reads remain filtered by the existing household membership RLS.
grant select on public.meal_plans, public.meal_plan_entries to authenticated;
