-- Account deletion (F8 REQ-ACC-11): `account_deletions` is server-only — RLS on, no policies, and no
-- client privileges at all, so anon/authenticated get 42501 for every verb (even on their own row).
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- ---------- Shape ----------
select has_table('public', 'account_deletions', 'public.account_deletions exists');
select columns_are('public', 'account_deletions', array['user_id', 'requested_at', 'scheduled_for'],
  'account_deletions has exactly user_id, requested_at, scheduled_for');
select col_is_pk('public', 'account_deletions', 'user_id', 'user_id is the primary key (one schedule per account)');
select col_not_null('public', 'account_deletions', 'scheduled_for', 'scheduled_for is required');
select col_has_default('public', 'account_deletions', 'requested_at', 'requested_at defaults to now()');
select has_index('public', 'account_deletions', 'account_deletions_scheduled_for_idx', 'purge index on scheduled_for');
select results_eq(
  $$ select confrelid::regclass::text, confdeltype::text from pg_constraint
      where conrelid = 'public.account_deletions'::regclass and contype = 'f' $$,
  $$ values ('auth.users', 'c') $$,
  'user_id references auth.users on delete cascade (the purge removes it with the auth user)'
);

-- ---------- RLS / privileges ----------
select ok((select relrowsecurity from pg_class where oid = 'public.account_deletions'::regclass),
  'RLS enabled on public.account_deletions');
select is_empty(
  $$ select policyname from pg_policies where schemaname = 'public' and tablename = 'account_deletions' $$,
  'no client policies on account_deletions'
);
select ok(
  not has_table_privilege('anon', 'public.account_deletions', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('authenticated', 'public.account_deletions', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'anon / authenticated hold no privilege on account_deletions'
);

-- A user with a scheduled deletion (written as postgres, like NestJS does).
insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-0000000007aa', 'pgtap-del@aura.test', 'authenticated', 'authenticated');
insert into public.account_deletions (user_id, scheduled_for)
values ('0aaaaaaa-0000-4000-8000-0000000007aa', now() + interval '7 days');

select throws_ok(
  $$ insert into public.account_deletions (user_id, requested_at, scheduled_for)
     values ('0aaaaaaa-0000-4000-8000-0000000007aa', now(), now() + interval '1 day') $$,
  '23505', null, 'one row per account'
);

-- ---------- authenticated (the row's own user) ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-0000000007aa","role":"authenticated","aud":"authenticated"}', true);

select throws_ok($$ select * from public.account_deletions $$,
  '42501', 'permission denied for table account_deletions', 'authenticated cannot SELECT (not even own row)');
select throws_ok(
  $$ insert into public.account_deletions (user_id, scheduled_for) values (auth.uid(), now()) $$,
  '42501', 'permission denied for table account_deletions', 'authenticated cannot INSERT');
select throws_ok($$ update public.account_deletions set scheduled_for = now() $$,
  '42501', 'permission denied for table account_deletions', 'authenticated cannot UPDATE (cannot move the date)');
select throws_ok($$ delete from public.account_deletions $$,
  '42501', 'permission denied for table account_deletions', 'authenticated cannot DELETE (cancel goes through NestJS)');
select throws_ok($$ truncate public.account_deletions $$,
  '42501', 'permission denied for table account_deletions', 'authenticated cannot TRUNCATE');

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok($$ select * from public.account_deletions $$,
  '42501', 'permission denied for table account_deletions', 'anon cannot SELECT');
select throws_ok(
  $$ insert into public.account_deletions (user_id, scheduled_for) values ('0aaaaaaa-0000-4000-8000-0000000007aa', now()) $$,
  '42501', 'permission denied for table account_deletions', 'anon cannot INSERT');
select throws_ok($$ update public.account_deletions set scheduled_for = now() $$,
  '42501', 'permission denied for table account_deletions', 'anon cannot UPDATE');
select throws_ok($$ delete from public.account_deletions $$,
  '42501', 'permission denied for table account_deletions', 'anon cannot DELETE');

-- ---------- the purge's final step (as postgres) removes the row with the auth user ----------
reset role;
select is((select count(*)::int from public.account_deletions where user_id = '0aaaaaaa-0000-4000-8000-0000000007aa'), 1,
  'the schedule is still there after all client attempts');
delete from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000007aa';
select is((select count(*)::int from public.account_deletions where user_id = '0aaaaaaa-0000-4000-8000-0000000007aa'), 0,
  'deleting the auth user leaves no account_deletions tombstone');

select * from finish();
rollback;
