-- F13 Keepsakes (PRD 06a "F13 Share cards & Keepsakes" › Keepsakes; 10-data-model `keepsakes`; REQ-SHR-05 / REQ-SHR-06;
-- 21-open-questions CI-8: keepsakes are NEVER visible to strangers). Rules: contracts/rules/RULES.md §11. Contract:
-- contracts/api/v1-keepsakes.md. Server: server/aura-api/src/keepsakes.
--
--  1. `keepsakes` — one row per (person, key) with the Aura day it was earned. NOTHING else: no link to rooms,
--     pseudonyms, capsules or content (PRD "stored as a key and a date only"). Written ONLY by NestJS (derived from
--     records it already holds, like `avatar_state`); the owner reads their own rows (select-own, RLS). No other
--     policy exists and no view, function or endpoint exposes another person's keepsakes (DS-10 + CI-8).
--     **Never lost** (REQ-SHR-05): rows can't be updated, and a delete is refused unless the account itself is going
--     (its deletion is due — the purge in src/account/account-purge.ts — or the auth user is gone, i.e. a cascade).
--  2. `keepsake_tallies` — server-only bookkeeping for the one count whose source is purged: Lantern Hour nights
--     (rooms go 7 days after they close). A count and the latest night counted, nothing that points at a room.
--
-- Both are personal: in the account purge's PERSONAL_TABLES and cascade with auth.users.
-- Idempotent (safe to re-run): on a shared local stack it may be applied ahead of lower-numbered migrations.

-- =============================================================================================== 1. keepsakes
create table if not exists public.keepsakes (
  user_id      uuid not null references auth.users(id) on delete cascade,
  keepsake_key text not null check (keepsake_key in (
                 'capsule_sealed_first', 'capsule_opened_first',
                 'glow_days_7', 'glow_days_30', 'glow_days_100', 'glow_days_365',
                 'ripples_first',
                 'lantern_hours_1', 'lantern_hours_10', 'lantern_hours_50',
                 'sanctuary_minutes_60', 'sanctuary_minutes_300', 'sanctuary_minutes_1000')),
  earned_on    date not null,                                    -- the Aura day it was earned (RULES.md §11)
  primary key (user_id, keepsake_key)
);
comment on table public.keepsakes is
  'F13 earned-only seals: a key and the day it was earned, nothing else. Written only by NestJS; select-own; never '
  'updated, never removed except with the account; never visible to anyone else (DS-10, CI-8).';

alter table public.keepsakes enable row level security;
drop policy if exists own_read on public.keepsakes;
create policy own_read on public.keepsakes for select to authenticated using (user_id = (select auth.uid()));
revoke all on table public.keepsakes from anon, authenticated;
grant select on table public.keepsakes to authenticated;

-- Never lost: keys and days are final; a row goes only with its account.
create or replace function public.keepsakes_never_lost() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'keepsakes_are_final' using errcode = 'AR060';
  end if;
  -- DELETE: allowed only while the account is being purged (deletion due) or already gone (FK cascade).
  if exists (select 1 from auth.users u where u.id = old.user_id)
     and not exists (select 1 from public.account_deletions d where d.user_id = old.user_id and d.scheduled_for <= now()) then
    raise exception 'keepsakes_are_never_lost' using errcode = 'AR060';
  end if;
  return old;
end $$;
revoke all on function public.keepsakes_never_lost() from public, anon, authenticated;
drop trigger if exists keepsakes_never_lost on public.keepsakes;
create trigger keepsakes_never_lost before update or delete on public.keepsakes
  for each row execute function public.keepsakes_never_lost();

-- =============================================================================================== 2. tallies
create table if not exists public.keepsake_tallies (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  lantern_nights  int not null default 0 check (lantern_nights >= 0),
  lantern_through timestamptz,                                    -- the latest Lantern Hour night already counted
  updated_at      timestamptz not null default now()
);
comment on table public.keepsake_tallies is
  'F13 server-only: Lantern Hour nights counted for keepsakes (rooms are purged; the count is not). No room link.';

alter table public.keepsake_tallies enable row level security;
revoke all on table public.keepsake_tallies from anon, authenticated;
