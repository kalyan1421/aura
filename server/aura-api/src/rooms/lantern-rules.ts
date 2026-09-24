import type { RoomState } from './room-types';

/**
 * F5 room lanterns and Tonight's intention (PRD 06b "Room lanterns and Tonight's intention (P1 · Milestone B)",
 * REQ-ROOM-13 / REQ-ROOM-14). Pure rules; the SQL side is lanterns.ts.
 *
 * - One shared lantern per room with **5 levels** [ASSUMPTION], lit only while the room is in Lantern Hour.
 * - **What adds light:** delivered gestures from human members within the rate limits (1 unit each) and breath cycles
 *   finished by humans in Breath Ripples sessions started from the room (`breathCycleWeight` units each).
 * - **Scaled to the room:** a level needs `max(minUnitsPerLevel, ceil(live × unitsPerMember))` units, with `live`
 *   measured when the light arrives — so a room of 3 can light it too [ASSUMPTION].
 * - **Additive only:** progress is stored as a running total (thousandths of a level) and only ever grows; nothing
 *   is recomputed from gesture rows, so leaving, removals, reflection removal or a change in "here now" can never dim
 *   it (and the DB refuses a lower value: trigger `rooms_lantern_additive`, migration 20261005000022).
 * - **Room totals only:** the views below carry the level and the hold count — never who added light or held, and not
 *   even the caller's own share (DS-10).
 */
export const LANTERN_MAX_LEVEL = 5;
export const LANTERN_PROGRESS_PER_LEVEL = 1000;
export const LANTERN_MAX_PROGRESS = LANTERN_MAX_LEVEL * LANTERN_PROGRESS_PER_LEVEL;

/** One delivered, within-limit human gesture. */
export const GESTURE_LIGHT_UNITS = 1;

export interface LanternConfig {
  /** Kill switch `room_lanterns_enabled` (missing flag = on). Off: no light is added and no lantern is shown. */
  enabled: boolean;
  /** Kill switch `room_intention_enabled` (missing flag = on). Off: no intention is shown or held. */
  intentionEnabled: boolean;
  unitsPerMember: number;
  minUnitsPerLevel: number;
  breathCycleWeight: number;
}

export const DEFAULT_LANTERN_CONFIG: LanternConfig = {
  enabled: true,
  intentionEnabled: true,
  unitsPerMember: 1.5,
  minUnitsPerLevel: 3,
  breathCycleWeight: 0.25,
};

/** Light units one level needs in a room with `liveMembers` here now (never fewer than one member). */
export function unitsPerLevel(liveMembers: number, cfg: Pick<LanternConfig, 'unitsPerMember' | 'minUnitsPerLevel'>): number {
  const live = Math.max(1, Math.floor(Number.isFinite(liveMembers) ? liveMembers : 1));
  return Math.max(1, cfg.minUnitsPerLevel, Math.ceil(live * cfg.unitsPerMember - 1e-9));
}

/**
 * Progress (thousandths of a level) that `units` of light add now. Rounded **up**, so exactly `unitsPerLevel` units
 * always complete a level (1/3 + 1/3 + 1/3 never stops at 0.999). Never negative.
 */
export function progressFor(units: number, liveMembers: number, cfg: Pick<LanternConfig, 'unitsPerMember' | 'minUnitsPerLevel'>): number {
  if (!Number.isFinite(units) || units <= 0) return 0;
  return Math.ceil((units * LANTERN_PROGRESS_PER_LEVEL) / unitsPerLevel(liveMembers, cfg) - 1e-9);
}

/** The only way progress changes: up, capped at a fully lit lantern. */
export function addProgress(current: number, delta: number): number {
  const base = Math.max(0, Math.min(LANTERN_MAX_PROGRESS, Math.floor(current || 0)));
  if (!Number.isFinite(delta) || delta <= 0) return base;
  return Math.min(LANTERN_MAX_PROGRESS, base + Math.ceil(delta));
}

export function levelOf(progress: number | null | undefined): number {
  const p = Math.max(0, Math.floor(progress ?? 0));
  return Math.min(LANTERN_MAX_LEVEL, Math.floor(p / LANTERN_PROGRESS_PER_LEVEL));
}

/** Units for human breath cycles (echo and guide seats never count: the caller passes human cycles only). */
export function breathLightUnits(humanCycles: number, cfg: Pick<LanternConfig, 'breathCycleWeight'>): number {
  if (!Number.isFinite(humanCycles) || humanCycles <= 0) return 0;
  return Math.floor(humanCycles) * cfg.breathCycleWeight;
}

/** Light is taken only while the room itself is in Lantern Hour (open rooms, 21:00–23:00 on its region clock). */
export const takesLight = (state: RoomState | 'purged'): boolean => state === 'lantern_hour';

/**
 * Tonight's intention rotates nightly: the n-th enabled preset of the room's language pool, n = the region-local
 * date of the window as a day number. Same night → same intention in every room of the pool.
 */
export function nightIndex(localDay: string): number {
  const t = Date.parse(`${localDay}T00:00:00Z`);
  return Number.isFinite(t) ? Math.floor(t / 86_400_000) : 0;
}

export function pickIntention(keys: readonly string[], localDay: string): string | null {
  if (keys.length === 0) return null;
  const i = ((nightIndex(localDay) % keys.length) + keys.length) % keys.length;
  return keys[i];
}

// ------------------------------------------------------------------ views (contracts/api/v1-rooms.md "Shared shapes")

/** The room's lantern: a room total. `active` = taking light now (the room is in Lantern Hour). */
export interface LanternView {
  level: number;
  maxLevel: number;
  active: boolean;
}

/** Tonight's intention: a preset key (the app localises it) and how many hold it — never who. */
export interface IntentionView {
  key: string;
  holds: number;
  /** Holding is possible now (the room is in Lantern Hour). After 23:00 it shows the total, read-only. */
  open: boolean;
}

export interface LanternRoomFields {
  lantern_progress?: number | null;
  lantern_hour_at?: Date | null;
  intention_key?: string | null;
  intention_holds?: number | null;
}

/**
 * Shown while the room is in Lantern Hour, and afterwards (incl. the memory: "Tonight's lantern") once the room has
 * had one. Null when the room never had a Lantern Hour or the kill switch is off.
 */
export function lanternView(room: LanternRoomFields, state: RoomState, cfg: Pick<LanternConfig, 'enabled'>): LanternView | null {
  if (!cfg.enabled) return null;
  const active = takesLight(state);
  if (!active && !room.lantern_hour_at) return null;
  return { level: levelOf(room.lantern_progress), maxLevel: LANTERN_MAX_LEVEL, active };
}

/** Shown once the room's intention for the night is set (at the start of its Lantern Hour). */
export function intentionView(room: LanternRoomFields, state: RoomState, cfg: Pick<LanternConfig, 'intentionEnabled'>): IntentionView | null {
  if (!cfg.intentionEnabled || !room.intention_key) return null;
  return { key: room.intention_key, holds: Math.max(0, room.intention_holds ?? 0), open: takesLight(state) };
}
