-- U07 Orbit Loom: the constellations a person keeps in the Reflection sky of their personal universe.
-- Rule: contracts/rules/RULES.md section 14 (shape, meanings, 5 per Aura day). Contract: contracts/api/v1.md
-- "Loom constellations" (sync entity `loom_constellation`, ops `upsert` / `delete`). Server:
-- server/aura-api/src/constellations/loom-constellations.ts. App: apps/mobile features/orbit_loom.
--
-- Cosmetic by construction: a few star points in the unit sky, the lines between them, and optionally one meaning
-- from a closed, neutral list. No free text, no mood, nothing that touches the ledger. Written only through
-- POST /v1/sync/push; the person reads their own rows (select-own) and pulls them back after a reinstall by
-- `updated_at`. Letting one go is a soft delete that erases the shape (like capsules), so a phone that pulls later
-- still learns it is gone. Purged with the account (account-purge.ts PERSONAL_TABLES).

create table if not exists public.loom_constellations (
  id          uuid primary key,                                   -- client UUIDv7 (idempotency key)
  user_id     uuid not null references auth.users(id) on delete cascade,
  stars       jsonb,                                              -- [[x, y], ...] in the unit sky; null once deleted
  links       jsonb,                                              -- [[a, b], ...] star indices; null once deleted
  meaning     text,                                               -- optional neutral meaning; null once deleted
  local_day   date not null,                                      -- the Aura day it was kept (the per-day limit)
  device_ts   timestamptz not null,                               -- when it was kept (device clock)
  deleted_at  timestamptz,                                        -- let go (soft delete)
  server_ts   timestamptz not null default now(),
  updated_at  timestamptz not null default now(),                 -- set by every write: the pull cursor

  constraint loom_constellations_meaning check (
    meaning is null or meaning in ('noticed', 'carrying', 'ahead', 'thankful', 'just_because')
  ),
  -- A live constellation has a shape; the server validates it fully (RULES.md section 14), this is the backstop.
  -- (Explicit `is not null`: a check that evaluates to null passes.)
  constraint loom_constellations_live_shape check (
    deleted_at is not null or (
      stars is not null and links is not null
      and jsonb_typeof(stars) = 'array' and jsonb_array_length(stars) between 3 and 7
      and jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 12
      and octet_length(stars::text) <= 512 and octet_length(links::text) <= 512
    )
  ),
  -- Letting one go erases the shape and its meaning.
  constraint loom_constellations_tombstone_erased check (
    deleted_at is null or (stars is null and links is null and meaning is null)
  )
);

-- Pull (`user_id = me and updated_at >= cursor`).
create index if not exists loom_constellations_user_updated_idx on public.loom_constellations (user_id, updated_at);
-- The per-day limit counts live rows.
create index if not exists loom_constellations_user_day_idx on public.loom_constellations (user_id, local_day)
  where deleted_at is null;

comment on table public.loom_constellations is
  'U07 Orbit Loom: cosmetic constellations kept in the Reflection sky (stars, links, optional neutral meaning). Written via POST /v1/sync/push only; select-own; soft delete erases the shape; purged with the account.';

alter table public.loom_constellations enable row level security;
drop policy if exists own_read on public.loom_constellations;
create policy own_read on public.loom_constellations for select to authenticated using (user_id = (select auth.uid()));
revoke all on table public.loom_constellations from anon, authenticated;
grant select on table public.loom_constellations to authenticated;
