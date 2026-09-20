-- ViNeat demo schema. Apply with Supabase CLI before enabling remote sync.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Bạn',
  role_label text not null default 'Thành viên',
  diet text not null default 'normal',
  avatar_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Gia đình của tôi',
  invite_code text not null unique,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role text not null default 'member'
    check (member_role in ('owner', 'adult', 'member')),
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (household_id, user_id)
);

create table if not exists public.food_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon_name text,
  sort_order integer not null default 0
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id uuid references public.food_categories(id) on delete set null,
  name text not null,
  quantity numeric(12, 3) not null default 1 check (quantity >= 0),
  unit text not null default 'phần',
  price_vnd integer not null default 0 check (price_vnd >= 0),
  purchase_date date,
  expiry_date date,
  storage_location text not null default 'fridge',
  note text,
  image_path text,
  source text not null default 'manual'
    check (source in ('manual', 'receipt', 'template', 'import')),
  created_by uuid references public.profiles(id) on delete set null,
  consumed_at timestamptz,
  discarded_at timestamptz,
  discard_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.inventory_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  inventory_item_id uuid references public.inventory_items(id) on delete set null,
  event_type text not null
    check (event_type in ('added', 'updated', 'consumed', 'discarded', 'restored')),
  quantity numeric(12, 3) not null default 0,
  value_vnd integer not null default 0 check (value_vnd >= 0),
  metadata jsonb not null default '{}'::jsonb,
  actor_id uuid references public.profiles(id) on delete set null,
  occurred_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  store_name text,
  purchased_at timestamptz,
  total_vnd integer not null default 0 check (total_vnd >= 0),
  image_path text,
  raw_ocr_text text,
  processing_status text not null default 'review'
    check (processing_status in ('uploaded', 'processing', 'review', 'imported', 'failed')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.receipt_items (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.receipts(id) on delete cascade,
  raw_name text not null,
  normalized_name text,
  quantity numeric(12, 3) not null default 1,
  unit text not null default 'phần',
  unit_price_vnd integer not null default 0,
  total_price_vnd integer not null default 0,
  estimated_expiry_date date,
  confidence numeric(4, 3) check (confidence between 0 and 1),
  inventory_item_id uuid references public.inventory_items(id) on delete set null,
  selected_for_import boolean not null default true
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  image_path text,
  meal_type text not null default 'dinner',
  difficulty text not null default 'easy',
  minutes integer not null default 15 check (minutes > 0),
  servings integer not null default 2 check (servings > 0),
  calories integer,
  protein_g numeric(8, 2),
  carbs_g numeric(8, 2),
  fat_g numeric(8, 2),
  source text not null default 'seed',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  name text not null,
  amount text not null,
  optional boolean not null default false,
  sort_order integer not null default 0
);

create table if not exists public.recipe_steps (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  step_number integer not null,
  instruction text not null,
  minutes integer,
  tip text,
  unique (recipe_id, step_number)
);

create table if not exists public.recipe_favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, recipe_id)
);

create table if not exists public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  week_start date not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (household_id, week_start)
);

