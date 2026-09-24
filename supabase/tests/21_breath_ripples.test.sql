-- F7 Breath Ripples (migration 20261005000021, contracts/api/v1-ripples.md):
--   * every new public table is server-only: RLS on, no public policies, no client privileges;
--   * echo_library is a separate schema with no FKs, no client access and no column that joins back to anyone;
--   * Realtime authorization: human seat holders read AND write their `game:` topic (Broadcast + Presence) until they
--     leave or the session ends; room members read the `ripples:` invite hints; nobody else; room topics unchanged;
--   * DB backstops (seat shapes, pseudonyms, tickets) and cascades (session purge, account purge).
begin;
create extension if not exists pgtap with schema extensions;

select plan(63);

-- ---------------------------------------------------------------- shape
select has_table('public', t, format('public.%s exists', t))
from unnest(array['ripple_config','ripple_invites','ripple_sessions','ripple_seats','ripple_tickets','ripple_session_log']) t;
select has_table('echo_library', 'recordings', 'echo_library.recordings exists');

select is((select count(*)::int from public.ripple_config), 1, 'ripple_config has exactly one row');
select results_eq(
  $$ select seat_count::int, early_start_s, early_start_min_humans::int, max_wait_s, invite_window_s, settle_ms, inhale_ms, exhale_ms,
            cycles::int, fade_ms, echo_min_cycles::int, echo_min_completion::float8, echo_max_median_offset_ms, echo_library_min,
            echo_retention_d, session_retention_d, events_per_s_cap::int
       from public.ripple_config $$,
  $$ values (4, 8, 2, 20, 20, 10000, 4000, 6000, 16, 10000, 12, 0.9::float8, 600, 50, 90, 7, 10) $$,
  'ripple_config defaults: 4 seats; 8 s with 2 / 20 s max; 10 s + 16 × (4 + 6) + 10 s; echo rules; 7 / 90 days; 10 events/s'
);
select is((select enabled from public.feature_flags where key = 'ripples_enabled'), true, 'kill switch ripples_enabled exists (on)');
select is((select enabled from public.feature_flags where key = 'ripples_echoes'), true, 'kill switch ripples_echoes exists (on)');

-- ---------------------------------------------------------------- server-only
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.ripple_config','public.ripple_invites','public.ripple_sessions','public.ripple_seats','public.ripple_tickets',
  'public.ripple_session_log','echo_library.recordings']::regclass[])), 'RLS enabled on every ripples table');
select is_empty(
  $$ select tablename from pg_policies where schemaname in ('public','echo_library') and tablename like any(array['ripple%','recordings']) $$,
  'no client policies on any ripples table (DS-10: only through NestJS)'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['ripple_config','ripple_invites','ripple_sessions','ripple_seats','ripple_tickets','ripple_session_log']) t
cross join unnest(array['anon','authenticated']) r;
select ok(not has_schema_privilege('authenticated', 'echo_library', 'USAGE') and not has_schema_privilege('anon', 'echo_library', 'USAGE'),
  'clients cannot even see the echo_library schema');
select ok(not has_table_privilege('authenticated', 'echo_library.recordings', 'SELECT, INSERT'), 'clients cannot read or write echoes');
select ok(has_function_privilege('authenticated', 'public.ripples_topic_allowed(text)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.ripples_topic_allowed(text)', 'EXECUTE'),
  'ripples_topic_allowed: callable by signed-in users (Realtime evaluates the policy as them), not anon');

-- ---------------------------------------------------------------- REQ-GAME-07: echoes are unlinked
select is(
  array(select column_name::text from information_schema.columns where table_schema = 'echo_library' and table_name = 'recordings' order by 1),
  array['completion','id','iso_week','median_offset_ms','offsets','pacer_version'],
  'echo recordings hold offsets, pacer version, completion, median offset and ISO week only'
);
select is_empty(
  $$ select 1 from information_schema.table_constraints where table_schema = 'echo_library' and constraint_type = 'FOREIGN KEY' $$,
  'echo_library has no foreign keys'
);
select is_empty(
  $$ select 1 from information_schema.columns where table_schema = 'echo_library'
       and (column_name ~ '(user|account|member|device|session|seat|birth|age|minor)' or data_type like 'timestamp%') $$,
  'no account / member / device / session / age column and no timestamp in echo_library'
);
select throws_ok($$ insert into echo_library.recordings (pacer_version, offsets, completion, median_offset_ms, iso_week) values (1, '{41}', 1, 0, '2026-W41') $$,
  '23514', null, 'offsets beyond ±40 steps (±2 s) are refused');
