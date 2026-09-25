/**
 * RULES.md §10.1 — F10 Look back (Milestone C).
 *
 * Like the rest of Insights, these rules run on the device only (PRD F10:
 * "computed on device and never uploaded"; Look back is pull-only and never
 * pushed). This copy exists so the Dart and TypeScript engines keep passing the
 * same vectors (contracts/rules/vectors/look_back.json); no endpoint uses it.
 */
import { addDays } from './dates';
import type { Quadrant } from './hue';
import { dayStar, type DayStarKind, weekStart } from './insights';

/** The same week 1 month, 6 months and 1 year ago. */
export const LOOK_BACK_MONTHS = [1, 6, 12] as const;

/** Hidden for 3 h after a Storm or Rain check-in, 24 h after a crisis sheet. */
export const LOOK_BACK_AFTER_HEAVY_MS = 3 * 3_600_000;
export const LOOK_BACK_AFTER_HELP_MS = 24 * 3_600_000;

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** `day` moved by `months` calendar months, the day clamped to the month's length. */
export function addMonthsClamped(day: string, months: number): string {
  const [y, m, d] = day.split('-').map(Number);
  const index = y * 12 + (m - 1) + months;
  const year = Math.floor(index / 12);
  const month = (index % 12) + 1;
  const dd = Math.min(d, daysInMonth(year, month));
  return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(dd).padStart(2, '0')}`;
}

export interface LookBackWindow {
  months: number;
  anchor: string;
  from: string;
  to: string;
}

/** The week holding `addMonthsClamped(today, −m)` for each of 1, 6 and 12 months. */
export function lookBackWindows(today: string, weekStartsOn = 1): LookBackWindow[] {
  return LOOK_BACK_MONTHS.map((months) => {
    const anchor = addMonthsClamped(today, -months);
    const from = weekStart(anchor, weekStartsOn);
    return { months, anchor, from, to: addDays(from, 6) };
  });
}

export type LookBackGateStatus = 'open' | 'off' | 'after_help' | 'after_heavy';

export interface LookBackGate {
  status: LookBackGateStatus;
  /** ISO instant when every gate in force has ended; null for open / off. */
  until: string | null;
}

export interface LookBackGateInput {
  now: string;
  checkIns?: readonly { quadrant: Quadrant; deviceTs: string }[];
  helpAt?: string | null;
  hidden?: boolean;
}

export function lookBackGate(input: LookBackGateInput): LookBackGate {
  if (input.hidden) return { status: 'off', until: null };
  const now = new Date(input.now).getTime();
  let helpEnd: number | null = null;
  if (input.helpAt != null) {
    const end = new Date(input.helpAt).getTime() + LOOK_BACK_AFTER_HELP_MS;
    if (now < end) helpEnd = end;
  }
  let heavyEnd: number | null = null;
  for (const c of input.checkIns ?? []) {
    if (c.quadrant !== 'storm' && c.quadrant !== 'rain') continue;
    const end = new Date(c.deviceTs).getTime() + LOOK_BACK_AFTER_HEAVY_MS;
    if (now < end && (heavyEnd === null || end > heavyEnd)) heavyEnd = end;
  }
  if (helpEnd === null && heavyEnd === null) return { status: 'open', until: null };
  const until = Math.max(helpEnd ?? -Infinity, heavyEnd ?? -Infinity);
  return { status: helpEnd !== null ? 'after_help' : 'after_heavy', until: new Date(until).toISOString() };
}

export interface LookBackEntry {
  id: string;
  localDay: string;
  quadrant: Quadrant;
  deviceTs: string;
  deleted?: boolean;
  lexiconCrisis?: boolean;
  helpOpened?: boolean;
  noteUnreadable?: boolean;
}

export interface LookBackDay {
  day: string;
  star: DayStarKind;
  quadrants: Quadrant[];
  entries: string[];
}

function shows(e: LookBackEntry): boolean {
  return !e.deleted && !e.lexiconCrisis && !e.helpOpened && !e.noteUnreadable;
}

/** A Look back week's sky: only entries that show, each day's star over those. */
export function lookBackSky(
  from: string,
  to: string,
  entries: readonly LookBackEntry[],
  restDays: readonly string[] = [],
): { visible: boolean; days: LookBackDay[] } {
  const rest = new Set(restDays);
  const visible = entries.filter((e) => shows(e) && e.localDay >= from && e.localDay <= to);
  const days: LookBackDay[] = [];
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const list = visible
      .filter((e) => e.localDay === day)
      .sort((a, b) => {
        const t = new Date(a.deviceTs).getTime() - new Date(b.deviceTs).getTime();
        if (t !== 0) return t;
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
      });
    const star = dayStar(
      list.map((e) => e.quadrant),
      rest.has(day),
    );
    days.push({ day, star: star.star, quadrants: star.quadrants, entries: list.map((e) => e.id) });
  }
  return { visible: visible.length > 0, days };
}
