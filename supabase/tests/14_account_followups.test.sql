-- Account & safety follow-ups (migration 20261005000014, contracts/api/v1.md):
--   * apple_auth_tokens / minor_signals / moderation_audit_anchor are server-only (RLS on, no policies, 42501 for clients);
--   * user_is_minor = under 18 by DOB OR an unexpired platform signal (REQ-ACC-04/10), still server-only;
--   * retention settings: audit log 3 years, closed reports kept (NULL) until AK / the lawyer decide;
--   * moderation_actions stays append-only for every role; only prune_moderation_actions() removes rows, only past
--     the retention, only a prefix (never the newest row), and the anchor keeps the remaining chain verifiable.
begin;
create extension if not exists pgtap with schema extensions;

select plan(58);

-- ---------------------------------------------------------------- shape
select has_table('public', t, format('public.%s exists', t))
from unnest(array['apple_auth_tokens', 'minor_signals', 'moderation_audit_anchor']) t;
select columns_are('public', 'apple_auth_tokens',
  array['user_id', 'client_id', 'wrapped_refresh_token', 'created_at', 'updated_at'],
  'apple_auth_tokens: the sealed token and its Apple client, nothing else');
select columns_are('public', 'minor_signals', array['user_id', 'minor_until', 'updated_at'],
  'minor_signals: a date, never the signal or an age');
select col_is_pk('public', 'apple_auth_tokens', 'user_id', 'one Apple token per account');
select col_is_pk('public', 'minor_signals', 'user_id', 'one signal row per account');
select results_eq(
  $$ select conrelid::regclass::text, confrelid::regclass::text, confdeltype::text from pg_constraint
      where conrelid in ('public.apple_auth_tokens'::regclass, 'public.minor_signals'::regclass) and contype = 'f'
      order by 1 $$,
  $$ values ('apple_auth_tokens', 'auth.users', 'c'), ('minor_signals', 'auth.users', 'c') $$,
  'both reference auth.users on delete cascade (nothing survives the purge)'
);

-- ---------------------------------------------------------------- server-only
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.apple_auth_tokens', 'public.minor_signals', 'public.moderation_audit_anchor']::regclass[])),
  'RLS enabled on the new tables');
select is_empty(
  $$ select tablename from pg_policies where schemaname = 'public'
      and tablename in ('apple_auth_tokens', 'minor_signals', 'moderation_audit_anchor') $$,
  'no client policies on the new tables'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['apple_auth_tokens', 'minor_signals', 'moderation_audit_anchor']) t
