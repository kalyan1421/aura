import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import type { Quadrant, Stage } from '../rules';
import { HIDDEN_ACCOUNT_SQL } from '../safety/safety-types';
import { partitionKey, type Candidate } from './matching';
import type { TzRegion } from './regions';
import type { GestureTarget, GestureType, LanguagePool, RoomState, Theme } from './room-types';

export interface RoomRow {
  id: string;
  language_pool: LanguagePool;
  quadrant: Quadrant;
  tz_region: TzRegion;
  seed_mood_id: string;
  theme: Theme;
  capacity: number;
  status: RoomState;
  here_now_broadcast: number;
  created_at: Date;
  opened_at: Date | null;
  joins_close_at: Date;
  memory_at: Date;
  purge_at: Date;
  // Room lanterns + Tonight's intention (migration 20261005000022): room totals only. Optional so rows built
  // elsewhere (fakes, older callers) stay valid; missing = nothing lit, no intention.
  lantern_progress?: number;
  lantern_hour_at?: Date | null;
  intention_key?: string | null;
  intention_holds?: number;
}

export interface MemberRow {
  member_id: string;
  room_id: string;
  user_id: string;
  pseudonym: string;
  mood_at_join: string;
  entry_quadrant: Quadrant;
  stage: Stage;
  hue: number | null;
  cosmetic: string | null;
  joined_at: Date;
  last_seen_at: Date;
  left_at: Date | null;
  survey_answered_at: Date | null;
  /** This member holds tonight's intention (only ever shown to this member). */
  holds_intention?: boolean;
}

export interface MemberViewRow {
  member_id: string;
  pseudonym: string;
  stage: Stage;
  hue: number | null;
  cosmetic: string | null;
  mood_at_join: string;
  live: boolean;
  muted: boolean;
  is_me: boolean;
}

export interface CountsRow {
  here_now: number;
  today: number;
}

export interface ReceivedGestureRow {
  id: string;
  type: GestureType;
  from_member_id: string;
  from_pseudonym: string;
  created_at: Date;
}

export interface SentGestureRow {
  id: string;
  type: GestureType;
  target: GestureTarget;
  to_member_id: string | null;
  created_at: Date;
}

export interface RoomGestureRow {
  id: string;
  type: GestureType;
  target: GestureTarget;
  created_at: Date;
}

export const ROOM_COLS = `r.id, r.language_pool, r.quadrant, r.tz_region, r.seed_mood_id, r.theme, r.capacity, r.status,
  r.here_now_broadcast, r.created_at, r.opened_at, r.joins_close_at, r.memory_at, r.purge_at,
  r.lantern_progress, r.lantern_hour_at, r.intention_key, r.intention_holds`;
const MEMBER_COLS = `m.member_id, m.room_id, m.user_id, m.pseudonym, m.mood_at_join, m.entry_quadrant, m.stage, m.hue,
  m.cosmetic, m.joined_at, m.last_seen_at, m.left_at, m.survey_answered_at, m.holds_intention`;

/** Here-now: current members seen within the live window, minus hidden accounts (deactivated / suspended). */
const HERE_NOW_SQL = (liveParam: string): string =>
  `coalesce(sum(case when m.left_at is null and m.last_seen_at > now() - make_interval(secs => ${liveParam})
                     and not ${HIDDEN_ACCOUNT_SQL('m.user_id')} then 1 else 0 end), 0)::int`;

/** Transaction-scoped lock per partition: matches into one partition serialise (no duplicate cold-start rooms). */
export async function lockPartition(q: Queryable, pool: LanguagePool, quadrant: Quadrant, region: TzRegion): Promise<void> {
  await q.query("select pg_advisory_xact_lock(hashtextextended('aura:room-partition:' || $1, 0))", [
    `${pool}:${quadrant}:${region}`,
  ]);
}

/** `public.rooms`, `room_members`, `room_gestures`, `room_mutes`, `room_survey_counts`. Never logs ids or pseudonyms. */
@Injectable()
export class RoomsRepository {
  async findRoom(q: Queryable, roomId: string): Promise<RoomRow | null> {
    const r = await q.query<RoomRow>(`select ${ROOM_COLS} from public.rooms r where r.id = $1`, [roomId]);
    return r.rows[0] ?? null;
  }

  /** Row lock: every join into a room takes it first, so capacity is checked race-free. */
  async lockRoom(q: Queryable, roomId: string): Promise<RoomRow | null> {
    const r = await q.query<RoomRow>(`select ${ROOM_COLS} from public.rooms r where r.id = $1 for update`, [roomId]);
    return r.rows[0] ?? null;
  }

