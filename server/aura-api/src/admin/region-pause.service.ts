import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { parseOrThrow } from '../common/zod';
import { DbService } from '../db/db.service';
import { QUIET_FLAG, WIND_DOWN_FLAG } from '../quiet/quiet-types';
import { TZ_REGIONS, isTzRegion, type TzRegion } from '../rooms/regions';
import { auditConsole } from './admin-audit';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import { reasonCode } from './admin.schemas';
import type { StaffUser } from './admin-types';

/**
 * Per-region kill switches (PRD 19 "Configuration": "from C Quiet Together and the Lantern Hour wind-down, per
 * region"; contracts/api/v1-quiet.md "Kill switches, per region"). The flag itself stays the global switch (flipped on
 * the Kill switches page like every flag); `payload.pausedRegions` pauses single timezone regions, and the server's
 * `isPaused` (src/quiet/quiet-flags.ts) honours it on every join. Same shape as the reflections `pausedPools` control
 * (src/reflections/admin-reflections.service.ts): the payload is edited by the service role, because `aura_admin` may
 * only change `enabled`, behind an Owner-only route, with the hash-chained audit row in the same transaction. The
 * audit detail holds the flag key and region names only.
 */
export const REGION_FLAGS = [QUIET_FLAG, WIND_DOWN_FLAG] as const;
export type RegionFlag = (typeof REGION_FLAGS)[number];

export interface RegionFlagState {
  key: RegionFlag;
  /** The global switch: off pauses every region whatever the list says. */
  enabled: boolean;
  /** Known regions only, in {@link TZ_REGIONS} order. */
  pausedRegions: TzRegion[];
  updatedAt: string | null;
}

export interface RegionPauses {
  regions: readonly TzRegion[];
  flags: RegionFlagState[];
}

const bodySchema = z.object({ reasonCode }).strict();

export const isRegionFlag = (v: unknown): v is RegionFlag => typeof v === 'string' && (REGION_FLAGS as readonly string[]).includes(v);

/** The stored list, cleaned: unknown names dropped, duplicates merged, canonical order. */
export function pausedRegionsOf(payload: unknown): TzRegion[] {
  const raw = (payload as { pausedRegions?: unknown } | null)?.pausedRegions;
  const list = Array.isArray(raw) ? raw.filter(isTzRegion) : [];
  return TZ_REGIONS.filter((r) => list.includes(r));
}

type FlagRow = {
  key: string;
  enabled: boolean;
  payload: unknown;
  updated_at: Date | string | null;
};

function toState(row: FlagRow): RegionFlagState {
  const at = row.updated_at;
  return {
    key: row.key as RegionFlag,
    enabled: row.enabled,
    pausedRegions: pausedRegionsOf(row.payload),
    updatedAt: at === null ? null : at instanceof Date ? at.toISOString() : new Date(at).toISOString(),
  };
}

@Injectable()
export class RegionPauseService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly db: DbService,
  ) {}

  /** Owner + Moderator (read-only for a Moderator). A flag missing from the table is simply not listed. */
  async get(): Promise<RegionPauses> {
    const rows = await this.adminDb.query<FlagRow>(
      'select key, enabled, payload, updated_at from public.feature_flags where key = any($1::text[]) order by key',
      [[...REGION_FLAGS]],
    );
    return { regions: TZ_REGIONS, flags: rows.rows.map(toState) };
  }

  /** Owner only: add or remove one region from the flag's `payload.pausedRegions`, audited with its reason. */
  async setPaused(staff: StaffUser, keyParam: string, regionParam: string, paused: boolean, body: unknown): Promise<RegionFlagState> {
    const b = parseOrThrow(bodySchema, body ?? {});
    if (!isRegionFlag(keyParam)) throw AdminErrors.notFound('That switch has no regions (quiet_enabled or lantern_wind_down_enabled).');
    if (!isTzRegion(regionParam)) throw AdminErrors.notFound(`Unknown region (${TZ_REGIONS.join(', ')}).`);
    const key = keyParam;
    const region = regionParam;
    return this.db.withTx(async (tx) => {
      const row = (await tx.query<FlagRow>('select key, enabled, payload, updated_at from public.feature_flags where key = $1 for update', [key])).rows[0];
      if (!row) throw AdminErrors.notFound(`The ${key} flag is missing (migration 20261005000027).`);
      const previous = pausedRegionsOf(row.payload);
      const next = TZ_REGIONS.filter((r) => (r === region ? paused : previous.includes(r)));
      const updated = (
        await tx.query<FlagRow>(
          `update public.feature_flags set payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object('pausedRegions', $2::jsonb)
            where key = $1 returning key, enabled, payload, updated_at`,
          [key, JSON.stringify(next)],
        )
      ).rows[0];
      await auditConsole(tx, staff.actor, {
        action: paused ? 'config_region_pause' : 'config_region_resume',
        reasonCode: b.reasonCode,
        detail: { key, region, pausedRegions: next, previous },
      });
      return toState(updated);
    });
  }
}
