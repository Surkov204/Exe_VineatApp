-- All household invitations and membership changes are authenticated and
-- transactional. Clients must not write household_members directly.
begin;

drop policy if exists "users create their households" on public.households;
drop policy if exists "owners update households" on public.households;
drop policy if exists "members can join" on public.household_members;
drop policy if exists "owners manage members" on public.household_members;

insert into public.household_members (household_id, user_id, member_role)
select h.id, h.created_by, 'owner'
from public.households h
where not exists (
  select 1 from public.household_members m
  where m.household_id = h.id and m.user_id = h.created_by
);

create or replace function public.is_household_owner(target_household uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = target_household
      and m.user_id = auth.uid()
      and m.member_role = 'owner'
  );
$$;

create policy "owners update households" on public.households
  for update using (public.is_household_owner(id))
  with check (public.is_household_owner(id));

create or replace function public.create_household(p_name text)
returns table(out_id uuid, out_name text, out_invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid;
  v_invite_code text;
  v_name text := nullif(btrim(p_name), '');
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if v_name is null or length(v_name) > 60 then
    raise exception 'Household name must contain 1 to 60 characters'
      using errcode = '22023';
  end if;

  insert into public.profiles (id) values (v_user_id)
    on conflict (id) do nothing;
  loop
    v_invite_code := upper(encode(extensions.gen_random_bytes(8), 'hex'));
    insert into public.households (name, invite_code, created_by)
    values (v_name, v_invite_code, v_user_id)
    on conflict (invite_code) do nothing
    returning id into v_household_id;
    exit when v_household_id is not null;
  end loop;
  insert into public.household_members (household_id, user_id, member_role)
    values (v_household_id, v_user_id, 'owner');
  return query select h.id, h.name, h.invite_code
    from public.households h where h.id = v_household_id;
end;
$$;

create or replace function public.join_household(p_invite_code text)
returns table(out_id uuid, out_name text, out_role text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid;
  v_name text;
  v_role text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if nullif(btrim(p_invite_code), '') is null then
    raise exception 'Invite code is required' using errcode = '22023';
  end if;
  select h.id, h.name into v_household_id, v_name
    from public.households h
    where upper(h.invite_code) = upper(btrim(p_invite_code));
  if v_household_id is null then
    raise exception 'Invalid household invite code' using errcode = '22023';
  end if;
  insert into public.profiles (id) values (v_user_id)
    on conflict (id) do nothing;
  insert into public.household_members (household_id, user_id, member_role)
    values (v_household_id, v_user_id, 'member')
    on conflict (household_id, user_id) do nothing;
  select m.member_role into v_role from public.household_members m
    where m.household_id = v_household_id and m.user_id = v_user_id;
  return query select v_household_id, v_name, v_role;
end;
$$;

create or replace function public.rotate_household_invite_code(p_household_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite_code text;
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only a household owner may rotate its invite code'
      using errcode = '42501';
  end if;
  loop
    v_invite_code := upper(encode(extensions.gen_random_bytes(8), 'hex'));
    begin
      update public.households set invite_code = v_invite_code
        where id = p_household_id;
      return v_invite_code;
    exception when unique_violation then
      null;
    end;
  end loop;
end;
$$;

create or replace function public.remove_household_member(
  p_household_id uuid, p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only a household owner may remove members'
      using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Transfer ownership before leaving this household'
      using errcode = '22023';
  end if;
  delete from public.household_members m
    where m.household_id = p_household_id
      and m.user_id = p_user_id and m.member_role <> 'owner';
  return found;
end;
$$;

create or replace function public.leave_household(p_household_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
begin
  select m.member_role into v_role from public.household_members m
    where m.household_id = p_household_id and m.user_id = auth.uid();
  if v_role is null then
    return false;
  end if;
  if v_role = 'owner' then
    raise exception 'Transfer ownership before leaving this household'
      using errcode = '22023';
  end if;
  delete from public.household_members m
    where m.household_id = p_household_id and m.user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.is_household_owner(uuid) from public, anon;
revoke all on function public.create_household(text) from public, anon;
revoke all on function public.join_household(text) from public, anon;
revoke all on function public.rotate_household_invite_code(uuid) from public, anon;
revoke all on function public.remove_household_member(uuid, uuid) from public, anon;
revoke all on function public.leave_household(uuid) from public, anon;
grant execute on function public.is_household_owner(uuid) to authenticated;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant execute on function public.rotate_household_invite_code(uuid) to authenticated;
grant execute on function public.remove_household_member(uuid, uuid) to authenticated;
grant execute on function public.leave_household(uuid) to authenticated;

comment on function public.create_household(text) is
  'Creates a household and owner membership atomically with a server-generated invite code.';
comment on function public.join_household(text) is
  'Validates an invite code and joins the authenticated user atomically.';
comment on function public.leave_household(uuid) is
  'Allows a non-owner member to leave; household owners must transfer ownership first.';

commit;
