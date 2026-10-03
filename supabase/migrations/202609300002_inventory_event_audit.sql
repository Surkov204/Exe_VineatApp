-- Preserve names and remaining stock at the moment of each operation.
create or replace function public.annotate_inventory_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare person text; remaining numeric;
begin
  if auth.uid() is not null then new.actor_id := auth.uid(); end if;
  select display_name into person from public.profiles where id = new.actor_id;
  select quantity into remaining from public.inventory_items
    where id = new.inventory_item_id and household_id = new.household_id;
  new.metadata := coalesce(new.metadata, '{}'::jsonb)
    || jsonb_build_object('actor_name', person, 'remaining_quantity', remaining);
  return new;
end;
$$;
revoke all on function public.annotate_inventory_event() from public, anon, authenticated;
create trigger annotate_inventory_event before insert on public.inventory_events
for each row execute function public.annotate_inventory_event();

-- Historical actors are known; historical remaining quantities are not inferred.
update public.inventory_events e
set metadata = coalesce(e.metadata, '{}'::jsonb) || jsonb_build_object('actor_name', p.display_name)
from public.profiles p where e.actor_id = p.id;
