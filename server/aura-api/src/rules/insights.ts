/**
 * RULES.md §10 — F10 Insights ("Aura Sky").
 *
 * These rules run on the device only (PRD F10: "computed on device and never
 * uploaded"). This copy exists so the Dart and TypeScript engines keep passing
 * the same vectors (contracts/rules/vectors/insights.json); no endpoint uses
 * it, and no personal data is sent to the server for it.
 */
import { auraDay } from './aura-day';
import { addDays, daysBetween } from './dates';
import { QUADRANTS, type Quadrant } from './hue';
import { foldStreak, initialStreak, type StreakState } from './streak';

export interface InsightCheckIn {
  localDay: string;
  quadrant: Quadrant;
  tags?: readonly string[];
  /** ISO instant and the UTC offset it was stamped with (both or neither). */
  deviceTs?: string | null;
  tzOffsetMinutes?: number | null;
}

export interface InsightHabitLog {
  habitId: string;
  localDay: string;
}

export const DAY_PARTS = ['morning', 'afternoon', 'evening', 'night'] as const;
export type DayPart = (typeof DAY_PARTS)[number];

export const INSIGHT_THRESHOLDS = {
  minCheckIns: 7,
  minDays: 5,
  minCheckInsForItems: 14,
  minContextDays: 3,
  minSupport: 3,
  minOut: 3,
  careWindowDays: 14,
} as const;

const HOUR_MS = 3_600_000;
const MINUTE_MS = 60_000;

