-- Two F9 safety changes (contracts/api/v1-rooms.md §2.1, §2.3, §2.4; PRD 06b "Report reasons", 06c F9 REQ-SAFE-04/05):
--
--  1. Report reason 9 "Targeting a young person": a bystander's sense that someone is going after a young person routes
--     to the Minors & grooming lane whatever the ages on record (src/safety/lanes.ts). Codes 1–8 keep their meaning, so
--     older apps keep working; the new code goes at the end.
--  2. Community guidelines acceptance on the server (REQ-SAFE-04 "Unaccepted current version → guidelines first"):
--     `safety_config.guidelines_version` is the version the app must have accepted before `POST /v1/rooms/match`
--     (bump it only once an app release carries the new copy); `guidelines_acceptances` records each version an
--     account accepted and when (`POST /v1/safety/guidelines/accept`). The app's own flag is only a cache of this.
--
-- `guidelines_acceptances` is SERVER-ONLY like the rest of F9 (RLS on, no policies, no client privileges): the app
-- reads its status from `GET /v1/safety/me`. Its rows hang off `profiles` with ON DELETE CASCADE, so the account purge
-- removes them in its first transaction together with the profile (step 1 of src/account/account-purge.ts), and the
-- auth.users delete would cascade them anyway. It must still be listed in PERSONAL_TABLES (before 'profiles'): the e2e
-- suite checks that every public table with a `user_id` column is in that list.

-- =============================================================================================== 1. reason 9
alter table public.reports drop constraint reports_reason_check;
alter table public.reports add constraint reports_reason_check check (reason between 1 and 9);
comment on column public.reports.reason is
  '1 in danger · 2 harassment · 3 sexual · 4 hate · 5 contact/personal info · 6 spam · 7 may be under 13 · 8 other · '
  '9 targeting a young person (7 and 9 → Minors & grooming whatever the ages; 1 → crisis). Never returned with a lane.';
comment on column public.safety_config.report_daily_limit is
  'Reports per account per 24 h for reasons 2–9; reason 1 (someone may be in danger) is never limited.';

-- =============================================================================================== 2. guidelines
alter table public.safety_config
  add column guidelines_version smallint not null default 1 check (guidelines_version between 1 and 1000);
comment on column public.safety_config.guidelines_version is
  'Community guidelines version an account must have accepted (this version or a newer one) before joining a room '
  '(REQ-SAFE-04). Bump only after an app release carries the new copy; everyone is asked again at their next room.';

create table public.guidelines_acceptances (
  user_id     uuid not null references public.profiles(user_id) on delete cascade,
  version     smallint not null check (version between 1 and 1000),
  accepted_at timestamptz not null default now(),
  primary key (user_id, version)
);
comment on table public.guidelines_acceptances is
  'Community guidelines versions each account accepted (REQ-SAFE-04, Play UGC). Written only by NestJS '
  '(POST /v1/safety/guidelines/accept); read via GET /v1/safety/me. Server-only; purged with the profile.';

alter table public.guidelines_acceptances enable row level security;
revoke all on table public.guidelines_acceptances from anon, authenticated;
