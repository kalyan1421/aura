-- Admin console v0 completion (PRD 19-admin-console REQ-ADM-03 / 07 / 11 and the v0 body items; 06c F9). Server:
-- server/aura-api/src/admin and src/safety; console: apps/admin; runbook: docs/setup/admin-console.md.
--
--  1. Least privilege (REQ-ADM-03). Console moderation actions now run as `aura_admin` (NestJS `SET LOCAL ROLE`), which
--     still holds no write grant on reports, sanctions, strikes or evidence (13_admin.test.sql keeps asserting that).
--     Each state change goes through one narrow SECURITY DEFINER function that checks its own preconditions:
--     `admin_report_for_action` (lock), `admin_add_strike`, `admin_add_sanction`, `admin_resolve_report`,
--     `admin_extend_evidence_hold` (only ever extends), `admin_lift_sanction`, `admin_record_mandatory_report`, and
--     `admin_hide_account_from_rooms` — the admin-triggered room broadcast (`member_left` through realtime.send), which
--     needs the account behind a membership and the realtime schema, neither of which aura_admin can reach.
--     `admin_audit_anchor()` lets the audit-chain check run as aura_admin without a grant on the anchor table.
--  2. Strike automation (REQ-ADM-07). `strikes_never_crisis`: no strike is ever recorded for a report whose item is
--     crisis-flagged — a crisis report itself, or an item (same member / gesture, or the same person in the same room)
--     with a crisis report that was not dismissed — whoever inserts it. The ladder (4th active strike → permanent
--     social ban with a 180-day evidence hold; strikes stop counting 90 days after issue) lives in ModerationService.
--  3. Staff editor (PRD 19 Roles: "staff roles" are Owner business). `admin_staff_list / add / update`, Owner-checked
--     in the database too, never leaving the console without an enabled Owner; the allowlist audit trigger now records
--     the staff member who made the change (`aura.admin_actor`, set by those functions) instead of `db:postgres`.
--  4. Deletion cases (REQ-ADM-11). `admin_deletion_cases` + functions. The requester proves control of the ACCOUNT's
--     mailbox: a one-time link goes to the address on the account (never to the address the request came from), is
--     stored only as a SHA-256, expires, is single-use and dies if the account's email changes. Only the public
--     confirmation route (service role) can mark a case verified — aura_admin cannot — and only a verified case can
--     start the deletion, which is the app's own: an `account_deletions` row (7-day grace, or immediate) and the hourly
--     purge (src/account/account-purge.ts). Evidence holds about the account survive until `hold_until`
--     (LEGAL_HOLD_TABLES). The table stores no email: the account link is an FK that the purge nulls, and a trigger then
--     marks the case completed (with how many records the legal hold keeps) and audits it.
--  5. Kill switches for v0 (PRD 19 "Single operator": reduced mode; 06c F9 "hold-all"): two flags, off by default.
--
-- Console refusals raise SQLSTATE AR040 with a machine code as the message (src/admin/admin-errors.ts maps them).
-- Every function here: SECURITY DEFINER, `search_path = ''`, no EXECUTE for public / anon / authenticated /
-- service_role; aura_admin gets EXECUTE only where listed at the end.

-- =============================================================================================== 1. moderation actions
-- Is this report's item crisis-flagged? The report is a crisis report (lane crisis / reason 1), or another crisis
-- report that was not dismissed (open, or actioned = confirmed) is about the same item, or about the same person in the
-- same room. "Self-harm expression is never a strike" (PRD 19); a dismissed crisis report no longer protects the item.
create function public.admin_item_crisis_flagged(p_report uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select r.lane = 'crisis' or r.reason = 1
        or exists (
             select 1 from public.reports c
              where c.id <> r.id and c.reason = 1 and c.status in ('open', 'actioned')
                and (c.target_ref = r.target_ref
                     or (r.target_user_id is not null and c.target_user_id = r.target_user_id and c.room_id = r.room_id)))
      from public.reports r where r.id = p_report), false)
$$;

-- The report a console action is about, locked for the rest of the transaction.
create function public.admin_report_for_action(p_report uuid)
returns table (report_id uuid, status text, lane text, reason smallint, target_user_id uuid, evidence_hold_id uuid,
               crisis_flagged boolean)
language sql volatile security definer set search_path = '' as $$
  select r.id, r.status, r.lane, r.reason, r.target_user_id, r.evidence_hold_id, public.admin_item_crisis_flagged(r.id)
    from public.reports r where r.id = p_report
     for update
$$;

-- One strike on the report's subject (expires after safety_config.strike_ttl_days, 90) → the new active-strike count.
create function public.admin_add_strike(p_report uuid, p_reason_code text, p_actor text)
returns table (strike_id uuid, active_strikes int)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  r   record;
  ttl int;
  sid uuid;
begin
  if p_reason_code is null or p_reason_code !~ '^[a-z0-9_]{1,40}$' or p_actor is null or char_length(p_actor) not between 1 and 120 then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select x.id, x.status, x.target_user_id into r from public.reports x where x.id = p_report for update;
  if not found then raise exception using errcode = 'AR040', message = 'report_not_found'; end if;
  if r.status <> 'open' then raise exception using errcode = 'AR040', message = 'report_closed'; end if;
  if r.target_user_id is null then raise exception using errcode = 'AR040', message = 'no_subject'; end if;
  select c.strike_ttl_days into ttl from public.safety_config c where c.id;
  -- strikes_never_crisis refuses a crisis-flagged item here, whoever calls.
  insert into public.strikes (user_id, reason_code, report_id, created_by, expires_at)
  values (r.target_user_id, p_reason_code, r.id, p_actor, now() + make_interval(days => coalesce(ttl, 90)))
  returning id into sid;
  return query
    select sid, (select count(*)::int from public.strikes s
                  where s.user_id = r.target_user_id and s.revoked_at is null and s.expires_at > now());
