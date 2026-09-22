-- Age rules: profiles_min_age blocks under-13s (DB-level backstop for POST /v1/profile → 403 under_13);
-- public.user_is_minor() is server-only and derives under-18 from the stored DOB (D2, DS-6).
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

insert into auth.users (id, email, aud, role) values
  ('00000012-0000-4000-8000-000000000000', 'pgtap-12@aura.test',     'authenticated', 'authenticated'),
  ('00000013-0000-4000-8000-000000000000', 'pgtap-13@aura.test',     'authenticated', 'authenticated'),
  ('00000014-0000-4000-8000-000000000000', 'pgtap-13b@aura.test',    'authenticated', 'authenticated'),
  ('00000016-0000-4000-8000-000000000000', 'pgtap-16@aura.test',     'authenticated', 'authenticated'),
  ('00000017-0000-4000-8000-000000000000', 'pgtap-17@aura.test',     'authenticated', 'authenticated'),
  ('00000018-0000-4000-8000-000000000000', 'pgtap-18@aura.test',     'authenticated', 'authenticated'),
  ('00000030-0000-4000-8000-000000000000', 'pgtap-30@aura.test',     'authenticated', 'authenticated'),
  ('000000ff-0000-4000-8000-000000000000', 'pgtap-noprof@aura.test', 'authenticated', 'authenticated');

-- ---------- profiles_min_age ----------
select throws_ok(
  $$ insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
     values ('00000012-0000-4000-8000-000000000000', (current_date - interval '12 years')::date, 'en', 'en', 'Asia/Kolkata') $$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_min_age"',
  'profiles_min_age rejects a 12-year-old'
);
select throws_ok(
  $$ insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
     values ('00000012-0000-4000-8000-000000000000', (current_date - interval '13 years' + interval '2 days')::date, 'en', 'en', 'Asia/Kolkata') $$,
  '23514', null,
  'profiles_min_age rejects someone turning 13 in two days (beyond the 1-day timezone slack)'
);
select lives_ok(
  $$ insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
     values ('00000014-0000-4000-8000-000000000000', (current_date - interval '13 years' + interval '1 day')::date, 'en', 'en', 'Pacific/Kiritimati') $$,
  'profiles_min_age accepts someone turning 13 tomorrow in UTC (already 13 in UTC+14): 1-day slack'
);
select lives_ok(
  $$ insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
     values ('00000013-0000-4000-8000-000000000000', (current_date - interval '13 years')::date, 'te-Latn', 'te', 'Asia/Kolkata') $$,
  'profiles_min_age accepts someone turning 13 today'
);
select lives_ok(
  $$ insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
     ('00000016-0000-4000-8000-000000000000', (current_date - interval '16 years')::date, 'en', 'en', 'Asia/Kolkata'),
     ('00000017-0000-4000-8000-000000000000', (current_date - interval '18 years' + interval '1 day')::date, 'hi', 'hi', 'Asia/Kolkata'),
     ('00000018-0000-4000-8000-000000000000', (current_date - interval '18 years')::date, 'en', 'en', 'Asia/Kolkata'),
     ('00000030-0000-4000-8000-000000000000', (current_date - interval '30 years')::date, 'te', 'te', 'Asia/Kolkata') $$,
  'profiles accepts 16, 17y364d, 18 and 30-year-olds'
);

-- ---------- user_is_minor: privileges ----------
select ok(not has_function_privilege('anon', 'public.user_is_minor(uuid)', 'EXECUTE'),
          'anon has no EXECUTE on user_is_minor');
select ok(not has_function_privilege('authenticated', 'public.user_is_minor(uuid)', 'EXECUTE'),
          'authenticated has no EXECUTE on user_is_minor');
select ok(not has_function_privilege('public', 'public.user_is_minor(uuid)', 'EXECUTE'),
          'PUBLIC has no EXECUTE on user_is_minor');
select ok(has_function_privilege('service_role', 'public.user_is_minor(uuid)', 'EXECUTE'),
          'service_role can EXECUTE user_is_minor');
select ok(
  (select prosecdef and proconfig @> array['search_path=public'] from pg_proc where oid = 'public.user_is_minor(uuid)'::regprocedure),
  'user_is_minor is SECURITY DEFINER with a pinned search_path'
);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000016-0000-4000-8000-000000000000","role":"authenticated","aud":"authenticated"}', true);
select throws_ok($$ select public.user_is_minor('00000016-0000-4000-8000-000000000000') $$, '42501', null,
                 'authenticated calling user_is_minor (even on self) is denied');
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select public.user_is_minor('00000016-0000-4000-8000-000000000000') $$, '42501', null,
                 'anon calling user_is_minor is denied');
reset role;

-- ---------- user_is_minor: values (as postgres) ----------
select is(public.user_is_minor('00000013-0000-4000-8000-000000000000'), true,  '13 today → minor');
select is(public.user_is_minor('00000016-0000-4000-8000-000000000000'), true,  '16 → minor');
select is(public.user_is_minor('00000017-0000-4000-8000-000000000000'), true,  '18 tomorrow (17y364d) → minor');
select is(public.user_is_minor('00000018-0000-4000-8000-000000000000'), false, '18 today → adult');
select is(public.user_is_minor('00000030-0000-4000-8000-000000000000'), false, '30 → adult');
select is(public.user_is_minor('000000ff-0000-4000-8000-000000000000'), false, 'no profile → false');
select is(public.user_is_minor(null), false, 'null uid → false');

-- A 12-year-old DOB can never be stored, so lift the constraint inside this (rolled-back) transaction
-- to prove the function itself classifies it correctly.
alter table public.profiles drop constraint profiles_min_age;
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
values ('00000012-0000-4000-8000-000000000000', (current_date - interval '12 years')::date, 'en', 'en', 'Asia/Kolkata');
select is(public.user_is_minor('00000012-0000-4000-8000-000000000000'), true, '12 → minor');

select * from finish();
rollback;
