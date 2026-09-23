-- F14 notifications, Milestone A subset (PRD 12-notifications; contracts/api/v1-notifications.md): the daily check-in
-- reminder and the "date capsule unlocked" push under the global rules — quiet hours, at most 2 pushes per local day
-- with precedence, content-free payloads, discreet mode, per-type toggles plus a master switch.
--
-- `public.notification_prefs` (foundations) gains:
--   * the settings the app syncs through POST /v1/sync/push (entity `notification_prefs`, per-field last-write-wins
--     on the device time; `field_ts` holds the time each field was last written): master switch, daily reminder on/off
--     (+ the existing `reminder_time`), the one-time "remind me inside quiet hours" confirmation, capsule pushes on/off;
--     quiet hours and discreet mode already exist;
--   * server-managed delivery state, kept on the same row so no new personal table is needed:
--       - `reminder_next_at` / `reminder_tz`: when the next daily reminder is due (worker sweep, every minute) and in
--         which zone it was computed (re-computed when the profile timezone changes);
--       - `sent_day` / `sent_types`: today's send log — the push TYPES sent on the user's current Aura day, for the
--         daily cap and per-type dedupe. Type names only: no ids, no content, nothing older than the current day.
-- Clients keep reading only their own row (select-own, foundations) and never write it.

alter table public.notification_prefs
  add column enabled              boolean     not null default true,   -- master switch
  add column reminder_enabled     boolean     not null default false,  -- off until the person picks a time
  add column reminder_in_quiet_ok boolean     not null default false,  -- confirmed: honour a reminder inside quiet hours
  add column capsule_enabled      boolean     not null default true,   -- "date capsule unlocked"
  add column field_ts             jsonb       not null default '{}'::jsonb,
  add column reminder_next_at     timestamptz,
  add column reminder_tz          text,
  add column sent_day             date,
  add column sent_types           text[]      not null default '{}';

alter table public.notification_prefs
  add constraint notification_prefs_field_ts_object check (jsonb_typeof(field_ts) = 'object'),
  -- Times are whole minutes (the app picks HH:MM).
  add constraint notification_prefs_whole_minutes check (
    extract(second from quiet_start) = 0
    and extract(second from quiet_end) = 0
    and (reminder_time is null or extract(second from reminder_time) = 0)
  ),
  -- The send log holds a handful of machine type names, nothing else.
  add constraint notification_prefs_sent_types_shape check (
    cardinality(sent_types) <= 16
    and array_to_string(sent_types, ',') ~ '^([a-z_]{1,40}(,[a-z_]{1,40})*)?$'
  ),
  add constraint notification_prefs_reminder_tz_length check (reminder_tz is null or char_length(reminder_tz) <= 64);

-- The reminder sweep: `reminder_next_at <= now()`.
create index notification_prefs_reminder_due_idx on public.notification_prefs (reminder_next_at)
  where reminder_next_at is not null;

comment on column public.notification_prefs.field_ts is
  'Per-field last-write-wins: field name -> device time (clamped to server time) of the last applied write.';
comment on column public.notification_prefs.reminder_next_at is
  'Server-managed: next daily-reminder instant (null = none). Re-computed on every prefs change and zone change.';
comment on column public.notification_prefs.sent_types is
  'Server-managed send log for sent_day (the user''s Aura day): push type names only — caps and dedupe.';
