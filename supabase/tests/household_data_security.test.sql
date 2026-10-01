begin;

select plan(65);

select ok(
  has_table_privilege('authenticated', 'public.profiles', 'select')
  and has_column_privilege('authenticated', 'public.profiles', 'display_name', 'update')
  and has_column_privilege('authenticated', 'public.profiles', 'role_label', 'update')
  and has_column_privilege('authenticated', 'public.profiles', 'diet', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'update')
  and not has_table_privilege('anon', 'public.profiles', 'select'),
  'signed-in users can edit only profile fields used by registration and settings'
);

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
  (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass)
  and not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and 'anon'::name = any(roles)
  )
  and not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd = 'DELETE'
  ),
  'private family photos require RLS and expose no anonymous or delete policy'
);

select ok(
  (select public = false
      and file_size_limit = 10485760
      and allowed_mime_types @> array['image/jpeg', 'image/png', 'image/webp']::text[]
      and cardinality(allowed_mime_types) = 3
   from storage.buckets where id = 'household-food'),
  'the family photo bucket is private and limits upload size and image formats'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'household members read food photos' and cmd = 'SELECT'
      and 'authenticated'::name = any(roles)
      and qual like '%household-food%'
      and qual like '%storage.foldername%'
      and qual like '%is_household_member%'
  ),
  'photo read policy scopes objects to authenticated household members'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'household members add food photos' and cmd = 'INSERT'
      and 'authenticated'::name = any(roles)
      and with_check like '%household-food%'
      and with_check like '%storage.foldername%'
      and with_check like '%is_household_member%'
  ),
  'photo upload policy checks the destination household folder'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'household members update food photos' and cmd = 'UPDATE'
      and 'authenticated'::name = any(roles)
      and qual like '%household-food%'
      and qual like '%storage.foldername%'
      and qual like '%is_household_member%'
      and with_check like '%household-food%'
      and with_check like '%storage.foldername%'
      and with_check like '%is_household_member%'
  ),
  'photo overwrite policy checks both the existing and destination household'
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

insert into storage.objects (id, bucket_id, name, owner, owner_id, metadata)
values (
  '66666666-6666-4666-8666-666666666666',
  'household-food',
  '11111111-1111-4111-8111-111111111111/photos/private.png',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '{"mimetype":"image/png","size":128}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);

reset role;
set local role anon;
select is(
  (select count(*)::integer from storage.objects
   where id = '66666666-6666-4666-8666-666666666666'),
  0,
  'an anonymous user cannot read a household photo'
);

reset role;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
set local role authenticated;
select is(
  (select count(*)::integer from storage.objects
   where id = '66666666-6666-4666-8666-666666666666'),
  1,
  'a household member can read its family photo'
);
select throws_ok(
  $$delete from storage.objects
    where id = '66666666-6666-4666-8666-666666666666'$$,
  '42501',
  'Direct deletion from storage tables is not allowed. Use the Storage API instead.',
  'a household member cannot delete a family photo directly'
);
select is(
  (select count(*)::integer from storage.objects
   where id = '66666666-6666-4666-8666-666666666666'),
  1,
  'the family photo remains after a denied delete'
);
select throws_ok(
  $$update storage.objects
    set name = '33333333-3333-4333-8333-333333333333/photos/moved.png'
    where id = '66666666-6666-4666-8666-666666666666'$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'a household member cannot move a photo into another family folder'
);

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
  'permission denied for table inventory_events',
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

select lives_ok(
  $$select public.record_recipe_cooked(
    '11111111-1111-4111-8111-111111111111', 'Món test', 1,
    '[{"inventory_item_id":"44444444-4444-4444-8444-444444444444","quantity":1}]'::jsonb
  )$$,
  'cooking records the recipe and consumes the confirmed inventory quantity'
);
select is(
  (select quantity from public.inventory_items
   where id = '44444444-4444-4444-8444-444444444444'),
  2::numeric,
  'the inventory quantity decreases by the amount cooked'
);
select is(
  (select count(*)::integer from public.inventory_events
   where inventory_item_id = '44444444-4444-4444-8444-444444444444'
     and event_type = 'consumed'),
  1,
  'cooking records a report event for the consumed food'
);
select throws_ok(
  $$select public.record_recipe_cooked(
    '11111111-1111-4111-8111-111111111111', 'Món vượt kho', 1,
    '[{"inventory_item_id":"44444444-4444-4444-8444-444444444444","quantity":99}]'::jsonb
  )$$,
  '22023',
  'Insufficient inventory quantity',
  'cooking cannot consume more than the available quantity'
);
select is(
  (select count(*)::integer from public.inventory_events
   where inventory_item_id = '44444444-4444-4444-8444-444444444444'
     and event_type = 'consumed'),
  1,
  'a rejected cooking transaction does not create a report event'
);

select throws_ok(
  $$select public.import_receipt(
    '11111111-1111-4111-8111-111111111111', 'Chợ lỗi', now(), 0,
    null, 'OCR test', '[{"normalized_name":"","quantity":1}]'::jsonb
  )$$,
  '22023',
  'Receipt item name is required',
  'receipt import rejects an invalid product name'
);
select is(
  (select count(*)::integer from public.receipts where store_name = 'Chợ lỗi'),
  0,
  'a rejected receipt import leaves no partial receipt'
);
select lives_ok(
  $$select set_config(
    'vineat.test.receipt_id',
    public.import_receipt(
      '11111111-1111-4111-8111-111111111111', 'Chợ test', now(), 42000,
      null, 'Cà chua 2 quả; Sữa 1 hộp',
      '[
        {"raw_name":"Ca chua","normalized_name":"Cà chua scan","quantity":2,"unit":"quả","unit_price_vnd":12000,"total_price_vnd":24000,"estimated_expiry_date":"2026-10-05","confidence":0.95,"selected_for_import":true},
        {"raw_name":"Sua","normalized_name":"Sữa bỏ chọn","quantity":1,"unit":"hộp","unit_price_vnd":18000,"total_price_vnd":18000,"confidence":0.8,"selected_for_import":false}
      ]'::jsonb
    )::text,
    true
  )$$,
  'a confirmed receipt imports transactionally'
);
select is(
  (select count(*)::integer from public.receipts
   where id = current_setting('vineat.test.receipt_id')::uuid),
  1,
  'receipt metadata is saved'
);
select is(
  (select count(*)::integer from public.receipt_items
   where receipt_id = current_setting('vineat.test.receipt_id')::uuid),
  2,
  'both selected and unselected OCR lines are preserved for review'
);
select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '11111111-1111-4111-8111-111111111111'
     and name = 'Cà chua scan' and quantity = 2),
  1,
  'only the confirmed receipt line is added to inventory'
);
select is(
  (select count(*)::integer from public.receipt_items
   where receipt_id = current_setting('vineat.test.receipt_id')::uuid
     and not selected_for_import and inventory_item_id is null),
  1,
  'an unselected receipt line is not added to inventory'
);
select is(
  (select count(*)::integer from public.inventory_events
   where event_type = 'added'
     and metadata->>'source' = 'receipt'
     and metadata->>'receipt_id' = current_setting('vineat.test.receipt_id')),
  1,
  'receipt imports create auditable inventory history'
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
  'permission denied for table recipe_cook_events',
  'cooking history is written only by its transactional RPC'
);

