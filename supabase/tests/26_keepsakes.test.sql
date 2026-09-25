-- F13 keepsakes (migration 20261005000026):
--   * keepsakes: a key and a day only, closed key list, one per (person, key), select-own (RLS), no client writes, no
--     console access, never updated, never deleted while the account lives, gone with the account (purge + cascade);
--   * keepsake_tallies: server-only, a count and a watermark only, personal (cascade);
--   * no public view or function exposes another person's keepsakes (DS-10, CI-8).
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin;

select plan(32);

insert into auth.users (id, email, aud, role) values
  ('26aaaaaa-0000-4000-8000-00000000000a', 'pgtap-keep-a@aura.test', 'authenticated', 'authenticated'),
  ('26bbbbbb-0000-4000-8000-00000000000b', 'pgtap-keep-b@aura.test', 'authenticated', 'authenticated'),
  ('26cccccc-0000-4000-8000-00000000000c', 'pgtap-keep-c@aura.test', 'authenticated', 'authenticated');

-- ---------------------------------------------------------------- shape
select has_table('public', 'keepsakes', 'keepsakes exists');
select columns_are('public', 'keepsakes', array['user_id', 'keepsake_key', 'earned_on'],
  'a key and a day only: no room, pseudonym, capsule or content column');
select col_is_pk('public', 'keepsakes', array['user_id', 'keepsake_key'], 'one row per (person, key)');
select col_type_is('public', 'keepsakes', 'earned_on', 'date', 'the day it was earned (no time of day)');
select has_table('public', 'keepsake_tallies', 'keepsake_tallies exists');
select columns_are('public', 'keepsake_tallies', array['user_id', 'lantern_nights', 'lantern_through', 'updated_at'],
  'tallies hold a count and a watermark, never a room');

select lives_ok(
  $$ insert into public.keepsakes (user_id, keepsake_key, earned_on) values
       ('26aaaaaa-0000-4000-8000-00000000000a', 'capsule_sealed_first', '2026-10-05'),
       ('26aaaaaa-0000-4000-8000-00000000000a', 'glow_days_7', '2026-10-12'),
       ('26aaaaaa-0000-4000-8000-00000000000a', 'sanctuary_minutes_1000', '2026-12-01'),
       ('26bbbbbb-0000-4000-8000-00000000000b', 'lantern_hours_1', '2026-10-08'),
       ('26cccccc-0000-4000-8000-00000000000c', 'ripples_first', '2026-10-09') $$,
  'the server writes keepsakes');
select throws_ok(
  $$ insert into public.keepsakes (user_id, keepsake_key, earned_on)
     values ('26aaaaaa-0000-4000-8000-00000000000a', 'capsule_sealed_first', '2026-11-01') $$,
  '23505', null, 'a keepsake is earned once');
select throws_ok(
  $$ insert into public.keepsakes (user_id, keepsake_key, earned_on)
     values ('26aaaaaa-0000-4000-8000-00000000000a', 'plus_welcome_gift', '2026-11-01') $$,
  '23514', null, 'only catalogue keys (no purchasable or gifted seal exists)');
select throws_ok(
  $$ insert into public.keepsakes (user_id, keepsake_key, earned_on)
     values ('26aaaaaa-0000-4000-8000-00000000000a', 'glow_days_30', null) $$,
  '23502', null, 'every keepsake has its day');

-- ---------------------------------------------------------------- never lost
select throws_ok(
  $$ update public.keepsakes set earned_on = '2026-10-01'
      where user_id = '26aaaaaa-0000-4000-8000-00000000000a' and keepsake_key = 'glow_days_7' $$,
  'AR060', 'keepsakes_are_final', 'a keepsake''s day never changes');
select throws_ok(
  $$ update public.keepsakes set keepsake_key = 'glow_days_365'
      where user_id = '26aaaaaa-0000-4000-8000-00000000000a' and keepsake_key = 'glow_days_7' $$,
  'AR060', 'keepsakes_are_final', 'nor its key');
select throws_ok(
  $$ delete from public.keepsakes where user_id = '26aaaaaa-0000-4000-8000-00000000000a' and keepsake_key = 'capsule_sealed_first' $$,
  'AR060', 'keepsakes_are_never_lost', 'a live account never loses one (deleting the capsule, a refund, a downgrade…)');
insert into public.account_deletions (user_id, requested_at, scheduled_for)
  values ('26aaaaaa-0000-4000-8000-00000000000a', now(), now() + interval '7 days');
select throws_ok(
  $$ delete from public.keepsakes where user_id = '26aaaaaa-0000-4000-8000-00000000000a' $$,
  'AR060', 'keepsakes_are_never_lost', 'not even during the grace period');
