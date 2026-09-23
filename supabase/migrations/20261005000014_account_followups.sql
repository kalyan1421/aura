-- Account & safety follow-ups (contracts/api/v1.md "Onboarding / profile", "Account deletion", "Account closed",
-- "Retention"; PRD 06c F8 REQ-ACC-04 / REQ-ACC-10 / REQ-ACC-11, F9; 19 admin console "Audit log").
--
--  1. `apple_auth_tokens`: the Sign in with Apple refresh token of an account, so the account deletion can revoke it
--     (App Review 5.1.1(v), PRD "Apple token revoked"). Written only by NestJS (POST /v1/account/apple-auth), sealed
--     with AURA_MASTER_KEY (AES-256-GCM, the user id bound as associated data — the same envelope as user_data_keys).
--     The purge revokes it at Apple, then deletes the row.
--  2. `minor_signals`: a platform age signal said "under 18" (Apple Declared Age Range / Play Age Signals) while the
--     date of birth says adult. Drives the invisible under-18 protections only (REQ-ACC-10); never returned to anyone.
--  3. `user_is_minor(uid)` = under 18 by stored DOB OR an unexpired signal.
--  4. Retention settings on `safety_config`: the moderation audit log is kept 3 years [LEGAL] (19 admin console);
--     closed reports have no retention in the PRD yet, so the setting defaults to NULL = keep (decision for AK and the
--     lawyer).
--  5. Pruning the append-only, hash-chained `moderation_actions`: only through `prune_moderation_actions()`, only rows
--     past the retention, only a prefix of the chain (never the newest row), and the last pruned row's hash is kept in
--     `moderation_audit_anchor` so the remaining chain still verifies. A plain DELETE / UPDATE / TRUNCATE still fails
--     for every role.
--
-- Every new table is server-only: RLS on, no policies, no client privileges (like account_deletions).

-- =============================================================================================== 1. Apple tokens
create table public.apple_auth_tokens (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  -- The Apple client the token was issued to (the bundle id for native iOS); revocation must use the same one.
  client_id             text not null check (client_id ~ '^[A-Za-z0-9][A-Za-z0-9.\-]{0,254}$'),
  -- base64( iv[12] ‖ AES-256-GCM(AURA_MASTER_KEY, refresh token) ‖ tag[16] ), AAD = 'aura:apple-refresh-token:v1:<user_id>'.
  wrapped_refresh_token text not null check (char_length(wrapped_refresh_token) between 40 and 8192),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on table public.apple_auth_tokens is
  'Sign in with Apple refresh token (sealed with AURA_MASTER_KEY), revoked at Apple when the account is deleted. Server-only; never logged.';

alter table public.apple_auth_tokens enable row level security;
revoke all on table public.apple_auth_tokens from anon, authenticated;

-- =============================================================================================== 2. age signals
create table public.minor_signals (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  -- Under-18 protections apply while current_date < minor_until: the day the youngest age in the signalled band (13)
  -- turns 18, counted from the day the signal reached the server. Only ever moved later, never earlier.
  minor_until date not null,
  updated_at  timestamptz not null default now()
);
comment on table public.minor_signals is
  'Invisible under-18 flag from a platform age signal (REQ-ACC-04/10). Server-only; never returned to any client (DS-10).';

alter table public.minor_signals enable row level security;
revoke all on table public.minor_signals from anon, authenticated;

-- =============================================================================================== 3. user_is_minor
-- Same signature, owner, privileges and pinned search_path as the foundations version; now also true while an
-- under-18 platform signal is unexpired. Drives only invisible protections (minors lane, stricter moderation,
-- analytics exclusion) and is never exposed to clients.
create or replace function public.user_is_minor(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.birth_date > (current_date - interval '18 years') from public.profiles p where p.user_id = uid), false)
      or exists (select 1 from public.minor_signals s where s.user_id = uid and s.minor_until > current_date)
$$;
revoke all on function public.user_is_minor(uuid) from public, anon, authenticated;

-- =============================================================================================== 4. retention settings
alter table public.safety_config
  -- 19 admin console: "Audit log … Retention 3 years [LEGAL]". 1096 days = 3 × 365 + 1, so a row is never deleted
  -- before three calendar years have passed, leap day or not.
  add column moderation_audit_retention_days int not null default 1096
    check (moderation_audit_retention_days between 365 and 3650),
  -- Closed (actioned / dismissed) reports: the PRD sets no retention. NULL = keep them (no deletion job runs).
  -- [LEGAL] decision for AK and the lawyer before any value is set.
  add column closed_report_retention_days int
    check (closed_report_retention_days is null or closed_report_retention_days between 30 and 3650);

