-- Longest glow streak (migration 20261005000030, RULES.md §7): a server-derived column on streak_state, read through the
-- existing select-own policy, never written by clients.
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

select has_column('public', 'streak_state', 'longest_glow_streak', 'streak_state.longest_glow_streak exists');
select col_not_null('public', 'streak_state', 'longest_glow_streak', 'longest_glow_streak is not null');
select col_default_is('public', 'streak_state', 'longest_glow_streak', '0', 'longest_glow_streak defaults to 0');

insert into auth.users (id, email) values ('30000000-0000-4000-8000-000000000001', 'longest-a@aura.test');
insert into public.streak_state (user_id, glow_streak) values ('30000000-0000-4000-8000-000000000001', 4);

select is(
  (select longest_glow_streak from public.streak_state where user_id = '30000000-0000-4000-8000-000000000001'),
  0, 'a new row starts at 0 (the server writes the folded value)');

select throws_ok(
  $$ update public.streak_state set longest_glow_streak = -1 where user_id = '30000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'a negative longest streak is refused');

-- Clients: own row readable, never writable.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.streak_state where longest_glow_streak = 0),
  1, 'the owner reads longest_glow_streak through select-own');
select throws_ok(
  $$ update public.streak_state set longest_glow_streak = 99 $$,
  '42501', null, 'clients cannot write it');
reset role;

select * from finish();
rollback;
