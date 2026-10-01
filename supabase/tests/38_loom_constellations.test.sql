-- U07 Orbit Loom constellations (migration 20261005000038):
--   * cosmetic columns only (stars, links, a closed-list meaning); no free text or mood;
--   * a live row has a bounded shape; letting one go erases it (soft delete, pull by updated_at);
--   * select-own (RLS), no client writes, no console access, cascades with the account.
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin;

select plan(21);

insert into auth.users (id, email, aud, role) values
  ('38aaaaaa-0000-4000-8000-00000000000a', 'pgtap-loom-a@aura.test', 'authenticated', 'authenticated'),
  ('38bbbbbb-0000-4000-8000-00000000000b', 'pgtap-loom-b@aura.test', 'authenticated', 'authenticated');
insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone, country) values
  ('38aaaaaa-0000-4000-8000-00000000000a', '2000-01-01', 'en', 'en', 'Asia/Kolkata', 'IN'),
  ('38bbbbbb-0000-4000-8000-00000000000b', '1995-05-05', 'te', 'te', 'Asia/Kolkata', 'IN');

-- ---------------------------------------------------------------- shape
select has_table('public', 'loom_constellations', 'loom_constellations exists');
select columns_are('public', 'loom_constellations',
  array['id', 'user_id', 'stars', 'links', 'meaning', 'local_day', 'device_ts', 'deleted_at', 'server_ts', 'updated_at'],
  'only cosmetic columns: no free text or mood');
select col_is_pk('public', 'loom_constellations', 'id', 'the client id is the key (idempotent)');

select lives_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts) values
       ('38aaaaaa-5000-7000-8000-000000000001', '38aaaaaa-0000-4000-8000-00000000000a',
        '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]', '[[0,1],[1,2]]', 'noticed', '2026-10-08', '2026-10-08T15:00:00Z'),
       ('38aaaaaa-5000-7000-8000-000000000002', '38aaaaaa-0000-4000-8000-00000000000a',
        '[[0.1,0.5],[0.3,0.2],[0.5,0.45],[0.7,0.15],[0.9,0.6]]', '[]', null, '2026-10-08', '2026-10-08T15:10:00Z'),
       ('38bbbbbb-5000-7000-8000-000000000001', '38bbbbbb-0000-4000-8000-00000000000b',
        '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]', '[[0,2]]', 'just_because', '2026-10-08', '2026-10-08T15:00:00Z') $$,
  'a shape with a meaning, and one with none and no lines'
);
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000011', '38aaaaaa-0000-4000-8000-00000000000a',
             '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]', '[]', 'I was sad today', '2026-10-08', now()) $$,
  '23514', null, 'free text as a meaning refused (closed list)');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000012', '38aaaaaa-0000-4000-8000-00000000000a',
             '[[0.2,0.2],[0.8,0.25]]', '[]', null, '2026-10-08', now()) $$,
  '23514', null, 'two stars refused');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000013', '38aaaaaa-0000-4000-8000-00000000000a',
             '[[0,0],[0.1,0],[0.2,0],[0.3,0],[0.4,0],[0.5,0],[0.6,0],[0.7,0]]', '[]', null, '2026-10-08', now()) $$,
  '23514', null, 'eight stars refused');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000014', '38aaaaaa-0000-4000-8000-00000000000a',
             null, null, null, '2026-10-08', now()) $$,
  '23514', null, 'a live row without a shape refused');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000015', '38aaaaaa-0000-4000-8000-00000000000a',
             '{"x":1}', '[]', null, '2026-10-08', now()) $$,
  '23514', null, 'stars that are not a list refused');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000016', '38aaaaaa-0000-4000-8000-00000000000a',
             '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]',
             '[[0,1],[0,2],[1,2],[0,1],[0,2],[1,2],[0,1],[0,2],[1,2],[0,1],[0,2],[1,2],[0,1]]', null, '2026-10-08', now()) $$,
  '23514', null, 'more than twelve lines refused');
select throws_ok(
  $$ update public.loom_constellations set deleted_at = now() where id = '38aaaaaa-5000-7000-8000-000000000001' $$,
  '23514', null, 'a deletion that keeps the shape refused');
select lives_ok(
  $$ update public.loom_constellations set deleted_at = now(), stars = null, links = null, meaning = null, updated_at = now()
     where id = '38aaaaaa-5000-7000-8000-000000000002' $$,
  'letting one go erases its shape');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000001', '38bbbbbb-0000-4000-8000-00000000000b',
             '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]', '[]', null, '2026-10-08', now()) $$,
  '23505', null, 'one row per constellation id');

-- ---------------------------------------------------------------- access
select ok((select relrowsecurity from pg_class where oid = 'public.loom_constellations'::regclass), 'RLS on');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"38aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.loom_constellations), 2, 'the owner reads their own (the let-go one too)');
select is((select count(*)::int from public.loom_constellations where user_id = '38bbbbbb-0000-4000-8000-00000000000b'), 0,
  'and never anyone else''s');
select throws_ok(
  $$ insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
     values ('38aaaaaa-5000-7000-8000-000000000021', '38aaaaaa-0000-4000-8000-00000000000a',
             '[[0.2,0.2],[0.8,0.25],[0.5,0.8]]', '[]', null, '2026-10-08', now()) $$,
  '42501', null, 'the app cannot write (POST /v1/sync/push only)');
select throws_ok($$ delete from public.loom_constellations $$, '42501', null, 'nor delete');
reset role;
set local role anon;
select throws_ok($$ select * from public.loom_constellations $$, '42501', null, 'anon cannot read');
reset role;
select ok(
  not has_table_privilege('aura_admin', 'public.loom_constellations', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'the console role cannot reach them');

-- ---------------------------------------------------------------- account deletion
delete from auth.users where id = '38bbbbbb-0000-4000-8000-00000000000b';
select is((select count(*)::int from public.loom_constellations where user_id = '38bbbbbb-0000-4000-8000-00000000000b'), 0,
  'they go with the account');

select * from finish();
rollback;
