-- PRD v1.2 (F8 REQ-ACC-01): email scope only — no name, picture or profile from Google / Apple is ever
-- stored in auth.users.raw_user_meta_data or auth.identities.identity_data (migration 000011).
begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

-- ---------- Shape ----------
select has_trigger('auth', 'users', 'strip_oauth_profile', 'auth.users has the strip_oauth_profile trigger');
select has_trigger('auth', 'identities', 'strip_oauth_profile', 'auth.identities has the strip_oauth_profile trigger');
select trigger_is('auth', 'users', 'strip_oauth_profile', 'public', 'strip_oauth_profile_user',
  'auth.users trigger runs public.strip_oauth_profile_user()');
select trigger_is('auth', 'identities', 'strip_oauth_profile', 'public', 'strip_oauth_profile_identity',
  'auth.identities trigger runs public.strip_oauth_profile_identity()');
select is_definer('public', 'strip_oauth_profile_user', 'user trigger function is SECURITY DEFINER');
select is_definer('public', 'strip_oauth_profile_identity', 'identity trigger function is SECURITY DEFINER');
select ok(
  not has_function_privilege('anon', 'public.strip_oauth_profile_claims(jsonb)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.strip_oauth_profile_claims(jsonb)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.strip_oauth_profile_user()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.strip_oauth_profile_identity()', 'EXECUTE'),
  'clients cannot call the strip functions (no PostgREST RPC)'
);

-- ---------- A Google sign-in, as GoTrue writes it ----------
insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data) values (
  '0aaaaaaa-0000-4000-8000-0000000011aa', 'pgtap-google@aura.test', 'authenticated', 'authenticated',
  '{"provider": "google", "providers": ["google"]}',
  '{"iss": "https://accounts.google.com", "sub": "1090000000000000000011", "email": "pgtap-google@aura.test",
    "email_verified": true, "phone_verified": false, "provider_id": "1090000000000000000011",
    "name": "Asha Rao", "full_name": "Asha Rao", "given_name": "Asha", "family_name": "Rao",
    "picture": "https://lh3.googleusercontent.com/a/pgtap", "avatar_url": "https://lh3.googleusercontent.com/a/pgtap",
    "locale": "en-IN"}'
);

select is(
  (select raw_user_meta_data from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000011aa'),
  '{"iss": "https://accounts.google.com", "sub": "1090000000000000000011", "email": "pgtap-google@aura.test",
    "email_verified": true, "phone_verified": false, "provider_id": "1090000000000000000011"}'::jsonb,
  'user_metadata keeps only iss / sub / email / verification flags / provider_id'
);

insert into auth.identities (provider_id, user_id, provider, identity_data) values (
  '1090000000000000000011', '0aaaaaaa-0000-4000-8000-0000000011aa', 'google',
  '{"iss": "https://accounts.google.com", "sub": "1090000000000000000011", "email": "Pgtap-Google@aura.test",
    "email_verified": true, "phone_verified": false, "provider_id": "1090000000000000000011",
    "name": "Asha Rao", "full_name": "Asha Rao", "given_name": "Asha", "family_name": "Rao",
    "picture": "https://lh3.googleusercontent.com/a/pgtap", "avatar_url": "https://lh3.googleusercontent.com/a/pgtap"}'
);

select is(
  (select identity_data from auth.identities where provider = 'google' and provider_id = '1090000000000000000011'),
  '{"iss": "https://accounts.google.com", "sub": "1090000000000000000011", "email": "Pgtap-Google@aura.test",
    "email_verified": true, "phone_verified": false, "provider_id": "1090000000000000000011"}'::jsonb,
  'identity_data stores no profile claims'
);
select is(
  (select email from auth.identities where provider = 'google' and provider_id = '1090000000000000000011'),
  'pgtap-google@aura.test',
  'identities.email (generated from identity_data->>email) still works'
);

-- ---------- Later sign-ins re-copy the claims (UPDATE) ----------
update auth.users
   set raw_user_meta_data = raw_user_meta_data || '{"name": "Asha", "picture": "https://example.test/p.png"}'
 where id = '0aaaaaaa-0000-4000-8000-0000000011aa';
select ok(
  not ((select raw_user_meta_data from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000011aa')
       ?| array['name', 'picture']),
  'an update never brings name / picture back into user_metadata'
);

update auth.identities
   set identity_data = identity_data || '{"given_name": "Asha", "family_name": "Rao", "avatar_url": "https://example.test/a.png"}'
 where provider = 'google' and provider_id = '1090000000000000000011';
select ok(
  not ((select identity_data from auth.identities
         where provider = 'google' and provider_id = '1090000000000000000011')
       ?| array['given_name', 'family_name', 'avatar_url']),
  'an update never brings profile claims back into identity_data'
);

-- ---------- Email OTP (and Apple, email scope only) rows are untouched ----------
insert into auth.users (id, email, aud, role, raw_user_meta_data) values (
  '0aaaaaaa-0000-4000-8000-0000000011bb', 'pgtap-otp@aura.test', 'authenticated', 'authenticated',
  '{"sub": "0aaaaaaa-0000-4000-8000-0000000011bb", "email": "pgtap-otp@aura.test", "email_verified": false, "phone_verified": false}'
);
select is(
  (select raw_user_meta_data from auth.users where id = '0aaaaaaa-0000-4000-8000-0000000011bb'),
  '{"sub": "0aaaaaaa-0000-4000-8000-0000000011bb", "email": "pgtap-otp@aura.test", "email_verified": false, "phone_verified": false}'::jsonb,
  'an email-OTP user keeps its metadata exactly'
);

-- ---------- Helper edge cases ----------
select is(public.strip_oauth_profile_claims(null), null::jsonb, 'null passes through');
select is(public.strip_oauth_profile_claims('[]'::jsonb), '[]'::jsonb, 'a non-object passes through');

select * from finish();
rollback;
