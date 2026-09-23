-- Remote flags, signed lexicon versions and device bans (migration 20261005000017; PRD 19 REQ-ADM-12 / REQ-ADM-14):
--   * feature_flags: description + updated_at (a trigger keeps it current for every role, incl. aura_admin's flips),
--     the rooms_enabled kill switch exists and is on; clients still read flags, never write them;
--   * signed_bundle_versions: content immutable (UPDATE refused), the live version can't be deleted, content version
--     matches the row; signed_bundle_current: seq only grows, signature shape;
--   * device_installs / device_bans: server-only; one active ban per install; a ban holds no account id and survives
--     the account; installs go with the account;
--   * none of the new tables is reachable by anon / authenticated, nor by aura_admin (REQ-ADM-03 allowlist unchanged).
begin;
create extension if not exists pgtap with schema extensions;
-- pgTAP's functions for the console role while this transaction runs (rolled back, like 13_admin).
grant usage on schema extensions to aura_admin;

select plan(51);

-- ---------------------------------------------------------------- flags
select has_column('public', 'feature_flags', 'description', 'feature_flags.description exists');
select has_column('public', 'feature_flags', 'updated_at', 'feature_flags.updated_at exists');
select col_not_null('public', 'feature_flags', 'updated_at', 'updated_at is never null');
select is((select enabled from public.feature_flags where key = 'rooms_enabled'), true, 'the rooms kill switch exists and is on');
select ok((select description is not null from public.feature_flags where key = 'rooms_pool_hi'), 'the Hindi pool flag is described');

alter table public.feature_flags disable trigger feature_flags_touch;
update public.feature_flags set updated_at = '2020-01-01' where key = 'rooms_pool_hi';
alter table public.feature_flags enable trigger feature_flags_touch;
set local role aura_admin;
update public.feature_flags set enabled = enabled where key = 'rooms_pool_hi';
select throws_ok($$ update public.feature_flags set description = 'x' where key = 'rooms_pool_hi' $$,
  '42501', null, 'aura_admin still cannot rewrite anything but enabled');
reset role;
select ok((select updated_at > '2020-01-02' from public.feature_flags where key = 'rooms_pool_hi'),
  'a flip by aura_admin (enabled only) still stamps updated_at');
set local role anon;
select lives_ok($$ select key, enabled, payload, description, updated_at from public.feature_flags $$, 'anon can still read every flag column');
select throws_ok($$ update public.feature_flags set enabled = false where key = 'rooms_enabled' $$, '42501', null, 'anon cannot flip a flag');
reset role;
set local role authenticated;
select throws_ok($$ insert into public.feature_flags (key) values ('pgtap_x') $$, '42501', null, 'authenticated cannot create a flag');
reset role;

-- ---------------------------------------------------------------- signed bundles
select has_table('public', 'signed_bundle_versions', 'signed_bundle_versions exists');
select has_table('public', 'signed_bundle_current', 'signed_bundle_current exists');
select col_is_pk('public', 'signed_bundle_versions', array['kind', 'version'], 'one row per kind and version');
select col_is_pk('public', 'signed_bundle_current', array['kind'], 'one live envelope per kind');

select lives_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('crisis_lexicon', 900001, '{"name":"aura.crisis_lexicon","version":900001}', repeat('a', 64), 'staff:pgtap'),
            ('crisis_lexicon', 900002, '{"name":"aura.crisis_lexicon","version":900002}', repeat('b', 64), 'staff:pgtap') $$,
  'the server stores versions'
);
select throws_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('crisis_lexicon', 900003, '{"version":1}', repeat('c', 64), 'staff:pgtap') $$,
  '23514', null, 'the stored content must carry the row''s version'
);
select throws_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('helplines_x', 1, '{"version":1}', repeat('c', 64), 'staff:pgtap') $$,
  '23514', null, 'unknown bundle kinds are refused'
);
select throws_ok(
  $$ update public.signed_bundle_versions set note = 'edited' where version = 900001 $$,
  'AR020', null, 'a stored version never changes (upload a new one)'
);
select lives_ok(
  $$ insert into public.signed_bundle_current (kind, version, seq, key_id, payload, signature, published_by)
     values ('crisis_lexicon', 900002, 100, 'ba9afcf9c1f7ab25', 'e30=', repeat('A', 86) || '==', 'staff:pgtap')
     on conflict (kind) do update set version = excluded.version, seq = excluded.seq, payload = excluded.payload,
       signature = excluded.signature, key_id = excluded.key_id, published_by = excluded.published_by $$,
  'publishing sets the live envelope'
);
select throws_ok(
  $$ delete from public.signed_bundle_versions where version = 900002 $$,
  '23503', null, 'the live version cannot be deleted'
);
select lives_ok($$ delete from public.signed_bundle_versions where version = 900001 $$, 'a version that is not live can go (break-glass)');
select throws_ok(
  $$ update public.signed_bundle_current set seq = 99 where kind = 'crisis_lexicon' $$,
  'AR021', null, 'seq never goes back (a rollback is a NEW signature with a higher seq)'
);
select lives_ok(
  $$ update public.signed_bundle_current set seq = seq + 1 where kind = 'crisis_lexicon' $$,
  'a newer seq is accepted'
);
select throws_ok(
  $$ update public.signed_bundle_current set signature = 'not-a-signature', seq = seq + 1 where kind = 'crisis_lexicon' $$,
  '23514', null, 'the signature is a base64 Ed25519 signature (64 bytes)'
);
select throws_ok(
  $$ update public.signed_bundle_current set version = 900009, seq = seq + 1 where kind = 'crisis_lexicon' $$,
  '23503', null, 'only a stored version can be live'
);

