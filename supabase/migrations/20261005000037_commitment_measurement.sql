-- W07 — do habit commitments help? (docs/measurement/commitments.md)
--
-- `habits.committed_from` holds only a habit's *current* commitment, so measuring from it alone would drop everyone who
-- tried a commitment and ended it: exactly the people who would show it does harm. This keeps an append-only history
-- (start / end, no content) written by a trigger on `habits`, so every writer is covered, and one aggregate function that
-- compares each person's committed habits with their own other habits (within-person, so it does not confuse "people
-- who opt in are more motivated" with "commitments work").
--
-- Server-side and aggregate only, per the analytics plan (PRD 13: Postgres is the source of truth for counts; adults only,
-- because commitments are never available under 18; no cell reported below 20 people).

create table public.habit_commitment_events (
  id        bigint generated always as identity primary key,
  user_id   uuid not null references auth.users(id) on delete cascade,
  habit_id  uuid not null,                       -- deliberately no FK: a deleted habit's history stays measurable
  kind      text not null check (kind in ('start', 'end')),
  day       date not null,                       -- `start`: committed_from; `end`: the UTC date it ended
  at        timestamptz not null default now()
);
create index habit_commitment_events_habit_idx on public.habit_commitment_events (habit_id, at, id);
create index habit_commitment_events_user_idx  on public.habit_commitment_events (user_id);
comment on table public.habit_commitment_events is
  'W07: append-only start/end of a habit commitment, written by trigger. Server-only; feeds commitment_outcomes(); deleted with the account.';

alter table public.habit_commitment_events enable row level security;
revoke all on table public.habit_commitment_events from anon, authenticated;

create function public.habits_commitment_events() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.committed_from is not null then
      insert into public.habit_commitment_events (user_id, habit_id, kind, day)
        values (new.user_id, new.id, 'start', new.committed_from);
    end if;
  elsif tg_op = 'UPDATE' then
    if new.committed_from is distinct from old.committed_from then
      if old.committed_from is not null then
        insert into public.habit_commitment_events (user_id, habit_id, kind, day)
          values (old.user_id, old.id, 'end', current_date);
      end if;
      if new.committed_from is not null then
        insert into public.habit_commitment_events (user_id, habit_id, kind, day)
          values (new.user_id, new.id, 'start', new.committed_from);
      end if;
    end if;
  elsif tg_op = 'DELETE' then
    -- Not while the account itself is being deleted (its rows are going anyway).
    if old.committed_from is not null and exists (select 1 from auth.users u where u.id = old.user_id) then
      insert into public.habit_commitment_events (user_id, habit_id, kind, day)
        values (old.user_id, old.id, 'end', current_date);
    end if;
  end if;
  return null;
end
$$;
revoke all on function public.habits_commitment_events() from public, anon, authenticated;

create trigger habits_commitment_events
  after insert or update of committed_from or delete on public.habits
  for each row execute function public.habits_commitment_events();

-- Commitments that already exist when this migration runs: their start is on record.
insert into public.habit_commitment_events (user_id, habit_id, kind, day)
select user_id, id, 'start', committed_from from public.habits where committed_from is not null;

