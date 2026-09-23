-- F8 REQ-ACC-11: in-app account deletion with a 7-day grace period (contracts/api/v1.md "Account deletion").
--
-- One row per account whose deletion is scheduled. Written only by NestJS (POST / DELETE
-- /v1/account/deletion); the worker's purge job (maintenance queue) removes every personal row, the
-- user's private-media objects and finally the auth.users row — which cascades this row away too, so
-- nothing keyed by the user id survives the purge (no tombstone).
--
-- Purge privileges: the API/worker connect as `postgres` (DATABASE_URL), which already holds DELETE on
-- every public table and on auth.users (+ the auth tables it scrubs), so no extra grant or SECURITY
-- DEFINER function is needed. Storage objects are removed through the Storage API (service key), never
-- by deleting storage.objects rows: storage.protect_delete() forbids that, and it would orphan the blobs.
create table public.account_deletions (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  requested_at  timestamptz not null default now(),
  scheduled_for timestamptz not null,
  constraint account_deletions_scheduled_after_request check (scheduled_for >= requested_at)
);

-- The purge scans for `scheduled_for <= now()`; the per-request guard uses the primary key.
create index account_deletions_scheduled_for_idx on public.account_deletions (scheduled_for);

-- Server-only table: RLS on with NO policies, and no client privileges at all (like user_data_keys,
-- sync_mutations, device_tokens in 000003) — any client/PostgREST access is an explicit 42501.
alter table public.account_deletions enable row level security;
revoke all on table public.account_deletions from anon, authenticated;
