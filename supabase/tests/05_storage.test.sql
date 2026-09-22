-- Storage: `private-media` is a private bucket with NO client policies; NestJS hands out signed URLs.
begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

select results_eq(
  $$ select id, name, public from storage.buckets where id = 'private-media' $$,
  $$ values ('private-media'::text, 'private-media'::text, false) $$,
  'private-media bucket exists and is private'
);
select is_empty(
  $$ select id from storage.buckets where public $$,
  'no public buckets at all'
);
select is_empty(
  $$ select policyname, cmd, roles from pg_policies
      where schemaname = 'storage' and tablename = 'objects' $$,
  'no storage.objects policies (clients can neither read nor upload directly)'
);
select is_empty(
  $$ select policyname from pg_policies
      where schemaname = 'storage' and cmd in ('INSERT', 'UPDATE', 'ALL') $$,
  'no client insert/update policies anywhere in storage'
);

-- an object uploaded through a NestJS-issued signed URL (simulated as postgres)
insert into auth.users (id, email, aud, role) values
  ('0aaaaaaa-0000-4000-8000-00000000000a', 'pgtap-a@aura.test', 'authenticated', 'authenticated');
insert into storage.objects (bucket_id, name, owner_id)
values ('private-media', '0aaaaaaa-0000-4000-8000-00000000000a/voice/0001.bin', '0aaaaaaa-0000-4000-8000-00000000000a');

-- ---------- authenticated (the object's own owner) ----------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);

select is_empty(
  $$ select name from storage.objects where bucket_id = 'private-media' $$,
  'owner cannot list/read private-media objects directly'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner_id)
     values ('private-media', '0aaaaaaa-0000-4000-8000-00000000000a/x.bin', '0aaaaaaa-0000-4000-8000-00000000000a') $$,
  '42501', null,
  'authenticated cannot upload into private-media without a signed URL'
);
select throws_ok(
  $$ insert into storage.buckets (id, name, public) values ('pgtap-rogue', 'pgtap-rogue', true) $$,
  '42501', null,
  'authenticated cannot create buckets'
);

-- ---------- anon ----------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty(
  $$ select name from storage.objects where bucket_id = 'private-media' $$,
  'anon cannot list/read private-media objects'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('private-media', 'anon/x.bin') $$,
  '42501', null,
  'anon cannot upload into private-media'
);
select is_empty(
  $$ select id from storage.buckets where id = 'private-media' $$,
  'anon cannot even see the bucket row'
);

reset role;
select * from finish();
rollback;
