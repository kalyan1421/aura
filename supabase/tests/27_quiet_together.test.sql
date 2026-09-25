-- F16 Quiet Together + Lantern Hour wind-down (migration 20261005000027, contracts/api/v1-quiet.md):
--   * every new public table is server-only: RLS on, no public policies, no client privileges (DS-10, REQ-QUIET-01);
--   * content-free: no text, mood, pseudonym, age or silhouette column anywhere in Quiet Together;
--   * Realtime authorization: current members READ their `quiet:` topic until the block ends; nobody writes to it
--     (no client broadcast, no Presence); left members, other people, suspended / deleting accounts are refused;
--   * DB backstops (one active membership, gesture presets, rhythm shape) and cascades (session purge, account purge);
--   * the wind-down is a room total: `room_members.wind_down_at` stays unreadable to clients like the rest of rooms;
--   * report / evidence kinds gain `quiet_session` and keep every earlier kind; both kill switches exist.
begin;
create extension if not exists pgtap with schema extensions;

select plan(50);

-- ---------------------------------------------------------------- shape
select has_table('public', t, format('public.%s exists', t))
from unnest(array['quiet_config','quiet_sessions','quiet_members','quiet_gestures']) t;
select has_column('public', 'room_members', 'wind_down_at', 'room_members.wind_down_at (wind-down opt-in) exists');
select has_column('public', 'rooms', 'wind_down_broadcast', 'rooms.wind_down_broadcast (tick cache) exists');

select is((select count(*)::int from public.quiet_config), 1, 'quiet_config has exactly one row');
select results_eq(
  $$ select block_min::int, capacity::int, thin_live_min::int, live_window_s, heartbeat_ms, focus_min::int, break_min::int,
            gesture_min_interval_ms, gesture_hour_max, gesture_limit_hits_to_mute::int, gesture_shadow_mute_h::int,
            retention_d, wind_down_start::text, wind_down_min::int, wind_down_inhale_ms, wind_down_exhale_ms
       from public.quiet_config $$,
  $$ values (60, 50, 3, 90, 30000, 25, 5, 10000, 20, 3, 24, 7, '22:30:00'::text, 20, 4000, 6000) $$,
  'quiet_config defaults: 60-min blocks, 50 per session, 25/5, 1 gesture / 10 s and 20 / hour, 7 days; wind-down 22:30 for 20 min on Calm 4/6'
);
select throws_ok($$ update public.quiet_config set focus_min = 20 $$, '23514', null, 'the rhythm always tiles the block (2 × (focus + break) = 60)');
select is((select enabled from public.feature_flags where key = 'quiet_enabled'), true, 'kill switch quiet_enabled exists (on)');
select is((select enabled from public.feature_flags where key = 'lantern_wind_down_enabled'), true, 'kill switch lantern_wind_down_enabled exists (on)');
select ok((select payload ? 'pausedRegions' from public.feature_flags where key = 'quiet_enabled')
      and (select payload ? 'pausedRegions' from public.feature_flags where key = 'lantern_wind_down_enabled'),
  'both kill switches carry a per-region pausedRegions list');

-- ---------------------------------------------------------------- server-only
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.quiet_config','public.quiet_sessions','public.quiet_members','public.quiet_gestures']::regclass[])),
  'RLS enabled on every Quiet Together table');
select is_empty(
  $$ select tablename from pg_policies where schemaname = 'public' and tablename like 'quiet%' $$,
  'no client policies on any Quiet Together table (DS-10: only through NestJS, counts only)'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['quiet_config','quiet_sessions','quiet_members','quiet_gestures']) t
cross join unnest(array['anon','authenticated']) r;
select ok(has_function_privilege('authenticated', 'public.quiet_topic_allowed(text)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.quiet_topic_allowed(text)', 'EXECUTE'),
  'quiet_topic_allowed: callable by signed-in users (Realtime evaluates the policy as them), not anon');

-- ---------------------------------------------------------------- content-free (REQ-QUIET-01)
select is_empty(
  $$ select table_name || '.' || column_name from information_schema.columns
      where table_schema = 'public' and table_name like 'quiet%'
        and column_name ~ '(pseudonym|mood|note|text|body|birth|dob|age|minor|silhouette|stage|hue|audio|voice)' $$,
  'no pseudonym, mood, text, age, silhouette or audio column in Quiet Together'
);

-- ---------------------------------------------------------------- reports / evidence kinds (additive)
select ok(pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_target_kind_check')) ~ 'quiet_session'
      and pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_target_kind_check')) ~ 'ripple_seat'
      and pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_target_kind_check')) ~ 'reflection',
  'reports.target_kind gains quiet_session and keeps ripple_seat and reflection');
select ok(pg_get_constraintdef((select oid from pg_constraint where conname = 'evidence_holds_item_kind_check')) ~ 'quiet_session'
      and pg_get_constraintdef((select oid from pg_constraint where conname = 'evidence_holds_item_kind_check')) ~ 'ripple_seat',
  'evidence_holds.item_kind gains quiet_session and keeps ripple_seat');

