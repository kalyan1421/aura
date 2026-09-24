-- Admin console v0 completion (migration 20261005000016; PRD 19-admin-console):
--   * REQ-ADM-03: aura_admin still reaches nothing private (no check-ins / notes / habits / capsules / birth_date, no
--     auth schema, no deletion-case table, no account_deletions / device_tokens); its only SECURITY DEFINER doors are
--     the listed console functions; clients and service_role can call none of them;
--   * moderation primitives as aura_admin: preconditions checked in the database, evidence only ever extended, the
--     admin-triggered room broadcast only for an account that is hidden;
--   * REQ-ADM-07: a crisis-flagged item never gets a strike (whoever inserts it); strikes past 90 days stop counting;
--   * staff editor: Owner-only in the database too, never an app account, audited with the staff actor;
--   * REQ-ADM-11: deletion cases — the link goes to the account's own address, only the public link (not aura_admin)
--     verifies, only a verified case schedules the app's deletion, and the purge completes the case while the evidence
--     hold about the account survives;
--   * kill switches reduced_mode / hold_all exist, off.
begin;
create extension if not exists pgtap with schema extensions;

select plan(111);

grant usage on schema extensions to aura_admin; -- pgTAP for the role-switched assertions (rolled back at the end)

-- ================================================================ REQ-ADM-03: the boundary
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
  'aura_admin still has no privilege on any other public table');