  /** The caller's membership in a room that still exists. `includeLeft` for reports/blocks/survey after leaving. */
  async membership(q: Queryable, roomId: string, userId: string, includeLeft = false): Promise<MemberRow | null> {
    const r = await q.query<MemberRow>(
      `select ${MEMBER_COLS} from public.room_members m
        where m.room_id = $1 and m.user_id = $2 ${includeLeft ? '' : 'and m.left_at is null'}`,
      [roomId, userId],
    );
    return r.rows[0] ?? null;
  }

  async memberInRoom(q: Queryable, roomId: string, memberId: string): Promise<MemberRow | null> {
    const r = await q.query<MemberRow>(`select ${MEMBER_COLS} from public.room_members m where m.room_id = $1 and m.member_id = $2`, [
      roomId,
      memberId,
    ]);
    return r.rows[0] ?? null;
  }

  /** Step 0: the active room held for this quadrant (joined for it, else a room of it), not left, < 24 h old. */
  async activeRoomForQuadrant(q: Queryable, userId: string, quadrant: Quadrant): Promise<{ member: MemberRow; room: RoomRow } | null> {
    const r = await q.query<MemberRow & { room_json: RoomRow }>(
      `select ${MEMBER_COLS}, row_to_json(r.*) as room_json
         from public.room_members m join public.rooms r on r.id = m.room_id
        where m.user_id = $1 and m.left_at is null and r.memory_at > now()
          and (m.entry_quadrant = $2 or r.quadrant = $2)
        order by (m.entry_quadrant = $2) desc, m.joined_at desc
        limit 1`,
      [userId, quadrant],
    );
    const row = r.rows[0];
    if (!row) return null;
    const { room_json, ...member } = row;
    return { member, room: reviveRoom(room_json) };
  }

  /** Does the user hold an active room OF this quadrant (step 3 would give them a second one)? */
  async holdsRoomOfQuadrant(q: Queryable, userId: string, quadrant: Quadrant): Promise<boolean> {
    const r = await q.query(
      `select 1 from public.room_members m join public.rooms r on r.id = m.room_id
        where m.user_id = $1 and m.left_at is null and r.memory_at > now() and r.quadrant = $2 limit 1`,
      [userId, quadrant],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** New rooms joined for this quadrant in the last 24 h (re-entries are not joins). */
  async newJoins24h(q: Queryable, userId: string, quadrant: Quadrant): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.room_members
        where user_id = $1 and entry_quadrant = $2 and joined_at > now() - interval '24 hours'`,
      [userId, quadrant],
    );
    return r.rows[0]?.n ?? 0;
  }

  /** Joins in the last 24 h by home partition (pool × region) for one quadrant: the thin-merge demand. */
  async demand(q: Queryable, quadrant: Quadrant): Promise<Map<string, number>> {
    const r = await q.query<{ pool: LanguagePool; region: TzRegion; n: number }>(
      `select home_language_pool as pool, home_region as region, count(*)::int as n
         from public.room_members
        where entry_quadrant = $1 and joined_at > now() - interval '24 hours'
        group by 1, 2`,
      [quadrant],
    );
    return new Map(r.rows.map((x) => [partitionKey({ pool: x.pool, region: x.region }), x.n]));
  }

  /**
   * Joinable rooms (PRD: < 20 h old, < capacity current members, no block with the joiner) of one partition and the
   * given quadrants, excluding any room the joiner was ever a member of (no rejoining).
   */
  async candidates(
    q: Queryable,
    p: { pool: LanguagePool; region: TzRegion; quadrants: Quadrant[]; userId: string; liveWindowS: number },
  ): Promise<Candidate[]> {
    const r = await q.query<{ id: string; quadrant: Quadrant; seed_mood_id: string; created_at: Date; live: number; total: number }>(
      `select r.id, r.quadrant, r.seed_mood_id, r.created_at,
              coalesce(sum(case when m.left_at is null and m.last_seen_at > now() - make_interval(secs => $5)
                                then 1 else 0 end), 0)::int as live,
              count(m.member_id)::int as total
         from public.rooms r
         left join public.room_members m on m.room_id = r.id
        where r.kind = 'mood' and r.language_pool = $1 and r.tz_region = $2 and r.quadrant = any($3::text[])
          and r.joins_close_at > now()
          and not exists (select 1 from public.room_members mine where mine.room_id = r.id and mine.user_id = $4)
          and not exists (
            select 1 from public.room_members o
              join public.blocks b on (b.blocker_user_id = $4 and b.blocked_user_id = o.user_id)
                                   or (b.blocked_user_id = $4 and b.blocker_user_id = o.user_id)
             where o.room_id = r.id and o.left_at is null)
        group by r.id
       having count(m.member_id) filter (where m.left_at is null) < r.capacity`,
      [p.pool, p.region, p.quadrants, p.userId, p.liveWindowS],
    );
    return r.rows.map((x) => ({
      roomId: x.id,
      quadrant: x.quadrant,
      seedMoodId: x.seed_mood_id,
      live: x.live,
      total: x.total,
      createdAt: x.created_at,
    }));
  }

  /** Distinct people seen in the partition's rooms within the window (step 3 trigger: < 3 over 15 min). */
  async partitionLive(q: Queryable, pool: LanguagePool, quadrant: Quadrant, region: TzRegion, windowMin: number): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(distinct m.user_id)::int as n
         from public.room_members m join public.rooms r on r.id = m.room_id
        where r.language_pool = $1 and r.quadrant = $2 and r.tz_region = $3
          and m.last_seen_at > now() - make_interval(mins => $4)`,
      [pool, quadrant, region, windowMin],
    );
    return r.rows[0]?.n ?? 0;
  }

