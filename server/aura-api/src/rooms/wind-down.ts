import { ApiError } from '../common/api-error';
import type { Queryable } from '../db/db';
import type { QuietConfig } from '../quiet/quiet-config';
import { isPaused } from '../quiet/quiet-flags';
import { WIND_DOWN_FLAG } from '../quiet/quiet-types';
import { WIND_DOWN_CUES, windDownLineup } from '../quiet/soundscapes';
import { addDays, localDate } from '../rules';
import { HIDDEN_ACCOUNT_SQL } from '../safety/safety-types';
import { Broadcast } from './broadcast';
import type { MatchingConfig } from './matching-config';
import { lanternWindow, zonedInstant, type TzRegion } from './regions';
import { stateOf } from './room-views';
import type { RoomRow } from './rooms.repository';

/**
 * F16 Lantern Hour wind-down (PRD 06b "Lantern Hour wind-down (Milestone C)"; REQ-QUIET-07; contracts/api/v1-quiet.md
 * §2). At 22:30 on the region clock [ASSUMPTION], rooms in Lantern Hour offer "Wind down together" for ~20 min: one
 * ambient track of base stems played locally from a common server `t0`, the F15 pacer (Calm 4/6) and preset text cues.
 * The room sees only "N winding down" — a room total; who opted in never leaves the server (DS-10).
 */
export type WindDownState = 'soon' | 'open';

export interface WindDownWindow {
  startsAt: Date;
  endsAt: Date;
  /** The region-local date of this night (tonight's lineup). */
  localDay: string;
}

export interface WindDownView {
  state: WindDownState;
  startsAt: string;
  startsAtMs: number;
  endsAt: string;
  endsAtMs: number;
  count: number;
  joined: boolean;
  pacer: { pattern: 'calm'; inhaleMs: number; exhaleMs: number };
  soundscape: { stems: string[] };
  cues: Array<{ atS: number; key: string }>;
}

/** The `wind_down` broadcast (room total; the room topic's §2.4 payload without `at`). */
export interface WindDownSignal {
  state: WindDownState | 'ended';
  count: number;
}

export const windDownPaused = (): ApiError =>
  new ApiError(503, 'wind_down_paused', 'The wind-down is resting tonight. The Sanctuary night wind-down is always there.');
export const windDownClosed = (): ApiError => ApiError.conflict('wind_down_closed', 'The wind-down is not open right now.');

/**
 * Tonight's wind-down for a room that is in Lantern Hour now: [22:30, 22:50) on the region clock, only if it fits
 * inside the Lantern Hour window (a config that puts it outside simply offers none). Null outside Lantern Hour.
 */
export function windDownWindow(room: RoomRow, now: Date, mcfg: MatchingConfig, qcfg: Pick<QuietConfig, 'windDown'>): WindDownWindow | null {
  if (stateOf(room, now, mcfg) !== 'lantern_hour') return null;
  const lh = lanternWindow(room.tz_region, now, mcfg.lanternStart, mcfg.lanternEnd);
  if (!lh.active) return null;
  let day = localDate(lh.startsAt, lh.timezone);
  let startsAt = zonedInstant(lh.timezone, day, qcfg.windDown.start.hour, qcfg.windDown.start.minute);
  if (startsAt.getTime() < lh.startsAt.getTime()) {
    day = addDays(day, 1); // a window that crosses midnight
    startsAt = zonedInstant(lh.timezone, day, qcfg.windDown.start.hour, qcfg.windDown.start.minute);
  }
  const endsAt = new Date(startsAt.getTime() + qcfg.windDown.lengthMin * 60_000);
  if (startsAt.getTime() < lh.startsAt.getTime() || endsAt.getTime() > lh.endsAt.getTime()) return null;
  return { startsAt, endsAt, localDay: day };
}

export function windDownStateAt(w: WindDownWindow, now: Date): WindDownState | null {
  const t = now.getTime();
  if (t < w.startsAt.getTime()) return 'soon';
  if (t < w.endsAt.getTime()) return 'open';
  return null;
}

/**
 * "N winding down": opted in tonight, still a member, live now (the rooms' own liveness: seen within the live window
 * on the DB clock, like "here now"), not hidden. Never who.
 */
export async function windDownCount(q: Queryable, roomId: string, w: WindDownWindow, liveWindowS: number): Promise<number> {
  const r = await q.query<{ n: number }>(
    `select count(*)::int as n from public.room_members m
      where m.room_id = $1 and m.left_at is null and m.wind_down_at >= $2
        and m.last_seen_at > now() - make_interval(secs => $3)
        and not ${HIDDEN_ACCOUNT_SQL('m.user_id')}`,
    [roomId, w.startsAt, liveWindowS],
  );
  return r.rows[0]?.n ?? 0;
}

export async function windDownPausedFor(q: Queryable, region: TzRegion): Promise<boolean> {
  const r = await q.query<{ enabled: boolean; payload: unknown }>('select enabled, payload from public.feature_flags where key = $1', [WIND_DOWN_FLAG]);
  return isPaused(r.rows[0], region);
}

/** Built field by field (a unit test pins the keys): times, a count, the caller's own flag, presets. */
export function windDownView(w: WindDownWindow, state: WindDownState, count: number, joined: boolean, qcfg: Pick<QuietConfig, 'windDown'>): WindDownView {
  return {
    state,
    startsAt: w.startsAt.toISOString(),
    startsAtMs: w.startsAt.getTime(),
    endsAt: w.endsAt.toISOString(),
    endsAtMs: w.endsAt.getTime(),
    count: Math.max(0, Math.floor(count)),
    joined,
    pacer: { pattern: 'calm', inhaleMs: qcfg.windDown.inhaleMs, exhaleMs: qcfg.windDown.exhaleMs },
    soundscape: { stems: windDownLineup(w.localDay) },
    cues: WIND_DOWN_CUES.map((c) => ({ atS: c.atS, key: c.key })),
  };
}

/**
 * The room's wind-down right now as a room total (for the broadcast and the tick): null when there is none (outside
 * Lantern Hour, after it ended, or paused for the region).
 */
export async function windDownSignalFor(q: Queryable, room: RoomRow, now: Date, mcfg: MatchingConfig, qcfg: QuietConfig): Promise<WindDownSignal | null> {
  const w = windDownWindow(room, now, mcfg, qcfg);
  const state = w ? windDownStateAt(w, now) : null;
  if (!w || !state || (await windDownPausedFor(q, room.tz_region))) return null;
  return { state, count: state === 'open' ? await windDownCount(q, room.id, w, mcfg.liveWindowS) : 0 };
}

export const signalKey = (s: WindDownSignal | null): string | null => (s ? `${s.state}:${s.count}` : null);

/**
 * Broadcasts `wind_down` when the room's signal differs from the last one sent (stored on the room), so each change
 * goes out once. An ended wind-down (a signal before, none now) goes out as `{ state: 'ended', count: 0 }`.
 */
export async function syncWindDownBroadcast(q: Queryable, roomId: string, signal: WindDownSignal | null, now: Date): Promise<boolean> {
  const key = signalKey(signal);
  const r = await q.query<{ wind_down_broadcast: string | null }>('select wind_down_broadcast from public.rooms where id = $1', [roomId]);
  const cached = r.rows[0]?.wind_down_broadcast ?? null;
  if (key === cached) return false;
  await q.query('update public.rooms set wind_down_broadcast = $2 where id = $1', [roomId, key]);
  await Broadcast.windDown(q, roomId, signal ?? { state: 'ended', count: 0 }, now);
  return true;
}
