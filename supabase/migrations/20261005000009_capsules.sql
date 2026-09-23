-- F4 Personal Time Capsules (contracts/api/v1-capsules.md; PRD F4, DS-1; conflict rules in 16-offline.md).
--
-- `public.capsules`: one row per capsule, written ONLY by NestJS (POST /v1/sync/push, entity `capsule`), read by the
-- owner with Supabase select-own (the app's pull). The row holds ciphertext plus unlock metadata only: title, text,
-- media references and the hard-moment flag live inside `payload_ct` (client-encrypted, never decrypted server-side).
-- A deleted capsule stays as a TOMBSTONE (content erased) so a delete made on one device wins over stale ops from
-- another and reaches every device through the pull.
create table public.capsules (
  id                uuid primary key,                                  -- client UUIDv7
  user_id           uuid not null references auth.users(id) on delete cascade,
  unlock_type       text not null check (unlock_type in ('date','mood')),
  unlock_local_date date,                                              -- date: 10:00 local (current zone) on this date
  trigger_mood_id   text references public.moods(id),                  -- mood: one mood ...
  trigger_quadrant  text check (trigger_quadrant in ('storm','rain','moonlight','sunrise')), -- ... or a quadrant
  payload_ct        text,                                              -- DS-1 ciphertext; null only on tombstones
  sealed_at         timestamptz not null,                              -- device time of sealing
  armed_at          timestamptz,                                       -- mood: may fire from here (seal + 24 h / re-arm)
  cycle             int not null default 0,                            -- mood: re-arm count ("Keep for next time")
  fired_at          timestamptz,                                       -- mood: fire time in the current cycle (earliest wins)
  cooldown_until    timestamptz,                                       -- mood: most recent fire + 168 h (global cooldown = max)
  opened_at         timestamptz,                                       -- server time of the first open (real unlock time)
  opened_device_ts  timestamptz,                                       -- the device's claimed open time
  deleted_at        timestamptz,                                       -- tombstone
  server_ts         timestamptz not null default now(),                -- when the seal reached the server
  updated_at        timestamptz not null default now(),                -- set by every write: the pull cursor

  -- Ciphertext only: base64/base64url (plaintext JSON would contain braces, quotes and spaces), ≤ 128 KiB.
  constraint capsules_payload_ct_shape check (
    payload_ct is null or (octet_length(payload_ct) between 1 and 131072 and payload_ct ~ '^[A-Za-z0-9+/_-]+={0,2}$')
  ),
  constraint capsules_cycle_nonneg check (cycle >= 0),
  -- A live capsule has content and exactly the unlock metadata of its type.
  constraint capsules_live_shape check (
    deleted_at is not null or (
      payload_ct is not null and (
        (unlock_type = 'date' and unlock_local_date is not null and trigger_mood_id is null and trigger_quadrant is null
          and armed_at is null and fired_at is null and cooldown_until is null and cycle = 0)
        or (unlock_type = 'mood' and unlock_local_date is null
          and (trigger_mood_id is null) <> (trigger_quadrant is null) and armed_at is not null)
      )
    )
  ),
  -- Deleting erases the content and the unlock target (a target mood says something about the person).
  constraint capsules_tombstone_erased check (
    deleted_at is null or (payload_ct is null and unlock_local_date is null and trigger_mood_id is null and trigger_quadrant is null)
  ),
  constraint capsules_opened_pair check ((opened_at is null) = (opened_device_ts is null)),
  constraint capsules_opened_trigger_fired check (unlock_type = 'date' or opened_at is null or fired_at is not null),
  constraint capsules_fire_has_cooldown check (fired_at is null or cooldown_until is not null)
);

-- Pull (`user_id = me and updated_at >= cursor`) and every per-user lookup / limit count.
create index capsules_user_updated_idx on public.capsules (user_id, updated_at);
-- Pending date capsules: the unlock-push sweep and the fair-use count.
create index capsules_pending_date_idx on public.capsules (user_id)
  where unlock_type = 'date' and deleted_at is null and opened_at is null;

alter table public.capsules enable row level security;
create policy own_read on public.capsules for select to authenticated using (user_id = (select auth.uid()));
-- Clients never write (default privileges from 000003 already withhold these; explicit for this table) and anon
-- has no business reading capsules at all.
revoke insert, update, delete, truncate on table public.capsules from anon, authenticated;
revoke select on table public.capsules from anon;

comment on table public.capsules is
  'F4 time capsules: ciphertext + unlock metadata only (DS-1). Written only by NestJS sync push; select-own for the owner.';

-- Server-only bookkeeping for the "Date capsule unlocked" push (one BullMQ delayed job per pending date capsule,
-- queue `capsule-unlock`): when it is due, in which zone it was computed (the worker sweep re-schedules when the
-- profile timezone changes) and whether it was sent. No user_id: rows go with their capsule (cascade), and the
-- account purge deletes capsules.
create table public.capsule_unlock_schedule (
  capsule_id  uuid primary key references public.capsules(id) on delete cascade,
  notify_at   timestamptz not null,
  notify_tz   text not null,
  notified_at timestamptz,
  updated_at  timestamptz not null default now()
);
create index capsule_unlock_schedule_pending_idx on public.capsule_unlock_schedule (notify_at) where notified_at is null;

alter table public.capsule_unlock_schedule enable row level security;
revoke all on table public.capsule_unlock_schedule from anon, authenticated;
