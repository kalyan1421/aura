-- PRD 12 rule 7 "Smart timing (P1): reminder ignored 5 days in a row → every other day; 14 ignored days → stop and
-- leave it to welcome-back. Any check-in restores the schedule." (contracts/api/v1-notifications.md "Smart timing").
--
-- Two server-only columns on the existing server-only `notification_activity` (no client privilege, RLS without
-- policies): the last daily reminder actually delivered, and how many reminders in a row went out with no check-in
-- after them. Written only by NestJS when a reminder is delivered (src/notifications/delivery.service.ts); read with
-- the account's check-ins to decide the next one (src/notifications/policy.ts `smartTimingSkip`).

alter table public.notification_activity
  add column if not exists reminder_last_sent_at timestamptz,
  add column if not exists reminder_ignored smallint not null default 0
    constraint notification_activity_reminder_ignored_nonneg check (reminder_ignored >= 0);

comment on column public.notification_activity.reminder_ignored is
  'PRD 12 rule 7: daily reminders in a row with no check-in after them (0 again after any check-in).';
