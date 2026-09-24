-- Sanctuary sessions + F14 Milestone B + reduced mode (migration 20261005000023):
--   * sanctuary_sessions: content-free columns, closed activity/variant lists, duration bounds, select-own (RLS), no
--     client writes, no console access, cascades with the account;
--   * notification_prefs: the Milestone B settings with their defaults and shape checks (habit_nudges ids → HH:MM);
--   * notification_schedule / notification_activity / gesture_push_log: server-only, personal (cascade);
--   * activity triggers: a sync mutation or an install sighting ends an absence (welcome-back step back to 0);
--   * reduced mode's flag describes the sign-up throttle.
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin;

select plan(42);

insert into auth.users (id, email, aud, role) values
  ('23aaaaaa-0000-4000-8000-00000000000a', 'pgtap-sanct-a@aura.test', 'authenticated', 'authenticated'),
  ('23bbbbbb-0000-4000-8000-00000000000b', 'pgtap-sanct-b@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone, country) values
  ('23aaaaaa-0000-4000-8000-00000000000a', '2000-01-01', 'en', 'en', 'Asia/Kolkata', 'IN'),
  ('23bbbbbb-0000-4000-8000-00000000000b', '1995-05-05', 'te', 'te', 'Asia/Kolkata', 'IN');

-- ---------------------------------------------------------------- sanctuary_sessions: shape
select has_table('public', 'sanctuary_sessions', 'sanctuary_sessions exists');
select columns_are('public', 'sanctuary_sessions',
  array['id', 'user_id', 'activity', 'variant', 'duration_s', 'local_day', 'device_ts', 'server_ts'],
  'only content-free columns: no text, audio, stems or mood');
select col_is_pk('public', 'sanctuary_sessions', 'id', 'the client id is the key (idempotent)');

select lives_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts) values
       ('23aaaaaa-5000-7000-8000-000000000001', '23aaaaaa-0000-4000-8000-00000000000a', 'breathe', 'calm', 64, '2026-10-08', '2026-10-08T15:00:00Z'),
       ('23aaaaaa-5000-7000-8000-000000000002', '23aaaaaa-0000-4000-8000-00000000000a', 'grounding', 'senses', 120, '2026-10-08', '2026-10-08T15:10:00Z'),
       ('23aaaaaa-5000-7000-8000-000000000003', '23aaaaaa-0000-4000-8000-00000000000a', 'stillness', 'orb', 60, '2026-10-08', '2026-10-08T15:20:00Z'),
       ('23aaaaaa-5000-7000-8000-000000000004', '23aaaaaa-0000-4000-8000-00000000000a', 'savour', 'moment', 90, '2026-10-08', '2026-10-08T15:30:00Z'),
       ('23aaaaaa-5000-7000-8000-000000000005', '23aaaaaa-0000-4000-8000-00000000000a', 'sounds', 'timer_30', 1800, '2026-10-08', '2026-10-08T16:00:00Z'),
       ('23aaaaaa-5000-7000-8000-000000000006', '23aaaaaa-0000-4000-8000-00000000000a', 'night_wind_down', 'v1', 1200, '2026-10-08', '2026-10-08T17:00:00Z'),
       ('23bbbbbb-5000-7000-8000-000000000001', '23bbbbbb-0000-4000-8000-00000000000b', 'breathe', '478', 76, '2026-10-08', '2026-10-08T15:00:00Z') $$,
  'every activity with one of its variants'
);
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000011', '23aaaaaa-0000-4000-8000-00000000000a', 'journal', 'v1', 60, '2026-10-08', now()) $$,
  '23514', null, 'unknown activity refused');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000012', '23aaaaaa-0000-4000-8000-00000000000a', 'grounding', 'three good things today', 60, '2026-10-08', now()) $$,
  '23514', null, 'free text in the variant refused (closed list per activity)');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000013', '23aaaaaa-0000-4000-8000-00000000000a', 'breathe', 'senses', 60, '2026-10-08', now()) $$,
  '23514', null, 'another activity''s variant refused');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000014', '23aaaaaa-0000-4000-8000-00000000000a', 'breathe', 'calm', 0, '2026-10-08', now()) $$,
  '23514', null, 'a zero-second session refused');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000015', '23aaaaaa-0000-4000-8000-00000000000a', 'sounds', 'open', 43201, '2026-10-08', now()) $$,
  '23514', null, 'more than 12 h refused');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000001', '23bbbbbb-0000-4000-8000-00000000000b', 'breathe', 'calm', 60, '2026-10-08', now()) $$,
  '23505', null, 'one row per record id');

