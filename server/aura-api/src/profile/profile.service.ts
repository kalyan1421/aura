import { Injectable } from '@nestjs/common';
import { ApiError, profileRequired } from '../common/api-error';
import { pgCode, pgConstraint } from '../db/db';
import { lockUser } from '../db/locks';
import { DbService } from '../db/db.service';
import type { Snapshot } from '../progression/snapshot';
import { ProgressionService } from '../progression/progression.service';
import { localDate } from '../rules';
import { isUnder13 } from './age';
import { ProfileRepository } from './profile.repository';
import { languagePoolFor, SIGNAL_MINOR_YEARS, type ProfileDto, type ProfileRequest } from './profile.schema';

const under13 = (): ApiError =>
  ApiError.forbidden('under_13', 'Aura is for people aged 13 and over.');

/** DOB is set once at onboarding (DS-6); corrections go through support, never the app. */
const birthDateLocked = (): ApiError =>
  ApiError.conflict('birth_date_locked', 'Date of birth can only be changed by contacting support.');

@Injectable()
export class ProfileService {
  constructor(
    private readonly db: DbService,
    private readonly repo: ProfileRepository,
    private readonly progression: ProgressionService,
  ) {}

  /**
   * Onboarding upsert. Under-13 — by DOB or by the platform age signal (`ageSignal: "under13"`) — is refused before
   * any write: nothing is stored. Later calls may change locale/timezone/country but never the date of birth.
   * `ageSignal: "under18"` switches on the invisible under-18 protections (`minor_signals`, REQ-ACC-10) even with an
   * adult DOB — also when the DOB-locked refusal answers — and is never returned (DS-10).
   */
  async upsert(userId: string, req: ProfileRequest, now = new Date()): Promise<{ profile: ProfileDto; snapshot: Snapshot }> {
    if (req.ageSignal === 'under13' || isUnder13(req.birthDate, now, req.timezone)) throw under13();
    const signalMinor = req.ageSignal === 'under18';
    const today = localDate(now, req.timezone);
    try {
      const out = await this.db.withTx(async (tx) => {
        await lockUser(tx, userId); // serialises concurrent first onboardings (no row to lock yet)
        const existing = await this.repo.find(tx, userId);
        if (existing && existing.birthDate !== req.birthDate) {
          // The DOB stays as onboarded (support-only change); protection from a new signal still only widens.
          if (signalMinor) await this.repo.extendMinorSignal(tx, userId, today, SIGNAL_MINOR_YEARS);
          return null;
        }
        const profile = await this.repo.upsert(tx, {
          userId,
          birthDate: req.birthDate,
          uiLocale: req.uiLocale,
          languagePool: languagePoolFor(req.uiLocale),
          timezone: req.timezone,
          country: req.country ?? null,
        });
        if (signalMinor) await this.repo.extendMinorSignal(tx, userId, today, SIGNAL_MINOR_YEARS);
        await this.repo.ensureStateRows(tx, userId);
        const snapshot = await this.progression.recompute(tx, userId, profile.timezone, now);
        return { profile, snapshot };
      });
      if (out === null) throw birthDateLocked();
      return out;
    } catch (err) {
      if (pgCode(err) === '23514' && pgConstraint(err) === 'profiles_min_age') throw under13();
      if (pgCode(err) === '23503') throw ApiError.unauthorized('This account no longer exists.', 'unknown_user');
      throw err;
    }
  }

  /** Profile or `409 profile_required`. */
  async require(userId: string): Promise<ProfileDto> {
    const p = await this.repo.find(this.db, userId);
    if (!p) throw profileRequired();
    return p;
  }

  async snapshot(userId: string, now = new Date()): Promise<Snapshot> {
    const p = await this.require(userId);
    return this.progression.snapshot(this.db, userId, p.timezone, now);
  }
}
