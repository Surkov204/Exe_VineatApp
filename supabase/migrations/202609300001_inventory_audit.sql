-- Keep batch identity, creator and last editor independent of the item name.
alter table public.inventory_items
  add column if not exists created_by_name text,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null,
  add column if not exists updated_by_name text;

update public.inventory_items i set created_by_name = p.display_name
from public.profiles p where i.created_by = p.id and i.created_by_name is null;

create or replace function public.set_inventory_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); actor_name text;
begin
  if actor is not null then
    select display_name into actor_name from public.profiles where id = actor;
  end if;
  if tg_op = 'INSERT' then
    new.created_by := coalesce(actor, new.created_by);
    select display_name into new.created_by_name from public.profiles where id = new.created_by;
    new.updated_by := null;
    new.updated_by_name := null;
  else
    new.created_by := old.created_by;
    new.created_by_name := old.created_by_name;
    new.created_at := old.created_at;
    new.purchase_date := old.purchase_date;
    new.updated_by := coalesce(actor, old.updated_by);
    new.updated_by_name := coalesce(actor_name, old.updated_by_name);
  end if;
  return new;
end;
$$;
revoke all on function public.set_inventory_audit() from public, anon, authenticated;
drop trigger if exists inventory_audit on public.inventory_items;
create trigger inventory_audit before insert or update on public.inventory_items
for each row execute function public.set_inventory_audit();
