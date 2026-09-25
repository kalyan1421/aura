-- Pseudonym blocklist (migration 20261005000034, PRD 19 Configuration): server-only, console-readable, shape-checked.
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

select has_table('public', 'pseudonym_blocklist', 'pseudonym_blocklist exists');
select ok((select relrowsecurity from pg_class where oid = 'public.pseudonym_blocklist'::regclass), 'RLS is on');
select ok(
  not has_table_privilege('anon', 'public.pseudonym_blocklist', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('authenticated', 'public.pseudonym_blocklist', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'clients have no privilege');
select ok(
  not has_table_privilege('aura_admin', 'public.pseudonym_blocklist', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'the console role has no grant (NestJS reads and writes it as the service role behind the console routes)');

select lives_ok(
  $$ insert into public.pseudonym_blocklist (pseudonym, reason_code, created_by) values ('Quiet Comet', 'pgtap', 'pgtap') $$,
  'a pseudonym-shaped name stores');
select throws_ok(
  $$ insert into public.pseudonym_blocklist (pseudonym, reason_code, created_by) values ('call me 98765', 'pgtap', 'pgtap') $$,
  '23514', null, 'only pseudonym-shaped names');
select throws_ok(
  $$ insert into public.pseudonym_blocklist (pseudonym, reason_code, created_by) values ('Soft Star', 'Bad Reason!', 'pgtap') $$,
  '23514', null, 'a reason code is a code');

select * from finish();
rollback;
