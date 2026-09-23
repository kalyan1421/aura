-- F5 Mood Rooms + F9 core safety primitives (contracts/api/v1-rooms.md; PRD 06b F5, 06c F9, 19 admin console).
--
-- Access model (DS-10): every table here is SERVER-ONLY — RLS on, no policies, no client privileges. Clients reach
-- rooms only through NestJS (`/v1/rooms*`, `/v1/safety*`), which returns member ids and pseudonyms, never account ids,
-- ages or DOBs. The one client-facing piece is Realtime authorization: a SELECT policy on `realtime.messages` lets a
-- signed-in user receive the private Broadcast topics of their own current memberships (`room:<room_id>`,
-- `member:<member_id>`). There is no INSERT policy, so clients can neither broadcast nor track Presence; the server
-- broadcasts with `realtime.send()` inside the same transaction as each write (delivered only if it commits).
--
-- Retention: rooms purge 24 h + 7 d after creation (worker `room-lifecycle`), cascading memberships, pseudonyms,
-- gestures and mutes. Reported items are snapshotted into `evidence_holds` (180 days, DS-4), which has no FK to rooms or
-- accounts so it survives both the room purge and the account purge. `moderation_actions` is an append-only,
-- hash-chained audit log keyed by a hashed subject id (survives account deletion without holding the raw id).

