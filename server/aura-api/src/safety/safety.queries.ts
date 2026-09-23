import { ApiError } from '../common/api-error';
import type { Queryable } from '../db/db';
import { ACTIVE_SANCTION_SQL, ROOM_ACCESS_SANCTIONS_SQL, SHADOW_SANCTIONS_SQL } from './safety-types';

/** Plain SQL helpers shared by rooms, safety and the worker (no DI, like the account purge helpers). */

export type RoomAccessState = 'available' | 'suspended' | 'closed';

export interface RoomAccess {
  state: RoomAccessState;
  /** End of the suspension; null = until lifted (pause pending review, social ban) or not suspended. */
  until: Date | null;
}

/** The account's room access from its active sanctions: account ban → closed; suspension/pause/social ban → suspended. */
export async function roomAccess(q: Queryable, userId: string): Promise<RoomAccess> {
  const r = await q.query<{ kind: string; ends_at: Date | null }>(
    `select s.kind, s.ends_at from public.sanctions s
      where s.user_id = $1 and s.kind in ${ROOM_ACCESS_SANCTIONS_SQL} and ${ACTIVE_SANCTION_SQL('s')}`,
    [userId],
  );
  if (r.rows.some((x) => x.kind === 'account_ban')) return { state: 'closed', until: null };
  if (r.rows.length === 0) return { state: 'available', until: null };
  const open = r.rows.some((x) => x.ends_at === null);
  const until = open ? null : new Date(Math.max(...r.rows.map((x) => (x.ends_at as Date).getTime())));
  return { state: 'suspended', until };
}

export const accountClosed = (): ApiError =>
  ApiError.forbidden('account_closed', "This account was closed for breaking Aura's rules.");
export const roomsSuspended = (): ApiError =>
  ApiError.forbidden('rooms_suspended', 'Rooms are paused for this account right now. GET /v1/safety/me says until when.');

/** Every `/v1/rooms*` route: 403 for suspended/paused/closed accounts. */
export async function assertRoomAccess(q: Queryable, userId: string): Promise<void> {
  const a = await roomAccess(q, userId);
  if (a.state === 'closed') throw accountClosed();
  if (a.state === 'suspended') throw roomsSuspended();
}

/** `/v1/safety*`: reporting and blocking stay available to suspended accounts ("help is never locked"), not closed ones. */
export async function assertNotClosed(q: Queryable, userId: string): Promise<void> {
  if ((await roomAccess(q, userId)).state === 'closed') throw accountClosed();
}

/** Gestures of a shadow-muted account are dropped silently (never visible to them). */
export async function isShadowMuted(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query(
    `select 1 from public.sanctions s where s.user_id = $1 and s.kind in ${SHADOW_SANCTIONS_SQL} and ${ACTIVE_SANCTION_SQL('s')} limit 1`,
    [userId],
  );
  return (r.rowCount ?? 0) > 0;
}

export async function hasActiveSanction(q: Queryable, userId: string, kind: string): Promise<boolean> {
  const r = await q.query(`select 1 from public.sanctions s where s.user_id = $1 and s.kind = $2 and ${ACTIVE_SANCTION_SQL('s')} limit 1`, [
    userId,
    kind,
  ]);
  return (r.rowCount ?? 0) > 0;
}

/** A block in either direction between two accounts. */
export async function blockBetween(q: Queryable, a: string, b: string): Promise<boolean> {
  const r = await q.query(
    `select 1 from public.blocks
      where (blocker_user_id = $1 and blocked_user_id = $2) or (blocker_user_id = $2 and blocked_user_id = $1) limit 1`,
    [a, b],
  );
  return (r.rowCount ?? 0) > 0;
}

/** Hidden from other members: deactivated (deletion pending) or room access taken away. */
export async function isHiddenAccount(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query<{ hidden: boolean }>(
    `select exists (select 1 from public.account_deletions d where d.user_id = $1)
         or exists (select 1 from public.sanctions s where s.user_id = $1 and s.kind in ${ROOM_ACCESS_SANCTIONS_SQL}
                     and ${ACTIVE_SANCTION_SQL('s')}) as hidden`,
    [userId],
  );
  return r.rows[0]?.hidden ?? false;
}

/** Under 18 by stored DOB (F8 `user_is_minor`). Server-side only: never returned to any client (DS-10). */
export async function anyMinor(q: Queryable, userIds: Array<string | null | undefined>): Promise<boolean> {
  const ids = [...new Set(userIds.filter((x): x is string => !!x))];
  if (ids.length === 0) return false;
  const r = await q.query<{ minor: boolean }>('select bool_or(public.user_is_minor(u)) as minor from unnest($1::uuid[]) u', [ids]);
  return r.rows[0]?.minor ?? false;
}

export interface SafetyConfig {
  reportDailyLimit: number;
  under13ReportsToPause: number;
  evidenceHoldDays: number;
  strikeTtlDays: number;
}

export async function loadSafetyConfig(q: Queryable): Promise<SafetyConfig> {
  const r = await q.query<{
    report_daily_limit: number;
    under13_reports_to_pause: number;
    evidence_hold_days: number;
    strike_ttl_days: number;
  }>('select report_daily_limit, under13_reports_to_pause, evidence_hold_days, strike_ttl_days from public.safety_config where id');
  const x = r.rows[0];
  return x
    ? {
        reportDailyLimit: x.report_daily_limit,
        under13ReportsToPause: x.under13_reports_to_pause,
        evidenceHoldDays: x.evidence_hold_days,
        strikeTtlDays: x.strike_ttl_days,
      }
    : { reportDailyLimit: 20, under13ReportsToPause: 2, evidenceHoldDays: 180, strikeTtlDays: 90 };
}