select throws_ok($$ insert into echo_library.recordings (pacer_version, offsets, completion, median_offset_ms, iso_week) values (1, '{0}', 1, 0, '2026-10-08') $$,
  '23514', null, 'only an ISO week, never a date');
select lives_ok($$ insert into echo_library.recordings (pacer_version, offsets, completion, median_offset_ms, iso_week) values (1, '{0,-1,null,2}', 0.75, 50, '2026-W41') $$,
  'a valid echo (nulls = missed transitions)');

-- ---------------------------------------------------------------- reports / evidence kinds (additive)
select ok(pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_target_kind_check')) ~ 'ripple_seat'
      and pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_target_kind_check')) ~ 'reflection',
  'reports.target_kind gains ripple_seat and keeps reflection');
select ok(pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_auto_signal_check')) ~ 'ripple_flood'
      and pg_get_constraintdef((select oid from pg_constraint where conname = 'reports_auto_signal_check')) ~ 'gesture_flood',
  'reports.auto_signal gains ripple_flood and keeps gesture_flood');
select ok(pg_get_constraintdef((select oid from pg_constraint where conname = 'evidence_holds_item_kind_check')) ~ 'ripple_seat',
  'evidence_holds.item_kind gains ripple_seat');

-- ---------------------------------------------------------------- fixtures (as postgres)
insert into auth.users (id, email, aud, role) values
  ('21aaaaaa-0000-4000-8000-00000000000a', 'pgtap-ripples-a@aura.test', 'authenticated', 'authenticated'),
  ('21bbbbbb-0000-4000-8000-00000000000b', 'pgtap-ripples-b@aura.test', 'authenticated', 'authenticated'),
  ('21cccccc-0000-4000-8000-00000000000c', 'pgtap-ripples-c@aura.test', 'authenticated', 'authenticated'),
  ('21dddddd-0000-4000-8000-00000000000d', 'pgtap-ripples-d@aura.test', 'authenticated', 'authenticated');

insert into public.ripple_sessions (id, entry, start_rule, t0, settle_ms, inhale_ms, exhale_ms, cycles, fade_ms, pacer_version, ends_at, purge_at)
values ('21000000-0000-4000-8000-0000000000a1', 'quick', 'early', now(), 10000, 4000, 6000, 16, 10000, 1,
        now() + interval '180 seconds', now() + interval '7 days');
insert into public.ripple_seats (id, session_id, seat, kind, user_id, pseudonym) values
  ('21000001-0000-4000-8000-0000000000a1', '21000000-0000-4000-8000-0000000000a1', 1, 'human', '21aaaaaa-0000-4000-8000-00000000000a', 'Quiet Comet'),
  ('21000002-0000-4000-8000-0000000000a1', '21000000-0000-4000-8000-0000000000a1', 2, 'human', '21bbbbbb-0000-4000-8000-00000000000b', 'Gentle Moon');
insert into public.ripple_seats (session_id, seat, kind) values ('21000000-0000-4000-8000-0000000000a1', 3, 'guide');
update public.ripple_seats set left_at = now() where id = '21000002-0000-4000-8000-0000000000a1';

insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at) values
  ('21000000-0000-4000-8000-0000000000b1', 'en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary', now(),
   now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
values ('2100000c-0000-4000-8000-0000000000b1', '21000000-0000-4000-8000-0000000000b1', '21cccccc-0000-4000-8000-00000000000c',
        'Soft Star', 'lonely', 'rain', 'en', 'south_asia', 4, 'spark');

insert into realtime.messages (topic, extension, payload, event, private) values
  ('game:21000000-0000-4000-8000-0000000000a1', 'broadcast', '{}', 'probe', true),
  ('game:21000000-0000-4000-8000-0000000000a1', 'presence', '{}', 'probe', true),
  ('ripples:21000000-0000-4000-8000-0000000000b1', 'broadcast', '{}', 'probe', true),
  ('room:21000000-0000-4000-8000-0000000000b1', 'presence', '{}', 'probe', true);

create temp table rt21 (who uuid, topic text, ext text, expect int) on commit drop;
insert into rt21 values
  ('21aaaaaa-0000-4000-8000-00000000000a', 'game:21000000-0000-4000-8000-0000000000a1', 'broadcast', 1),     -- seated human
  ('21aaaaaa-0000-4000-8000-00000000000a', 'game:21000000-0000-4000-8000-0000000000a1', 'presence', 1),      -- Presence too
  ('21bbbbbb-0000-4000-8000-00000000000b', 'game:21000000-0000-4000-8000-0000000000a1', 'broadcast', 0),     -- left the session
  ('21cccccc-0000-4000-8000-00000000000c', 'game:21000000-0000-4000-8000-0000000000a1', 'broadcast', 0),     -- never seated
  ('21cccccc-0000-4000-8000-00000000000c', 'ripples:21000000-0000-4000-8000-0000000000b1', 'broadcast', 1),  -- room member: invite hints
  ('21aaaaaa-0000-4000-8000-00000000000a', 'ripples:21000000-0000-4000-8000-0000000000b1', 'broadcast', 0),  -- not a member
  ('21cccccc-0000-4000-8000-00000000000c', 'room:21000000-0000-4000-8000-0000000000b1', 'presence', 0);      -- room Presence stays closed
grant select on rt21 to authenticated;

create temp table rt21_result (who uuid, topic text, ext text, got int) on commit drop;
do $$
declare c record; n int;
begin
  for c in select * from rt21 loop
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', c.who, 'role', 'authenticated')::text, true);
    perform set_config('realtime.topic', c.topic, true);
    select count(*) into n from realtime.messages where topic = c.topic and extension = c.ext;
    perform set_config('role', 'postgres', true);
    insert into rt21_result values (c.who, c.topic, c.ext, n);
  end loop;
end $$;
reset role;
select is(r.got, c.expect, format('realtime: %s reading %s (%s) → %s', c.who, c.topic, c.ext, c.expect))
from rt21 c join rt21_result r on r.who = c.who and r.topic = c.topic and r.ext = c.ext
order by c.who, c.topic, c.ext;

-- Writes: breath events go client to client on the player's own game topic only.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"21aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select set_config('realtime.topic', 'game:21000000-0000-4000-8000-0000000000a1', true);
select lives_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                   values ('game:21000000-0000-4000-8000-0000000000a1', 'broadcast', '{"seat":1,"phase":"in","t":1}', 'breath_state', true) $$,
  'realtime: a seated player may broadcast on the game topic');
select lives_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                   values ('game:21000000-0000-4000-8000-0000000000a1', 'presence', '{"seat":1}', 'presence', true) $$,
  'realtime: a seated player may track Presence');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"21bbbbbb-0000-4000-8000-00000000000b","role":"authenticated"}', true);
select set_config('realtime.topic', 'game:21000000-0000-4000-8000-0000000000a1', true);
select throws_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                    values ('game:21000000-0000-4000-8000-0000000000a1', 'broadcast', '{}', 'breath_state', true) $$,
  '42501', null, 'realtime: after leaving, no more broadcasts');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"21cccccc-0000-4000-8000-00000000000c","role":"authenticated"}', true);
select set_config('realtime.topic', 'ripples:21000000-0000-4000-8000-0000000000b1', true);
select throws_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                    values ('ripples:21000000-0000-4000-8000-0000000000b1', 'broadcast', '{}', 'ripple_invite', true) $$,
  '42501', null, 'realtime: invite hints are server-only (members cannot forge one)');
select set_config('realtime.topic', 'room:21000000-0000-4000-8000-0000000000b1', true);
select throws_ok($$ insert into realtime.messages (topic, extension, payload, event, private)
                    values ('room:21000000-0000-4000-8000-0000000000b1', 'broadcast', '{}', 'forged', true) $$,
  '42501', null, 'realtime: room topics stay server-only');
