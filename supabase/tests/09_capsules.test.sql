-- F4 time capsules (contracts/api/v1-capsules.md): `capsules` is select-own for the owner and never client-written;
-- `capsule_unlock_schedule` is server-only. The CHECKs are the DB backstop for "ciphertext only", the per-type
-- unlock metadata and tombstones that keep no content.
begin;
create extension if not exists pgtap with schema extensions;

select plan(51);

-- ---------- Shape ----------
select has_table('public', 'capsules', 'public.capsules exists');
select has_table('public', 'capsule_unlock_schedule', 'public.capsule_unlock_schedule exists');
select is(
  array(
    select c from unnest(array[
      'id','user_id','unlock_type','unlock_local_date','trigger_mood_id','trigger_quadrant','payload_ct','sealed_at',
      'armed_at','cycle','fired_at','cooldown_until','opened_at','opened_device_ts','deleted_at','server_ts','updated_at'
    ]) c
    except
    select column_name::text from information_schema.columns where table_schema = 'public' and table_name = 'capsules'
  ),
  '{}'::text[],
  'capsules keeps every contract column (the app pulls them)'
);
select columns_are('public', 'capsule_unlock_schedule', array['capsule_id','notify_at','notify_tz','notified_at','updated_at'],
  'capsule_unlock_schedule has no user_id and no content');
select col_is_pk('public', 'capsules', 'id', 'the client UUIDv7 is the primary key');
select set_eq(
  $$ select confrelid::regclass::text, confdeltype::text from pg_constraint
      where conrelid = 'public.capsules'::regclass and contype = 'f' $$,
  $$ values ('auth.users', 'c'), ('moods', 'a') $$,
  'capsules → auth.users on delete cascade; trigger_mood_id → the mood catalogue'
);
select results_eq(
  $$ select confrelid::regclass::text, confdeltype::text from pg_constraint
      where conrelid = 'public.capsule_unlock_schedule'::regclass and contype = 'f' $$,
  $$ values ('capsules', 'c') $$,
  'schedule rows go with their capsule (on delete cascade)'
);
select has_index('public', 'capsules', 'capsules_user_updated_idx', 'pull cursor index (user_id, updated_at)');
select has_index('public', 'capsules', 'capsules_pending_date_idx', 'pending date capsules index');
select has_index('public', 'capsule_unlock_schedule', 'capsule_unlock_schedule_pending_idx', 'unsent pushes by notify_at');

-- ---------- RLS / policies / privileges ----------
select ok((select relrowsecurity from pg_class where oid = 'public.capsules'::regclass), 'RLS enabled on capsules');
select ok((select relrowsecurity from pg_class where oid = 'public.capsule_unlock_schedule'::regclass),
  'RLS enabled on capsule_unlock_schedule');
