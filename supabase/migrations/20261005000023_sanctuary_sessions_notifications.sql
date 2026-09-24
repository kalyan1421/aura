-- Sanctuary session records (F15) and the F14 Milestone B notification rules; reduced mode's sign-up throttle (PRD 19).
-- Server: src/sanctuary (sync entity `sanctuary_session`), src/notifications (schedules.ts, welcome-back.ts,
-- gestures-push.ts and the new kinds in delivery), src/profile/signup-throttle.ts.
-- Contracts: contracts/api/v1.md "Sanctuary sessions", contracts/api/v1-notifications.md §6–§9.
--
--  1. `sanctuary_sessions` (PRD 10-data-model): one content-free row per finished Sanctuary activity — activity,
--     variant (the breathing pattern / grounding exercise / sounds timer), duration, Aura day, device time. No text,
--     audio, stems or mood. Written only through POST /v1/sync/push (entity `sanctuary_session`, idempotent on the
--     client id); the owner reads their own rows (select-own). Personal: in the account purge.
--  2. `notification_prefs` gains the Milestone B settings (per-type toggles, rule 8): gestures received, welcome back
--     (both on by default), the opt-in wind-down reminder (off until a time is picked; `wind_down_in_quiet_ok` is
--     rule 1's one-time confirmation for a time inside quiet hours) and per-habit nudge times (`habit_nudges`,
--     habit id -> HH:MM; a habit with a time is opted in). Lantern Hour uses the foundations' `lantern_opt_in`.
--  3. `notification_schedule` — server-managed next instant per user-timed kind (wind-down reminder, Lantern Hour,
--     habit nudge), swept every minute like `reminder_next_at`. Server-only, personal.
--  4. `notification_activity` — when the account last wrote anything (sync push, profile / device / room calls via
--     device_installs) and how many welcome-back pushes this absence has had (2 per absence, then silence).
--     Maintained by triggers; server-only, personal.
--  5. `gesture_push_log` — "1 push per room per day" for gestures received: one row per recipient, room and Aura day
--     once the batched push is queued. Server-only, personal; goes with the room.
--  6. Reduced mode's sign-up throttle: an index for "profiles created in the last hour"; the flag's description.
-- Idempotent (safe to re-run): on the shared local stack it may be applied ahead of lower-numbered migrations.

-- =============================================================================================== 1. sanctuary sessions
create table if not exists public.sanctuary_sessions (
  id          uuid primary key,                                   -- client UUIDv7 (idempotency key)
  user_id     uuid not null references auth.users(id) on delete cascade,
  activity    text not null check (activity in ('breathe','grounding','stillness','savour','sounds','night_wind_down')),
  variant     text not null,
  duration_s  int  not null check (duration_s between 1 and 43200),   -- 1 s … 12 h (a long Sounds session)
  local_day   date not null,                                      -- the Aura day the activity started
  device_ts   timestamptz not null,                               -- when it finished (device clock)
  server_ts   timestamptz not null default now(),
  -- Content-free by construction: the variant is one of a closed list per activity, never free text.
  constraint sanctuary_sessions_variant check (
       (activity = 'breathe'         and variant in ('calm','box','478'))
    or (activity = 'grounding'       and variant in ('land','heart','senses','gratitude'))
    or (activity = 'stillness'       and variant = 'orb')
    or (activity = 'savour'          and variant = 'moment')
    or (activity = 'sounds'          and variant in ('open','timer_15','timer_30','timer_60'))
    or (activity = 'night_wind_down' and variant = 'v1')
  )
);
create index if not exists sanctuary_sessions_user_day_idx on public.sanctuary_sessions (user_id, local_day);
create index if not exists sanctuary_sessions_user_ts_idx on public.sanctuary_sessions (user_id, device_ts desc);
comment on table public.sanctuary_sessions is
  'F15: one content-free record per finished Sanctuary activity (activity, variant, duration, Aura day). Written via POST /v1/sync/push only; select-own; purged with the account.';

alter table public.sanctuary_sessions enable row level security;
drop policy if exists own_read on public.sanctuary_sessions;
create policy own_read on public.sanctuary_sessions for select to authenticated using (user_id = auth.uid());
revoke all on table public.sanctuary_sessions from anon, authenticated;
grant select on table public.sanctuary_sessions to authenticated;

