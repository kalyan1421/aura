-- Admin console v0 (PRD 19-admin-console; 06c F9 grievances, IT Rules clocks and 24×7 paging; 20-timeline week 13 exit:
-- "A test takedown order pages AK"). Server: server/aura-api/src/admin (NestJS `/admin/*`, `POST /v1/grievances`,
-- `POST /v1/intake/legal-orders`); console: apps/admin (Next.js, talks only to those routes); setup and runbook:
-- docs/setup/admin-console.md.
--
--  1. `aura_admin` — the Postgres role every console read and console write of these tables runs under (NestJS opens
--     the transaction and `SET LOCAL ROLE aura_admin`, src/admin/admin-db.ts). NOLOGIN. Grants only on the moderation
--     and admin tables, column-scoped where an account link isn't needed: never the reporter (`reports.reporter_user_id`),
--     never the account behind a pseudonym (`room_members.user_id`), nothing on private tables (check-ins, notes,
--     habits, capsules, keys, ledgers, `profiles` incl. `birth_date`, consents, device tokens) and no usage on the `auth`
--     schema (REQ-ADM-03). BYPASSRLS because the moderation tables are server-only (RLS on, no policies): the grants
--     are the boundary. Moderation ACTIONS go through the internal ModerationService (src/safety), which runs as the
--     service role; the console layer adds staff auth, roles and audit around it (see docs/setup/admin-console.md).
--  2. `admin_staff` — the console allowlist with roles (Owner / Moderator / Read-only analyst). Staff are Supabase Auth
--     users that are NOT app accounts (no profile); the NestJS guard also requires AAL2 via TOTP. Every change to the
--     allowlist is written to the audit chain by a trigger, whoever makes it.
--  3. `admin_grievances` — Grievance Officer tickets (IT Rules 2021 as amended 20 Feb 2026, PRD 19): acknowledge 24 h,
--     resolve 7 days, unlawful content 36 h, nudity / CSAM and non-consensual intimate imagery 2 h (those page 24×7).
--     Holds the complainant's contact email [LEGAL: retention]. Owner only.
--  4. `admin_legal_orders` — court / government takedown orders: 3 h from receipt, Owner only, page 24×7.
--  5. `admin_pages`, `admin_page_deliveries` — the on-call pager (who/what is being paged, retries, escalation,
--     acknowledgement) and its delivery log. Payloads never carry content (lane, minor flag, wait time, ticket only).
--  6. `admin_mandatory_checklists` — the minors & grooming SOP checklist per evidence hold (mandatory report prepared;
--     the filing itself follows the lawyer's SOP, action A3) and the break-glass evidence-bundle export record.
--  7. `admin_account_age_days(uuid)` — account age for the item view without giving aura_admin the auth schema.
--
-- Account links: no table here has a `user_id` column or holds an app account id (staff ids are separate accounts),
-- so the account purge (src/account/account-purge.ts) has nothing to clear.

-- =============================================================================================== 1. aura_admin
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'aura_admin') then
    create role aura_admin nologin noinherit bypassrls;
  end if;
end $$;
alter role aura_admin nologin noinherit bypassrls;
-- The API's database role switches into aura_admin per transaction; it never inherits aura_admin's (narrower) grants.
-- In production grant the same to the role in the API's DATABASE_URL if it isn't `postgres`.
grant aura_admin to postgres with inherit false, set true;

-- =============================================================================================== 2. staff allowlist
create table public.admin_staff (
  staff_id     uuid primary key references auth.users(id) on delete cascade,
  role         text not null check (role in ('owner','moderator','analyst')),
  display_name text not null check (char_length(display_name) between 1 and 60),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  disabled_at  timestamptz
);
comment on table public.admin_staff is
  'Admin console allowlist + roles (PRD 19 "Roles"). Staff accounts are separate from app accounts; changes are audited.';

