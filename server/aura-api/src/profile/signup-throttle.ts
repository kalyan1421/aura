import { HttpStatus, Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import type { Queryable } from '../db/db';

/**
 * Reduced mode's sign-up throttle (PRD 19 "When AK will be unreachable … he first turns on reduced mode: reflections
 * paused, sign-ups throttled; check-ins, gestures and crisis support keep working"). The reflections half lives in
 * src/reflections (composerPaused); this is the other half, on the route every sign-up passes: the first
 * `POST /v1/profile` of an account (onboarding creates the profile; nothing personal exists before it).
 *
 * While `feature_flags.reduced_mode` is on, at most `payload.signupsPerHour` new profiles (default
 * {@link DEFAULT_SIGNUPS_PER_HOUR} `[ASSUMPTION]`) are created per rolling hour across the service; the next one gets
 * `503 signups_throttled` and the app asks the person to try again later (nothing is stored, the onboarding answers
 * stay on the phone). "Throttled", not closed: sign-ups keep trickling in, so a moderator returning finds a queue they
 * can handle. Existing accounts are never affected (locale / timezone updates, re-onboarding on a new phone).
 * The check and the insert are serialised (a transaction-level advisory lock, only while reduced mode is on), so a
 * burst can't overshoot the allowance. The flag is read straight from the table: the console flips it and the next
 * sign-up sees it.
 */
export const REDUCED_MODE_FLAG = 'reduced_mode';
export const DEFAULT_SIGNUPS_PER_HOUR = 20;
export const MAX_SIGNUPS_PER_HOUR = 100_000;
/** Advisory-lock key of the sign-up allowance (any constant distinct from the per-user locks, which hash a uuid). */
export const SIGNUP_THROTTLE_LOCK = 'aura:signup-throttle';

export const signupsThrottled = (): ApiError =>
  new ApiError(
    HttpStatus.SERVICE_UNAVAILABLE,
    'signups_throttled',
    'Aura is welcoming new people slowly for a little while. Please try again later.',
  );

export interface SignupThrottleSettings {
  on: boolean;
  perHour: number;
}

/** The flag row → settings (pure). A missing row, a bad or absent payload → off / the default allowance. */
export function throttleSettings(row: { enabled: boolean; payload: Record<string, unknown> | null } | undefined): SignupThrottleSettings {
  const raw = row?.payload?.signupsPerHour;
  const perHour =
    typeof raw === 'number' && Number.isInteger(raw) && raw >= 0 && raw <= MAX_SIGNUPS_PER_HOUR ? raw : DEFAULT_SIGNUPS_PER_HOUR;
  return { on: row?.enabled === true, perHour };
}

@Injectable()
export class SignupThrottle {
  /** Reduced mode and the hourly allowance, straight from `public.feature_flags`. */
  async settings(q: Queryable): Promise<SignupThrottleSettings> {
    const r = await q.query<{ enabled: boolean; payload: Record<string, unknown> | null }>(
      'select enabled, payload from public.feature_flags where key = $1',
      [REDUCED_MODE_FLAG],
    );
    return throttleSettings(r.rows[0]);
  }

  /**
   * Call inside the onboarding transaction, before the new profile row is inserted. Throws `503 signups_throttled`
   * when reduced mode is on and the last hour's new profiles already reach the allowance.
   */
  async check(tx: Queryable): Promise<void> {
    const s = await this.settings(tx);
    if (!s.on) return;
    await tx.query('select pg_advisory_xact_lock(hashtext($1))', [SIGNUP_THROTTLE_LOCK]);
    const r = await tx.query<{ n: number }>(
      "select count(*)::int as n from public.profiles where created_at > now() - interval '1 hour'",
    );
    if ((r.rows[0]?.n ?? 0) >= s.perHour) throw signupsThrottled();
  }
}
