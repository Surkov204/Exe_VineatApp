begin;

-- pgcrypto is installed in the Supabase-managed extensions schema.
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

commit;
