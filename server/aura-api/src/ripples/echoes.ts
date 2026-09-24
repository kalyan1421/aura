import type { Queryable } from '../db/db';
import type { RippleConfig } from './ripple-config';

/**
 * Echoes (PRD 06b F7 "Echoes (clearly labelled)"; REQ-GAME-07 / REQ-GAME-09). A recording is a list of pacer-relative
 * transition offsets (inhale/exhale starts, in order) in 50 ms steps, `null` = missed; plus the pacer version, the
 * completion, the median |offset| and the ISO week. Nothing else: no account, member, device, session or age, no
 * timestamp finer than the week, a random id. Lives in the separate `echo_library` schema with no foreign keys.
 */
export const OFFSET_STEP_MS = 50;
/** ±2 s: half the shortest phase. Anything further is not the same transition. */
export const MAX_OFFSET_STEPS = 40;

export interface EchoTrace {
  offsets: Array<number | null>;
}

export interface EchoRow {
  pacerVersion: number;
  offsets: Array<number | null>;
  completion: number;
  medianOffsetMs: number;
  isoWeek: string;
}

/** Valid offsets: integers within ±40 steps (or null), at most 2 transitions per cycle. */
export function validTrace(t: EchoTrace, cycles: number): boolean {
  if (!Array.isArray(t.offsets) || t.offsets.length === 0 || t.offsets.length > 2 * cycles) return false;
  return t.offsets.every((v) => v === null || (Number.isInteger(v) && Math.abs(v) <= MAX_OFFSET_STEPS));
}

/** Median of |offset| in ms over the transitions that were hit (0 when none). */
export function medianOffsetMs(offsets: ReadonlyArray<number | null>): number {
  const hits = offsets.filter((v): v is number => v !== null).map((v) => Math.abs(v) * OFFSET_STEP_MS);
  if (hits.length === 0) return 0;
  const s = hits.sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : Math.round((s[mid - 1] + s[mid]) / 2);
}

/** Hit transitions over the session's transitions (2 per cycle), 0–1, three decimals. */
export function completion(offsets: ReadonlyArray<number | null>, cycles: number): number {
  const hits = offsets.filter((v) => v !== null).length;
  return Math.round(Math.min(1, hits / (2 * cycles)) * 1000) / 1000;
}

/** ISO 8601 week of a UTC instant, e.g. `2026-W41`. */
export function isoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = t.getUTCDay() || 7; // Mon = 1 … Sun = 7
  t.setUTCDate(t.getUTCDate() + 4 - day); // the week's Thursday decides the year
  const yearStart = Date.UTC(t.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((t.getTime() - yearStart) / 86_400_000 + 1) / 7);
  return `${t.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

export function echoRow(trace: EchoTrace, cycles: number, cfg: Pick<RippleConfig, 'pacerVersion'>, now: Date): EchoRow {
  return {
    pacerVersion: cfg.pacerVersion,
    offsets: trace.offsets,
    completion: completion(trace.offsets, cycles),
    medianOffsetMs: medianOffsetMs(trace.offsets),
    isoWeek: isoWeek(now),
  };
}

/** Selection filter (PRD: pacer version, completion ≥ 90 %, median offset ≤ 600 ms, within retention). */
const ELIGIBLE_SQL = `pacer_version = $1 and completion >= $2 and median_offset_ms <= $3
  and to_date(iso_week, 'IYYY-"W"IW') > (now() at time zone 'utc')::date - make_interval(days => $4)`;

export async function eligibleEchoCount(q: Queryable, cfg: RippleConfig): Promise<number> {
  const r = await q.query<{ n: number }>(`select count(*)::int as n from echo_library.recordings where ${ELIGIBLE_SQL}`, [
    cfg.pacerVersion,
    cfg.echoMinCompletion,
    cfg.echoMaxMedianOffsetMs,
    cfg.echoRetentionD,
  ]);
  return r.rows[0]?.n ?? 0;
}

/** `n` distinct eligible echoes at random (never twice in one session). */
export async function pickEchoes(q: Queryable, cfg: RippleConfig, n: number): Promise<Array<{ id: string; offsets: Array<number | null> }>> {
  if (n <= 0) return [];
  const r = await q.query<{ id: string; offsets: Array<number | null> }>(
    `select id, offsets from echo_library.recordings where ${ELIGIBLE_SQL} order by random() limit $5`,
    [cfg.pacerVersion, cfg.echoMinCompletion, cfg.echoMaxMedianOffsetMs, cfg.echoRetentionD, n],
  );
  return r.rows;
}

/** One unlinked row. Deliberately takes nothing that identifies anyone. */
export async function insertEcho(q: Queryable, row: EchoRow): Promise<void> {
  await q.query(
    `insert into echo_library.recordings (pacer_version, offsets, completion, median_offset_ms, iso_week)
     values ($1, $2::smallint[], $3, $4, $5)`,
    [row.pacerVersion, row.offsets, row.completion, row.medianOffsetMs, row.isoWeek],
  );
}

/** Retention: echoes older than `echoRetentionD` days (by their ISO week's Monday). */
export async function purgeOldEchoes(q: Queryable, retentionD: number): Promise<number> {
  const r = await q.query(
    `delete from echo_library.recordings
      where to_date(iso_week, 'IYYY-"W"IW') <= (now() at time zone 'utc')::date - make_interval(days => $1)`,
    [retentionD],
  );
  return r.rowCount ?? 0;
}
