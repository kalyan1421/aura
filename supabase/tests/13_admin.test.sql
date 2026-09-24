-- Admin console v0 (migration 20261005000013; PRD 19-admin-console):
--   * every admin table is server-only: RLS on, no policies, no client privileges;
--   * `aura_admin` reaches only the moderation + admin tables, column-scoped (no reporter, no account behind a
--     pseudonym, nothing private: REQ-ADM-03), can append to but never rewrite the audit log (REQ-ADM-08), can't edit
--     the allowlist, evidence, reports or sanctions directly (actions go through ModerationService);
--   * allowlist changes are audited by trigger; statutory-clock and pager shapes are enforced by the schema.
begin;
create extension if not exists pgtap with schema extensions;

select plan(96);

-- pgTAP lives in `extensions`; let aura_admin call it for the role-switched assertions below (rolled back at the end,
-- so the real grants are what the other assertions see).
grant usage on schema extensions to aura_admin;

-- ---------------------------------------------------------------- shape
select has_table('public', t, format('public.%s exists', t))
from unnest(array['admin_staff','admin_grievances','admin_legal_orders','admin_pages','admin_page_deliveries',
                  'admin_mandatory_checklists']) t;
select has_role('aura_admin', 'aura_admin role exists');
select ok((select not rolcanlogin and rolbypassrls from pg_roles where rolname = 'aura_admin'),
  'aura_admin: no login; bypasses RLS (its grants are the boundary)');
select ok(pg_has_role('postgres', 'aura_admin', 'SET'), 'the API role (postgres) can SET ROLE aura_admin');
select ok(not pg_has_role('postgres', 'aura_admin', 'USAGE'), '... and does not inherit it');
select ok(not pg_has_role(r, 'aura_admin', 'MEMBER'), format('%s cannot become aura_admin', r))
from unnest(array['anon','authenticated','service_role','authenticator']) r;
select is(
  (select array_agg(column_name::text order by column_name::text) from information_schema.columns
    where table_schema = 'public' and table_name like 'admin\_%' and column_name = 'user_id'),
  null,
  'no admin table has a user_id column (nothing for the account purge; staff are separate accounts)'
);

-- ---------------------------------------------------------------- server-only: RLS, no policies, no client privileges
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.admin_staff','public.admin_grievances','public.admin_legal_orders','public.admin_pages',
  'public.admin_page_deliveries','public.admin_mandatory_checklists']::regclass[])), 'RLS enabled on every admin table');
select is_empty(
  $$ select tablename from pg_policies where schemaname = 'public' and tablename like 'admin\_%' $$,
  'no policies on any admin table'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['admin_staff','admin_grievances','admin_legal_orders','admin_pages','admin_page_deliveries',
                  'admin_mandatory_checklists']) t
cross join unnest(array['anon','authenticated']) r;
select ok(not has_function_privilege(r, 'public.admin_account_age_days(uuid)', 'EXECUTE'),
  format('%s cannot call admin_account_age_days', r))
from unnest(array['anon','authenticated']) r;
select ok(not has_function_privilege('authenticated', 'public.admin_staff_audit()', 'EXECUTE'),
  'the allowlist audit trigger function is not callable by clients');

