-- Beta hardening follow-up to the realtime load test (migration 20261005000028, docs/perf/realtime-load-test.md):
--   * every public foreign key with ON DELETE CASCADE / SET NULL / SET DEFAULT has an index that leads with one of
--     its columns, so deletes (room purge, account deletion, evidence purge) never scan the referencing table;
--   * the indexes added for the hot purge paths exist and the FK lookups can use them; reports keep ON DELETE SET NULL.
begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

-- ---------------------------------------------------------------- the general rule
select is(
  (select coalesce(string_agg(format('%s(%s)', c.conrelid::regclass, c.conname), ', ' order by 1), '')
     from pg_constraint c
    where c.contype = 'f'
      and c.connamespace = 'public'::regnamespace
      and c.confdeltype in ('c', 'n', 'd')
      and not exists (
        select 1 from pg_index i
         where i.indrelid = c.conrelid
           and i.indkey[0] = any (c.conkey))),
  '',
  'every cascading / set-null foreign key in public has an index leading with one of its columns'
);

-- ---------------------------------------------------------------- the purge-path indexes
select has_index('public', 'reports', 'reports_reporter_member_idx', 'reports.reporter_member_id is indexed');
select has_index('public', 'reports', 'reports_target_member_idx', 'reports.target_member_id is indexed');
select has_index('public', 'reports', 'reports_target_gesture_idx', 'reports.target_gesture_id is indexed');
select has_index('public', 'gifts', 'gifts_recipient_member_idx', 'gifts.recipient_member_id is indexed');
select has_index('public', 'ripple_seats', 'ripple_seats_room_member_idx', 'ripple_seats.room_member_id is indexed');

-- ---------------------------------------------------------------- the FK lookups can use them
-- (the partial `where … is not null` indexes are usable for the FK check's `col = $1`)
create function pg_temp.plan_of(q text) returns text language plpgsql as $f$
declare r record; s text := '';
begin
  for r in execute 'explain (costs off) ' || q loop s := s || r."QUERY PLAN" || E'\n'; end loop;
  return s;
end $f$;
set local enable_seqscan = off;
select matches(
  pg_temp.plan_of($q$ select 1 from public.reports where target_gesture_id = '00000000-0000-4000-8000-000000000028' $q$),
  'reports_target_gesture_idx',
  'a gesture delete finds its reports through reports_target_gesture_idx'
);
select matches(
  pg_temp.plan_of($q$ select 1 from public.reports where reporter_member_id = '00000000-0000-4000-8000-000000000028' $q$),
  'reports_reporter_member_idx',
  'a member delete finds reports it filed through reports_reporter_member_idx'
);
select matches(
  pg_temp.plan_of($q$ select 1 from public.reports where target_member_id = '00000000-0000-4000-8000-000000000028' $q$),
  'reports_target_member_idx',
  'a member delete finds reports about it through reports_target_member_idx'
);
reset enable_seqscan;

-- ---------------------------------------------------------------- behaviour unchanged: SET NULL still applies
-- A report on a gesture keeps its row when the gesture goes (moderation history stays), with the link nulled.
select is(
  (select confdeltype::text from pg_constraint where conname = 'reports_target_gesture_id_fkey'),
  'n',
  'reports_target_gesture_id_fkey is still ON DELETE SET NULL (reports outlive what they point at)'
);

select * from finish();
rollback;
