-- F6 Reflections (migration 20261005000018; contracts/api/v1-reflections.md):
--   * server-only: RLS on, no policies, no privilege for anon / authenticated (strangers read through NestJS, DS-10);
--   * shape: no replies (parent_id must stay null, REQ-REF-05), status / reason enums, same-room author membership,
--     text only encrypted (body_ct + body_key together, scrubbed only when deleted / expired);
--   * gestures on a reflection, reports and evidence on a reflection;
--   * aura_admin (REQ-ADM-03): reads without the author's account or the duplicate hash; the definer functions decide
--     (approve / remove with report resolution and the lift of the automatic shadow-mute), escalate only upward, and
--     reveal the author only for a reflection that has a report; clients can call none of them;
--   * cascades: with the room (purge) and the author's account; flags exist.
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin; -- pgTAP for the role-switched assertions (rolled back)

select plan(50);

-- ---------------------------------------------------------------- fixtures
insert into auth.users (id, email, aud, role) values
  ('18aaaaaa-0000-4000-8000-00000000000a', 'pgtap-refl-a@aura.test', 'authenticated', 'authenticated'),
  ('18bbbbbb-0000-4000-8000-00000000000b', 'pgtap-refl-b@aura.test', 'authenticated', 'authenticated');
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at)
values ('18cccccc-0000-4000-8000-00000000000c', 'en', 'storm', 'south_asia', 'anxious', 'lighthouse', now(),
        now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days'),
       ('18dddddd-0000-4000-8000-00000000000d', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary', now(),
        now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool,
                                 home_region, match_step, stage)
values ('18a0a0a0-0000-4000-8000-00000000000a', '18cccccc-0000-4000-8000-00000000000c', '18aaaaaa-0000-4000-8000-00000000000a',
        'Quiet Comet', 'anxious', 'storm', 'en', 'south_asia', 4, 'spark'),
       ('18b0b0b0-0000-4000-8000-00000000000b', '18cccccc-0000-4000-8000-00000000000c', '18bbbbbb-0000-4000-8000-00000000000b',
        'Gentle Harbor', 'anxious', 'storm', 'en', 'south_asia', 4, 'spark'),
       ('18a1a1a1-0000-4000-8000-00000000000a', '18dddddd-0000-4000-8000-00000000000d', '18aaaaaa-0000-4000-8000-00000000000a',
        'Soft Lantern', 'lonely', 'rain', 'en', 'south_asia', 4, 'spark');

-- ---------------------------------------------------------------- server-only
select has_table('public', 'reflections', 'reflections exists');
select has_table('public', 'reflection_config', 'reflection_config exists');
select is((select count(*)::int from public.reflection_config), 1, 'one config row');
select ok((select relrowsecurity from pg_class where oid = 'public.reflections'::regclass)
          and (select relrowsecurity from pg_class where oid = 'public.reflection_config'::regclass),
  'RLS on for both tables');
select is_empty($$ select policyname from pg_policies where schemaname = 'public' and tablename in ('reflections','reflection_config') $$,
  'no policies: no client ever reads a reflection from Postgres (DS-10)');
select ok(not has_table_privilege(r, 'public.reflections', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
          and not has_any_column_privilege(r, 'public.reflections', 'SELECT, INSERT, UPDATE'),
  format('%s: no privilege on reflections', r))
from unnest(array['anon', 'authenticated']) r;
set local role authenticated;
select throws_ok($$ select * from public.reflections $$, '42501', null, 'a signed-in client cannot read reflections');
reset role;

-- ---------------------------------------------------------------- shape
select lives_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool, published_at)
     values ('18e0e0e0-0000-7000-8000-000000000001', '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'published', repeat('A', 40), repeat('B', 80), 12, 'en', now()) $$,
  'a published reflection (ciphertext + wrapped key)');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, parent_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', '18e0e0e0-0000-7000-8000-000000000001', 'pending', repeat('A', 40), repeat('B', 80), 3, 'en') $$,
  '23514', null, 'no replies: parent_id must stay null (REQ-REF-05)');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a1a1a1-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'pending', repeat('A', 40), repeat('B', 80), 3, 'en') $$,
  '23503', null, 'the author membership must belong to the same room');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'held', null, null, 3, 'en') $$,
  '23514', null, 'a live reflection always carries its (encrypted) text');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'held', repeat('A', 40), null, 3, 'en') $$,
  '23514', null, 'ciphertext and wrapped key come together');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'visible', repeat('A', 40), repeat('B', 80), 3, 'en') $$,
  '23514', null, 'status is one of the known states');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'published', repeat('A', 40), repeat('B', 80), 3, 'en') $$,
  '23514', null, 'published needs published_at');
