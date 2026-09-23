-- F5 Mood Rooms + F9 core safety (migration 20261005000010, contracts/api/v1-rooms.md):
--   * every new table is server-only: RLS on, no public policies, no client privileges (reads AND writes → 42501);
--   * Realtime authorization: members read their room / own member topic only, nobody else; clients can't write;
--   * DB backstops: capacity, one room per quadrant, join cutoff, pseudonym shape/uniqueness, same-room references;
--   * append-only, hash-chained audit log; evidence survives room and account deletion; purge cascades.
begin;
create extension if not exists pgtap with schema extensions;

select plan(83);

-- ---------------------------------------------------------------- shape
select has_table('public', t, format('public.%s exists', t))
from unnest(array['matching_config','safety_config','rooms','room_members','room_gestures','room_mutes',
                  'room_survey_counts','blocks','evidence_holds','reports','sanctions','strikes','moderation_actions']) t;

select is((select count(*)::int from public.matching_config), 1, 'matching_config has exactly one row');
select results_eq(
  $$ select step1_exact_mood, live_window_s, thin_join_threshold, room_capacity, join_cutoff_h, memory_after_h, purge_after_d,
            joins_per_quadrant_24h, gesture_min_interval_ms, gesture_room_hour_max, gesture_same_target_max,
            lantern_start::text, lantern_end::text
       from public.matching_config $$,
  $$ values (false, 120, 12, 24, 20, 24, 7, 3, 2000, 40, 3, '21:00:00', '23:00:00') $$,
  'matching_config defaults: step 1 off at alpha, 24 seats, 20 h / 24 h / +7 d, PRD limits, Lantern Hour 21–23'
);
select results_eq(
  $$ select report_daily_limit, under13_reports_to_pause, evidence_hold_days, strike_ttl_days from public.safety_config $$,
  $$ values (20, 2, 180, 90) $$,
  'safety_config defaults: 20 reports/day, 2 under-13 reports pause, 180-day evidence, 90-day strikes'
);
select is((select enabled from public.feature_flags where key = 'rooms_pool_hi'), false, 'Hindi + Hinglish rooms flag exists and is off');

-- ---------------------------------------------------------------- server-only: RLS, no policies, no privileges
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.matching_config','public.safety_config','public.rooms','public.room_members','public.room_gestures',
  'public.room_mutes','public.room_survey_counts','public.blocks','public.evidence_holds','public.reports',
  'public.sanctions','public.strikes','public.moderation_actions']::regclass[])), 'RLS enabled on every rooms/safety table');
select is_empty(
  $$ select tablename from pg_policies where schemaname = 'public' and tablename in
       ('matching_config','safety_config','rooms','room_members','room_gestures','room_mutes','room_survey_counts',
        'blocks','evidence_holds','reports','sanctions','strikes','moderation_actions') $$,
  'no client policies on any rooms/safety table (DS-10: stranger data only through NestJS)'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['rooms','room_members','room_gestures','room_mutes','blocks','evidence_holds','reports','sanctions',
                  'strikes','moderation_actions','matching_config','safety_config','room_survey_counts']) t
cross join unnest(array['anon','authenticated']) r
where t in ('rooms','room_members','room_gestures','blocks','evidence_holds','reports','sanctions','moderation_actions');
select ok(not has_sequence_privilege('authenticated', 'public.moderation_actions_id_seq', 'USAGE, SELECT, UPDATE'),
  'clients cannot touch the audit sequence');
select ok(not has_table_privilege('service_role', 'public.moderation_actions', 'UPDATE, DELETE, TRUNCATE'),
  'service_role cannot rewrite the audit log');
select ok(has_function_privilege('authenticated', 'public.realtime_topic_allowed(text)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.realtime_topic_allowed(text)', 'EXECUTE'),
  'realtime_topic_allowed: callable by signed-in users (Realtime evaluates the policy as them), not anon');
select ok(not has_function_privilege('authenticated', 'public.room_members_guard()', 'EXECUTE')
          and not has_function_privilege('authenticated', 'public.moderation_actions_chain()', 'EXECUTE'),
  'trigger functions are not callable by clients');

