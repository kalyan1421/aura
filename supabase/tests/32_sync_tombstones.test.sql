-- Delta-pull tombstones (migration 20261005000032, PRD 16 sync model): every server delete of a check-in, habit or
-- habit log leaves an id-only tombstone the owner (only) can read; clients can't write them; deleting the account
-- leaves none behind; a record that comes back clears its tombstone.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

insert into auth.users (id, email, aud, role) values
  ('32aaaaaa-0000-4000-8000-00000000000a', 'pgtap-tomb-a@aura.test', 'authenticated', 'authenticated'),
  ('32bbbbbb-0000-4000-8000-00000000000b', 'pgtap-tomb-b@aura.test', 'authenticated', 'authenticated');
insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts) values
  ('32aaaaaa-c000-7000-8000-000000000001', '32aaaaaa-0000-4000-8000-00000000000a', 'anxious', 'storm', '2026-10-08', '2026-10-08T10:00:00Z'),
  ('32bbbbbb-c000-7000-8000-000000000001', '32bbbbbb-0000-4000-8000-00000000000b', 'calm', 'moonlight', '2026-10-08', '2026-10-08T10:00:00Z');
insert into public.habits (id, user_id, kind, preset_key) values
  ('32aaaaaa-4000-7000-8000-000000000001', '32aaaaaa-0000-4000-8000-00000000000a', 'preset', 'hydrate');
insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts) values
  ('32aaaaaa-1000-7000-8000-000000000001', '32aaaaaa-0000-4000-8000-00000000000a', '32aaaaaa-4000-7000-8000-000000000001', '2026-10-08', '2026-10-08T10:05:00Z');

select ok((select relrowsecurity from pg_class where oid = 'public.sync_tombstones'::regclass), 'RLS is on');

-- A delete leaves an id-only tombstone.
delete from public.check_ins where id = '32aaaaaa-c000-7000-8000-000000000001';
select results_eq(
  $$ select entity, entity_id::text from public.sync_tombstones where user_id = '32aaaaaa-0000-4000-8000-00000000000a' $$,
  $$ values ('check_in', '32aaaaaa-c000-7000-8000-000000000001') $$,
  'deleting a check-in leaves its tombstone');

-- A habit's delete cascades to its logs: both leave tombstones.
delete from public.habits where id = '32aaaaaa-4000-7000-8000-000000000001';
select is(
  (select array_agg(entity order by entity) from public.sync_tombstones where user_id = '32aaaaaa-0000-4000-8000-00000000000a'),
  array['check_in','habit','habit_log'],
  'a habit and its cascaded logs leave tombstones');

-- A record that comes back clears its tombstone.
insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts) values
  ('32aaaaaa-c000-7000-8000-000000000001', '32aaaaaa-0000-4000-8000-00000000000a', 'anxious', 'storm', '2026-10-08', '2026-10-08T10:00:00Z');
select is(
  (select count(*)::int from public.sync_tombstones where entity = 'check_in' and entity_id = '32aaaaaa-c000-7000-8000-000000000001'),
  0, 'a re-inserted record has no tombstone');

-- Clients: own tombstones readable, never writable; nobody else's.
delete from public.check_ins where id = '32bbbbbb-c000-7000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"32aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.sync_tombstones), 2, 'A reads only A''s tombstones');
select throws_ok(
  $$ insert into public.sync_tombstones (user_id, entity, entity_id) values ('32aaaaaa-0000-4000-8000-00000000000a', 'check_in', gen_random_uuid()) $$,
  '42501', null, 'clients cannot insert');
select throws_ok($$ delete from public.sync_tombstones $$, '42501', null, 'clients cannot delete');
select throws_ok($$ update public.sync_tombstones set deleted_at = now() $$, '42501', null, 'clients cannot update');
reset role;
set local role anon;
select throws_ok($$ select count(*) from public.sync_tombstones $$, '42501', null, 'anon cannot read');
reset role;

select ok(
  not has_function_privilege('authenticated', 'public.sync_tombstone_record()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.sync_tombstone_record()', 'EXECUTE'),
  'the trigger function is not client-callable');

-- Deleting the account: its rows cascade, no tombstone is written for it, nothing is left.
delete from auth.users where id = '32bbbbbb-0000-4000-8000-00000000000b';
select is(
  (select count(*)::int from public.sync_tombstones where user_id = '32bbbbbb-0000-4000-8000-00000000000b'),
  0, 'deleting the auth user leaves no tombstones (and does not fail)');
select lives_ok(
  $$ delete from auth.users where id = '32aaaaaa-0000-4000-8000-00000000000a' $$,
  'an account with check-ins, habits and logs deletes cleanly');

select * from finish();
rollback;
