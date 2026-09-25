-- Console follow-ups (migration 20261005000029, PRD 19 "Configuration"):
--   * every kill switch the console lists has a current description (the console shows it instead of its own text):
--     none empty, none saying a feature is not built or not wired;
--   * the two per-region switches carry a `pausedRegions` array and point at the console's region control;
--   * the region payload stays out of `aura_admin`'s reach (it may flip `enabled` only; the service role writes the
--     payload behind the Owner-only route).
begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

select is(
  (select count(*)::int from public.feature_flags
    where key in ('room_lanterns_enabled','room_intention_enabled','ripples_enabled','ripples_echoes','gifts_enabled',
                  'quiet_enabled','lantern_wind_down_enabled','reflections_composer','rooms_enabled','rooms_pool_hi',
                  'hold_all','reduced_mode')),
  12, 'all twelve kill switches exist');

select is(
  (select count(*)::int from public.feature_flags where description is null or btrim(description) = ''),
  0, 'every flag has a description');

select is(
  (select count(*)::int from public.feature_flags
    where description ~* '(not (built|wired)|not yet built|milestone [a-c])'),
  0, 'no description says a feature is not built / not wired or names a milestone');

select ok(
  (select description like '%Kill switches page%' from public.feature_flags where key = 'quiet_enabled'),
  'quiet_enabled points at the console region control');
select ok(
  (select description like '%Kill switches page%' from public.feature_flags where key = 'lantern_wind_down_enabled'),
  'lantern_wind_down_enabled points at the console region control');

select is(
  (select count(*)::int from public.feature_flags
    where key in ('quiet_enabled','lantern_wind_down_enabled') and jsonb_typeof(payload -> 'pausedRegions') = 'array'),
  2, 'both regional switches carry a pausedRegions array');

select ok(
  has_column_privilege('aura_admin', 'public.feature_flags', 'enabled', 'UPDATE'),
  'aura_admin may flip enabled');
select ok(
  not has_column_privilege('aura_admin', 'public.feature_flags', 'payload', 'UPDATE'),
  'aura_admin may not write payload (region lists go through the service role)');
select ok(
  not has_table_privilege('authenticated', 'public.feature_flags', 'UPDATE'),
  'clients cannot change flags');

select * from finish();
rollback;