  /** Under the room lock: current members vs capacity, and whether any current member has a block with the joiner. */
  async joinCheck(q: Queryable, roomId: string, userId: string): Promise<{ active: number; total: number; blocked: boolean }> {
    const r = await q.query<{ active: number; total: number; blocked: boolean }>(
      `select count(*) filter (where m.left_at is null)::int as active,
              count(*)::int as total,
              exists (
                select 1 from public.room_members o
                  join public.blocks b on (b.blocker_user_id = $2 and b.blocked_user_id = o.user_id)
                                       or (b.blocked_user_id = $2 and b.blocker_user_id = o.user_id)
                 where o.room_id = $1 and o.left_at is null) as blocked
         from public.room_members m where m.room_id = $1`,
      [roomId, userId],
    );
    return r.rows[0] ?? { active: 0, total: 0, blocked: false };
  }

  async roomPseudonyms(q: Queryable, roomId: string): Promise<string[]> {
    const r = await q.query<{ pseudonym: string }>('select pseudonym from public.room_members where room_id = $1', [roomId]);
    return r.rows.map((x) => x.pseudonym);
  }

  /** The joiner's pseudonyms in their other current rooms (one account never shows the same name twice). */
  async activePseudonymsOf(q: Queryable, userId: string): Promise<string[]> {
    const r = await q.query<{ pseudonym: string }>(
      `select m.pseudonym from public.room_members m join public.rooms r on r.id = m.room_id
        where m.user_id = $1 and m.left_at is null and r.purge_at > now()`,
      [userId],
    );
    return r.rows.map((x) => x.pseudonym);
  }

  async avatarOf(q: Queryable, userId: string): Promise<{ stage: Stage; hue: number | null }> {
    const r = await q.query<{ stage: Stage; hue: number | null }>('select stage, hue from public.avatar_state where user_id = $1', [
      userId,
    ]);
    return r.rows[0] ?? { stage: 'spark', hue: null };
  }

  async createRoom(
    q: Queryable,
    p: {
      pool: LanguagePool;
      quadrant: Quadrant;
      region: TzRegion;
      seedMoodId: string;
      theme: Theme;
      capacity: number;
      joinCutoffH: number;
      memoryAfterH: number;
      purgeAfterD: number;
    },
  ): Promise<RoomRow> {
    const r = await q.query<RoomRow>(
      `insert into public.rooms as r (language_pool, quadrant, tz_region, seed_mood_id, theme, capacity,
                                      joins_close_at, memory_at, purge_at)
       values ($1, $2, $3, $4, $5, $6, now() + make_interval(hours => $7), now() + make_interval(hours => $8),
               now() + make_interval(hours => $8) + make_interval(days => $9))
       returning ${ROOM_COLS}`,
      [p.pool, p.quadrant, p.region, p.seedMoodId, p.theme, p.capacity, p.joinCutoffH, p.memoryAfterH, p.purgeAfterD],
    );
    return r.rows[0];
  }

  async insertMember(
    q: Queryable,
    p: {
      roomId: string;
      userId: string;
      pseudonym: string;
      moodId: string;
      entryQuadrant: Quadrant;
      homePool: LanguagePool;
      homeRegion: TzRegion;
      step: number;
      stage: Stage;
      hue: number | null;
    },
  ): Promise<MemberRow> {
    const r = await q.query<MemberRow>(
      `insert into public.room_members as m (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool,
                                             home_region, match_step, stage, hue)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       returning ${MEMBER_COLS}`,
      [p.roomId, p.userId, p.pseudonym, p.moodId, p.entryQuadrant, p.homePool, p.homeRegion, p.step, p.stage, p.hue],
    );
    return r.rows[0];
  }

