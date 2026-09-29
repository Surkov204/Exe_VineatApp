-- ViNeat realtime foundation (forward-only).
--
-- IMPORTANT
--   * Assumes supabase/migrations/202609200001_initial_schema.sql has already run.
--   * This file is additive. It never edits prior migrations and never uses the
--     service_role key. Everything below runs as the migration (postgres/admin)
--     role or as an authenticated client through SECURITY DEFINER RPCs.
--   * Do NOT apply automatically to a hosted project. Apply with the Supabase CLI
--     (supabase db push / supabase migration up) after reviewing.
--
-- WHAT THIS FIXES / ADDS
--   1. Replaces the two permissive household_members policies from the initial
--      schema:
--        - "members can join" allowed ANY authenticated user to insert a row with
--          user_id = auth.uid() into ANY household UUID (self-join by guessing id).
--        - "owners manage members" let ANY member delete ANY other member.
--      After this migration, membership changes only happen through
--      public.create_household / public.join_household_by_invite (owner-based,
--      invite-code verified). Direct client inserts/deletes are denied.
--   2. Adds an idempotent inventory item insert RPC keyed by a client
--      operation_id UUID, gated by household membership.
--   3. Adds a household-scoped monotonic revision counter plus a durable
--      household_changes log. Revision bump + change row + realtime broadcast are
--      emitted transactionally by a trigger, so a client can catch up with
--      "give me changes after revision R".
--   4. Creates/repairs private Realtime topic authorization policies on
--      realtime.messages so only household members can subscribe to
--      "household:<uuid>" (SELECT), even if other permissive policies exist.
--      Broadcasts remain untrusted hints; DB RPCs enforce real authorization.
--
-- SERVER CONTRACT (keep in sync with the Flutter repository/client)
--
--   public.create_household(p_name text)
--     -> public.households row (id, name, invite_code, created_by, ...)
--     Caller becomes the sole 'owner' member. Atomic: household + owner
--     membership are created in one statement. Requires an authenticated user.
--     Typical failure: {'code': '28000', message: 'not authenticated'}.
--
--   public.join_household_by_invite(p_invite_code text)
--     -> public.households row of the joined household
--     Invite code is normalised (upper, trimmed) before comparison. Idempotent:
--     joining twice returns the same household. Requires an authenticated user.
--     Typical failures:
--       'P0002' household not found
--       '28000' not authenticated
--
--   public.add_inventory_item(
--       p_operation_id uuid, p_household_id uuid, p_name text,
--       p_category_id uuid, p_quantity numeric, p_unit text,
--       p_price_vnd integer, p_purchase_date date, p_expiry_date date,
--       p_storage_location text, p_note text, p_image_path text,
--       p_source text, p_created_at timestamptz, p_item_id uuid)
--     -> the created or already-existing public.inventory_items row.
--     Idempotent on p_operation_id: a retried call returns the original row and
--     does NOT bump revision or emit a new change/broadcast. Requires membership.
--     The server sets created_by = auth.uid(); the client does not. A NULL
--     p_price_vnd means unknown (price_known=false), distinct from a real 0.
--     p_created_at is retained for a stable RPC signature but ignored: only
--     server time is authoritative for the newly created row.
--     Typical failures (raise SQLSTATE 42501, category 'insufficient_privilege'):
--       'P0002' household not found
--       '28000' not authenticated
--       '42501' caller is not a member of the household
--       '23514' source is not an allowed inventory source
--
--   public.get_household_changes(p_household_id uuid, p_after_revision bigint)
--     -> setof (revision, entity, entity_id, action, payload, actor_id,
--               operation_id, created_at)
--     Household-scoped catch-up feed. If the client's last revision is older than
--     the oldest retained log entry, it must perform a full snapshot instead.
--     Monotonic revisions: apply changes in ascending revision order.
--
--   Existing permissions on realtime are preserved. This migration only ensures
--   the topic-scoped SELECT policy exists for authenticated users. Server-side
--   broadcast inserts are performed by the trigger as the migration owner.
--
-- REALTIME TOPIC
--   "household:<household_id>"   (private channel, config.private = true)
--   Event name: 'household_change'
--   Payload mirrors household_changes minus sensitive fields; it is a hint only.
--   Clients must reconcile with get_household_changes after subscribing.