-- =============================================================================================== config
-- Single-row tunables (PRD: "thresholds in matching_config, tunable without a release"). Rooms copy capacity and
-- lifetimes when created, so a change applies to new rooms only.
create table public.matching_config (
  id                             boolean primary key default true check (id),
  step1_exact_mood               boolean not null default false,          -- ladder step 1: off at alpha
  live_window_s                  int  not null default 120 check (live_window_s between 30 and 900),
  partition_live_window_min      int  not null default 15  check (partition_live_window_min between 1 and 240),
  partition_live_min             int  not null default 3   check (partition_live_min between 1 and 48),
  adjacent_live_min              int  not null default 3   check (adjacent_live_min between 1 and 48),
  spawn_live_threshold           int  not null default 12  check (spawn_live_threshold between 2 and 48),
  thin_join_threshold            int  not null default 12  check (thin_join_threshold between 0 and 100000),
  default_region                 text not null default 'south_asia'
                                 check (default_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  room_capacity                  int  not null default 24  check (room_capacity between 2 and 48),
  join_cutoff_h                  int  not null default 20  check (join_cutoff_h between 1 and 168),
  memory_after_h                 int  not null default 24  check (memory_after_h between 1 and 168),
  purge_after_d                  int  not null default 7   check (purge_after_d between 1 and 30),
  joins_per_quadrant_24h         int  not null default 3   check (joins_per_quadrant_24h between 1 and 100),
  gesture_min_interval_ms        int  not null default 2000 check (gesture_min_interval_ms between 0 and 60000),
  gesture_room_hour_max          int  not null default 40  check (gesture_room_hour_max between 1 and 10000),
  gesture_same_target_max        int  not null default 3   check (gesture_same_target_max between 1 and 1000),
  gesture_same_target_window_min int  not null default 10  check (gesture_same_target_window_min between 1 and 1440),
  gesture_limit_hits_to_mute     int  not null default 3   check (gesture_limit_hits_to_mute between 1 and 1000),
  gesture_shadow_mute_h          int  not null default 24  check (gesture_shadow_mute_h between 1 and 720),
  lantern_start                  time not null default '21:00',
  lantern_end                    time not null default '23:00',
  updated_at                     timestamptz not null default now(),
  constraint matching_config_lifetimes check (join_cutoff_h <= memory_after_h),
  constraint matching_config_lantern check (lantern_start < lantern_end)
);
insert into public.matching_config default values;

create table public.safety_config (
  id                        boolean primary key default true check (id),
  report_daily_limit        int not null default 20  check (report_daily_limit between 1 and 1000),   -- reasons 2–8
  under13_reports_to_pause  int not null default 2   check (under13_reports_to_pause between 1 and 100),
  evidence_hold_days        int not null default 180 check (evidence_hold_days between 1 and 3650),
  strike_ttl_days           int not null default 90  check (strike_ttl_days between 1 and 3650),
  updated_at                timestamptz not null default now()
);
insert into public.safety_config default values;

-- Hindi + Hinglish rooms stay off until moderation is ready (PRD F5). Client-readable like every feature flag.
insert into public.feature_flags (key, enabled, payload)
values ('rooms_pool_hi', false, '{}'::jsonb)
on conflict (key) do nothing;

-- =============================================================================================== rooms
create table public.rooms (
  id                 uuid primary key default gen_random_uuid(),
  kind               text not null default 'mood' check (kind in ('mood')),     -- P2 hook: bring-a-friend rooms
  language_pool      text not null check (language_pool in ('en','te','hi')),
  quadrant           text not null check (quadrant in ('storm','rain','moonlight','sunrise')),
  tz_region          text not null check (tz_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  seed_mood_id       text not null references public.moods(id),               -- the creator's mood (ladder step 1)
  theme              text not null,
  capacity           int  not null default 24 check (capacity between 2 and 48),
  -- Cached for the lifecycle worker (it broadcasts each transition once). Reads derive the state from timestamps.
  status             text not null default 'forming'
                     check (status in ('forming','open','lantern_hour','closing','memory')),
  status_changed_at  timestamptz not null default now(),
  here_now_broadcast int  not null default 0,                                  -- last "here now" pushed
  created_at         timestamptz not null default now(),
  opened_at          timestamptz,                                              -- the 2nd member ever joined
  joins_close_at     timestamptz not null,                                     -- created + 20 h: no new members
  memory_at          timestamptz not null,                                     -- created + 24 h: read-only memory
  purge_at           timestamptz not null,                                     -- memory + 7 d: hard delete
  constraint rooms_timeline check (created_at < joins_close_at and joins_close_at <= memory_at and memory_at < purge_at),
  constraint rooms_theme check (theme = case quadrant
    when 'storm' then 'lighthouse' when 'rain' then 'rain_sanctuary'
    when 'moonlight' then 'midnight_observatory' else 'sunrise_deck' end)
);
create index rooms_partition_idx on public.rooms (language_pool, quadrant, tz_region, joins_close_at);
create index rooms_purge_at_idx on public.rooms (purge_at);
create index rooms_active_status_idx on public.rooms (status) where status <> 'memory';

-- One row per membership. `member_id` and `pseudonym` are fresh per room (DS-2); `user_id` never leaves the server.
create table public.room_members (
  member_id          uuid primary key default gen_random_uuid(),
  room_id            uuid not null references public.rooms(id) on delete cascade,
  user_id            uuid not null references auth.users(id) on delete cascade,
  pseudonym          text not null check (pseudonym ~ '^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$'),
  mood_at_join       text not null references public.moods(id),                -- the chip (DS-3)
  entry_quadrant     text not null check (entry_quadrant in ('storm','rain','moonlight','sunrise')),
  home_language_pool text not null check (home_language_pool in ('en','te','hi')),   -- demand stats (thin merge)
  home_region        text not null check (home_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  match_step         smallint not null check (match_step between 1 and 4),
  -- Silhouette snapshot at join (never updates; hue in 30° buckets, so it can't fingerprint across rooms).
  stage              text not null check (stage in ('spark','ember','glow','radiance','constellation')),
  hue                smallint check (hue is null or (hue between 0 and 330 and hue % 30 = 0)),
  cosmetic           text,
  joined_at          timestamptz not null default now(),
  last_seen_at       timestamptz not null default now(),                       -- heartbeat liveness
  left_at            timestamptz,
  survey_answered_at timestamptz,
  constraint room_members_one_seat unique (room_id, user_id),                  -- also: no rejoining after leaving
  constraint room_members_pseudonym_unique unique (room_id, pseudonym),
  constraint room_members_room_member unique (room_id, member_id)              -- target of same-room FKs below
);
create index room_members_user_idx on public.room_members (user_id, joined_at desc);
create index room_members_active_idx on public.room_members (room_id, last_seen_at) where left_at is null;
create index room_members_demand_idx on public.room_members (entry_quadrant, home_language_pool, home_region, joined_at);

-- Backstop for the matcher (which already locks the partition and the room row): never a member over capacity, never
-- a join after the cutoff, never two active rooms for one quadrant (by entry quadrant or by room quadrant).
create function public.room_members_guard() returns trigger
language plpgsql set search_path = '' as $$
declare
  r record;
  active_count int;
begin
  select capacity, joins_close_at, quadrant into r from public.rooms where id = new.room_id for update;
  if not found then
    return new;  -- the FK reports the missing room
  end if;
  if r.joins_close_at <= now() then
    raise exception 'room_closed_to_joins' using errcode = 'AR003';
  end if;
  select count(*) into active_count from public.room_members where room_id = new.room_id and left_at is null;
  if active_count >= r.capacity then
    raise exception 'room_full' using errcode = 'AR001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('aura:user:' || new.user_id::text, 0));
  if exists (
    select 1 from public.room_members m join public.rooms x on x.id = m.room_id
     where m.user_id = new.user_id and m.left_at is null and x.memory_at > now()
       and (m.entry_quadrant = new.entry_quadrant or x.quadrant = r.quadrant)
  ) then
    raise exception 'one_room_per_quadrant' using errcode = 'AR002';
  end if;
  return new;
end $$;
create trigger room_members_guard before insert on public.room_members
  for each row execute function public.room_members_guard();

-- Gestures: ephemeral room content, purged with the room. `dropped` ones were never delivered or broadcast (the sender
-- still sees them as sent): over a limit, sender shadow-muted, a block between the pair, recipient muted the sender,
-- or the recipient's room access is suspended.
create table public.room_gestures (
  id             uuid primary key default gen_random_uuid(),
  room_id        uuid not null references public.rooms(id) on delete cascade,
  from_member_id uuid not null,
  to_member_id   uuid,
  type           text not null check (type in ('warm_tea','light_a_candle','hug','me_too','soft_rain','stargaze',
                                               'deep_breath','youre_not_alone')),
  target         text not null check (target in ('room','member')),            -- 'reflection' arrives with F6
  dropped        text check (dropped in ('over_limit','shadow_muted','blocked','muted','hidden')),
  created_at     timestamptz not null default now(),
  constraint room_gestures_target_shape check ((target = 'member') = (to_member_id is not null)),
  constraint room_gestures_not_self check (to_member_id is null or to_member_id <> from_member_id),
  constraint room_gestures_from_fk foreign key (room_id, from_member_id)
    references public.room_members (room_id, member_id) on delete cascade,
  constraint room_gestures_to_fk foreign key (room_id, to_member_id)
    references public.room_members (room_id, member_id) on delete cascade
);
create index room_gestures_room_idx on public.room_gestures (room_id, created_at desc);
create index room_gestures_from_idx on public.room_gestures (from_member_id, created_at desc);
create index room_gestures_to_idx on public.room_gestures (to_member_id, created_at desc) where to_member_id is not null;

-- Mute is per membership and one-directional ("for you only"), within one room.
create table public.room_mutes (
  room_id         uuid not null,
  muter_member_id uuid not null,
  muted_member_id uuid not null,
  created_at      timestamptz not null default now(),
  primary key (muter_member_id, muted_member_id),
  constraint room_mutes_not_self check (muter_member_id <> muted_member_id),
  constraint room_mutes_muter_fk foreign key (room_id, muter_member_id)
    references public.room_members (room_id, member_id) on delete cascade,
  constraint room_mutes_muted_fk foreign key (room_id, muted_member_id)
    references public.room_members (room_id, member_id) on delete cascade
);

-- "Did you feel less alone?" — aggregate only (no user, member or room id).
create table public.room_survey_counts (
  day           date not null,
  language_pool text not null check (language_pool in ('en','te','hi')),
  quadrant      text not null check (quadrant in ('storm','rain','moonlight','sunrise')),
  tz_region     text not null check (tz_region in ('americas','europe_africa','south_asia','east_asia_pacific')),
  answer        text not null check (answer in ('yes','no','skip')),
  n             int  not null default 0 check (n >= 0),
  primary key (day, language_pool, quadrant, tz_region, answer)
);

-- =============================================================================================== safety
-- Block: account-level, both ways, never matched again; the blocked person is never told. No pseudonym is kept.
create table public.blocks (
  id              uuid primary key default gen_random_uuid(),
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  source_room_id  uuid references public.rooms(id) on delete set null,
  quadrant        text check (quadrant in ('storm','rain','moonlight','sunrise')),   -- label for the blocker's list
  created_at      timestamptz not null default now(),
  constraint blocks_pair unique (blocker_user_id, blocked_user_id),
  constraint blocks_not_self check (blocker_user_id <> blocked_user_id)
);
create index blocks_blocked_idx on public.blocks (blocked_user_id);

create table public.evidence_holds (
  id                        uuid primary key default gen_random_uuid(),
  report_id                 uuid,                         -- no FK: evidence outlives reports
  item_kind                 text not null check (item_kind in ('member','gesture','room')),
  item_ref                  uuid,
  reason                    text not null check (reason ~ '^[a-z0-9_:]{1,60}$'),
  account_ids               uuid[] not null default '{}', -- involved accounts; no FK: survives the account purge (DS-4)
  snapshot                  jsonb not null,               -- item, room context, pseudonym mapping, timestamps
  created_at                timestamptz not null default now(),
  hold_until                timestamptz not null,         -- created + 180 d (overrides the room purge)
  mandatory_report_required boolean not null default false,
  reported_to               text,                         -- POCSO / IT Rules / NCMEC channel once reported
  report_ref                text,
  legal_reason              text,                         -- Owner-recorded reason when no external report is filed
  constraint evidence_holds_window check (hold_until > created_at)
);
create index evidence_holds_hold_until_idx on public.evidence_holds (hold_until);
create index evidence_holds_report_idx on public.evidence_holds (report_id);

-- Reports → lanes. `involves_minor` and `lane` are console-only (never returned to app clients).
create table public.reports (
  id                 uuid primary key default gen_random_uuid(),
  source             text not null default 'user' check (source in ('user','auto')),
  auto_signal        text check (auto_signal in ('gesture_flood')),
  reporter_user_id   uuid references auth.users(id) on delete set null,
  reporter_member_id uuid references public.room_members(member_id) on delete set null,
  reason             smallint not null check (reason between 1 and 8),
  lane               text not null check (lane in ('crisis','minors_grooming','harassment','spam')),
  involves_minor     boolean not null default false,
  pages              boolean not null default false,       -- 24×7 page (admin console stage)
  target_kind        text not null check (target_kind in ('member','gesture','room')),
  room_id            uuid references public.rooms(id) on delete set null,
  target_member_id   uuid references public.room_members(member_id) on delete set null,
  target_gesture_id  uuid references public.room_gestures(id) on delete set null,
  target_user_id     uuid references auth.users(id) on delete set null,
  target_ref         uuid not null,                        -- member / gesture / room id at report time (dedupe key)
  note               text check (note is null or char_length(note) <= 8000),
  status             text not null default 'open' check (status in ('open','actioned','dismissed')),
  sla_due_at         timestamptz not null,
  created_at         timestamptz not null default now(),
  resolved_at        timestamptz,
  resolved_by        text,
  evidence_hold_id   uuid references public.evidence_holds(id) on delete set null,
  -- reporter_user_id may be null on a user report once the reporter's account is purged (FK set null).
  constraint reports_source_shape check ((source = 'auto') = (auto_signal is not null)),
  constraint reports_resolution check ((status = 'open') = (resolved_at is null))
);
create index reports_queue_idx on public.reports (lane, created_at) where status = 'open';
create index reports_reporter_idx on public.reports (reporter_user_id, created_at desc);
create index reports_target_user_idx on public.reports (target_user_id, reason) where status = 'open';
create index reports_room_idx on public.reports (room_id);
-- Repeat reports by one person on the same target for the same reason count once while open.
create unique index reports_open_dedupe_idx on public.reports (reporter_user_id, target_ref, reason)
  where status = 'open' and source = 'user';

create table public.sanctions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  kind        text not null check (kind in ('warning','gesture_shadow_mute','shadow_mute','room_suspension',
                                            'rooms_pause','social_ban','account_ban')),
  reason_code text not null check (reason_code ~ '^[a-z0-9_]{1,40}$'),
  source      text not null check (source in ('auto','moderator')),
  report_id   uuid references public.reports(id) on delete set null,
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz,                                   -- null = until lifted (pause, ban)
  lifted_at   timestamptz,
  created_by  text not null default 'system',
  created_at  timestamptz not null default now(),
  constraint sanctions_window check (ends_at is null or ends_at > starts_at)
);
create index sanctions_user_idx on public.sanctions (user_id, kind) where lifted_at is null;

-- Strikes expire 90 days after issue (REQ-ADM-07: "90-day-old strikes stop counting"). Crisis flags never strike.
create table public.strikes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  reason_code text not null check (reason_code ~ '^[a-z0-9_]{1,40}$'),
  report_id   uuid references public.reports(id) on delete set null,
  created_by  text not null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  constraint strikes_ttl check (expires_at > created_at)
);
create index strikes_user_idx on public.strikes (user_id, expires_at);

-- Append-only, hash-chained audit log (REQ-SAFE-08, REQ-ADM-08). `subject_hash` = HMAC of the account id (computed
-- by NestJS), so rows survive account deletion without holding the raw id. Never content, never raw account ids.
create sequence public.moderation_actions_id_seq;
create table public.moderation_actions (
  id           bigint primary key,                          -- assigned by the chain trigger, in chain order
  created_at   timestamptz not null default clock_timestamp(),
  actor        text not null check (char_length(actor) between 1 and 120),
  action       text not null check (action ~ '^[a-z_]{2,40}$'),
  report_id    uuid,
  subject_hash text check (subject_hash is null or subject_hash ~ '^[0-9a-f]{64}$'),
  reason_code  text check (reason_code is null or reason_code ~ '^[a-z0-9_]{1,40}$'),
  detail       jsonb not null default '{}'::jsonb,
  prev_hash    text,
  row_hash     text not null default ''
);
alter sequence public.moderation_actions_id_seq owned by public.moderation_actions.id;

create function public.moderation_actions_chain() returns trigger
language plpgsql set search_path = '' as $$
declare
  prev text;
begin
  -- Serialise appends so ids follow the chain order, then link to the previous row.
  perform pg_advisory_xact_lock(hashtextextended('aura:moderation_actions', 0));
  new.id := nextval('public.moderation_actions_id_seq');
  select a.row_hash into prev from public.moderation_actions a order by a.id desc limit 1;
  new.prev_hash := prev;
  new.row_hash := encode(sha256(convert_to(
    coalesce(prev, '') || '|' || new.id::text || '|' || to_char(new.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') ||
    '|' || new.actor || '|' || new.action || '|' || coalesce(new.report_id::text, '') || '|' ||
    coalesce(new.subject_hash, '') || '|' || coalesce(new.reason_code, '') || '|' || new.detail::text, 'UTF8')), 'hex');
  return new;
end $$;
create trigger moderation_actions_chain before insert on public.moderation_actions
  for each row execute function public.moderation_actions_chain();

create function public.moderation_actions_append_only() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'moderation_actions is append-only' using errcode = 'AR010';
end $$;
create trigger moderation_actions_no_update_delete before update or delete on public.moderation_actions
  for each row execute function public.moderation_actions_append_only();
create trigger moderation_actions_no_truncate before truncate on public.moderation_actions
  for each statement execute function public.moderation_actions_append_only();

-- =============================================================================================== RLS / privileges
alter table public.matching_config    enable row level security;
alter table public.safety_config      enable row level security;
alter table public.rooms              enable row level security;
alter table public.room_members       enable row level security;
alter table public.room_gestures      enable row level security;
alter table public.room_mutes         enable row level security;
alter table public.room_survey_counts enable row level security;
alter table public.blocks             enable row level security;
alter table public.evidence_holds     enable row level security;
alter table public.reports            enable row level security;
alter table public.sanctions          enable row level security;
alter table public.strikes            enable row level security;
alter table public.moderation_actions enable row level security;

-- Server-only: no policies and no client privileges at all (any client/PostgREST access → 42501).
revoke all on table
  public.matching_config, public.safety_config, public.rooms, public.room_members, public.room_gestures,
  public.room_mutes, public.room_survey_counts, public.blocks, public.evidence_holds, public.reports,
  public.sanctions, public.strikes, public.moderation_actions
from anon, authenticated;
revoke all on sequence public.moderation_actions_id_seq from anon, authenticated;
-- The audit log can't be rewritten by any application role (the trigger also stops the owner).
revoke update, delete, truncate on table public.moderation_actions from service_role;

-- Trigger functions are not callable by clients.
revoke all on function public.room_members_guard() from public, anon, authenticated;
revoke all on function public.moderation_actions_chain() from public, anon, authenticated;
revoke all on function public.moderation_actions_append_only() from public, anon, authenticated;

-- =============================================================================================== realtime authorization
-- Private Broadcast topics: `room:<room_id>` for every current member, `member:<member_id>` for its owner only.
-- Realtime evaluates the SELECT policy as the joining user (role authenticated, their JWT claims, realtime.topic()
-- = the topic). room_members is not client-readable, hence the SECURITY DEFINER check, which only ever answers
-- "may *I* read this topic". Suspended/paused/closed accounts and accounts pending deletion are refused.
create function public.realtime_topic_allowed(topic text) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
     and exists (
       select 1
         from public.room_members m
         join public.rooms r on r.id = m.room_id
        where m.user_id = auth.uid()
          and m.left_at is null
          and r.purge_at > now()
          and (topic = 'room:' || m.room_id::text or topic = 'member:' || m.member_id::text)
     )
     and not exists (select 1 from public.account_deletions d where d.user_id = auth.uid())
     and not exists (
       select 1 from public.sanctions s
        where s.user_id = auth.uid()
          and s.kind in ('room_suspension','rooms_pause','social_ban','account_ban')
          and s.lifted_at is null and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
     )
$$;
revoke all on function public.realtime_topic_allowed(text) from public, anon;
grant execute on function public.realtime_topic_allowed(text) to authenticated;

create policy aura_rooms_receive on realtime.messages
  for select to authenticated
  using (realtime.messages.extension = 'broadcast' and public.realtime_topic_allowed((select realtime.topic())));