  /** The 2nd member ever joined: forming → open (or straight into Lantern Hour). */
  async markOpened(q: Queryable, roomId: string, status: RoomState): Promise<RoomRow | null> {
    const r = await q.query<RoomRow>(
      `update public.rooms r set opened_at = now(), status = $2, status_changed_at = now()
        where r.id = $1 and r.opened_at is null
        returning ${ROOM_COLS}`,
      [roomId, status],
    );
    return r.rows[0] ?? null;
  }

  async counts(q: Queryable, roomId: string, liveWindowS: number): Promise<CountsRow> {
    const r = await q.query<CountsRow>(
      `select ${HERE_NOW_SQL('$2')} as here_now, count(*)::int as today from public.room_members m where m.room_id = $1`,
      [roomId, liveWindowS],
    );
    return r.rows[0] ?? { here_now: 0, today: 0 };
  }

  async countsFor(q: Queryable, roomIds: string[], liveWindowS: number): Promise<Map<string, CountsRow>> {
    if (roomIds.length === 0) return new Map();
    const r = await q.query<CountsRow & { room_id: string }>(
      `select m.room_id, ${HERE_NOW_SQL('$2')} as here_now, count(*)::int as today
         from public.room_members m where m.room_id = any($1::uuid[]) group by m.room_id`,
      [roomIds, liveWindowS],
    );
    return new Map(r.rows.map((x) => [x.room_id, { here_now: x.here_now, today: x.today }]));
  }

  /**
   * Current members as `viewer` sees them: minus accounts the viewer blocked (the blocked side sees no change) and
   * hidden accounts (deactivated / suspended); `muted` = the viewer muted them. Oldest first.
   */
  async membersFor(q: Queryable, roomId: string, viewer: { memberId: string; userId: string }, liveWindowS: number): Promise<MemberViewRow[]> {
    const r = await q.query<MemberViewRow>(
      `select m.member_id, m.pseudonym, m.stage, m.hue, m.cosmetic, m.mood_at_join,
              (m.last_seen_at > now() - make_interval(secs => $4)) as live,
              exists (select 1 from public.room_mutes mu where mu.muter_member_id = $2 and mu.muted_member_id = m.member_id) as muted,
              (m.member_id = $2) as is_me
         from public.room_members m
        where m.room_id = $1 and m.left_at is null
          and (m.member_id = $2 or (
                not exists (select 1 from public.blocks b where b.blocker_user_id = $3 and b.blocked_user_id = m.user_id)
            and not ${HIDDEN_ACCOUNT_SQL('m.user_id')}))
        order by m.joined_at, m.member_id`,
      [roomId, viewer.memberId, viewer.userId, liveWindowS],
    );
    return r.rows;
  }

  /** Delivered gestures to me, minus senders I muted or blocked and gestures I reported. Newest first. */
  async gesturesReceived(q: Queryable, me: { memberId: string; userId: string }, limit = 100): Promise<ReceivedGestureRow[]> {
    const r = await q.query<ReceivedGestureRow>(
      `select g.id, g.type, g.from_member_id, f.pseudonym as from_pseudonym, g.created_at
         from public.room_gestures g join public.room_members f on f.member_id = g.from_member_id
        where g.to_member_id = $1 and g.dropped is null
          and not exists (select 1 from public.room_mutes mu where mu.muter_member_id = $1 and mu.muted_member_id = g.from_member_id)
          and not exists (select 1 from public.blocks b where b.blocker_user_id = $2 and b.blocked_user_id = f.user_id)
          and not exists (select 1 from public.reports rp where rp.reporter_user_id = $2 and rp.target_gesture_id = g.id)
        order by g.created_at desc, g.id
        limit $3`,
      [me.memberId, me.userId, limit],
    );
    return r.rows;
  }

  /** Everything I sent, including silently dropped gestures (they always "look sent"). Newest first. */
  async gesturesSent(q: Queryable, memberId: string, limit = 100): Promise<SentGestureRow[]> {
    const r = await q.query<SentGestureRow>(
      `select g.id, g.type, g.target, g.to_member_id, g.created_at from public.room_gestures g
        where g.from_member_id = $1 order by g.created_at desc, g.id limit $2`,
      [memberId, limit],
    );
    return r.rows;
  }