comment on column public.safety_config.moderation_audit_retention_days is
  'Days a moderation_actions row is kept (default 1096 = 3 years, 19 admin console [LEGAL]); pruned daily by the worker.';
comment on column public.safety_config.closed_report_retention_days is
  'Days a closed report is kept after it was resolved. NULL (default) = keep; set only after AK / the lawyer decide [LEGAL].';

-- =============================================================================================== 5. audit pruning
-- The chain's cut point: the id and row_hash of the last row removed by prune_moderation_actions(). The oldest remaining
-- row's prev_hash must equal last_pruned_hash (src/safety/audit.ts verifyAuditChain).
create table public.moderation_audit_anchor (
  id               boolean primary key default true check (id),
  last_pruned_id   bigint not null,
  last_pruned_hash text not null check (last_pruned_hash ~ '^[0-9a-f]{64}$'),
  pruned_rows      bigint not null default 0 check (pruned_rows >= 0),
  updated_at       timestamptz not null default now()
);
comment on table public.moderation_audit_anchor is
  'Where the moderation audit chain was cut by the retention job; written only by prune_moderation_actions().';

alter table public.moderation_audit_anchor enable row level security;
revoke all on table public.moderation_audit_anchor from anon, authenticated;
revoke insert, update, delete, truncate on table public.moderation_audit_anchor from service_role;

-- The append-only trigger now lets exactly one thing through: a DELETE made by prune_moderation_actions() (which sets
-- the transaction-local flag below) of a row that is past the configured retention. Even with the flag set by hand, a
-- row inside the retention, an UPDATE or a TRUNCATE still fails (AR010).
create or replace function public.moderation_actions_append_only() returns trigger
language plpgsql set search_path = '' as $$
declare
  keep_days int;
begin
  if tg_op = 'DELETE' and coalesce(current_setting('aura.moderation_audit_prune', true), '') = 'on' then
    select c.moderation_audit_retention_days into keep_days from public.safety_config c where c.id;
    if keep_days is not null and old.created_at < now() - make_interval(days => keep_days) then
      return old;
    end if;
  end if;
  raise exception 'moderation_actions is append-only' using errcode = 'AR010';
end $$;
revoke all on function public.moderation_actions_append_only() from public, anon, authenticated;

-- Deletes up to p_batch of the oldest rows past the retention. Only a prefix of the chain goes (the rows before the
-- first row still inside the retention), never the newest row (the next append links to it), under the chain
-- trigger's advisory lock so no append interleaves. Records the cut in moderation_audit_anchor. Returns the number of
-- rows deleted. Worker `maintenance` queue, job `retention` (daily).
create function public.prune_moderation_actions(p_batch int default 10000) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  keep_days  int;
  cutoff     timestamptz;
  newest     bigint;
  first_kept bigint;
  last_id    bigint;
  last_hash  text;
  n          bigint;
begin
  if p_batch is null or p_batch < 1 or p_batch > 100000 then
    raise exception 'p_batch must be between 1 and 100000' using errcode = '22023';
  end if;
  select c.moderation_audit_retention_days into keep_days from public.safety_config c where c.id;
  if keep_days is null then
    return 0;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('aura:moderation_actions', 0));
  cutoff := now() - make_interval(days => keep_days);

  select max(a.id) into newest from public.moderation_actions a;
  if newest is null then
    return 0;
  end if;
  select coalesce(min(a.id), newest) into first_kept from public.moderation_actions a where a.created_at >= cutoff;

  select max(d.id), count(*) into last_id, n
    from (select a.id from public.moderation_actions a where a.id < first_kept order by a.id limit p_batch) d;
  if n = 0 then
    return 0;
  end if;
  select a.row_hash into last_hash from public.moderation_actions a where a.id = last_id;

  perform set_config('aura.moderation_audit_prune', 'on', true);
  delete from public.moderation_actions a where a.id <= last_id;
  perform set_config('aura.moderation_audit_prune', 'off', true);

  insert into public.moderation_audit_anchor as x (id, last_pruned_id, last_pruned_hash, pruned_rows, updated_at)
  values (true, last_id, last_hash, n, now())
  on conflict (id) do update
    set last_pruned_id = excluded.last_pruned_id,
        last_pruned_hash = excluded.last_pruned_hash,
        pruned_rows = x.pruned_rows + excluded.pruned_rows,
        updated_at = excluded.updated_at;
  return n;
end $$;
revoke all on function public.prune_moderation_actions(int) from public, anon, authenticated, service_role;