end $$;

-- One sanction on the report's subject. Kinds and durations are the console's (gesture shadow-mutes are automatic only).
create function public.admin_add_sanction(p_report uuid, p_kind text, p_reason_code text, p_hours int, p_actor text,
                                          p_source text default 'moderator')
returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  r   record;
  sid uuid;
begin
  if p_reason_code is null or p_reason_code !~ '^[a-z0-9_]{1,40}$' or p_actor is null or char_length(p_actor) not between 1 and 120
     or p_source is null or p_source not in ('moderator', 'auto')
     or p_kind is null or p_kind not in ('warning', 'shadow_mute', 'room_suspension', 'rooms_pause', 'social_ban', 'account_ban') then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  if (p_kind = 'shadow_mute' and (p_hours is null or p_hours not between 1 and 720))
     or (p_kind = 'room_suspension' and (p_hours is null or p_hours not in (24, 168)))
     or (p_kind in ('warning', 'rooms_pause', 'social_ban', 'account_ban') and p_hours is not null) then
    raise exception using errcode = 'AR040', message = 'invalid_duration';
  end if;
  select x.id, x.status, x.target_user_id into r from public.reports x where x.id = p_report for update;
  if not found then raise exception using errcode = 'AR040', message = 'report_not_found'; end if;
  if r.status <> 'open' then raise exception using errcode = 'AR040', message = 'report_closed'; end if;
  if r.target_user_id is null then raise exception using errcode = 'AR040', message = 'no_subject'; end if;
  insert into public.sanctions (user_id, kind, reason_code, source, report_id, ends_at, created_by)
  values (r.target_user_id, p_kind, p_reason_code, p_source, r.id,
          case when p_hours is null then null else now() + make_interval(hours => p_hours) end, p_actor)
  returning id into sid;
  return sid;
end $$;

-- Close an open report (actioned / dismissed). False when it was not open.
create function public.admin_resolve_report(p_report uuid, p_status text, p_actor text) returns boolean
language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_status is null or p_status not in ('actioned', 'dismissed') or p_actor is null or char_length(p_actor) not between 1 and 120 then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  update public.reports set status = p_status, resolved_at = now(), resolved_by = p_actor where id = p_report and status = 'open';
  return found;
end $$;

-- Keep evidence at least `p_days` from now (never shortens), optionally marking it for a mandatory report.
create function public.admin_extend_evidence_hold(p_hold uuid, p_days int, p_mandatory boolean default false) returns boolean
language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_days is null or p_days not between 1 and 3650 then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  update public.evidence_holds
     set hold_until = greatest(hold_until, now() + make_interval(days => p_days)),
         mandatory_report_required = mandatory_report_required or coalesce(p_mandatory, false)
   where id = p_hold;
  return found;
end $$;

-- Lift an active sanction early; the row (who it was about) comes back for the audit HMAC.
create function public.admin_lift_sanction(p_sanction uuid)
returns table (user_id uuid, kind text, report_id uuid)
language sql volatile security definer set search_path = '' as $$
  update public.sanctions s set lifted_at = now() where s.id = p_sanction and s.lifted_at is null
  returning s.user_id, s.kind, s.report_id
$$;

-- Minors & grooming SOP step 3: an external reference (where + ref) or an Owner-recorded legal reason, exactly one.
create function public.admin_record_mandatory_report(p_hold uuid, p_reported_to text, p_report_ref text, p_legal_reason text)
returns boolean
language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_legal_reason is not null then
    if p_report_ref is not null or p_reported_to is not null or char_length(p_legal_reason) not between 10 and 2000 then
      raise exception using errcode = 'AR040', message = 'invalid_input';
    end if;
    update public.evidence_holds set legal_reason = p_legal_reason where id = p_hold;
  else
    if p_report_ref is null or p_reported_to is null or char_length(p_reported_to) not between 2 and 200
       or char_length(p_report_ref) not between 1 and 200 then
      raise exception using errcode = 'AR040', message = 'invalid_input';
    end if;
    update public.evidence_holds set reported_to = p_reported_to, report_ref = p_report_ref where id = p_hold;
  end if;
  return found;
end $$;

-- Admin-triggered room broadcast: once a sanction takes an account's room access away, every live room it sits in gets
-- `member_left` with fresh counts — the same payload as Broadcast.memberLeft (src/rooms/broadcast.ts, contracts/api/
-- v1-rooms.md §3): { memberId, counts: { hereNow, today }, at }. Only for an account that IS hidden now (an active
-- room-access sanction or a pending deletion), so the console role can't make anyone vanish on its own. Returns how
-- many rooms were told.
create function public.admin_hide_account_from_rooms(p_user uuid, p_at timestamptz default now()) returns int
language plpgsql volatile security definer set search_path = '' as $$
declare
  m        record;
  live_s   int;
  here_now int;
  today    int;
  n        int := 0;