  /** The room's anonymous feed: delivered gestures, no sender or recipient, minus ones I reported. Newest first. */
  async gesturesRecent(q: Queryable, roomId: string, viewerUserId: string, limit = 50): Promise<RoomGestureRow[]> {
    const r = await q.query<RoomGestureRow>(
      `select g.id, g.type, g.target, g.created_at from public.room_gestures g
        where g.room_id = $1 and g.dropped is null
          and not exists (select 1 from public.reports rp where rp.reporter_user_id = $2 and rp.target_gesture_id = g.id)
        order by g.created_at desc, g.id limit $3`,
      [roomId, viewerUserId, limit],
    );
    return r.rows;
  }

  /** Liveness. Returns whether the member was already live before this touch (null = not a current member). */
  async touch(q: Queryable, memberId: string, liveWindowS: number): Promise<{ wasLive: boolean } | null> {
    const r = await q.query<{ was_live: boolean }>(
      `with prev as (select member_id, last_seen_at from public.room_members where member_id = $1 and left_at is null for update)
       update public.room_members m set last_seen_at = now()
         from prev where m.member_id = prev.member_id
       returning (prev.last_seen_at > now() - make_interval(secs => $2)) as was_live`,
      [memberId, liveWindowS],
    );
    return r.rows[0] ? { wasLive: r.rows[0].was_live } : null;
  }

  async leave(q: Queryable, memberId: string): Promise<boolean> {
    const r = await q.query('update public.room_members set left_at = now() where member_id = $1 and left_at is null', [memberId]);
    return (r.rowCount ?? 0) > 0;
  }

  /** "Did you feel less alone?": ≥ 30 s in this room, and no survey answered in the last 24 h (any room). */
  async surveyEligible(q: Queryable, member: { memberId: string; userId: string }): Promise<boolean> {
    const r = await q.query<{ ok: boolean }>(
      `select (m.joined_at <= now() - interval '30 seconds')
              and not exists (select 1 from public.room_members x
                               where x.user_id = $2 and x.survey_answered_at > now() - interval '24 hours') as ok
         from public.room_members m where m.member_id = $1`,
      [member.memberId, member.userId],
    );
    return r.rows[0]?.ok ?? false;
  }

  /** Marks the membership (for the once-a-day rule) and adds 1 to the aggregate counter. Nothing else is stored. */
  async recordSurvey(q: Queryable, memberId: string, room: Pick<RoomRow, 'language_pool' | 'quadrant' | 'tz_region'>, answer: string): Promise<void> {
    await q.query('update public.room_members set survey_answered_at = now() where member_id = $1', [memberId]);
    await q.query(
      `insert into public.room_survey_counts (day, language_pool, quadrant, tz_region, answer, n)
       values ((now() at time zone 'utc')::date, $1, $2, $3, $4, 1)
       on conflict (day, language_pool, quadrant, tz_region, answer) do update set n = public.room_survey_counts.n + 1`,
      [room.language_pool, room.quadrant, room.tz_region, answer],
    );
  }

  async mute(q: Queryable, roomId: string, muter: string, muted: string): Promise<void> {
    await q.query(
      `insert into public.room_mutes (room_id, muter_member_id, muted_member_id) values ($1, $2, $3)
       on conflict (muter_member_id, muted_member_id) do nothing`,
      [roomId, muter, muted],
    );
  }

  async unmute(q: Queryable, muter: string, muted: string): Promise<void> {
    await q.query('delete from public.room_mutes where muter_member_id = $1 and muted_member_id = $2', [muter, muted]);
  }

  /** My rooms (not left, not purged), newest first, with my membership. */
  async myRooms(q: Queryable, userId: string): Promise<Array<{ member: MemberRow; room: RoomRow }>> {
    const r = await q.query<MemberRow & { room_json: RoomRow }>(
      `select ${MEMBER_COLS}, row_to_json(r.*) as room_json
         from public.room_members m join public.rooms r on r.id = m.room_id
        where m.user_id = $1 and m.left_at is null and r.purge_at > now()
        order by r.created_at desc, r.id`,
      [userId],
    );
    return r.rows.map(({ room_json, ...member }) => ({ member, room: reviveRoom(room_json) }));
  }
}

/** row_to_json turns timestamps into strings: bring them back to Dates. */
function reviveRoom(j: RoomRow): RoomRow {
  const d = (v: unknown): Date => (v instanceof Date ? v : new Date(String(v)));
  return {
    ...j,
    created_at: d(j.created_at),
    opened_at: j.opened_at === null ? null : d(j.opened_at),
    joins_close_at: d(j.joins_close_at),
    memory_at: d(j.memory_at),
    purge_at: d(j.purge_at),
    lantern_hour_at: j.lantern_hour_at === null || j.lantern_hour_at === undefined ? null : d(j.lantern_hour_at),
  };
}