-- Every allowlist change lands in the append-only, hash-chained audit log (PRD 19: "staff roles" are Owner business;
-- the console has no staff editor in v0, so changes are made in SQL and this trigger records them). SECURITY DEFINER:
-- the change may come from a role that cannot write the audit log itself — e.g. GoTrue (supabase_auth_admin) deleting
-- a staff auth user cascades here. `session_user` still records who really made the change.
create function public.admin_staff_audit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  r   record;
  act text;
begin
  if tg_op = 'DELETE' then
    r := old;
    act := 'staff_removed';
  elsif tg_op = 'INSERT' then
    r := new;
    act := 'staff_granted';
  else
    r := new;
    act := case
      when new.disabled_at is not null and old.disabled_at is null then 'staff_disabled'
      when new.disabled_at is null and old.disabled_at is not null then 'staff_enabled'
      else 'staff_changed'
    end;
  end if;
  insert into public.moderation_actions (actor, action, reason_code, detail)
  values (left('db:' || session_user, 120), act, 'staff_allowlist',
          jsonb_build_object('staffId', r.staff_id, 'role', r.role, 'disabled', r.disabled_at is not null));
  return null;
end $$;
create trigger admin_staff_audit after insert or update or delete on public.admin_staff
  for each row execute function public.admin_staff_audit();

-- =============================================================================================== 3. grievances
-- Ticket ids: Crockford base32 (no I, L, O, U), 8 characters, minted by NestJS.
create table public.admin_grievances (
  id                  uuid primary key default gen_random_uuid(),
  ticket              text not null unique check (ticket ~ '^GRV-[0-9A-HJKMNP-TV-Z]{8}$'),
  channel             text not null check (channel in ('web_form','in_app','email','post','other')),
  category            text not null check (category in ('general','unlawful_content','nudity_csam','ncii',
                                                        'data_request','moderation_appeal')),
  complainant_name    text check (complainant_name is null or char_length(complainant_name) between 1 and 120),
  complainant_email   text not null check (char_length(complainant_email) between 3 and 254
                                           and complainant_email ~ '^[^@\s]+@[^@\s]+$'),
  locale              text check (locale is null or locale in ('en','te','te-Latn','hi','hi-Latn')),
  description         text not null check (char_length(description) between 1 and 5000),
  content_location    text check (content_location is null or char_length(content_location) <= 1000),
  status              text not null default 'open' check (status in ('open','acknowledged','resolved')),
  received_at         timestamptz not null default now(),
  ack_due_at          timestamptz not null,                   -- received + 24 h
  resolve_due_at      timestamptz not null,                   -- received + 7 d / 36 h / 2 h by category
  pages               boolean not null default false,         -- nudity / CSAM / NCII: 24×7 page
  acknowledged_at     timestamptz,                            -- the auto-acknowledgement (ticket id shown / emailed)
  ack_email_sent_at   timestamptz,
  ack_email_attempts  int not null default 0 check (ack_email_attempts between 0 and 100),
  resolved_at         timestamptz,
  resolved_by         text,
  outcome             text check (outcome is null or outcome in ('action_taken','no_action','referred','duplicate','withdrawn')),
  reply               text check (reply is null or char_length(reply) <= 5000),   -- sent with the GAC appeal route
  reply_email_sent_at timestamptz,
  created_by          text not null check (char_length(created_by) between 1 and 120),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint admin_grievances_clock check (ack_due_at > received_at and resolve_due_at > received_at),
  constraint admin_grievances_resolution check ((status = 'resolved') = (resolved_at is not null and outcome is not null))
);
create index admin_grievances_open_idx on public.admin_grievances (resolve_due_at) where status <> 'resolved';
create index admin_grievances_received_idx on public.admin_grievances (received_at desc);
comment on table public.admin_grievances is
  'Grievance Officer tickets (IT Rules 2021 as amended 20 Feb 2026; PRD 19 REQ-ADM-09). Owner only. [LEGAL] retention.';

