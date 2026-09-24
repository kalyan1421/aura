import type { Queryable } from '../db/db';
import { localDate } from '../rules';
import { Broadcast } from './broadcast';
import { addProgress, breathLightUnits, levelOf, pickIntention, progressFor, takesLight, GESTURE_LIGHT_UNITS, LANTERN_MAX_PROGRESS } from './lantern-rules';
import { loadMatchingConfig, type MatchingConfig } from './matching-config';
import { lanternWindow } from './regions';
import { roomInfo, roomStateView, stateOf } from './room-views';
import { ROOM_COLS, RoomsRepository, type RoomRow } from './rooms.repository';

/**
 * SQL side of room lanterns and Tonight's intention (rules: lantern-rules.ts; schema: migration 20261005000022).
 * Every write here only ever raises a room total (the DB trigger `rooms_lantern_additive` refuses anything else) and
 * every broadcast is the whole-room `room_state` (DS-10: no member id, no per-member value). Runs inside the caller's
 * transaction, so a broadcast goes out only if the write commits. Never logs ids.
 */

const repo = new RoomsRepository();

/**
 * At the start of a room's Lantern Hour: pin the night (`lantern_hour_at` = the window's start) and tonight's
 * intention (rotated from the room's language-pool presets by the region-local date). Idempotent and write-once
 * (the first caller wins; later calls return the stored row). A no-op outside the room's Lantern Hour. Returns the
 * current row.
 */
export async function ensureLanternNight(q: Queryable, room: RoomRow, now: Date, cfg: MatchingConfig): Promise<RoomRow> {
  if (room.lantern_hour_at || !takesLight(stateOf(room, now, cfg))) return room;
  const w = lanternWindow(room.tz_region, now, cfg.lanternStart, cfg.lanternEnd);
  const presets = await q.query<{ key: string }>(
    'select key from public.room_intention_presets where language_pool = $1 and enabled order by position, key',
    [room.language_pool],
  );
  const key = pickIntention(
    presets.rows.map((p) => p.key),
    localDate(w.startsAt, w.timezone),
  );
  const r = await q.query<RoomRow>(
    `update public.rooms r set lantern_hour_at = $2, intention_key = coalesce(r.intention_key, $3)
      where r.id = $1 and r.lantern_hour_at is null
      returning ${ROOM_COLS}`,
    [room.id, w.startsAt, key],
  );
  if (r.rows[0]) return r.rows[0];
  return (await repo.findRoom(q, room.id)) ?? room;
}

export interface LightResult {
  /** Level before and after (0–5). A broadcast went out when they differ. */
  before: number;
  after: number;
}

/**
 * Adds `units` of light to the room's lantern — only while the room is in Lantern Hour and the kill switch is on.
 * The light a level needs is scaled by the members live right now. Broadcasts `room_state` when the level rises
 * (at most 5 times a night), never per gesture. Returns null when nothing was added.
 */
export async function addLanternLight(q: Queryable, roomId: string, units: number, now: Date, cfg: MatchingConfig): Promise<LightResult | null> {
  if (!cfg.lanterns.enabled || !(units > 0)) return null;
  let room = await repo.findRoom(q, roomId);
  if (!room || !takesLight(stateOf(room, now, cfg))) return null;
  room = await ensureLanternNight(q, room, now, cfg);
  if ((room.lantern_progress ?? 0) >= LANTERN_MAX_PROGRESS) return null;

  const live = (await repo.counts(q, roomId, cfg.liveWindowS)).here_now;
  const delta = progressFor(units, live, cfg.lanterns);
  if (delta <= 0) return null;
  // Atomic under the row lock: concurrent senders both add (no lost update), and the cap holds.
  const r = await q.query<RoomRow & { before_progress: number }>(
    `with old as (select id, lantern_progress from public.rooms where id = $1 for update)
     update public.rooms r set lantern_progress = least($3::int, old.lantern_progress + $2::int)
       from old where r.id = old.id
     returning old.lantern_progress as before_progress, ${ROOM_COLS}`,
    [roomId, delta, LANTERN_MAX_PROGRESS],
  );
  const updated = r.rows[0];
  if (!updated) return null;
  const { before_progress, ...row } = updated;
  const before = levelOf(before_progress);
  const after = levelOf(addProgress(before_progress, delta));
  if (after > before) await Broadcast.roomState(q, roomId, roomStateView(roomInfo(row, now, cfg)), now);
  return { before, after };
}

/** One delivered, within-limit gesture from a human member (gestures.service.ts calls this after delivery). */
export function addGestureLight(q: Queryable, roomId: string, now: Date, cfg: MatchingConfig): Promise<LightResult | null> {
  return addLanternLight(q, roomId, GESTURE_LIGHT_UNITS, now, cfg);
}

/**
 * **Hook for F7 Breath Ripples** (src/ripples): call once when a session that was started from a room ends, inside
 * the transaction that records the session, with the number of breath cycles finished by **human** seats only —
 * never echo or guide seats (PRD F5: "echoes, guide lights, staff … add nothing"). Adds light only while that room is
 * in Lantern Hour; otherwise a no-op. Returns the lantern level afterwards, or null when nothing was added.
 *
 *   await addBreathCyclesToRoomLantern(tx, session.roomId, humanCyclesFinished);
 */
export async function addBreathCyclesToRoomLantern(
  q: Queryable,
  roomId: string,
  humanCycles: number,
  now = new Date(),
  cfg?: MatchingConfig,
): Promise<{ level: number } | null> {
  const config = cfg ?? (await loadMatchingConfig(q));
  const units = breathLightUnits(humanCycles, config.lanterns);
  const r = await addLanternLight(q, roomId, units, now, config);
  return r ? { level: r.after } : null;
}

/**
 * Holds tonight's intention for one membership: at most once (the member flag can't be undone), +1 on the room
 * total, then `room_state` to the room. Returns the updated row and whether this call added the hold.
 */
export async function holdIntentionFor(q: Queryable, room: RoomRow, memberId: string): Promise<{ room: RoomRow; added: boolean }> {
  const m = await q.query(
    'update public.room_members set holds_intention = true where member_id = $1 and room_id = $2 and not holds_intention',
    [memberId, room.id],
  );
  if ((m.rowCount ?? 0) === 0) return { room: (await repo.findRoom(q, room.id)) ?? room, added: false };
  const r = await q.query<RoomRow>(
    `update public.rooms r set intention_holds = r.intention_holds + 1 where r.id = $1 returning ${ROOM_COLS}`,
    [room.id],
  );
  return { room: r.rows[0] ?? room, added: true };
}