begin
  if p_user is null then return 0; end if;
  if not (exists (select 1 from public.account_deletions d where d.user_id = p_user)
          or exists (select 1 from public.sanctions s
                      where s.user_id = p_user and s.kind in ('room_suspension', 'rooms_pause', 'social_ban', 'account_ban')
                        and s.lifted_at is null and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()))) then
    return 0;
  end if;
  select c.live_window_s into live_s from public.matching_config c where c.id;
  live_s := coalesce(live_s, 120);
  for m in
    select x.member_id, x.room_id
      from public.room_members x join public.rooms r on r.id = x.room_id
     where x.user_id = p_user and x.left_at is null and r.memory_at > now()
  loop
    select coalesce(sum(case when y.left_at is null and y.last_seen_at > now() - make_interval(secs => live_s)
                              and not (exists (select 1 from public.account_deletions hd where hd.user_id = y.user_id)
                                       or exists (select 1 from public.sanctions hs
                                                   where hs.user_id = y.user_id
                                                     and hs.kind in ('room_suspension', 'rooms_pause', 'social_ban', 'account_ban')
                                                     and hs.lifted_at is null and hs.starts_at <= now()
                                                     and (hs.ends_at is null or hs.ends_at > now())))
                             then 1 else 0 end), 0)::int,
           count(*)::int
      into here_now, today
      from public.room_members y where y.room_id = m.room_id;
    perform realtime.send(
      jsonb_build_object(
        'memberId', m.member_id,
        'counts', jsonb_build_object('hereNow', here_now, 'today', today),
        'at', to_char(coalesce(p_at, now()) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')),
      'member_left', 'room:' || m.room_id::text, true);
    n := n + 1;
  end loop;
  return n;
end $$;

-- Where the retention job cut the audit chain (moderation_audit_anchor), for verifyAuditChain as aura_admin.
create function public.admin_audit_anchor() returns table (last_pruned_id bigint, last_pruned_hash text)
language sql stable security definer set search_path = '' as $$
  select a.last_pruned_id, a.last_pruned_hash from public.moderation_audit_anchor a where a.id
$$;

-- =============================================================================================== 2. strikes never crisis
create function public.strikes_never_crisis() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.report_id is not null and public.admin_item_crisis_flagged(new.report_id) then
    raise exception using errcode = 'AR040', message = 'crisis_never_strikes';
  end if;
  return new;
end $$;
create trigger strikes_never_crisis before insert on public.strikes
  for each row execute function public.strikes_never_crisis();

-- =============================================================================================== 3. staff editor
-- The allowlist audit trigger (migration 13) now names the staff member when the console made the change: the
-- functions below set the transaction-local `aura.admin_actor` to `staff:<id>` around their write. Anything else (SQL,
-- Studio, an auth-user deletion cascade) is still recorded as `db:<session user>`.
create or replace function public.admin_staff_audit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  r   record;
  act text;
  who text;
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
  who := nullif(current_setting('aura.admin_actor', true), '');
  if who is null or who !~ '^staff:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    who := left('db:' || session_user, 120);
  end if;
  insert into public.moderation_actions (actor, action, reason_code, detail)
  values (who, act, 'staff_allowlist',
          jsonb_build_object('staffId', r.staff_id, 'role', r.role, 'disabled', r.disabled_at is not null));
  return null;
end $$;

-- `staff:<uuid>` of an enabled Owner → that id; anything else → AR040 forbidden_role (defence in depth: the NestJS
-- route is Owner-only already).
create function public.admin_assert_owner(p_actor text) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare
  sid uuid;
begin
  if p_actor is null or p_actor !~ '^staff:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'AR040', message = 'forbidden_role';
  end if;
  sid := substr(p_actor, 7)::uuid;
  if not exists (select 1 from public.admin_staff s where s.staff_id = sid and s.role = 'owner' and s.disabled_at is null) then
    raise exception using errcode = 'AR040', message = 'forbidden_role';
  end if;
  return sid;
end $$;

-- The staff list for the Owner's editor: staff accounts only (never app accounts), with their sign-in state.
create function public.admin_staff_list()
returns table (staff_id uuid, role text, display_name text, disabled boolean, created_at timestamptz, updated_at timestamptz,
               email text, last_sign_in_at timestamptz, has_totp boolean, google_domains text[], other_providers text[])
language sql stable security definer set search_path = '' as $$
  select s.staff_id, s.role, s.display_name, s.disabled_at is not null, s.created_at, s.updated_at,
         u.email::text, u.last_sign_in_at,
         exists (select 1 from auth.mfa_factors f
                  where f.user_id = s.staff_id and f.factor_type = 'totp' and f.status = 'verified'),
         coalesce((select array_agg(distinct lower(i.identity_data -> 'custom_claims' ->> 'hd'))
                     from auth.identities i
                    where i.user_id = s.staff_id and i.provider = 'google'
                      and i.identity_data -> 'custom_claims' ->> 'hd' is not null), '{}'::text[]),
         coalesce((select array_agg(distinct i.provider) from auth.identities i
                    where i.user_id = s.staff_id and i.provider not in ('google', 'email')), '{}'::text[])
    from public.admin_staff s
    left join auth.users u on u.id = s.staff_id
   order by s.disabled_at is not null, s.role, s.created_at
$$;

-- Add an existing Supabase Auth user (signed in once, e.g. with Google Workspace) as staff. Never an app account.
create function public.admin_staff_add(p_actor text, p_email text, p_role text, p_display_name text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  n   int;
  uid uuid;
begin
  perform public.admin_assert_owner(p_actor);
  if p_role is null or p_role not in ('owner', 'moderator', 'analyst')
     or p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 60
     or p_email is null or char_length(btrim(p_email)) not between 3 and 254 or btrim(p_email) !~ '^[^@\s]+@[^@\s]+$' then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select count(*)::int, (array_agg(u.id))[1] into n, uid
    from auth.users u
   where lower(u.email) = lower(btrim(p_email)) and u.deleted_at is null and not coalesce(u.is_anonymous, false);
  if n = 0 then raise exception using errcode = 'AR040', message = 'no_account'; end if;
  if n > 1 then raise exception using errcode = 'AR040', message = 'ambiguous_account'; end if;
  if exists (select 1 from public.profiles p where p.user_id = uid) then
    raise exception using errcode = 'AR040', message = 'app_account';
  end if;
  if exists (select 1 from public.admin_staff s where s.staff_id = uid) then
    raise exception using errcode = 'AR040', message = 'already_staff';
  end if;
  perform set_config('aura.admin_actor', p_actor, true);
  insert into public.admin_staff (staff_id, role, display_name) values (uid, p_role, btrim(p_display_name));
  perform set_config('aura.admin_actor', '', true);
  return uid;
end $$;

-- Change a staff member's role, display name or disabled state. An Owner can't demote or disable themselves, and the
-- console never ends up without an enabled Owner. No-op when nothing changes (no audit row).
create function public.admin_staff_update(p_actor text, p_staff uuid, p_role text, p_display_name text, p_disabled boolean)
returns boolean
language plpgsql volatile security definer set search_path = '' as $$
declare
  me    uuid;
  cur   record;
  role_ text;
  name_ text;
  dis_  timestamptz;
begin
  me := public.admin_assert_owner(p_actor);
  if (p_role is not null and p_role not in ('owner', 'moderator', 'analyst'))
     or (p_display_name is not null and char_length(btrim(p_display_name)) not between 1 and 60) then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select s.staff_id, s.role, s.display_name, s.disabled_at into cur from public.admin_staff s where s.staff_id = p_staff for update;
  if not found then raise exception using errcode = 'AR040', message = 'staff_not_found'; end if;
  if p_staff = me and ((p_role is not null and p_role <> 'owner') or coalesce(p_disabled, false)) then
    raise exception using errcode = 'AR040', message = 'cannot_change_self';
  end if;
  role_ := coalesce(p_role, cur.role);
  name_ := coalesce(btrim(p_display_name), cur.display_name);
  dis_ := case when p_disabled is null then cur.disabled_at when p_disabled then coalesce(cur.disabled_at, now()) else null end;
  if role_ = cur.role and name_ = cur.display_name and dis_ is not distinct from cur.disabled_at then
    return false;
  end if;
  perform set_config('aura.admin_actor', p_actor, true);
  update public.admin_staff s set role = role_, display_name = name_, disabled_at = dis_, updated_at = now()
   where s.staff_id = p_staff;
  perform set_config('aura.admin_actor', '', true);
  if not exists (select 1 from public.admin_staff s where s.role = 'owner' and s.disabled_at is null) then
    raise exception using errcode = 'AR040', message = 'last_owner';
  end if;
  return true;
end $$;

-- =============================================================================================== 4. deletion cases
-- Ticket ids: Crockford base32 (no I, L, O, U), 8 characters, minted by NestJS (like grievances and legal orders).
create table public.admin_deletion_cases (
  id                     uuid primary key default gen_random_uuid(),
  ticket                 text not null unique check (ticket ~ '^DEL-[0-9A-HJKMNP-TV-Z]{8}$'),
  channel                text not null check (channel in ('email', 'grievance', 'post', 'other')),
  grievance_id           uuid references public.admin_grievances(id) on delete set null,
  received_at            timestamptz not null,                   -- when the request reached AKVega
  status                 text not null check (status in ('awaiting_verification', 'verified', 'declined', 'deletion_scheduled',
                                                         'completed', 'closed', 'no_account', 'staff_account')),
  -- The matched app account. Never shown (NestJS turns it into the audit HMAC); nulled by the account purge.
  account_id             uuid references auth.users(id) on delete set null,
  token_hash             text unique check (token_hash is null or token_hash ~ '^[0-9a-f]{64}$'),  -- SHA-256 of the link token
  token_expires_at       timestamptz,
  email_hash             text check (email_hash is null or email_hash ~ '^[0-9a-f]{64}$'),  -- the address the link went to
  verification_sent_at   timestamptz,
  verification_attempts  int not null default 0 check (verification_attempts between 0 and 100),
  verified_at            timestamptz,
  declined_at            timestamptz,
  deletion_mode          text check (deletion_mode is null or deletion_mode in ('grace', 'immediate')),
  deletion_reason        text check (deletion_reason is null or deletion_reason ~ '^[a-z0-9_]{1,40}$'),
  deletion_requested_at  timestamptz,
  deletion_requested_by  text check (deletion_requested_by is null or char_length(deletion_requested_by) between 1 and 120),
  deletion_scheduled_for timestamptz,
  completed_at           timestamptz,
  held_records           int check (held_records is null or held_records >= 0),  -- evidence rows kept at completion
  held_until             timestamptz,
  closed_at              timestamptz,
  closed_by              text check (closed_by is null or char_length(closed_by) between 1 and 120),
  close_outcome          text check (close_outcome is null or close_outcome in ('withdrawn', 'unverified', 'duplicate',
                                     'declined_by_holder', 'restored_by_holder', 'no_account', 'staff_account',
                                     'account_gone', 'other')),
  created_by             text not null check (char_length(created_by) between 1 and 120),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint admin_deletion_cases_received check (received_at <= created_at + interval '5 minutes'),
  constraint admin_deletion_cases_token check ((token_hash is null) = (token_expires_at is null)),
  constraint admin_deletion_cases_awaiting check (status <> 'awaiting_verification' or account_id is not null),
  constraint admin_deletion_cases_verified check (status <> 'verified' or verified_at is not null),
  constraint admin_deletion_cases_scheduled check (status <> 'deletion_scheduled'
                                                   or (deletion_requested_at is not null and deletion_mode is not null
                                                       and deletion_scheduled_for is not null)),
  constraint admin_deletion_cases_completed check ((status = 'completed') = (completed_at is not null)),
  constraint admin_deletion_cases_closed check ((status in ('closed', 'no_account', 'staff_account')) = (closed_at is not null))
);
create index admin_deletion_cases_status_idx on public.admin_deletion_cases (status, created_at desc);
create index admin_deletion_cases_account_idx on public.admin_deletion_cases (account_id) where account_id is not null;
-- One open case per account (admin_deletion_case_open also says so first, with a clear code).
create unique index admin_deletion_cases_one_open_idx on public.admin_deletion_cases (account_id)
  where status in ('awaiting_verification', 'verified', 'deletion_scheduled');
comment on table public.admin_deletion_cases is
  'Emailed / grievance account-deletion requests (PRD 19 REQ-ADM-11): verified by a one-time link to the account''s own '
  'email, then the app''s deletion. Owner only, through admin_deletion_case_* functions. Stores no email.';

-- Open a case for the account that signs in with `p_email`. Matched → awaiting_verification (the token hash and expiry
-- are stored; `send_to` is the address ON THE ACCOUNT, where NestJS sends the link). No app account → closed as
-- no_account; a staff account → closed as staff_account (nothing is sent either way). One open case per account.
create function public.admin_deletion_case_open(p_ticket text, p_email text, p_channel text, p_received_at timestamptz,
                                                p_grievance uuid, p_token_hash text, p_token_expires_at timestamptz,
                                                p_actor text)
returns table (case_id uuid, status text, account_id uuid, send_to text)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  n    int;
  uid  uuid;
  mail text;
  st   text;
  cid  uuid;
begin
  if p_email is null or char_length(btrim(p_email)) not between 3 and 254 or btrim(p_email) !~ '^[^@\s]+@[^@\s]+$'
     or p_channel is null or p_channel not in ('email', 'grievance', 'post', 'other')
     or p_received_at is null or p_received_at > now() + interval '5 minutes'
     or p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
     or p_token_expires_at is null or p_token_expires_at <= now() or p_token_expires_at > now() + interval '14 days'
     or p_actor is null or char_length(p_actor) not between 1 and 120 then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select count(*)::int, (array_agg(u.id))[1], (array_agg(u.email::text))[1] into n, uid, mail
    from auth.users u
   where lower(u.email) = lower(btrim(p_email)) and u.deleted_at is null
     and not coalesce(u.is_anonymous, false) and not coalesce(u.is_sso_user, false);
  if n = 0 then
    st := 'no_account';
  elsif n > 1 then
    raise exception using errcode = 'AR040', message = 'ambiguous_account';
  elsif exists (select 1 from public.admin_staff s where s.staff_id = uid) then
    st := 'staff_account';
  elsif exists (select 1 from public.admin_deletion_cases d
                 where d.account_id = uid and d.status in ('awaiting_verification', 'verified', 'deletion_scheduled')) then
    raise exception using errcode = 'AR040', message = 'open_case_exists';
  else
    st := 'awaiting_verification';
  end if;
  if st <> 'awaiting_verification' then
    uid := null;
    mail := null;
  end if;
  insert into public.admin_deletion_cases (ticket, channel, grievance_id, received_at, status, account_id, token_hash,
                                           token_expires_at, email_hash, closed_at, close_outcome, created_by)
  values (p_ticket, p_channel, p_grievance, p_received_at, st, uid,
          case when uid is not null then p_token_hash end,
          case when uid is not null then p_token_expires_at end,
          case when uid is not null then encode(sha256(convert_to(lower(mail), 'UTF8')), 'hex') end,
          case when uid is null then now() end,
          case when uid is null then st end,
          p_actor)
  returning id into cid;
  return query select cid, st, uid, mail;
end $$;

-- After NestJS tried to send the link: count the attempt, and remember when one went out.
create function public.admin_deletion_case_mark_sent(p_case uuid, p_ok boolean) returns void
language sql volatile security definer set search_path = '' as $$
  update public.admin_deletion_cases
     set verification_attempts = least(verification_attempts + 1, 100),
         verification_sent_at = case when p_ok then now() else verification_sent_at end,
         updated_at = now()
   where id = p_case and status = 'awaiting_verification'
$$;

-- A fresh link for a case still waiting (the previous one stops working); again to the address on the account.
create function public.admin_deletion_case_reissue(p_case uuid, p_token_hash text, p_token_expires_at timestamptz)
returns table (account_id uuid, send_to text)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  c    record;
  mail text;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
     or p_token_expires_at is null or p_token_expires_at <= now() or p_token_expires_at > now() + interval '14 days' then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select d.id, d.status, d.account_id into c from public.admin_deletion_cases d where d.id = p_case for update;
  if not found then raise exception using errcode = 'AR040', message = 'case_not_found'; end if;
  if c.status <> 'awaiting_verification' then raise exception using errcode = 'AR040', message = 'case_not_awaiting'; end if;
  select u.email::text into mail from auth.users u where u.id = c.account_id and u.deleted_at is null;
  if mail is null then raise exception using errcode = 'AR040', message = 'no_account'; end if;
  update public.admin_deletion_cases
     set token_hash = p_token_hash, token_expires_at = p_token_expires_at,
         email_hash = encode(sha256(convert_to(lower(mail), 'UTF8')), 'hex'), updated_at = now()
   where id = p_case;
  return query select c.account_id, mail;
end $$;

-- The public confirmation page (service role only): what a link token points at, without changing anything.
create function public.deletion_case_lookup(p_token_hash text) returns table (case_id uuid, ticket text, state text)
language sql stable security definer set search_path = '' as $$
  select d.id, d.ticket, case when d.token_expires_at <= now() then 'expired' else 'valid' end
    from public.admin_deletion_cases d
   where p_token_hash ~ '^[0-9a-f]{64}$' and d.token_hash = p_token_hash and d.status = 'awaiting_verification'
$$;

-- The public confirmation (service role only — never aura_admin, so the console can't verify on anyone's behalf):
-- the holder of a live link confirms (→ verified) or declines ("this wasn't me" → declined). Single use: the token is
-- cleared. Refused ('invalid') if the account's email changed since the link was sent or the account is gone.
create function public.deletion_case_confirm(p_token_hash text, p_decline boolean)
returns table (case_id uuid, ticket text, outcome text, account_id uuid)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  c   record;
  cur text;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    return query select null::uuid, null::text, 'invalid'::text, null::uuid;
    return;
  end if;
  select d.id, d.ticket, d.status, d.account_id, d.token_expires_at, d.email_hash into c
    from public.admin_deletion_cases d where d.token_hash = p_token_hash for update;
  if not found or c.status <> 'awaiting_verification' or c.account_id is null then
    return query select null::uuid, null::text, 'invalid'::text, null::uuid;
    return;
  end if;
  if c.token_expires_at <= now() then
    return query select c.id, c.ticket, 'expired'::text, null::uuid;
    return;
  end if;
  select encode(sha256(convert_to(lower(u.email), 'UTF8')), 'hex') into cur
    from auth.users u where u.id = c.account_id and u.deleted_at is null;
  if cur is null or cur <> c.email_hash then
    return query select c.id, c.ticket, 'invalid'::text, null::uuid;
    return;
  end if;
  if coalesce(p_decline, false) then
    update public.admin_deletion_cases
       set status = 'declined', declined_at = now(), token_hash = null, token_expires_at = null, updated_at = now()
     where id = c.id;
    return query select c.id, c.ticket, 'declined'::text, c.account_id;
  else
    update public.admin_deletion_cases
       set status = 'verified', verified_at = now(), token_hash = null, token_expires_at = null, updated_at = now()
     where id = c.id;
    return query select c.id, c.ticket, 'verified'::text, c.account_id;
  end if;
end $$;

-- Start the deletion for a VERIFIED case — the app's own deletion (contracts/api/v1.md "Account deletion"): an
-- account_deletions row (deactivated at once; `p_scheduled_for` = the 7-day grace NestJS computes, or now when
-- immediate), the device tokens go (no pushes), and the hourly purge does the rest. Same per-user advisory lock as
-- the app's route, so it serialises with "Keep my account" and the purge. An existing schedule is kept (a grace
-- request never moves it); immediate only brings it forward.
create function public.admin_deletion_case_schedule(p_case uuid, p_immediate boolean, p_scheduled_for timestamptz,
                                                    p_reason text, p_actor text)
returns table (account_id uuid, scheduled_for timestamptz)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  c     record;
  sched timestamptz;
  due   timestamptz;
begin
  if p_actor is null or char_length(p_actor) not between 1 and 120
     or (p_reason is not null and p_reason !~ '^[a-z0-9_]{1,40}$')
     or (coalesce(p_immediate, false) and p_reason is null) then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select d.id, d.status, d.account_id into c from public.admin_deletion_cases d where d.id = p_case for update;
  if not found then raise exception using errcode = 'AR040', message = 'case_not_found'; end if;
  if c.status <> 'verified' then raise exception using errcode = 'AR040', message = 'case_not_verified'; end if;
  if c.account_id is null then raise exception using errcode = 'AR040', message = 'no_account'; end if;
  if exists (select 1 from public.admin_staff s where s.staff_id = c.account_id) then
    raise exception using errcode = 'AR040', message = 'staff_account';
  end if;
  if coalesce(p_immediate, false) then
    sched := now();
  else
    if p_scheduled_for is null or p_scheduled_for <= now() or p_scheduled_for > now() + interval '30 days' then
      raise exception using errcode = 'AR040', message = 'invalid_input';
    end if;
    sched := p_scheduled_for;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('aura:user:' || c.account_id::text, 0));
  insert into public.account_deletions as a (user_id, requested_at, scheduled_for)
  values (c.account_id, now(), sched)
  on conflict (user_id) do update set scheduled_for = least(a.scheduled_for, excluded.scheduled_for)
   where coalesce(p_immediate, false);
  delete from public.device_tokens t where t.user_id = c.account_id;
  select a.scheduled_for into due from public.account_deletions a where a.user_id = c.account_id;
  update public.admin_deletion_cases
     set status = 'deletion_scheduled',
         deletion_mode = case when coalesce(p_immediate, false) then 'immediate' else 'grace' end,
         deletion_reason = p_reason, deletion_requested_at = now(), deletion_requested_by = p_actor,
         deletion_scheduled_for = due, updated_at = now()
   where id = p_case;
  return query select c.account_id, due;
end $$;

-- Close a case without (further) deletion: while it waits or was verified / declined, or after the account holder kept
-- the account ("Keep my account" during the grace period cancelled the scheduled deletion).
create function public.admin_deletion_case_close(p_case uuid, p_outcome text, p_actor text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare
  c record;
begin
  if p_outcome is null or p_outcome not in ('withdrawn', 'unverified', 'duplicate', 'declined_by_holder', 'restored_by_holder', 'other')
     or p_actor is null or char_length(p_actor) not between 1 and 120 then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select d.id, d.status, d.account_id into c from public.admin_deletion_cases d where d.id = p_case for update;
  if not found then raise exception using errcode = 'AR040', message = 'case_not_found'; end if;
  if not (c.status in ('awaiting_verification', 'verified', 'declined')
          or (c.status = 'deletion_scheduled'
              and not exists (select 1 from public.account_deletions a where a.user_id = c.account_id))) then
    raise exception using errcode = 'AR040', message = 'case_not_closable';
  end if;
  update public.admin_deletion_cases
     set status = 'closed', closed_at = now(), closed_by = p_actor, close_outcome = p_outcome,
         token_hash = null, token_expires_at = null, email_hash = null, updated_at = now()
   where id = p_case;
end $$;

-- The console's view of cases: never the token, the email hash or the email itself — a masked address while the
-- account exists, whether its deletion is still pending, and how many evidence rows about it are under legal hold.
create function public.admin_deletion_cases_list(p_filter text default 'open', p_limit int default 200, p_case uuid default null)
returns table (id uuid, ticket text, channel text, grievance_id uuid, grievance_ticket text, received_at timestamptz,
               status text, account_id uuid, account_email_masked text, token_expires_at timestamptz,
               verification_sent_at timestamptz, verification_attempts int, verified_at timestamptz,
               declined_at timestamptz, deletion_mode text, deletion_reason text, deletion_requested_at timestamptz,
               deletion_requested_by text, deletion_scheduled_for timestamptz, deletion_pending boolean,
               completed_at timestamptz, held_records int, held_until timestamptz, closed_at timestamptz,
               closed_by text, close_outcome text, created_by text, created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select d.id, d.ticket, d.channel, d.grievance_id, g.ticket, d.received_at, d.status, d.account_id,
         case when u.email is null then null else regexp_replace(u.email::text, '^(.)[^@]*@', '\1•••@') end,
         d.token_expires_at, d.verification_sent_at, d.verification_attempts, d.verified_at, d.declined_at,
         d.deletion_mode, d.deletion_reason, d.deletion_requested_at, d.deletion_requested_by, d.deletion_scheduled_for,
         exists (select 1 from public.account_deletions a where a.user_id = d.account_id),
         d.completed_at,
         case when d.account_id is null then d.held_records
              else (select count(*)::int from public.evidence_holds e
                     where d.account_id = any(e.account_ids) and e.hold_until > now()) end,
         case when d.account_id is null then d.held_until
              else (select max(e.hold_until) from public.evidence_holds e
                     where d.account_id = any(e.account_ids) and e.hold_until > now()) end,
         d.closed_at, d.closed_by, d.close_outcome, d.created_by, d.created_at, d.updated_at
    from public.admin_deletion_cases d
    left join public.admin_grievances g on g.id = d.grievance_id
    left join auth.users u on u.id = d.account_id and u.deleted_at is null
   where (p_case is null or d.id = p_case)
     and (p_case is not null
          or coalesce(p_filter, 'open') = 'all'
          or (coalesce(p_filter, 'open') = 'open' and d.status in ('awaiting_verification', 'verified', 'declined', 'deletion_scheduled'))
          or (p_filter = 'closed' and d.status in ('completed', 'closed', 'no_account', 'staff_account')))
   order by d.created_at desc
   limit least(greatest(coalesce(p_limit, 200), 1), 500)
$$;

-- The account purge deletes auth.users → the FK nulls account_id → this marks the case completed (a scheduled
-- deletion) or closed (the account went some other way), records what the legal hold keeps, drops the token and email
-- hash, and audits it. Runs inside the purge's own transaction.
create function public.admin_deletion_cases_account_gone() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  held  int;
  until timestamptz;
  act   text;
begin
  if old.account_id is not null and new.account_id is null then
    select count(*)::int, max(e.hold_until) into held, until
      from public.evidence_holds e where old.account_id = any(e.account_ids) and e.hold_until > now();
    new.held_records := held;
    new.held_until := until;
    new.token_hash := null;
    new.token_expires_at := null;
    new.email_hash := null;
    if old.status = 'deletion_scheduled' then
      new.status := 'completed';
      new.completed_at := now();
      act := 'deletion_case_completed';
    elsif old.status in ('awaiting_verification', 'verified', 'declined') then
      new.status := 'closed';
      new.closed_at := now();
      new.closed_by := 'system:account_purge';
      new.close_outcome := 'account_gone';
      act := 'deletion_case_closed';
    end if;
    new.updated_at := now();
    if act is not null then
      insert into public.moderation_actions (actor, action, reason_code, detail)
      values ('system:account_purge', act, 'account_purged',
              jsonb_build_object('caseId', new.id, 'ticket', new.ticket, 'heldRecords', held));
    end if;
  end if;
  return new;
end $$;
create trigger admin_deletion_cases_account_gone before update of account_id on public.admin_deletion_cases
  for each row execute function public.admin_deletion_cases_account_gone();

alter table public.admin_deletion_cases enable row level security;
-- Server-only: no policies, no client privileges, and no direct grant for aura_admin (functions only).
revoke all on table public.admin_deletion_cases from anon, authenticated;

-- =============================================================================================== 5. kill switches
-- Off by default. Reduced mode (PRD 19 "When AK will be unreachable"): reflections paused and sign-ups throttled while
-- check-ins, gestures and crisis support keep working. Hold-all (06c F9 "Gaps"): every new reflection waits for a human.
-- Reflections arrive with F6 (Milestone B); what each switch does today is listed in docs/setup/admin-console.md.
insert into public.feature_flags (key, enabled, payload) values
  ('reduced_mode', false, '{}'::jsonb),
  ('hold_all', false, '{}'::jsonb)
on conflict (key) do nothing;

-- =============================================================================================== privileges
revoke all on function public.admin_item_crisis_flagged(uuid) from public, anon, authenticated, service_role;
revoke all on function public.admin_report_for_action(uuid) from public, anon, authenticated, service_role;
revoke all on function public.admin_add_strike(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_add_sanction(uuid, text, text, int, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_resolve_report(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_extend_evidence_hold(uuid, int, boolean) from public, anon, authenticated, service_role;
revoke all on function public.admin_lift_sanction(uuid) from public, anon, authenticated, service_role;
revoke all on function public.admin_record_mandatory_report(uuid, text, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_hide_account_from_rooms(uuid, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.admin_audit_anchor() from public, anon, authenticated, service_role;
revoke all on function public.strikes_never_crisis() from public, anon, authenticated, service_role;
revoke all on function public.admin_staff_audit() from public, anon, authenticated, service_role;
revoke all on function public.admin_assert_owner(text) from public, anon, authenticated, service_role;
revoke all on function public.admin_staff_list() from public, anon, authenticated, service_role;
revoke all on function public.admin_staff_add(text, text, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_staff_update(text, uuid, text, text, boolean) from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_case_open(text, text, text, timestamptz, uuid, text, timestamptz, text)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_case_mark_sent(uuid, boolean) from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_case_reissue(uuid, text, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.deletion_case_lookup(text) from public, anon, authenticated, service_role;
revoke all on function public.deletion_case_confirm(text, boolean) from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_case_schedule(uuid, boolean, timestamptz, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_case_close(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_cases_list(text, int, uuid) from public, anon, authenticated, service_role;
revoke all on function public.admin_deletion_cases_account_gone() from public, anon, authenticated, service_role;
-- Migration 13 left service_role (PostgREST with the service key) able to call this one; the console never needs that.
revoke all on function public.admin_account_age_days(uuid) from service_role;

-- aura_admin: exactly the console's state changes and reads. Not: deletion_case_lookup / deletion_case_confirm (the
-- public link only), admin_assert_owner and the trigger functions.
grant execute on function public.admin_item_crisis_flagged(uuid) to aura_admin;
grant execute on function public.admin_report_for_action(uuid) to aura_admin;
grant execute on function public.admin_add_strike(uuid, text, text) to aura_admin;
grant execute on function public.admin_add_sanction(uuid, text, text, int, text, text) to aura_admin;
grant execute on function public.admin_resolve_report(uuid, text, text) to aura_admin;
grant execute on function public.admin_extend_evidence_hold(uuid, int, boolean) to aura_admin;
grant execute on function public.admin_lift_sanction(uuid) to aura_admin;
grant execute on function public.admin_record_mandatory_report(uuid, text, text, text) to aura_admin;
grant execute on function public.admin_hide_account_from_rooms(uuid, timestamptz) to aura_admin;
grant execute on function public.admin_audit_anchor() to aura_admin;
grant execute on function public.admin_staff_list() to aura_admin;
grant execute on function public.admin_staff_add(text, text, text, text) to aura_admin;
grant execute on function public.admin_staff_update(text, uuid, text, text, boolean) to aura_admin;
grant execute on function public.admin_deletion_case_open(text, text, text, timestamptz, uuid, text, timestamptz, text) to aura_admin;
grant execute on function public.admin_deletion_case_mark_sent(uuid, boolean) to aura_admin;
grant execute on function public.admin_deletion_case_reissue(uuid, text, timestamptz) to aura_admin;
grant execute on function public.admin_deletion_case_schedule(uuid, boolean, timestamptz, text, text) to aura_admin;
grant execute on function public.admin_deletion_case_close(uuid, text, text) to aura_admin;
grant execute on function public.admin_deletion_cases_list(text, int, uuid) to aura_admin;
