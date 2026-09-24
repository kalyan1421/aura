/**
 * Reduced mode's sign-up throttle (PRD 19; src/profile/signup-throttle.ts): off → nothing; on → at most
 * `signupsPerHour` new profiles per rolling hour (default 20), serialised by an advisory lock; ProfileService applies
 * it to NEW profiles only.
 */
import { ApiError } from '../../src/common/api-error';
import { ProfileService } from '../../src/profile/profile.service';
import {
  DEFAULT_SIGNUPS_PER_HOUR,
  SignupThrottle,
  throttleSettings,
} from '../../src/profile/signup-throttle';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';

class FakeQ {
  constructor(
    private flag: { enabled: boolean; payload: Record<string, unknown> | null } | null,
    private recent: number,
  ) {}
  statements: string[] = [];
  async query(sql: string) {
    this.statements.push(sql.slice(0, 40));
    if (sql.includes('from public.feature_flags')) return { rows: this.flag ? [this.flag] : [], rowCount: this.flag ? 1 : 0 };
    if (sql.includes('pg_advisory_xact_lock')) return { rows: [], rowCount: 1 };
    if (sql.includes('from public.profiles where created_at')) return { rows: [{ n: this.recent }], rowCount: 1 };
    throw new Error(sql);
  }
}

describe('throttleSettings', () => {
  it('off without the flag; the default allowance unless the payload sets a sane one', () => {
    expect(throttleSettings(undefined)).toEqual({ on: false, perHour: DEFAULT_SIGNUPS_PER_HOUR });
    expect(throttleSettings({ enabled: true, payload: {} })).toEqual({ on: true, perHour: DEFAULT_SIGNUPS_PER_HOUR });
    expect(throttleSettings({ enabled: true, payload: { signupsPerHour: 5 } }).perHour).toBe(5);
    expect(throttleSettings({ enabled: true, payload: { signupsPerHour: 0 } }).perHour).toBe(0);
    expect(throttleSettings({ enabled: true, payload: { signupsPerHour: -1 } }).perHour).toBe(DEFAULT_SIGNUPS_PER_HOUR);
    expect(throttleSettings({ enabled: true, payload: { signupsPerHour: '5' } }).perHour).toBe(DEFAULT_SIGNUPS_PER_HOUR);
  });
});

describe('SignupThrottle.check', () => {
  const t = new SignupThrottle();
  it('reduced mode off: no lock, no count', async () => {
    const q = new FakeQ({ enabled: false, payload: {} }, 999);
    await t.check(q as never);
    expect(q.statements).toHaveLength(1);
  });

  it('on: under the allowance passes; at it → 503 signups_throttled', async () => {
    await expect(t.check(new FakeQ({ enabled: true, payload: { signupsPerHour: 3 } }, 2) as never)).resolves.toBeUndefined();
    const err = await t.check(new FakeQ({ enabled: true, payload: { signupsPerHour: 3 } }, 3) as never).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 503, code: 'signups_throttled' });
  });
});

describe('ProfileService applies it to new profiles only', () => {
  const req = { birthDate: '1996-03-14', uiLocale: 'en' as const, timezone: 'Asia/Kolkata', country: 'IN' };
  const make = (existing: boolean) => {
    const checks: number[] = [];
    const tx = { query: async () => ({ rows: [], rowCount: 1 }) };
    const db = { withTx: async <T>(f: (q: typeof tx) => Promise<T>) => f(tx) };
    const repo = {
      find: async () => (existing ? { birthDate: req.birthDate, timezone: req.timezone } : null),
      upsert: async () => ({ timezone: req.timezone }),
      ensureStateRows: async () => undefined,
      extendMinorSignal: async () => undefined,
    };
    const progression = { recompute: async () => ({}) };
    const throttle = {
      check: async () => {
        checks.push(1);
        throw new ApiError(503, 'signups_throttled', 'slow');
      },
    };
    return { svc: new ProfileService(db as never, repo as never, progression as never, throttle as never), checks };
  };

  it('a sign-up while throttled is refused before any write', async () => {
    const { svc, checks } = make(false);
    await expect(svc.upsert(USER, req)).rejects.toMatchObject({ code: 'signups_throttled' });
    expect(checks).toEqual([1]);
  });

  it('an existing account updating its profile is never throttled', async () => {
    const { svc, checks } = make(true);
    await expect(svc.upsert(USER, req)).resolves.toBeDefined();
    expect(checks).toEqual([]);
  });
});
