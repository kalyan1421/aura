/**
 * Server-side under-18 from platform age signals (F8 REQ-ACC-04 / REQ-ACC-10; contracts/api/v1.md "Onboarding /
 * profile"): `POST /v1/profile` takes an optional `ageSignal`. `under13` → 403 under_13 with nothing stored (like the
 * DOB); `under18` → invisible protections (`minor_signals`) even with an adult DOB, never returned; `adult` / null →
 * the DOB alone. E2E against the real DB (user_is_minor): test/e2e/account-followups.e2e-spec.ts.
 */
import { ProfileService } from '../../src/profile/profile.service';
import { AGE_SIGNALS, profileRequestSchema, SIGNAL_MINOR_YEARS } from '../../src/profile/profile.schema';

const U = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const base = { birthDate: '1996-04-17', uiLocale: 'en' as const, timezone: 'Asia/Kolkata', country: null };

describe('profile request: ageSignal', () => {
  const ok = { birthDate: '2006-04-17', uiLocale: 'te-Latn', timezone: 'Asia/Kolkata', country: 'IN' };

  it('accepts under13 | under18 | adult | null | absent', () => {
    expect(AGE_SIGNALS).toEqual(['under13', 'under18', 'adult']);
    for (const ageSignal of ['under13', 'under18', 'adult', null]) {
      expect(profileRequestSchema.parse({ ...ok, ageSignal }).ageSignal).toBe(ageSignal);
    }
    expect('ageSignal' in profileRequestSchema.parse(ok)).toBe(false);
  });

  it.each([['child'], ['UNDER18'], [17], [true], [{ lower: 13 }]])('rejects %p → 400', (ageSignal) => {
    expect(profileRequestSchema.safeParse({ ...ok, ageSignal }).success).toBe(false);
  });

  it('protection from a signal lasts until the youngest age in the band (13) turns 18', () => {
    expect(SIGNAL_MINOR_YEARS).toBe(5);
  });
});

/** Just enough of the repository / DB / progression for ProfileService.upsert. */
function harness(existingDob: string | null = null) {
  const calls: string[] = [];
  const minor: { userId: string; today: string; years: number }[] = [];
  const tx = { query: async (t: string) => (calls.push(t), { rows: [], rowCount: 0 }) };
  const db = { withTx: jest.fn(async <T>(fn: (q: typeof tx) => Promise<T>) => fn(tx)) };
  const repo = {
    find: async () =>
      existingDob
        ? { userId: U, birthDate: existingDob, uiLocale: 'en', languagePool: 'en', timezone: 'Asia/Kolkata', country: null, createdAt: 'x', updatedAt: 'x' }
        : null,
    upsert: async (_: unknown, p: { birthDate: string; timezone: string }) => {
      calls.push('upsert');
      return { userId: U, birthDate: p.birthDate, uiLocale: 'en', languagePool: 'en', timezone: p.timezone, country: null, createdAt: 'x', updatedAt: 'x' };
    },
    extendMinorSignal: async (_: unknown, userId: string, today: string, years: number) => {
      calls.push('minor');
      minor.push({ userId, today, years });
    },
    ensureStateRows: async () => undefined,
  };
  const progression = { recompute: async () => ({ snapshot: true }) };
  const service = new ProfileService(db as never, repo as never, progression as never);
  return { service, db, calls, minor };
}

describe('ProfileService.upsert with an age signal', () => {
  // 20:00 UTC on 7 Oct is already 8 Oct in India: the window starts on the user's own date.
  const now = new Date('2026-10-07T20:00:00Z');

  it('under13 with an adult DOB → 403 under_13 before the database is touched (nothing stored)', async () => {
    const h = harness();
    await expect(h.service.upsert(U, { ...base, ageSignal: 'under13' }, now)).rejects.toMatchObject({ status: 403, code: 'under_13' });
    expect(h.db.withTx).not.toHaveBeenCalled();
  });

  it('under18 with an adult DOB → the invisible flag from the local date + 5 years, in the same transaction', async () => {
    const h = harness();
    const out = await h.service.upsert(U, { ...base, ageSignal: 'under18' }, now);
    expect(h.minor).toEqual([{ userId: U, today: '2026-10-08', years: 5 }]);
    expect(h.calls.indexOf('minor')).toBeGreaterThan(h.calls.indexOf('upsert'));
    // DS-10 / REQ-ACC-10: nothing about the signal or minor status comes back.
    expect(Object.keys(out.profile).sort()).toEqual(['birthDate', 'country', 'createdAt', 'languagePool', 'timezone', 'uiLocale', 'updatedAt', 'userId']);
    expect(JSON.stringify(out)).not.toMatch(/minor|signal|under/i);
  });

  it.each([['adult'], [null], [undefined]])('ageSignal %p → the DOB alone (no flag written)', async (ageSignal) => {
    const h = harness();
    await h.service.upsert(U, { ...base, ageSignal: ageSignal as 'adult' | null | undefined }, now);
    expect(h.minor).toEqual([]);
  });

  it('a different DOB is still refused (409 birth_date_locked), but an under-18 signal is kept', async () => {
    const h = harness('1990-01-01');
    await expect(h.service.upsert(U, { ...base, ageSignal: 'under18' }, now)).rejects.toMatchObject({ status: 409, code: 'birth_date_locked' });
    expect(h.minor).toHaveLength(1);
    expect(h.calls).not.toContain('upsert');
    const h2 = harness('1990-01-01');
    await expect(h2.service.upsert(U, base, now)).rejects.toMatchObject({ status: 409, code: 'birth_date_locked' });
    expect(h2.minor).toEqual([]);
  });
});