-- ---------------------------------------------------------------- installs and bans
insert into auth.users (id, email, aud, role) values
  ('17aaaaaa-0000-4000-8000-00000000000a', 'pgtap-dev-a@aura.test', 'authenticated', 'authenticated'),
  ('17bbbbbb-0000-4000-8000-00000000000b', 'pgtap-dev-b@aura.test', 'authenticated', 'authenticated');

select lives_ok(
  $$ insert into public.device_installs (user_id, install_hash, platform) values
       ('17aaaaaa-0000-4000-8000-00000000000a', repeat('1', 64), 'ios'),
       ('17bbbbbb-0000-4000-8000-00000000000b', repeat('1', 64), null) $$,
  'one install can be seen for several accounts (shared phone)'
);
select throws_ok(
  $$ insert into public.device_installs (user_id, install_hash) values ('17aaaaaa-0000-4000-8000-00000000000a', 'raw-install-id') $$,
  '23514', null, 'only HMACs are stored, never a raw install id'
);
select throws_ok(
  $$ insert into public.device_installs (user_id, install_hash, platform) values ('17aaaaaa-0000-4000-8000-00000000000a', repeat('2', 64), 'web') $$,
  '23514', null, 'platform is ios or android'
);
select lives_ok(
  $$ insert into public.device_bans (install_hash, reason_code, subject_hash, created_by)
     values (repeat('1', 64), 'grooming', repeat('f', 64), 'staff:pgtap') $$,
  'a ban holds the install hash, a reason code and the audit HMAC of the account'
);
select throws_ok(
  $$ insert into public.device_bans (install_hash, reason_code, created_by) values (repeat('1', 64), 'again', 'staff:pgtap') $$,
  '23505', null, 'one active ban per install'
);
select lives_ok(
  $$ update public.device_bans set lifted_at = now(), lifted_by = 'staff:pgtap', lift_reason = 'appeal_upheld'
      where install_hash = repeat('1', 64) and lifted_at is null $$,
  'a ban can be lifted (with who and why)'
);
select lives_ok(
  $$ insert into public.device_bans (install_hash, reason_code, created_by) values (repeat('1', 64), 'again', 'staff:pgtap') $$,
  'after a lift the install can be banned again (history kept)'
);
select throws_ok(
  $$ update public.device_bans set lifted_at = now() where install_hash = repeat('1', 64) and lifted_at is null $$,
  '23514', null, 'a lift always says who and why'
);
select throws_ok(
  $$ insert into public.device_bans (install_hash, reason_code, created_by) values (repeat('3', 64), 'Bad Reason', 'staff:pgtap') $$,
  '23514', null, 'reason codes are machine codes'
);
select is_empty(
  $$ select column_name from information_schema.columns
      where table_schema = 'public' and table_name = 'device_bans' and (column_name like '%user%' or data_type = 'uuid' and column_name <> 'id' and column_name <> 'report_id') $$,
  'device_bans holds no account id'
);

delete from auth.users where id = '17aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.device_installs where user_id = '17aaaaaa-0000-4000-8000-00000000000a'), 0,
  'installs go with the account');
select is((select count(*)::int from public.device_bans where install_hash = repeat('1', 64)), 2,
  'bans outlive the account (a new account on that phone is still refused)');

-- ---------------------------------------------------------------- server-only
select ok(
  (select bool_and(c.relrowsecurity) from pg_class c
    where c.oid in ('public.signed_bundle_versions'::regclass, 'public.signed_bundle_current'::regclass,
                    'public.device_installs'::regclass, 'public.device_bans'::regclass)),
  'RLS is on for every new table'
);
select is_empty(
  $$ select tablename from pg_policies where schemaname = 'public'
      and tablename in ('signed_bundle_versions','signed_bundle_current','device_installs','device_bans') $$,
  'no client policies on the new tables'
);
select ok(
  not has_table_privilege(r, format('public.%I', t), 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  format('%s holds no privilege on %s', r, t)
)
from unnest(array['anon', 'authenticated', 'aura_admin']) r,
     unnest(array['signed_bundle_versions', 'signed_bundle_current', 'device_installs', 'device_bans']) t
order by r, t;

select * from finish();
rollback;
