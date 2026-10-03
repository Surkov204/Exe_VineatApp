begin;

-- RLS filters rows; SQL grants separately decide which operations a client
-- role may attempt. Rebuild the public API surface from least privilege.
revoke all on table
  public.profiles,
  public.households,
  public.household_members,
  public.food_categories,
  public.inventory_items,
  public.inventory_events,
  public.receipts,
  public.receipt_items,
  public.recipes,
  public.recipe_ingredients,
  public.recipe_steps,
  public.recipe_favorites,
  public.meal_plans,
  public.meal_plan_entries,
  public.shopping_items,
  public.notification_preferences,
  public.activity_logs,
  public.tutorial_progress,
  public.demo_imports,
  public.recipe_cook_events,
  public.recipe_cook_event_items
from public, anon, authenticated;

-- The app reads its own profile, family membership and inventory snapshots.
grant select on table public.profiles to authenticated;
grant select on table public.households to authenticated;
grant select on table public.household_members to authenticated;

-- Catalogs are safe for signed-out browsing; household records are not.
grant select on table
  public.food_categories,
  public.recipes,
  public.recipe_ingredients,
  public.recipe_steps
to anon, authenticated;

-- Inventory and shopping are edited directly with household-scoped RLS.
grant select, insert, update, delete
  on table public.inventory_items, public.shopping_items
  to authenticated;

-- Report, receipt, cooking and import history is read-only to clients; all
-- writes go through authenticated transactional functions.
grant select on table
  public.inventory_events,
  public.receipts,
  public.receipt_items,
  public.demo_imports,
  public.recipe_cook_events,
  public.recipe_cook_event_items
to authenticated;

-- Tutorial progress is user-owned and saved with an upsert.
grant select, insert, update on table public.tutorial_progress to authenticated;

-- No current app flow exposes favorites, meal plans, notification settings or
-- the generic activity log. They remain unavailable until a reviewed feature
-- migration grants the exact operations it needs.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.prevent_household_scope_change()
  from public, anon, authenticated;

-- Private family uploads use the household UUID as the first object folder.
-- A member can upload/read/overwrite files only inside a family they belong to.
drop policy if exists "household members read food photos" on storage.objects;
create policy "household members read food photos" on storage.objects
  for select to authenticated using (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "household members add food photos" on storage.objects;
create policy "household members add food photos" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "household members update food photos" on storage.objects;
create policy "household members update food photos" on storage.objects
  for update to authenticated using (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  ) with check (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

-- There is no delete-photo action in the UI; don't expose one to client roles.
drop policy if exists "household members delete food photos" on storage.objects;
revoke all on table storage.objects from public, anon, authenticated;
grant select, insert, update on table storage.objects to authenticated;

-- The bucket is private and bounds upload cost while accepting picker formats.
update storage.buckets
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'household-food';

commit;
