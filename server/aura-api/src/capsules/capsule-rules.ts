/**
 * contracts/rules/RULES.md §9 — F4 time capsules (vectors: contracts/rules/vectors/capsules.json).
 * Pure functions: the app runs the same rules offline (Dart, packages/aura_domain); the server uses the window
 * (seal validation), the unlock instant (the "capsule unlocked" push) and the arming / cooldown constants.
 * `pickTrigger` is implemented here only so both implementations are held to the same vectors.
 */
import { addDays, isLocalDay, localDate, wallClock, type Quadrant } from '../rules';

/** A date capsule unlocks 7 days … 5 years after the seal's calendar date. */
export const UNLOCK_MIN_DAYS = 7;
export const UNLOCK_MAX_YEARS = 5;
/** …at 10:00 wall-clock time in the user's current zone. */
export const UNLOCK_HOUR = 10;
/** A trigger capsule arms 24 h after sealing (PRD F4, REQ-CAP-02). */
export const TRIGGER_ARMING_MS = 24 * 3600_000;
/** After any trigger capsule fires, none fires for 7 × 24 h (global cooldown, REQ-CAP-03). */
export const TRIGGER_COOLDOWN_MS = 168 * 3600_000;

const DAY_MS = 86_400_000;
const pad = (n: number, w = 2): string => String(n).padStart(w, '0');

/** `day` + `years`, same month and day; Feb 29 → Feb 28 when the target year has none. */
export function addYears(day: string, years: number): string {
  if (!isLocalDay(day)) throw new RangeError(`invalid local day: ${day}`);
  const [y, m, d] = day.split('-').map(Number);
  const year = y + years;
  const daysInMonth = new Date(Date.UTC(year, m, 0)).getUTCDate();
  return `${pad(year, 4)}-${pad(m)}-${pad(Math.min(d, daysInMonth))}`;
}

/** Inclusive bounds for `unlockLocalDate`, from the seal's calendar date in `tz` (no 04:00 shift). */
export function unlockWindow(sealedAt: string | Date, tz: string): { min: string; max: string } {
  const sealDate = localDate(sealedAt, tz);
  return { min: addDays(sealDate, UNLOCK_MIN_DAYS), max: addYears(sealDate, UNLOCK_MAX_YEARS) };
}

/** RULES.md §9 `window`. */
export function isValidUnlockDate(sealedAt: string | Date, tz: string, unlockLocalDate: string): boolean {
  if (!isLocalDay(unlockLocalDate)) return false;
  const { min, max } = unlockWindow(sealedAt, tz);
  return unlockLocalDate >= min && unlockLocalDate <= max;
}

/** UTC offset (ms) of `tz` at the instant `ms` (whole seconds). */
function offsetAt(ms: number, tz: string): number {
  const w = wallClock(new Date(ms), tz);
  return Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute, w.second) - Math.floor(ms / 1000) * 1000;
}

/**
 * The instant at which the wall clock in `tz` reads `hour:minute` on `day`. A wall time that occurs twice (DST
 * fall-back) → the earlier instant; one that does not exist (DST gap) → shifted forward by the gap, i.e. read
 * with the offset in force before the transition (the `compatible` rule of java.time / Temporal).
 */
export function zonedInstant(day: string, hour: number, minute: number, tz: string): Date {
  if (!isLocalDay(day)) throw new RangeError(`invalid local day: ${day}`);
  const [y, m, d] = day.split('-').map(Number);
  const wall = Date.UTC(y, m - 1, d, hour, minute);
  const before = offsetAt(wall - DAY_MS, tz);
  const offsets = new Set([before, offsetAt(wall, tz), offsetAt(wall + DAY_MS, tz)]);
  const exact = [...offsets].map((o) => wall - o).filter((t) => offsetAt(t, tz) === wall - t);
  if (exact.length > 0) return new Date(Math.min(...exact));
  return new Date(wall - before);
}

/** RULES.md §9 `unlock_at`: 10:00 local on `localDate` in `tz` (always the user's current zone). */
export function unlockAt(localDate: string, tz: string): Date {
  return zonedInstant(localDate, UNLOCK_HOUR, 0, tz);
}

/** A trigger capsule may fire from this instant (seal + 24 h). */
export function armedAtFor(sealedAt: string | Date): Date {
  return new Date(new Date(sealedAt).getTime() + TRIGGER_ARMING_MS);
}

/** A fire at `firedAt` holds every trigger capsule until this instant. */
export function cooldownUntilFor(firedAt: string | Date): Date {
  return new Date(new Date(firedAt).getTime() + TRIGGER_COOLDOWN_MS);
}

export interface TriggerCapsule {
  id: string;
  unlockType: 'date' | 'mood';
  triggerMoodId?: string | null;
  triggerQuadrant?: Quadrant | null;
  sealedAt: string;
  armedAt?: string | null;
  firedAt?: string | null;
  openedAt?: string | null;
  deletedAt?: string | null;
  cooldownUntil?: string | null;
}

export interface TriggerCheckIn {
  moodId: string;
  quadrant: Quadrant;
  deviceTs: string;
  /** false for a backfill (localDay ≠ auraDay(deviceTs)): backfills never fire capsules. */
  live: boolean;
  /** Lexicon hit or "I need help now": the pick is held, not fired (crisis collision rule). */
  crisis: boolean;
}

export interface TriggerPick {
  fire: string | null;
  hold: string | null;
}

const ms = (iso: string): number => Date.parse(iso);

/** Latest `cooldownUntil` over all capsules (tombstones included), or null. */
export function globalCooldownUntil(capsules: readonly TriggerCapsule[]): number | null {
  let max: number | null = null;
  for (const c of capsules) {
    if (!c.cooldownUntil) continue;
    const t = ms(c.cooldownUntil);
    if (max === null || t > max) max = t;
  }
  return max;
}

/** RULES.md §9 `trigger`. */
export function pickTrigger(capsules: readonly TriggerCapsule[], checkIn: TriggerCheckIn): TriggerPick {
  const none: TriggerPick = { fire: null, hold: null };
  if (!checkIn.live) return none;
  const at = ms(checkIn.deviceTs);
  const cooldown = globalCooldownUntil(capsules);
  if (cooldown !== null && at < cooldown) return none;
  const candidates = capsules.filter(
    (c) =>
      c.unlockType === 'mood' &&
      !c.deletedAt &&
      !c.firedAt &&
      !c.openedAt &&
      !!c.armedAt &&
      ms(c.armedAt) <= at &&
      ((!!c.triggerMoodId && c.triggerMoodId === checkIn.moodId) || (!!c.triggerQuadrant && c.triggerQuadrant === checkIn.quadrant)),
  );
  if (candidates.length === 0) return none;
  candidates.sort(
    (a, b) =>
      ms(a.armedAt as string) - ms(b.armedAt as string) ||
      ms(a.sealedAt) - ms(b.sealedAt) ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  const pick = candidates[0].id;
  return checkIn.crisis ? { fire: null, hold: pick } : { fire: pick, hold: null };
}
