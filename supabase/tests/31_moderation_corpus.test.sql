-- De-identified moderation corpus (migration 20261005000031, REQ-SAFE-16): server-only, and nothing in it can point
-- back to a person, room or reflection.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

select has_table('public', 'moderation_corpus', 'moderation_corpus exists');
select ok((select relrowsecurity from pg_class where oid = 'public.moderation_corpus'::regclass), 'RLS is on');
select is(
  (select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'moderation_corpus'),
  0, 'no policies: nothing reaches it through PostgREST');
select ok(
  not has_table_privilege('anon', 'public.moderation_corpus', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('authenticated', 'public.moderation_corpus', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'clients have no privilege at all');
select ok(
  not has_table_privilege('aura_admin', 'public.moderation_corpus', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'the console role has no privilege (no screen shows it)');

-- De-identified by construction: no column that names or joins to anyone or anything.
select is(
  array(select column_name::text from information_schema.columns
         where table_schema = 'public' and table_name = 'moderation_corpus' order by ordinal_position),
  array['id','language','label','source','week','text_ct','text_key'],
  'columns: only id, language, label, source, week and the sealed text');
select is(
  (select count(*)::int from information_schema.table_constraints
    where table_schema = 'public' and table_name = 'moderation_corpus' and constraint_type = 'FOREIGN KEY'),
  0, 'no foreign keys');
select is(
  (select data_type from information_schema.columns where table_schema = 'public' and table_name = 'moderation_corpus' and column_name = 'week'),
  'date', 'the only time is a date (the ISO week), never a timestamp');

-- Shapes.
insert into public.moderation_corpus (id, language, label, source, week, text_ct, text_key)
values ('31000000-0000-4000-8000-000000000001', 'te-Latn', 'allow', 'auto', '2026-10-05', repeat('A', 40), repeat('B', 40));
select is((select count(*)::int from public.moderation_corpus where id = '31000000-0000-4000-8000-000000000001'), 1,
  'a well-formed row stores');
select throws_ok(
  $$ insert into public.moderation_corpus (language, label, source, week, text_ct, text_key)
     values ('en', 'allow', 'auto', '2026-10-07', repeat('A', 40), repeat('B', 40)) $$,
  '23514', null, 'week must be a Monday (ISO week start)');
select throws_ok(
  $$ insert into public.moderation_corpus (language, label, source, week, text_ct, text_key)
     values ('en', 'crisis', 'auto', '2026-10-05', repeat('A', 40), repeat('B', 40)) $$,
  '23514', null, 'no crisis label exists (crisis text never enters the corpus, DS-7)');
select throws_ok(
  $$ insert into public.moderation_corpus (language, label, source, week, text_ct, text_key)
     values ('ta', 'allow', 'auto', '2026-10-05', repeat('A', 40), repeat('B', 40)) $$,
  '23514', null, 'only the five app languages');

select * from finish();
rollback;
