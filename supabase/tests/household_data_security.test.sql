begin;

select plan(33);

select ok(
  not has_table_privilege('anon', 'public.households', 'select')
  and not has_table_privilege('anon', 'public.inventory_items', 'select')
  and not has_table_privilege('authenticated', 'public.household_members', 'insert')
  and not has_table_privilege('authenticated', 'public.household_members', 'update')
  and not has_table_privilege('authenticated', 'public.household_members', 'delete'),
  'private household rows are authenticated-only and memberships cannot be edited directly'
);

select ok(
  has_table_privilege('authenticated', 'public.inventory_items', 'select')
  and has_table_privilege('authenticated', 'public.inventory_items', 'insert')
  and has_table_privilege('authenticated', 'public.inventory_items', 'update')
  and has_table_privilege('authenticated', 'public.inventory_items', 'delete'),
  'authenticated members receive only the inventory operations used by the app'
);

select ok(
  has_table_privilege('authenticated', 'public.shopping_items', 'select')
  and has_table_privilege('authenticated', 'public.shopping_items', 'insert')
  and has_table_privilege('authenticated', 'public.shopping_items', 'update')
  and has_table_privilege('authenticated', 'public.shopping_items', 'delete'),
  'authenticated members receive the shopping operations used by the app'
);

select ok(
  has_table_privilege('authenticated', 'public.inventory_events', 'select')
  and not has_table_privilege('authenticated', 'public.inventory_events', 'insert')
  and not has_table_privilege('authenticated', 'public.inventory_events', 'update')
  and not has_table_privilege('authenticated', 'public.inventory_events', 'delete'),
  'report history is readable but cannot be directly forged or removed'
);

select ok(
  has_table_privilege('authenticated', 'public.receipts', 'select')
  and has_table_privilege('authenticated', 'public.receipt_items', 'select')
  and not has_table_privilege('authenticated', 'public.receipts', 'insert')
  and not has_table_privilege('authenticated', 'public.receipt_items', 'insert'),
  'receipt history is read-only outside its transactional import function'
);

select ok(
  has_table_privilege('authenticated', 'public.tutorial_progress', 'select')
  and has_table_privilege('authenticated', 'public.tutorial_progress', 'insert')
  and has_table_privilege('authenticated', 'public.tutorial_progress', 'update'),
  'authenticated users can save their own tutorial progress'
);

select ok(
  has_table_privilege('authenticated', 'public.demo_imports', 'select')
  and not has_table_privilege('authenticated', 'public.demo_imports', 'insert'),
  'one-time demo imports can only be claimed by the server function'
);

select ok(
  has_table_privilege('authenticated', 'public.recipe_cook_events', 'select')
  and has_table_privilege('authenticated', 'public.recipe_cook_event_items', 'select')
  and not has_table_privilege('authenticated', 'public.recipe_cook_events', 'insert')
  and not has_table_privilege('authenticated', 'public.recipe_cook_event_items', 'insert'),
  'cooking history is readable but is written only by the transaction function'
);