cross join unnest(array['anon', 'authenticated']) r;
select ok(not has_table_privilege('service_role', 'public.moderation_audit_anchor', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role cannot move the audit anchor');

insert into auth.users (id, email, aud, role) values
  ('14aaaaaa-0000-4000-8000-00000000000a', 'pgtap-fu-adult-signal@aura.test', 'authenticated', 'authenticated'),
  ('14bbbbbb-0000-4000-8000-00000000000b', 'pgtap-fu-adult-expired@aura.test', 'authenticated', 'authenticated'),
  ('14cccccc-0000-4000-8000-00000000000c', 'pgtap-fu-minor@aura.test', 'authenticated', 'authenticated'),
  ('14dddddd-0000-4000-8000-00000000000d', 'pgtap-fu-noprofile@aura.test', 'authenticated', 'authenticated'),
  ('14eeeeee-0000-4000-8000-00000000000e', 'pgtap-fu-adult@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
  ('14aaaaaa-0000-4000-8000-00000000000a', (current_date - interval '30 years')::date, 'en', 'en', 'Asia/Kolkata'),
  ('14bbbbbb-0000-4000-8000-00000000000b', (current_date - interval '30 years')::date, 'en', 'en', 'Asia/Kolkata'),
  ('14cccccc-0000-4000-8000-00000000000c', (current_date - interval '16 years')::date, 'te', 'te', 'Asia/Kolkata'),
  ('14eeeeee-0000-4000-8000-00000000000e', (current_date - interval '30 years')::date, 'en', 'en', 'Asia/Kolkata');
insert into public.minor_signals (user_id, minor_until) values
  ('14aaaaaa-0000-4000-8000-00000000000a', (current_date + interval '5 years')::date),
  ('14bbbbbb-0000-4000-8000-00000000000b', current_date),
  ('14dddddd-0000-4000-8000-00000000000d', (current_date + interval '1 day')::date);
insert into public.apple_auth_tokens (user_id, client_id, wrapped_refresh_token) values
  ('14aaaaaa-0000-4000-8000-00000000000a', 'com.akvega.aura', repeat('A', 64));

-- ---------------------------------------------------------------- clients (even the row's own user) get 42501
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"14aaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);
select throws_ok($$ select * from public.apple_auth_tokens $$, '42501', null, 'authenticated cannot read its Apple token');
select throws_ok($$ select * from public.minor_signals $$, '42501', null, 'authenticated cannot read its own signal (invisible flag)');
select throws_ok($$ insert into public.minor_signals (user_id, minor_until) values (auth.uid(), current_date) $$,
  '42501', null, 'authenticated cannot write a signal');
select throws_ok($$ delete from public.apple_auth_tokens $$, '42501', null, 'authenticated cannot delete an Apple token');
select throws_ok($$ select public.user_is_minor(auth.uid()) $$, '42501', null, 'authenticated cannot call user_is_minor');
select throws_ok($$ select public.prune_moderation_actions(10) $$, '42501', null, 'authenticated cannot prune the audit log');
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.minor_signals $$, '42501', null, 'anon cannot read signals');
select throws_ok($$ select public.prune_moderation_actions(10) $$, '42501', null, 'anon cannot prune the audit log');
reset role;
select ok(not has_function_privilege('service_role', 'public.prune_moderation_actions(int)', 'EXECUTE'),
  'service_role cannot prune the audit log (the worker runs it as the owner)');

-- ---------------------------------------------------------------- constraints
select throws_ok(
  $$ insert into public.apple_auth_tokens (user_id, client_id, wrapped_refresh_token)
     values ('14bbbbbb-0000-4000-8000-00000000000b', 'not a client id', repeat('A', 64)) $$,
  '23514', null, 'client_id must look like a bundle / Services id');
select throws_ok(
  $$ insert into public.apple_auth_tokens (user_id, client_id, wrapped_refresh_token)
     values ('14bbbbbb-0000-4000-8000-00000000000b', 'com.akvega.aura', 'short') $$,
  '23514', null, 'a sealed token is never a few characters (no plaintext by mistake)');

-- ---------------------------------------------------------------- user_is_minor: DOB OR unexpired signal
select ok((select prosecdef and proconfig @> array['search_path=public'] from pg_proc
            where oid = 'public.user_is_minor(uuid)'::regprocedure),
  'user_is_minor is still SECURITY DEFINER with a pinned search_path');
select ok(has_function_privilege('service_role', 'public.user_is_minor(uuid)', 'EXECUTE')
          and not has_function_privilege('public', 'public.user_is_minor(uuid)', 'EXECUTE'),
  'user_is_minor keeps its privileges (server roles only)');
select is(public.user_is_minor('14aaaaaa-0000-4000-8000-00000000000a'), true, 'adult DOB + unexpired under-18 signal → minor');
select is(public.user_is_minor('14bbbbbb-0000-4000-8000-00000000000b'), false, 'adult DOB + signal ending today → adult (exclusive end)');
select is(public.user_is_minor('14cccccc-0000-4000-8000-00000000000c'), true, '16 by DOB, no signal → minor');
select is(public.user_is_minor('14dddddd-0000-4000-8000-00000000000d'), true, 'no profile yet + signal → minor');
select is(public.user_is_minor('14eeeeee-0000-4000-8000-00000000000e'), false, 'adult DOB, no signal → adult');
select is(public.user_is_minor(null), false, 'null uid → false');

delete from auth.users where id in ('14aaaaaa-0000-4000-8000-00000000000a', '14dddddd-0000-4000-8000-00000000000d');
select is((select count(*)::int from public.minor_signals
            where user_id in ('14aaaaaa-0000-4000-8000-00000000000a', '14dddddd-0000-4000-8000-00000000000d')), 0,
  'deleting the auth user removes its signal');
select is((select count(*)::int from public.apple_auth_tokens where user_id = '14aaaaaa-0000-4000-8000-00000000000a'), 0,
  'deleting the auth user removes its Apple token');

-- ---------------------------------------------------------------- retention settings
select results_eq(
  $$ select moderation_audit_retention_days, closed_report_retention_days from public.safety_config $$,
  $$ values (1096, null::int) $$,
  'defaults: audit log kept 3 years (1096 days); closed reports kept (NULL, [LEGAL] decision pending)'
);
select throws_ok($$ update public.safety_config set moderation_audit_retention_days = 30 $$, '23514', null,
  'the audit retention can never drop below a year');
select throws_ok($$ update public.safety_config set closed_report_retention_days = 7 $$, '23514', null,
  'a closed-report retention, once chosen, is at least 30 days');

-- ---------------------------------------------------------------- audit pruning
-- Start from an empty log inside this rolled-back transaction: the only place the append-only trigger is lifted.
alter table public.moderation_actions disable trigger moderation_actions_no_update_delete;
delete from public.moderation_actions;
alter table public.moderation_actions enable trigger moderation_actions_no_update_delete;
delete from public.moderation_audit_anchor;

insert into public.moderation_actions (created_at, actor, action) values (now() - interval '5 years', 'system', 'old_one');
insert into public.moderation_actions (created_at, actor, action) values (now() - interval '4 years', 'system', 'old_two');
insert into public.moderation_actions (created_at, actor, action) values (now() - interval '37 months', 'system', 'old_three');
insert into public.moderation_actions (actor, action) values ('staff:pgtap', 'new_one');
insert into public.moderation_actions (actor, action) values ('staff:pgtap', 'new_two');

select throws_ok($$ delete from public.moderation_actions where action = 'old_one' $$, 'AR010', null,
  'a plain DELETE of an old row still fails (only the prune function may remove rows)');
select set_config('aura.moderation_audit_prune', 'on', true);
select throws_ok($$ delete from public.moderation_actions where action = 'new_one' $$, 'AR010', null,
  'with the prune flag set by hand, a row inside the retention still cannot be deleted');
select throws_ok($$ update public.moderation_actions set actor = 'x' where action = 'old_one' $$, 'AR010', null,
  'with the prune flag set by hand, rows still cannot be updated');
select throws_ok($$ truncate public.moderation_actions $$, 'AR010', null, 'truncate still fails');
select set_config('aura.moderation_audit_prune', 'off', true);

select throws_ok($$ select public.prune_moderation_actions(0) $$, '22023', null, 'the batch size is validated');

create temp table fu_chain on commit drop as select id, action, row_hash, prev_hash from public.moderation_actions;

select is(public.prune_moderation_actions(2), 2::bigint, 'prune takes the oldest rows first, one batch at a time');
select results_eq(
  $$ select action from public.moderation_actions order by id $$,
  $$ values ('old_three'), ('new_one'), ('new_two') $$,
  'the two oldest rows are gone, the rest of the chain is untouched'
);
select results_eq(
  $$ select x.last_pruned_id, x.last_pruned_hash, x.pruned_rows from public.moderation_audit_anchor x $$,
  $$ select c.id, c.row_hash, 2::bigint from fu_chain c where c.action = 'old_two' $$,
  'the anchor records the last pruned row'
);
select is(public.prune_moderation_actions(), 1::bigint, 'the next run takes the last row past the retention');
select is(public.prune_moderation_actions(), 0::bigint, 'nothing inside the retention is ever pruned');
select results_eq(
  $$ select action from public.moderation_actions order by id $$,
  $$ values ('new_one'), ('new_two') $$,
  'only rows inside the 3-year retention remain'
);
select results_eq(
  $$ select x.last_pruned_hash, x.pruned_rows from public.moderation_audit_anchor x $$,
  $$ select c.row_hash, 3::bigint from fu_chain c where c.action = 'old_three' $$,
  'the anchor moves with each run and counts every pruned row'
);
select is(
  (select a.prev_hash from public.moderation_actions a order by a.id limit 1),
  (select x.last_pruned_hash from public.moderation_audit_anchor x),
  'the oldest remaining row links to the anchor'
);
-- The same check as src/safety/audit.ts verifyAuditChain (the anchor stands in for the first row's predecessor).
select ok(
  (with anchor as (select last_pruned_hash from public.moderation_audit_anchor where id),
        ordered as (
          select a.*, coalesce(lag(a.row_hash) over (order by a.id), (select last_pruned_hash from anchor)) as expected_prev
            from public.moderation_actions a)
   select bool_and(
            prev_hash is not distinct from expected_prev
            and row_hash = encode(sha256(convert_to(
              coalesce(prev_hash, '') || '|' || id::text || '|' ||
              to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || '|' || actor || '|' || action || '|' ||
              coalesce(report_id::text, '') || '|' || coalesce(subject_hash, '') || '|' || coalesce(reason_code, '') || '|' ||
              detail::text, 'UTF8')), 'hex'))
     from ordered),
  'the pruned chain still verifies end to end'
);

-- Every row past the retention: the newest one stays so the next append can link to it.
alter table public.moderation_actions disable trigger moderation_actions_no_update_delete;
delete from public.moderation_actions;
alter table public.moderation_actions enable trigger moderation_actions_no_update_delete;
insert into public.moderation_actions (created_at, actor, action) values (now() - interval '6 years', 'system', 'old_a');
insert into public.moderation_actions (created_at, actor, action) values (now() - interval '5 years', 'system', 'old_b');
insert into public.moderation_actions (created_at, actor, action) values (now() - interval '4 years', 'system', 'old_c');
select is(public.prune_moderation_actions(), 2::bigint, 'with every row past the retention, all but the newest go');
select results_eq($$ select action from public.moderation_actions $$, $$ values ('old_c') $$,
  'the newest row is never pruned');
insert into public.moderation_actions (actor, action) values ('staff:pgtap', 'after_prune');
select is(
  (select prev_hash from public.moderation_actions where action = 'after_prune'),
  (select row_hash from public.moderation_actions where action = 'old_c'),
  'a new append still links to the chain'
);

select * from finish();
rollback;
