-- "The app never writes personal tables directly": every INSERT / UPDATE / DELETE / TRUNCATE by a
-- client role (authenticated or anon) on every public table fails with 42501 "permission denied for
-- table" — i.e. at the GRANT layer, before RLS is even consulted (RLS would also say 42501, so the
-- message is asserted to prove the grant revoke itself holds).
begin;
create extension if not exists pgtap with schema extensions;

select plan(137);

insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'pgtap-a@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', '2000-01-01', 'en', 'en', 'Asia/Kolkata');

-- statements to attempt: 17 tables x 4 verbs (UPDATE uses each table's first column)
create temp table write_attempts on commit drop as
select t.tbl, v.verb,
       case v.verb
         when 'INSERT'   then format('insert into public.%I default values', t.tbl)
         when 'UPDATE'   then format('update public.%I set %I = %I', t.tbl, a.attname, a.attname)
         when 'DELETE'   then format('delete from public.%I', t.tbl)
         when 'TRUNCATE' then format('truncate public.%I', t.tbl)
       end as stmt
from unnest(array[
  'moods','preset_habits','feature_flags','profiles','user_consents','user_data_keys',
  'check_ins','habits','habit_logs','starlight_ledger','active_days','avatar_state',
  'streak_state','sync_mutations','device_tokens','notification_prefs','crisis_events'
]) as t(tbl)
join pg_attribute a on a.attrelid = format('public.%I', t.tbl)::regclass and a.attnum = 1
cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) as v(verb);
grant select on write_attempts to anon, authenticated;

select is((select count(*)::int from write_attempts), 68, '68 write statements generated');

-- ---------- authenticated (signed-in user A, writing their OWN rows) ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);

select throws_ok(stmt, '42501', format('permission denied for table %s', tbl),
                 format('authenticated cannot %s %s', verb, tbl))
from write_attempts order by tbl, verb;

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(stmt, '42501', format('permission denied for table %s', tbl),
                 format('anon cannot %s %s', verb, tbl))
from write_attempts order by tbl, verb;

reset role;
select * from finish();
rollback;