select ok(
  not has_table_privilege('anon', 'storage.objects', 'select')
  and has_table_privilege('authenticated', 'storage.objects', 'select')
  and has_table_privilege('authenticated', 'storage.objects', 'insert')
  and has_table_privilege('authenticated', 'storage.objects', 'update')
  and not has_table_privilege('authenticated', 'storage.objects', 'delete'),
  'private family photos expose only the authenticated upload/read/overwrite operations'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'authenticated', 'authenticated',
   'vineat-owner@example.test', '', timezone('utc', now()),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'authenticated', 'authenticated',
   'vineat-other@example.test', '', timezone('utc', now()),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'authenticated', 'authenticated',
   'vineat-third@example.test', '', timezone('utc', now()),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.households (id, name, invite_code, created_by) values
  ('11111111-1111-4111-8111-111111111111', 'Gia đình A', 'VINEATTEST000001',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('22222222-2222-4222-8222-222222222222', 'Gia đình A thứ hai', 'VINEATTEST000002',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('33333333-3333-4333-8333-333333333333', 'Gia đình B', 'VINEATTEST000003',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc');

insert into public.household_members (household_id, user_id, member_role) values
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner'),
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner'),
  ('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'member'),
  ('33333333-3333-4333-8333-333333333333', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'owner');

insert into public.inventory_items (
  id, household_id, name, quantity, unit, price_vnd, created_by
) values (
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111', 'Cà chua riêng A', 3, 'quả', 12000,
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);

insert into public.shopping_items (
  id, household_id, name, quantity, unit, created_by
) values (
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111', 'Tỏi riêng A', 1, 'củ',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);

select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'),
  1,
  'A can read its own household inventory'
);

select throws_ok(
  $$insert into public.inventory_events (household_id, event_type, quantity)
    values ('11111111-1111-4111-8111-111111111111', 'added', 1)$$,
  '42501',
  'new row violates row-level security policy for table "inventory_events"',
  'members cannot forge report history with direct inserts'
);

select lives_ok(
  $$select public.record_inventory_event(
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444', 'updated', 3, 12000,
    '{"unit":"quả"}'::jsonb
  )$$,
  'an authorized member can record a report event through the RPC'
);

select throws_ok(
  $$select public.record_inventory_event(
    '22222222-2222-4222-8222-222222222222',
    '44444444-4444-4444-8444-444444444444', 'updated', 3, 12000, '{}'::jsonb
  )$$,
  '42501',
  'Inventory item not found',
  'an event cannot attach another household inventory item'
);

select throws_ok(
  $$update public.inventory_items
    set household_id = '22222222-2222-4222-8222-222222222222'
    where id = '44444444-4444-4444-8444-444444444444'$$,
  '42501',
  'household_id is immutable',
  'inventory rows cannot be reassigned between households'
);

select throws_ok(
  $$update public.shopping_items
    set household_id = '22222222-2222-4222-8222-222222222222'
    where id = '55555555-5555-4555-8555-555555555555'$$,
  '42501',
  'household_id is immutable',
  'shopping rows cannot be reassigned between households'
);

select throws_ok(
  $$insert into public.recipe_cook_events (household_id, recipe_name, cooked_by)
    values ('11111111-1111-4111-8111-111111111111', 'Giả mạo', auth.uid())$$,
  '42501',
  'new row violates row-level security policy for table "recipe_cook_events"',
  'cooking history is written only by its transactional RPC'
);

select throws_ok(
  $$insert into public.receipts (household_id, created_by)
    values ('11111111-1111-4111-8111-111111111111', auth.uid())$$,
  '42501',
  'new row violates row-level security policy for table "receipts"',
  'receipt history is written only by its transactional import RPC'
);

select lives_ok(
  $$select public.rotate_household_invite_code(
    '11111111-1111-4111-8111-111111111111'
  )$$,
  'the household owner can rotate an invite code'
);
select set_config(
  'vineat.test.rotated_invite_code',
  (select invite_code from public.households
   where id = '11111111-1111-4111-8111-111111111111'),
  true
);

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
set local role authenticated;

select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'),
  1,
  'the second household member sees shared inventory'
);

select lives_ok(
  $$select public.complete_shopping_item('55555555-5555-4555-8555-555555555555')$$,
  'a family member can complete a shopping item'
);

select lives_ok(
  $$select public.complete_shopping_item('55555555-5555-4555-8555-555555555555')$$,
  'repeating the purchase action is idempotent'
);

select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'
     and name = 'Tỏi riêng A'),
  1,
  'repeated purchase never creates duplicate stock'
);

select throws_ok(
  $$select public.set_household_member_role(
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'adult'
  )$$,
  '42501',
  'Only a household owner may change member roles',
  'a regular member cannot change household roles'
);

select throws_ok(
  $$select public.remove_household_member(
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  )$$,
  '42501',
  'Only a household owner may remove members',
  'a regular member cannot remove another household member'
);

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
set local role authenticated;

select lives_ok(
  $$select public.set_household_member_role(
    '11111111-1111-4111-8111-111111111111',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'adult'
  )$$,
  'the owner can update a member role'
);

select lives_ok(
  $$select public.remove_household_member(
    '11111111-1111-4111-8111-111111111111',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  )$$,
  'the owner can revoke a member'
);

reset role;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', true);
set local role authenticated;

select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'a removed member immediately loses access to family inventory'
);

reset role;
select set_config('request.jwt.claim.sub', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', true);
set local role authenticated;

select lives_ok(
  $$select * from public.create_household('Gia đình mới')$$,
  'a new household can be created with a server-generated invite code'
);

select throws_ok(
  $$select * from public.join_household('VINEATTEST000001')$$,
  '22023',
  'Invalid household invite code',
  'a rotated invitation code cannot join the previous household'
);

select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'an unrelated account cannot read another household inventory'
);

select is(
  (select count(*)::integer from public.inventory_events
   where household_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'an unrelated account cannot read another household report history'
);

select lives_ok(
  $$select * from public.join_household(
    lower(current_setting('vineat.test.rotated_invite_code'))
  )$$,
  'a second account can join using a valid case-insensitive invite code'
);

select is(
  (select member_role from public.household_members
   where household_id = '11111111-1111-4111-8111-111111111111'
     and user_id = auth.uid()),
  'member',
  'a successful invite adds the account with the member role'
);

select * from finish();
rollback;
