import { Pool } from 'pg';
import { loadEnvFile, DEFAULT_ENV_FILE } from '../../src/config/app-config';
import { SyncRepository } from '../../src/sync/sync.repository';
import { habitPayloadSchema } from '../../src/sync/sync.schema';

loadEnvFile(DEFAULT_ENV_FILE);
const A = '36e2e2e2-0000-4000-8000-00000000000a';
const B = '36e2e2e2-0000-4000-8000-00000000000b';
const HA = '36e2e2e2-1000-4000-8000-000000000001';
const HB = '36e2e2e2-1000-4000-8000-000000000002';

/**
 * W02 (RULES.md §13) against the live local Postgres, without GoTrue: users are inserted directly like the pgTAP tests do,
 * so this exercises the real upsert SQL, `user_is_minor` and the DB backstop trigger.
 */
describe('W02 habit commitments: real SQL', () => {
  let pool: Pool;
  const repo = new SyncRepository();
  beforeAll(async () => {
    pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 2 });
    await pool.query(`delete from auth.users where id in ($1,$2)`, [A, B]);
    await pool.query(
      `insert into auth.users (id, email, aud, role) values ($1,'w02a@aura.test','authenticated','authenticated'),($2,'w02b@aura.test','authenticated','authenticated')`,
      [A, B],
    );
    await pool.query(
      `insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone) values
       ($1, current_date - interval '30 years','en','en','Asia/Kolkata'), ($2, current_date - interval '15 years','en','en','Asia/Kolkata')`,
      [A, B],
    );
  });
  afterAll(async () => {
    await pool.query(`delete from auth.users where id in ($1,$2)`, [A, B]);
    await pool.end();
  });

  const parse = (o: Record<string, unknown>) => habitPayloadSchema.parse({ kind: 'custom', name: 'Read', active: true, ...o });

  it('keeps on undefined, clears on null, refuses a minor at the DB layer, and reads back plain YYYY-MM-DD', async () => {
    expect(await repo.upsertHabit(pool, A, parse({ id: HA, committedFrom: '2026-10-01', pausedThrough: '2026-10-05' }))).toBe(true);
    expect(await repo.findHabit(pool, A, HA)).toEqual({ presetKey: null, committedFrom: '2026-10-01', pausedThrough: '2026-10-05' });
    await repo.upsertHabit(pool, A, parse({ id: HA, name: 'Read more' })); // older client: fields omitted
    expect(await repo.findHabit(pool, A, HA)).toEqual({ presetKey: null, committedFrom: '2026-10-01', pausedThrough: '2026-10-05' });
    await repo.upsertHabit(pool, A, parse({ id: HA, pausedThrough: null }));
    expect(await repo.findHabit(pool, A, HA)).toMatchObject({ committedFrom: '2026-10-01', pausedThrough: null });
    await repo.upsertHabit(pool, A, parse({ id: HA, committedFrom: null }));
    expect(await repo.findHabit(pool, A, HA)).toMatchObject({ committedFrom: null, pausedThrough: null });
    // someone else's id is a no-op
    expect(await repo.upsertHabit(pool, B, parse({ id: HA, committedFrom: null }))).toBe(false);

    expect(await repo.isMinor(pool, A)).toBe(false);
    expect(await repo.isMinor(pool, B)).toBe(true);
    await expect(repo.upsertHabit(pool, B, parse({ id: HB, committedFrom: '2026-10-01' }))).rejects.toMatchObject({ code: '23514' });
    expect(await repo.upsertHabit(pool, B, parse({ id: HB }))).toBe(true); // a minor still tracks habits
    const ledger = await pool.query('select count(*)::int as n from public.starlight_ledger where user_id in ($1,$2)', [A, B]);
    expect(ledger.rows[0].n).toBe(0);
  });
});
