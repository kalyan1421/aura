-- Remote flags, signed reversible crisis-lexicon versions and device bans (PRD 19 admin console REQ-ADM-12
-- "Flag changes reach clients within 5 min without a release; lexicon versions are signed and reversible" and
-- REQ-ADM-14 "One confirm action bans account and device"; 06c F9 "versioned signed bundle … refreshed on sync").
-- Server: server/aura-api/src/remote-config (GET /v1/config, GET /v1/lexicon/crisis, /admin/lexicons/crisis*) and
-- src/devices (install ids, device bans, /admin/devices*). Contract: contracts/api/v1.md "Remote config", "Crisis
-- lexicon versions", "Device bans". Runbook and key management: docs/setup/lexicon-and-flags.md.
--
--  1. `feature_flags` gains `description` and `updated_at` (kept current by a trigger, whoever flips a flag), and the
--     `rooms_enabled` kill switch (on). Still anon/authenticated-readable; the app reads flags through GET /v1/config.
--  2. `signed_bundle_versions` — every uploaded lexicon version, content immutable once stored (UPDATE refused;
--     a version that is live can't be deleted). `signed_bundle_current` — the live, signed envelope per kind; its `seq`
--     only grows, so a rollback is a NEW signature and phones can refuse a replayed older one.
--  3. `device_installs` — which (hashed) install ids each account used. Personal: in the account purge's PERSONAL_TABLES.
--  4. `device_bans` — banned install hashes. No account column and no FK, so a ban outlives the account; `subject_hash`
--     is the audit log's HMAC of the account.
--
-- Every new table is server-only: RLS on, no policies, no client privileges, and nothing for `aura_admin` either: the
-- console's lexicon publishes and device bans run as the service role behind AdminGuard (Owner), like the moderation
-- actions in src/safety, each audited in the same transaction (REQ-ADM-03's allowlist stays as it is).

-- =============================================================================================== 1. flags
alter table public.feature_flags
  add column if not exists description text check (description is null or char_length(description) <= 300),
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.feature_flags_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
revoke all on function public.feature_flags_touch() from public, anon, authenticated;
drop trigger if exists feature_flags_touch on public.feature_flags;
create trigger feature_flags_touch before update on public.feature_flags
  for each row execute function public.feature_flags_touch();

update public.feature_flags
   set description = 'Hindi + Hinglish rooms. Off until their moderation is ready: those accounts are offered English rooms (POST /v1/rooms/match → 409 language_pool_unavailable).'
 where key = 'rooms_pool_hi' and description is null;

insert into public.feature_flags (key, enabled, payload, description)
values ('rooms_enabled', true, '{}'::jsonb,
        'Mood rooms. Off: no new room joins (POST /v1/rooms/match → 503 rooms_paused) and the app hides its join offers; rooms already joined keep working until they close.')
on conflict (key) do nothing;

comment on column public.feature_flags.updated_at is 'Last change (any role); set by trigger feature_flags_touch.';

-- =============================================================================================== 2. signed bundles
create table public.signed_bundle_versions (
  kind           text not null check (kind in ('crisis_lexicon')),
  version        int  not null check (version between 1 and 1000000),
  content        jsonb not null check (jsonb_typeof(content) = 'object'),        -- contracts/safety schema
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),       -- of the canonical JSON (sorted keys)
  vectors        jsonb not null default '[]'::jsonb check (jsonb_typeof(vectors) = 'array'),  -- the version's own cases
  note           text check (note is null or char_length(note) <= 500),
  created_at     timestamptz not null default now(),
  created_by     text not null check (char_length(created_by) between 1 and 120),  -- staff:<id> / cli:<who>
  primary key (kind, version),
  constraint signed_bundle_versions_version_matches check (content -> 'version' = to_jsonb(version))
);
comment on table public.signed_bundle_versions is
  'Uploaded crisis lexicon versions (REQ-ADM-12). Content never changes once stored; publishing signs a copy into signed_bundle_current.';

create function public.signed_bundle_versions_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'signed bundle versions never change: upload a new version instead' using errcode = 'AR020';
end $$;
revoke all on function public.signed_bundle_versions_immutable() from public, anon, authenticated;
create trigger signed_bundle_versions_no_update before update on public.signed_bundle_versions
  for each row execute function public.signed_bundle_versions_immutable();

create table public.signed_bundle_current (
  kind         text primary key check (kind in ('crisis_lexicon')),
  version      int not null,
  seq          bigint not null check (seq > 0),
  key_id       text not null check (key_id ~ '^[0-9a-f]{16}$'),
  payload      text not null check (char_length(payload) between 1 and 4000000),   -- base64 of the exact signed bytes
  signature    text not null check (signature ~ '^[A-Za-z0-9+/]{86}==$'),          -- base64 Ed25519 (64 bytes)
  published_at timestamptz not null default now(),
  published_by text not null check (char_length(published_by) between 1 and 120),
  -- The live version can't be deleted from signed_bundle_versions (NO ACTION).
  constraint signed_bundle_current_version_fk foreign key (kind, version)
    references public.signed_bundle_versions (kind, version)
);
comment on table public.signed_bundle_current is
  'The live signed envelope per kind, served by GET /v1/lexicon/crisis. seq only grows (rollback = new signature).';

create function public.signed_bundle_current_seq() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.seq <= old.seq then
    raise exception 'signed bundle seq must grow (a rollback is a new signature)' using errcode = 'AR021';
  end if;
  return new;
end $$;
revoke all on function public.signed_bundle_current_seq() from public, anon, authenticated;
create trigger signed_bundle_current_seq before update on public.signed_bundle_current
  for each row execute function public.signed_bundle_current_seq();

-- =============================================================================================== 3. installs
create table public.device_installs (
  user_id       uuid not null references auth.users(id) on delete cascade,
  install_hash  text not null check (install_hash ~ '^[0-9a-f]{64}$'),   -- HMAC of the app's random install id
  platform      text check (platform is null or platform in ('ios','android')),
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  primary key (user_id, install_hash)
);
create index device_installs_install_idx on public.device_installs (install_hash);
comment on table public.device_installs is
  'Which (hashed) app installs each account used, so a ban reaches its phones (REQ-ADM-14). Personal: purged with the account.';

-- =============================================================================================== 4. bans
create table public.device_bans (
  id           uuid primary key default gen_random_uuid(),
  install_hash text not null check (install_hash ~ '^[0-9a-f]{64}$'),
  reason_code  text not null check (reason_code ~ '^[a-z0-9_]{1,40}$'),
  subject_hash text check (subject_hash is null or subject_hash ~ '^[0-9a-f]{64}$'),  -- audit HMAC, never the account id
  report_id    uuid,                                                                   -- no FK: outlives report retention
  created_at   timestamptz not null default now(),
  created_by   text not null check (char_length(created_by) between 1 and 120),
  lifted_at    timestamptz,
  lifted_by    text check (lifted_by is null or char_length(lifted_by) between 1 and 120),
  lift_reason  text check (lift_reason is null or lift_reason ~ '^[a-z0-9_]{1,40}$'),
  constraint device_bans_lift check ((lifted_at is null) = (lifted_by is null) and (lifted_at is null) = (lift_reason is null))
);
-- One active ban per install (a lifted one stays as history).
create unique index device_bans_active_idx on public.device_bans (install_hash) where lifted_at is null;
create index device_bans_created_idx on public.device_bans (created_at desc);
comment on table public.device_bans is
  'Banned app installs (REQ-ADM-14): 403 device_banned. No account link, so a ban outlives the account.';

-- =============================================================================================== RLS / privileges
alter table public.signed_bundle_versions enable row level security;
alter table public.signed_bundle_current  enable row level security;
alter table public.device_installs        enable row level security;
alter table public.device_bans            enable row level security;

revoke all on table public.signed_bundle_versions, public.signed_bundle_current, public.device_installs, public.device_bans
  from anon, authenticated;