select ok(
  (select count(*) = 1 and bool_and(policyname = 'own_read' and cmd = 'SELECT' and roles = '{authenticated}'::name[])
     from pg_policies where schemaname = 'public' and tablename = 'capsules'),
  'capsules has exactly one policy: SELECT own rows, for authenticated'
);
select is_empty(
  $$ select policyname from pg_policies where schemaname = 'public' and tablename = 'capsule_unlock_schedule' $$,
  'no client policies on capsule_unlock_schedule'
);
select ok(
  not has_table_privilege('anon', 'public.capsules', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'anon holds no privilege on capsules (not even SELECT)'
);
select ok(
  has_table_privilege('authenticated', 'public.capsules', 'SELECT')
  and not has_table_privilege('authenticated', 'public.capsules', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'authenticated may only SELECT capsules (RLS picks the rows); every write goes through NestJS'
);
select ok(
  not has_table_privilege('anon', 'public.capsule_unlock_schedule', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('authenticated', 'public.capsule_unlock_schedule', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'capsule_unlock_schedule is server-only'
);

-- ---------- Fixtures (as postgres, like NestJS) ----------
insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-0000000009aa', 'pgtap-cap-a@aura.test', 'authenticated', 'authenticated'),
  ('0bbbbbbb-0000-4000-8000-0000000009bb', 'pgtap-cap-b@aura.test', 'authenticated', 'authenticated');

-- ---------- Constraints ----------
select lives_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000901', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-10-08',
             'Y2lwaGVydGV4dC1h', '2026-10-08T12:30:00Z') $$,
  'a date capsule: ciphertext + unlock date'
);
select lives_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_quadrant, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000902', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'storm',
             'Y2lwaGVydGV4dC1i', '2026-10-08T12:30:00Z', '2026-10-09T12:30:00Z') $$,
  'a trigger capsule for a quadrant'
);
select lives_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_mood_id, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000903', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'overwhelmed',
             'Y2lwaGVydGV4dC1j_-', '2026-10-08T12:30:00Z', '2026-10-09T12:30:00Z') $$,
  'a trigger capsule for one mood (base64url ciphertext)'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_mood_id, trigger_quadrant, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000911', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'overwhelmed', 'storm',
             'Y3Q=', now(), now()) $$,
  '23514', null, 'a trigger capsule has exactly one target (not both)'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000912', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'Y3Q=', now(), now()) $$,
  '23514', null, 'a trigger capsule has exactly one target (not none)'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_quadrant, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000913', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'rain', 'Y3Q=', now()) $$,
  '23514', null, 'a trigger capsule needs armed_at'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, trigger_quadrant, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000914', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-01-01', 'rain',
             'Y3Q=', now()) $$,
  '23514', null, 'a date capsule carries no trigger'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000915', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', 'Y3Q=', now()) $$,
  '23514', null, 'a date capsule needs its unlock date'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_mood_id, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000916', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'ecstatic',
             'Y3Q=', now(), now()) $$,
  '23503', null, 'the target mood must exist in the catalogue'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, trigger_quadrant, payload_ct, sealed_at, armed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000917', '0aaaaaaa-0000-4000-8000-0000000009aa', 'mood', 'thunder',
             'Y3Q=', now(), now()) $$,
  '23514', null, 'the target quadrant must be one of the four'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000918', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-01-01',
             '{"title": "Dear me", "text": "plaintext"}', now()) $$,
  '23514', null, 'plaintext (JSON) is refused: payload_ct must look like base64 ciphertext'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000919', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-01-01',
             repeat('A', 131073), now()) $$,
  '23514', null, 'ciphertext above 128 KiB is refused'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-00000000091a', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-01-01', now()) $$,
  '23514', null, 'a live capsule must carry its ciphertext'
);
select throws_ok(
  $$ update public.capsules set deleted_at = now() where id = '0aaaaaaa-ca00-7000-8000-000000000903' $$,
  '23514', null, 'a tombstone cannot keep the ciphertext or the target'
);
select lives_ok(
  $$ update public.capsules
        set deleted_at = now(), payload_ct = null, trigger_mood_id = null
      where id = '0aaaaaaa-ca00-7000-8000-000000000903' $$,
  'a tombstone keeps no content (payload and target erased)'
);
select throws_ok(
  $$ update public.capsules set opened_at = now() where id = '0aaaaaaa-ca00-7000-8000-000000000901' $$,
  '23514', null, 'opened_at and opened_device_ts are set together'
);
select throws_ok(
  $$ update public.capsules set opened_at = now(), opened_device_ts = now() where id = '0aaaaaaa-ca00-7000-8000-000000000902' $$,
  '23514', null, 'an opened trigger capsule has fired'
);
select throws_ok(
  $$ update public.capsules set fired_at = now() where id = '0aaaaaaa-ca00-7000-8000-000000000902' $$,
  '23514', null, 'a fire always sets the cooldown'
);
select throws_ok(
  $$ update public.capsules set cycle = -1 where id = '0aaaaaaa-ca00-7000-8000-000000000902' $$,
  '23514', null, 'cycle is never negative'
);

insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at) values
  ('0bbbbbbb-ca00-7000-8000-000000000901', '0bbbbbbb-0000-4000-8000-0000000009bb', 'date', '2028-01-01', 'Yi1jdA==',
   '2026-10-08T12:30:00Z');
insert into public.capsule_unlock_schedule (capsule_id, notify_at, notify_tz) values
  ('0aaaaaaa-ca00-7000-8000-000000000901', '2027-10-08T04:30:00Z', 'Asia/Kolkata'),
  ('0bbbbbbb-ca00-7000-8000-000000000901', '2028-01-01T04:30:00Z', 'Asia/Kolkata');

-- ---------- User A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-0000000009aa","role":"authenticated","aud":"authenticated"}', true);

select set_eq(
  $$ select id::text from public.capsules $$,
  array['0aaaaaaa-ca00-7000-8000-000000000901', '0aaaaaaa-ca00-7000-8000-000000000902', '0aaaaaaa-ca00-7000-8000-000000000903'],
  'user A reads exactly their own capsules, tombstones included (the pull sees deletes)'
);
select is_empty(
  $$ select 1 from public.capsules where user_id = '0bbbbbbb-0000-4000-8000-0000000009bb' $$,
  'user A cannot read user B''s capsules, even by asking'
);
select is(
  (select payload_ct from public.capsules where id = '0aaaaaaa-ca00-7000-8000-000000000903'),
  null,
  'a tombstone shows no content'
);
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000999', auth.uid(), 'date', '2027-01-01', 'Y3Q=', now()) $$,
  '42501', 'permission denied for table capsules', 'authenticated cannot INSERT a capsule (sync push only)'
);
select throws_ok(
  $$ update public.capsules set opened_at = now(), opened_device_ts = now() $$,
  '42501', 'permission denied for table capsules', 'authenticated cannot UPDATE (no early open, no edit)'
);
select throws_ok($$ delete from public.capsules $$,
  '42501', 'permission denied for table capsules', 'authenticated cannot DELETE (delete is a sync tombstone)');
select throws_ok($$ truncate public.capsules $$,
  '42501', 'permission denied for table capsules', 'authenticated cannot TRUNCATE');
select throws_ok($$ select * from public.capsule_unlock_schedule $$,
  '42501', 'permission denied for table capsule_unlock_schedule', 'authenticated cannot read the unlock schedule');
select throws_ok(
  $$ delete from public.capsule_unlock_schedule $$,
  '42501', 'permission denied for table capsule_unlock_schedule', 'authenticated cannot cancel an unlock push');

-- ---------- User B ----------
select set_config('request.jwt.claims',
  '{"sub":"0bbbbbbb-0000-4000-8000-0000000009bb","role":"authenticated","aud":"authenticated"}', true);
select set_eq($$ select id::text from public.capsules $$, array['0bbbbbbb-ca00-7000-8000-000000000901'],
  'user B reads only their own capsule');

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.capsules $$,
  '42501', 'permission denied for table capsules', 'anon cannot read capsules');
select throws_ok(
  $$ insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
     values ('0aaaaaaa-ca00-7000-8000-000000000998', '0aaaaaaa-0000-4000-8000-0000000009aa', 'date', '2027-01-01', 'Y3Q=', now()) $$,
  '42501', 'permission denied for table capsules', 'anon cannot write capsules');

-- ---------- account deletion: everything goes with the auth user ----------
reset role;
delete from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000009aa';
select is((select count(*)::int from public.capsules where user_id = '0aaaaaaa-0000-4000-8000-0000000009aa'), 0,
  'deleting the auth user removes their capsules (tombstones too)');
select is(
  (select count(*)::int from public.capsule_unlock_schedule where capsule_id = '0aaaaaaa-ca00-7000-8000-000000000901'), 0,
  '... and their unlock schedule');
select is((select count(*)::int from public.capsules where user_id = '0bbbbbbb-0000-4000-8000-0000000009bb'), 1,
  'nobody else''s capsules are touched');

select * from finish();
rollback;