-- 1. Guard: this migration depends on the initial schema. Fail loudly instead of
--    creating half-broken objects.
do $$
begin
  if to_regclass('public.household_members') is null
     or to_regclass('public.inventory_items') is null
     or to_regclass('public.households') is null then
    raise exception
      '202609270001_realtime_foundation requires 202609200001_initial_schema to run first';
  end if;
end;
$$;
-- 2. Close the two permissive household_members policies from the initial schema.
--    Membership is now managed exclusively through the invite-gated RPCs below.
drop policy if exists "members can join" on public.household_members;
drop policy if exists "owners manage members" on public.household_members;
-- A direct household INSERT could otherwise create an orphan household without
-- an owner membership. Creation must go through create_household() below.
drop policy if exists "users create their households" on public.households;
-- Inventory changes go through reviewed RPCs. The base FOR ALL policy let
-- clients forge server-owned fields (version/created_by/operation id).
drop policy if exists "inventory member access" on public.inventory_items;
drop policy if exists "inventory is member readable" on public.inventory_items;
create policy "inventory is member readable" on public.inventory_items
  for select using (public.is_household_member(household_id));
-- Reporting events must not be forged directly by an authenticated client.
-- The inventory RPC/trigger can populate them server-side in a future release.
drop policy if exists "inventory events member access" on public.inventory_events;
drop policy if exists "inventory events are member readable" on public.inventory_events;
create policy "inventory events are member readable" on public.inventory_events
  for select using (public.is_household_member(household_id));
drop policy if exists "activity is member insertable" on public.activity_logs;
-- 3. Revision infrastructure -------------------------------------------------

-- Preserve the originating operation on the committed row so the trigger can
-- include it in the event (and clients can match an optimistic local write).
alter table public.inventory_items add column if not exists client_operation_id uuid;
alter table public.inventory_items add column if not exists price_known boolean not null default true;
alter table public.inventory_items add column if not exists version bigint not null default 1;
create unique index if not exists inventory_items_client_operation_idx
  on public.inventory_items (client_operation_id)
  where client_operation_id is not null;
alter table public.inventory_items
  drop constraint if exists inventory_items_source_check;
alter table public.inventory_items
  add constraint inventory_items_source_check
  check (source in ('manual', 'receipt', 'template', 'import', 'voice'));
-- Server versions, never client clocks, decide whether an edit was based on a
-- stale row. This trigger also covers admin-side writes outside the RPC.
create or replace function public.inventory_items_bump_version()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1;
  else
    new.version := old.version + 1;
  end if;
  return new;
end;
$$;
revoke all on function public.inventory_items_bump_version() from public, anon, authenticated;
drop trigger if exists inventory_items_bump_version on public.inventory_items;
create trigger inventory_items_bump_version
  before insert or update on public.inventory_items
  for each row execute function public.inventory_items_bump_version();
-- Per-household monotonic revision. The counter is isolated in its own table so
-- updates on it are short row-locks on a single row per household, avoiding
-- contention with the change log itself.
create table if not exists public.household_revisions (
  household_id uuid primary key references public.households(id) on delete cascade,
  revision bigint not null default 0,
  updated_at timestamptz not null default timezone('utc', now())
);
-- Durable change log. Clients catch up with changes after their last revision.
-- Retention is intentionally not automated here; prune in a scheduled job
-- (e.g. keep 30 days) once real traffic exists.
create table if not exists public.household_changes (
  household_id uuid not null references public.households(id) on delete cascade,
  revision bigint not null,
  entity text not null,
  entity_id uuid,
  action text not null check (action in ('insert', 'update', 'delete')),
  payload jsonb not null default '{}'::jsonb,
  actor_id uuid references public.profiles(id) on delete set null,
  operation_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (household_id, revision)
);
-- The revision table is private: no direct client access. All reads/writes go
-- through SECURITY DEFINER functions and the writer trigger.
alter table public.household_revisions enable row level security;
revoke all on public.household_revisions from anon, authenticated;
-- Change log is readable by household members; writes only via the trigger.
alter table public.household_changes enable row level security;
revoke all on public.household_changes from anon;
grant select on public.household_changes to authenticated;
drop policy if exists "changes are member readable" on public.household_changes;
create policy "changes are member readable" on public.household_changes
  for select using (public.is_household_member(household_id));