select throws_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool, reject_reason)
     values (gen_random_uuid(), '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'rejected', repeat('A', 40), repeat('B', 80), 3, 'en', 'rude') $$,
  '23514', null, 'reject reasons are the contract codes');
select lives_ok(
  $$ insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool, hold_reason)
     values ('18e0e0e0-0000-7000-8000-000000000002', '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a',
             '18aaaaaa-0000-4000-8000-00000000000a', 'held', repeat('A', 40), repeat('B', 80), 5, 'en', 'uncertain') $$,
  'a held reflection');
select lives_ok(
  $$ update public.reflections set status = 'deleted', body_ct = null, body_key = null where id = '18e0e0e0-0000-7000-8000-000000000002' $$,
  'deleted / expired items are scrubbed');
update public.reflections set status = 'held', body_ct = repeat('A', 40), body_key = repeat('B', 80) where id = '18e0e0e0-0000-7000-8000-000000000002';

-- ---------------------------------------------------------------- gestures, reports, evidence
select lives_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, to_member_id, to_reflection_id, type, target)
     values ('18cccccc-0000-4000-8000-00000000000c', '18b0b0b0-0000-4000-8000-00000000000b', '18a0a0a0-0000-4000-8000-00000000000a',
             '18e0e0e0-0000-7000-8000-000000000001', 'hug', 'reflection') $$,
  'a gesture on a reflection goes to its author');
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, to_member_id, type, target)
     values ('18cccccc-0000-4000-8000-00000000000c', '18b0b0b0-0000-4000-8000-00000000000b', '18a0a0a0-0000-4000-8000-00000000000a', 'hug', 'reflection') $$,
  '23514', null, 'a reflection gesture names its reflection');
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, to_reflection_id, type, target)
     values ('18cccccc-0000-4000-8000-00000000000c', '18b0b0b0-0000-4000-8000-00000000000b', '18e0e0e0-0000-7000-8000-000000000001', 'hug', 'room') $$,
  '23514', null, 'a room gesture never carries a reflection');
select lives_ok(
  $$ insert into public.reports (id, source, auto_signal, reason, lane, target_kind, room_id, target_member_id, target_user_id,
                                 target_reflection_id, target_ref, sla_due_at)
     values ('18f0f0f0-0000-4000-8000-000000000001', 'auto', 'reflection_hold', 8, 'spam', 'reflection', '18cccccc-0000-4000-8000-00000000000c',
             '18a0a0a0-0000-4000-8000-00000000000a', '18aaaaaa-0000-4000-8000-00000000000a', '18e0e0e0-0000-7000-8000-000000000002',
             '18e0e0e0-0000-7000-8000-000000000002', now() + interval '1 day'),
            ('18f0f0f0-0000-4000-8000-000000000002', 'auto', 'reflection_minor_safety', 9, 'minors_grooming', 'reflection',
             '18cccccc-0000-4000-8000-00000000000c', '18a0a0a0-0000-4000-8000-00000000000a', '18aaaaaa-0000-4000-8000-00000000000a',
             '18e0e0e0-0000-7000-8000-000000000002', '18e0e0e0-0000-7000-8000-000000000002', now() + interval '4 hours') $$,
  'automatic reflection reports (hold, minor safety)');
select throws_ok(
  $$ insert into public.reports (source, auto_signal, reason, lane, target_kind, target_ref, sla_due_at)
     values ('auto', 'reflection_spam', 8, 'spam', 'reflection', gen_random_uuid(), now()) $$,
  '23514', null, 'unknown automatic signals are refused');
select lives_ok(
  $$ insert into public.evidence_holds (report_id, item_kind, item_ref, reason, snapshot, hold_until)
     values ('18f0f0f0-0000-4000-8000-000000000001', 'reflection', '18e0e0e0-0000-7000-8000-000000000002', 'spam:other', '{}', now() + interval '180 days') $$,
  'evidence can hold a reflection');
insert into public.sanctions (user_id, kind, reason_code, source, report_id, created_by)
values ('18aaaaaa-0000-4000-8000-00000000000a', 'shadow_mute', 'auto_minor_safety', 'auto', '18f0f0f0-0000-4000-8000-000000000002', 'system');

-- ---------------------------------------------------------------- aura_admin (REQ-ADM-03)
select ok(not has_column_privilege('aura_admin', 'public.reflections', c, 'SELECT'), format('aura_admin cannot read reflections.%s', c))
from unnest(array['user_id', 'text_hash']) c;
select ok(has_column_privilege('aura_admin', 'public.reflections', 'body_ct', 'SELECT')
          and has_column_privilege('aura_admin', 'public.reports', 'target_reflection_id', 'SELECT'),
  'aura_admin reads the ciphertext (only NestJS can open it) and the report link');
