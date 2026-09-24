-- F7 Breath Ripples (PRD 06b "F7 Breath Ripples"; 10-data-model `game_sessions`, `game_seats`, `echo_recordings`;
-- 14-states "Breath Ripples lobby and session"; 19-admin-console kill switches). Contract: contracts/api/v1-ripples.md.
-- Server: server/aura-api/src/ripples.
--
-- Access model (DS-10): every public table here is SERVER-ONLY — RLS on, no policies, no client privileges. Clients
-- reach Breath Ripples only through NestJS (`/v1/ripples*`), which returns seat numbers and pseudonyms, never account
-- ids, ages or DOBs. The client-facing pieces are Realtime authorization policies on `realtime.messages`:
--   * `game:<session_id>` — the human seat holders of a session that hasn't ended may READ and WRITE Broadcast and
--     Presence: breath events go client to client (PRD "Breath events go client to client"); the server adds
--     `session_start`, `seat_update` and `session_end` with `realtime.send()`;
--   * `ripples:<room_id>` — current members of a room may READ the "Breathe together" invite hints (ids only).
--
--  1. `ripple_config` — single-row tunables (start rules 4 humans / 8 s with ≥ 2 / 20 s max, the 3-minute session,
--     echo selection and retention, event budgets). Tunable without a release.
--  2. `ripple_invites` — "Breathe together" in a room: open for 20 s, then the session starts with echo-fill.
--  3. `ripple_tickets` — the one global quick-match queue and room-invite joins. Clients poll every 2 s; NestJS groups
--     tickets atomically (`FOR UPDATE SKIP LOCKED`), keeping blocked pairs apart.
--  4. `ripple_sessions`, `ripple_seats` — content-free (seat, kind, pseudonym, times, cycles). No sync value is ever
--     stored (REQ-GAME-06). Purged 7 days after the session ends [ASSUMPTION]; a report snapshots its session into
--     `evidence_holds` (180 days) first.
--  5. `ripple_session_log` — the session event log (seat and member ids: seated, left, completed, flood, report,
--     block), kept with the session (7 days).
--  6. `echo_library.recordings` — a SEPARATE schema with NO foreign keys and no column that could join back to an
--     account, member, device, session or age (REQ-GAME-07): pacer-relative transition offsets (50 ms steps), pacer
--     version, completion, median offset and the ISO week. The id is random (v4, no time in it); there is no
--     timestamp finer than the week. Purged after 90 days [ASSUMPTION].
--  7. Reports on a light: `reports.target_kind` / `evidence_holds.item_kind` gain `ripple_seat`; automatic flood
--     signals `reports.auto_signal = 'ripple_flood'` (REQ-GAME-05).
--  8. Kill switches: `ripples_enabled` (off → `503 ripples_paused` on match), `ripples_echoes` (off → no echo is
--     recorded or seated).
--  9. Realtime authorization (above).
-- Idempotent (safe to re-run): on a shared local stack it may be applied ahead of lower-numbered migrations.

