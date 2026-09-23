import { addDays, localDate, wallClock } from '../rules';

/**
 * Timezone regions (PRD F5 "Matching and realtime"), chosen by the device's UTC offset at join. Each region has one
 * Lantern Hour clock so its members share an evening (±2 h). DST is handled by the tz database (Intl).
 */
export const TZ_REGIONS = ['americas', 'europe_africa', 'south_asia', 'east_asia_pacific'] as const;
export type TzRegion = (typeof TZ_REGIONS)[number];

export const REGION_CLOCK: Readonly<Record<TzRegion, string>> = {
  americas: 'America/Chicago',
  europe_africa: 'Europe/Berlin',
  south_asia: 'Asia/Kolkata',
  east_asia_pacific: 'Asia/Tokyo',
};

export function isTzRegion(v: unknown): v is TzRegion {
  return typeof v === 'string' && (TZ_REGIONS as readonly string[]).includes(v);
}

/** UTC offset of `tz` at `instant`, in whole minutes (Asia/Kolkata → 330, America/Chicago in summer → −300). */
export function utcOffsetMinutes(tz: string, instant: Date): number {
  const w = wallClock(instant, tz);
  const wallAsUtc = Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute, w.second);
  const wholeSeconds = Math.floor(instant.getTime() / 1000) * 1000;
  return Math.round((wallAsUtc - wholeSeconds) / 60_000);
}

/**
 * `americas` ≤ −2:30 · `europe_africa` −2:00…+3:00 · `south_asia` +3:30…+6:30 (incl. the Gulf) · `east_asia_pacific`
 * ≥ +7:00. No zone uses the gaps (−2:30…−2:00, +3:00…+3:30, +6:30…+7:00); they go to the nearer evening.
 */
export function regionForOffset(offsetMinutes: number): TzRegion {
  if (offsetMinutes < -120) return 'americas';
  if (offsetMinutes <= 180) return 'europe_africa';
  if (offsetMinutes <= 390) return 'south_asia';
  return 'east_asia_pacific';
}

export function regionForTimeZone(tz: string, now: Date): TzRegion {
  return regionForOffset(utcOffsetMinutes(tz, now));
}

/** The instant a wall-clock time happens in `tz` (21:00 / 23:00 are never inside a DST gap). */
export function zonedInstant(tz: string, day: string, hour: number, minute: number): Date {
  const [y, m, d] = day.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hour, minute);
  const first = utcOffsetMinutes(tz, new Date(guess));
  let t = guess - first * 60_000;
  const second = utcOffsetMinutes(tz, new Date(t));
  if (second !== first) t = guess - second * 60_000;
  return new Date(t);
}

export interface ClockTime {
  hour: number;
  minute: number;
}

/** Postgres `time` text ("21:00:00") → {hour, minute}. */
export function parseClockTime(v: string): ClockTime {
  const m = /^(\d{1,2}):(\d{2})/.exec(v);
  if (!m) throw new RangeError(`invalid time ${v}`);
  return { hour: Number(m[1]), minute: Number(m[2]) };
}

export interface LanternWindow {
  /** The region clock (IANA). */
  timezone: string;
  active: boolean;
  /** The current window when active, else the next one. */
  startsAt: Date;
  endsAt: Date;
}

export const DEFAULT_LANTERN_START: ClockTime = { hour: 21, minute: 0 };
export const DEFAULT_LANTERN_END: ClockTime = { hour: 23, minute: 0 };

/**
 * Lantern Hour on the region's clock: [start, end) local time (default 21:00–23:00), DST-correct.
 * Never active outside the window (REQ-ROOM-11).
 */
export function lanternWindow(
  region: TzRegion,
  now: Date,
  start: ClockTime = DEFAULT_LANTERN_START,
  end: ClockTime = DEFAULT_LANTERN_END,
): LanternWindow {
  const timezone = REGION_CLOCK[region];
  const today = localDate(now, timezone);
  let startsAt = zonedInstant(timezone, today, start.hour, start.minute);
  let endsAt = zonedInstant(timezone, today, end.hour, end.minute);
  if (now.getTime() >= endsAt.getTime()) {
    const tomorrow = addDays(today, 1);
    startsAt = zonedInstant(timezone, tomorrow, start.hour, start.minute);
    endsAt = zonedInstant(timezone, tomorrow, end.hour, end.minute);
  }
  const active = now.getTime() >= startsAt.getTime() && now.getTime() < endsAt.getTime();
  return { timezone, active, startsAt, endsAt };
}

/** Is it Lantern Hour on this region's clock right now? (Wall-clock check, independent of the window maths.) */
export function isLanternHour(region: TzRegion, now: Date, start = DEFAULT_LANTERN_START, end = DEFAULT_LANTERN_END): boolean {
  const w = wallClock(now, REGION_CLOCK[region]);
  const minutes = w.hour * 60 + w.minute;
  return minutes >= start.hour * 60 + start.minute && minutes < end.hour * 60 + end.minute;
}