-- ---------------------------------------------------------------- fixtures (as postgres)
insert into auth.users (id, email, aud, role) values
  ('10aaaaaa-0000-4000-8000-00000000000a', 'pgtap-rooms-a@aura.test', 'authenticated', 'authenticated'),
  ('10bbbbbb-0000-4000-8000-00000000000b', 'pgtap-rooms-b@aura.test', 'authenticated', 'authenticated'),
  ('10cccccc-0000-4000-8000-00000000000c', 'pgtap-rooms-c@aura.test', 'authenticated', 'authenticated'),
  ('10dddddd-0000-4000-8000-00000000000d', 'pgtap-rooms-d@aura.test', 'authenticated', 'authenticated');

insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, capacity, opened_at, joins_close_at, memory_at, purge_at) values
  ('10000000-0000-4000-8000-0000000000a1', 'en', 'storm', 'south_asia', 'anxious', 'lighthouse', 2, now(),
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days'),
  ('10000000-0000-4000-8000-0000000000a2', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary', 24, null,
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');

insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage) values
  ('1000000a-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-0000000000a1', '10aaaaaa-0000-4000-8000-00000000000a', 'Quiet Comet', 'anxious', 'storm', 'en', 'south_asia', 4, 'spark'),
  ('1000000b-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-0000000000a1', '10bbbbbb-0000-4000-8000-00000000000b', 'Gentle Moon', 'restless', 'storm', 'en', 'south_asia', 2, 'glow'),
  ('1000000c-0000-4000-8000-0000000000a2', '10000000-0000-4000-8000-0000000000a2', '10cccccc-0000-4000-8000-00000000000c', 'Soft Star', 'lonely', 'rain', 'en', 'south_asia', 4, 'spark');
update public.room_members set left_at = now() where member_id = '1000000b-0000-4000-8000-0000000000a1';

-- Messages as Realtime stores them (inserted as postgres; the policy decides what a user may READ).
insert into realtime.messages (topic, extension, payload, event, private) values
  ('room:10000000-0000-4000-8000-0000000000a1', 'broadcast', '{}', 'probe', true),
  ('room:10000000-0000-4000-8000-0000000000a1', 'presence', '{}', 'probe', true),
  ('member:1000000a-0000-4000-8000-0000000000a1', 'broadcast', '{}', 'probe', true),
  ('member:1000000c-0000-4000-8000-0000000000a2', 'broadcast', '{}', 'probe', true),
  ('room:10000000-0000-4000-8000-0000000000a2', 'broadcast', '{}', 'probe', true);

create temp table rt_case (who uuid, topic text, expect int) on commit drop;
insert into rt_case values
  ('10aaaaaa-0000-4000-8000-00000000000a', 'room:10000000-0000-4000-8000-0000000000a1', 1),     -- current member
  ('10aaaaaa-0000-4000-8000-00000000000a', 'member:1000000a-0000-4000-8000-0000000000a1', 1),   -- own member topic
  ('10aaaaaa-0000-4000-8000-00000000000a', 'member:1000000c-0000-4000-8000-0000000000a2', 0),   -- someone else's member topic
  ('10aaaaaa-0000-4000-8000-00000000000a', 'room:10000000-0000-4000-8000-0000000000a2', 0),     -- a room they're not in
  ('10bbbbbb-0000-4000-8000-00000000000b', 'room:10000000-0000-4000-8000-0000000000a1', 0),     -- left the room
  ('10cccccc-0000-4000-8000-00000000000c', 'room:10000000-0000-4000-8000-0000000000a1', 0),     -- never a member
  ('10dddddd-0000-4000-8000-00000000000d', 'room:10000000-0000-4000-8000-0000000000a1', 0);     -- no membership at all
grant select on rt_case to authenticated, anon;

-- ---------------------------------------------------------------- realtime authorization (as Realtime checks it)
-- Realtime reads realtime.messages as the joining user (role authenticated, their JWT claims, realtime.topic = the
-- channel topic); a private join is allowed when that SELECT sees the topic's broadcast rows.
create temp table rt_result (topic text, who uuid, got int) on commit drop;
do $$
declare c record; n int;
begin
  for c in select * from rt_case loop
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', c.who, 'role', 'authenticated')::text, true);
    perform set_config('realtime.topic', c.topic, true);
    select count(*) into n from realtime.messages where topic = c.topic and extension = 'broadcast';
    perform set_config('role', 'postgres', true);
    insert into rt_result values (c.topic, c.who, n);
  end loop;
end $$;
reset role;

select is(r.got, c.expect, format('realtime: %s reading %s → %s row(s)', c.who, c.topic, c.expect))
from rt_case c join rt_result r on r.topic = c.topic and r.who = c.who
order by c.who, c.topic;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select set_config('realtime.topic', 'room:10000000-0000-4000-8000-0000000000a1', true);
select is((select count(*)::int from realtime.messages where topic = 'room:10000000-0000-4000-8000-0000000000a1' and extension = 'presence'), 0,
  'realtime: members get broadcast only — Presence is not readable (liveness is the server heartbeat)');
select throws_ok(
  $$ insert into realtime.messages (topic, extension, payload, event, private)
     values ('room:10000000-0000-4000-8000-0000000000a1', 'broadcast', '{}', 'forged', true) $$,
  '42501', null, 'realtime: clients cannot broadcast (no INSERT policy)');
select throws_ok($$ select * from public.room_members $$, '42501', null, 'authenticated cannot read room_members (not even own rows)');
select throws_ok($$ select * from public.reports $$, '42501', null, 'authenticated cannot read reports');
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, type, target)
     values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', 'hug', 'room') $$,
  '42501', null, 'authenticated cannot write gestures directly (only NestJS)');
