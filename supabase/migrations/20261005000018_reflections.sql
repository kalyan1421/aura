-- F6 Reflections (contracts/api/v1-reflections.md; PRD 06b F6, 06c F9 "Reflection pipeline", 19 admin console).
-- Server: server/aura-api/src/reflections (API + worker); console: apps/admin (/reflections); app:
-- apps/mobile/lib/src/features/reflections.
--
--  1. `reflection_config` — single-row tunables (limits, timeouts, thresholds, the overnight window, the auto-pause
--     level), changeable without a release. Thresholds are validated again by NestJS (falls back to its defaults).
--  2. `reflections` — SERVER-ONLY like the rest of F5/F9 (RLS on, no policies, no client privileges): no client ever
--     reads another person's reflection from Postgres; strangers read through NestJS, which returns pseudonyms only
--     (DS-10). The text is envelope-encrypted (DS-1): `body_ct` = base64(iv ‖ AES-256-GCM ciphertext ‖ tag) under a
--     random per-reflection data key, `body_key` = that key wrapped with the server master key (src/keys/envelope.ts),
--     both bound to the reflection id. Only NestJS can decrypt. `text_hash` is an HMAC of the normalized text (near-
--     duplicate check), never shown. `parent_id` is the P2 replies hook and must stay null in v1 (REQ-REF-05).
--     Rows cascade with the room (purge at 24 h + 7 d) and with the author's membership / account; the account purge
--     deletes them explicitly (PERSONAL_TABLES). Reported / held items are copied into `evidence_holds` (encrypted)
--     first, which survives both purges (180 days, [LEGAL]).
--  3. Gestures on a reflection: `room_gestures.target = 'reflection'` with `to_reflection_id` (the recipient member is
--     the author, so blocks / mutes / hidden accounts drop them like any member gesture).
--  4. Reports and evidence: `reports.target_kind = 'reflection'` + `target_reflection_id`; the pipeline's automatic
--     items (`auto_signal` reflection_hold / reflection_crisis / reflection_minor_safety / reflection_violation);
--     `evidence_holds.item_kind = 'reflection'`.
--  5. Flags: `reflections_composer` (kill switch, payload `pausedPools`); `reduced_mode` and `hold_all` (migration 16)
--     now take effect in the pipeline.
--  6. Console (`aura_admin`, REQ-ADM-03): column-scoped reads (never `user_id` or `text_hash`), and three SECURITY
--     DEFINER functions for state changes — `admin_reflection_decide` (approve / remove, with the room / author
--     broadcasts and report resolution), `admin_reflection_escalate` (report lane up) — plus `admin_reflection_author`
--     (the author's account for the audit HMAC and the item view, only for a reflection that has a report).

-- =============================================================================================== 1. config
create table public.reflection_config (
  id                   boolean primary key default true check (id),
  max_chars            int  not null default 200 check (max_chars between 1 and 1000),
  per_room_24h         int  not null default 3   check (per_room_24h between 1 and 100),
  per_account_24h      int  not null default 10  check (per_account_24h between 1 and 1000),
  respond_within_ms    int  not null default 1800 check (respond_within_ms between 0 and 10000),
  provider_timeout_ms  int  not null default 5000 check (provider_timeout_ms between 500 and 30000),
  pending_timeout_s    int  not null default 60  check (pending_timeout_s between 10 and 3600),
  near_duplicate_rooms int  not null default 2   check (near_duplicate_rooms between 1 and 100),   -- held when in MORE rooms
  auto_pause_held      int  not null default 50  check (auto_pause_held between 1 and 100000),  -- per language pool
  overnight_start      time not null default '00:30',
  overnight_end        time not null default '07:30',
  overnight_tz         text not null default 'Asia/Kolkata',
  -- Omni-moderation thresholds [ASSUMPTION, tuned weekly in beta]; NestJS validates the shape (src/reflections/decide.ts).
  thresholds           jsonb not null default '{}'::jsonb check (jsonb_typeof(thresholds) = 'object'),
  updated_at           timestamptz not null default now()
);
insert into public.reflection_config default values;
comment on table public.reflection_config is
  'F6 tunables (PRD F6 "Behaviour", "Moderation pipeline"; 19 "Configuration … under-18 moderation thresholds").';

-- =============================================================================================== 2. reflections
create table public.reflections (
  id              uuid primary key,                                  -- client-generated UUIDv7 (idempotent sends)
  room_id         uuid not null references public.rooms(id) on delete cascade,
  member_id       uuid not null,
  user_id         uuid not null references auth.users(id) on delete cascade,   -- the author; never leaves NestJS
  parent_id       uuid check (parent_id is null),                    -- P2: text replies; rejected in v1 (REQ-REF-05)
  status          text not null check (status in ('pending','published','held','rejected','crisis_diverted',
                                                  'removed','deleted','expired')),
  body_ct         text check (body_ct is null or char_length(body_ct) between 16 and 20000),
  body_key        text check (body_key is null or char_length(body_key) between 16 and 200),
  char_count      smallint not null check (char_count between 1 and 1000),
  text_hash       text check (text_hash is null or text_hash ~ '^[0-9a-f]{64}$'),
  language_pool   text not null check (language_pool in ('en','te','hi')),
  involves_minor  boolean not null default false,                    -- author or a room member under 18 (invisible)
  strict          boolean not null default false,                    -- stricter thresholds were applied
  overnight       boolean not null default false,                    -- decided inside the reviewer's night window
  stage           text check (stage is null or stage in ('rules','provider','human','author','system')),
  hold_reason     text check (hold_reason is null or hold_reason in ('uncertain','strict_threshold','overnight',
                    'provider_unavailable','timeout','hold_all','active_strike','sanction','near_duplicate','reported')),
  reject_reason   text check (reject_reason is null or reject_reason in ('contact_details','link','personal_questions',
                    'hurtful','sexual','other')),
  mod_scores      jsonb check (mod_scores is null or jsonb_typeof(mod_scores) = 'object'),   -- category → score, no text
  rule_hits       text[] not null default '{}',                      -- rule ids, never the matched words
  created_at      timestamptz not null default now(),
  decided_at      timestamptz,
  decided_by      text check (decided_by is null or char_length(decided_by) between 1 and 120),
  published_at    timestamptz,
  removed_at      timestamptz,
  hidden_at       timestamptz,                                       -- hidden by the report threshold, awaiting review
  constraint reflections_member_fk foreign key (room_id, member_id)
    references public.room_members (room_id, member_id) on delete cascade,
  -- Text is kept (encrypted) while it can still matter; deleted / expired items are scrubbed.
  constraint reflections_body check ((body_ct is null) = (body_key is null)
                                     and (status in ('deleted','expired') or body_ct is not null)),
  constraint reflections_published check (status <> 'published' or published_at is not null)
);
create index reflections_room_idx on public.reflections (room_id, created_at desc);
create index reflections_user_idx on public.reflections (user_id, created_at desc);
create index reflections_review_idx on public.reflections (status, created_at) where status in ('pending','held');
create index reflections_hash_idx on public.reflections (user_id, text_hash, created_at) where text_hash is not null;
comment on table public.reflections is
  'F6 reflections. Server-only (DS-10): strangers read through NestJS. Text envelope-encrypted (DS-1), never logged.';

-- =============================================================================================== 3. gestures on reflections
alter table public.room_gestures add column to_reflection_id uuid references public.reflections(id) on delete cascade;
alter table public.room_gestures drop constraint room_gestures_target_check;
alter table public.room_gestures add constraint room_gestures_target_check check (target in ('room','member','reflection'));
alter table public.room_gestures drop constraint room_gestures_target_shape;
alter table public.room_gestures add constraint room_gestures_target_shape check (
  ((target in ('member','reflection')) = (to_member_id is not null))
  and ((target = 'reflection') = (to_reflection_id is not null)));
create index room_gestures_reflection_idx on public.room_gestures (to_reflection_id) where to_reflection_id is not null;

-- =============================================================================================== 4. reports + evidence
alter table public.reports add column target_reflection_id uuid references public.reflections(id) on delete set null;
alter table public.reports drop constraint reports_target_kind_check;
alter table public.reports add constraint reports_target_kind_check check (target_kind in ('member','gesture','room','reflection'));
alter table public.reports drop constraint reports_auto_signal_check;
alter table public.reports add constraint reports_auto_signal_check check (auto_signal in (
  'gesture_flood','reflection_hold','reflection_crisis','reflection_minor_safety','reflection_violation'));
create index reports_reflection_idx on public.reports (target_reflection_id) where target_reflection_id is not null;

alter table public.evidence_holds drop constraint evidence_holds_item_kind_check;
alter table public.evidence_holds add constraint evidence_holds_item_kind_check
  check (item_kind in ('member','gesture','room','reflection'));

-- =============================================================================================== 5. flags
insert into public.feature_flags (key, enabled, payload, description)
values ('reflections_composer', true, '{"pausedPools": []}'::jsonb,
        'Reflections (F6). Off: no new reflections anywhere (POST …/reflections → 503 reflections_paused). payload.pausedPools pauses a language pool (en / te / hi); tripped automatically above reflection_config.auto_pause_held held items; resume on the console''s Reflections page.')
on conflict (key) do nothing;
update public.feature_flags
   set description = 'Reduced mode (PRD 19, before AK is unreachable): reflections paused (503 reflections_paused); check-ins, gestures and crisis support keep working. The sign-up throttle is not wired yet.'
 where key = 'reduced_mode';
update public.feature_flags
   set description = 'Hold-all (06c F9, before planned absences): every new reflection waits for a human; gestures unaffected.'
 where key = 'hold_all';

-- =============================================================================================== 6. console functions
-- The author's account for a reflection that has a report (the audit HMAC, strike history, "Under 18" flag). A
-- reflection nobody reported and the pipeline never queued stays unlinkable from the console.
create function public.admin_reflection_author(p_reflection uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select r.user_id from public.reflections r
   where r.id = p_reflection
     and exists (select 1 from public.reports x where x.target_reflection_id = r.id)
$$;

-- Approve or remove a reflection (19 "Actions"; contracts/api/v1-reflections.md §4), in the caller's transaction:
--  approve — pending / held / rejected / crisis_diverted / removed → published (hidden cleared); an already published
--            item is un-hidden. Open reports on it close as dismissed ("reviewed, no action") and an automatic
--            shadow-mute raised by them is lifted. Refused for a memory room (room_read_only) or a deleted / expired
--            item (not_reviewable).
--  remove  — pending / held → rejected (p_reject_reason, default other); published → removed; crisis_diverted and
--            rejected stay unpublished. Open reports on it close as actioned.
-- Becoming visible sends `reflection_published` to the room; leaving view sends `reflection_removed`; a changed status
-- sends `reflection_status` to the author's member topic — ids and a status only (DS-10).
create function public.admin_reflection_decide(p_reflection uuid, p_decision text, p_actor text,
                                               p_reject_reason text default null)
returns table (room_id uuid, previous_status text, status text, hidden boolean, reports_resolved int,
               sanctions_lifted int, subject uuid)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  r        record;
  rm       record;
  new_st   text;
  was_vis  boolean;
  now_vis  boolean;
  resolved int := 0;
  lifted   int := 0;
  rep_ids  uuid[];
  at_txt   text := to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
begin
  if p_decision is null or p_decision not in ('approve', 'remove')
     or p_actor is null or char_length(p_actor) not between 1 and 120
     or (p_reject_reason is not null and p_reject_reason not in
         ('contact_details','link','personal_questions','hurtful','sexual','other')) then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select x.* into r from public.reflections x where x.id = p_reflection for update;
  if not found then raise exception using errcode = 'AR040', message = 'not_found'; end if;
  if r.status in ('deleted', 'expired') then raise exception using errcode = 'AR040', message = 'not_reviewable'; end if;
  select x.memory_at into rm from public.rooms x where x.id = r.room_id;
  was_vis := r.status = 'published' and r.hidden_at is null;

  if p_decision = 'approve' then
    if rm.memory_at <= now() and not was_vis then
      raise exception using errcode = 'AR040', message = 'room_read_only';
    end if;
    new_st := 'published';
    update public.reflections x
       set status = 'published', hidden_at = null, reject_reason = null,
           published_at = coalesce(x.published_at, now()), removed_at = null,
           decided_at = now(), decided_by = p_actor, stage = 'human'
     where x.id = r.id;
  else
    new_st := case when r.status in ('pending', 'held') then 'rejected'
                   when r.status = 'published' then 'removed'
                   else r.status end;
    update public.reflections x
       set status = new_st,
           reject_reason = case when r.status in ('pending', 'held', 'published') then coalesce(p_reject_reason, 'other')
                                else x.reject_reason end,
           removed_at = case when r.status = 'published' then now() else x.removed_at end,
           decided_at = now(), decided_by = p_actor, stage = 'human'
     where x.id = r.id;
  end if;
  now_vis := new_st = 'published';

  select coalesce(array_agg(x.id), '{}') into rep_ids
    from public.reports x where x.target_reflection_id = r.id and x.status = 'open';
  update public.reports x
     set status = case when p_decision = 'approve' then 'dismissed' else 'actioned' end,
         resolved_at = now(), resolved_by = p_actor
   where x.id = any(rep_ids);
  get diagnostics resolved = row_count;
  if p_decision = 'approve' then
    update public.sanctions s set lifted_at = now()
     where s.report_id = any(rep_ids) and s.source = 'auto' and s.kind = 'shadow_mute' and s.lifted_at is null;
    get diagnostics lifted = row_count;
  end if;

  if now_vis and not was_vis then
    perform realtime.send(jsonb_build_object('reflectionId', r.id, 'at', at_txt), 'reflection_published',
                          'room:' || r.room_id::text, true);
  elsif was_vis and not now_vis then
    perform realtime.send(jsonb_build_object('reflectionId', r.id, 'at', at_txt), 'reflection_removed',
                          'room:' || r.room_id::text, true);
  end if;
  if new_st <> r.status then
    perform realtime.send(jsonb_build_object('reflectionId', r.id, 'status', new_st, 'at', at_txt), 'reflection_status',
                          'member:' || r.member_id::text, true);
  end if;
  return query select r.room_id, r.status, new_st, false, resolved, lifted, r.user_id;
end $$;

-- Escalate a reflection report to a higher-priority lane (19 "Escalate"): crisis > minors_grooming > harassment >
-- spam. The SLA only gets shorter and paging only turns on (NestJS computes both with src/safety/lanes.ts).
create function public.admin_reflection_escalate(p_report uuid, p_lane text, p_due timestamptz, p_pages boolean)
returns boolean
language plpgsql volatile security definer set search_path = '' as $$
declare
  r   record;
  rank_ constant jsonb := '{"crisis":0,"minors_grooming":1,"harassment":2,"spam":3}';
begin
  if p_lane is null or p_lane not in ('crisis', 'minors_grooming') or p_due is null then
    raise exception using errcode = 'AR040', message = 'invalid_input';
  end if;
  select x.id, x.lane, x.status, x.target_kind into r from public.reports x where x.id = p_report for update;
  if not found or r.target_kind <> 'reflection' then raise exception using errcode = 'AR040', message = 'not_found'; end if;
  if r.status <> 'open' then raise exception using errcode = 'AR040', message = 'no_open_report'; end if;
  if (rank_ ->> p_lane)::int >= (rank_ ->> r.lane)::int then
    raise exception using errcode = 'AR040', message = 'invalid_lane';
  end if;
  update public.reports x
     set lane = p_lane, sla_due_at = least(x.sla_due_at, p_due), pages = x.pages or coalesce(p_pages, false)
   where x.id = p_report;
  return true;
end $$;

-- =============================================================================================== RLS / privileges
alter table public.reflection_config enable row level security;
alter table public.reflections       enable row level security;
revoke all on table public.reflection_config, public.reflections from anon, authenticated;

revoke all on function public.admin_reflection_author(uuid) from public, anon, authenticated, service_role;
revoke all on function public.admin_reflection_decide(uuid, text, text, text) from public, anon, authenticated, service_role;
revoke all on function public.admin_reflection_escalate(uuid, text, timestamptz, boolean) from public, anon, authenticated, service_role;

-- aura_admin: reads without the author's account or the duplicate hash; the ciphertext is useless without NestJS's
-- master key (the console never gets a decrypt route of its own: NestJS decrypts for the item view).
grant select (id, room_id, member_id, parent_id, status, body_ct, body_key, char_count, language_pool, involves_minor,
              strict, overnight, stage, hold_reason, reject_reason, mod_scores, rule_hits, created_at, decided_at,
              decided_by, published_at, removed_at, hidden_at)
  on public.reflections to aura_admin;
grant select (thresholds, auto_pause_held, overnight_start, overnight_end, overnight_tz) on public.reflection_config to aura_admin;
grant select (target_reflection_id) on public.reports to aura_admin;
grant select (to_reflection_id) on public.room_gestures to aura_admin;
grant execute on function public.admin_reflection_author(uuid) to aura_admin;
grant execute on function public.admin_reflection_decide(uuid, text, text, text) to aura_admin;
grant execute on function public.admin_reflection_escalate(uuid, text, timestamptz, boolean) to aura_admin;
