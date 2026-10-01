begin;

-- Registration and profile settings edit only these three user-owned fields.
-- Row-level security in the initial schema still restricts UPDATE to auth.uid().
grant update (display_name, role_label, diet)
  on table public.profiles to authenticated;

commit;