select throws_ok(
  $$ insert into public.blocks (blocker_user_id, blocked_user_id) values ('10aaaaaa-0000-4000-8000-00000000000a', '10cccccc-0000-4000-8000-00000000000c') $$,
  '42501', null, 'authenticated cannot write blocks directly');
reset role;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select set_config('realtime.topic', 'room:10000000-0000-4000-8000-0000000000a1', true);
select is((select count(*)::int from realtime.messages where topic = 'room:10000000-0000-4000-8000-0000000000a1'), 0, 'realtime: anon reads nothing');
reset role;

-- Suspended accounts and accounts pending deletion lose their topics.
insert into public.sanctions (user_id, kind, reason_code, source, ends_at)
values ('10aaaaaa-0000-4000-8000-00000000000a', 'room_suspension', 'e2e', 'moderator', now() + interval '1 day');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.realtime_topic_allowed('room:10000000-0000-4000-8000-0000000000a1'), false, 'realtime: a suspended account is refused');
reset role;
update public.sanctions set lifted_at = now() where user_id = '10aaaaaa-0000-4000-8000-00000000000a';
insert into public.account_deletions (user_id, scheduled_for) values ('10aaaaaa-0000-4000-8000-00000000000a', now() + interval '7 days');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.realtime_topic_allowed('room:10000000-0000-4000-8000-0000000000a1'), false, 'realtime: an account pending deletion is refused');
reset role;
delete from public.account_deletions where user_id = '10aaaaaa-0000-4000-8000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.realtime_topic_allowed('room:10000000-0000-4000-8000-0000000000a1'), true, 'realtime: allowed again once lifted / cancelled');
reset role;

