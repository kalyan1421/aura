-- Milestone A gaps (PRD 18 "Helplines by country"; 06b F5 / 14-states "Tell me when they open"; 12-notifications).
-- Server: server/aura-api/src/remote-config (helplines.service.ts, GET /v1/helplines, /admin/helplines*) and
-- src/notifications (pool-waitlist.ts: the sync entity `room_pool_waitlist` and the `pool-open-sweep` job).
-- Contracts: contracts/safety/helplines.schema.json, contracts/api/v1.md "Helpline directory versions",
-- contracts/api/v1-notifications.md "rooms_pool_open". Runbook: docs/setup/lexicon-and-flags.md.
--
--  1. Signed bundles gain the kind `helplines`: the crisis helpline directory is versioned, signed and reversible like
--     the crisis lexicon (same tables, same immutability / seq triggers, same Owner-only publish).
--  2. `room_pool_waitlist` — "Tell me when they open" on the Hindi + Hinglish pool screen: one row per account and
--     pool until the pool opens. The worker's sweep sends one push per row once the pool's flag is on and deletes
--     the row in the same transaction (once, then the opt-in is gone). Personal: in the account purge's
--     PERSONAL_TABLES and cascades with the auth user. Server-only like the other push tables (written through
--     POST /v1/sync/push, never by a client).

-- =============================================================================================== 1. bundle kind
alter table public.signed_bundle_versions drop constraint signed_bundle_versions_kind_check;
alter table public.signed_bundle_versions
  add constraint signed_bundle_versions_kind_check check (kind in ('crisis_lexicon', 'helplines'));
alter table public.signed_bundle_current drop constraint signed_bundle_current_kind_check;
alter table public.signed_bundle_current
  add constraint signed_bundle_current_kind_check check (kind in ('crisis_lexicon', 'helplines'));

comment on table public.signed_bundle_versions is
  'Uploaded signed-bundle versions (REQ-ADM-12): crisis lexicon and helpline directory. Content never changes once stored; publishing signs a copy into signed_bundle_current.';
comment on table public.signed_bundle_current is
  'The live signed envelope per kind, served by GET /v1/lexicon/crisis and GET /v1/helplines. seq only grows (rollback = new signature).';

-- =============================================================================================== 2. pool waitlist
create table public.room_pool_waitlist (
  user_id      uuid not null references auth.users(id) on delete cascade,
  pool         text not null check (pool in ('hi')),          -- language pools that open later (rooms.language_pool)
  requested_at timestamptz not null default now(),
  primary key (user_id, pool)
);
create index room_pool_waitlist_pool_idx on public.room_pool_waitlist (pool, requested_at);
comment on table public.room_pool_waitlist is
  '"Tell me when they open" (14-states): one push when the pool''s flag turns on, then the row is deleted. Personal.';

alter table public.room_pool_waitlist enable row level security;
revoke all on table public.room_pool_waitlist from anon, authenticated;
