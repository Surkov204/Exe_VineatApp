-- Bounded Deepgram voice pilot. Apply after the initial and realtime migrations.
-- Authenticated callers can claim at most 30 short clips per UTC day each;
-- the entire project can claim at most 1,000 clips until an admin raises the
-- limit through a reviewed migration. Never expose the provider key in SQL.

create table if not exists public.voice_trial_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_day date not null,
  used integer not null default 0 check (used between 0 and 30),
  primary key (user_id, usage_day)
);
create table if not exists public.voice_trial_budget (
  singleton boolean primary key default true check (singleton),
  used integer not null default 0 check (used between 0 and 1000)
);
insert into public.voice_trial_budget (singleton, used) values (true, 0)
  on conflict (singleton) do nothing;
alter table public.voice_trial_daily_usage enable row level security;
alter table public.voice_trial_budget enable row level security;
revoke all on public.voice_trial_daily_usage from anon, authenticated;
revoke all on public.voice_trial_budget from anon, authenticated;
create or replace function public.claim_voice_trial_slot()
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_used integer;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- An exception block rolls BOTH counters back when either quota is full.
  -- On conflict / UPDATE serialize simultaneous requests for the same user
  -- or project, so two devices cannot each spend the final slot.
  begin
    insert into public.voice_trial_daily_usage (user_id, usage_day, used)
    values (v_user, (now() at time zone 'UTC')::date, 1)
    on conflict (user_id, usage_day) do update
      set used = public.voice_trial_daily_usage.used + 1
      where public.voice_trial_daily_usage.used < 30
    returning used into v_used;
    if not found then
      raise exception 'voice quota exhausted' using errcode = 'P0100';
    end if;

    update public.voice_trial_budget
    set used = used + 1
    where singleton = true and used < 1000
    returning used into v_used;
    if not found then
      raise exception 'voice quota exhausted' using errcode = 'P0100';
    end if;
    return true;
  exception when SQLSTATE 'P0100' then
    return false;
  end;
end;
$$;
revoke all on function public.claim_voice_trial_slot() from public, anon, authenticated;
grant execute on function public.claim_voice_trial_slot() to authenticated;
