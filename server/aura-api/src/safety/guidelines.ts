import { ArgumentsHost, Catch, HttpStatus, Injectable, type ExceptionFilter } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { ApiError, profileRequired } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode, type Queryable } from '../db/db';
import { DbService } from '../db/db.service';

/**
 * Community guidelines before the first room (PRD 06c F9 REQ-SAFE-04, Play UGC), recorded on the server per version
 * (contracts/api/v1-rooms.md §2.4): `safety_config.guidelines_version` is the version rooms require; an account may
 * join once it has accepted that version or a newer one (`public.guidelines_acceptances`, server-only). The app keeps
 * its own flag only as a cache: `POST /v1/rooms/match` answers `409 guidelines_required` with the version to accept.
 */
export interface GuidelinesStatus {
  /** The version rooms require now. */
  version: number;
  /** The caller accepted `version` or a newer one: rooms are open as far as the guidelines go. */
  accepted: boolean;
  /** The newest version the caller accepted, or null. */
  acceptedVersion: number | null;
  acceptedAt: string | null;
}

export const GUIDELINES_REQUIRED = 'guidelines_required';
export const MAX_GUIDELINES_VERSION = 1000;

/** `409 guidelines_required` + `version` (the body gets `version` from GuidelinesRequiredFilter). */
export class GuidelinesRequiredError extends ApiError {
  constructor(readonly version: number) {
    super(HttpStatus.CONFLICT, GUIDELINES_REQUIRED, `Accept the community guidelines (version ${version}) before joining a room.`);
    this.name = 'GuidelinesRequiredError';
  }
}

/**
 * Writes `{ code, message, version }` for GuidelinesRequiredError on the routes that can raise it (`@UseFilters`);
 * everything else keeps going to the global ApiExceptionFilter (`{ code, message }`).
 */
@Catch(GuidelinesRequiredError)
export class GuidelinesRequiredFilter implements ExceptionFilter {
  catch(e: GuidelinesRequiredError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return;
    res.status(e.status).json({ code: e.code, message: e.message, version: e.version });
  }
}

export async function guidelinesStatus(q: Queryable, userId: string): Promise<GuidelinesStatus> {
  const r = await q.query<{ current: number; accepted_version: number | null; accepted_at: Date | null }>(
    `select coalesce((select c.guidelines_version from public.safety_config c where c.id), 1)::int as current,
            a.version::int as accepted_version, a.accepted_at
       from (select 1) one
       left join lateral (select g.version, g.accepted_at from public.guidelines_acceptances g
                           where g.user_id = $1 order by g.version desc limit 1) a on true`,
    [userId],
  );
  const x = r.rows[0] ?? { current: 1, accepted_version: null, accepted_at: null };
  return {
    version: x.current,
    accepted: x.accepted_version !== null && x.accepted_version >= x.current,
    acceptedVersion: x.accepted_version,
    acceptedAt: x.accepted_at ? x.accepted_at.toISOString() : null,
  };
}

/** `POST /v1/rooms/match`: 409 guidelines_required until the required version (or a newer one) is accepted. */
export async function assertGuidelinesAccepted(q: Queryable, userId: string): Promise<void> {
  const s = await guidelinesStatus(q, userId);
  if (!s.accepted) throw new GuidelinesRequiredError(s.version);
}

const acceptSchema = z.object({ version: z.number().int().min(1).max(MAX_GUIDELINES_VERSION) });

/**
 * `POST /v1/safety/guidelines/accept { version }` → the caller's status. `version` is the version whose text the app
 * showed: the required one, or a newer one (an app release that carries new copy before the server asks for it). An
 * older one can't open rooms → `409 guidelines_required` with the version to accept (an out-of-date app says
 * "update"). Idempotent: the first `accepted_at` of a version is kept. Needs a profile (`409 profile_required`).
 */
@Injectable()
export class GuidelinesService {
  constructor(private readonly db: DbService) {}

  async accept(userId: string, body: unknown): Promise<GuidelinesStatus> {
    const { version } = parseOrThrow(acceptSchema, body);
    return this.db.withTx(async (tx) => {
      const current = (await guidelinesStatus(tx, userId)).version;
      if (version < current) throw new GuidelinesRequiredError(current);
      const profile = await tx.query('select 1 from public.profiles where user_id = $1', [userId]);
      if ((profile.rowCount ?? 0) === 0) throw profileRequired();
      try {
        await tx.query(
          `insert into public.guidelines_acceptances (user_id, version) values ($1, $2)
           on conflict (user_id, version) do nothing`,
          [userId, version],
        );
      } catch (err) {
        if (pgCode(err) === '23503') throw profileRequired(); // the profile went meanwhile
        throw err;
      }
      return guidelinesStatus(tx, userId);
    });
  }

  status(userId: string): Promise<GuidelinesStatus> {
    return guidelinesStatus(this.db, userId);
  }
}
