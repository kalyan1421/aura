-- Reminder smart timing (migration 20261005000033, PRD 12 rule 7): two server-only counters on notification_activity.
begin;
create extension if not exists pgtap with schema extensions;

select plan(6);

select has_column('public', 'notification_activity', 'reminder_last_sent_at', 'reminder_last_sent_at exists');
select has_column('public', 'notification_activity', 'reminder_ignored', 'reminder_ignored exists');
select col_default_is('public', 'notification_activity', 'reminder_ignored', '0', 'reminder_ignored starts at 0');

insert into auth.users (id, email) values ('33000000-0000-4000-8000-000000000001', 'pgtap-smart@aura.test');
insert into public.notification_activity (user_id) values ('33000000-0000-4000-8000-000000000001')
  on conflict (user_id) do nothing;
select throws_ok(
  $$ update public.notification_activity set reminder_ignored = -1 where user_id = '33000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'a negative count is refused');

select ok(
  not has_table_privilege('authenticated', 'public.notification_activity', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('anon', 'public.notification_activity', 'SELECT, INSERT, UPDATE, DELETE'),
  'still server-only: no client privilege');
select is(
  (select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'notification_activity'),
  0, 'no client policies');

select * from finish();
rollback;
