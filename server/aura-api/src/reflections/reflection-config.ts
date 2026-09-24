import type { Queryable } from '../db/db';
import { baselineLexicon, matcherFor, parseLexicon } from '../remote-config/lexicon/document';
import type { CrisisLexiconMatcher } from '../remote-config/lexicon/matcher';
import { parseClockTime, type ClockTime } from '../rooms/regions';
import { parseThresholds, type Thresholds } from './decide';

/** `public.reflection_config` (migration 20261005000018), read per request (one tiny row). */
export interface ReflectionConfig {
  maxChars: number;
  perRoom24h: number;
  perAccount24h: number;
  respondWithinMs: number;
  providerTimeoutMs: number;
  pendingTimeoutS: number;
  nearDuplicateRooms: number;
  autoPauseHeld: number;
  overnightStart: ClockTime;
  overnightEnd: ClockTime;
  overnightTz: string;
  thresholds: Thresholds;
}

export const DEFAULT_REFLECTION_CONFIG: ReflectionConfig = {
  maxChars: 200,
  perRoom24h: 3,
  perAccount24h: 10,
  respondWithinMs: 1800,
  providerTimeoutMs: 5000,
  pendingTimeoutS: 60,
  nearDuplicateRooms: 2,
  autoPauseHeld: 50,
  overnightStart: { hour: 0, minute: 30 },
  overnightEnd: { hour: 7, minute: 30 },
  overnightTz: 'Asia/Kolkata',
  thresholds: parseThresholds({}),
};

function validTz(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export async function loadReflectionConfig(q: Queryable): Promise<ReflectionConfig> {
  const r = await q.query<{
    max_chars: number;
    per_room_24h: number;
    per_account_24h: number;
    respond_within_ms: number;
    provider_timeout_ms: number;
    pending_timeout_s: number;
    near_duplicate_rooms: number;
    auto_pause_held: number;
    overnight_start: string;
    overnight_end: string;
    overnight_tz: string;
    thresholds: unknown;
  }>('select * from public.reflection_config where id');
  const x = r.rows[0];
  if (!x) return DEFAULT_REFLECTION_CONFIG;
  return {
    maxChars: x.max_chars,
    perRoom24h: x.per_room_24h,
    perAccount24h: x.per_account_24h,
    respondWithinMs: x.respond_within_ms,
    providerTimeoutMs: x.provider_timeout_ms,
    pendingTimeoutS: x.pending_timeout_s,
    nearDuplicateRooms: x.near_duplicate_rooms,
    autoPauseHeld: x.auto_pause_held,
    overnightStart: parseClockTime(x.overnight_start),
    overnightEnd: parseClockTime(x.overnight_end),
    overnightTz: validTz(x.overnight_tz) ? x.overnight_tz : DEFAULT_REFLECTION_CONFIG.overnightTz,
    thresholds: parseThresholds(x.thresholds),
  };
}

// ------------------------------------------------------------------------------------------------ flags
export const COMPOSER_FLAG = 'reflections_composer';
export const REDUCED_MODE_FLAG = 'reduced_mode';
export const HOLD_ALL_FLAG = 'hold_all';
export const REFLECTION_POOLS = ['en', 'te', 'hi'] as const;
export type ReflectionPool = (typeof REFLECTION_POOLS)[number];

export interface ReflectionFlags {
  /** `reflections_composer` on (a missing row counts as on: kill switches only take things away). */
  composerEnabled: boolean;
  pausedPools: ReflectionPool[];
  reducedMode: boolean;
  holdAll: boolean;
}

type FlagMap = Record<string, { enabled: boolean; payload?: Record<string, unknown> }>;

export function flagsFrom(flags: FlagMap): ReflectionFlags {
  const composer = flags[COMPOSER_FLAG];
  const paused = composer?.payload?.pausedPools;
  return {
    composerEnabled: composer ? composer.enabled : true,
    pausedPools: Array.isArray(paused) ? (paused.filter((p) => (REFLECTION_POOLS as readonly unknown[]).includes(p)) as ReflectionPool[]) : [],
    reducedMode: flags[REDUCED_MODE_FLAG]?.enabled === true,
    holdAll: flags[HOLD_ALL_FLAG]?.enabled === true,
  };
}

/** Straight from the table (the worker, which has no RemoteConfigService cache). */
export async function loadFlags(q: Queryable): Promise<ReflectionFlags> {
  const r = await q.query<{ key: string; enabled: boolean; payload: Record<string, unknown> | null }>(
    'select key, enabled, payload from public.feature_flags where key = any($1::text[])',
    [[COMPOSER_FLAG, REDUCED_MODE_FLAG, HOLD_ALL_FLAG]],
  );
  const map: FlagMap = {};
  for (const f of r.rows) map[f.key] = { enabled: f.enabled, payload: f.payload ?? undefined };
  return flagsFrom(map);
}

/** Composer paused for this pool: the kill switch, a paused pool, or reduced mode (PRD 19). */
export const composerPaused = (f: ReflectionFlags, pool: string): boolean =>
  !f.composerEnabled || f.reducedMode || (f.pausedPools as string[]).includes(pool);

// ------------------------------------------------------------------------------------------------ crisis lexicon
/**
 * The server's crisis lexicon for reflections (F9 L1 repeated on the server): the live signed version when one is
 * published (the same content phones use), else the bundled baseline. Cached per process for a minute.
 */
export class ReflectionCrisisLexicon {
  private cached: { matcher: CrisisLexiconMatcher; version: number; at: number } | null = null;
  private static baseline: CrisisLexiconMatcher | null = null;

  static baselineMatcher(): CrisisLexiconMatcher {
    ReflectionCrisisLexicon.baseline ??= matcherFor(baselineLexicon());
    return ReflectionCrisisLexicon.baseline;
  }

  async matcher(q: Queryable, now = Date.now()): Promise<CrisisLexiconMatcher> {
    if (this.cached && now - this.cached.at < 60_000) return this.cached.matcher;
    let matcher = ReflectionCrisisLexicon.baselineMatcher();
    let version = 0;
    try {
      const r = await q.query<{ version: number; content: unknown }>(
        `select v.version, v.content from public.signed_bundle_current c
           join public.signed_bundle_versions v on v.kind = c.kind and v.version = c.version
          where c.kind = 'crisis_lexicon'`,
      );
      if (r.rows[0]) {
        matcher = matcherFor(parseLexicon(r.rows[0].content));
        version = r.rows[0].version;
      }
    } catch {
      // A stored version that no longer parses: keep the bundled baseline (never fewer crisis terms than the app).
    }
    this.cached = { matcher, version, at: now };
    return matcher;
  }
}