update public.account_deletions set requested_at = now() - interval '8 days', scheduled_for = now() - interval '1 day'
 where user_id = '26aaaaaa-0000-4000-8000-00000000000a';
select lives_ok(
  $$ delete from public.keepsakes where user_id = '26aaaaaa-0000-4000-8000-00000000000a' $$,
  'the account purge (deletion due) removes them');
select is((select count(*)::int from public.keepsakes where user_id = '26aaaaaa-0000-4000-8000-00000000000a'), 0,
  'nothing left for the purged account');
-- Re-seed A for the access checks below.
delete from public.account_deletions where user_id = '26aaaaaa-0000-4000-8000-00000000000a';
insert into public.keepsakes (user_id, keepsake_key, earned_on) values
  ('26aaaaaa-0000-4000-8000-00000000000a', 'capsule_sealed_first', '2026-10-05'),
  ('26aaaaaa-0000-4000-8000-00000000000a', 'glow_days_7', '2026-10-12');
insert into public.keepsake_tallies (user_id, lantern_nights, lantern_through) values
  ('26aaaaaa-0000-4000-8000-00000000000a', 3, '2026-10-08T15:30:00Z'),
  ('26cccccc-0000-4000-8000-00000000000c', 1, '2026-10-08T15:30:00Z');
select throws_ok(
  $$ update public.keepsake_tallies set lantern_nights = -1 where user_id = '26aaaaaa-0000-4000-8000-00000000000a' $$,
  '23514', null, 'a tally never goes below zero');

-- ---------------------------------------------------------------- access
select ok((select relrowsecurity from pg_class where oid = 'public.keepsakes'::regclass), 'RLS on keepsakes');
select ok((select relrowsecurity from pg_class where oid = 'public.keepsake_tallies'::regclass), 'RLS on keepsake_tallies');
select is(
  (select array_agg(policyname::text order by policyname) from pg_policies where schemaname = 'public' and tablename = 'keepsakes'),
  array['own_read'],
  'the only policy is the owner''s own read (no member, room or "public" policy)');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"26aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select results_eq(
  $$ select keepsake_key from public.keepsakes order by keepsake_key $$,
  array['capsule_sealed_first', 'glow_days_7'],
  'the owner reads their own keepsakes');
select is((select count(*)::int from public.keepsakes where user_id <> '26aaaaaa-0000-4000-8000-00000000000a'), 0,
  'and never anyone else''s (keepsakes are never visible to strangers)');
select throws_ok(
  $$ insert into public.keepsakes (user_id, keepsake_key, earned_on)
     values ('26aaaaaa-0000-4000-8000-00000000000a', 'glow_days_365', '2026-10-05') $$,
  '42501', null, 'the app cannot grant itself a keepsake (NestJS awards them)');
select throws_ok($$ delete from public.keepsakes $$, '42501', null, 'nor delete one');
select throws_ok($$ select * from public.keepsake_tallies $$, '42501', null, 'keepsake_tallies: server-only');
select set_config('request.jwt.claims', '{"sub":"26bbbbbb-0000-4000-8000-00000000000b","role":"authenticated"}', true);
select results_eq(
  $$ select keepsake_key from public.keepsakes $$,
  array['lantern_hours_1'],
  'another person sees only their own');
reset role;
set local role anon;
select throws_ok($$ select * from public.keepsakes $$, '42501', null, 'anon cannot read keepsakes');
reset role;
select ok(
  not has_table_privilege('aura_admin', 'public.keepsakes', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('aura_admin', 'public.keepsake_tallies', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'the console role reaches neither table');
select is_empty(
  $$ select v.table_name from information_schema.view_table_usage v
      where v.table_schema = 'public' and v.table_name in ('keepsakes', 'keepsake_tallies') $$,
  'no view reads keepsakes (nothing can re-expose them to others)');
select is_empty(
  $$ select p.proname from pg_proc p
      where p.pronamespace = 'public'::regnamespace and p.proname <> 'keepsakes_never_lost'
        and p.prosrc ilike '%keepsake%' $$,
  'no public function reads keepsakes');

-- ---------------------------------------------------------------- cascade with the account
delete from auth.users where id = '26cccccc-0000-4000-8000-00000000000c';
select is((select count(*)::int from public.keepsakes where user_id = '26cccccc-0000-4000-8000-00000000000c'), 0,
  'deleting the auth user cascades keepsakes (the never-lost guard lets the account go)');
select is((select count(*)::int from public.keepsake_tallies where user_id = '26cccccc-0000-4000-8000-00000000000c'), 0,
  'and its tally');

select * from finish();
rollback;
