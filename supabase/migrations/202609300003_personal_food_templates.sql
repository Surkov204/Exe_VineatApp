alter table public.profiles add column if not exists expiry_preferences jsonb not null default '{"enabled":true,"automatic":false}'::jsonb;
create table public.food_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (length(name) between 1 and 80),
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  created_at timestamptz not null default now()
);
alter table public.food_templates enable row level security;
create policy "personal templates" on public.food_templates for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on public.food_templates to authenticated;