-- ---------------------------------------------------------------- DB backstops for the matcher
-- Room a1 (storm) has 2 seats: A is in it, B left it.
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a1', '10bbbbbb-0000-4000-8000-00000000000b', 'Warm Halo', 'anxious', 'storm', 'en', 'south_asia', 2, 'spark') $$,
  '23505', null, 'one seat per account per room: leaving is final (no rejoining)'
);
insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
values ('10000000-0000-4000-8000-0000000000a1', '10dddddd-0000-4000-8000-00000000000d', 'Brave Nova', 'anxious', 'storm', 'en', 'south_asia', 2, 'spark');
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a1', '10cccccc-0000-4000-8000-00000000000c', 'Calm Tide', 'anxious', 'storm', 'en', 'south_asia', 2, 'spark') $$,
  'AR001', 'room_full', 'capacity is enforced by the DB too: a member over capacity is refused (left members free their seat)'
);
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at) values
  ('10000000-0000-4000-8000-0000000000a3', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary',
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a3', '10cccccc-0000-4000-8000-00000000000c', 'Warm Halo', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark') $$,
  'AR002', 'one_room_per_quadrant', 'never two active rooms for one quadrant'
);
update public.rooms set created_at = now() - interval '21 hours', joins_close_at = now() - interval '1 hour' where id = '10000000-0000-4000-8000-0000000000a3';
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a3', '10dddddd-0000-4000-8000-00000000000d', 'Warm Halo', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark') $$,
  'AR003', 'room_closed_to_joins', 'no new members after 20 h'
);
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a2', '10dddddd-0000-4000-8000-00000000000d', 'Call 98765', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark') $$,
  '23514', null, 'a pseudonym can never carry digits or contact-like text'
);
select throws_ok(
  $$ insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
     values ('10000000-0000-4000-8000-0000000000a2', '10dddddd-0000-4000-8000-00000000000d', 'Soft Star', 'lonely', 'rain', 'en', 'south_asia', 2, 'spark') $$,
  '23505', null, 'pseudonyms are unique within a room'
);
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, to_member_id, type, target)
     values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', '1000000c-0000-4000-8000-0000000000a2', 'hug', 'member') $$,
  '23503', null, 'a gesture can only target a member of the same room'
);
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, type, target)
     values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', 'kiss', 'room') $$,
  '23514', null, 'only the 8 preset gestures exist'
);
select throws_ok(
  $$ insert into public.room_gestures (room_id, from_member_id, type, target)
     values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', 'hug', 'member') $$,
  '23514', null, 'a member gesture needs a recipient (target shape)'
);
select throws_ok(
  $$ insert into public.room_mutes (room_id, muter_member_id, muted_member_id)
     values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', '1000000c-0000-4000-8000-0000000000a2') $$,
  '23503', null, 'mutes stay within one room'
);
select throws_ok(
  $$ insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at)
     values ('en', 'storm', 'south_asia', 'anxious', 'sunrise_deck', now() + interval '1 hour', now() + interval '2 hours', now() + interval '3 hours') $$,
  '23514', null, 'a room''s theme always matches its quadrant'
);

-- ---------------------------------------------------------------- audit log: hash-chained, append-only for everyone
insert into public.moderation_actions (actor, action, reason_code, detail) values ('system', 'auto_rooms_pause', 'under_13_reports', '{"n":2}');
insert into public.moderation_actions (actor, action, reason_code) values ('staff:pgtap', 'dismiss', 'other');
select ok(
  (select a2.prev_hash = a1.row_hash and a2.id > a1.id
     from (select * from public.moderation_actions order by id desc limit 1 offset 1) a1,
          (select * from public.moderation_actions order by id desc limit 1) a2),
  'each audit row links to the previous row''s hash, in id order'
);
select throws_ok($$ update public.moderation_actions set actor = 'x' $$, 'AR010', null, 'audit rows cannot be updated (even by the owner)');
select throws_ok($$ delete from public.moderation_actions $$, 'AR010', null, 'audit rows cannot be deleted (even by the owner)');
select throws_ok($$ truncate public.moderation_actions $$, 'AR010', null, 'the audit log cannot be truncated');

-- ---------------------------------------------------------------- reports, evidence, blocks and purge semantics
insert into public.reports (id, reporter_user_id, reason, lane, target_kind, room_id, target_member_id, target_user_id, target_ref, sla_due_at)
values ('10000000-0000-4000-8000-00000000e001', '10cccccc-0000-4000-8000-00000000000c', 2, 'harassment', 'member',
        '10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', '10aaaaaa-0000-4000-8000-00000000000a',
        '1000000a-0000-4000-8000-0000000000a1', now() + interval '1 day');
