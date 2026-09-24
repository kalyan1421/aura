-- Milestone B security review (migration 20261005000024, docs/security/milestone-b-review.md).
-- Catalogue-wide invariants of the client ↔ database boundary. Unlike the per-feature tests (02, 09, 10, 18, 20, 21 …)
-- these enumerate the catalogue at run time, so a FUTURE migration that forgets a revoke / RLS / search_path fails here
-- without anyone updating a table list:
--   * every table in public / echo_library has RLS; clients hold no write privilege and no write policy on any of them;
--   * `using (true)` only on the three catalogues; every other client policy is select-own (auth.uid());
--   * clients execute only the two Realtime topic checks; every SECURITY DEFINER function pins search_path; nobody but
--     the owner can create objects in the schemas those functions resolve against;
--   * new functions are not client-callable by default (SR-4);
--   * private-media: private, no storage policies, 6 MiB object cap (SR-3);
--   * realtime.messages: authenticated only, every policy gated by a membership function;
--   * the console role aura_admin writes only the console tables (PRD 19 least privilege).
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- Tables in the application schemas (extension-owned objects excluded).
create temp table app_tables on commit drop as
select c.oid, n.nspname, c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname in ('public', 'echo_library')
   and c.relkind in ('r', 'p')
   and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');

create temp table app_functions on commit drop as
select p.oid, n.nspname, p.proname, p.prosecdef, p.proconfig, pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('public', 'echo_library')
   and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e');

select cmp_ok((select count(*)::int from app_tables), '>=', 70, 'sanity: the application schemas hold the expected number of tables');

-- ---------------------------------------------------------------- tables: RLS, client writes
select is(
  (select array_agg(nspname || '.' || relname order by 1) from app_tables t where not (select relrowsecurity from pg_class where oid = t.oid)),
  null,
  'every table in public / echo_library has row level security enabled'
);

select is(
  (select array_agg(distinct t.nspname || '.' || t.relname || ':' || r.rolname)
     from app_tables t
     cross join (values ('anon'), ('authenticated')) r(rolname)
    where has_table_privilege(r.rolname, t.oid, 'INSERT') or has_table_privilege(r.rolname, t.oid, 'UPDATE')
       or has_table_privilege(r.rolname, t.oid, 'DELETE') or has_table_privilege(r.rolname, t.oid, 'TRUNCATE')
       or has_any_column_privilege(r.rolname, t.oid, 'INSERT') or has_any_column_privilege(r.rolname, t.oid, 'UPDATE')),
  null,
  'no client role (anon / authenticated) holds any write privilege on any application table or column'
);

select is(
  (select array_agg(t.relname || '.' || p.polname order by 1)
     from pg_policy p join app_tables t on t.oid = p.polrelid
    where p.polcmd <> 'r'),
  null,
  'no INSERT / UPDATE / DELETE / ALL policy exists on any application table (clients only ever read)'
);

select is(
  (select array_agg(t.relname || '.' || p.polname order by 1)
     from pg_policy p join app_tables t on t.oid = p.polrelid
    where coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') = 'true'
      and t.relname not in ('moods', 'preset_habits', 'feature_flags')),
  null,
  '`using (true)` only on the public catalogues (moods, preset_habits, feature_flags)'
);

select is(
  (select array_agg(t.relname || '.' || p.polname order by 1)
     from pg_policy p join app_tables t on t.oid = p.polrelid
    where t.relname not in ('moods', 'preset_habits', 'feature_flags')
      and (pg_get_expr(p.polqual, p.polrelid) !~ '^\(user_id = (auth\.uid\(\)|\( SELECT auth\.uid\(\) AS uid\))\)$'
           or p.polroles <> array['authenticated'::regrole]::oid[])),
  null,
  'every other client policy is exactly select-own for authenticated: user_id = auth.uid()'
);

select is(
  (select array_agg(t.relname order by t.relname)
     from app_tables t
    where has_table_privilege('anon', t.oid, 'SELECT')
      and exists (select 1 from pg_attribute a where a.attrelid = t.oid and a.attname = 'user_id' and not a.attisdropped)
      and exists (select 1 from pg_policy p where p.polrelid = t.oid and 'anon'::regrole = any(p.polroles))),
  null,
  'no table with a user_id column has a policy for anon'
);

select is(
  (select array_agg(c.oid::regclass::text order by 1)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'S' and n.nspname in ('public', 'echo_library')
      and (has_sequence_privilege('anon', c.oid, 'USAGE,SELECT,UPDATE') or has_sequence_privilege('authenticated', c.oid, 'USAGE,SELECT,UPDATE'))),
  null,
  'no sequence is usable by a client role'
);

select ok(
  not has_schema_privilege('anon', 'echo_library', 'USAGE') and not has_schema_privilege('authenticated', 'echo_library', 'USAGE'),
  'echo_library (unlinked echo recordings) is not reachable by client roles at all'
);

