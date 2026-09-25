import { Injectable } from '@nestjs/common';
import { profileRequired } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { blockSet } from '../ripples/matcher';
import { isTzRegion, regionForTimeZone, type TzRegion } from '../rooms/regions';
import { assertGuidelinesAccepted } from '../safety/guidelines';
import { HIDDEN_ACCOUNT_SQL } from '../safety/safety-types';
import { assertRoomAccess } from '../safety/safety.queries';
import { blockFor } from './blocks';
import { loadQuietConfig, type QuietConfig } from './quiet-config';
import { regionPaused } from './quiet-flags';
import { QUIET_FLAG, type QuietMode } from './quiet-types';
import { sessionView, type QuietSessionRow, type QuietSessionView } from './quiet-views';
import { invalidTimezone, joinRequestSchema, notFound, pathId, quietPaused } from './quiet.schema';
import { planQuietPlacement, type QuietCandidate } from './placement';
import { newSoundscapeSeed } from './soundscapes';

export interface SessionResponse {
  session: QuietSessionView;
}

interface ActiveMember {
  member_id: string;
  session_id: string;
  home_region: TzRegion;
  mode: QuietMode;
  t0: Date;
  ends_at: Date;
}

const SESSION_COLS = 's.id, s.mode, s.tz_region, s.t0, s.ends_at, s.soundscape_seed, s.capacity, s.created_at';

/** The default busiest region (as F5 `matching_config.default_region`; launch is mostly south_asia). */
const DEFAULT_REGION: TzRegion = 'south_asia';

/**
 * Live people in one session: current members seen within the live window, minus hidden accounts (deactivated /
 * suspended). The only thing about people that ever leaves the server (REQ-QUIET-01).
 */
export async function liveCount(q: Queryable, sessionId: string, now: Date, cfg: Pick<QuietConfig, 'liveWindowS'>): Promise<number> {
  const r = await q.query<{ n: number }>(
    `select count(*)::int as n from public.quiet_members m
      where m.session_id = $1 and m.left_at is null
        and m.last_seen_at > $2::timestamptz - make_interval(secs => $3)
        and not ${HIDDEN_ACCOUNT_SQL('m.user_id')}`,
    [sessionId, now, cfg.liveWindowS],
  );
  return r.rows[0]?.n ?? 0;
}

/**
 * F16 Quiet Together sessions (contracts/api/v1-quiet.md §1.1–§1.3): drop-in join, the heartbeat (which also moves you
 * into the next block), and a silent leave. Views are built only by quiet-views.ts (counts only). Nothing here touches
 * Starlight, streaks, keepsakes or any per-person record of time spent (REQ-QUIET-04). Never logs ids.
 */
@Injectable()
export class QuietService {
  constructor(private readonly db: DbService) {}

