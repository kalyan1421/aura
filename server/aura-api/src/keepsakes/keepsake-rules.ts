/**
 * F13 keepsakes and share milestones — pure rules (contracts/rules/RULES.md §11, vectors `keepsakes.json`).
 * The Dart copy (packages/aura_domain/lib/src/rules/keepsakes.dart) passes the same vectors. NestJS awards keepsakes
 * (authoritative); `sharePrompt` / `capsuleYears` run on the device and live here only to keep the engines in step.
 */
import { addYears } from '../capsules/capsule-rules';
import { STAGES, type Stage } from '../rules/stage';

export type KeepsakeSource = 'capsuleSeals' | 'capsuleOpens' | 'glowDays' | 'rippleSessions' | 'lanternNights' | 'sanctuarySeconds';

export interface KeepsakeDef {
  key: string;
  source: KeepsakeSource;
  threshold: number;
}

/** The catalogue, in display order (RULES.md §11). The key is the only thing stored, with its day. */
export const KEEPSAKES: readonly KeepsakeDef[] = [
  { key: 'capsule_sealed_first', source: 'capsuleSeals', threshold: 1 },
  { key: 'capsule_opened_first', source: 'capsuleOpens', threshold: 1 },
  { key: 'glow_days_7', source: 'glowDays', threshold: 7 },
  { key: 'glow_days_30', source: 'glowDays', threshold: 30 },
  { key: 'glow_days_100', source: 'glowDays', threshold: 100 },
  { key: 'glow_days_365', source: 'glowDays', threshold: 365 },
  { key: 'ripples_first', source: 'rippleSessions', threshold: 1 },
  { key: 'lantern_hours_1', source: 'lanternNights', threshold: 1 },
  { key: 'lantern_hours_10', source: 'lanternNights', threshold: 10 },
  { key: 'lantern_hours_50', source: 'lanternNights', threshold: 50 },
  { key: 'sanctuary_minutes_60', source: 'sanctuarySeconds', threshold: 3600 },
  { key: 'sanctuary_minutes_300', source: 'sanctuarySeconds', threshold: 18000 },
  { key: 'sanctuary_minutes_1000', source: 'sanctuarySeconds', threshold: 60000 },
] as const;

export const KEEPSAKE_KEYS: readonly string[] = KEEPSAKES.map((k) => k.key);

export function isKeepsakeKey(v: unknown): v is string {
  return typeof v === 'string' && KEEPSAKE_KEYS.includes(v);
}

/** One dated event of a source (an Aura day and how much it adds). */
export interface KeepsakeEvent {
  day: string;
  amount: number;
}

export type KeepsakeSources = Partial<Record<KeepsakeSource, readonly KeepsakeEvent[]>> & {
  /** Lantern Hour nights already counted (the tally), before `lanternNights`. */
  lanternCounted?: number;
};

export interface EarnedKeepsake {
  key: string;
  day: string;
}

function normalise(source: KeepsakeSource, events: readonly KeepsakeEvent[]): KeepsakeEvent[] {
  const positive = events.filter((e) => Number.isFinite(e.amount) && e.amount > 0);
  const list =
    source === 'glowDays'
      ? [...new Set(positive.map((e) => e.day))].map((day) => ({ day, amount: 1 })) // 1 per distinct day
      : positive.map((e) => ({ day: e.day, amount: Math.floor(e.amount) }));
  // Stable sort by day (plain string order is calendar order for YYYY-MM-DD).
  return list.map((e, i) => ({ e, i })).sort((a, b) => (a.e.day < b.e.day ? -1 : a.e.day > b.e.day ? 1 : a.i - b.i)).map((x) => x.e);
}

/** RULES.md §11 `earned`: every keepsake the sources reach, with the day each was reached, in catalogue order. */
export function earnedKeepsakes(sources: KeepsakeSources): EarnedKeepsake[] {
  const out: EarnedKeepsake[] = [];
  const sorted = new Map<KeepsakeSource, KeepsakeEvent[]>();
  for (const def of KEEPSAKES) {
    const counted = def.source === 'lanternNights' ? Math.max(0, Math.floor(sources.lanternCounted ?? 0)) : 0;
    if (def.threshold <= counted) continue; // reached before these events: already stored, never re-dated
    let events = sorted.get(def.source);
    if (!events) {
      events = normalise(def.source, sources[def.source] ?? []);
      sorted.set(def.source, events);
    }
    let total = counted;
    for (const e of events) {
      total += e.amount;
      if (total >= def.threshold) {
        out.push({ key: def.key, day: e.day });
        break;
      }
    }
  }
  return out;
}

/** RULES.md §11 `capsule_years`: anniversaries of the first seal's day that are ≤ today. */
export function capsuleYears(firstSealed: string | null, today: string): number {
  if (!firstSealed || firstSealed > today) return 0;
  let y = 0;
  while (addYears(firstSealed, y + 1) <= today) y += 1;
  return y;
}

export const GLOW_MILESTONES = [7, 30, 100, 365] as const;

export interface SharePromptState {
  stage: Stage;
  lifetimeGlowDays: number;
  capsuleYears: number;
  offered: readonly string[];
  hideGlow: boolean;
}

/** RULES.md §11 `share_prompt`: one prompt for the highest new milestone; every new one is marked offered. */
export function sharePrompt(s: SharePromptState): { prompt: string | null; offer: string[] } {
  const stageIndex = STAGES.indexOf(s.stage);
  const evolution = STAGES.slice(1, Math.max(1, stageIndex + 1)).map((st) => `evolution:${st}`);
  const glow = GLOW_MILESTONES.filter((n) => n <= s.lifetimeGlowDays).map((n) => `glow:${n}`);
  const years = Math.max(0, Math.floor(s.capsuleYears));
  const anniversaries = Array.from({ length: years }, (_, i) => `capsule_anniversary:${i + 1}`);
  const offered = new Set(s.offered);
  const fresh = (ids: string[]) => ids.filter((id) => !offered.has(id));
  const [e, g, a] = [fresh(evolution), fresh(glow), fresh(anniversaries)];
  const prompt = e.at(-1) ?? (s.hideGlow ? undefined : g.at(-1)) ?? a.at(-1) ?? null;
  return { prompt, offer: [...e, ...g, ...a] };
}