-- ---------------------------------------------------------------- sanctuary_sessions: access
select ok((select relrowsecurity from pg_class where oid = 'public.sanctuary_sessions'::regclass), 'RLS on sanctuary_sessions');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"23aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.sanctuary_sessions), 6, 'the owner reads their own sessions');
select is((select count(*)::int from public.sanctuary_sessions where user_id = '23bbbbbb-0000-4000-8000-00000000000b'), 0,
  'and never anyone else''s');
select throws_ok(
  $$ insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
     values ('23aaaaaa-5000-7000-8000-000000000021', '23aaaaaa-0000-4000-8000-00000000000a', 'breathe', 'calm', 60, '2026-10-08', now()) $$,
  '42501', null, 'the app cannot write sessions (POST /v1/sync/push only)');
select throws_ok($$ delete from public.sanctuary_sessions $$, '42501', null, 'nor delete them');
select throws_ok($$ select * from public.notification_schedule $$, '42501', null, 'notification_schedule: server-only');
select throws_ok($$ select * from public.notification_activity $$, '42501', null, 'notification_activity: server-only');
select throws_ok($$ select * from public.gesture_push_log $$, '42501', null, 'gesture_push_log: server-only');
reset role;
set local role anon;
select throws_ok($$ select * from public.sanctuary_sessions $$, '42501', null, 'anon cannot read sessions');
reset role;
select ok(
  not has_table_privilege('aura_admin', 'public.sanctuary_sessions', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('aura_admin', 'public.notification_schedule', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('aura_admin', 'public.notification_activity', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('aura_admin', 'public.gesture_push_log', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'the console role reaches none of them');
select ok((select bool_and(relrowsecurity) from pg_class where oid = any(array[
  'public.notification_schedule'::regclass, 'public.notification_activity'::regclass, 'public.gesture_push_log'::regclass])),
  'RLS on the server-only tables');

-- ---------------------------------------------------------------- notification_prefs (Milestone B)
insert into public.notification_prefs (user_id) values ('23aaaaaa-0000-4000-8000-00000000000a');
select row_eq(
  $$ select gestures_enabled, welcome_back_enabled, wind_down_enabled, wind_down_time, wind_down_in_quiet_ok, lantern_opt_in, habit_nudges
       from public.notification_prefs where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  row(true, true, false, null::time, false, false, '{}'::jsonb),
  'defaults: gestures and welcome back on; wind-down, Lantern Hour and habit nudges opt-in (off)');
select lives_ok(
  $$ update public.notification_prefs set habit_nudges = '{"23aaaaaa-4000-7000-8000-000000000001": "09:00"}',
       wind_down_enabled = true, wind_down_time = '22:30' where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  'a habit id → HH:MM map and a wind-down time are accepted');
select throws_ok(
  $$ update public.notification_prefs set habit_nudges = '{"23aaaaaa-4000-7000-8000-000000000001": "Drink water"}'
      where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  '23514', null, 'habit nudges hold times only (no names, no text)');
select throws_ok(
  $$ update public.notification_prefs set habit_nudges = '{"hydrate": "09:00"}' where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  '23514', null, 'keys are habit ids');
select throws_ok(
  $$ update public.notification_prefs set habit_nudges = '["09:00"]' where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  '23514', null, 'an object, not a list');
select throws_ok(
  $$ update public.notification_prefs set wind_down_time = '22:30:15' where user_id = '23aaaaaa-0000-4000-8000-00000000000a' $$,
  '23514', null, 'wind-down times are whole minutes');

-- ---------------------------------------------------------------- schedule + push log
select lives_ok(
  $$ insert into public.notification_schedule (user_id, kind, next_at, tz) values
       ('23aaaaaa-0000-4000-8000-00000000000a', 'wind_down_reminder', now() + interval '1 hour', 'Asia/Kolkata'),
       ('23aaaaaa-0000-4000-8000-00000000000a', 'lantern_hour', now() + interval '2 hours', 'Asia/Kolkata'),
       ('23aaaaaa-0000-4000-8000-00000000000a', 'habit_nudge', now() + interval '3 hours', 'Asia/Kolkata') $$,
  'one planned instant per user-timed kind');
select throws_ok(
  $$ insert into public.notification_schedule (user_id, kind, next_at, tz)
     values ('23aaaaaa-0000-4000-8000-00000000000a', 'daily_reminder', now(), 'Asia/Kolkata') $$,
  '23514', null, 'other kinds are not scheduled here (the daily reminder keeps reminder_next_at)');
select throws_ok(
  $$ insert into public.notification_schedule (user_id, kind, next_at, tz)
     values ('23aaaaaa-0000-4000-8000-00000000000a', 'lantern_hour', now(), 'Asia/Kolkata') $$,
  '23505', null, 'one row per user and kind');

insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at)
values ('23cccccc-0000-4000-8000-00000000000c', 'hi', 'sunrise', 'americas', 'joyful', 'sunrise_deck',
        now() + interval '20 hours', now() + interval '24 hours', now() + interval '8 days');
select lives_ok(
  $$ insert into public.gesture_push_log (user_id, room_id, local_day)
     values ('23aaaaaa-0000-4000-8000-00000000000a', '23cccccc-0000-4000-8000-00000000000c', '2026-10-08') $$,
  'a gestures push is logged per recipient, room and day');
select throws_ok(
  $$ insert into public.gesture_push_log (user_id, room_id, local_day)
     values ('23aaaaaa-0000-4000-8000-00000000000a', '23cccccc-0000-4000-8000-00000000000c', '2026-10-08') $$,
  '23505', null, 'at most one per room per day');
delete from public.rooms where id = '23cccccc-0000-4000-8000-00000000000c';
select is((select count(*)::int from public.gesture_push_log where user_id = '23aaaaaa-0000-4000-8000-00000000000a'), 0,
  'the log goes with the room');

-- ---------------------------------------------------------------- activity triggers (welcome back)
insert into public.notification_activity (user_id, last_active_at, welcome_step, welcome_sent_at)
values ('23bbbbbb-0000-4000-8000-00000000000b', now() - interval '10 days', 1, now() - interval '3 days')
on conflict (user_id) do update set last_active_at = excluded.last_active_at, welcome_step = 1;
insert into public.sync_mutations (user_id, mutation_id, entity, status)
values ('23bbbbbb-0000-4000-8000-00000000000b', '23bbbbbb-9000-7000-8000-000000000001', 'check_in', 'applied');
select ok(
  (select welcome_step = 0 and last_active_at > now() - interval '1 minute' from public.notification_activity
    where user_id = '23bbbbbb-0000-4000-8000-00000000000b'),
  'a sync mutation ends the absence (step back to 0)');
update public.notification_activity set welcome_step = 2, last_active_at = now() - interval '30 days'
 where user_id = '23bbbbbb-0000-4000-8000-00000000000b';
insert into public.device_installs (user_id, install_hash, platform)
values ('23bbbbbb-0000-4000-8000-00000000000b', repeat('d', 64), 'android');
select ok(
  (select welcome_step = 0 and last_active_at > now() - interval '1 minute' from public.notification_activity
    where user_id = '23bbbbbb-0000-4000-8000-00000000000b'),
  'so does an install sighting (profile / device / room calls)');
select throws_ok(
  $$ update public.notification_activity set welcome_step = 3 where user_id = '23bbbbbb-0000-4000-8000-00000000000b' $$,
  '23514', null, 'two welcome-back pushes per absence at most');
select ok(not has_function_privilege('authenticated', 'public.note_account_activity()', 'EXECUTE'),
  'the trigger function is not callable by clients');

-- ---------------------------------------------------------------- purge (cascade) + flag
insert into public.notification_activity (user_id) values ('23aaaaaa-0000-4000-8000-00000000000a') on conflict do nothing;
delete from auth.users where id = '23aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.sanctuary_sessions where user_id = '23aaaaaa-0000-4000-8000-00000000000a'), 0,
  'sessions go with the account');
select is(
  (select count(*)::int from public.notification_schedule where user_id = '23aaaaaa-0000-4000-8000-00000000000a')
  + (select count(*)::int from public.notification_activity where user_id = '23aaaaaa-0000-4000-8000-00000000000a'),
  0, 'the push plan and activity marker go with the account');
select is((select count(*)::int from public.sanctuary_sessions where user_id = '23bbbbbb-0000-4000-8000-00000000000b'), 1,
  'other accounts keep theirs');
select ok((select description like '%sign-ups throttled%signupsPerHour%' from public.feature_flags where key = 'reduced_mode'),
  'reduced mode''s description names the sign-up throttle');
select has_index('public', 'profiles', 'profiles_created_at_idx', 'new sign-ups in the last hour are an index range');

select * from finish();
rollback;