insert into public.evidence_holds (id, report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until)
values ('10000000-0000-4000-8000-00000000f001', '10000000-0000-4000-8000-00000000e001', 'member', '1000000a-0000-4000-8000-0000000000a1',
        'harassment:harassment', array['10aaaaaa-0000-4000-8000-00000000000a']::uuid[], '{"members":[]}', now() + interval '180 days');
select throws_ok(
  $$ insert into public.reports (reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('10cccccc-0000-4000-8000-00000000000c', 2, 'harassment', 'member', '1000000a-0000-4000-8000-0000000000a1', now()) $$,
  '23505', null, 'an open report on the same item for the same reason counts once per reporter'
);
select throws_ok(
  $$ insert into public.reports (reporter_user_id, reason, lane, target_kind, target_ref, sla_due_at)
     values ('10cccccc-0000-4000-8000-00000000000c', 9, 'spam', 'room', gen_random_uuid(), now()) $$,
  '23514', null, 'report reasons are 1–8'
);
insert into public.blocks (blocker_user_id, blocked_user_id, quadrant) values
  ('10aaaaaa-0000-4000-8000-00000000000a', '10bbbbbb-0000-4000-8000-00000000000b', 'storm'),
  ('10cccccc-0000-4000-8000-00000000000c', '10aaaaaa-0000-4000-8000-00000000000a', 'rain');
select throws_ok(
  $$ insert into public.blocks (blocker_user_id, blocked_user_id) values ('10aaaaaa-0000-4000-8000-00000000000a', '10aaaaaa-0000-4000-8000-00000000000a') $$,
  '23514', null, 'nobody can block themselves'
);

-- Room purge: memberships, gestures and mutes go with the room; the report loses its room link; evidence stays.
insert into public.room_gestures (room_id, from_member_id, to_member_id, type, target)
values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', '1000000b-0000-4000-8000-0000000000a1', 'warm_tea', 'member');
insert into public.room_mutes (room_id, muter_member_id, muted_member_id)
values ('10000000-0000-4000-8000-0000000000a1', '1000000a-0000-4000-8000-0000000000a1', '1000000b-0000-4000-8000-0000000000a1');
delete from public.rooms where id = '10000000-0000-4000-8000-0000000000a1';
select is((select count(*)::int from public.room_members where room_id = '10000000-0000-4000-8000-0000000000a1'), 0, 'purge: memberships (pseudonyms) are gone');
select is((select count(*)::int from public.room_gestures where room_id = '10000000-0000-4000-8000-0000000000a1'), 0, 'purge: gestures are gone');
select is((select count(*)::int from public.room_mutes where room_id = '10000000-0000-4000-8000-0000000000a1'), 0, 'purge: mutes are gone');
select results_eq(
  $$ select room_id, target_member_id from public.reports where id = '10000000-0000-4000-8000-00000000e001' $$,
  $$ values (null::uuid, null::uuid) $$,
  'purge: the report keeps its lane item but loses the room links'
);
select is((select count(*)::int from public.evidence_holds where id = '10000000-0000-4000-8000-00000000f001'), 1, 'purge: the evidence snapshot survives (180-day hold)');

-- Account deletion (auth.users cascade): blocks go both ways, reports are de-identified, evidence stays (legal hold).
delete from auth.users where id = '10aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.blocks where '10aaaaaa-0000-4000-8000-00000000000a' in (blocker_user_id, blocked_user_id)), 0,
  'account deletion removes blocks in both directions');
select is((select target_user_id from public.reports where id = '10000000-0000-4000-8000-00000000e001'), null,
  'account deletion de-identifies reports about the account');
select is((select count(*)::int from public.evidence_holds where '10aaaaaa-0000-4000-8000-00000000000a' = any(account_ids)), 1,
  'the evidence hold about the account survives its deletion (LEGAL_HOLD_TABLES)');
delete from auth.users where id = '10cccccc-0000-4000-8000-00000000000c';
select is((select reporter_user_id from public.reports where id = '10000000-0000-4000-8000-00000000e001'), null,
  'deleting the reporter keeps the report in its lane, without the reporter link');

select * from finish();
rollback;