-- =============================================================================================== 1. config
create table if not exists public.ripple_config (
  id                        boolean primary key default true check (id),
  seat_count                smallint not null default 4 check (seat_count between 2 and 4),
  early_start_s             int not null default 8 check (early_start_s between 1 and 60),
  early_start_min_humans    smallint not null default 2 check (early_start_min_humans between 2 and 4),
  max_wait_s                int not null default 20 check (max_wait_s between 2 and 120),
  invite_window_s           int not null default 20 check (invite_window_s between 5 and 120),
  invites_per_window        smallint not null default 1 check (invites_per_window between 1 and 20),
  invite_limit_window_min   int not null default 10 check (invite_limit_window_min between 1 and 1440),
  ticket_stale_s            int not null default 6 check (ticket_stale_s between 3 and 60),
  poll_ms                   int not null default 2000 check (poll_ms between 250 and 10000),
  start_lead_ms             int not null default 0 check (start_lead_ms between 0 and 5000),
  settle_ms                 int not null default 10000 check (settle_ms between 0 and 60000),
  inhale_ms                 int not null default 4000 check (inhale_ms between 1000 and 20000),
  exhale_ms                 int not null default 6000 check (exhale_ms between 1000 and 20000),
  cycles                    smallint not null default 16 check (cycles between 1 and 60),
  fade_ms                   int not null default 10000 check (fade_ms between 0 and 60000),
  pacer_version             smallint not null default 1 check (pacer_version between 1 and 999),
  echo_min_cycles           smallint not null default 12 check (echo_min_cycles between 1 and 60),
  echo_min_completion       numeric(4,3) not null default 0.900 check (echo_min_completion between 0 and 1),
  echo_max_median_offset_ms int not null default 600 check (echo_max_median_offset_ms between 0 and 5000),
  echo_library_min          int not null default 50 check (echo_library_min between 0 and 100000),
  echo_retention_d          int not null default 90 check (echo_retention_d between 1 and 3650),
  session_retention_d       int not null default 7 check (session_retention_d between 1 and 365),
  events_per_s_cap          smallint not null default 10 check (events_per_s_cap between 1 and 100),
  pulse_min_interval_ms     int not null default 3000 check (pulse_min_interval_ms between 0 and 60000),
  gesture_min_interval_ms   int not null default 5000 check (gesture_min_interval_ms between 0 and 60000),
  heartbeat_ms              int not null default 2000 check (heartbeat_ms between 500 and 10000),
  disconnect_after_ms       int not null default 3000 check (disconnect_after_ms between 1000 and 60000),
  echo_after_ms             int not null default 10000 check (echo_after_ms between 1000 and 120000),
  rejoin_window_ms          int not null default 10000 check (rejoin_window_ms between 1000 and 120000),
  updated_at                timestamptz not null default now()
);
insert into public.ripple_config (id) values (true) on conflict (id) do nothing;
comment on table public.ripple_config is
  'F7 Breath Ripples tunables (single row). PRD: 4 humans start at once; at 8 s with >= 2 humans; at 20 s with whoever waits; 10 s settle, 16 x (4 s in / 6 s out), 10 s fade.';

-- =============================================================================================== 2. room invites
create table if not exists public.ripple_invites (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.rooms(id) on delete cascade,
  -- The inviter (1 per 10 min). An invite belongs to the room, not its inviter: other members' tickets hang off it, so
  -- account deletion clears these two links (ACCOUNT_REFERENCE_CLEANUP) instead of deleting the invite.
  inviter_user_id   uuid references auth.users(id) on delete set null,
  inviter_member_id uuid references public.room_members(member_id) on delete set null,
  created_at timestamptz not null default now(),
  starts_at  timestamptz not null,                                                   -- created + 20 s
  status     text not null default 'open' check (status in ('open','started','cancelled')),
  constraint ripple_invites_window check (starts_at > created_at)
);
create index if not exists ripple_invites_room_idx on public.ripple_invites (room_id, starts_at) where status = 'open';
create index if not exists ripple_invites_user_idx on public.ripple_invites (inviter_user_id, created_at desc);