-- ---------------------------------------------------------------- REQ-ADM-03: aura_admin reaches nothing private
select is_empty(
  $$ select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r','p','v','m')
        and c.relname not in ('reports','rooms','room_members','room_gestures','evidence_holds','sanctions','strikes',
                              'safety_config','matching_config','moderation_actions','feature_flags',
                              'admin_staff','admin_grievances','admin_legal_orders','admin_pages',
                              'admin_page_deliveries','admin_mandatory_checklists',
                              'reflections','reflection_config') -- F6: column-scoped review reads (18_reflections)
        and (has_table_privilege('aura_admin', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
             or has_any_column_privilege('aura_admin', c.oid, 'SELECT, INSERT, UPDATE, REFERENCES')) $$,
  'aura_admin has no privilege on any other public table (check-ins, notes, habits, capsules, keys, ledgers, profiles …)'
);
select ok(not has_schema_privilege('aura_admin', 'auth', 'USAGE'), 'aura_admin has no usage on the auth schema (no email, phone)');
select ok(not has_column_privilege('aura_admin', 'public.profiles', 'birth_date', 'SELECT'), 'aura_admin cannot read birth_date');
select ok(has_column_privilege('aura_admin', 'public.reports', 'target_user_id', 'SELECT')
          and not has_column_privilege('aura_admin', 'public.reports', 'reporter_user_id', 'SELECT'),
  'reports: the subject is reachable (hashed by NestJS), the reporter never is');
select ok(has_column_privilege('aura_admin', 'public.room_members', 'pseudonym', 'SELECT')
          and not has_column_privilege('aura_admin', 'public.room_members', 'user_id', 'SELECT'),
  'room_members: pseudonyms yes, the account behind them no');
select ok(has_function_privilege('aura_admin', 'public.user_is_minor(uuid)', 'EXECUTE')
          and has_function_privilege('aura_admin', 'public.admin_account_age_days(uuid)', 'EXECUTE'),
  'aura_admin: the "Under 18" flag (a boolean) and account age');
select ok(not has_function_privilege('aura_admin', 'public.realtime_topic_allowed(text)', 'EXECUTE'),
  'aura_admin cannot call the realtime authorisation function');

set local role aura_admin;
select throws_ok($$ select 1 from public.check_ins limit 1 $$, '42501', null, 'aura_admin: check_ins → permission denied');
select throws_ok($$ select 1 from public.capsules limit 1 $$, '42501', null, 'aura_admin: capsules → permission denied');
select throws_ok($$ select 1 from public.habits limit 1 $$, '42501', null, 'aura_admin: habits → permission denied');
select throws_ok($$ select 1 from public.habit_logs limit 1 $$, '42501', null, 'aura_admin: habit_logs → permission denied');
select throws_ok($$ select birth_date from public.profiles limit 1 $$, '42501', null, 'aura_admin: birth_date → permission denied');
select throws_ok($$ select 1 from public.user_data_keys limit 1 $$, '42501', null, 'aura_admin: wrapped data keys → permission denied');
select throws_ok($$ select email from auth.users limit 1 $$, '42501', null, 'aura_admin: auth.users → permission denied');
select throws_ok($$ select reporter_user_id from public.reports limit 1 $$, '42501', null, 'aura_admin: reporter identity → permission denied');
select throws_ok($$ select user_id from public.room_members limit 1 $$, '42501', null, 'aura_admin: account behind a pseudonym → permission denied');
reset role;

-- ---------------------------------------------------------------- fixtures (as postgres)
insert into auth.users (id, email, aud, role, created_at) values
  ('13aaaaaa-0000-4000-8000-00000000000a', 'pgtap-admin-subject@aura.test', 'authenticated', 'authenticated', now() - interval '40 days'),
  ('13bbbbbb-0000-4000-8000-00000000000b', 'pgtap-admin-reporter@aura.test', 'authenticated', 'authenticated', now()),
  ('13cccccc-0000-4000-8000-00000000000c', 'pgtap-admin-staff@aura.test', 'authenticated', 'authenticated', now());
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at) values
  ('13000000-0000-4000-8000-0000000000a1', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary',
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage) values
  ('1300000a-0000-4000-8000-0000000000a1', '13000000-0000-4000-8000-0000000000a1', '13aaaaaa-0000-4000-8000-00000000000a', 'Quiet Comet', 'lonely', 'rain', 'en', 'south_asia', 4, 'spark'),
  ('1300000b-0000-4000-8000-0000000000a1', '13000000-0000-4000-8000-0000000000a1', '13bbbbbb-0000-4000-8000-00000000000b', 'Gentle Moon', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark');
insert into public.evidence_holds (id, report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until) values
  ('13e00000-0000-4000-8000-0000000000e1', '13d00000-0000-4000-8000-0000000000d1', 'member', '1300000a-0000-4000-8000-0000000000a1',
   'minors_grooming:contact_info', array['13aaaaaa-0000-4000-8000-00000000000a']::uuid[], '{}'::jsonb, now() + interval '180 days');
insert into public.reports (id, reporter_user_id, reporter_member_id, reason, lane, involves_minor, pages, target_kind, room_id,
                            target_member_id, target_user_id, target_ref, sla_due_at, evidence_hold_id) values
  ('13d00000-0000-4000-8000-0000000000d1', '13bbbbbb-0000-4000-8000-00000000000b', '1300000b-0000-4000-8000-0000000000a1', 5,
   'minors_grooming', true, true, 'member', '13000000-0000-4000-8000-0000000000a1', '1300000a-0000-4000-8000-0000000000a1',
   '13aaaaaa-0000-4000-8000-00000000000a', '1300000a-0000-4000-8000-0000000000a1', now() + interval '2 hours',
   '13e00000-0000-4000-8000-0000000000e1');

-- ---------------------------------------------------------------- what aura_admin CAN do
set local role aura_admin;
select is((select count(*)::int from public.reports where id = '13d00000-0000-4000-8000-0000000000d1'), 1,
  'aura_admin reads the queue (server-only table, no policy needed)');
select is((select pseudonym from public.room_members where member_id = '1300000a-0000-4000-8000-0000000000a1'), 'Quiet Comet',
  'aura_admin reads the subject''s room pseudonym');
select is(public.admin_account_age_days('13aaaaaa-0000-4000-8000-00000000000a'), 40, 'account age in days, without the auth schema');
select is(public.user_is_minor('13aaaaaa-0000-4000-8000-00000000000a'), false, 'the Under-18 flag is a boolean (no profile → false)');
select lives_ok(
  $$ insert into public.moderation_actions (actor, action, reason_code, detail) values ('staff:pgtap', 'pgtap_probe', 'pgtap', '{}') $$,
  'aura_admin appends to the audit log');
select ok((select row_hash ~ '^[0-9a-f]{64}$' from public.moderation_actions where action = 'pgtap_probe' order by id desc limit 1),
  'the hash chain links rows appended as aura_admin');
-- REQ-ADM-08
select throws_ok($$ update public.moderation_actions set actor = 'x' $$, '42501', null, 'aura_admin cannot update the audit log');
select throws_ok($$ delete from public.moderation_actions $$, '42501', null, 'aura_admin cannot delete audit rows');
select throws_ok($$ truncate public.moderation_actions $$, '42501', null, 'aura_admin cannot truncate the audit log');
-- Actions go through ModerationService (service role), never direct writes from the console role.
select throws_ok($$ update public.reports set status = 'dismissed', resolved_at = now() $$, '42501', null,
  'aura_admin cannot close reports directly');
select throws_ok(
  $$ insert into public.sanctions (user_id, kind, reason_code, source) values ('13aaaaaa-0000-4000-8000-00000000000a', 'account_ban', 'x', 'moderator') $$,
  '42501', null, 'aura_admin cannot write sanctions directly');
select throws_ok($$ update public.evidence_holds set hold_until = now() + interval '1 day' $$, '42501', null,
  'aura_admin cannot shorten or edit evidence holds');
select throws_ok($$ delete from public.evidence_holds $$, '42501', null, 'aura_admin cannot delete evidence');
-- Kill switches: flip existing flags only.
select lives_ok($$ update public.feature_flags set enabled = enabled where key = 'rooms_pool_hi' $$, 'aura_admin flips a feature flag');
select throws_ok($$ insert into public.feature_flags (key) values ('pgtap_flag') $$, '42501', null, 'aura_admin cannot create flags');
select throws_ok($$ update public.feature_flags set payload = '{}'::jsonb $$, '42501', null, 'aura_admin cannot rewrite flag payloads');
select throws_ok($$ delete from public.feature_flags where key = 'rooms_pool_hi' $$, '42501', null, 'aura_admin cannot delete flags');
select throws_ok($$ update public.matching_config set room_capacity = 2 $$, '42501', null, 'aura_admin cannot edit matching_config');
-- The allowlist is not the console's to edit.
select throws_ok(
  $$ insert into public.admin_staff (staff_id, role, display_name) values ('13bbbbbb-0000-4000-8000-00000000000b', 'owner', 'Me') $$,
  '42501', null, 'aura_admin cannot add staff');
select throws_ok($$ update public.admin_staff set role = 'owner' $$, '42501', null, 'aura_admin cannot change roles');
reset role;

-- ---------------------------------------------------------------- allowlist changes are audited (whoever makes them)
insert into public.admin_staff (staff_id, role, display_name) values ('13cccccc-0000-4000-8000-00000000000c', 'moderator', 'PgTap');
select is(
  (select count(*)::int from public.moderation_actions
    where action = 'staff_granted' and reason_code = 'staff_allowlist' and detail->>'staffId' = '13cccccc-0000-4000-8000-00000000000c'
      and detail->>'role' = 'moderator' and actor like 'db:%'),
  1, 'granting console access writes an audit row');
update public.admin_staff set role = 'owner' where staff_id = '13cccccc-0000-4000-8000-00000000000c';
update public.admin_staff set disabled_at = now() where staff_id = '13cccccc-0000-4000-8000-00000000000c';
delete from public.admin_staff where staff_id = '13cccccc-0000-4000-8000-00000000000c';
select results_eq(
  $$ select action from public.moderation_actions
      where reason_code = 'staff_allowlist' and detail->>'staffId' = '13cccccc-0000-4000-8000-00000000000c' order by id $$,
  $$ values ('staff_granted'), ('staff_changed'), ('staff_disabled'), ('staff_removed') $$,
  'role change, disable and removal are audited too');
select throws_ok(
  $$ insert into public.admin_staff (staff_id, role, display_name) values ('13cccccc-0000-4000-8000-00000000000c', 'superuser', 'X') $$,
  '23514', null, 'roles are owner / moderator / analyst');
-- A role that may remove staff but cannot write the audit log itself (like GoTrue's supabase_auth_admin when an auth
-- user is deleted and the FK cascades) must still succeed, and still leave the audit row: the trigger is a definer.
select ok((select prosecdef and proconfig = array['search_path=""'] from pg_proc where oid = 'public.admin_staff_audit()'::regprocedure),
  'the allowlist audit trigger runs as definer with a pinned search_path');
insert into public.admin_staff (staff_id, role, display_name) values ('13cccccc-0000-4000-8000-00000000000c', 'analyst', 'PgTap');
create role pgtap_staff_remover nologin;
grant select, delete on public.admin_staff to pgtap_staff_remover;
grant usage on schema extensions to pgtap_staff_remover;
grant pgtap_staff_remover to postgres;
set local role pgtap_staff_remover;
select lives_ok($$ delete from public.admin_staff where staff_id = '13cccccc-0000-4000-8000-00000000000c' $$,
  'removing staff works for a role without audit-log privileges (e.g. an auth-user deletion cascade)');
reset role;
select is((select actor from public.moderation_actions where action = 'staff_removed'
             and detail->>'staffId' = '13cccccc-0000-4000-8000-00000000000c' order by id desc limit 1),
  'db:postgres', '... and the audit row names the session user');

-- ---------------------------------------------------------------- grievances (IT Rules clocks)
set local role aura_admin;
select lives_ok(
  $$ insert into public.admin_grievances (ticket, channel, category, complainant_email, description, ack_due_at, resolve_due_at, pages, created_by)
     values ('GRV-7K3F9Q2M', 'email', 'nudity_csam', 'person@example.com', 'text', now() + interval '24 hours', now() + interval '2 hours', true, 'staff:pgtap') $$,
  'aura_admin (Owner, via the console) records an emailed grievance');
select throws_ok(
  $$ insert into public.admin_grievances (ticket, channel, category, complainant_email, description, ack_due_at, resolve_due_at, created_by)
     values ('GRV-ILOU0000', 'email', 'general', 'person@example.com', 'text', now() + interval '24 hours', now() + interval '7 days', 'x') $$,
  '23514', null, 'tickets use Crockford base32 (no I, L, O, U)');
select throws_ok(
  $$ insert into public.admin_grievances (ticket, channel, category, complainant_email, description, ack_due_at, resolve_due_at, created_by)
     values ('GRV-00000001', 'email', 'gossip', 'person@example.com', 'text', now() + interval '24 hours', now() + interval '7 days', 'x') $$,
  '23514', null, 'unknown grievance category rejected');
select throws_ok(
  $$ insert into public.admin_grievances (ticket, channel, category, complainant_email, description, ack_due_at, resolve_due_at, created_by)
     values ('GRV-00000002', 'email', 'general', 'not-an-email', 'text', now() + interval '24 hours', now() + interval '7 days', 'x') $$,
  '23514', null, 'the complainant email must look like one');
select throws_ok(
  $$ update public.admin_grievances set status = 'resolved', resolved_at = now() where ticket = 'GRV-7K3F9Q2M' $$,
  '23514', null, 'a grievance cannot be resolved without an outcome');
select lives_ok(
  $$ update public.admin_grievances set status = 'resolved', resolved_at = now(), outcome = 'action_taken', reply = 'Removed.'
      where ticket = 'GRV-7K3F9Q2M' $$,
  'resolved with an outcome and a reply');
select throws_ok($$ delete from public.admin_grievances $$, '42501', null, 'grievances cannot be deleted from the console');

-- ---------------------------------------------------------------- legal orders (3 h)
select lives_ok(
  $$ insert into public.admin_legal_orders (ticket, source, authority, received_at, due_at, summary, intake_channel, is_test, created_by)
     values ('LO-00000001', 'government', 'Test authority', now() - interval '10 minutes', now() + interval '170 minutes',
             'Drill', 'console', true, 'staff:pgtap') $$,
  'a test takedown order is recorded');
select throws_ok(
  $$ insert into public.admin_legal_orders (ticket, source, authority, received_at, due_at, summary, intake_channel, created_by)
     values ('LO-00000002', 'court', 'X', now() + interval '1 hour', now() + interval '4 hours', 'x', 'console', 'x') $$,
  '23514', null, 'an order cannot be received in the future (the clock starts at receipt)');
select throws_ok(
  $$ update public.admin_legal_orders set status = 'actioned' where ticket = 'LO-00000001' $$,
  '23514', null, 'an order is closed with a closing time');
select throws_ok($$ delete from public.admin_legal_orders $$, '42501', null, 'legal orders cannot be deleted from the console');
reset role;

-- ---------------------------------------------------------------- pager
insert into public.admin_pages (id, kind, ref_id, reason, is_test, due_at) values
  ('13f00000-0000-4000-8000-0000000000f1', 'legal_order', (select id from public.admin_legal_orders where ticket = 'LO-00000001'),
   'legal_order', true, now() + interval '170 minutes');
select throws_ok(
  $$ insert into public.admin_pages (kind, ref_id, reason) values ('legal_order', (select id from public.admin_legal_orders where ticket = 'LO-00000001'), 'legal_order') $$,
  '23505', null, 'one page per item');
select throws_ok(
  $$ insert into public.admin_pages (kind, ref_id, reason) values ('test', gen_random_uuid(), 'test_manual') $$,
  '23514', null, 'test pages point at nothing');
select throws_ok(
  $$ insert into public.admin_page_deliveries (page_id, round, level, channel, attempt, ok, error)
     values ('13f00000-0000-4000-8000-0000000000f1', 0, 0, 'webhook', 1, false, 'HTTP 500: <html>body</html>') $$,
  '23514', null, 'delivery errors are codes, never response bodies');
insert into public.admin_page_deliveries (page_id, round, level, channel, attempt, ok, http_status)
values ('13f00000-0000-4000-8000-0000000000f1', 0, 0, 'webhook', 1, true, 200);
set local role aura_admin;
select lives_ok(
  $$ update public.admin_pages set status = 'acknowledged', acknowledged_at = now(), acknowledged_by = 'staff:pgtap'
      where id = '13f00000-0000-4000-8000-0000000000f1' $$,
  'staff acknowledge a page');
select throws_ok($$ insert into public.admin_pages (kind, reason) values ('test', 'test_manual') $$, '42501', null,
  'staff cannot raise pages directly (the pager does)');
select throws_ok($$ delete from public.admin_pages $$, '42501', null, 'pages cannot be deleted');
select throws_ok(
  $$ insert into public.admin_page_deliveries (page_id, round, level, channel, attempt, ok) values ('13f00000-0000-4000-8000-0000000000f1', 0, 0, 'email', 1, true) $$,
  '42501', null, 'the delivery log is written by the pager only');
select is((select count(*)::int from public.admin_page_deliveries where page_id = '13f00000-0000-4000-8000-0000000000f1'), 1,
  'staff read the delivery log');

-- ---------------------------------------------------------------- mandatory-report checklist
select lives_ok(
  $$ insert into public.admin_mandatory_checklists (evidence_hold_id, items, updated_by)
     values ('13e00000-0000-4000-8000-0000000000e1', '{"counsel_consulted": {"done": true}}', 'staff:pgtap') $$,
  'the Owner ticks the SOP checklist');
select throws_ok(
  $$ insert into public.admin_mandatory_checklists (evidence_hold_id, items) values (gen_random_uuid(), '{}') $$,
  '23503', null, 'a checklist belongs to an evidence hold');
reset role;
delete from public.evidence_holds where id = '13e00000-0000-4000-8000-0000000000e1';
select is((select count(*)::int from public.admin_mandatory_checklists where evidence_hold_id = '13e00000-0000-4000-8000-0000000000e1'), 0,
  'the checklist goes when the evidence hold expires');

select * from finish();
rollback;
