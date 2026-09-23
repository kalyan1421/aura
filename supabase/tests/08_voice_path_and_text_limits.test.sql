-- F1 voice notes: check_ins.voice_path is null or exactly `<user_id>/voice/<id>` (DB backstop for the
-- sync rule `invalid_voice_path`; objects live in the private-media bucket under the owner's prefix).
-- F2 habit names: ≤ 30 grapheme clusters is enforced by NestJS; the DB only bounds the size (≤ 480 code
-- points), so valid Telugu names (many code points per character) are never refused by the backstop.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

select ok(
  exists (select 1 from pg_constraint
           where conrelid = 'public.check_ins'::regclass and conname = 'check_ins_voice_path_shape'
             and contype = 'c' and convalidated),
  'check_ins_voice_path_shape exists and is validated'
);

insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-0000000008aa', 'pgtap-voice-a@aura.test', 'authenticated', 'authenticated'),
  ('0bbbbbbb-0000-4000-8000-0000000008bb', 'pgtap-voice-b@aura.test', 'authenticated', 'authenticated');

select lives_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000801', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z',
             '0aaaaaaa-0000-4000-8000-0000000008aa/voice/0aaaaaaa-c000-7000-8000-000000000801') $$,
  'a check-in may reference its own voice object <user_id>/voice/<id>'
);
select lives_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000802', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z', null) $$,
  'voice_path may be null (no voice note)'
);
select throws_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000803', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z',
             '0bbbbbbb-0000-4000-8000-0000000008bb/voice/0aaaaaaa-c000-7000-8000-000000000803') $$,
  '23514', null,
  'a path under another user''s prefix is refused'
);
select throws_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000804', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z',
             '0aaaaaaa-0000-4000-8000-0000000008aa/voice/0aaaaaaa-c000-7000-8000-000000000801') $$,
  '23514', null,
  'a path naming a different check-in is refused'
);
select throws_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000805', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z',
             '0aaaaaaa-0000-4000-8000-0000000008aa/capsules/0aaaaaaa-c000-7000-8000-000000000805') $$,
  '23514', null,
  'only the voice/ folder is valid for a check-in'
);
select throws_ok(
  $$ insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
     values ('0aaaaaaa-c000-7000-8000-000000000806', '0aaaaaaa-0000-4000-8000-0000000008aa', 'calm', 'moonlight',
             '2026-10-08', '2026-10-08T10:00:00Z',
             upper('0aaaaaaa-0000-4000-8000-0000000008aa/voice/0aaaaaaa-c000-7000-8000-000000000806')) $$,
  '23514', null,
  'the path is canonical lower-case (object names are case-sensitive)'
);
select throws_ok(
  $$ update public.check_ins set voice_path = '0aaaaaaa-0000-4000-8000-0000000008aa/voice/../x'
      where id = '0aaaaaaa-c000-7000-8000-000000000802' $$,
  '23514', null,
  'an edit cannot set a non-canonical path either'
);
select lives_ok(
  $$ update public.check_ins set voice_path = null where id = '0aaaaaaa-c000-7000-8000-000000000801' $$,
  'an edit may clear the voice note'
);
select is(
  (select count(*)::int from public.check_ins
    where user_id = '0aaaaaaa-0000-4000-8000-0000000008aa' and voice_path is not null),
  0,
  'after clearing, no check-in of the user references a voice object'
);

-- ---------- habit names ----------
select ok(
  not exists (select 1 from pg_constraint where conrelid = 'public.habits'::regclass and conname = 'habits_name_check')
  and exists (select 1 from pg_constraint where conrelid = 'public.habits'::regclass and conname = 'habits_name_length'
                and contype = 'c' and convalidated),
  'the code-point name limit (<= 40) is replaced by habits_name_length'
);
select lives_ok(
  $$ insert into public.habits (id, user_id, kind, name)
     values ('0aaaaaaa-4000-7000-8000-000000000801', '0aaaaaaa-0000-4000-8000-0000000008aa', 'custom',
             repeat('స్త్రీ', 30)) $$,
  'a 30-character Telugu name (180 code points) is accepted'
);
select throws_ok(
  $$ insert into public.habits (id, user_id, kind, name)
     values ('0aaaaaaa-4000-7000-8000-000000000802', '0aaaaaaa-0000-4000-8000-0000000008aa', 'custom',
             repeat('x', 481)) $$,
  '23514', null,
  'names beyond 480 code points are refused (size backstop)'
);
select lives_ok(
  $$ insert into public.habits (id, user_id, kind, preset_key, name)
     values ('0aaaaaaa-4000-7000-8000-000000000803', '0aaaaaaa-0000-4000-8000-0000000008aa', 'preset', 'breathe', null) $$,
  'presets without a name are unaffected'
);

select * from finish();
rollback;