select ok(not has_table_privilege('aura_admin', 'public.reflections', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'aura_admin cannot write reflections directly');
select ok(not has_function_privilege(r, 'public.admin_reflection_decide(uuid, text, text, text)', 'EXECUTE')
          and not has_function_privilege(r, 'public.admin_reflection_escalate(uuid, text, timestamptz, boolean)', 'EXECUTE')
          and not has_function_privilege(r, 'public.admin_reflection_author(uuid)', 'EXECUTE'),
  format('%s cannot call the console reflection functions', r))
from unnest(array['anon', 'authenticated', 'service_role']) r;

set local role aura_admin;
select throws_ok($$ select user_id from public.reflections $$, '42501', null, 'as aura_admin: no author account');
select is((select public.admin_reflection_author('18e0e0e0-0000-7000-8000-000000000002')), '18aaaaaa-0000-4000-8000-00000000000a'::uuid,
  'the author of a queued reflection (for the audit HMAC)');
select is((select public.admin_reflection_author('18e0e0e0-0000-7000-8000-000000000001')), null::uuid,
  'nobody behind a reflection nobody reported');
select throws_ok($$ select * from public.admin_reflection_escalate('18f0f0f0-0000-4000-8000-000000000002', 'minors_grooming', now(), false) $$,
  'AR040', 'invalid_lane', 'escalation never moves sideways or down');
select ok((select public.admin_reflection_escalate('18f0f0f0-0000-4000-8000-000000000001', 'minors_grooming', now() + interval '2 hours', true)),
  'escalate a hold item to Minors & grooming');
select throws_ok($$ select * from public.admin_reflection_decide('18e0e0e0-0000-7000-8000-000000000002', 'publish', 'staff:pgtap') $$,
  'AR040', 'invalid_input', 'only approve / remove');
select results_eq(
  $$ select previous_status, status, reports_resolved, sanctions_lifted
       from public.admin_reflection_decide('18e0e0e0-0000-7000-8000-000000000002', 'approve', 'staff:18000000-0000-4000-8000-000000000000') $$,
  $$ values ('held'::text, 'published'::text, 2, 1) $$,
  'approve: held → published, both open reports resolved, the automatic shadow-mute lifted'
);
reset role;
select is((select lane from public.reports where id = '18f0f0f0-0000-4000-8000-000000000001'), 'minors_grooming', 'the escalation stuck');
select is((select status from public.reports where id = '18f0f0f0-0000-4000-8000-000000000001'), 'dismissed', 'approve → reports dismissed (no action)');
select ok((select published_at is not null and decided_by like 'staff:%' from public.reflections where id = '18e0e0e0-0000-7000-8000-000000000002'),
  'published with the deciding staff member');
select ok(exists (select 1 from realtime.messages where topic = 'room:18cccccc-0000-4000-8000-00000000000c' and event = 'reflection_published'
                    and payload ->> 'reflectionId' = '18e0e0e0-0000-7000-8000-000000000002' and not (payload ? 'text')),
  'the room was told the id (never the text)');

set local role aura_admin;
select results_eq(
  $$ select previous_status, status from public.admin_reflection_decide('18e0e0e0-0000-7000-8000-000000000002', 'remove', 'staff:18000000-0000-4000-8000-000000000000', 'hurtful') $$,
  $$ values ('published'::text, 'removed'::text) $$,
  'remove: published → removed'
);
reset role;
select is((select reject_reason from public.reflections where id = '18e0e0e0-0000-7000-8000-000000000002'), 'hurtful', 'the author sees a reason code');
select ok(exists (select 1 from realtime.messages where topic = 'member:18a0a0a0-0000-4000-8000-00000000000a' and event = 'reflection_status'
                    and payload ->> 'status' = 'removed'),
  'the author''s member topic got the status');
update public.reflections set status = 'expired', body_ct = null, body_key = null where id = '18e0e0e0-0000-7000-8000-000000000002';
set local role aura_admin;
select throws_ok($$ select * from public.admin_reflection_decide('18e0e0e0-0000-7000-8000-000000000002', 'approve', 'staff:pgtap') $$,
  'AR040', 'not_reviewable', 'an expired item can no longer be reviewed');
reset role;

-- ---------------------------------------------------------------- flags and cascades
select is((select enabled from public.feature_flags where key = 'reflections_composer'), true, 'the composer kill switch exists, on');
select ok((select payload ? 'pausedPools' from public.feature_flags where key = 'reflections_composer'), 'with a per-pool list');
delete from public.rooms where id = '18cccccc-0000-4000-8000-00000000000c';
select is((select count(*)::int from public.reflections where room_id = '18cccccc-0000-4000-8000-00000000000c'), 0,
  'reflections are purged with their room');
select is((select count(*)::int from public.evidence_holds where item_ref = '18e0e0e0-0000-7000-8000-000000000002'), 1,
  'evidence about a reflection survives the room purge');

select * from finish();
rollback;
