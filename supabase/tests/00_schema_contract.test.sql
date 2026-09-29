-- Schema contract + security posture of the public schema.
-- Other stacks code against these tables/columns: additions are fine, renames/drops fail here.
begin;
create extension if not exists pgtap with schema extensions;

select plan(40);

-- ---------- Tables & columns (superset check: new columns/tables allowed) ----------
select is(
  array(
    select t from unnest(array[
      'moods','preset_habits','feature_flags','profiles','user_consents','user_data_keys',
      'check_ins','habits','habit_logs','starlight_ledger','active_days','avatar_state',
      'streak_state','sync_mutations','device_tokens','notification_prefs','crisis_events'
    ]) t
    except
    select tablename::text from pg_tables where schemaname = 'public'
  ),
  '{}'::text[],
  'all 17 contract tables exist in public'
);

with expected(tbl, cols) as (values
  ('active_days',        array['user_id','local_day']),
  ('avatar_state',       array['user_id','stage','total_starlight','hue','is_resting','ring_count','glow_level','constellation_stars','equipped_cosmetics','updated_at']),
  ('check_ins',          array['id','user_id','mood_id','quadrant','tags','note_ct','voice_path','local_day','device_ts','server_ts','source','backfill','updated_at']),
  ('crisis_events',      array['id','surface','locale','created_at']),
  ('device_tokens',      array['id','user_id','platform','token','updated_at']),
  ('feature_flags',      array['key','enabled','payload']),
  ('habit_logs',         array['id','user_id','habit_id','local_day','device_ts','server_ts']),
  ('habits',             array['id','user_id','kind','preset_key','name','active','created_at','updated_at','committed_from','paused_through']),
  ('moods',              array['id','quadrant','sort','names']),
  ('notification_prefs', array['user_id','reminder_time','quiet_start','quiet_end','discreet','lantern_opt_in','updated_at']),
  ('preset_habits',      array['key','names']),
  ('profiles',           array['user_id','birth_date','ui_locale','language_pool','timezone','tz_region','country','created_at','updated_at','deleted_at']),
  ('starlight_ledger',   array['id','user_id','amount','reason','source_id','habit_key','local_day','created_at']),
  ('streak_state',       array['user_id','glow_streak','lifetime_glow_days','rest_bank','earn_counter','last_active_day','updated_at']),
  ('sync_mutations',     array['user_id','mutation_id','entity','status','reason','applied_at']),
  ('user_consents',      array['id','user_id','purpose','policy_version','granted_at','withdrawn_at']),
  ('user_data_keys',     array['user_id','key_id','wrapped_key','created_at'])
)
select is(
  array(
    select c from unnest(e.cols) c
    except
    select column_name::text from information_schema.columns
     where table_schema = 'public' and table_name = e.tbl
  ),
  '{}'::text[],
  format('public.%s keeps all contract columns', e.tbl)
)
from expected e
order by e.tbl;

-- ---------- RLS ----------
select is_empty(
  $$ select c.relname from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p') and not c.relrowsecurity $$,
  'RLS is enabled on EVERY table in public (including future ones)'
);

select ok(
  (select relrowsecurity from pg_class where oid = format('public.%I', t)::regclass),
  format('RLS enabled on public.%s', t)
)
from unnest(array[
  'moods','preset_habits','feature_flags','profiles','user_consents','user_data_keys',
  'check_ins','habits','habit_logs','starlight_ledger','active_days','avatar_state',
  'streak_state','sync_mutations','device_tokens','notification_prefs','crisis_events'
]) t
order by t;

select is_empty(
  $$ select tablename, policyname, cmd from pg_policies where schemaname = 'public' and cmd <> 'SELECT' $$,
  'no public policy grants anything but SELECT (clients never write)'
);

-- ---------- Privileges ----------
select is_empty(
  $$ select c.relname from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p')
        and has_table_privilege('anon', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE') $$,
  'anon holds no write privilege on any public table'
);

select is_empty(
  $$ select c.relname from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p')
        and has_table_privilege('authenticated', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE') $$,
  'authenticated holds no write privilege on any public table'
);

-- Default privileges: a table created by a later migration is not client-writable either.
create table public.__pgtap_probe (id int);
alter table public.__pgtap_probe enable row level security;
select ok(
  not has_table_privilege('anon', 'public.__pgtap_probe', 'INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('authenticated', 'public.__pgtap_probe', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'default privileges: new public tables are not client-writable'
);

select * from finish();
rollback;