-- 4. Revision bump + transactional change emit + private realtime broadcast ----

-- Core emitter. Must run inside the same transaction as the mutation. It:
--   * runs only from a trusted inventory trigger (the function is not granted
--     to authenticated clients; ordinary client writes require an RPC),
--   * bumps the household revision,
--   * writes the durable change-log row that carries that revision,
--   * broadcasts to the private "household:<id>" topic via realtime.send.
-- A Realtime outage must not roll back the actual mutation. Clients must treat the
-- broadcast as a hint and reconcile through get_household_changes.
create or replace function public.emit_household_change(
  p_household_id uuid,
  p_entity text,
  p_entity_id uuid,
  p_action text,
  p_payload jsonb default '{}'::jsonb,
  p_operation_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revision bigint;
  v_actor uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
begin
  if p_action not in ('insert', 'update', 'delete') then
    raise exception 'invalid action %', p_action using errcode = '22023';
  end if;

  insert into public.household_revisions (household_id, revision)
  values (p_household_id, 1)
  on conflict (household_id) do update
    set revision = public.household_revisions.revision + 1,
        updated_at = timezone('utc', now())
  returning revision into v_revision;

  insert into public.household_changes (
    household_id, revision, entity, entity_id, action, payload,
    actor_id, operation_id
  )
  values (
    p_household_id, v_revision, p_entity, p_entity_id, p_action, v_payload,
    v_actor, p_operation_id
  );

  begin
    perform realtime.send(
      jsonb_build_object(
        'household_id', p_household_id,
        'revision', v_revision,
        'entity', p_entity,
        'entity_id', p_entity_id,
        'action', p_action,
        'operation_id', p_operation_id
      ),
      'household_change',
       'household:' || p_household_id::text,
       true
    );
  exception when others then
    null;
  end;

  return v_revision;
end;
$$;
-- This function is deliberately NOT callable by clients. Otherwise a member
-- could forge revisions/events without an actual database mutation.
revoke all on function public.emit_household_change(uuid, text, uuid, text, jsonb, uuid)
  from public;
revoke all on function public.emit_household_change(uuid, text, uuid, text, jsonb, uuid)
  from anon, authenticated;
-- Generic trigger function used by the mutation triggers below. It relies on
-- public.emit_household_change is private; only this SECURITY DEFINER trigger
-- may invoke it. auth.uid() still resolves the original request's JWT identity.
create or replace function public.inventory_items_emit_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household uuid;
  v_item_id uuid;
  v_action text;
  v_payload jsonb;
begin
  if tg_op = 'DELETE' then
    v_household := old.household_id;
    v_item_id := old.id;
    v_action := 'delete';
    v_payload := jsonb_build_object('id', old.id, 'household_id', old.household_id);
  elsif tg_op = 'UPDATE' then
    if new.household_id is distinct from old.household_id then
      raise exception 'cannot move an inventory item between households'
        using errcode = '23514';
    end if;
    v_household := new.household_id;
    v_item_id := new.id;
    v_action := 'update';
    v_payload := to_jsonb(new);
  else
    v_household := new.household_id;
    v_item_id := new.id;
    v_action := 'insert';
    v_payload := to_jsonb(new);
  end if;

  perform public.emit_household_change(
    v_household,
    'inventory_items',
    v_item_id,
    v_action,
    v_payload,
    case when tg_op = 'DELETE' then old.client_operation_id
         else new.client_operation_id end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
revoke all on function public.inventory_items_emit_change() from public, anon, authenticated;
drop trigger if exists inventory_items_emit_change on public.inventory_items;
create trigger inventory_items_emit_change
  after insert or update or delete on public.inventory_items
  for each row execute function public.inventory_items_emit_change();
-- 5. Household creation / joining via invite code (SECURITY DEFINER) -----------

-- create_household(name) -> households row.
-- Using an RPC instead of a direct INSERT avoids the ownership bypass that comes
-- with separate identities for the household row and its owner membership: the
-- household, its revision row and the owner membership are created atomically,
-- and the caller can never create a household they are not the owner of.
create or replace function public.create_household(p_name text default 'Gia đình của tôi')
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_household public.households;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_name is null or length(btrim(p_name)) = 0 then
    p_name := 'Gia đình của tôi';
  end if;
  if length(btrim(p_name)) > 100 then
    raise exception 'household name is too long' using errcode = '22023';
  end if;

  insert into public.households (name, invite_code, created_by)
  values (
    btrim(p_name),
    -- Human-readable, hard-to-guess invite code. 12 hex chars = 48 bits.
     upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
    v_uid
  )
  returning * into v_household;

  insert into public.household_members (household_id, user_id, member_role)
  values (v_household.id, v_uid, 'owner');

  insert into public.household_revisions (household_id, revision)
  values (v_household.id, 0)
  on conflict (household_id) do nothing;

  return v_household;
end;
$$;
-- join_household_by_invite(code) -> households row.
-- The only way a non-owner becomes a member. Verifies the invite code server-side
-- so a client cannot self-join an arbitrary household id.
create or replace function public.join_household_by_invite(p_invite_code text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_invite_code, '')));
  v_household public.households;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if v_code = '' then
    raise exception 'invite code is required' using errcode = '22023';
  end if;
  if length(v_code) != 12 then
    raise exception 'invalid invite code' using errcode = '22023';
  end if;

  select * into v_household
  from public.households
  where invite_code = v_code;

  if not found then
    raise exception 'household not found for invite code'
      using errcode = 'P0002';
  end if;

  -- Idempotent join. A user may only be a member of a household once; role is
  -- never overwritten, so an existing owner stays owner.
  insert into public.household_members (household_id, user_id, member_role)
  values (v_household.id, v_uid, 'member')
  on conflict (household_id, user_id) do nothing;

  return v_household;
