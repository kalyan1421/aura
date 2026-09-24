-- Milestone A gaps (migration 20261005000019):
--   * signed bundles accept the kind `helplines` (the crisis helpline directory) with the same guarantees as the
--     lexicon: content immutable, the stored content carries its version, seq only grows, the live version can't go;
--     other kinds are still refused;
--   * room_pool_waitlist ("Tell me when they open"): one row per account and pool, only pools that open later, goes
--     with the account, server-only (no client or console access).
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin;

select plan(22);

-- ---------------------------------------------------------------- helplines bundle kind
select lives_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('helplines', 900001, '{"name":"aura.helplines","version":900001,"countries":{}}', repeat('a', 64), 'staff:pgtap'),
            ('helplines', 900002, '{"name":"aura.helplines","version":900002,"countries":{}}', repeat('b', 64), 'staff:pgtap') $$,
  'helpline directory versions can be stored'
);
select lives_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('crisis_lexicon', 900001, '{"name":"aura.crisis_lexicon","version":900001}', repeat('a', 64), 'staff:pgtap') $$,
  'the same version number exists independently per kind'
);
select throws_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('helplines', 900003, '{"version":1}', repeat('c', 64), 'staff:pgtap') $$,
  '23514', null, 'the stored directory must carry the row''s version'
);
select throws_ok(
  $$ insert into public.signed_bundle_versions (kind, version, content, content_sha256, created_by)
     values ('helplines_x', 1, '{"version":1}', repeat('c', 64), 'staff:pgtap') $$,
  '23514', null, 'other kinds are still refused'
);
select throws_ok(
  $$ update public.signed_bundle_versions set note = 'edited' where kind = 'helplines' and version = 900001 $$,
  'AR020', null, 'a stored directory never changes (upload a new version)'
);
select lives_ok(
  $$ insert into public.signed_bundle_current (kind, version, seq, key_id, payload, signature, published_by)
     values ('helplines', 900002, 100, 'ba9afcf9c1f7ab25', 'e30=', repeat('A', 86) || '==', 'staff:pgtap')
     on conflict (kind) do update set version = excluded.version, seq = excluded.seq, payload = excluded.payload,
       signature = excluded.signature, key_id = excluded.key_id, published_by = excluded.published_by $$,
  'a directory can be live, next to the lexicon'
);
select throws_ok(
  $$ delete from public.signed_bundle_versions where kind = 'helplines' and version = 900002 $$,
  '23503', null, 'the live directory version cannot be deleted'
);
select throws_ok(
  $$ update public.signed_bundle_current set seq = 99 where kind = 'helplines' $$,
  'AR021', null, 'the directory seq never goes back (a rollback is a NEW signature)'
);
select lives_ok(
  $$ update public.signed_bundle_current set version = 900001, seq = seq + 1 where kind = 'helplines' $$,
  'rolling back to an older stored version with a higher seq works'
);
select throws_ok(
  $$ update public.signed_bundle_current set version = 900009, seq = seq + 1 where kind = 'helplines' $$,
  '23503', null, 'only a stored directory version can be live'
);
select is(
  (select array_agg(kind order by kind) from public.signed_bundle_versions where version = 900001),
  array['crisis_lexicon', 'helplines'],
  'lexicon and directory versions live side by side'
);

-- ---------------------------------------------------------------- room_pool_waitlist
select has_table('public', 'room_pool_waitlist', 'room_pool_waitlist exists');
select col_is_pk('public', 'room_pool_waitlist', array['user_id', 'pool'], 'one row per account and pool');

insert into auth.users (id, email, aud, role) values
  ('19aaaaaa-0000-4000-8000-00000000000a', 'pgtap-pool-a@aura.test', 'authenticated', 'authenticated');

select lives_ok(
  $$ insert into public.room_pool_waitlist (user_id, pool) values ('19aaaaaa-0000-4000-8000-00000000000a', 'hi') $$,
  'the Hindi + Hinglish pool can be waited for'
);
select throws_ok(
  $$ insert into public.room_pool_waitlist (user_id, pool) values ('19aaaaaa-0000-4000-8000-00000000000a', 'hi') $$,
  '23505', null, 'a second tap is the same row'
);
select throws_ok(
  $$ insert into public.room_pool_waitlist (user_id, pool) values ('19aaaaaa-0000-4000-8000-00000000000a', 'te') $$,
  '23514', null, 'only pools that open later'
);
select ok((select requested_at is not null from public.room_pool_waitlist where user_id = '19aaaaaa-0000-4000-8000-00000000000a'),
  'the request time is kept (the sweep serves the oldest first)');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"19aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ select * from public.room_pool_waitlist $$, '42501', null, 'the app cannot read it (server-only)');
select throws_ok(
  $$ insert into public.room_pool_waitlist (user_id, pool) values ('19aaaaaa-0000-4000-8000-00000000000a', 'hi') $$,
  '42501', null, 'the app cannot write it (POST /v1/sync/push only)'
);
reset role;

select ok(
  not has_table_privilege('aura_admin', 'public.room_pool_waitlist', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE')
  and not has_table_privilege('anon', 'public.room_pool_waitlist', 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE'),
  'neither the console role nor anon holds any privilege on it'
);
select ok((select relrowsecurity from pg_class where oid = 'public.room_pool_waitlist'::regclass), 'RLS is on');

delete from auth.users where id = '19aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.room_pool_waitlist where user_id = '19aaaaaa-0000-4000-8000-00000000000a'), 0,
  'opt-ins go with the account');

select * from finish();
rollback;
