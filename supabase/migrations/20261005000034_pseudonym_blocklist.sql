-- PRD 19 "Configuration: … pseudonym word lists per language plus an offensive-combination blocklist".
--
-- Room pseudonyms are built from two curated word lists (server/aura-api/src/rooms/pseudonyms.ts): adjective + celestial
-- noun, Latin letters only (the `room_members.pseudonym` CHECK), the same names for every language pool — like the
-- brand terms, a name is never translated (recorded as an interpretation in docs/status/pending.md). The lists and a
-- first blocklist stay in code, reviewed like copy. This adds the Owner's own blocklist on top: a combination that
-- reads badly in some language or context can be taken out of use at once, from the console, without a release.
--
--   * server-only (RLS on, no client privilege, and no grant to the console role `aura_admin`: its privileges stay
--     limited to the moderation tables). NestJS reads and writes it as the service role behind role-checked console
--     routes (read: Owner + Moderator; change: Owner), audited with its reason in the hash-chained log;
--   * new memberships (rooms, Breath Ripples seats) never get a blocked name; a room that already shows one keeps it
--     for its short life (≤ 24 h, then memory) — nothing is renamed under people's feet.

create table public.pseudonym_blocklist (
  pseudonym   text primary key check (pseudonym ~ '^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$'),
  reason_code text not null check (reason_code ~ '^[a-z0-9_]{1,40}$'),
  created_by  text not null check (char_length(created_by) between 1 and 120),
  created_at  timestamptz not null default now()
);
comment on table public.pseudonym_blocklist is
  'PRD 19: room pseudonyms the Owner took out of use (on top of the code blocklist). Console-managed, audited.';

alter table public.pseudonym_blocklist enable row level security;
revoke all on public.pseudonym_blocklist from anon, authenticated;
