-- F5 room lanterns and Tonight's intention (PRD 06b "Room lanterns and Tonight's intention (P1 · Milestone B)",
-- REQ-ROOM-13 / REQ-ROOM-14; 10-data-model `rooms` "from B lantern_level, intention_key, intention_holds";
-- 19-admin-console kill switches + "the Tonight's intention list per language").
-- Server: server/aura-api/src/rooms (lantern-rules.ts, lanterns.ts, lanterns.service.ts). Contract:
-- contracts/api/v1-rooms.md §1.9 and `room_state`.
--
--  1. `rooms` gains the lantern and intention ROOM TOTALS: `lantern_progress` (thousandths of a level, 0–5000; the
--     level is `floor(progress / 1000)`, stored as the generated `lantern_level`), `lantern_hour_at` (the start of
--     the Lantern Hour window the lantern belongs to), `intention_key` (the preset shown tonight) and
--     `intention_holds` (how many members hold it). Never a per-member contribution. Purged with the room.
--  2. **The lantern never dims** (REQ-ROOM-13): a trigger refuses any UPDATE that lowers `lantern_progress` or
--     `intention_holds`, or changes the night / intention once set — for every role, the owner included.
--  3. `room_members.holds_intention` — the only per-member bit, so one member counts once. It is never sent to
--     anyone but that member (their own `me.holdingIntention`), never counted per person anywhere, can't be undone,
--     and goes with the membership (room purge, account purge). No habit, reminder or record beyond this.
--  4. Tunables in `matching_config` (scaled to the room: the light a level needs grows with the live members, so a
--     room of 3 can light it too [ASSUMPTION]).
--  5. `room_intention_presets` — the intention list per language pool, rotated nightly; keys only (the app
--     localises them; no free text anywhere).
--  6. Kill switches (feature flags, client-readable like every flag): `room_lanterns_enabled`,
--     `room_intention_enabled`.
-- Idempotent (safe to re-run): on a shared local stack it may be applied ahead of lower-numbered migrations.

-- =============================================================================================== 1. room totals
alter table public.rooms
  add column if not exists lantern_progress int not null default 0 check (lantern_progress between 0 and 5000),
  add column if not exists lantern_level    smallint generated always as (least(5, lantern_progress / 1000)::smallint) stored,
  add column if not exists lantern_hour_at  timestamptz,
  add column if not exists intention_key    text check (intention_key is null or intention_key ~ '^[a-z][a-z0-9_]{1,47}$'),
  add column if not exists intention_holds  int not null default 0 check (intention_holds between 0 and 1000);

comment on column public.rooms.lantern_progress is
  'Room lantern (F5, REQ-ROOM-13): room total in thousandths of a level (0–5000). Only ever grows. Never per member.';
comment on column public.rooms.lantern_level is 'floor(lantern_progress / 1000), 0–5 (generated).';
comment on column public.rooms.lantern_hour_at is 'Start of the Lantern Hour window this room''s lantern and intention belong to.';
comment on column public.rooms.intention_key is 'Tonight''s intention (preset key, localised by the app). Set once per room.';
comment on column public.rooms.intention_holds is 'How many members hold tonight''s intention (room total only). Only ever grows.';

-- =============================================================================================== 2. never dims
create or replace function public.rooms_lantern_additive() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.lantern_progress < old.lantern_progress then
    raise exception 'lantern_never_dims' using errcode = 'AR030';
  end if;
  if new.intention_holds < old.intention_holds then
    raise exception 'intention_holds_never_fall' using errcode = 'AR030';
  end if;
  if old.lantern_hour_at is not null and new.lantern_hour_at is distinct from old.lantern_hour_at then
    raise exception 'lantern_night_fixed' using errcode = 'AR031';
  end if;
  if old.intention_key is not null and new.intention_key is distinct from old.intention_key then
    raise exception 'intention_fixed' using errcode = 'AR031';
  end if;
  return new;
end $$;
revoke all on function public.rooms_lantern_additive() from public, anon, authenticated;
drop trigger if exists rooms_lantern_additive on public.rooms;
create trigger rooms_lantern_additive before update on public.rooms
  for each row execute function public.rooms_lantern_additive();

-- =============================================================================================== 3. one hold per member
alter table public.room_members
  add column if not exists holds_intention boolean not null default false;
comment on column public.room_members.holds_intention is
  'This member holds tonight''s intention (counts once in rooms.intention_holds). Shown only to the member; never listed, never undone.';

create or replace function public.room_members_hold_once() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.holds_intention and not new.holds_intention then
    raise exception 'intention_hold_is_final' using errcode = 'AR030';
  end if;
  return new;
end $$;
revoke all on function public.room_members_hold_once() from public, anon, authenticated;
drop trigger if exists room_members_hold_once on public.room_members;
create trigger room_members_hold_once before update of holds_intention on public.room_members
  for each row execute function public.room_members_hold_once();

-- =============================================================================================== 4. tunables
alter table public.matching_config
  add column if not exists lantern_units_per_member    numeric(5,2) not null default 1.5
    check (lantern_units_per_member between 0.1 and 50),
  add column if not exists lantern_min_units_per_level int not null default 3 check (lantern_min_units_per_level between 1 and 1000),
  add column if not exists lantern_breath_cycle_weight numeric(5,2) not null default 0.25
    check (lantern_breath_cycle_weight between 0 and 10);
comment on column public.matching_config.lantern_units_per_member is
  'Room lantern: light units a level needs per live member (a gesture = 1 unit) [ASSUMPTION].';
comment on column public.matching_config.lantern_min_units_per_level is
  'Room lantern: at least this many units per level, however few are live [ASSUMPTION].';
comment on column public.matching_config.lantern_breath_cycle_weight is
  'Room lantern: units per human breath cycle finished in a Breath Ripples session started from the room [ASSUMPTION].';

-- =============================================================================================== 5. intention presets
create table if not exists public.room_intention_presets (
  language_pool text not null check (language_pool in ('en','te','hi')),
  key           text not null check (key ~ '^[a-z][a-z0-9_]{1,47}$'),
  position      int  not null default 0,
  enabled       boolean not null default true,
  updated_at    timestamptz not null default now(),
  primary key (language_pool, key)
);
comment on table public.room_intention_presets is
  'Tonight''s intention list per language pool (PRD 19 "the Tonight''s intention list per language"). Keys only; the app localises them. Enabled presets rotate nightly by the region-local date.';
alter table public.room_intention_presets enable row level security;
revoke all on table public.room_intention_presets from anon, authenticated;

insert into public.room_intention_presets (language_pool, key, position)
select p.pool, k.key, k.position
  from (values ('en'), ('te'), ('hi')) as p(pool)
  cross join (values
    ('sleep_before_midnight', 10),
    ('gentle_with_myself',    20),
    ('phone_down_10',         30),
    ('water_before_bed',      40),
    ('one_kind_thought',      50),
    ('slow_breaths',          60)
  ) as k(key, position)
on conflict do nothing;

-- =============================================================================================== 6. kill switches
insert into public.feature_flags (key, enabled, payload, description) values
  ('room_lanterns_enabled', true, '{}'::jsonb,
   'Room lanterns (F5, Milestone B). Off: lanterns take no light and are hidden in every room (the stored level is kept).'),
  ('room_intention_enabled', true, '{}'::jsonb,
   'Tonight''s intention (F5, Milestone B). Off: no intention shows and holding answers 503 intention_paused.')
on conflict (key) do nothing;
