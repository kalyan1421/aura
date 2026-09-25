/**
 * Orphan private-media sweep (src/media/orphan-sweep.ts; contracts/api/v1.md "Media"): against the live local Postgres
 * (storage.objects metadata, like the purge reads it). Uses its own random user prefix only and removes what it adds;
 * Storage itself is replaced by a recorder (no object bytes are needed to test the selection).
 */
import { randomUUID } from 'node:crypto';
import type { Pool } from 'pg';
import { PRIVATE_MEDIA_BUCKET } from '../../src/account/private-media';
import { findOrphanMedia, sweepOrphanMedia } from '../../src/media/orphan-sweep';
import { createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(60_000);

describe('orphan private-media sweep (e2e)', () => {
  let db: Pool;
  let u: TestUser;
  const names: string[] = [];

  const put = async (name: string, daysOld: number) => {
    names.push(name);
    await db.query(
      `insert into storage.objects (bucket_id, name, owner_id, created_at) values ($1, $2, $3, now() - make_interval(days => $4))`,
      [PRIVATE_MEDIA_BUCKET, name, u.id, daysOld],
    );
  };

  beforeAll(async () => {
    db = dbPool();
    u = await createUser('media-sweep');
    await db.query(
      `insert into public.profiles (user_id, birth_date, ui_locale, language_pool, timezone, country)
       values ($1, '1995-05-05', 'en', 'en', 'Asia/Kolkata', 'IN')`,
      [u.id],
    );
  });

  afterAll(async () => {
    // Metadata rows only (no bytes were stored): Storage refuses direct deletes unless asked explicitly.
    const c = await db.connect();
    try {
      await c.query('begin');
      await c.query(`set local storage.allow_delete_query = 'true'`);
      await c.query('delete from storage.objects where bucket_id = $1 and name = any($2::text[])', [PRIVATE_MEDIA_BUCKET, names]);
      await c.query('commit');
    } finally {
      c.release();
    }
    await deleteUser(u.id);
    await db.end();
  });

  it('finds only month-old uploads with no record; leaves referenced, recent and foreign-shaped objects', async () => {
    const kept = randomUUID();
    const orphanVoice = randomUUID();
    const recentVoice = randomUUID();
    const liveCapsule = randomUUID();
    const orphanCapsule = randomUUID();
    await db.query(
      `insert into public.check_ins (id, user_id, mood_id, quadrant, local_day, device_ts, voice_path)
       values ($1, $2, 'calm', 'moonlight', '2026-08-01', '2026-08-01T10:00:00Z', $3)`,
      [kept, u.id, `${u.id}/voice/${kept}`],
    );
    await db.query(
      `insert into public.capsules (id, user_id, unlock_type, unlock_local_date, payload_ct, sealed_at)
       values ($1, $2, 'date', '2027-08-01', $3, '2026-08-01T10:00:00Z')`,
      [liveCapsule, u.id, 'A'.repeat(40)],
    );
    await put(`${u.id}/voice/${kept}`, 60); // referenced
    await put(`${u.id}/voice/${orphanVoice}`, 60); // orphan
    await put(`${u.id}/voice/${recentVoice}`, 2); // too recent: its push may still be on the way
    await put(`${u.id}/capsules/${liveCapsule}/photo-0`, 60); // its capsule exists
    await put(`${u.id}/capsules/${orphanCapsule}/voice`, 60); // never sealed on the server
    await put(`${u.id}/other/thing`, 60); // not a shape this sweep owns

    const found = (await findOrphanMedia(db, 30, 10_000)).filter((n) => n.startsWith(`${u.id}/`)).sort();
    expect(found).toEqual([`${u.id}/capsules/${orphanCapsule}/voice`, `${u.id}/voice/${orphanVoice}`].sort());
  });

  it('removes through Storage; without a service key it does nothing', async () => {
    const removed: string[] = [];
    const idle = await sweepOrphanMedia(db, { configured: false, remove: async () => 0 });
    expect(idle).toEqual({ found: 0, removed: 0 });
    const r = await sweepOrphanMedia(db, {
      configured: true,
      remove: async (n) => {
        removed.push(...n);
        return n.length;
      },
    });
    expect(r.removed).toBe(r.found);
    expect(removed.filter((n) => n.startsWith(`${u.id}/`))).toHaveLength(2);
  });
});
