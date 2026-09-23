-- Safety follow-ups (migration 20261005000015, contracts/api/v1-rooms.md §2.1 / §2.4):
--   * report reason 9 "Targeting a young person" is storable; 1–8 keep their meaning; nothing outside 1–9;
--   * `safety_config.guidelines_version` (default 1) is the community guidelines version rooms require;
--   * `guidelines_acceptances` is server-only (RLS on, no policies, 42501 for every client role, even for the row's
--     own user), one row per (account, version), and goes with the profile (so the account purge removes it).
begin;
create extension if not exists pgtap with schema extensions;

select plan(31);

-- ---------------------------------------------------------------- shape
select has_table('public', 'guidelines_acceptances', 'public.guidelines_acceptances exists');
select columns_are('public', 'guidelines_acceptances', array['user_id', 'version', 'accepted_at'],
  'guidelines_acceptances: account, version and when, nothing else');
select col_is_pk('public', 'guidelines_acceptances', array['user_id', 'version'], 'one row per account and version');
select results_eq(
  $$ select confrelid::regclass::text, confdeltype::text from pg_constraint
      where conrelid = 'public.guidelines_acceptances'::regclass and contype = 'f' $$,
  $$ values ('profiles', 'c') $$,
  'references profiles on delete cascade (purged with the profile, in the purge''s first transaction)'
);
select has_column('public', 'safety_config', 'guidelines_version', 'safety_config.guidelines_version exists');
select col_not_null('public', 'safety_config', 'guidelines_version', 'guidelines_version is never null');
select col_default_is('public', 'safety_config', 'guidelines_version', '1', 'the first guidelines version is 1');
select is((select guidelines_version::int from public.safety_config where id), 1, 'the live config asks for version 1');

-- ---------------------------------------------------------------- server-only
select ok((select relrowsecurity from pg_class where oid = 'public.guidelines_acceptances'::regclass),
  'RLS enabled on guidelines_acceptances');
select is_empty(
  $$ select policyname from pg_policies where schemaname = 'public' and tablename = 'guidelines_acceptances' $$,
  'no client policies on guidelines_acceptances'
);
select ok(
  not has_table_privilege(r, 'public.guidelines_acceptances', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on guidelines_acceptances', r)
)
from unnest(array['anon', 'authenticated']) r;

-- ---------------------------------------------------------------- fixtures (as postgres; rolled back)
insert into auth.users (id, email, aud, role) values
  ('15aaaaaa-0000-4000-8000-00000000000a', 'pgtap-gl-a@aura.test', 'authenticated', 'authenticated'),
  ('15bbbbbb-0000-4000-8000-00000000000b', 'pgtap-gl-b@aura.test', 'authenticated', 'authenticated'),
  ('15cccccc-0000-4000-8000-00000000000c', 'pgtap-gl-noprofile@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
  ('15aaaaaa-0000-4000-8000-00000000000a', (current_date - interval '30 years')::date, 'en', 'en', 'Asia/Kolkata'),
  ('15bbbbbb-0000-4000-8000-00000000000b', (current_date - interval '16 years')::date, 'te', 'te', 'Asia/Kolkata');

select lives_ok(
  $$ insert into public.guidelines_acceptances (user_id, version) values
       ('15aaaaaa-0000-4000-8000-00000000000a', 1), ('15aaaaaa-0000-4000-8000-00000000000a', 2),
       ('15bbbbbb-0000-4000-8000-00000000000b', 1) $$,
  'the server records each version an account accepted'
);
select throws_ok(
  $$ insert into public.guidelines_acceptances (user_id, version) values ('15aaaaaa-0000-4000-8000-00000000000a', 1) $$,
  '23505', null, 'the same version twice is one row (the server keeps the first accepted_at)'
);
select throws_ok(
  $$ insert into public.guidelines_acceptances (user_id, version) values ('15aaaaaa-0000-4000-8000-00000000000a', 0) $$,
  '23514', null, 'versions start at 1'
);
select throws_ok(
  $$ insert into public.guidelines_acceptances (user_id, version) values ('15cccccc-0000-4000-8000-00000000000c', 1) $$,
  '23503', null, 'no acceptance without a profile (onboarding first)'
);
select throws_ok($$ update public.safety_config set guidelines_version = 0 where id $$, '23514', null,
  'the required version is at least 1');

-- ---------------------------------------------------------------- report reasons 1–9
select lives_ok(
  $$ insert into public.reports (source, reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('user', '15aaaaaa-0000-4000-8000-00000000000a', 9, 'minors_grooming', 'room', gen_random_uuid(),
             now() + interval '4 hours') $$,
  'reason 9 (targeting a young person) is storable'
);
select lives_ok(
  $$ insert into public.reports (source, reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('user', '15aaaaaa-0000-4000-8000-00000000000a', 8, 'spam', 'room', gen_random_uuid(), now() + interval '1 day') $$,
  'reasons 1–8 keep working (older apps)'
);
select throws_ok(
  $$ insert into public.reports (source, reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('user', '15aaaaaa-0000-4000-8000-00000000000a', 10, 'spam', 'room', gen_random_uuid(), now() + interval '1 day') $$,
  '23514', null, 'reason 10 does not exist'
);
select throws_ok(
  $$ insert into public.reports (source, reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('user', '15aaaaaa-0000-4000-8000-00000000000a', 0, 'spam', 'room', gen_random_uuid(), now() + interval '1 day') $$,
  '23514', null, 'reason 0 does not exist'
);

-- ---------------------------------------------------------------- clients (even the row's own user) get 42501
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"15aaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);
select throws_ok($$ select * from public.guidelines_acceptances $$, '42501', null,
  'authenticated cannot read acceptances, not even its own (GET /v1/safety/me says)');
select throws_ok(
  $$ insert into public.guidelines_acceptances (user_id, version) values (auth.uid(), 3) $$,
  '42501', null, 'authenticated cannot record an acceptance itself (only POST /v1/safety/guidelines/accept)'
);
select throws_ok($$ update public.guidelines_acceptances set version = 5 $$, '42501', null,
  'authenticated cannot change an acceptance');
select throws_ok($$ delete from public.guidelines_acceptances $$, '42501', null, 'authenticated cannot delete an acceptance');
select throws_ok($$ update public.safety_config set guidelines_version = 1 where id $$, '42501', null,
  'authenticated cannot change the required version');
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.guidelines_acceptances $$, '42501', null, 'anon cannot read acceptances');
reset role;

-- ---------------------------------------------------------------- purged with the profile / the account
select is(
  (select count(*)::int from public.guidelines_acceptances where user_id = '15aaaaaa-0000-4000-8000-00000000000a'),
  2, 'two versions on record for A before the purge'
);
delete from public.profiles where user_id = '15aaaaaa-0000-4000-8000-00000000000a'; -- purge step 1 deletes the profile
select is(
  (select count(*)::int from public.guidelines_acceptances where user_id = '15aaaaaa-0000-4000-8000-00000000000a'),
  0, 'deleting the profile removes the account''s acceptances in the same transaction'
);
select is(
  (select count(*)::int from public.guidelines_acceptances where user_id = '15bbbbbb-0000-4000-8000-00000000000b'),
  1, 'other accounts keep theirs'
);
delete from auth.users where id = '15bbbbbb-0000-4000-8000-00000000000b';
select is(
  (select count(*)::int from public.guidelines_acceptances where user_id = '15bbbbbb-0000-4000-8000-00000000000b'),
  0, 'deleting the auth user cascades through the profile'
);

select * from finish();
rollback;
