-- W07 (migration 20261005000037): the commitment history trigger and the outcomes function.
-- The scenario is small enough to derive by hand; T = today, B = T - 60.
--
--   25 adults, each with habit A (committed at B) and habit H (never committed), both created 30 days before B.
--   A logs: B-10, B-5 | B+1, B+2       users 1-15 also B+8         H logs: B-9, B-4 | B+2
--   users 1-5 end their commitment on B+20 (an 'end' event).
--
--   Rest episodes (a habit unlogged for two full days, decay would start 3 days after its last log):
--     committed A: 10 users x 1 (not recovered, lapsed) + 15 users x 2 (one recovered, not lapsed; one not, lapsed)
--                  -> 40 episodes, 15 recovered (0.375), 25 lapsed (0.625)
--     control H:   25 x 1 (never logged again); lapsed for the 10 users whose A has no log after B+2 (0.4)
--   Logs change over the 14 days after vs before: A 0 (users 6-25) or +1 (users 1-15 have B+8; the first 5 are among them)
--     -> the 10 users 16-25 change 0, the 15 users 1-15 change +1: mean 0.6; H changes -1; difference (10x1 + 15x2)/25 = 1.6
--   Ended within 30 days: 5 of 25 = 0.2
begin;
create extension if not exists pgtap with schema extensions;

select plan(23);

create function pg_temp.mk(n int, prefix text) returns void language plpgsql as $$
declare
  b date := current_date - 60;
  u uuid; a uuid; h uuid; i int;
begin
  for i in 1..n loop
    u := (prefix || lpad(i::text, 12, '0'))::uuid;
    a := ('37a00000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    h := ('37b00000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
    insert into auth.users (id, email, aud, role)
      values (u, 'pgtap-37-' || prefix || i || '@aura.test', 'authenticated', 'authenticated');
    insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone)
      values (u, current_date - interval '30 years', 'en', 'en', 'Asia/Kolkata');
    insert into public.habits (id, user_id, kind, name, created_at, committed_from)
      values (a, u, 'custom', 'A', (b - 30)::timestamptz, b);
    insert into public.habits (id, user_id, kind, name, created_at)
      values (h, u, 'custom', 'H', (b - 30)::timestamptz);
    insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts)
      select gen_random_uuid(), u, a, d, d::timestamptz from unnest(array[b - 10, b - 5, b + 1, b + 2]) d;
    if i <= 15 then
      insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts)
        values (gen_random_uuid(), u, a, b + 8, (b + 8)::timestamptz);
    end if;
    insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts)
      select gen_random_uuid(), u, h, d, d::timestamptz from unnest(array[b - 9, b - 4, b + 2]) d;
    if i <= 5 then
      insert into public.habit_commitment_events (user_id, habit_id, kind, day) values (u, a, 'end', b + 20);
    end if;
  end loop;
end
$$;

select pg_temp.mk(25, '37000000-0000-4000-8000-');

-- ---------- the history trigger
select is((select count(*)::int from public.habit_commitment_events where kind = 'start'), 25,
          'inserting a committed habit records its start (one per habit; uncommitted habits record nothing)');
select is((select day from public.habit_commitment_events where kind = 'start' limit 1), current_date - 60,
          'a start is on record for the day the person committed');

update public.habits set committed_from = null where id = '37a00000-0000-4000-8000-000000000025';
select is((select count(*)::int from public.habit_commitment_events
            where habit_id = '37a00000-0000-4000-8000-000000000025' and kind = 'end'), 1,
          'ending a commitment records an end');
update public.habits set committed_from = current_date where id = '37a00000-0000-4000-8000-000000000025';
update public.habits set committed_from = current_date - 1 where id = '37a00000-0000-4000-8000-000000000025';
select is((select array_agg(kind order by id) from public.habit_commitment_events
            where habit_id = '37a00000-0000-4000-8000-000000000025'), array['start', 'end', 'start', 'end', 'start'],
          'a new start and a changed start each end the one before, so intervals never overlap');
update public.habits set active = false where id = '37a00000-0000-4000-8000-000000000025';
select is((select count(*)::int from public.habit_commitment_events
            where habit_id = '37a00000-0000-4000-8000-000000000025'), 5, 'other edits record nothing');
-- Restore user 25 exactly as the scenario describes (an interval [B, infinity)).
delete from public.habit_commitment_events where habit_id = '37a00000-0000-4000-8000-000000000025';
update public.habits set committed_from = null where id = '37a00000-0000-4000-8000-000000000025';
delete from public.habit_commitment_events where habit_id = '37a00000-0000-4000-8000-000000000025';
update public.habits set committed_from = current_date - 60 where id = '37a00000-0000-4000-8000-000000000025';
update public.habits set active = true where id = '37a00000-0000-4000-8000-000000000025';

select ok(not has_table_privilege('authenticated', 'public.habit_commitment_events', 'SELECT')
       and not has_table_privilege('anon', 'public.habit_commitment_events', 'SELECT'),
          'clients cannot read the history (server-only)');
select ok(not has_function_privilege('authenticated', 'public.commitment_outcomes(date)', 'EXECUTE'),
          'clients cannot call the outcomes function');

select ok(has_function_privilege('aura_admin', 'public.commitment_outcomes(date)', 'EXECUTE')
      and not has_table_privilege('aura_admin', 'public.habit_commitment_events', 'SELECT'),
          'the console role can call the aggregate function but cannot read the history table');

-- ---------- the outcomes
create temp table o as select * from public.commitment_outcomes();
select is((select count(*)::int from o), 8, 'eight cells: recovery, lapse (committed and control), logs change (committed, control, difference), ended');

select is((select value from o where measure = 'recovery_7d' and cohort = 'committed'), 0.375, 'recovery, committed: 15 of 40 episodes');
select is((select units from o where measure = 'recovery_7d' and cohort = 'committed'), 40, '...over 40 episodes');
select is((select value from o where measure = 'recovery_7d' and cohort = 'control'), 0.0, 'recovery, control: 0 of 25');
select is((select value from o where measure = 'lapse_14d' and cohort = 'committed'), 0.625, 'lapse, committed: 25 of 40');
select is((select value from o where measure = 'lapse_14d' and cohort = 'control'), 0.4, 'lapse, control: 10 of 25');
select is((select value from o where measure = 'logs_14d_change' and cohort = 'committed'), 0.6, 'logs change, committed: mean +0.6');
select is((select value from o where measure = 'logs_14d_change' and cohort = 'control'), -1.0, 'logs change, control: -1');
select is((select value from o where measure = 'logs_14d_change' and cohort = 'difference'), 1.6, 'within-person difference: +1.6');
select is((select value from o where measure = 'ended_30d'), 0.2, 'ended within 30 days: 5 of 25');
select is((select bool_or(suppressed) from o), false, '25 people: nothing suppressed');

-- ---------- deleting an account with commitments must not fail (the trigger runs during the cascade)
select lives_ok($$ delete from auth.users where email like 'pgtap-37-37000000%' $$,
                'deleting the accounts (habits cascade, the trigger fires) works');
select is((select count(*)::int from public.habit_commitment_events where user_id::text like '37000000-%'), 0,
          'and their history goes with them');

-- ---------- a small cohort is suppressed, never shown
select pg_temp.mk(5, '37100000-0000-4000-8000-');
select ok((select bool_and(suppressed and value is null) from public.commitment_outcomes()),
          'fewer than 20 people: every cell is suppressed (no value)');
select is((select max(users) from public.commitment_outcomes()), 5, '...but the number of people is still reported');

select * from finish();
rollback;
