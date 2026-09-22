-- RLS read isolation: a signed-in user reads ONLY their own personal rows; anon reads none;
-- server-only tables are unreadable by any client role.
begin;
create extension if not exists pgtap with schema extensions;

select plan(50);

-- ---------- Fixtures (as postgres; everything is rolled back) ----------
-- A = 0a..., B = 0b...
insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'pgtap-a@aura.test', 'authenticated', 'authenticated'),
  ('0bbbbbbb-0000-4000-8000-00000000000b', 'pgtap-b@aura.test', 'authenticated', 'authenticated');

insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone, country) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', '2000-01-01', 'en',      'en', 'Asia/Kolkata', 'IN'),
  ('0bbbbbbb-0000-4000-8000-00000000000b', '1995-05-05', 'te-Latn', 'te', 'Asia/Kolkata', 'IN');

insert into public.user_consents (user_id, purpose, policy_version) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'core', '2026-10'),
  ('0bbbbbbb-0000-4000-8000-00000000000b', 'core', '2026-10');

insert into public.check_ins (id, user_id, mood_id, quadrant, tags, local_day, device_ts) values
  ('0aaaaaaa-c000-7000-8000-000000000001', '0aaaaaaa-0000-4000-8000-00000000000a', 'anxious', 'storm',     '{study}', '2026-10-08', '2026-10-08T10:00:00Z'),
  ('0aaaaaaa-c000-7000-8000-000000000002', '0aaaaaaa-0000-4000-8000-00000000000a', 'calm',    'moonlight', '{}',      '2026-10-09', '2026-10-09T10:00:00Z'),
  ('0bbbbbbb-c000-7000-8000-000000000001', '0bbbbbbb-0000-4000-8000-00000000000b', 'joyful',  'sunrise',   '{}',      '2026-10-08', '2026-10-08T11:00:00Z');

insert into public.habits (id, user_id, kind, preset_key, name) values
  ('0aaaaaaa-4000-7000-8000-000000000001', '0aaaaaaa-0000-4000-8000-00000000000a', 'preset', 'breathe', null),
  ('0bbbbbbb-4000-7000-8000-000000000001', '0bbbbbbb-0000-4000-8000-00000000000b', 'custom', null, 'Read 10 pages');

insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts) values
  ('0aaaaaaa-1000-7000-8000-000000000001', '0aaaaaaa-0000-4000-8000-00000000000a', '0aaaaaaa-4000-7000-8000-000000000001', '2026-10-08', '2026-10-08T10:05:00Z'),
  ('0bbbbbbb-1000-7000-8000-000000000001', '0bbbbbbb-0000-4000-8000-00000000000b', '0bbbbbbb-4000-7000-8000-000000000001', '2026-10-08', '2026-10-08T11:05:00Z');

insert into public.starlight_ledger (user_id, amount, reason, source_id, habit_key, local_day) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 10, 'checkin', '0aaaaaaa-c000-7000-8000-000000000001', null,      '2026-10-08'),
  ('0aaaaaaa-0000-4000-8000-00000000000a',  5, 'habit',   '0aaaaaaa-1000-7000-8000-000000000001', 'breathe', '2026-10-08'),
  ('0bbbbbbb-0000-4000-8000-00000000000b', 10, 'checkin', '0bbbbbbb-c000-7000-8000-000000000001', null,      '2026-10-08');

insert into public.active_days (user_id, local_day) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', '2026-10-08'),
  ('0bbbbbbb-0000-4000-8000-00000000000b', '2026-10-08');

insert into public.avatar_state (user_id) values
  ('0aaaaaaa-0000-4000-8000-00000000000a'), ('0bbbbbbb-0000-4000-8000-00000000000b');
insert into public.streak_state (user_id) values
  ('0aaaaaaa-0000-4000-8000-00000000000a'), ('0bbbbbbb-0000-4000-8000-00000000000b');
insert into public.notification_prefs (user_id) values
  ('0aaaaaaa-0000-4000-8000-00000000000a'), ('0bbbbbbb-0000-4000-8000-00000000000b');

-- server-only tables
insert into public.user_data_keys (user_id, wrapped_key) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'd3JhcHBlZC1h'), ('0bbbbbbb-0000-4000-8000-00000000000b', 'd3JhcHBlZC1i');
insert into public.sync_mutations (user_id, mutation_id, entity, status) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', '0aaaaaaa-5000-7000-8000-000000000001', 'check_in', 'applied');
insert into public.device_tokens (user_id, platform, token) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'ios', 'pgtap-device-token-a');
insert into public.crisis_events (surface, locale) values ('checkin', 'en');

-- ---------- User A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);

select is(auth.uid(), '0aaaaaaa-0000-4000-8000-00000000000a'::uuid, 'claims simulate user A');

-- A sees exactly their own rows ...
select set_eq(
  format('select user_id from public.%I', t),
  array['0aaaaaaa-0000-4000-8000-00000000000a'::uuid],
  format('user A reads own rows in %s', t)
)
from unnest(array['profiles','user_consents','check_ins','habits','habit_logs','starlight_ledger',
                  'active_days','avatar_state','streak_state','notification_prefs']) t;

-- ... and none of B's, even when asking for them explicitly.
select is_empty(
  format('select 1 from public.%I where user_id = %L', t, '0bbbbbbb-0000-4000-8000-00000000000b'),
  format('user A cannot read user B rows in %s', t)
)
from unnest(array['profiles','user_consents','check_ins','habits','habit_logs','starlight_ledger',
                  'active_days','avatar_state','streak_state','notification_prefs']) t;

select is((select count(*)::int from public.check_ins), 2, 'user A sees both of their check-ins');

-- server-only tables: no client privilege at all
select throws_ok(format('select * from public.%I', t), '42501', null,
                 format('authenticated cannot read %s', t))
from unnest(array['user_data_keys','sync_mutations','device_tokens','crisis_events']) t;

-- ---------- User B ----------
select set_config('request.jwt.claims',
  '{"sub":"0bbbbbbb-0000-4000-8000-00000000000b","role":"authenticated","aud":"authenticated"}', true);

select set_eq(
  format('select user_id from public.%I', t),
  array['0bbbbbbb-0000-4000-8000-00000000000b'::uuid],
  format('user B reads only own rows in %s', t)
)
from unnest(array['profiles','user_consents','check_ins','habits','habit_logs','starlight_ledger',
                  'active_days','avatar_state','streak_state','notification_prefs']) t;

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty(format('select 1 from public.%I', t), format('anon reads no rows in %s', t))
from unnest(array['profiles','user_consents','check_ins','habits','habit_logs','starlight_ledger',
                  'active_days','avatar_state','streak_state','notification_prefs']) t;

select throws_ok(format('select * from public.%I', t), '42501', null,
                 format('anon cannot read %s', t))
from unnest(array['user_data_keys','sync_mutations','device_tokens','crisis_events']) t;

reset role;
select * from finish();
rollback;