-- ---------------------------------------------------------------- fixtures (as postgres)
insert into auth.users (id, email, aud, role) values
  ('27aaaaaa-0000-4000-8000-00000000000a', 'pgtap-quiet-a@aura.test', 'authenticated', 'authenticated'),
  ('27bbbbbb-0000-4000-8000-00000000000b', 'pgtap-quiet-b@aura.test', 'authenticated', 'authenticated'),
  ('27cccccc-0000-4000-8000-00000000000c', 'pgtap-quiet-c@aura.test', 'authenticated', 'authenticated');

insert into public.quiet_sessions (id, mode, tz_region, t0, ends_at, soundscape_seed, capacity, purge_at) values
  ('27000000-0000-4000-8000-0000000000a1', 'study', 'south_asia', date_trunc('hour', now()), date_trunc('hour', now()) + interval '60 minutes', 42, 50,
   date_trunc('hour', now()) + interval '60 minutes' + interval '7 days');
insert into public.quiet_members (member_id, session_id, user_id, home_region) values
  ('27000001-0000-4000-8000-0000000000a1', '27000000-0000-4000-8000-0000000000a1', '27aaaaaa-0000-4000-8000-00000000000a', 'south_asia'),
  ('27000002-0000-4000-8000-0000000000a1', '27000000-0000-4000-8000-0000000000a1', '27bbbbbb-0000-4000-8000-00000000000b', 'south_asia');
update public.quiet_members set left_at = now() where member_id = '27000002-0000-4000-8000-0000000000a1';
insert into public.quiet_gestures (session_id, member_id, type) values
  ('27000000-0000-4000-8000-0000000000a1', '27000001-0000-4000-8000-0000000000a1', 'light_a_candle');

insert into realtime.messages (topic, extension, payload, event, private) values
  ('quiet:27000000-0000-4000-8000-0000000000a1', 'broadcast', '{"count":1}', 'count', true),
  ('quiet:27000000-0000-4000-8000-0000000000a1', 'presence', '{}', 'probe', true);

create temp table rt27 (who uuid, topic text, ext text, expect int) on commit drop;
insert into rt27 values
  ('27aaaaaa-0000-4000-8000-00000000000a', 'quiet:27000000-0000-4000-8000-0000000000a1', 'broadcast', 1),  -- current member
  ('27aaaaaa-0000-4000-8000-00000000000a', 'quiet:27000000-0000-4000-8000-0000000000a1', 'presence', 0),   -- no Presence at all
  ('27bbbbbb-0000-4000-8000-00000000000b', 'quiet:27000000-0000-4000-8000-0000000000a1', 'broadcast', 0),  -- left
  ('27cccccc-0000-4000-8000-00000000000c', 'quiet:27000000-0000-4000-8000-0000000000a1', 'broadcast', 0);  -- never joined
grant select on rt27 to authenticated;

create temp table rt27_result (who uuid, topic text, ext text, got int) on commit drop;
do $$
declare c record; n int;
begin
  for c in select * from rt27 loop
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', c.who, 'role', 'authenticated')::text, true);
    perform set_config('realtime.topic', c.topic, true);
    select count(*) into n from realtime.messages where topic = c.topic and extension = c.ext;
    perform set_config('role', 'postgres', true);
    insert into rt27_result values (c.who, c.topic, c.ext, n);
  end loop;
end $$;
reset role;
select is(r.got, c.expect, format('realtime: %s reading %s (%s) → %s', c.who, c.topic, c.ext, c.expect))
from rt27 c join rt27_result r on r.who = c.who and r.topic = c.topic and r.ext = c.ext
order by c.who, c.topic, c.ext;

-- Nobody writes to a quiet topic: counts and gestures come from the server only.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"27aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select set_config('realtime.topic', 'quiet:27000000-0000-4000-8000-0000000000a1', true);
select throws_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                    values ('quiet:27000000-0000-4000-8000-0000000000a1', 'broadcast', '{"type":"hug"}', 'gesture', true) $$,
  '42501', null, 'realtime: a member cannot broadcast on the quiet topic (no forged gestures or counts)');
select throws_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                    values ('quiet:27000000-0000-4000-8000-0000000000a1', 'presence', '{}', 'presence', true) $$,
  '42501', null, 'realtime: no per-member Presence on the quiet topic');
select throws_ok($$ select * from public.quiet_members $$, '42501', null, 'authenticated cannot read memberships');
select throws_ok($$ select * from public.quiet_sessions $$, '42501', null, 'authenticated cannot read sessions');
select throws_ok($$ select wind_down_at from public.room_members $$, '42501', null, 'the wind-down opt-in is not client-readable');
select is(public.quiet_topic_allowed('room:27000000-0000-4000-8000-0000000000a1'), false, 'quiet_topic_allowed never opens room topics');
select is(public.quiet_topic_allowed('game:27000000-0000-4000-8000-0000000000a1'), false, 'quiet_topic_allowed never opens game topics');
reset role;