  // ------------------------------------------------------------------ §1.1 join
  async join(userId: string, body: unknown, now = new Date()): Promise<SessionResponse> {
    const req = parseOrThrow(joinRequestSchema, body);
    const profile = await this.profileOf(userId);
    if (!profile) throw profileRequired();
    await assertRoomAccess(this.db, userId);
    await assertGuidelinesAccepted(this.db, userId); // REQ-SAFE-04: guidelines before any stranger surface
    const homeRegion = this.regionOf(req.timezone ?? profile.timezone, now);

    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadQuietConfig(tx);
      if (await regionPaused(tx, QUIET_FLAG, homeRegion)) throw quietPaused();

      const current = await this.activeMembership(tx, userId);
      if (current && current.mode === req.mode && now.getTime() < current.ends_at.getTime() && now.getTime() >= current.t0.getTime()) {
        await this.touch(tx, current.member_id, now);
        return { session: await this.view(tx, current.session_id, cfg, now) };
      }
      if (current) await this.leaveMember(tx, current.member_id, now);
      const sessionId = await this.place(tx, userId, req.mode, homeRegion, cfg, now);
      return { session: await this.view(tx, sessionId, cfg, now) };
    });
  }

  // ------------------------------------------------------------------ §1.2 heartbeat (+ the next block)
  async heartbeat(userId: string, sessionIdParam: string, now = new Date()): Promise<SessionResponse> {
    const sessionId = pathId(sessionIdParam);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadQuietConfig(tx);
      const me = await this.activeMembership(tx, userId);
      if (!me || me.session_id !== sessionId) throw notFound();
      if (now.getTime() < me.ends_at.getTime()) {
        await this.touch(tx, me.member_id, now);
        return { session: await this.view(tx, sessionId, cfg, now) };
      }
      // The block ended: "The next session starts at 10:00." — the next block of the same mode, same rules.
      await this.leaveMember(tx, me.member_id, now);
      if (await regionPaused(tx, QUIET_FLAG, me.home_region)) throw quietPaused();
      const next = await this.place(tx, userId, me.mode, me.home_region, cfg, now);
      return { session: await this.view(tx, next, cfg, now) };
    });
  }

  // ------------------------------------------------------------------ §1.3 leave (costs nothing)
  async leave(userId: string, sessionIdParam: string, now = new Date()): Promise<void> {
    let sessionId: string;
    try {
      sessionId = pathId(sessionIdParam);
    } catch {
      return; // idempotent: an unknown id is a no-op
    }
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      await tx.query(
        `update public.quiet_members set left_at = greatest(joined_at, $3::timestamptz)
          where session_id = $1 and user_id = $2 and left_at is null`,
        [sessionId, userId, now],
      );
    });
  }

  // ------------------------------------------------------------------ placement
  /**
   * Under the mode's lock: the current block's sessions of this mode (every region: a thin region merges), the
   * joiner's blocks (both directions), then the planner. A new session starts on its region's block.
   */
  private async place(tx: Tx, userId: string, mode: QuietMode, homeRegion: TzRegion, cfg: QuietConfig, now: Date): Promise<string> {
    await tx.query("select pg_advisory_xact_lock(hashtextextended('aura:quiet-placement:' || $1, 0))", [mode]);
    const rows = await tx.query<{ id: string; tz_region: TzRegion; created_at: Date; live: number; member_user_ids: string[] }>(
      `select s.id, s.tz_region, s.created_at,
              count(m.member_id) filter (where m.left_at is null and m.last_seen_at > $2::timestamptz - make_interval(secs => $3)
                                           and not ${HIDDEN_ACCOUNT_SQL('m.user_id')})::int as live,
              coalesce(array_agg(m.user_id) filter (where m.left_at is null), '{}'::uuid[]) as member_user_ids
         from public.quiet_sessions s
         left join public.quiet_members m on m.session_id = s.id
        where s.mode = $1 and s.t0 <= $2 and s.ends_at > $2
        group by s.id`,
      [mode, now, cfg.liveWindowS],
    );
    const candidates: QuietCandidate[] = rows.rows
      .filter((r) => isTzRegion(r.tz_region))
      .map((r) => ({ sessionId: r.id, region: r.tz_region, live: r.live, memberUserIds: r.member_user_ids, createdAtMs: r.created_at.getTime() }));
    const blocks = await tx.query<{ blocker: string; blocked: string }>(
      `select blocker_user_id as blocker, blocked_user_id as blocked from public.blocks where blocker_user_id = $1 or blocked_user_id = $1`,
      [userId],
    );
    const plan = planQuietPlacement({ userId, homeRegion }, candidates, blockSet(blocks.rows), {
      capacity: cfg.capacity,
      thinLiveMin: cfg.thinLiveMin,
      defaultRegion: DEFAULT_REGION,
    });

    let sessionId = plan.sessionId;
    if (!sessionId) {
      const block = blockFor(plan.region, now, cfg.blockMin);
      const ins = await tx.query<{ id: string }>(
        `insert into public.quiet_sessions (mode, tz_region, t0, ends_at, soundscape_seed, capacity, purge_at)
         values ($1, $2, $3, $4, $5, $6, $4::timestamptz + make_interval(days => $7)) returning id`,
        [mode, plan.region, block.t0, block.endsAt, newSoundscapeSeed(), cfg.capacity, cfg.retentionD],
      );
      sessionId = ins.rows[0].id;
    }
    await tx.query(
      `insert into public.quiet_members (session_id, user_id, home_region, joined_at, last_seen_at) values ($1, $2, $3, $4, $4)`,
      [sessionId, userId, homeRegion, now],
    );
    return sessionId;
  }

  // ------------------------------------------------------------------ helpers
  private async activeMembership(q: Queryable, userId: string): Promise<ActiveMember | null> {
    const r = await q.query<ActiveMember>(
      `select m.member_id, m.session_id, m.home_region, s.mode, s.t0, s.ends_at
         from public.quiet_members m join public.quiet_sessions s on s.id = m.session_id
        where m.user_id = $1 and m.left_at is null`,
      [userId],
    );
    return r.rows[0] ?? null;
  }

  private async touch(q: Queryable, memberId: string, now: Date): Promise<void> {
    await q.query('update public.quiet_members set last_seen_at = greatest(last_seen_at, $2::timestamptz) where member_id = $1', [memberId, now]);
  }

  private async leaveMember(q: Queryable, memberId: string, now: Date): Promise<void> {
    await q.query('update public.quiet_members set left_at = greatest(joined_at, $2::timestamptz) where member_id = $1 and left_at is null', [
      memberId,
      now,
    ]);
  }

  private async view(q: Queryable, sessionId: string, cfg: QuietConfig, now: Date): Promise<QuietSessionView> {
    const r = await q.query<QuietSessionRow>(`select ${SESSION_COLS} from public.quiet_sessions s where s.id = $1`, [sessionId]);
    const s = r.rows[0];
    if (!s) throw notFound();
    return sessionView(s, await liveCount(q, sessionId, now, cfg), cfg, now);
  }

  private regionOf(tz: string, now: Date): TzRegion {
    try {
      return regionForTimeZone(tz, now);
    } catch {
      throw invalidTimezone();
    }
  }

  private async profileOf(userId: string): Promise<{ timezone: string } | null> {
    const r = await this.db.query<{ timezone: string }>('select timezone from public.profiles where user_id = $1', [userId]);
    return r.rows[0] ?? null;
  }
}