/** `morning` 04–12 · `afternoon` 12–17 · `evening` 17–21 · `night` otherwise. */
export function dayPartOfHour(hour: number): DayPart {
  if (hour >= 4 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/** The stamped wall clock as a UTC-anchored Date, or null without an instant. */
function wallClock(c: InsightCheckIn): Date | null {
  if (c.deviceTs == null || c.tzOffsetMinutes == null) return null;
  const t = new Date(c.deviceTs).getTime();
  if (Number.isNaN(t)) return null;
  return new Date(t + c.tzOffsetMinutes * MINUTE_MS);
}

/** Live = made on its own Aura day (not a backfill), per its stamped wall clock. */
export function isLive(c: InsightCheckIn): boolean {
  const wall = wallClock(c);
  if (!wall) return false;
  return new Date(wall.getTime() - 4 * HOUR_MS).toISOString().slice(0, 10) === c.localDay;
}

export function partOf(c: InsightCheckIn): DayPart | null {
  if (!isLive(c)) return null;
  return dayPartOfHour((wallClock(c) as Date).getUTCHours());
}

// ---- sky ---------------------------------------------------------------------

export type DayStarKind = 'empty' | 'rest' | 'single' | 'split';

function quadrantCounts(qs: Iterable<Quadrant>): Record<Quadrant, number> {
  const counts = { storm: 0, rain: 0, moonlight: 0, sunrise: 0 } as Record<Quadrant, number>;
  for (const q of qs) counts[q] += 1;
  return counts;
}

export function dayStar(quadrants: readonly Quadrant[], rest = false): { star: DayStarKind; quadrants: Quadrant[] } {
  const counts = quadrantCounts(quadrants);
  const top = Math.max(...QUADRANTS.map((q) => counts[q]));
  if (top === 0) return { star: rest ? 'rest' : 'empty', quadrants: [] };
  const tied = QUADRANTS.filter((q) => counts[q] === top);
  return { star: tied.length === 1 ? 'single' : 'split', quadrants: tied };
}

/** Gap days the §7 fold bridges with banked rest days, ascending. */
export function restDays(activeDays: readonly string[]): string[] {
  const sorted = [...new Set(activeDays)].sort();
  const out: string[] = [];
  let state: StreakState = initialStreak();
  for (const day of sorted) {
    const last = state.lastActiveDay;
    if (last !== null) {
      const gap = daysBetween(last, day) - 1;
      if (gap >= 1 && gap <= state.restBank) {
        for (let i = 1; i <= gap; i++) out.push(addDays(last, i));
      }
    }
    state = foldStreak(state, [day]);
  }
  return out;
}

// ---- weeks and months ------------------------------------------------------------

/** ISO weekday (1 = Monday … 7 = Sunday). */
export function isoWeekday(day: string): number {
  const d = new Date(`${day}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

export function weekStart(day: string, weekStartsOn = 1): string {
  return addDays(day, -((isoWeekday(day) - weekStartsOn + 7) % 7));
}

export interface WeekWindow {
  today: string;
  weekStart: string;
  from: string;
  to: string;
}

export function weeklyWindow(today: string, weekStartsOn = 1): WeekWindow {
  const start = weekStart(today, weekStartsOn);
  return { today, weekStart: start, from: addDays(start, -7), to: addDays(start, -1) };
}

export interface MonthWindow {
  today: string;
  monthStart: string;
  from: string;
  to: string;
}

export function monthWindow(today: string): MonthWindow {
  const monthStart = `${today.slice(0, 8)}01`;
  const to = addDays(monthStart, -1);
  return { today, monthStart, from: `${to.slice(0, 8)}01`, to };
}

// ---- gate ---------------------------------------------------------------------------

export type GateStatus = 'ok' | 'need_checkins' | 'need_days';

const inRange = (cs: readonly InsightCheckIn[], from: string, to: string): InsightCheckIn[] =>
  cs.filter((c) => c.localDay >= from && c.localDay <= to);

function gateOf(window: readonly InsightCheckIn[]): { status: GateStatus; checkIns: number; days: number } {
  const n = window.length;
  const d = new Set(window.map((c) => c.localDay)).size;
  const status: GateStatus =
    n < INSIGHT_THRESHOLDS.minCheckIns ? 'need_checkins' : d < INSIGHT_THRESHOLDS.minDays ? 'need_days' : 'ok';
  return { status, checkIns: n, days: d };
}

export function patternGate(checkIns: readonly InsightCheckIn[], from: string, to: string) {
  return gateOf(inRange(checkIns, from, to));
}

// ---- patterns ----------------------------------------------------------------------

export type PatternKind = 'tag_quadrant' | 'habit_quadrant' | 'time_of_day' | 'quadrant_mix';
const KIND_ORDER: readonly PatternKind[] = ['tag_quadrant', 'habit_quadrant', 'time_of_day'];

export interface InsightPattern {
  kind: PatternKind;
  quadrant: Quadrant;
  key: string | null;
}

interface Contrast {
  quadrant: Quadrant;
  num: number;
  den: number;
  k: number;
}

interface Candidate extends Contrast {
  kind: PatternKind;
  key: string;
}

function contrast(population: readonly InsightCheckIn[], isIn: (c: InsightCheckIn) => boolean): Contrast | null {
  const ins = population.filter(isIn);
  const outs = population.filter((c) => !isIn(c));
  const nIn = ins.length;
  const nOut = outs.length;
  if (new Set(ins.map((c) => c.localDay)).size < INSIGHT_THRESHOLDS.minContextDays) return null;
  if (nOut < INSIGHT_THRESHOLDS.minOut) return null;
  const inCounts = quadrantCounts(ins.map((c) => c.quadrant));
  const outCounts = quadrantCounts(outs.map((c) => c.quadrant));
  let best: Contrast | null = null;
  for (const q of QUADRANTS) {
    const kIn = inCounts[q];
    const kOut = outCounts[q];
    if (kIn < INSIGHT_THRESHOLDS.minSupport) continue;
    const num = kIn * nOut - kOut * nIn;
    const den = nIn * nOut;
    if (4 * num < den) continue; // lift < 1/4
    if (!best || num * best.den > best.num * den || (num * best.den === best.num * den && kIn > best.k)) {
      best = { quadrant: q, num, den, k: kIn };
    }
  }
  return best;
}

function compareCandidates(a: Candidate, b: Candidate): number {
  const lift = a.num * b.den - b.num * a.den;
  if (lift !== 0) return lift > 0 ? -1 : 1;
  if (a.k !== b.k) return a.k > b.k ? -1 : 1;
  if (a.kind !== b.kind) return KIND_ORDER.indexOf(a.kind) - KIND_ORDER.indexOf(b.kind);
  return a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
}

function quadrantMix(window: readonly InsightCheckIn[]): InsightPattern | null {
  const counts = quadrantCounts(window.map((c) => c.quadrant));
  const ordered = QUADRANTS.map((q) => counts[q]).sort((a, b) => b - a);
  const [top, second] = ordered;
  if (second >= top || 5 * top < 2 * window.length || top - second < 2) return null;
  const quadrant = QUADRANTS.find((q) => counts[q] === top) as Quadrant;
  return { kind: 'quadrant_mix', quadrant, key: null };
}

export function findPatterns(input: {
  checkIns: readonly InsightCheckIn[];
  habitLogs?: readonly InsightHabitLog[];
  from: string;
  to: string;
  includeHabits?: boolean;
}): InsightPattern[] {
  const { from, to } = input;
  const window = inRange(input.checkIns, from, to);
  if (gateOf(window).status !== 'ok') return [];

  const candidates: Candidate[] = [];
  const add = (kind: PatternKind, key: string, pop: readonly InsightCheckIn[], isIn: (c: InsightCheckIn) => boolean) => {
    const r = contrast(pop, isIn);
    if (r) candidates.push({ ...r, kind, key });
  };

  if (window.length >= INSIGHT_THRESHOLDS.minCheckInsForItems) {
    const tags = [...new Set(window.flatMap((c) => c.tags ?? []))].sort();
    for (const tag of tags) add('tag_quadrant', tag, window, (c) => (c.tags ?? []).includes(tag));
    if (input.includeHabits) {
      const daysByHabit = new Map<string, Set<string>>();
      for (const l of input.habitLogs ?? []) {
        if (l.localDay < from || l.localDay > to) continue;
        if (!daysByHabit.has(l.habitId)) daysByHabit.set(l.habitId, new Set());
        daysByHabit.get(l.habitId)!.add(l.localDay);
      }
      for (const id of [...daysByHabit.keys()].sort()) {
        const days = daysByHabit.get(id)!;
        add('habit_quadrant', id, window, (c) => days.has(c.localDay));
      }
    }
  }

  const live = window.filter(isLive);
  for (const part of DAY_PARTS) add('time_of_day', part, live, (c) => partOf(c) === part);

  candidates.sort(compareCandidates);
  const out: InsightPattern[] = candidates.map((c) => ({ kind: c.kind, quadrant: c.quadrant, key: c.key }));
  const mix = quadrantMix(window);
  if (mix) out.push(mix);
  return out;
}

export function weeklyInsight(input: {
  checkIns: readonly InsightCheckIn[];
  habitLogs?: readonly InsightHabitLog[];
  today: string;
  weekStartsOn?: number;
  includeHabits?: boolean;
}): InsightPattern | null {
  const w = weeklyWindow(input.today, input.weekStartsOn ?? 1);
  const ps = findPatterns({ ...input, from: w.from, to: w.to });
  return ps[0] ?? null;
}

// ---- month in stars, care --------------------------------------------------------------

export function monthRecap(checkIns: readonly InsightCheckIn[], today: string) {
  const m = monthWindow(today);
  const inMonth = inRange(checkIns, m.from, m.to);
  return {
    month: m.from.slice(0, 7),
    from: m.from,
    to: m.to,
    checkIns: inMonth.length,
    daysCheckedIn: new Set(inMonth.map((c) => c.localDay)).size,
    quadrantCounts: quadrantCounts(inMonth.map((c) => c.quadrant)),
  };
}

export function showCareCard(checkIns: readonly InsightCheckIn[], today: string): boolean {
  const window = inRange(checkIns, addDays(today, -(INSIGHT_THRESHOLDS.careWindowDays - 1)), today);
  if (window.length < INSIGHT_THRESHOLDS.minCheckIns) return false;
  const heavy = window.filter((c) => c.quadrant === 'storm' || c.quadrant === 'rain').length;
  return 5 * heavy >= 4 * window.length;
}

/** `today` for an instant in the person's current zone (§1). */
export const insightsToday = (now: string | Date, tz: string): string => auraDay(now, tz);