select ok(not has_table_privilege('aura_admin', format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
          and not has_any_column_privilege('aura_admin', format('public.%I', t), 'SELECT, INSERT, UPDATE'),
  format('aura_admin: no direct privilege on %s', t))
from unnest(array['admin_deletion_cases','moderation_audit_anchor','account_deletions','device_tokens']) t;
select ok(not has_table_privilege(r, 'public.admin_deletion_cases', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s: no privilege on admin_deletion_cases', r))
from unnest(array['anon','authenticated']) r;
select ok((select relrowsecurity from pg_class where oid = 'public.admin_deletion_cases'::regclass)
          and not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_deletion_cases'),
  'admin_deletion_cases: RLS on, no policies (server-only)');

set local role aura_admin;
select throws_ok($$ select note_ct from public.check_ins limit 1 $$, '42501', null, 'aura_admin: check-ins and notes → denied');
select throws_ok($$ select 1 from public.habits limit 1 $$, '42501', null, 'aura_admin: habits → denied');
select throws_ok($$ select 1 from public.capsules limit 1 $$, '42501', null, 'aura_admin: capsules → denied');
select throws_ok($$ select birth_date from public.profiles limit 1 $$, '42501', null, 'aura_admin: birth_date → denied');
select throws_ok($$ select 1 from public.admin_deletion_cases limit 1 $$, '42501', null, 'aura_admin: deletion cases only through functions');
select throws_ok($$ select 1 from public.moderation_audit_anchor $$, '42501', null, 'aura_admin: the audit anchor only through admin_audit_anchor()');
select throws_ok($$ select * from public.deletion_case_confirm(repeat('a', 64), false) $$, '42501', null,
  'aura_admin cannot confirm a deletion link (only the public route can)');
select throws_ok($$ select * from public.deletion_case_lookup(repeat('a', 64)) $$, '42501', null, 'aura_admin cannot look up link tokens');
reset role;

-- The SECURITY DEFINER doors open to aura_admin are exactly these (a new one needs a deliberate grant and this list).
select is(
  array(select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.prosecdef and has_function_privilege('aura_admin', p.oid, 'EXECUTE')
         order by 1),
  array['admin_account_age_days','admin_add_sanction','admin_add_strike','admin_audit_anchor','admin_deletion_case_close',
        'admin_deletion_case_mark_sent','admin_deletion_case_open','admin_deletion_case_reissue','admin_deletion_case_schedule',
        'admin_deletion_cases_list','admin_extend_evidence_hold','admin_hide_account_from_rooms','admin_item_crisis_flagged',
        'admin_lift_sanction','admin_record_mandatory_report','admin_reflection_author','admin_reflection_decide',
        'admin_reflection_escalate','admin_report_for_action','admin_resolve_report', -- F6: migration 18
        'admin_staff_add','admin_staff_list','admin_staff_update','user_is_minor'],
  'aura_admin can execute only the listed SECURITY DEFINER functions');
select is_empty(
  $$ select p.proname || ' / ' || r from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      cross join unnest(array['anon','authenticated','service_role']) r
      where n.nspname = 'public' and (p.proname like 'admin\_%' or p.proname like 'deletion\_case\_%' or p.proname = 'strikes_never_crisis')
        and has_function_privilege(r, p.oid, 'EXECUTE') $$,
  'no client role (nor service_role) can call a console function');
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef
        and (p.proname like 'admin\_%' or p.proname like 'deletion\_case\_%' or p.proname = 'strikes_never_crisis')
        and coalesce(p.proconfig, '{}') <> array['search_path=""'] $$,
  'every console definer function pins an empty search_path');

-- ================================================================ fixtures (as postgres)
insert into auth.users (id, email, aud, role, created_at) values
  ('16aaaaaa-0000-4000-8000-00000000000a', 'pgtap16-subject@aura.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('16bbbbbb-0000-4000-8000-00000000000b', 'pgtap16-reporter@aura.test', 'authenticated', 'authenticated', now()),
  ('16cccccc-0000-4000-8000-00000000000c', 'pgtap16-other@aura.test', 'authenticated', 'authenticated', now()),
  ('16dddddd-0000-4000-8000-00000000000d', 'PgTap16-Delete@Aura.test', 'authenticated', 'authenticated', now()),
  ('16eeeeee-0000-4000-8000-00000000000e', 'pgtap16-owner@aura.test', 'authenticated', 'authenticated', now()),
  ('16ffffff-0000-4000-8000-00000000000f', 'pgtap16-candidate@aura.test', 'authenticated', 'authenticated', now()),
  ('16111111-0000-4000-8000-000000000011', 'pgtap16-immediate@aura.test', 'authenticated', 'authenticated', now()),
  ('16222222-0000-4000-8000-000000000022', 'pgtap16-changer@aura.test', 'authenticated', 'authenticated', now());
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
  ('16bbbbbb-0000-4000-8000-00000000000b', '1990-01-01', 'en', 'en', 'Asia/Kolkata');
insert into public.admin_staff (staff_id, role, display_name) values ('16eeeeee-0000-4000-8000-00000000000e', 'owner', 'PgTap Owner');
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at) values
  ('16000000-0000-4000-8000-0000000000a1', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary',
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage) values
  ('1600000a-0000-4000-8000-0000000000a1', '16000000-0000-4000-8000-0000000000a1', '16aaaaaa-0000-4000-8000-00000000000a', 'Quiet Comet', 'lonely', 'rain', 'en', 'south_asia', 4, 'spark'),
  ('1600000b-0000-4000-8000-0000000000a1', '16000000-0000-4000-8000-0000000000a1', '16bbbbbb-0000-4000-8000-00000000000b', 'Gentle Moon', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark'),
  ('1600000c-0000-4000-8000-0000000000a1', '16000000-0000-4000-8000-0000000000a1', '16cccccc-0000-4000-8000-00000000000c', 'Still River', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark');
insert into public.evidence_holds (id, report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until) values
  ('16e00000-0000-4000-8000-0000000000e1', '16d00000-0000-4000-8000-0000000000d1', 'member', '1600000a-0000-4000-8000-0000000000a1',
   'harassment:harassment', array['16aaaaaa-0000-4000-8000-00000000000a']::uuid[], '{}'::jsonb, now() + interval '30 days'),
  ('16e00000-0000-4000-8000-0000000000e2', null, 'member', null,
   'harassment:harassment', array['16dddddd-0000-4000-8000-00000000000d']::uuid[], '{}'::jsonb, now() + interval '100 days');
-- d1 harassment about the subject; d2 a crisis report about the same member (open); d3 harassment about "other";
-- d4 another crisis report (stays open); d5 harassment about the subject for sanctions.
insert into public.reports (id, reporter_user_id, reporter_member_id, reason, lane, target_kind, room_id, target_member_id,
                            target_user_id, target_ref, sla_due_at, evidence_hold_id) values
  ('16d00000-0000-4000-8000-0000000000d1', '16bbbbbb-0000-4000-8000-00000000000b', '1600000b-0000-4000-8000-0000000000a1', 2,
   'harassment', 'member', '16000000-0000-4000-8000-0000000000a1', '1600000a-0000-4000-8000-0000000000a1',
   '16aaaaaa-0000-4000-8000-00000000000a', '1600000a-0000-4000-8000-0000000000a1', now() + interval '24 hours',
   '16e00000-0000-4000-8000-0000000000e1'),
  ('16d00000-0000-4000-8000-0000000000d2', '16cccccc-0000-4000-8000-00000000000c', '1600000c-0000-4000-8000-0000000000a1', 1,
   'crisis', 'member', '16000000-0000-4000-8000-0000000000a1', '1600000a-0000-4000-8000-0000000000a1',
   '16aaaaaa-0000-4000-8000-00000000000a', '1600000a-0000-4000-8000-0000000000a1', now() + interval '1 hour', null),
  ('16d00000-0000-4000-8000-0000000000d3', '16bbbbbb-0000-4000-8000-00000000000b', '1600000b-0000-4000-8000-0000000000a1', 4,
   'harassment', 'member', '16000000-0000-4000-8000-0000000000a1', '1600000c-0000-4000-8000-0000000000a1',
   '16cccccc-0000-4000-8000-00000000000c', '1600000c-0000-4000-8000-0000000000a1', now() + interval '24 hours', null),
  ('16d00000-0000-4000-8000-0000000000d4', '16bbbbbb-0000-4000-8000-00000000000b', '1600000b-0000-4000-8000-0000000000a1', 1,
   'crisis', 'member', '16000000-0000-4000-8000-0000000000a1', '1600000c-0000-4000-8000-0000000000a1',
   '16cccccc-0000-4000-8000-00000000000c', '1600000c-0000-4000-8000-0000000000a1', now() + interval '1 hour', null),
  ('16d00000-0000-4000-8000-0000000000d5', '16cccccc-0000-4000-8000-00000000000c', '1600000c-0000-4000-8000-0000000000a1', 6,
   'spam', 'member', '16000000-0000-4000-8000-0000000000a1', '1600000a-0000-4000-8000-0000000000a1',
   '16aaaaaa-0000-4000-8000-00000000000a', '1600000a-0000-4000-8000-0000000000a1', now() + interval '24 hours', null);
insert into public.device_tokens (user_id, platform, token) values
  ('16dddddd-0000-4000-8000-00000000000d', 'android', 'pgtap16-fcm-token-delete-me');
-- Two strikes on "other" that are past 90 days (expired) and one fresh.
insert into public.strikes (user_id, reason_code, created_by, created_at, expires_at) values
  ('16cccccc-0000-4000-8000-00000000000c', 'harassment', 'staff:pgtap', now() - interval '120 days', now() - interval '30 days'),
  ('16cccccc-0000-4000-8000-00000000000c', 'harassment', 'staff:pgtap', now() - interval '91 days', now() - interval '1 day'),
  ('16cccccc-0000-4000-8000-00000000000c', 'harassment', 'staff:pgtap', now() - interval '10 days', now() + interval '80 days');

-- ================================================================ moderation primitives, as aura_admin
set local role aura_admin;
select is((select crisis_flagged from public.admin_report_for_action('16d00000-0000-4000-8000-0000000000d1')), true,
  'an item with an open crisis report about the same member is crisis-flagged');
select throws_ok($$ select * from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d1', 'harassment', 'staff:pgtap') $$,
  'AR040', 'crisis_never_strikes', 'REQ-ADM-07 negative: no strike on a crisis-flagged item');
select throws_ok($$ select * from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d2', 'harassment', 'staff:pgtap') $$,
  'AR040', 'crisis_never_strikes', 'REQ-ADM-07 negative: a crisis report itself never strikes');
select is(public.admin_resolve_report('16d00000-0000-4000-8000-0000000000d2', 'dismissed', 'staff:pgtap'), true,
  'the crisis report is dismissed (false alarm)');
select is(public.admin_resolve_report('16d00000-0000-4000-8000-0000000000d2', 'dismissed', 'staff:pgtap'), false,
  'resolving a closed report changes nothing');
select is(public.admin_item_crisis_flagged('16d00000-0000-4000-8000-0000000000d1'), false,
  'a dismissed crisis report no longer protects the item');
select is((select active_strikes from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d1', 'harassment', 'staff:pgtap')), 1,
  'then the harassment report strikes: 1 active strike');
select throws_ok($$ select * from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d3', 'harassment', 'staff:pgtap') $$,
  'AR040', 'crisis_never_strikes', 'an open crisis report about the same person in the same room also protects them');
select is(public.admin_resolve_report('16d00000-0000-4000-8000-0000000000d4', 'dismissed', 'staff:pgtap'), true, 'that crisis report dismissed too');
select is((select active_strikes from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d3', 'hate', 'staff:pgtap')), 2,
  'REQ-ADM-07: strikes older than 90 days stop counting (2 expired + 1 fresh + this one = 2 active)');
select throws_ok($$ select * from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d1', 'Not A Code', 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'bad input is refused before anything else');
select throws_ok($$ select * from public.admin_add_strike('16d00000-0000-4000-8000-0000000000d2', 'harassment', 'staff:pgtap') $$,
  'AR040', 'report_closed', 'a closed report cannot strike');

select throws_ok($$ select public.admin_add_sanction('16d00000-0000-4000-8000-0000000000d5', 'gesture_shadow_mute', 'spam', 24, 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'gesture shadow-mutes are automatic only');
select throws_ok($$ select public.admin_add_sanction('16d00000-0000-4000-8000-0000000000d5', 'room_suspension', 'spam', 48, 'staff:pgtap') $$,
  'AR040', 'invalid_duration', 'suspensions are 24 h or 7 days');
select throws_ok($$ select public.admin_add_sanction('16d00000-0000-4000-8000-0000000000d5', 'account_ban', 'spam', 24, 'staff:pgtap') $$,
  'AR040', 'invalid_duration', 'a ban has no end');
select is(public.admin_hide_account_from_rooms('16aaaaaa-0000-4000-8000-00000000000a', now()), 0,
  'the room broadcast refuses an account that is not hidden');
select ok(public.admin_add_sanction('16d00000-0000-4000-8000-0000000000d5', 'room_suspension', 'spam', 24, 'staff:pgtap') is not null,
  'a 24 h room suspension is recorded');
select is(public.admin_hide_account_from_rooms('16aaaaaa-0000-4000-8000-00000000000a', now()), 1,
  'the suspended account leaves its live room for everyone else (member_left through the definer)');
select is((select count(*)::int from public.sanctions where report_id = '16d00000-0000-4000-8000-0000000000d5'), 1,
  'aura_admin reads the sanction it created');
select is((select count(*)::int from public.admin_lift_sanction((select id from public.sanctions where report_id = '16d00000-0000-4000-8000-0000000000d5'))), 1,
  'lifting returns the sanction');
select is((select count(*)::int from public.admin_lift_sanction((select id from public.sanctions where report_id = '16d00000-0000-4000-8000-0000000000d5'))), 0,
  'lifting twice returns nothing');
select throws_ok($$ select public.admin_extend_evidence_hold('16e00000-0000-4000-8000-0000000000e1', 0) $$, 'AR040', 'invalid_input',
  'hold extensions are 1–3650 days');
select is(public.admin_extend_evidence_hold('16e00000-0000-4000-8000-0000000000e1', 1), true, 'a shorter extension is accepted …');
select ok((select hold_until > now() + interval '29 days' from public.evidence_holds where id = '16e00000-0000-4000-8000-0000000000e1'),
  '… but never shortens the hold');
select is(public.admin_extend_evidence_hold('16e00000-0000-4000-8000-0000000000e1', 180, true), true, 'extend to 180 days, mandatory report');
select ok((select hold_until > now() + interval '179 days' and mandatory_report_required from public.evidence_holds
            where id = '16e00000-0000-4000-8000-0000000000e1'), 'held 180 days from now and marked for a mandatory report');
select throws_ok($$ select public.admin_record_mandatory_report('16e00000-0000-4000-8000-0000000000e1', 'NCRP', 'REF-1', 'a legal reason text') $$,
  'AR040', 'invalid_input', 'a mandatory report closes with a reference OR a legal reason, not both');
select is(public.admin_record_mandatory_report('16e00000-0000-4000-8000-0000000000e1', 'NCRP (drill)', 'PGTAP-1', null), true, 'reference recorded');
select is(public.admin_record_mandatory_report(gen_random_uuid(), 'NCRP (drill)', 'PGTAP-2', null), false, 'unknown hold → false');
select lives_ok($$ select * from public.admin_audit_anchor() $$, 'the audit-chain anchor is readable through its function');
select throws_ok($$ update public.reports set status = 'dismissed', resolved_at = now() $$, '42501', null,
  'still no direct write on reports');
reset role;

select throws_ok(
  $$ insert into public.strikes (user_id, reason_code, report_id, created_by, expires_at)
     values ('16aaaaaa-0000-4000-8000-00000000000a', 'harassment', '16d00000-0000-4000-8000-0000000000d2', 'db:pgtap', now() + interval '90 days') $$,
  'AR040', 'crisis_never_strikes', 'the database refuses a strike on a crisis report whoever inserts it');
select ok((select prosecdef from pg_proc where oid = 'public.strikes_never_crisis()'::regprocedure), 'the guard runs as definer');

-- ================================================================ staff editor
set local role aura_admin;
select throws_ok($$ select public.admin_staff_add('staff:16cccccc-0000-4000-8000-00000000000c', 'pgtap16-candidate@aura.test', 'moderator', 'Kay') $$,
  'AR040', 'forbidden_role', 'only an enabled Owner can add staff (checked in the database too)');
select throws_ok($$ select public.admin_staff_add('db:postgres', 'pgtap16-candidate@aura.test', 'moderator', 'Kay') $$,
  'AR040', 'forbidden_role', 'the actor must be a staff:<id>');
select is(public.admin_staff_add('staff:16eeeeee-0000-4000-8000-00000000000e', 'PGTAP16-Candidate@aura.test', 'moderator', ' Kay '),
  '16ffffff-0000-4000-8000-00000000000f'::uuid, 'the Owner adds an existing auth user (email case-insensitive)');
select throws_ok($$ select public.admin_staff_add('staff:16eeeeee-0000-4000-8000-00000000000e', 'pgtap16-candidate@aura.test', 'analyst', 'Kay') $$,
  'AR040', 'already_staff', 'no duplicates');
select throws_ok($$ select public.admin_staff_add('staff:16eeeeee-0000-4000-8000-00000000000e', 'pgtap16-reporter@aura.test', 'moderator', 'App') $$,
  'AR040', 'app_account', 'an app account can never become staff');
select throws_ok($$ select public.admin_staff_add('staff:16eeeeee-0000-4000-8000-00000000000e', 'nobody-16@aura.test', 'moderator', 'X') $$,
  'AR040', 'no_account', 'the person must have signed in once (the auth user exists)');
select throws_ok($$ select public.admin_staff_add('staff:16eeeeee-0000-4000-8000-00000000000e', 'pgtap16-other@aura.test', 'superuser', 'X') $$,
  'AR040', 'invalid_input', 'roles are owner / moderator / analyst');
select throws_ok($$ select public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', '16eeeeee-0000-4000-8000-00000000000e', 'moderator', null, null) $$,
  'AR040', 'cannot_change_self', 'an Owner cannot demote themselves');
select throws_ok($$ select public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', '16eeeeee-0000-4000-8000-00000000000e', null, null, true) $$,
  'AR040', 'cannot_change_self', 'nor disable themselves');
select is(public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', '16ffffff-0000-4000-8000-00000000000f', 'analyst', null, null), true,
  'the Owner changes a role');
select is(public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', '16ffffff-0000-4000-8000-00000000000f', 'analyst', 'Kay', null), false,
  'no change → no write, no audit row');
select is(public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', '16ffffff-0000-4000-8000-00000000000f', null, null, true), true,
  'the Owner disables a staff member');
select throws_ok($$ select public.admin_staff_update('staff:16eeeeee-0000-4000-8000-00000000000e', gen_random_uuid(), 'analyst', null, null) $$,
  'AR040', 'staff_not_found', 'unknown staff');
select is(
  (select array_agg(email order by email) from public.admin_staff_list() where email like 'pgtap16-%'),
  array['pgtap16-candidate@aura.test','pgtap16-owner@aura.test'],
  'the staff list shows staff accounts only (never app accounts)');
select is((select has_totp from public.admin_staff_list() where staff_id = '16eeeeee-0000-4000-8000-00000000000e'), false,
  'the staff list says whether TOTP is enrolled');
reset role;
select results_eq(
  $$ select action, actor from public.moderation_actions
      where reason_code = 'staff_allowlist' and detail->>'staffId' = '16ffffff-0000-4000-8000-00000000000f' order by id $$,
  $$ values ('staff_granted', 'staff:16eeeeee-0000-4000-8000-00000000000e'), ('staff_changed', 'staff:16eeeeee-0000-4000-8000-00000000000e'),
            ('staff_disabled', 'staff:16eeeeee-0000-4000-8000-00000000000e') $$,
  'console staff changes are audited with the Owner as actor');
select set_config('aura.admin_actor', 'not-a-staff-actor', true);
update public.admin_staff set display_name = 'Kay K' where staff_id = '16ffffff-0000-4000-8000-00000000000f';
select is((select actor from public.moderation_actions where reason_code = 'staff_allowlist'
            and detail->>'staffId' = '16ffffff-0000-4000-8000-00000000000f' order by id desc limit 1), 'db:postgres',
  'a malformed actor setting falls back to the database user');
select set_config('aura.admin_actor', '', true);

-- ================================================================ REQ-ADM-11: deletion cases
set local role aura_admin;
select is(
  (select row(status, account_id is null, send_to is null)::text from public.admin_deletion_case_open(
     'DEL-00000001', 'nobody-16@aura.test', 'email', now() - interval '1 hour', null, repeat('1', 64), now() + interval '72 hours', 'staff:pgtap')),
  '(no_account,t,t)', 'no app account for that email → closed as no_account, nothing to send');
select is(
  (select row(status, send_to is null)::text from public.admin_deletion_case_open(
     'DEL-00000002', 'pgtap16-owner@aura.test', 'email', now(), null, repeat('2', 64), now() + interval '72 hours', 'staff:pgtap')),
  '(staff_account,t)', 'a staff account is never deleted through a case');
select is(
  (select row(status, account_id, send_to)::text from public.admin_deletion_case_open(
     'DEL-00000003', ' pgtap16-delete@AURA.TEST ', 'email', now() - interval '2 hours', null,
     encode(sha256(convert_to('pgtap16-token-d', 'UTF8')), 'hex'), now() + interval '72 hours', 'staff:pgtap')),
  '(awaiting_verification,16dddddd-0000-4000-8000-00000000000d,PgTap16-Delete@Aura.test)',
  'matched → awaiting verification; the link goes to the address ON THE ACCOUNT');
select throws_ok(
  $$ select * from public.admin_deletion_case_open('DEL-00000004', 'pgtap16-delete@aura.test', 'email', now(), null, repeat('4', 64),
                                                   now() + interval '72 hours', 'staff:pgtap') $$,
  'AR040', 'open_case_exists', 'one open case per account');
select throws_ok(
  $$ select * from public.admin_deletion_case_open('DEL-00000005', 'pgtap16-other@aura.test', 'email', now(), null, repeat('5', 64),
                                                   now() + interval '30 days', 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'links live at most 14 days');
select throws_ok(
  $$ select * from public.admin_deletion_case_schedule((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'),
                                                       false, now() + interval '7 days', null, 'staff:pgtap') $$,
  'AR040', 'case_not_verified', 'REQ-ADM-11 negative: nothing is deleted before the account holder confirms');
select is((select account_email_masked from public.admin_deletion_cases_list('open') where ticket = 'DEL-00000003'), 'P•••@Aura.test',
  'the console sees a masked address only');
select is((select row(held_records, deletion_pending)::text from public.admin_deletion_cases_list('open') where ticket = 'DEL-00000003'),
  '(1,f)', 'and how many evidence rows about the account are under legal hold');
reset role;

-- The public link (service role): wrong token, then the right one, then again (single use).
select is((select outcome from public.deletion_case_confirm(repeat('9', 64), false)), 'invalid', 'an unknown token verifies nothing');
select is((select state from public.deletion_case_lookup(encode(sha256(convert_to('pgtap16-token-d', 'UTF8')), 'hex'))), 'valid',
  'the page can say the link is live without changing anything');
select is((select row(outcome, account_id)::text from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-d', 'UTF8')), 'hex'), false)),
  '(verified,16dddddd-0000-4000-8000-00000000000d)', 'the holder of the link confirms → verified');
select is((select outcome from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-d', 'UTF8')), 'hex'), false)), 'invalid',
  'the link works once');

set local role aura_admin;
select throws_ok(
  $$ select * from public.admin_deletion_case_schedule((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'),
                                                       false, now() + interval '31 days', null, 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'the grace period stays inside the PRD''s 30 days');
select throws_ok(
  $$ select * from public.admin_deletion_case_schedule((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'),
                                                       true, null, null, 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'an immediate deletion needs a reason code');
select ok(
  (select abs(extract(epoch from (scheduled_for - (now() + interval '7 days')))) < 5
     from public.admin_deletion_case_schedule((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'),
                                              false, now() + interval '7 days', null, 'staff:pgtap')),
  'a verified case starts the app''s deletion with the 7-day grace');
select is((select row(status, deletion_mode, deletion_pending)::text from public.admin_deletion_cases_list('open') where ticket = 'DEL-00000003'),
  '(deletion_scheduled,grace,t)', 'the case shows the pending deletion');
select throws_ok(
  $$ select public.admin_deletion_case_close((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'), 'withdrawn', 'staff:pgtap') $$,
  'AR040', 'case_not_closable', 'a pending deletion can only be closed once the holder kept the account');
reset role;
select ok((select scheduled_for > now() + interval '6 days' from public.account_deletions where user_id = '16dddddd-0000-4000-8000-00000000000d'),
  'account_deletions has the schedule (the app''s own deletion; the hourly purge takes it from here)');
select is((select count(*)::int from public.device_tokens where user_id = '16dddddd-0000-4000-8000-00000000000d'), 0,
  'its device tokens are gone at once (no pushes during the grace period)');

-- The purge's last step deletes the auth user: the case completes, the evidence hold about the account survives.
delete from auth.users where id = '16dddddd-0000-4000-8000-00000000000d';
select is(
  (select row(status, account_id is null, completed_at is not null, held_records, token_hash is null, email_hash is null)::text
     from public.admin_deletion_cases where ticket = 'DEL-00000003'),
  '(completed,t,t,1,t,t)', 'the purge completes the case and leaves no link or hash behind');
select ok((select '16dddddd-0000-4000-8000-00000000000d'::uuid = any(account_ids) and hold_until > now()
             from public.evidence_holds where id = '16e00000-0000-4000-8000-0000000000e2'),
  'REQ-ADM-11 negative: the evidence hold about the account survives until hold_until');
select is((select count(*)::int from public.moderation_actions where action = 'deletion_case_completed' and actor = 'system:account_purge'
            and detail->>'ticket' = 'DEL-00000003'), 1, 'the completion is audited (no account id, no email)');
select ok(not exists (select 1 from public.moderation_actions where detail::text ilike '%16dddddd-0000-4000-8000-00000000000d%'
                       or detail::text ilike '%pgtap16-delete%'), 'no audit row holds the account id or its email');

-- Immediate (with a reason), decline, expiry and a changed email.
set local role aura_admin;
select is((select status from public.admin_deletion_case_open('DEL-00000006', 'pgtap16-immediate@aura.test', 'grievance', now(), null,
          encode(sha256(convert_to('pgtap16-token-i', 'UTF8')), 'hex'), now() + interval '72 hours', 'staff:pgtap')), 'awaiting_verification',
  'a second case');
reset role;
select is((select outcome from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-i', 'UTF8')), 'hex'), false)), 'verified', 'confirmed');
set local role aura_admin;
select ok((select scheduled_for <= now() from public.admin_deletion_case_schedule(
             (select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000006'), true, null, 'under_13_confirmed', 'staff:pgtap')),
  'immediate: due now (the next hourly purge)');
select is((select deletion_mode from public.admin_deletion_cases_list('open') where ticket = 'DEL-00000006'), 'immediate', 'recorded as immediate');
select is((select status from public.admin_deletion_case_open('DEL-00000007', 'pgtap16-other@aura.test', 'email', now(), null,
          encode(sha256(convert_to('pgtap16-token-o', 'UTF8')), 'hex'), now() + interval '72 hours', 'staff:pgtap')), 'awaiting_verification',
  'a third case');
select is((select status from public.admin_deletion_case_open('DEL-00000008', 'pgtap16-changer@aura.test', 'email', now(), null,
          encode(sha256(convert_to('pgtap16-token-c', 'UTF8')), 'hex'), now() + interval '72 hours', 'staff:pgtap')), 'awaiting_verification',
  'a fourth case');
reset role;
select is((select outcome from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-o', 'UTF8')), 'hex'), true)), 'declined',
  '"This wasn''t me" → declined');
update auth.users set email = 'pgtap16-changed@aura.test' where id = '16222222-0000-4000-8000-000000000022';
select is((select outcome from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-c', 'UTF8')), 'hex'), false)), 'invalid',
  'a link sent before the account''s email changed no longer verifies');
update public.admin_deletion_cases set token_expires_at = now() - interval '1 minute' where ticket = 'DEL-00000008';
select is((select state from public.deletion_case_lookup(encode(sha256(convert_to('pgtap16-token-c', 'UTF8')), 'hex'))), 'expired',
  'an expired link says so');
select is((select outcome from public.deletion_case_confirm(encode(sha256(convert_to('pgtap16-token-c', 'UTF8')), 'hex'), false)), 'expired',
  'and verifies nothing');
set local role aura_admin;
select is((select count(*)::int from public.admin_deletion_case_reissue((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000008'),
          encode(sha256(convert_to('pgtap16-token-c2', 'UTF8')), 'hex'), now() + interval '72 hours')
          where send_to = 'pgtap16-changed@aura.test'), 1, 'a re-sent link goes to the current address on the account');
select lives_ok($$ select public.admin_deletion_case_close((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000007'),
                                                          'declined_by_holder', 'staff:pgtap') $$, 'a declined case is closed');
select is((select row(status, close_outcome, closed_by)::text from public.admin_deletion_cases_list('closed') where ticket = 'DEL-00000007'),
  '(closed,declined_by_holder,staff:pgtap)', 'closed with its outcome');
select throws_ok($$ select public.admin_deletion_case_close((select id from public.admin_deletion_cases_list('all') where ticket = 'DEL-00000003'),
                                                           'withdrawn', 'staff:pgtap') $$, 'AR040', 'case_not_closable', 'a completed case stays completed');
select is((select array_agg(ticket || ':' || status order by ticket) from public.admin_deletion_cases_list('open') where ticket like 'DEL-0000000_'),
  array['DEL-00000006:deletion_scheduled','DEL-00000008:awaiting_verification'], 'the open list: waiting, verified, declined or scheduled');
reset role;
select throws_ok(
  $$ insert into public.admin_deletion_cases (ticket, channel, received_at, status, created_by)
     values ('DEL-ILOU0000', 'email', now(), 'no_account', 'x') $$, '23514', null, 'tickets use Crockford base32');
select throws_ok(
  $$ insert into public.admin_deletion_cases (ticket, channel, received_at, status, created_by)
     values ('DEL-00000009', 'email', now(), 'awaiting_verification', 'x') $$, '23514', null,
  'a waiting case always points at an account');

-- ================================================================ kill switches
select is((select array_agg(key || '=' || enabled order by key) from public.feature_flags where key in ('reduced_mode','hold_all')),
  array['hold_all=false','reduced_mode=false'], 'reduced mode and hold-all exist, off');
set local role aura_admin;
select lives_ok($$ update public.feature_flags set enabled = enabled where key in ('reduced_mode','hold_all') $$,
  'the Owner flips them from the console (aura_admin: update(enabled) only)');
reset role;

select * from finish();
rollback;
