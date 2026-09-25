-- F16 Quiet Together + the Lantern Hour wind-down (PRD 06b "F16 Quiet Together", "Lantern Hour wind-down (Milestone C)";
-- 10-data-model `quiet_sessions`, `quiet_members`; 14-states "Quiet Together (F16)"; 19-admin-console kill switches
-- "from C Quiet Together and the Lantern Hour wind-down, per region"). Contract: contracts/api/v1-quiet.md.
-- Server: server/aura-api/src/quiet, server/aura-api/src/rooms/wind-down*.ts.
--
-- Access model (DS-10, REQ-QUIET-01): every public table here is SERVER-ONLY — RLS on, no policies, no client
-- privileges. Clients reach Quiet Together only through NestJS (`/v1/quiet*`), which returns COUNTS ONLY: never a
-- member list, member id, pseudonym, account id, age, mood or silhouette. The one client-facing piece is a Realtime
-- authorization policy on `realtime.messages`:
--   * `quiet:<session_id>` — current (not left) members of a session may READ Broadcast until its block ends (+2 min).
--     Nobody writes: the server sends `count` and unnamed `gesture` events with `realtime.send()`; there is no
--     per-member Presence (PRD 09).
--
--  1. `quiet_config` — single-row tunables: 60-min blocks, 50 per session, thin-region merge, liveness window,
--     heartbeat, 25/5 rhythm, gesture limits (1 / 10 s, 20 / session hour), retention, and the wind-down (22:30 on the
--     region clock, 20 min, Calm 4/6 pacer).
--  2. `quiet_sessions` — content-free: mode, region, block start `t0` / end, soundscape seed, capacity. Purged 7 days
--     after the block ends [ASSUMPTION] (cascades members and the gesture log).
--  3. `quiet_members` — the membership (server-side `member_id` for rate limits and reports; never sent to clients).
--     One active membership per account.
--  4. `quiet_gestures` — the gesture log (type, time, drop reason). Rate limits and report evidence only.
--  5. Rooms (the wind-down): `room_members.wind_down_at` (opted in tonight) and `rooms.wind_down_broadcast` (the
--     lifecycle tick's cache so each wind-down change is broadcast once). "N winding down" is a room total.
--  6. Reports: `reports.target_kind` / `evidence_holds.item_kind` gain `quiet_session` — ADDED to whatever list the
--     constraints hold when this runs (other migrations may extend them too).
--  7. Kill switches: `quiet_enabled`, `lantern_wind_down_enabled` (payload `pausedRegions`: a list of tz regions).
--  8. Realtime authorization (above).
-- Idempotent (safe to re-run): on a shared local stack it may be applied ahead of lower-numbered migrations.

-- =============================================================================================== 1. config
create table if not exists public.quiet_config (
  id                         boolean primary key default true check (id),
  block_min                  smallint not null default 60 check (block_min = 60),
  capacity                   smallint not null default 50 check (capacity between 2 and 500),
  thin_live_min              smallint not null default 3 check (thin_live_min between 0 and 100),
  live_window_s              int not null default 90 check (live_window_s between 30 and 600),
  heartbeat_ms               int not null default 30000 check (heartbeat_ms between 5000 and 120000),
  stale_after_min            int not null default 10 check (stale_after_min between 2 and 120),
  focus_min                  smallint not null default 25 check (focus_min between 5 and 55),
  break_min                  smallint not null default 5 check (break_min between 1 and 25),
  gesture_min_interval_ms    int not null default 10000 check (gesture_min_interval_ms between 0 and 600000),
  gesture_hour_max           int not null default 20 check (gesture_hour_max between 1 and 1000),
  gesture_limit_hits_to_mute smallint not null default 3 check (gesture_limit_hits_to_mute between 1 and 100),
  gesture_shadow_mute_h      smallint not null default 24 check (gesture_shadow_mute_h between 1 and 720),
  retention_d                int not null default 7 check (retention_d between 1 and 365),
  wind_down_start            time not null default '22:30',
  wind_down_min              smallint not null default 20 check (wind_down_min between 5 and 60),
  wind_down_inhale_ms        int not null default 4000 check (wind_down_inhale_ms between 1000 and 20000),
  wind_down_exhale_ms        int not null default 6000 check (wind_down_exhale_ms between 1000 and 20000),
  updated_at                 timestamptz not null default now(),
  constraint quiet_config_rhythm check ((focus_min + break_min) * 2 = block_min)
);
insert into public.quiet_config (id) values (true) on conflict (id) do nothing;
comment on table public.quiet_config is
  'F16 Quiet Together tunables (single row). PRD: 60-min blocks on the region clock, up to 50 per session, 25/5 rhythm, gestures 1 per 10 s and 20 per session hour; wind-down at 22:30 for ~20 min on the Calm 4/6 pacer.';

-- =============================================================================================== 2. sessions
create table if not exists public.quiet_sessions (
  id              uuid primary key default gen_random_uuid(),
  mode            text not null check (mode in ('study','read','rest')),
  tz_region       text not null check (tz_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  t0              timestamptz not null,                                      -- block start = the shared start
  ends_at         timestamptz not null,
  soundscape_seed int not null check (soundscape_seed >= 0),
  capacity        smallint not null check (capacity between 2 and 500),
  created_at      timestamptz not null default now(),
  purge_at        timestamptz not null,
  constraint quiet_sessions_times check (ends_at > t0 and purge_at > ends_at)
);
create index if not exists quiet_sessions_block_idx on public.quiet_sessions (mode, t0, tz_region);
create index if not exists quiet_sessions_open_idx on public.quiet_sessions (ends_at);
create index if not exists quiet_sessions_purge_idx on public.quiet_sessions (purge_at);

-- =============================================================================================== 3. members
create table if not exists public.quiet_members (
  member_id    uuid primary key default gen_random_uuid(),                   -- server-side only (DS-10)
  session_id   uuid not null references public.quiet_sessions(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  home_region  text not null check (home_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  joined_at    timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  left_at      timestamptz,
  constraint quiet_members_times check (left_at is null or left_at >= joined_at)
);
create unique index if not exists quiet_members_one_active on public.quiet_members (user_id) where left_at is null;
create index if not exists quiet_members_session_idx on public.quiet_members (session_id) where left_at is null;
create index if not exists quiet_members_user_idx on public.quiet_members (user_id);

-- =============================================================================================== 4. gesture log
create table if not exists public.quiet_gestures (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.quiet_sessions(id) on delete cascade,
  member_id  uuid not null references public.quiet_members(member_id) on delete cascade,
  type       text not null check (type in ('warm_tea','light_a_candle','hug','me_too','soft_rain','stargaze','deep_breath','youre_not_alone')),
  dropped    text check (dropped in ('over_limit','shadow_muted')),
  created_at timestamptz not null default now()
);
create index if not exists quiet_gestures_member_idx on public.quiet_gestures (member_id, created_at desc);
create index if not exists quiet_gestures_session_idx on public.quiet_gestures (session_id, created_at desc);

-- =============================================================================================== 5. rooms: the wind-down
alter table public.room_members add column if not exists wind_down_at timestamptz;
comment on column public.room_members.wind_down_at is
  'F16 Lantern Hour wind-down: when this member opted in tonight (null = not winding down). Only the room total ("N winding down") ever leaves the server.';
alter table public.rooms add column if not exists wind_down_broadcast text;
comment on column public.rooms.wind_down_broadcast is
  'F16: the last wind-down state:count the lifecycle tick broadcast (so each change goes out once). A room total.';

-- =============================================================================================== 6. reports + evidence
-- Additive and order-independent: append `quiet_session` to the kinds the constraint allows right now.
do $$
declare
  kinds text[];
  def   text;
begin
  select pg_get_constraintdef(c.oid) into def from pg_constraint c
   where c.conrelid = 'public.reports'::regclass and c.conname = 'reports_target_kind_check';
  kinds := coalesce((select array_agg(m[1]) from regexp_matches(coalesce(def, ''), '''([a-z_]+)''', 'g') m),
                    array['member','gesture','room','reflection','ripple_seat']);
  if not 'quiet_session' = any(kinds) then kinds := kinds || 'quiet_session'::text; end if;
  execute 'alter table public.reports drop constraint if exists reports_target_kind_check';
  execute format('alter table public.reports add constraint reports_target_kind_check check (target_kind in (%s))',
                 (select string_agg(quote_literal(k), ',') from unnest(kinds) k));

  select pg_get_constraintdef(c.oid) into def from pg_constraint c
   where c.conrelid = 'public.evidence_holds'::regclass and c.conname = 'evidence_holds_item_kind_check';
  kinds := coalesce((select array_agg(m[1]) from regexp_matches(coalesce(def, ''), '''([a-z_]+)''', 'g') m),
                    array['member','gesture','room','reflection','ripple_seat']);
  if not 'quiet_session' = any(kinds) then kinds := kinds || 'quiet_session'::text; end if;
  execute 'alter table public.evidence_holds drop constraint if exists evidence_holds_item_kind_check';
  execute format('alter table public.evidence_holds add constraint evidence_holds_item_kind_check check (item_kind in (%s))',
                 (select string_agg(quote_literal(k), ',') from unnest(kinds) k));
end
$$;

-- =============================================================================================== 7. flags
insert into public.feature_flags (key, enabled, payload, description) values
  ('quiet_enabled', true, '{"pausedRegions": []}'::jsonb,
   'Quiet Together (F16). Off: no new joins (POST /v1/quiet/join → 503 quiet_paused) and the app hides its entry; sessions running finish their block. payload.pausedRegions pauses single timezone regions (americas / europe_africa / south_asia / east_asia_pacific).'),
  ('lantern_wind_down_enabled', true, '{"pausedRegions": []}'::jsonb,
   'Lantern Hour wind-down (F16). Off: rooms offer no "Wind down together" (POST /v1/rooms/:id/wind-down → 503 wind_down_paused). payload.pausedRegions pauses single timezone regions.')
on conflict (key) do nothing;

-- =============================================================================================== server-only
alter table public.quiet_config   enable row level security;
alter table public.quiet_sessions enable row level security;
alter table public.quiet_members  enable row level security;
alter table public.quiet_gestures enable row level security;
revoke all on table public.quiet_config, public.quiet_sessions, public.quiet_members, public.quiet_gestures
  from anon, authenticated;

-- =============================================================================================== 8. realtime authorization
-- `quiet:<session_id>`: a current (not left) member, while the block hasn't ended (+2 min for the last count).
-- Refused for accounts pending deletion or with an active room-access sanction, like the room and game topics.
create or replace function public.quiet_topic_allowed(topic text) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
     and topic like 'quiet:%'
     and exists (
       select 1
         from public.quiet_members m
         join public.quiet_sessions s on s.id = m.session_id
        where m.user_id = auth.uid()
          and m.left_at is null
          and s.ends_at + interval '2 minutes' > now()
          and topic = 'quiet:' || s.id::text)
     and not exists (select 1 from public.account_deletions d where d.user_id = auth.uid())
     and not exists (
       select 1 from public.sanctions x
        where x.user_id = auth.uid()
          and x.kind in ('room_suspension','rooms_pause','social_ban','account_ban')
          and x.lifted_at is null and x.starts_at <= now() and (x.ends_at is null or x.ends_at > now())
     )
$$;
revoke all on function public.quiet_topic_allowed(text) from public, anon;
grant execute on function public.quiet_topic_allowed(text) to authenticated;

-- Read only: Broadcast from the server. No insert policy for `quiet:` topics, so no client can send or track Presence.
drop policy if exists aura_quiet_receive on realtime.messages;
create policy aura_quiet_receive on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and (select realtime.topic()) like 'quiet:%'
    and public.quiet_topic_allowed((select realtime.topic()))
  );