-- Sanctioned / deleting accounts and ended blocks lose the topic.
insert into public.sanctions (user_id, kind, reason_code, source, ends_at)
values ('27aaaaaa-0000-4000-8000-00000000000a', 'room_suspension', 'pgtap', 'moderator', now() + interval '1 day');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"27aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.quiet_topic_allowed('quiet:27000000-0000-4000-8000-0000000000a1'), false, 'realtime: a suspended account is refused');
reset role;
update public.sanctions set lifted_at = now() where user_id = '27aaaaaa-0000-4000-8000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"27aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.quiet_topic_allowed('quiet:27000000-0000-4000-8000-0000000000a1'), true, 'realtime: the sanction lifted, the member may listen again');
reset role;
insert into public.account_deletions (user_id, scheduled_for) values ('27aaaaaa-0000-4000-8000-00000000000a', now() + interval '7 days');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"27aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.quiet_topic_allowed('quiet:27000000-0000-4000-8000-0000000000a1'), false, 'realtime: an account pending deletion is refused');
reset role;
delete from public.account_deletions where user_id = '27aaaaaa-0000-4000-8000-00000000000a';
update public.quiet_sessions set t0 = t0 - interval '3 hours', ends_at = ends_at - interval '3 hours' where id = '27000000-0000-4000-8000-0000000000a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"27aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.quiet_topic_allowed('quiet:27000000-0000-4000-8000-0000000000a1'), false, 'realtime: an ended block is closed (+2 min grace)');
reset role;

-- ---------------------------------------------------------------- backstops
select throws_ok($$ insert into public.quiet_members (session_id, user_id, home_region) values ('27000000-0000-4000-8000-0000000000a1', '27aaaaaa-0000-4000-8000-00000000000a', 'south_asia') $$,
  '23505', null, 'one active Quiet Together membership per account');
select lives_ok($$ insert into public.quiet_members (session_id, user_id, home_region) values ('27000000-0000-4000-8000-0000000000a1', '27bbbbbb-0000-4000-8000-00000000000b', 'south_asia') $$,
  'a person who left may drop in again');
select throws_ok($$ insert into public.quiet_gestures (session_id, member_id, type) values ('27000000-0000-4000-8000-0000000000a1', '27000001-0000-4000-8000-0000000000a1', 'hello there') $$,
  '23514', null, 'gestures are presets only (no text)');
select throws_ok($$ insert into public.quiet_sessions (mode, tz_region, t0, ends_at, soundscape_seed, capacity, purge_at) values ('party', 'south_asia', now(), now() + interval '1 hour', 1, 50, now() + interval '8 days') $$,
  '23514', null, 'modes are study / read / rest');
select throws_ok($$ insert into public.quiet_sessions (mode, tz_region, t0, ends_at, soundscape_seed, capacity, purge_at) values ('rest', 'south_asia', now(), now() - interval '1 hour', 1, 50, now() + interval '8 days') $$,
  '23514', null, 'a block ends after it starts');

-- ---------------------------------------------------------------- cascades
delete from public.quiet_sessions where id = '27000000-0000-4000-8000-0000000000a1';
select is((select count(*)::int from public.quiet_members where session_id = '27000000-0000-4000-8000-0000000000a1'), 0,
  'purging a session removes its memberships');
select is((select count(*)::int from public.quiet_gestures where session_id = '27000000-0000-4000-8000-0000000000a1'), 0,
  'purging a session removes its gesture log');

insert into public.quiet_sessions (id, mode, tz_region, t0, ends_at, soundscape_seed, capacity, purge_at) values
  ('27000000-0000-4000-8000-0000000000a2', 'rest', 'europe_africa', now(), now() + interval '60 minutes', 7, 50, now() + interval '8 days');
insert into public.quiet_members (member_id, session_id, user_id, home_region) values
  ('27000003-0000-4000-8000-0000000000a2', '27000000-0000-4000-8000-0000000000a2', '27cccccc-0000-4000-8000-00000000000c', 'europe_africa');
insert into public.quiet_gestures (session_id, member_id, type) values
  ('27000000-0000-4000-8000-0000000000a2', '27000003-0000-4000-8000-0000000000a2', 'stargaze');
delete from auth.users where id = '27cccccc-0000-4000-8000-00000000000c';
select is((select count(*)::int from public.quiet_members where member_id = '27000003-0000-4000-8000-0000000000a2'), 0,
  'deleting the account removes its memberships');
select is((select count(*)::int from public.quiet_gestures where member_id = '27000003-0000-4000-8000-0000000000a2'), 0,
  'and its gesture log');

select * from finish();
rollback;