-- =============================================================================================== 4. legal orders
create table public.admin_legal_orders (
  id              uuid primary key default gen_random_uuid(),
  ticket          text not null unique check (ticket ~ '^LO-[0-9A-HJKMNP-TV-Z]{8}$'),
  source          text not null check (source in ('court','government','law_enforcement','other')),
  authority       text not null check (char_length(authority) between 1 and 200),
  reference       text check (reference is null or char_length(reference) <= 200),
  received_at     timestamptz not null,                       -- the clock starts at receipt, not at data entry
  due_at          timestamptz not null,                       -- received + 3 h
  summary         text not null check (char_length(summary) between 1 and 5000),
  targets         text check (targets is null or char_length(targets) <= 5000),
  intake_channel  text not null check (intake_channel in ('console','intake_api')),
  is_test         boolean not null default false,             -- drills: page exactly like a real order
  status          text not null default 'open' check (status in ('open','acknowledged','actioned','rejected')),
  acknowledged_at timestamptz,
  acknowledged_by text,
  closed_at       timestamptz,
  closed_by       text,
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 5000),
  created_by      text not null check (char_length(created_by) between 1 and 120),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint admin_legal_orders_clock check (due_at > received_at and received_at <= created_at + interval '5 minutes'),
  constraint admin_legal_orders_closed check ((status in ('actioned','rejected')) = (closed_at is not null))
);
create index admin_legal_orders_open_idx on public.admin_legal_orders (due_at) where status in ('open','acknowledged');
comment on table public.admin_legal_orders is
  'Court / government takedown orders (IT Rules, 3 h; PRD 19 REQ-ADM-09, REQ-ADM-15). Owner only; pages 24×7.';