create table if not exists public.meal_plan_entries (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null references public.meal_plans(id) on delete cascade,
  recipe_id uuid references public.recipes(id) on delete set null,
  planned_date date not null,
  meal_slot text not null default 'dinner',
  servings integer not null default 2 check (servings > 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  quantity numeric(12, 3) not null default 1,
  unit text not null default 'phần',
  category text not null default 'other',
  priority text not null default 'normal'
    check (priority in ('urgent', 'normal', 'optional')),
  note text,
  checked_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  expiry_warning boolean not null default true,
  weekly_cleanup boolean not null default true,
  achievements boolean not null default true,
  family_activity boolean not null default true,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists inventory_items_household_expiry_idx
  on public.inventory_items (household_id, expiry_date);
create index if not exists inventory_events_household_date_idx
  on public.inventory_events (household_id, occurred_at desc);
create index if not exists receipts_household_date_idx
  on public.receipts (household_id, purchased_at desc);
create index if not exists shopping_items_household_checked_idx
  on public.shopping_items (household_id, checked_at);
create index if not exists activity_logs_household_created_idx
  on public.activity_logs (household_id, created_at desc);

create or replace function public.is_household_member(target_household uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.household_members
    where household_id = target_household and user_id = auth.uid()
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', 'Bạn'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members', 'food_categories',
    'inventory_items', 'inventory_events', 'receipts', 'receipt_items',
    'recipes', 'recipe_ingredients', 'recipe_steps', 'recipe_favorites',
    'meal_plans', 'meal_plan_entries', 'shopping_items',
    'notification_preferences', 'activity_logs'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end;
$$;

create policy "profiles are self readable" on public.profiles
  for select using (id = auth.uid());
create policy "profiles are self writable" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy "households are member readable" on public.households
  for select using (public.is_household_member(id));
create policy "users create their households" on public.households
  for insert with check (created_by = auth.uid());
create policy "owners update households" on public.households
  for update using (created_by = auth.uid()) with check (created_by = auth.uid());

create policy "members are readable" on public.household_members
  for select using (public.is_household_member(household_id));
create policy "members can join" on public.household_members
  for insert with check (
    user_id = auth.uid()
    or public.is_household_member(household_id)
  );
create policy "owners manage members" on public.household_members
  for delete using (public.is_household_member(household_id));

create policy "categories are public readable" on public.food_categories
  for select using (true);

create policy "inventory member access" on public.inventory_items
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "inventory events member access" on public.inventory_events
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "receipts member access" on public.receipts
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "receipt items member access" on public.receipt_items
  for all using (exists (
    select 1 from public.receipts r
    where r.id = receipt_id and public.is_household_member(r.household_id)
  ))
  with check (exists (
    select 1 from public.receipts r
    where r.id = receipt_id and public.is_household_member(r.household_id)
  ));

create policy "recipes are public readable" on public.recipes
  for select using (true);
create policy "recipe ingredients are public readable" on public.recipe_ingredients
  for select using (true);
create policy "recipe steps are public readable" on public.recipe_steps
  for select using (true);
create policy "favorites are self manageable" on public.recipe_favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "meal plans member access" on public.meal_plans
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "meal entries member access" on public.meal_plan_entries
  for all using (exists (
    select 1 from public.meal_plans p
    where p.id = meal_plan_id and public.is_household_member(p.household_id)
  ))
  with check (exists (
    select 1 from public.meal_plans p
    where p.id = meal_plan_id and public.is_household_member(p.household_id)
  ));
create policy "shopping member access" on public.shopping_items
  for all using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "notification preferences are self manageable"
  on public.notification_preferences
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "activity is member readable" on public.activity_logs
  for select using (public.is_household_member(household_id));
create policy "activity is member insertable" on public.activity_logs
  for insert with check (public.is_household_member(household_id));

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute procedure public.set_updated_at();
drop trigger if exists households_set_updated_at on public.households;
create trigger households_set_updated_at before update on public.households
  for each row execute procedure public.set_updated_at();
drop trigger if exists inventory_items_set_updated_at on public.inventory_items;
create trigger inventory_items_set_updated_at before update on public.inventory_items
  for each row execute procedure public.set_updated_at();
drop trigger if exists receipts_set_updated_at on public.receipts;
create trigger receipts_set_updated_at before update on public.receipts
  for each row execute procedure public.set_updated_at();
drop trigger if exists recipes_set_updated_at on public.recipes;
create trigger recipes_set_updated_at before update on public.recipes
  for each row execute procedure public.set_updated_at();
drop trigger if exists shopping_items_set_updated_at on public.shopping_items;
create trigger shopping_items_set_updated_at before update on public.shopping_items
  for each row execute procedure public.set_updated_at();
