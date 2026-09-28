begin;

-- Harden the helper created in the first schema migration. The fixed search
-- path and restricted grants prevent objects from being shadowed by callers.
create or replace function public.is_household_member(target_household uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = target_household and m.user_id = auth.uid()
  );
$$;
revoke all on function public.is_household_member(uuid) from public, anon;
grant execute on function public.is_household_member(uuid) to authenticated;

create table if not exists public.tutorial_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  page_key text not null check (page_key in ('home', 'scan', 'recipes', 'shopping', 'reports')),
  completed_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, page_key)
);
alter table public.tutorial_progress enable row level security;
create policy "tutorial progress is self manageable" on public.tutorial_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.demo_imports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  import_key text not null,
  imported_at timestamptz not null default timezone('utc', now()),
  imported_items integer not null default 0 check (imported_items >= 0),
  unique (user_id, household_id, import_key)
);
alter table public.demo_imports enable row level security;
create policy "members read household imports" on public.demo_imports
  for select using (
    user_id = auth.uid() and public.is_household_member(household_id)
  );
create policy "users confirm their own imports" on public.demo_imports
  for insert with check (
    user_id = auth.uid() and public.is_household_member(household_id)
  );

alter table public.shopping_items
  add column if not exists inventory_item_id uuid
  references public.inventory_items(id) on delete set null;
create unique index if not exists shopping_inventory_link_unique_idx
  on public.shopping_items (inventory_item_id)
  where inventory_item_id is not null;
alter table public.inventory_items
  add column if not exists image_index integer not null default 0;

create table if not exists public.recipe_cook_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipe_id uuid references public.recipes(id) on delete set null,
  recipe_name text not null,
  servings integer not null default 1 check (servings > 0),
  cooked_by uuid references public.profiles(id) on delete set null,
  cooked_at timestamptz not null default timezone('utc', now())
);
create table if not exists public.recipe_cook_event_items (
  cook_event_id uuid not null references public.recipe_cook_events(id) on delete cascade,
  inventory_item_id uuid references public.inventory_items(id) on delete set null,
  item_name text not null,
  quantity numeric(12, 3) not null check (quantity > 0),
  unit text not null,
  value_vnd integer not null default 0 check (value_vnd >= 0),
  primary key (cook_event_id, item_name)
);
alter table public.recipe_cook_events enable row level security;
alter table public.recipe_cook_event_items enable row level security;
create policy "members read recipe cook events" on public.recipe_cook_events
  for select using (public.is_household_member(household_id));
create policy "members create recipe cook events" on public.recipe_cook_events
  for insert with check (
    public.is_household_member(household_id)
    and (cooked_by is null or cooked_by = auth.uid())
  );
create policy "members read recipe cook event items" on public.recipe_cook_event_items
  for select using (exists (
    select 1 from public.recipe_cook_events e
    where e.id = cook_event_id and public.is_household_member(e.household_id)
  ));

