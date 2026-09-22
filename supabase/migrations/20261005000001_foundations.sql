-- Aura foundations schema (PRD v1.1: Data Model; contracts/api/v1.md; contracts/rules/RULES.md)
-- Rule: clients never write personal tables. RLS grants SELECT-own only; NestJS writes via a privileged role.

create extension if not exists pgcrypto;

-- ---------- Catalogues (public read) ----------
create table public.moods (
  id        text primary key,
  quadrant  text not null check (quadrant in ('storm','rain','moonlight','sunrise')),
  sort      int  not null,
  names     jsonb not null
);

create table public.preset_habits (
  key   text primary key,
  names jsonb not null
);

create table public.feature_flags (
  key     text primary key,
  enabled boolean not null default false,
  payload jsonb not null default '{}'::jsonb
);

-- ---------- Identity ----------
create table public.profiles (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  birth_date    date not null,                                  -- DS-6: full DOB
  ui_locale     text not null check (ui_locale in ('en','te','te-Latn','hi','hi-Latn')),
  language_pool text not null check (language_pool in ('en','te','hi')),
  timezone      text not null,                                  -- IANA, e.g. Asia/Kolkata
  tz_region     text,                                           -- set by NestJS for room matching
  country       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint profiles_min_age check (birth_date <= (current_date - interval '13 years'))
);

-- Under-18 flag is derived, never stored, and never limits features (D2).
create function public.user_is_minor(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select birth_date > (current_date - interval '18 years') from public.profiles where user_id = uid), false)
$$;
revoke all on function public.user_is_minor(uuid) from public, anon, authenticated;

create table public.user_consents (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  purpose        text not null check (purpose in ('core','analytics','echoes','moderation_corpus')),
  policy_version text not null,
  granted_at     timestamptz not null default now(),
  withdrawn_at   timestamptz
);
create index on public.user_consents (user_id, purpose);

create table public.user_data_keys (             -- DS-1 envelope encryption; never client-readable
  user_id     uuid primary key references auth.users(id) on delete cascade,
  key_id      uuid not null default gen_random_uuid(),
  wrapped_key text not null,                     -- AES-256-GCM(master, dataKey), base64
  created_at  timestamptz not null default now()
);

-- ---------- Personal core ----------
create table public.check_ins (
  id          uuid primary key,                  -- client UUIDv7
  user_id     uuid not null references auth.users(id) on delete cascade,
  mood_id     text not null references public.moods(id),
  quadrant    text not null check (quadrant in ('storm','rain','moonlight','sunrise')),
  tags        text[] not null default '{}',
  note_ct     text,                              -- client-encrypted, base64; server never decrypts
  voice_path  text,
  local_day   date not null,                     -- Aura day (04:00 rollover)
  device_ts   timestamptz not null,
  server_ts   timestamptz not null default now(),
  source      text not null default 'app' check (source in ('app','widget')),
  backfill    boolean not null default false,
  updated_at  timestamptz not null default now()
);
create index on public.check_ins (user_id, local_day);

create table public.habits (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  kind        text not null check (kind in ('preset','custom')),
  preset_key  text references public.preset_habits(key),
  name        text check (name is null or char_length(name) <= 40),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint habits_kind_shape check ((kind = 'preset' and preset_key is not null) or (kind = 'custom' and name is not null))
);
create index on public.habits (user_id);

create table public.habit_logs (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  habit_id    uuid not null references public.habits(id) on delete cascade,
  local_day   date not null,
  device_ts   timestamptz not null,
  server_ts   timestamptz not null default now(),
  unique (habit_id, local_day)
);
create index on public.habit_logs (user_id, local_day);

-- Append-only. One row per eligible credited event (amount may be 0 when capped) — DS-5.
create table public.starlight_ledger (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  amount      int  not null check (amount >= 0),
  reason      text not null check (reason in ('checkin','habit')),
  source_id   uuid not null,
  habit_key   text,                              -- preset key for trait counts (breathe, sleep_on_time)
  local_day   date not null,
  created_at  timestamptz not null default now(),
  unique (reason, source_id)
);
create index on public.starlight_ledger (user_id, local_day);