-- ---------------------------------------------------------------- functions
select is(
  (select array_agg(nspname || '.' || proname || '(' || args || ')' order by 1) from app_functions f
    where has_function_privilege('anon', f.oid, 'EXECUTE')),
  null,
  'anon executes no application function'
);

select is(
  (select array_agg(proname order by proname) from app_functions f where has_function_privilege('authenticated', f.oid, 'EXECUTE')),
  array['realtime_topic_allowed', 'ripples_topic_allowed']::name[],
  'authenticated executes only the two Realtime topic checks (each answers for the caller''s own membership only)'
);

select is(
  (select array_agg(nspname || '.' || proname order by 1) from app_functions
    where prosecdef and not exists (select 1 from unnest(coalesce(proconfig, '{}')) c where c like 'search_path=%')),
  null,
  'every SECURITY DEFINER function pins its search_path'
);

select is(
  (select array_agg(r.rolname || ' on ' || s.nspname order by 1)
     from (values ('public'), ('echo_library'), ('extensions')) s(nspname)
     cross join (values ('anon'), ('authenticated'), ('aura_admin'), ('service_role')) r(rolname)
    where has_schema_privilege(r.rolname, s.nspname, 'CREATE')),
  null,
  'no client, console or service role can create objects in the schemas SECURITY DEFINER functions resolve against'
);

-- SR-4: a function created now (by the migration owner, like any future migration) is not client-callable by default.
create function public.sr24_probe() returns int language sql security definer set search_path = '' as $$ select 1 $$;
select ok(
  not has_function_privilege('anon', 'public.sr24_probe()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'public.sr24_probe()', 'EXECUTE'),
  'SR-4: a new function in public is NOT executable by anon / authenticated unless a migration grants it'
);
select ok(has_function_privilege('service_role', 'public.sr24_probe()', 'EXECUTE'), 'SR-4: service_role keeps EXECUTE on new functions');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"0aaaaaaa-0000-4000-8000-0000000000a4","role":"authenticated","aud":"authenticated"}', true);
select throws_ok('select public.sr24_probe()', '42501', null, 'SR-4: authenticated gets 42501 calling a new, ungranted function');
reset role;

-- ---------------------------------------------------------------- storage
select is(
  (select row(public, file_size_limit)::text from storage.buckets where id = 'private-media'),
  row(false, 6291456::bigint)::text,
  'SR-3: private-media is private and capped at 6 MiB per object (the largest object the API signs for)'
);

select is(
  (select array_agg(polname order by 1) from pg_policy
    where polrelid = 'storage.objects'::regclass
      and (coalesce(pg_get_expr(polqual, polrelid), '') || coalesce(pg_get_expr(polwithcheck, polrelid), '')) ~ 'private-media|^true$|^$'),
  null,
  'no storage.objects policy touches private-media or is unconditional (clients only use NestJS-signed URLs)'
);

-- ---------------------------------------------------------------- realtime authorization
select is(
  (select array_agg(polname order by 1) from pg_policy
    where polrelid = 'realtime.messages'::regclass and polroles <> array['authenticated'::regrole]::oid[]),
  null,
  'every realtime.messages policy is for authenticated only (no anon / public)'
);

select is(
  (select array_agg(polname order by 1) from pg_policy
    where polrelid = 'realtime.messages'::regclass
      and (coalesce(pg_get_expr(polqual, polrelid), '') || coalesce(pg_get_expr(polwithcheck, polrelid), ''))
          !~ '(realtime|ripples)_topic_allowed'),
  null,
  'every realtime.messages policy is gated by a membership check (realtime_topic_allowed / ripples_topic_allowed)'
);

select is(
  (select array_agg(polname order by 1) from pg_policy
    where polrelid = 'realtime.messages'::regclass and polcmd = 'a'
      and coalesce(pg_get_expr(polwithcheck, polrelid), '') !~ '''game:%''::text'),
  null,
  'clients may only WRITE to game:<session> topics (rooms, member and ripples topics are server-send only)'
);

-- ---------------------------------------------------------------- console role (PRD 19 least privilege)
select is(
  (select array_agg(t.relname order by t.relname)
     from app_tables t
    where has_table_privilege('aura_admin', t.oid, 'INSERT') or has_table_privilege('aura_admin', t.oid, 'UPDATE')
       or has_table_privilege('aura_admin', t.oid, 'DELETE') or has_table_privilege('aura_admin', t.oid, 'TRUNCATE')
       or has_any_column_privilege('aura_admin', t.oid, 'INSERT') or has_any_column_privilege('aura_admin', t.oid, 'UPDATE')),
  array['admin_grievances', 'admin_legal_orders', 'admin_mandatory_checklists', 'admin_pages', 'feature_flags', 'moderation_actions']::name[],
  'aura_admin writes only the console tables (+ feature_flags.enabled); every other change goes through an audited SECURITY DEFINER function'
);

select * from finish();
rollback;