-- Buying a shopping row is idempotent: repeating the request returns the
-- already-linked inventory item instead of creating duplicate stock.
create or replace function public.complete_shopping_item(p_shopping_item_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.shopping_items%rowtype;
  v_inventory_id uuid;
begin
  select * into v_item from public.shopping_items
    where id = p_shopping_item_id for update;
  if not found or not public.is_household_member(v_item.household_id) then
    raise exception 'Shopping item not found' using errcode = '42501';
  end if;
  if v_item.inventory_item_id is not null then
    update public.shopping_items
      set checked_at = coalesce(checked_at, timezone('utc', now()))
      where id = v_item.id;
    return v_item.inventory_item_id;
  end if;
  insert into public.inventory_items (
    household_id, name, quantity, unit, category_id, price_vnd,
    purchase_date, source, created_by
  ) values (
    v_item.household_id, v_item.name, greatest(v_item.quantity, 0), v_item.unit,
    null, 0, current_date, 'manual', auth.uid()
  ) returning id into v_inventory_id;
  update public.shopping_items
    set checked_at = timezone('utc', now()), inventory_item_id = v_inventory_id
    where id = v_item.id;
  insert into public.inventory_events (
    household_id, inventory_item_id, event_type, quantity, actor_id,
    metadata
  ) values (
    v_item.household_id, v_inventory_id, 'added', v_item.quantity,
    auth.uid(), jsonb_build_object('source', 'shopping', 'shopping_item_id', v_item.id)
  );
  return v_inventory_id;
end;
$$;

create or replace function public.consume_inventory_item(
  p_inventory_item_id uuid,
  p_quantity numeric,
  p_discarded boolean default false
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.inventory_items%rowtype;
  v_value integer;
  v_type text := case when p_discarded then 'discarded' else 'consumed' end;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be positive' using errcode = '22023';
  end if;
  select * into v_item from public.inventory_items
    where id = p_inventory_item_id for update;
  if not found or not public.is_household_member(v_item.household_id) then
    raise exception 'Inventory item not found' using errcode = '42501';
  end if;
  if v_item.quantity < p_quantity then
    raise exception 'Insufficient inventory quantity' using errcode = '22023';
  end if;
  v_value := case when v_item.quantity > 0
    then round(v_item.price_vnd * p_quantity / v_item.quantity)::integer
    else 0 end;
  update public.inventory_items
    set quantity = quantity - p_quantity,
        price_vnd = greatest(price_vnd - v_value, 0),
        consumed_at = case when not p_discarded and quantity - p_quantity = 0
          then timezone('utc', now()) else consumed_at end,
        discarded_at = case when p_discarded and quantity - p_quantity = 0
          then timezone('utc', now()) else discarded_at end,
        discard_reason = case when p_discarded then 'discarded in app' else discard_reason end
    where id = v_item.id;
  insert into public.inventory_events (
    household_id, inventory_item_id, event_type, quantity, value_vnd,
    actor_id, metadata
  ) values (
    v_item.household_id, v_item.id, v_type, p_quantity, v_value,
    auth.uid(), jsonb_build_object('name', v_item.name, 'unit', v_item.unit)
  );
  return v_item.quantity - p_quantity;
end;
$$;

-- Cooking logs actual consumed quantities and atomically decrements stock.
-- p_items is [{"inventory_item_id":"uuid","quantity":1.0}].
create or replace function public.record_recipe_cooked(
  p_household_id uuid,
  p_recipe_name text,
  p_servings integer,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_line jsonb;
  v_item public.inventory_items%rowtype;
  v_quantity numeric(12, 3);
  v_value integer;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  if nullif(btrim(p_recipe_name), '') is null or p_servings < 1
     or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Invalid cooking event' using errcode = '22023';
  end if;
  insert into public.recipe_cook_events (
    household_id, recipe_name, servings, cooked_by
  ) values (p_household_id, btrim(p_recipe_name), p_servings, auth.uid())
  returning id into v_event_id;

  for v_line in select value from jsonb_array_elements(p_items) loop
    if coalesce(v_line->>'inventory_item_id', '') = '' then continue; end if;
    v_quantity := (v_line->>'quantity')::numeric;
    if v_quantity <= 0 then
      raise exception 'Consumed quantity must be positive' using errcode = '22023';
    end if;
    select * into v_item from public.inventory_items
      where id = (v_line->>'inventory_item_id')::uuid
        and household_id = p_household_id
      for update;
    if not found or v_item.quantity < v_quantity then
      raise exception 'Insufficient inventory quantity' using errcode = '22023';
    end if;
    v_value := case when v_item.quantity > 0
      then round(v_item.price_vnd * v_quantity / v_item.quantity)::integer
      else 0 end;
    update public.inventory_items
      set quantity = quantity - v_quantity,
          price_vnd = greatest(price_vnd - v_value, 0),
          consumed_at = case when quantity - v_quantity = 0
            then timezone('utc', now()) else consumed_at end
      where id = v_item.id;
    insert into public.recipe_cook_event_items (
      cook_event_id, inventory_item_id, item_name, quantity, unit, value_vnd
    ) values (
      v_event_id, v_item.id, v_item.name, v_quantity, v_item.unit, v_value
    );
    insert into public.inventory_events (
      household_id, inventory_item_id, event_type, quantity, value_vnd,
      actor_id, metadata
    ) values (
      p_household_id, v_item.id, 'consumed', v_quantity, v_value,
      auth.uid(), jsonb_build_object('recipe_name', btrim(p_recipe_name), 'cook_event_id', v_event_id)
    );
  end loop;
  return v_event_id;
end;
$$;

create or replace function public.import_receipt(
  p_household_id uuid,
  p_store_name text,
  p_purchased_at timestamptz,
  p_total_vnd integer,
  p_image_path text,
  p_raw_ocr_text text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_receipt_id uuid;
  v_line jsonb;
  v_receipt_item_id uuid;
  v_inventory_item_id uuid;
  v_name text;
  v_quantity numeric(12, 3);
  v_unit text;
  v_unit_price integer;
  v_total integer;
  v_confidence numeric(4, 3);
  v_expiry date;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'Household membership required' using errcode = '42501';
  end if;
  if p_total_vnd < 0 or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) > 200 then
    raise exception 'Invalid receipt payload' using errcode = '22023';
  end if;
  insert into public.receipts (
    household_id, store_name, purchased_at, total_vnd, image_path,
    raw_ocr_text, processing_status, created_by
  ) values (
    p_household_id, nullif(btrim(p_store_name), ''), p_purchased_at,
    p_total_vnd, p_image_path, p_raw_ocr_text, 'imported', auth.uid()
  ) returning id into v_receipt_id;

  for v_line in select value from jsonb_array_elements(p_items) loop
    v_name := nullif(btrim(v_line->>'normalized_name'), '');
    if v_name is null or length(v_name) > 120 then
      raise exception 'Receipt item name is required' using errcode = '22023';
    end if;
    v_quantity := coalesce((v_line->>'quantity')::numeric, 1);
    v_unit := coalesce(nullif(btrim(v_line->>'unit'), ''), 'phần');
    v_unit_price := greatest(coalesce((v_line->>'unit_price_vnd')::integer, 0), 0);
    v_total := greatest(coalesce((v_line->>'total_price_vnd')::integer, 0), 0);
    v_confidence := greatest(0, least(1, coalesce((v_line->>'confidence')::numeric, .5)))::numeric(4,3);
    v_expiry := nullif(v_line->>'estimated_expiry_date', '')::date;
    if v_quantity <= 0 then
      raise exception 'Receipt item quantity must be positive' using errcode = '22023';
    end if;
    insert into public.receipt_items (
      receipt_id, raw_name, normalized_name, quantity, unit,
      unit_price_vnd, total_price_vnd, estimated_expiry_date,
      confidence, selected_for_import
    ) values (
      v_receipt_id, coalesce(nullif(v_line->>'raw_name', ''), v_name),
      v_name, v_quantity, v_unit, v_unit_price, v_total, v_expiry,
      v_confidence, coalesce((v_line->>'selected_for_import')::boolean, true)
    ) returning id into v_receipt_item_id;

    if coalesce((v_line->>'selected_for_import')::boolean, true) then
      insert into public.inventory_items (
        household_id, name, quantity, unit, price_vnd, purchase_date,
        expiry_date, source, created_by
      ) values (
        p_household_id, v_name, v_quantity, v_unit, v_total,
        coalesce(p_purchased_at::date, current_date), v_expiry, 'receipt', auth.uid()
      ) returning id into v_inventory_item_id;
      update public.receipt_items
        set inventory_item_id = v_inventory_item_id where id = v_receipt_item_id;
      insert into public.inventory_events (
        household_id, inventory_item_id, event_type, quantity, value_vnd,
        actor_id, metadata
      ) values (
        p_household_id, v_inventory_item_id, 'added', v_quantity, v_total,
        auth.uid(), jsonb_build_object('name', v_name, 'unit', v_unit, 'source', 'receipt', 'receipt_id', v_receipt_id)
      );
    end if;
  end loop;
  return v_receipt_id;
end;
$$;

revoke all on function public.complete_shopping_item(uuid) from public, anon;
revoke all on function public.record_recipe_cooked(uuid, text, integer, jsonb) from public, anon;
revoke all on function public.consume_inventory_item(uuid, numeric, boolean) from public, anon;
revoke all on function public.import_receipt(uuid, text, timestamptz, integer, text, text, jsonb) from public, anon;
grant execute on function public.complete_shopping_item(uuid) to authenticated;
grant execute on function public.record_recipe_cooked(uuid, text, integer, jsonb) to authenticated;
grant execute on function public.consume_inventory_item(uuid, numeric, boolean) to authenticated;
grant execute on function public.import_receipt(uuid, text, timestamptz, integer, text, text, jsonb) to authenticated;

-- Keep receipt/item photos private. Object paths begin with household UUID.
insert into storage.buckets (id, name, public)
values ('household-food', 'household-food', false)
on conflict (id) do update set public = false;
drop policy if exists "household members read food photos" on storage.objects;
create policy "household members read food photos" on storage.objects
  for select using (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );
drop policy if exists "household members add food photos" on storage.objects;
create policy "household members add food photos" on storage.objects
  for insert with check (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );
drop policy if exists "household members update food photos" on storage.objects;
create policy "household members update food photos" on storage.objects
  for update using (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  ) with check (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );
drop policy if exists "household members delete food photos" on storage.objects;
create policy "household members delete food photos" on storage.objects
  for delete using (
    bucket_id = 'household-food'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

commit;