select throws_ok($$ select * from public.ripple_seats $$, '42501', null, 'authenticated cannot read seats');
reset role;

-- Ended sessions and sanctioned / deleting accounts lose the topic.
insert into public.sanctions (user_id, kind, reason_code, source, ends_at)
values ('21aaaaaa-0000-4000-8000-00000000000a', 'room_suspension', 'pgtap', 'moderator', now() + interval '1 day');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"21aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.ripples_topic_allowed('game:21000000-0000-4000-8000-0000000000a1'), false, 'realtime: a suspended account is refused');
reset role;
update public.sanctions set lifted_at = now() where user_id = '21aaaaaa-0000-4000-8000-00000000000a';
update public.ripple_sessions set ended_at = now() where id = '21000000-0000-4000-8000-0000000000a1';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"21aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is(public.ripples_topic_allowed('game:21000000-0000-4000-8000-0000000000a1'), false, 'realtime: an ended session is closed');
select is(public.ripples_topic_allowed('room:21000000-0000-4000-8000-0000000000b1'), false, 'ripples_topic_allowed never opens room topics');
reset role;

-- ---------------------------------------------------------------- backstops
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind, user_id) values ('21000000-0000-4000-8000-0000000000a1', 4, 'human', '21cccccc-0000-4000-8000-00000000000c') $$,
  '23514', null, 'a human seat always has a pseudonym');
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind, user_id, pseudonym) values ('21000000-0000-4000-8000-0000000000a1', 4, 'guide', '21cccccc-0000-4000-8000-00000000000c', 'Soft Star') $$,
  '23514', null, 'echo / guide seats never hold an account');
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind, echo_id) values ('21000000-0000-4000-8000-0000000000a1', 4, 'guide', gen_random_uuid()) $$,
  '23514', null, 'only echo seats reference a recording');
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind, user_id, pseudonym) values ('21000000-0000-4000-8000-0000000000a1', 4, 'human', '21cccccc-0000-4000-8000-00000000000c', 'Call 98765') $$,
  '23514', null, 'a seat label can never carry digits or contact-like text');
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind, user_id, pseudonym) values ('21000000-0000-4000-8000-0000000000a1', 4, 'human', '21cccccc-0000-4000-8000-00000000000c', 'Quiet Comet') $$,
  '23505', null, 'pseudonyms are unique within a session');
select throws_ok($$ insert into public.ripple_seats (session_id, seat, kind) values ('21000000-0000-4000-8000-0000000000a1', 1, 'guide') $$,
  '23505', null, 'one light per seat');
insert into public.ripple_tickets (id, user_id, entry) values ('21000000-0000-4000-8000-0000000000c1', '21dddddd-0000-4000-8000-00000000000d', 'quick');
select throws_ok($$ insert into public.ripple_tickets (id, user_id, entry) values ('21000000-0000-4000-8000-0000000000c2', '21dddddd-0000-4000-8000-00000000000d', 'quick') $$,
  '23505', null, 'one waiting ticket per account');
select throws_ok($$ insert into public.ripple_tickets (id, user_id, entry) values ('21000000-0000-4000-8000-0000000000c3', '21cccccc-0000-4000-8000-00000000000c', 'room') $$,
  '23514', null, 'a room ticket always names its room, membership and invite');

-- ---------------------------------------------------------------- cascades
delete from auth.users where id = '21aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.ripple_seats where session_id = '21000000-0000-4000-8000-0000000000a1'), 2,
  'account purge removes the account''s seat (other seats stay)');
insert into public.ripple_session_log (session_id, seat, event) values ('21000000-0000-4000-8000-0000000000a1', 2, 'left');
delete from public.ripple_sessions where id = '21000000-0000-4000-8000-0000000000a1';
select is((select count(*)::int from public.ripple_seats where session_id = '21000000-0000-4000-8000-0000000000a1')
        + (select count(*)::int from public.ripple_session_log where session_id = '21000000-0000-4000-8000-0000000000a1'), 0,
  'the 7-day purge of a session removes its seats and event log');

select * from finish();
rollback;
