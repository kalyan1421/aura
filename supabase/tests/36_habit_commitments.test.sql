-- W02 habit commitments (migration 20261005000036): columns, shape checks, the minor backstop, RLS/grants unchanged.
begin;
create extension if not exists pgtap with schema extensions;

select plan(13);

-- Two users: an adult and a minor (stored DOB), both with a profile.
insert into auth.users (id, email, aud, role) values
  ('36aaaaaa-0000-4000-8000-00000000000a', 'pgtap-36a@aura.test', 'authenticated', 'authenticated'),
  ('36bbbbbb-0000-4000-8000-00000000000b', 'pgtap-36b@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
  ('36aaaaaa-0000-4000-8000-00000000000a', current_date - interval '30 years', 'en', 'en', 'Asia/Kolkata'),
  ('36bbbbbb-0000-4000-8000-00000000000b', current_date - interval '15 years', 'en', 'en', 'Asia/Kolkata');

select has_column('public', 'habits', 'committed_from', 'habits.committed_from exists');
select has_column('public', 'habits', 'paused_through', 'habits.paused_through exists');
select col_is_null('public', 'habits', 'committed_from', 'committed_from is nullable (NULL = not a commitment)');

select lives_ok($$insert into public.habits (id, user_id, kind, name)
  values ('36aaaaaa-1000-4000-8000-000000000001', '36aaaaaa-0000-4000-8000-00000000000a', 'custom', 'Read')$$,
  'a habit without a commitment still inserts (existing rows and old clients)');

select lives_ok($$update public.habits set committed_from = '2026-10-01'
  where id = '36aaaaaa-1000-4000-8000-000000000001'$$, 'an adult can commit a habit');

select lives_ok($$update public.habits set paused_through = '2026-10-20'
  where id = '36aaaaaa-1000-4000-8000-000000000001'$$, 'an adult can pause a commitment');

select throws_ok($$update public.habits set committed_from = null
  where id = '36aaaaaa-1000-4000-8000-000000000001'$$, '23514', null,
  'clearing the commitment while a pause is set violates the shape check');

select throws_ok($$insert into public.habits (id, user_id, kind, name, paused_through)
  values ('36aaaaaa-1000-4000-8000-000000000002', '36aaaaaa-0000-4000-8000-00000000000a', 'custom', 'Walk', '2026-10-20')$$,
  '23514', null, 'a pause without a commitment is refused');

select throws_ok($$insert into public.habits (id, user_id, kind, name, committed_from)
  values ('36bbbbbb-1000-4000-8000-000000000001', '36bbbbbb-0000-4000-8000-00000000000b', 'custom', 'Read', '2026-10-01')$$,
  '23514', 'commitment_not_available', 'a minor cannot commit a habit (DB backstop)');

select lives_ok($$insert into public.habits (id, user_id, kind, name)
  values ('36bbbbbb-1000-4000-8000-000000000002', '36bbbbbb-0000-4000-8000-00000000000b', 'custom', 'Water')$$,
  'a minor can still track a habit without a commitment');

select ok(has_column_privilege('authenticated', 'public.habits', 'committed_from', 'SELECT')
      and has_column_privilege('authenticated', 'public.habits', 'paused_through', 'SELECT'),
  'clients can read both columns (the phone pulls them; RLS still limits rows to the owner)');

select ok(not has_column_privilege('authenticated', 'public.habits', 'paused_through', 'INSERT'),
  'clients cannot insert commitments either');

select ok(not has_column_privilege('authenticated', 'public.habits', 'committed_from', 'UPDATE'),
  'clients cannot write commitments directly (only through POST /v1/sync/push)');

select * from finish();
rollback;
