-- F8 REQ-ACC-01 / PRD v1.2: "email scope only; no name, picture or profile stored".
--
-- Supabase Auth (GoTrue) copies the provider's ID-token claims into auth.users.raw_user_meta_data
-- (user_metadata) and auth.identities.identity_data on every Google / Apple sign-in. Google always
-- includes name, given/family name and picture (its SDKs request the basic profile), so they would be
-- stored even though Aura never asks for them. These BEFORE triggers drop every profile claim before the
-- row is written, on insert and on each later update (GoTrue re-copies claims at every sign-in, and a
-- client could call updateUser(data: …)).
--
-- Kept (GoTrue needs them): sub, email, email_verified, phone, phone_verified, iss, provider_id,
-- custom_claims. identities.email is a generated column over identity_data->>'email', so email stays.
-- Removing the other keys doesn't affect GoTrue: it reads the subject from identities.provider_id and
-- the email from its own columns; the profile keys are informational only.

create or replace function public.strip_oauth_profile_claims(claims jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when claims is null or jsonb_typeof(claims) <> 'object' then claims
    else claims - array[
      'name', 'full_name', 'given_name', 'family_name', 'middle_name', 'nickname',
      'preferred_username', 'user_name', 'picture', 'avatar_url', 'profile', 'website',
      'gender', 'birthdate', 'zoneinfo', 'locale', 'slug'
    ]::text[]
  end
$$;

create or replace function public.strip_oauth_profile_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.raw_user_meta_data := public.strip_oauth_profile_claims(new.raw_user_meta_data);
  return new;
end;
$$;

create or replace function public.strip_oauth_profile_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.identity_data := public.strip_oauth_profile_claims(new.identity_data);
  return new;
end;
$$;

-- Not callable by clients (PostgREST RPC); the triggers run them for GoTrue.
revoke all on function public.strip_oauth_profile_claims(jsonb) from public, anon, authenticated;
revoke all on function public.strip_oauth_profile_user() from public, anon, authenticated;
revoke all on function public.strip_oauth_profile_identity() from public, anon, authenticated;

drop trigger if exists strip_oauth_profile on auth.users;
create trigger strip_oauth_profile
  before insert or update of raw_user_meta_data on auth.users
  for each row execute function public.strip_oauth_profile_user();

drop trigger if exists strip_oauth_profile on auth.identities;
create trigger strip_oauth_profile
  before insert or update of identity_data on auth.identities
  for each row execute function public.strip_oauth_profile_identity();

-- One-time scrub of rows written before this migration (none in alpha; hosted projects may differ).
update auth.users
   set raw_user_meta_data = public.strip_oauth_profile_claims(raw_user_meta_data)
 where raw_user_meta_data ?| array[
   'name', 'full_name', 'given_name', 'family_name', 'middle_name', 'nickname',
   'preferred_username', 'user_name', 'picture', 'avatar_url', 'profile', 'website',
   'gender', 'birthdate', 'zoneinfo', 'locale', 'slug'
 ];

update auth.identities
   set identity_data = public.strip_oauth_profile_claims(identity_data)
 where identity_data ?| array[
   'name', 'full_name', 'given_name', 'family_name', 'middle_name', 'nickname',
   'preferred_username', 'user_name', 'picture', 'avatar_url', 'profile', 'website',
   'gender', 'birthdate', 'zoneinfo', 'locale', 'slug'
 ];