-- Active-day evidence survives check-in deletion ("deleting never removes glow days").
create table public.active_days (
  user_id   uuid not null references auth.users(id) on delete cascade,
  local_day date not null,
  primary key (user_id, local_day)
);

create table public.avatar_state (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  stage               text not null default 'spark' check (stage in ('spark','ember','glow','radiance','constellation')),
  total_starlight     int  not null default 0,
  hue                 real,
  is_resting          boolean not null default false,
  ring_count          int  not null default 0 check (ring_count between 0 and 3),
  glow_level          int  not null default 0 check (glow_level between 0 and 3),
  constellation_stars int  not null default 0 check (constellation_stars between 0 and 12),
  equipped_cosmetics  text[] not null default '{}',
  updated_at          timestamptz not null default now()
);

create table public.streak_state (
  user_id            uuid primary key references auth.users(id) on delete cascade,
  glow_streak        int  not null default 0,
  lifetime_glow_days int  not null default 0,
  rest_bank          int  not null default 1 check (rest_bank between 0 and 3),   -- 1 welcome rest day
  earn_counter       int  not null default 0 check (earn_counter between 0 and 3),
  last_active_day    date,
  updated_at         timestamptz not null default now()
);

-- ---------- Sync & ops ----------
create table public.sync_mutations (              -- idempotency for POST /v1/sync/push
  user_id     uuid not null references auth.users(id) on delete cascade,
  mutation_id uuid not null,
  entity      text not null,
  status      text not null check (status in ('applied','rejected')),
  reason      text,
  applied_at  timestamptz not null default now(),
  primary key (user_id, mutation_id)
);

create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text not null check (platform in ('ios','android')),
  token      text not null unique,
  updated_at timestamptz not null default now()
);

create table public.notification_prefs (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  reminder_time  time,
  quiet_start    time not null default '23:00',
  quiet_end      time not null default '08:00',
  discreet       boolean not null default false,
  lantern_opt_in boolean not null default false,
  updated_at     timestamptz not null default now()
);

create table public.crisis_events (               -- DS-7: aggregate only, no user_id by design
  id         bigserial primary key,
  surface    text not null,
  locale     text not null,
  created_at timestamptz not null default now()
);

-- ---------- RLS ----------
alter table public.moods              enable row level security;
alter table public.preset_habits      enable row level security;
alter table public.feature_flags      enable row level security;
alter table public.profiles           enable row level security;
alter table public.user_consents      enable row level security;
alter table public.user_data_keys     enable row level security;
alter table public.check_ins          enable row level security;
alter table public.habits             enable row level security;
alter table public.habit_logs         enable row level security;
alter table public.starlight_ledger   enable row level security;
alter table public.active_days        enable row level security;
alter table public.avatar_state       enable row level security;
alter table public.streak_state       enable row level security;
alter table public.sync_mutations     enable row level security;
alter table public.device_tokens      enable row level security;
alter table public.notification_prefs enable row level security;
alter table public.crisis_events      enable row level security;

create policy catalogue_read on public.moods         for select to anon, authenticated using (true);
create policy catalogue_read on public.preset_habits for select to anon, authenticated using (true);
create policy flags_read     on public.feature_flags for select to anon, authenticated using (true);

create policy own_read on public.profiles           for select to authenticated using (user_id = auth.uid());
create policy own_read on public.user_consents      for select to authenticated using (user_id = auth.uid());
create policy own_read on public.check_ins          for select to authenticated using (user_id = auth.uid());
create policy own_read on public.habits             for select to authenticated using (user_id = auth.uid());
create policy own_read on public.habit_logs         for select to authenticated using (user_id = auth.uid());
create policy own_read on public.starlight_ledger   for select to authenticated using (user_id = auth.uid());
create policy own_read on public.active_days        for select to authenticated using (user_id = auth.uid());
create policy own_read on public.avatar_state       for select to authenticated using (user_id = auth.uid());
create policy own_read on public.streak_state       for select to authenticated using (user_id = auth.uid());
create policy own_read on public.notification_prefs for select to authenticated using (user_id = auth.uid());
-- user_data_keys, sync_mutations, device_tokens, crisis_events: no client policies at all.

-- Belt and braces: clients cannot write anything, even if a policy is added by mistake.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