end;
$$;
-- Household owner management (transfer/remove) is intentionally left to a
-- follow-up migration. For now owners cannot remove members through the API,
-- which is strictly safer than the initial permissive delete policy.

revoke all on function public.create_household(text) from public;
revoke all on function public.join_household_by_invite(text) from public;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.join_household_by_invite(text) to authenticated;
-- 6. Idempotent inventory item insertion ---------------------------------------

-- Client sends a stable operation_id per mutation attempt. Retries with the same
-- operation_id return the previously created row without a new revision/change.
create table if not exists public.inventory_insert_operations (
  operation_id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  -- Keep the operation tombstone if the item is later removed: a delayed retry
  -- must never recreate an item the family intentionally deleted.
  item_id uuid references public.inventory_items(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);
alter table public.inventory_insert_operations enable row level security;
revoke all on public.inventory_insert_operations from anon, authenticated;
create or replace function public.add_inventory_item(
  p_operation_id uuid,
  p_household_id uuid,
  p_name text,
  p_category_id uuid default null,
  p_quantity numeric default 1,
  p_unit text default 'phần',
  p_price_vnd integer default null,
  p_purchase_date date default null,
  p_expiry_date date default null,
  p_storage_location text default 'fridge',
  p_note text default null,
  p_image_path text default null,
  p_source text default 'manual',
  p_created_at timestamptz default null,
  p_item_id uuid default null
)
returns public.inventory_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.inventory_items;
  v_operation public.inventory_insert_operations;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_operation_id is null then
    raise exception 'operation_id is required' using errcode = '22023';
  end if;
  if p_source not in ('manual', 'receipt', 'template', 'import', 'voice') then
    raise exception 'invalid inventory source %', p_source using errcode = '23514';
  end if;

  if not public.is_household_member(p_household_id) then
    raise exception 'caller is not a member of household %', p_household_id
      using errcode = '42501';
  end if;

  -- Fast idempotent replay: same operation already committed.
   select * into v_operation from public.inventory_insert_operations
   where operation_id = p_operation_id;
   if found then
     if v_operation.household_id is distinct from p_household_id
         or v_operation.actor_id is distinct from v_uid then
       raise exception 'operation_id belongs to another request'
         using errcode = '42501';
     end if;
     if v_operation.item_id is null then
       raise exception 'operation already committed to a deleted item'
         using errcode = '23505';
     end if;
     select * into v_item from public.inventory_items
     where id = v_operation.item_id;
     return v_item;
   end if;

   if p_name is null or btrim(p_name) = '' or length(p_name) > 200 then
     raise exception 'name must contain 1 to 200 characters' using errcode = '22023';
   end if;
   if p_quantity is null or p_quantity <= 0 or p_quantity > 1000000 then
     raise exception 'quantity must be positive' using errcode = '22023';
   end if;
   if p_unit is null or btrim(p_unit) = '' or length(p_unit) > 40 then
     raise exception 'unit must contain 1 to 40 characters' using errcode = '22023';
   end if;
   if p_price_vnd is not null and p_price_vnd < 0 then
     raise exception 'price must not be negative' using errcode = '22023';
   end if;

   insert into public.inventory_items (
     id, household_id, category_id, name, quantity, unit, price_vnd,
    purchase_date, expiry_date, storage_location, note, image_path,
     source, created_by, created_at, client_operation_id, price_known
  )
  values (
     coalesce(p_item_id, gen_random_uuid()), p_household_id, p_category_id,
     btrim(p_name), p_quantity,
     btrim(p_unit), coalesce(p_price_vnd, 0),
    p_purchase_date, p_expiry_date, coalesce(p_storage_location, 'fridge'),
    p_note, p_image_path, p_source, v_uid,
     timezone('utc', now()), p_operation_id,
     p_price_vnd is not null
  )
  returning * into v_item;

  insert into public.inventory_insert_operations (
    operation_id, household_id, item_id, actor_id
  )
  values (p_operation_id, p_household_id, v_item.id, v_uid);

  return v_item;

exception
  when unique_violation then
    -- Concurrent retry of the same operation won the race. Return the winner's
    -- row. The losing transaction's inventory insert is rolled back with it.
     select * into v_operation from public.inventory_insert_operations
     where operation_id = p_operation_id;
     if not found then
       raise;
     end if;
     if v_operation.household_id is distinct from p_household_id
         or v_operation.actor_id is distinct from v_uid then
       raise exception 'operation_id belongs to another request'
         using errcode = '42501';
     end if;
     if v_operation.item_id is null then
       raise exception 'operation already committed to a deleted item'
         using errcode = '23505';
     end if;
     select * into v_item from public.inventory_items
     where id = v_operation.item_id;
     return v_item;
end;
$$;
revoke all on function public.add_inventory_item(
  uuid, uuid, text, uuid, numeric, text, integer, date, date, text, text, text, text, timestamptz, uuid
) from public;
grant execute on function public.add_inventory_item(
  uuid, uuid, text, uuid, numeric, text, integer, date, date, text, text, text, text, timestamptz, uuid
) to authenticated;
-- 7. Catch-up read API ---------------------------------------------------------

-- Returns changes strictly newer than p_after_revision for a household the caller
-- belongs to. Clients apply these in ascending revision order. If the oldest
-- retained revision is greater than p_after_revision + 1, the client has missed
-- changes and must load a fresh snapshot instead.
create or replace function public.get_household_changes(
  p_household_id uuid,
  p_after_revision bigint default 0,
  p_limit integer default 500
)
returns table (
  event_id text,
  revision bigint,
  entity text,
  entity_id uuid,
  action text,
  payload jsonb,
  actor_id uuid,
  operation_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'caller is not a member of household %', p_household_id
      using errcode = '42501';
  end if;

  return query
   select c.household_id::text || ':' || c.revision::text,
          c.revision, c.entity, c.entity_id, c.action, c.payload,
         c.actor_id, c.operation_id, c.created_at
  from public.household_changes c
  where c.household_id = p_household_id
    and c.revision > greatest(coalesce(p_after_revision, 0), 0)
  order by c.revision asc
  limit least(greatest(coalesce(p_limit, 500), 1), 2000);
end;
$$;
revoke all on function public.get_household_changes(uuid, bigint, integer) from public;
grant execute on function public.get_household_changes(uuid, bigint, integer) to authenticated;
-- The change feed may be pruned later. An empty batch cannot prove that the
-- client is current; expose the authoritative high-water cursor separately.
create or replace function public.get_household_sync_cursor(p_household_id uuid)
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare v_cursor jsonb;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'caller is not a member of household %', p_household_id
      using errcode = '42501';
  end if;
  select jsonb_build_object(
    'current_revision', coalesce((select r.revision from public.household_revisions r
      where r.household_id = p_household_id), 0),
    'oldest_retained_revision', (select min(c.revision) from public.household_changes c
      where c.household_id = p_household_id)
  ) into v_cursor;
  return v_cursor;
end;
$$;
revoke all on function public.get_household_sync_cursor(uuid) from public;
grant execute on function public.get_household_sync_cursor(uuid) to authenticated;
-- A snapshot and its high-water revision come from the same MVCC statement.
-- Subscribe first, then call this RPC so events arriving during loading are
-- safely deduplicated/caught up by revision. A private household is required.
create or replace function public.get_household_inventory_snapshot(p_household_id uuid)
returns jsonb
language plpgsql security definer stable set search_path = public as $$
declare v_snapshot jsonb;
begin
  if not public.is_household_member(p_household_id) then
    raise exception 'caller is not a member of household %', p_household_id
      using errcode = '42501';
  end if;
  select jsonb_build_object(
    'revision', coalesce((select r.revision from public.household_revisions r
                          where r.household_id = p_household_id), 0),
    'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at, i.id)
                       from public.inventory_items i
                       where i.household_id = p_household_id), '[]'::jsonb)
  ) into v_snapshot;
  return v_snapshot;
