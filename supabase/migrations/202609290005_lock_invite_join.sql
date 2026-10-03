begin;

-- Serialize invite validation with code rotation. A join started with a code
-- that is being rotated waits, then re-checks the current code before joining.
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
    where upper(h.invite_code) = upper(btrim(p_invite_code))
    for update;
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

commit;
