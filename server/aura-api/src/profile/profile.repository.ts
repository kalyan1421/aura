import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import type { LanguagePool, ProfileDto, UiLocale } from './profile.schema';

interface ProfileRow {
  user_id: string;
  birth_date: string;
  ui_locale: UiLocale;
  language_pool: LanguagePool;
  timezone: string;
  country: string | null;
  created_at: Date;
  updated_at: Date;
}

const toDto = (r: ProfileRow): ProfileDto => ({
  userId: r.user_id,
  birthDate: r.birth_date,
  uiLocale: r.ui_locale,
  languagePool: r.language_pool,
  timezone: r.timezone,
  country: r.country,
  createdAt: r.created_at.toISOString(),
  updatedAt: r.updated_at.toISOString(),
});

const COLS = 'user_id, birth_date, ui_locale, language_pool, timezone, country, created_at, updated_at';

@Injectable()
export class ProfileRepository {
  async find(q: Queryable, userId: string): Promise<ProfileDto | null> {
    const r = await q.query<ProfileRow>(`select ${COLS} from public.profiles where user_id = $1`, [userId]);
    return r.rows[0] ? toDto(r.rows[0]) : null;
  }

  async upsert(
    q: Queryable,
    p: { userId: string; birthDate: string; uiLocale: UiLocale; languagePool: LanguagePool; timezone: string; country: string | null },
  ): Promise<ProfileDto> {
    const r = await q.query<ProfileRow>(
      `insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone, country)
       values ($1, $2, $3, $4, $5, $6)
       on conflict (user_id) do update set
         ui_locale = excluded.ui_locale, language_pool = excluded.language_pool,
         timezone = excluded.timezone, country = excluded.country, updated_at = now()
       returning ${COLS}`,
      [p.userId, p.birthDate, p.uiLocale, p.languagePool, p.timezone, p.country],
    );
    return toDto(r.rows[0]);
  }

  /**
   * A platform signal said "under 18" (F8 REQ-ACC-04/10): invisible under-18 protections until `years` after
   * `today` (the user's local date). Only ever extended, never shortened. Server-only (`public.minor_signals`).
   */
  async extendMinorSignal(q: Queryable, userId: string, today: string, years: number): Promise<void> {
    await q.query(
      `insert into public.minor_signals (user_id, minor_until) values ($1, ($2::date + make_interval(years => $3))::date)
       on conflict (user_id) do update
         set minor_until = greatest(public.minor_signals.minor_until, excluded.minor_until), updated_at = now()`,
      [userId, today, years],
    );
  }

  /** avatar_state + streak_state with schema defaults (streak: 1 welcome rest day). */
  async ensureStateRows(q: Queryable, userId: string): Promise<void> {
    await q.query('insert into public.avatar_state (user_id) values ($1) on conflict (user_id) do nothing', [userId]);
    await q.query('insert into public.streak_state (user_id) values ($1) on conflict (user_id) do nothing', [userId]);
  }
}
