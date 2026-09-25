-- Beta hardening: realtime load test follow-up (docs/perf/realtime-load-test.md, PRD 20-timeline weeks 28–29).
--
-- Finding: deleting a room (the purge job, `room-lifecycle.ts`), a member or a gesture (account deletion cascades) makes
-- Postgres check every foreign key that points at the deleted row. Several of those referencing columns had no index,
-- so each check was a sequential scan of the referencing table. `reports` is kept for years (moderation queue and
-- audit trail) and already holds one auto row per held reflection / flood signal, so the cost grows with it:
-- measured locally with 200k reports, purging one room with 1 member and 5 gestures took 60.6 ms, 59 ms of it in the
-- `reports_reporter_member_id_fkey`, `reports_target_member_id_fkey` and `reports_target_gesture_id_fkey` checks
-- (≈ 8 ms per member and per gesture); with the indexes below it took 0.54 ms. A 20-member room with 200 gestures
-- would have cost ≈ 2 s of the purge worker per room at that size.
--
-- Fix: index every referencing column of an ON DELETE CASCADE / SET NULL foreign key that had none (partial
-- `where … is not null` for the nullable ones: the FK check's `col = $1` implies it). Pure additions — no data, policy
-- or privilege change. Tables are small before launch, so plain CREATE INDEX (brief write lock) is fine here; on a
-- large production table the same statement would be run CONCURRENTLY outside a transaction.
-- supabase/tests/28_perf.test.sql keeps it that way: every such foreign key must have an index that leads with one of
-- its columns.

-- ---- reports (kept long; touched by member, gesture, evidence-hold deletes) ----------------------------------------
create index if not exists reports_reporter_member_idx on public.reports (reporter_member_id)
  where reporter_member_id is not null;
create index if not exists reports_target_member_idx on public.reports (target_member_id)
  where target_member_id is not null;
create index if not exists reports_target_gesture_idx on public.reports (target_gesture_id)
  where target_gesture_id is not null;
create index if not exists reports_evidence_hold_idx on public.reports (evidence_hold_id)
  where evidence_hold_id is not null;

-- ---- sanctions / strikes → reports ---------------------------------------------------------------------------------
create index if not exists sanctions_report_idx on public.sanctions (report_id) where report_id is not null;
create index if not exists strikes_report_idx on public.strikes (report_id) where report_id is not null;

-- ---- rooms and room members (room purge) ---------------------------------------------------------------------------
create index if not exists room_mutes_muted_idx on public.room_mutes (room_id, muted_member_id);
create index if not exists gifts_recipient_member_idx on public.gifts (recipient_member_id)
  where recipient_member_id is not null;
create index if not exists gifts_room_idx on public.gifts (room_id) where room_id is not null;
create index if not exists gesture_push_log_room_idx on public.gesture_push_log (room_id);
create index if not exists blocks_source_room_idx on public.blocks (source_room_id) where source_room_id is not null;

-- ---- Breath Ripples → rooms / members / invites ---------------------------------------------------------------------
create index if not exists ripple_seats_room_member_idx on public.ripple_seats (room_member_id)
  where room_member_id is not null;
create index if not exists ripple_tickets_room_member_idx on public.ripple_tickets (room_member_id)
  where room_member_id is not null;
create index if not exists ripple_tickets_room_idx on public.ripple_tickets (room_id) where room_id is not null;
create index if not exists ripple_tickets_session_idx on public.ripple_tickets (session_id) where session_id is not null;
create index if not exists ripple_invites_inviter_member_idx on public.ripple_invites (inviter_member_id)
  where inviter_member_id is not null;
create index if not exists ripple_sessions_invite_idx on public.ripple_sessions (invite_id) where invite_id is not null;

-- ---- account deletion (auth.users cascade) and small admin / billing links -----------------------------------------
create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
create index if not exists admin_deletion_cases_grievance_idx on public.admin_deletion_cases (grievance_id)
  where grievance_id is not null;
create index if not exists entitlements_plus_subscription_idx on public.entitlements (plus_subscription_id)
  where plus_subscription_id is not null;
create index if not exists user_cosmetics_purchase_idx on public.user_cosmetics (purchase_id)
  where purchase_id is not null;
