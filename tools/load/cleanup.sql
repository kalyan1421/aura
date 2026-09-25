-- Aura load harness cleanup: deletes ONLY what one run (:runid) created, in one transaction.
--   psql "$LOAD_DB_URL" -v ON_ERROR_STOP=1 -v runid=<id> -v since=<ISO start of the run> -f cleanup.sql
-- Use cleanup.sh (it validates the run id and the DB host first).
--
-- What a run creates and how it goes (FK actions checked against the schema, see tools/load/README.md "Cleanup"):
--   auth.users `load-<runid>-<n>@aura.test`  → deleted last; ON DELETE CASCADE removes profiles, avatar/streak state,
--        user_consents (echo opt-out), guidelines_acceptances, room_members (→ room_gestures, room_mutes, reflections,
--        ripple_tickets by member), reflections, ripple_seats, ripple_tickets, sanctions, strikes, gesture_push_log …
--   rooms only our users ever sat in      → deleted (no FK to users; would otherwise stay as empty rooms until purge)
--   ripple_sessions only our users sat in → deleted (+ seats, session log); ripple_invites by our users → deleted
--   reports about / by our users, rooms, members, gestures or reflections (auto items: held reflections, flood signals)
--        → deleted (reports.* user FKs are SET NULL, they would stay as unlinked queue items) + their evidence holds
--   realtime.messages on our rooms' / members' / sessions' topics → deleted (server broadcasts are stored rows)
-- Rooms or sessions shared with anyone else (e.g. another agent's e2e user) are kept; only our memberships/seats go.
-- Never touched: global config rows (feature_flags, matching_config, …), aggregate survey counters, the moderation audit
-- chain (append-only; the harness creates no audit rows when the mock moderation provider is used).

\set ON_ERROR_STOP on
begin;

create temp table lt_users on commit drop as
  select id from auth.users where email ~ ('^load-' || :'runid' || '-[0-9]+@aura\.test$');

create temp table lt_members on commit drop as
  select member_id, room_id from public.room_members where user_id in (select id from lt_users);

create temp table lt_rooms on commit drop as
  select r.id from public.rooms r
   where exists (select 1 from public.room_members m where m.room_id = r.id and m.user_id in (select id from lt_users))
     and not exists (select 1 from public.room_members m where m.room_id = r.id and m.user_id not in (select id from lt_users));

create temp table lt_sessions on commit drop as
  select x.id from public.ripple_sessions x
   where exists (select 1 from public.ripple_seats s where s.session_id = x.id and s.user_id in (select id from lt_users))
     and not exists (select 1 from public.ripple_seats s
                      where s.session_id = x.id and s.kind = 'human' and s.user_id is not null
                        and s.user_id not in (select id from lt_users));

create temp table lt_reflections on commit drop as
  select id from public.reflections
   where user_id in (select id from lt_users) or room_id in (select id from lt_rooms);

create temp table lt_reports on commit drop as
  select id, evidence_hold_id from public.reports
   where reporter_user_id in (select id from lt_users)
      or target_user_id in (select id from lt_users)
      or reporter_member_id in (select member_id from lt_members)
      or target_member_id in (select member_id from lt_members)
      or room_id in (select id from lt_rooms)
      or target_reflection_id in (select id from lt_reflections)
      or target_gesture_id in (select g.id from public.room_gestures g
                                where g.from_member_id in (select member_id from lt_members)
                                   or g.to_member_id in (select member_id from lt_members));

create temp table lt_topics on commit drop as
            select 'room:' || id::text as topic from lt_rooms
  union all select 'ripples:' || id::text from lt_rooms
  union all select 'member:' || member_id::text from lt_members
  union all select 'game:' || id::text from lt_sessions;

select (select count(*) from lt_users) as users, (select count(*) from lt_members) as memberships,
       (select count(*) from lt_rooms) as rooms_only_ours, (select count(*) from lt_sessions) as ripple_sessions_only_ours,
       (select count(*) from lt_reflections) as reflections, (select count(*) from lt_reports) as reports,
       (select count(*) from lt_topics) as realtime_topics;

delete from public.reports where id in (select id from lt_reports);
delete from public.evidence_holds h
 where h.id in (select evidence_hold_id from lt_reports where evidence_hold_id is not null)
    or (h.report_id in (select id from lt_reports))
    or (cardinality(h.account_ids) > 0 and h.account_ids <@ (select coalesce(array_agg(id), '{}') from lt_users));
delete from realtime.messages where topic in (select topic from lt_topics);
delete from public.ripple_invites where inviter_user_id in (select id from lt_users) or room_id in (select id from lt_rooms);
delete from public.ripple_sessions where id in (select id from lt_sessions);
delete from public.rooms where id in (select id from lt_rooms);
delete from auth.users where id in (select id from lt_users);

-- In-transaction verification: nothing that referenced this run is left.
select case when n = 0 then 'verified: nothing of run ' || :'runid' || ' is left' else 'NOT CLEAN: ' || n || ' rows left' end as verification
  from (select
          (select count(*) from auth.users where id in (select id from lt_users))
        + (select count(*) from public.room_members where user_id in (select id from lt_users))
        + (select count(*) from public.rooms where id in (select id from lt_rooms))
        + (select count(*) from public.ripple_sessions where id in (select id from lt_sessions))
        + (select count(*) from public.ripple_seats where user_id in (select id from lt_users))
        + (select count(*) from public.ripple_tickets where user_id in (select id from lt_users))
        + (select count(*) from public.reflections where id in (select id from lt_reflections))
        + (select count(*) from public.reports where id in (select id from lt_reports))
        + (select count(*) from realtime.messages where topic in (select topic from lt_topics)) as n) v;
commit;

-- After commit: no orphans from the run window (rooms nobody sits in, human-less sessions), no account of the run.
select
  (select count(*) from auth.users where email ~ ('^load-' || :'runid' || '-[0-9]+@aura\.test$')) as run_accounts,
  (select count(*) from public.rooms r where r.created_at >= :'since'::timestamptz
      and not exists (select 1 from public.room_members m where m.room_id = r.id))                  as memberless_rooms_since_start,
  (select count(*) from public.ripple_sessions x where x.created_at >= :'since'::timestamptz
      and not exists (select 1 from public.ripple_seats s where s.session_id = x.id and s.kind = 'human')) as humanless_sessions_since_start;