-- =============================================================================================== 2. prefs
-- `habit_nudges`: {"<habit uuid>": "HH:MM", …}, at most 16 entries (6 presets + 3 custom fit easily).
create or replace function public.habit_nudges_valid(j jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select jsonb_typeof(j) = 'object'
     and (select count(*) from jsonb_each(j)) <= 16
     and not exists (
       select 1 from jsonb_each(j) e
        where e.key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           or jsonb_typeof(e.value) <> 'string'
           or (e.value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
     )
$$;
revoke all on function public.habit_nudges_valid(jsonb) from public, anon, authenticated;

alter table public.notification_prefs
  add column if not exists gestures_enabled      boolean not null default true,   -- "Gestures received" (batched)
  add column if not exists welcome_back_enabled  boolean not null default true,   -- "Welcome back" (2 per absence)
  add column if not exists wind_down_enabled     boolean not null default false,  -- opt-in (REQ-NTF-04): off until a time is picked
  add column if not exists wind_down_time        time,
  add column if not exists wind_down_in_quiet_ok boolean not null default false,  -- rule 1: confirmed a time inside quiet hours
  add column if not exists habit_nudges          jsonb   not null default '{}'::jsonb;

alter table public.notification_prefs
  drop constraint if exists notification_prefs_habit_nudges_shape,
  drop constraint if exists notification_prefs_wind_down_whole_minutes;
alter table public.notification_prefs
  add constraint notification_prefs_habit_nudges_shape check (public.habit_nudges_valid(habit_nudges)),
  add constraint notification_prefs_wind_down_whole_minutes check (
    wind_down_time is null or extract(second from wind_down_time) = 0
  );

comment on column public.notification_prefs.lantern_opt_in is
  'Lantern Hour push (opt-in, PRD 12): when the timezone region''s Lantern Hour starts; synced as `lanternHour`.';
comment on column public.notification_prefs.habit_nudges is
  'Habit nudges (opt-in, PRD 12): habit id -> local HH:MM. Ids only, never a habit name.';

-- =============================================================================================== 3. schedule
create table if not exists public.notification_schedule (
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null check (kind in ('wind_down_reminder','lantern_hour','habit_nudge')),
  next_at    timestamptz not null,
  tz         text not null check (char_length(tz) between 1 and 64),  -- the zone next_at was planned in
  planned_at timestamptz not null default now(),
  primary key (user_id, kind)
);
create index if not exists notification_schedule_due_idx on public.notification_schedule (next_at);
comment on table public.notification_schedule is
  'Server-managed: the next instant of each user-timed push kind (wind-down reminder, Lantern Hour, habit nudge). No row = nothing planned.';

alter table public.notification_schedule enable row level security;
revoke all on table public.notification_schedule from anon, authenticated;

-- =============================================================================================== 4. activity
create table if not exists public.notification_activity (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  last_active_at  timestamptz not null default now(),
  welcome_step    smallint    not null default 0 check (welcome_step between 0 and 2),  -- pushes this absence
  welcome_sent_at timestamptz
);
create index if not exists notification_activity_idle_idx on public.notification_activity (last_active_at) where welcome_step < 2;
comment on table public.notification_activity is
  'Server-managed: last write by the account (triggers) and the welcome-back pushes of the current absence (7 and 21 days, then silence).';

alter table public.notification_activity enable row level security;
revoke all on table public.notification_activity from anon, authenticated;

-- Any write the account makes (a sync push, a profile / device / room call) ends an absence.
create or replace function public.note_account_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_activity as a (user_id, last_active_at, welcome_step)
  values (new.user_id, now(), 0)
  on conflict (user_id) do update
    set last_active_at = greatest(a.last_active_at, excluded.last_active_at), welcome_step = 0;
  return null;
end $$;
revoke all on function public.note_account_activity() from public, anon, authenticated;

drop trigger if exists sync_mutations_note_activity on public.sync_mutations;
create trigger sync_mutations_note_activity after insert on public.sync_mutations
  for each row execute function public.note_account_activity();
drop trigger if exists device_installs_note_activity on public.device_installs;
create trigger device_installs_note_activity after insert or update of last_seen_at on public.device_installs
  for each row execute function public.note_account_activity();

-- Existing accounts start from what is already known.
insert into public.notification_activity (user_id, last_active_at)
select x.user_id, max(x.at)
  from (select user_id, applied_at as at from public.sync_mutations
        union all select user_id, last_seen_at from public.device_installs
        union all select user_id, updated_at from public.profiles) x
 where exists (select 1 from auth.users u where u.id = x.user_id)
 group by x.user_id
on conflict (user_id) do nothing;

-- =============================================================================================== 5. gesture push log
create table if not exists public.gesture_push_log (
  user_id    uuid not null references auth.users(id) on delete cascade,
  room_id    uuid not null references public.rooms(id) on delete cascade,
  local_day  date not null,                                           -- the recipient's Aura day
  created_at timestamptz not null default now(),
  primary key (user_id, room_id, local_day)
);
create index if not exists gesture_push_log_created_idx on public.gesture_push_log (created_at);
comment on table public.gesture_push_log is
  '"Gestures received": one batched push per recipient, room and Aura day (PRD 12 cap). Ids and a date only.';

alter table public.gesture_push_log enable row level security;
revoke all on table public.gesture_push_log from anon, authenticated;

-- =============================================================================================== 6. sign-up throttle
create index if not exists profiles_created_at_idx on public.profiles (created_at);

update public.feature_flags
   set description = 'Reduced mode (PRD 19, before AK is unreachable): reflections paused (503 reflections_paused) and sign-ups throttled (new profiles beyond payload.signupsPerHour in the last hour, default 20, get 503 signups_throttled); check-ins, gestures and crisis support keep working.'
 where key = 'reduced_mode';
