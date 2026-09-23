-- F14 notifications (contracts/api/v1-notifications.md): `notification_prefs` keeps its foundations contract, gains
-- the synced toggles with the PRD defaults and the server-managed delivery state, stays select-own for the owner
-- and is never client-written.
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

-- ---------- Shape ----------
select is(
  array(
    select c from unnest(array[
      'user_id','reminder_time','quiet_start','quiet_end','discreet','lantern_opt_in','updated_at',
      'enabled','reminder_enabled','reminder_in_quiet_ok','capsule_enabled','field_ts',
      'reminder_next_at','reminder_tz','sent_day','sent_types'
    ]) c
    except
    select column_name::text from information_schema.columns
     where table_schema = 'public' and table_name = 'notification_prefs'
  ),
  '{}'::text[],
  'notification_prefs keeps the foundations columns and has the F14 ones'
);
select has_index('public', 'notification_prefs', 'notification_prefs_reminder_due_idx', 'reminder sweep index');

-- ---------- Defaults (PRD 12-notifications) ----------
insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-0000000012aa', 'pgtap-ntf-a@aura.test', 'authenticated', 'authenticated'),
  ('0bbbbbbb-0000-4000-8000-0000000012bb', 'pgtap-ntf-b@aura.test', 'authenticated', 'authenticated');
insert into public.notification_prefs (user_id) values ('0aaaaaaa-0000-4000-8000-0000000012aa');
-- the shape the account-purge e2e inserts (foundations columns only) still works
insert into public.notification_prefs (user_id, reminder_time) values ('0bbbbbbb-0000-4000-8000-0000000012bb', '21:00');

select results_eq(
  $$ select enabled, reminder_enabled, reminder_time, reminder_in_quiet_ok, capsule_enabled,
            quiet_start, quiet_end, discreet, field_ts, reminder_next_at, sent_day, sent_types
       from public.notification_prefs where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  $$ values (true, false, null::time, false, true, '23:00'::time, '08:00'::time, false, '{}'::jsonb,
             null::timestamptz, null::date, '{}'::text[]) $$,
  'defaults: master on, reminder off until picked, capsule pushes on, quiet 23:00–08:00, discreet off, empty log'
);

-- ---------- Constraints ----------
select throws_ok(
  $$ update public.notification_prefs set field_ts = '[]'::jsonb where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  '23514', null, 'field_ts is a JSON object'
);
select throws_ok(
  $$ update public.notification_prefs set quiet_start = '23:00:30' where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  '23514', null, 'quiet hours are whole minutes'
);
select throws_ok(
  $$ update public.notification_prefs set reminder_time = '20:00:01' where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  '23514', null, 'the reminder time is whole minutes'
);
select throws_ok(
  $$ update public.notification_prefs set sent_types = array['Something you sealed is ready']
      where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  '23514', null, 'the send log holds machine type names only (never copy or content)'
);
select throws_ok(
  $$ update public.notification_prefs set sent_types = array['capsule_unlocked:0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d']
      where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  '23514', null, 'the send log never holds record ids'
);
select lives_ok(
  $$ update public.notification_prefs
        set sent_day = '2026-10-08', sent_types = array['capsule_unlocked','daily_reminder'],
            reminder_time = '20:00', reminder_enabled = true, reminder_next_at = '2026-10-08T14:30:00Z',
            reminder_tz = 'Asia/Kolkata', field_ts = '{"reminderTime":"2026-10-08T10:00:00.000Z"}'
      where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  'server-managed state: today''s send log and the next reminder'
);

-- ---------- RLS / privileges ----------
select ok((select relrowsecurity from pg_class where oid = 'public.notification_prefs'::regclass),
  'RLS enabled on notification_prefs');
select ok(
  (select count(*) = 1 and bool_and(policyname = 'own_read' and cmd = 'SELECT')
     from pg_policies where schemaname = 'public' and tablename = 'notification_prefs'),
  'notification_prefs has exactly one policy: SELECT own row'
);
select ok(
  not has_table_privilege('authenticated', 'public.notification_prefs', 'INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('anon', 'public.notification_prefs', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'clients hold no write privilege on notification_prefs (settings go through the sync push)'
);

-- ---------- User A ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-0000000012aa","role":"authenticated","aud":"authenticated"}', true);

select results_eq(
  $$ select user_id::text, reminder_enabled, reminder_time, sent_types from public.notification_prefs $$,
  $$ values ('0aaaaaaa-0000-4000-8000-0000000012aa', true, '20:00'::time, array['capsule_unlocked','daily_reminder']) $$,
  'user A reads exactly their own row, new columns included (select=* pulls keep working)'
);
select is_empty(
  $$ select 1 from public.notification_prefs where user_id = '0bbbbbbb-0000-4000-8000-0000000012bb' $$,
  'user A cannot read user B''s prefs, even by asking'
);
select throws_ok(
  $$ update public.notification_prefs set discreet = true $$,
  '42501', 'permission denied for table notification_prefs', 'authenticated cannot UPDATE prefs'
);
select throws_ok(
  $$ update public.notification_prefs set sent_types = '{}' $$,
  '42501', 'permission denied for table notification_prefs', 'authenticated cannot reset the send log'
);
select throws_ok(
  $$ insert into public.notification_prefs (user_id) values (auth.uid()) $$,
  '42501', 'permission denied for table notification_prefs', 'authenticated cannot INSERT prefs'
);
select throws_ok(
  $$ delete from public.notification_prefs $$,
  '42501', 'permission denied for table notification_prefs', 'authenticated cannot DELETE prefs'
);

-- ---------- User B ----------
select set_config('request.jwt.claims',
  '{"sub":"0bbbbbbb-0000-4000-8000-0000000012bb","role":"authenticated","aud":"authenticated"}', true);
select results_eq(
  $$ select user_id::text, reminder_time from public.notification_prefs $$,
  $$ values ('0bbbbbbb-0000-4000-8000-0000000012bb', '21:00'::time) $$,
  'user B reads only their own row'
);

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is_empty($$ select 1 from public.notification_prefs $$, 'anon reads no prefs');
select throws_ok(
  $$ update public.notification_prefs set enabled = false $$,
  '42501', 'permission denied for table notification_prefs', 'anon cannot UPDATE prefs'
);

-- ---------- cascade ----------
reset role;
delete from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000012aa';
select is_empty(
  $$ select 1 from public.notification_prefs where user_id = '0aaaaaaa-0000-4000-8000-0000000012aa' $$,
  'prefs (and their send log and schedule) go with the auth user'
);
select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'notification_prefs' and column_name = 'user_id'),
  1,
  'still one row per user (no new personal table: the send log lives on the prefs row)'
);
select col_is_pk('public', 'notification_prefs', 'user_id', 'one prefs row per user');

select * from finish();
rollback;
