-- Room lanterns and Tonight's intention (migration 20261005000022, PRD F5 Milestone B, REQ-ROOM-13 / REQ-ROOM-14):
--   * the room totals exist; the level is derived from the progress (0–5);
--   * the lantern never dims and the hold count never falls — refused for every role, the owner included;
--   * the night and the intention are write-once; progress and holds stay in range;
--   * a member's hold is final; the room purge (DELETE) still takes everything;
--   * presets per pool and the two kill-switch flags are seeded; the tunables have their defaults;
--   * nothing here is readable by a client (DS-10: stranger-facing reads go through NestJS only).
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

insert into auth.users (id, email, aud, role) values
  ('22aaaaaa-0000-4000-8000-00000000000a', 'pgtap-lantern-a@aura.test', 'authenticated', 'authenticated'),
  ('22bbbbbb-0000-4000-8000-00000000000b', 'pgtap-lantern-b@aura.test', 'authenticated', 'authenticated');
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at)
values ('22cccccc-0000-4000-8000-00000000000c', 'en', 'storm', 'south_asia', 'anxious', 'lighthouse', now(),
        now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');
insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool,
                                 home_region, match_step, stage)
values ('22a0a0a0-0000-4000-8000-00000000000a', '22cccccc-0000-4000-8000-00000000000c', '22aaaaaa-0000-4000-8000-00000000000a',
        'Quiet Comet', 'anxious', 'storm', 'en', 'south_asia', 4, 'spark'),
       ('22b0b0b0-0000-4000-8000-00000000000b', '22cccccc-0000-4000-8000-00000000000c', '22bbbbbb-0000-4000-8000-00000000000b',
        'Gentle Harbor', 'anxious', 'storm', 'en', 'south_asia', 4, 'spark');

-- ---------------------------------------------------------------- shape
select has_column('public', 'rooms', 'lantern_progress', 'rooms.lantern_progress exists');
select has_column('public', 'rooms', 'lantern_level', 'rooms.lantern_level exists');
select has_column('public', 'rooms', 'intention_key', 'rooms.intention_key exists');
select has_column('public', 'rooms', 'intention_holds', 'rooms.intention_holds exists');
select has_column('public', 'room_members', 'holds_intention', 'room_members.holds_intention exists');
select results_eq(
  $$ select lantern_progress, lantern_level::int, intention_holds, intention_key from public.rooms
      where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  $$ values (0, 0, 0, null::text) $$,
  'a new room starts unlit, with no intention and no holds'
);

-- ---------------------------------------------------------------- additive only (REQ-ROOM-13)
select lives_ok(
  $$ update public.rooms set lantern_progress = 2400, lantern_hour_at = '2026-10-08T15:30:00Z', intention_key = 'gentle_with_myself'
      where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'light can be added and the night pinned'
);
select is((select lantern_level::int from public.rooms where id = '22cccccc-0000-4000-8000-00000000000c'), 2,
  'the level is floor(progress / 1000)');
select throws_ok(
  $$ update public.rooms set lantern_progress = 2399 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'AR030', 'lantern_never_dims', 'the lantern never dims'
);
select throws_ok(
  $$ update public.rooms set lantern_progress = 0 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'AR030', 'lantern_never_dims', 'the lantern never resets'
);
select lives_ok(
  $$ update public.rooms set lantern_progress = lantern_progress where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'an unchanged level is fine (other room updates keep working)'
);
select lives_ok(
  $$ update public.rooms set status = 'open', here_now_broadcast = 2 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'status / presence updates are not affected'
);
select throws_ok(
  $$ update public.rooms set lantern_progress = 5001 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  '23514', null, 'progress is capped at a fully lit lantern (5 levels)'
);
select lives_ok(
  $$ update public.rooms set lantern_progress = 5000 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'a fully lit lantern'
);
select is((select lantern_level::int from public.rooms where id = '22cccccc-0000-4000-8000-00000000000c'), 5,
  'fully lit = level 5');
select throws_ok(
  $$ update public.rooms set lantern_level = 1 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  '428C9', null, 'the level can''t be written directly (generated)'
);

-- ---------------------------------------------------------------- write-once night and intention
select throws_ok(
  $$ update public.rooms set intention_key = 'phone_down_10' where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'AR031', 'intention_fixed', 'tonight''s intention doesn''t change once set'
);
select throws_ok(
  $$ update public.rooms set lantern_hour_at = now() where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'AR031', 'lantern_night_fixed', 'the lantern''s night doesn''t change once set'
);
select throws_ok(
  $$ insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at, intention_key)
     values ('en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary', now() + interval '19 hours', now() + interval '23 hours',
             now() + interval '8 days', 'Sleep well, Quiet Comet!') $$,
  '23514', null, 'intention keys are preset keys, never free text'
);

-- ---------------------------------------------------------------- holds (REQ-ROOM-14)
select lives_ok(
  $$ update public.room_members set holds_intention = true where member_id = '22a0a0a0-0000-4000-8000-00000000000a';
     update public.rooms set intention_holds = intention_holds + 1 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'a member holds tonight''s intention; the room total rises'
);
select throws_ok(
  $$ update public.room_members set holds_intention = false where member_id = '22a0a0a0-0000-4000-8000-00000000000a' $$,
  'AR030', 'intention_hold_is_final', 'a hold is final (no un-hold that would lower the total)'
);
select throws_ok(
  $$ update public.rooms set intention_holds = 0 where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  'AR030', 'intention_holds_never_fall', 'the hold count never falls'
);
select lives_ok(
  $$ update public.room_members set left_at = now() where member_id = '22a0a0a0-0000-4000-8000-00000000000a' $$,
  'leaving works and touches no total'
);
select results_eq(
  $$ select lantern_level::int, intention_holds from public.rooms where id = '22cccccc-0000-4000-8000-00000000000c' $$,
  $$ values (5, 1) $$,
  'leaving lowers neither the lantern nor the hold count'
);

-- ---------------------------------------------------------------- seeds and tunables
select is((select count(*)::int from public.room_intention_presets where enabled and language_pool = 'te'), 6,
  'six intention presets per pool (en, te, hi)');
select is((select count(*)::int from public.feature_flags where key in ('room_lanterns_enabled', 'room_intention_enabled') and enabled), 2,
  'both kill switches exist and start on');
select results_eq(
  $$ select lantern_units_per_member, lantern_min_units_per_level, lantern_breath_cycle_weight from public.matching_config where id $$,
  $$ values (1.50::numeric(5,2), 3, 0.25::numeric(5,2)) $$,
  'lantern tunables have their [ASSUMPTION] defaults'
);

-- ---------------------------------------------------------------- server-only
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ select lantern_level from public.rooms $$, '42501', null, 'clients can''t read room totals directly');
select throws_ok($$ select key from public.room_intention_presets $$, '42501', null, 'clients can''t read the preset list');
reset role;

-- ---------------------------------------------------------------- purge still takes everything
delete from public.rooms where id = '22cccccc-0000-4000-8000-00000000000c';
select is((select count(*)::int from public.room_members where room_id = '22cccccc-0000-4000-8000-00000000000c'), 0,
  'purging the room removes the memberships and their holds (a DELETE is not a dim)');

select * from finish();
rollback;