-- =============================================================================================== 5. pager
create table public.admin_pages (
  id                uuid primary key default gen_random_uuid(),
  kind              text not null check (kind in ('legal_order','grievance','report','test')),
  ref_id            uuid,                                     -- the order / grievance / report (none for a test page)
  reason            text not null check (reason ~ '^[a-z0-9_]{1,40}$'),
  lane              text check (lane is null or lane in ('crisis','minors_grooming','harassment','spam')),
  minor_involved    boolean not null default false,
  is_test           boolean not null default false,
  due_at            timestamptz,                              -- the item's SLA / statutory deadline
  status            text not null default 'open' check (status in ('open','acknowledged','resolved','expired')),
  round             int not null default 0 check (round >= 0),
  escalation_level  int not null default 0 check (escalation_level between 0 and 1),
  next_attempt_at   timestamptz not null default now(),
  lease_until       timestamptz,                              -- a dispatcher holds the page while delivering
  last_attempt_at   timestamptz,
  last_delivered_at timestamptz,
  acknowledged_at   timestamptz,
  acknowledged_by   text,
  closed_at         timestamptz,
  created_at        timestamptz not null default now(),
  constraint admin_pages_ref check ((kind = 'test') = (ref_id is null)),
  constraint admin_pages_ack check ((status = 'acknowledged') = (acknowledged_at is not null))
);
-- One page per item, ever (a report that paged at filing doesn't page again near its SLA).
create unique index admin_pages_ref_idx on public.admin_pages (kind, ref_id) where ref_id is not null;
create index admin_pages_due_idx on public.admin_pages (next_attempt_at) where status = 'open';
create index admin_pages_created_idx on public.admin_pages (created_at desc);
comment on table public.admin_pages is
  'On-call pages to the Owner (PRD 19 REQ-ADM-05/15): push → escalation at 5 min → repeat every 5 min until acknowledged.';

create table public.admin_page_deliveries (
  id          bigint generated always as identity primary key,
  page_id     uuid not null references public.admin_pages(id) on delete cascade,
  round       int not null check (round >= 0),
  level       int not null check (level between 0 and 1),
  channel     text not null check (channel in ('webhook','escalation_webhook','email','none')),
  attempt     int not null check (attempt between 1 and 10),
  ok          boolean not null,
  http_status int,
  error       text check (error is null or error ~ '^[a-z0-9_]{1,60}$'),  -- a code, never a response body
  latency_ms  int not null default 0 check (latency_ms >= 0),
  created_at  timestamptz not null default now()
);
create index admin_page_deliveries_page_idx on public.admin_page_deliveries (page_id, id);
comment on table public.admin_page_deliveries is 'Paging log: one row per delivery attempt per channel (REQ-ADM-15 "logged").';

-- =============================================================================================== 6. mandatory-report checklist
create table public.admin_mandatory_checklists (
  evidence_hold_id   uuid primary key references public.evidence_holds(id) on delete cascade,
  items              jsonb not null default '{}'::jsonb check (jsonb_typeof(items) = 'object'),
  bundle_exported_at timestamptz,
  bundle_sha256      text check (bundle_sha256 is null or bundle_sha256 ~ '^[0-9a-f]{64}$'),
  updated_at         timestamptz not null default now(),
  updated_by         text
);
comment on table public.admin_mandatory_checklists is
  'Minors & grooming SOP checklist per evidence hold (PRD 19 REQ-ADM-14); the filing follows the lawyer''s SOP (A3).';

-- =============================================================================================== 7. account age
create function public.admin_account_age_days(uid uuid) returns int
language sql stable security definer set search_path = '' as $$
  select floor(extract(epoch from (now() - u.created_at)) / 86400)::int from auth.users u where u.id = uid
$$;

-- =============================================================================================== RLS / privileges
alter table public.admin_staff                enable row level security;
alter table public.admin_grievances           enable row level security;
alter table public.admin_legal_orders         enable row level security;
alter table public.admin_pages                enable row level security;
alter table public.admin_page_deliveries      enable row level security;
alter table public.admin_mandatory_checklists enable row level security;

-- Server-only: no policies, no client privileges (any client/PostgREST access → 42501).
revoke all on table
  public.admin_staff, public.admin_grievances, public.admin_legal_orders, public.admin_pages,
  public.admin_page_deliveries, public.admin_mandatory_checklists
from anon, authenticated;
revoke all on sequence public.admin_page_deliveries_id_seq from anon, authenticated;
revoke all on function public.admin_staff_audit() from public, anon, authenticated;
revoke all on function public.admin_account_age_days(uuid) from public, anon, authenticated;

-- aura_admin: moderation tables, read-only and column-scoped (no reporter identity, no account behind a pseudonym).
grant select (id, source, auto_signal, reporter_member_id, reason, lane, involves_minor, pages, target_kind, room_id,
              target_member_id, target_gesture_id, target_user_id, target_ref, note, status, sla_due_at, created_at,
              resolved_at, resolved_by, evidence_hold_id)
  on public.reports to aura_admin;
grant select (id, kind, language_pool, quadrant, tz_region, seed_mood_id, capacity, status, created_at, opened_at,
              joins_close_at, memory_at, purge_at)
  on public.rooms to aura_admin;
grant select (member_id, room_id, pseudonym, mood_at_join, joined_at, left_at) on public.room_members to aura_admin;
grant select (id, room_id, from_member_id, to_member_id, type, target, dropped, created_at) on public.room_gestures to aura_admin;
grant select on public.evidence_holds, public.sanctions, public.strikes, public.safety_config, public.matching_config
  to aura_admin;
-- The audit log: append and read only (REQ-ADM-08: UPDATE / DELETE fail for aura_admin too).
grant select, insert on public.moderation_actions to aura_admin;
grant usage on sequence public.moderation_actions_id_seq to aura_admin;
-- Kill switches (feature flags): flip, never create or delete.
grant select, update (enabled) on public.feature_flags to aura_admin;
-- "Under 18" flag (a boolean, never the DOB) and account age.
grant execute on function public.user_is_minor(uuid) to aura_admin;
grant execute on function public.admin_account_age_days(uuid) to aura_admin;

-- aura_admin: the console's own tables. Pages are raised and delivered by the pager (service role); staff acknowledge.
grant select on public.admin_staff to aura_admin;
grant select, insert, update on public.admin_grievances to aura_admin;
grant select, insert, update on public.admin_legal_orders to aura_admin;
grant select, update on public.admin_pages to aura_admin;
grant select on public.admin_page_deliveries to aura_admin;
grant select, insert, update on public.admin_mandatory_checklists to aura_admin;