end;
$$;
revoke all on function public.get_household_inventory_snapshot(uuid) from public;
grant execute on function public.get_household_inventory_snapshot(uuid) to authenticated;
-- 8. Private Realtime Broadcast authorization ----------------------------------

-- The household topic uses the private flag: only authenticated users with a
-- matching SELECT policy on realtime.messages may subscribe. Membership is
-- resolved from the topic string "household:<uuid>".
--
-- realtime.messages already exists and has RLS enabled in a Supabase project.
-- Guard the policy creation so this migration still applies cleanly if the
-- realtime schema is missing (e.g. plain Postgres in CI/local tests).
do $$
begin
  if to_regclass('realtime.messages') is null then
    raise notice 'realtime.messages not present; skipping Realtime authorization policies';
    return;
  end if;

  execute 'grant select on realtime.messages to authenticated';

  -- A restrictive policy gates the household namespace even if the project
  -- already has an unrelated permissive SELECT policy on realtime.messages.
  -- Existing INSERT policies are left intact for other project features; the
  -- client treats any broadcast as an untrusted hint and reads the DB change log.
  execute 'drop policy if exists "household members can receive broadcasts" on realtime.messages';
  execute 'drop policy if exists "household topics require membership" on realtime.messages';
  execute $policy$
      create policy "household members can receive broadcasts"
      on realtime.messages
      for select
      to authenticated
      using (
        realtime.messages.extension = 'broadcast'
         and case
           when realtime.topic() ~* '^household:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           then public.is_household_member(split_part(realtime.topic(), ':', 2)::uuid)
           else false
         end
      )
    $policy$;
  execute $policy$
      create policy "household topics require membership"
      on realtime.messages as restrictive for select to authenticated
      using (
        case
          when realtime.topic() like 'household:%'
            then realtime.messages.extension = 'broadcast'
              and case
                when realtime.topic() ~* '^household:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                then public.is_household_member(split_part(realtime.topic(), ':', 2)::uuid)
                else false
              end
          else true
        end
      )
    $policy$;

  -- Presence is not used by this app yet; no presence policy is created.
end;
$$;
-- 9. Documentation / comments --------------------------------------------------

comment on table public.household_revisions is
  'Per-household monotonic revision counter. Read via get_household_changes; writes only through emit_household_change().';
comment on table public.household_changes is
  'Durable, household-scoped change log. One row per committed mutation, keyed (household_id, revision).';
comment on function public.create_household(text) is
  'Creates a household, its owner membership and revision row atomically. Returns the households row.';
comment on function public.join_household_by_invite(text) is
  'Joins the household matching the invite code. Idempotent. Returns the households row.';
comment on function public.add_inventory_item(
  uuid, uuid, text, uuid, numeric, text, integer, date, date, text, text, text, text, timestamptz, uuid) is
  'Idempotent inventory insert keyed by operation_id; requires household membership; emits revision+change+broadcast via trigger.';
comment on function public.get_household_changes(uuid, bigint, integer) is
  'Catch-up feed of household changes after a given revision. Caller must be a household member.';