-- =============================================================================================== 4. sessions and seats
create table if not exists public.ripple_sessions (
  id            uuid primary key default gen_random_uuid(),
  entry         text not null check (entry in ('quick','room')),
  room_id       uuid references public.rooms(id) on delete set null,
  invite_id     uuid references public.ripple_invites(id) on delete set null,
  tz_region     text check (tz_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  language_pool text check (language_pool in ('en','te','hi')),
  start_rule    text not null check (start_rule in ('full','early','timeout','invite')),
  t0            timestamptz not null,
  settle_ms     int not null check (settle_ms >= 0),
  inhale_ms     int not null check (inhale_ms > 0),
  exhale_ms     int not null check (exhale_ms > 0),
  cycles        smallint not null check (cycles > 0),
  fade_ms       int not null check (fade_ms >= 0),
  pacer_version smallint not null,
  ends_at       timestamptz not null,
  ended_at      timestamptz,
  created_at    timestamptz not null default now(),
  purge_at      timestamptz not null,
  constraint ripple_sessions_times check (ends_at > t0 and purge_at > ends_at),
  constraint ripple_sessions_entry check (entry = 'room' or (invite_id is null and start_rule <> 'invite'))
);
create index if not exists ripple_sessions_open_idx on public.ripple_sessions (ends_at) where ended_at is null;
create index if not exists ripple_sessions_purge_idx on public.ripple_sessions (purge_at);
create index if not exists ripple_sessions_room_idx on public.ripple_sessions (room_id) where room_id is not null;

create table if not exists public.ripple_seats (
  id             uuid primary key default gen_random_uuid(),                          -- the seat's member id (event log)
  session_id     uuid not null references public.ripple_sessions(id) on delete cascade,
  seat           smallint not null check (seat between 1 and 4),
  kind           text not null check (kind in ('human','echo','guide')),
  user_id        uuid references auth.users(id) on delete cascade,
  room_member_id uuid references public.room_members(member_id) on delete set null,
  pseudonym      text check (pseudonym ~ '^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$'),
  echo_id        uuid,                                     -- echo_library.recordings.id: NO foreign key (unlinked schema)
  waited_ms      int check (waited_ms >= 0),
  joined_at      timestamptz not null default now(),
  left_at        timestamptz,
  cycles_done    smallint check (cycles_done between 0 and 60),
  completed      boolean not null default false,
  completed_at   timestamptz,
  constraint ripple_seats_unique unique (session_id, seat),
  constraint ripple_seats_human check ((kind = 'human') = (user_id is not null and pseudonym is not null)),
  constraint ripple_seats_echo check ((kind = 'echo') = (echo_id is not null)),
  constraint ripple_seats_left check (kind = 'human' or left_at is null)
);
create unique index if not exists ripple_seats_one_per_user on public.ripple_seats (session_id, user_id) where user_id is not null;
create unique index if not exists ripple_seats_pseudonym on public.ripple_seats (session_id, pseudonym) where pseudonym is not null;
create index if not exists ripple_seats_user_idx on public.ripple_seats (user_id) where user_id is not null;

-- =============================================================================================== 3. tickets
create table if not exists public.ripple_tickets (
  id             uuid primary key,                                                   -- client-generated (UUIDv7)
  user_id        uuid not null references auth.users(id) on delete cascade,
  entry          text not null check (entry in ('quick','room')),
  room_id        uuid references public.rooms(id) on delete cascade,
  room_member_id uuid references public.room_members(member_id) on delete cascade,
  invite_id      uuid references public.ripple_invites(id) on delete cascade,
  status         text not null default 'waiting' check (status in ('waiting','matched','cancelled','expired')),
  enqueued_at    timestamptz not null default now(),
  last_poll_at   timestamptz not null default now(),
  session_id     uuid references public.ripple_sessions(id) on delete set null,
  seat           smallint check (seat between 1 and 4),
  matched_at     timestamptz,
  constraint ripple_tickets_room check ((entry = 'room') = (room_id is not null and room_member_id is not null and invite_id is not null)),
  constraint ripple_tickets_matched check ((status = 'matched') = (matched_at is not null))
);
create unique index if not exists ripple_tickets_one_waiting on public.ripple_tickets (user_id) where status = 'waiting';
create index if not exists ripple_tickets_queue_idx on public.ripple_tickets (entry, enqueued_at) where status = 'waiting';
create index if not exists ripple_tickets_invite_idx on public.ripple_tickets (invite_id) where status = 'waiting';

-- =============================================================================================== 5. session event log
create table if not exists public.ripple_session_log (
  id         bigserial primary key,
  session_id uuid not null references public.ripple_sessions(id) on delete cascade,
  seat       smallint check (seat between 1 and 4),
  seat_id    uuid,                                   -- ripple_seats.id (the seat's member id) at the time
  event      text not null check (event in ('seated','left','completed','flood','report','block')),
  at         timestamptz not null default now()
);
create index if not exists ripple_session_log_session_idx on public.ripple_session_log (session_id, at);

-- =============================================================================================== 6. echo library
-- Separate schema, no foreign keys, nothing joinable to accounts, members, devices, sessions or ages (REQ-GAME-07).
create schema if not exists echo_library;
revoke all on schema echo_library from public, anon, authenticated;
comment on schema echo_library is
  'F7 echoes: unlinked breath recordings. No account, member, device, session or age data; no FKs; week-level time only.';

create table if not exists echo_library.recordings (
  id               uuid primary key default gen_random_uuid(),       -- random v4: carries no time
  pacer_version    smallint not null check (pacer_version between 1 and 999),
  -- Pacer-relative transition offsets (inhale / exhale starts, in order) in 50 ms steps; null = that transition was missed.
  offsets          smallint[] not null
                   check (cardinality(offsets) between 1 and 120 and 40 >= all(offsets) and -40 <= all(offsets)),
  completion       numeric(4,3) not null check (completion between 0 and 1),
  median_offset_ms int not null check (median_offset_ms between 0 and 2000),
  iso_week         text not null check (iso_week ~ '^[0-9]{4}-W[0-9]{2}$')
);
create index if not exists recordings_select_idx on echo_library.recordings (pacer_version, completion, median_offset_ms);
create index if not exists recordings_week_idx on echo_library.recordings (iso_week);
alter table echo_library.recordings enable row level security;
revoke all on table echo_library.recordings from public, anon, authenticated;
comment on table echo_library.recordings is
  'Echo recordings (F7). Written by NestJS only for humans with >= 12 cycles who have not opted out (user_consents purpose echoes). Unlinked: cannot be deleted per person [LEGAL]. Purged after ripple_config.echo_retention_d.';

-- =============================================================================================== 7. reports + evidence
-- Additive: keeps every earlier kind / signal (migrations 20261005000018 and 20261005000020's 'gift_pattern') and adds
-- the Breath Ripples ones.
alter table public.reports drop constraint if exists reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check
  check (target_kind in ('member','gesture','room','reflection','ripple_seat'));
alter table public.reports drop constraint if exists reports_auto_signal_check;
alter table public.reports add constraint reports_auto_signal_check check (auto_signal in (
  'gesture_flood','reflection_hold','reflection_crisis','reflection_minor_safety','reflection_violation','gift_pattern',
  'ripple_flood'));
alter table public.evidence_holds drop constraint if exists evidence_holds_item_kind_check;
alter table public.evidence_holds add constraint evidence_holds_item_kind_check
  check (item_kind in ('member','gesture','room','reflection','ripple_seat'));

-- =============================================================================================== 8. flags
insert into public.feature_flags (key, enabled, payload, description) values
  ('ripples_enabled', true, '{}'::jsonb,
   'Breath Ripples (F7). Off: no new sessions (POST /v1/ripples/match → 503 ripples_paused) and the app hides its entries; sessions already playing finish.'),
  ('ripples_echoes', true, '{}'::jsonb,
   'Breath Ripples echoes (F7). Off: no echo is recorded and none is seated (empty seats stay empty; guides only while the library is small).')
on conflict (key) do nothing;

-- =============================================================================================== server-only
alter table public.ripple_config      enable row level security;
alter table public.ripple_invites     enable row level security;
alter table public.ripple_sessions    enable row level security;
alter table public.ripple_seats       enable row level security;
alter table public.ripple_tickets     enable row level security;
alter table public.ripple_session_log enable row level security;
revoke all on table
  public.ripple_config, public.ripple_invites, public.ripple_sessions, public.ripple_seats, public.ripple_tickets,
  public.ripple_session_log
from anon, authenticated;
revoke all on sequence public.ripple_session_log_id_seq from anon, authenticated;

-- =============================================================================================== 9. realtime authorization
-- `game:<session_id>`: a human seat holder who hasn't left, while the session hasn't ended (+30 s for the last
-- `session_end`); `ripples:<room_id>`: a current member of the room (the invite hints). Refused for accounts pending
-- deletion or with an active room-access sanction, like the room topics (migration 20261005000010).
create or replace function public.ripples_topic_allowed(topic text) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
     and (
       (topic like 'game:%' and exists (
          select 1
            from public.ripple_seats s
            join public.ripple_sessions x on x.id = s.session_id
           where s.user_id = auth.uid()
             and s.kind = 'human'
             and s.left_at is null
             and x.ended_at is null
             and x.ends_at + interval '30 seconds' > now()
             and topic = 'game:' || s.session_id::text))
       or
       (topic like 'ripples:%' and exists (
          select 1
            from public.room_members m
            join public.rooms r on r.id = m.room_id
           where m.user_id = auth.uid()
             and m.left_at is null
             and r.memory_at > now()
             and topic = 'ripples:' || m.room_id::text))
     )
     and not exists (select 1 from public.account_deletions d where d.user_id = auth.uid())
     and not exists (
       select 1 from public.sanctions s
        where s.user_id = auth.uid()
          and s.kind in ('room_suspension','rooms_pause','social_ban','account_ban')
          and s.lifted_at is null and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
     )
$$;
revoke all on function public.ripples_topic_allowed(text) from public, anon;
grant execute on function public.ripples_topic_allowed(text) to authenticated;

drop policy if exists aura_ripples_receive on realtime.messages;
create policy aura_ripples_receive on realtime.messages
  for select to authenticated
  using (
    (
      (realtime.messages.extension in ('broadcast','presence') and (select realtime.topic()) like 'game:%')
      or (realtime.messages.extension = 'broadcast' and (select realtime.topic()) like 'ripples:%')
    )
    and public.ripples_topic_allowed((select realtime.topic()))
  );

-- Clients write only to their own session's topic (breath_state / pulse / gesture / heartbeat and Presence).
drop policy if exists aura_ripples_send on realtime.messages;
create policy aura_ripples_send on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension in ('broadcast','presence')
    and (select realtime.topic()) like 'game:%'
    and public.ripples_topic_allowed((select realtime.topic()))
  );