select throws_ok(
  $$insert into public.receipts (household_id, created_by)
    values ('11111111-1111-4111-8111-111111111111', auth.uid())$$,
  '42501',
  'permission denied for table receipts',
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
  2,
  'the second household member sees shared inventory and confirmed receipt items'
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

select throws_ok(
  $$select public.import_demo_inventory(
    '22222222-2222-4222-8222-222222222222', 'local-demo-v1',
    '[{"name":"Món không hợp lệ","quantity":0}]'::jsonb
  )$$,
  '22023',
  'Invalid demo inventory item',
  'an invalid demo import is rejected before completion'
);
select is(
  public.import_demo_inventory(
    '22222222-2222-4222-8222-222222222222', 'local-demo-v1',
    '[{"name":"Cà rốt demo","quantity":2,"unit":"củ","price_vnd":4000},{"name":"Đậu demo","quantity":1,"unit":"gói","price_vnd":12000}]'::jsonb
  ),
  2,
  'a family can explicitly import its demo inventory once'
);
select is(
  public.import_demo_inventory(
    '22222222-2222-4222-8222-222222222222', 'local-demo-v1', '[]'::jsonb
  ),
  0,
  'repeating the demo import does not add inventory again'
);
select is(
  (select count(*)::integer from public.inventory_items
   where household_id = '22222222-2222-4222-8222-222222222222'),
  2,
  'an invalid attempt does not consume the one-time import marker'
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

select is(
  (select count(*)::integer from storage.objects
   where id = '66666666-6666-4666-8666-666666666666'),
  0,
  'an unrelated household cannot read another family photo'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values (
      'household-food',
      '11111111-1111-4111-8111-111111111111/photos/forbidden.png',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      '{"mimetype":"image/png","size":64}'::jsonb
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'an unrelated household cannot upload into another family folder'
);
select throws_ok(
  $$select public.import_demo_inventory(
    '22222222-2222-4222-8222-222222222222', 'local-demo-v1', '[]'::jsonb
  )$$,
  '42501',
  'Household membership required',
  'an unrelated household cannot import data into another family'
);
select throws_ok(
  $$select public.import_receipt(
    '11111111-1111-4111-8111-111111111111', 'Chợ trái phép', now(), 0,
    null, null, '[]'::jsonb
  )$$,
  '42501',
  'Household membership required',
  'an unrelated household cannot add a receipt to another family'
);
select throws_ok(
  $$select public.record_recipe_cooked(
    '11111111-1111-4111-8111-111111111111', 'Món trái phép', 1, '[]'::jsonb
  )$$,
  '42501',
  'Household membership required',
  'an unrelated household cannot record cooking in another family'
);

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