-- =============================================================================================== outcomes
-- One row per measure and cohort. `users` is distinct adults; `units` is the things counted (episodes, habits). A cell
-- with fewer than 20 users is suppressed: `value` is null and `suppressed` true.
--
--   recovery_7d      of "rest episodes" (a habit unlogged for two full days), the share logged again within the
--                    next 7 days. committed = the habit was under a commitment; control = the same person's other
--                    habits, after their first commitment, not under one.
--   lapse_14d        of the same episodes, the share followed by 14 days with no habit log and no active day at all
--                    (the guardrail: a commitment must not push people away from Aura).
--   logs_14d_change  per person: logs in the 14 days after a habit was committed minus the 14 days before, for that
--                    habit (committed) and for their other habits over the same days (control); 'difference' is the
--                    mean of committed minus control (a within-person difference in differences).
--   ended_30d        of commitments observed for 30 days, the share ended within 30 (committed only).
create function public.commitment_outcomes(p_since date default (current_date - 180))
returns table (measure text, cohort text, users int, units int, value numeric, suppressed boolean)
language sql stable security definer set search_path = public as $$
  with adult as (
    select p.user_id from public.profiles p where not public.user_is_minor(p.user_id)
  ),
  ev as (
    select e.user_id, e.habit_id, e.kind, e.day,
           lead(e.kind) over w as next_kind, lead(e.day) over w as next_day
      from public.habit_commitment_events e
     where e.user_id in (select user_id from adult)
    window w as (partition by e.habit_id order by e.at, e.id)
  ),
  ivals as (               -- [s, e): the days a habit was under a commitment
    select user_id, habit_id, day as s,
           case when next_kind = 'end' then next_day else 'infinity'::date end as e
      from ev where kind = 'start'
  ),
  first_start as (
    select user_id, min(s) as fs from ivals group by user_id
  ),
  logs as (
    select l.user_id, l.habit_id, l.local_day as d,
           lead(l.local_day) over (partition by l.habit_id order by l.local_day) as nd
      from public.habit_logs l where l.user_id in (select user_id from adult)
  ),
  eps as (                 -- a habit unlogged for two full days: decay would begin on d + 3
    select l.user_id, l.habit_id, l.d, l.d + 3 as ed, l.nd
      from logs l
     where coalesce(l.nd - l.d - 1, 9999) >= 2
       and l.d + 3 >= p_since
       and l.d + 3 + 13 <= current_date - 1                 -- the whole 14-day window is in the past
  ),
  tagged as (
    select e.*,
           exists (select 1 from ivals i
                    where i.habit_id = e.habit_id and i.s <= e.d and e.ed < i.e) as committed,
           f.fs is not null and e.ed >= f.fs as after_first
      from eps e left join first_start f on f.user_id = e.user_id
  ),
  scored as (
    select t.user_id, t.committed,
           (t.nd is not null and t.nd <= t.ed + 6) as recovered,
           not exists (select 1 from public.habit_logs x
                        where x.user_id = t.user_id and x.local_day between t.ed and t.ed + 13)
           and not exists (select 1 from public.active_days a
                            where a.user_id = t.user_id and a.local_day between t.ed and t.ed + 13) as lapsed
      from tagged t
     -- committed episodes, and control episodes of people who have committed (same person, same period)
     where t.committed or (t.after_first and not exists (
             select 1 from ivals i where i.habit_id = t.habit_id and i.s <= t.ed and t.ed < i.e))
  ),
  -- first commitment of each habit with a full 14 days before and after
  starts as (
    select i.user_id, i.habit_id, min(i.s) as c
      from ivals i
      join public.habits h on h.id = i.habit_id and h.created_at::date <= i.s - 14
     where i.s >= p_since and i.s + 13 <= current_date - 1
     group by i.user_id, i.habit_id
  ),
  committed_change as (
    select s.user_id, s.habit_id, s.c,
           (select count(*) from public.habit_logs l where l.habit_id = s.habit_id and l.local_day between s.c and s.c + 13)
         - (select count(*) from public.habit_logs l where l.habit_id = s.habit_id and l.local_day between s.c - 14 and s.c - 1) as change
      from starts s
  ),
  control_change as (      -- the same person's habits never committed in that window, present for the whole of it
    select s.user_id, s.habit_id as for_habit, h.id as control_habit,
           (select count(*) from public.habit_logs l where l.habit_id = h.id and l.local_day between s.c and s.c + 13)
         - (select count(*) from public.habit_logs l where l.habit_id = h.id and l.local_day between s.c - 14 and s.c - 1) as change
      from starts s
      join public.habits h on h.user_id = s.user_id and h.id <> s.habit_id and h.created_at::date <= s.c - 14
     where not exists (select 1 from ivals i
                        where i.habit_id = h.id and i.s <= s.c + 13 and i.e > s.c - 14)
  ),
  per_user as (
    select cc.user_id,
           avg(cc.change)::numeric as committed_change,
           (select avg(k.change)::numeric from control_change k where k.user_id = cc.user_id) as control_change
      from committed_change cc group by cc.user_id
  ),
  did as (select * from per_user where control_change is not null),
  ended as (
    select i.user_id, i.habit_id, (i.e <> 'infinity'::date and i.e <= i.s + 30) as ended_30
      from (select user_id, habit_id, s, e, row_number() over (partition by habit_id order by s) as rn from ivals) i
     where i.rn = 1 and i.s >= p_since and i.s + 30 <= current_date - 1
  )
  select m.measure, m.cohort, m.users, m.units,
         case when m.users >= 20 then round(m.value, 4) end, m.users < 20
    from (
      select 'recovery_7d'::text as measure, case when committed then 'committed' else 'control' end as cohort,
             count(distinct user_id)::int as users, count(*)::int as units, avg(recovered::int)::numeric as value
        from scored group by committed
      union all
      select 'lapse_14d', case when committed then 'committed' else 'control' end,
             count(distinct user_id)::int, count(*)::int, avg(lapsed::int)::numeric
        from scored group by committed
      union all
      select 'logs_14d_change', 'committed', count(*)::int, count(*)::int, avg(committed_change) from did
      union all
      select 'logs_14d_change', 'control', count(*)::int, count(*)::int, avg(control_change) from did
      union all
      select 'logs_14d_change', 'difference', count(*)::int, count(*)::int, avg(committed_change - control_change) from did
      union all
      select 'ended_30d', 'committed', count(distinct user_id)::int, count(*)::int, avg(ended_30::int)::numeric from ended
    ) m
   order by m.measure, m.cohort
$$;
revoke all on function public.commitment_outcomes(date) from public, anon, authenticated;
comment on function public.commitment_outcomes(date) is
  'W07: aggregate outcomes of habit commitments (adults, within-person, cells under 20 people suppressed). Server-side only.';

-- The console reads it as `aura_admin` (least privilege, REQ-ADM-03: `SET LOCAL ROLE`). It is SECURITY DEFINER and
-- returns aggregates only, so this grants no access to any table.
grant execute on function public.commitment_outcomes(date) to aura_admin;

