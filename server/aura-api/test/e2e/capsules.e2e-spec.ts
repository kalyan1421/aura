/**
 * F4 Personal Time Capsules end to end (contracts/api/v1-capsules.md): real Nest app + live local Supabase (Auth,
 * Postgres, PostgREST, Storage) + Redis. Covers seal → select-own pull (ciphertext only), sealed-means-sealed, the
 * Free trigger limit, the date window, one-way open, fire (earliest wins), re-arm, delete tombstones, capsule media,
 * the account purge and the 10:00-local unlock push.
 */
import { randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { purgeAccount } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { addYears, unlockAt } from '../../src/capsules/capsule-rules';
import { CapsuleUnlockService, unlockJobId } from '../../src/capsules/capsule-unlock.service';
import { uuidv7 } from '../../src/common/uuid';
import { NotificationsService } from '../../src/notifications/notifications.service';
import { QueuesService } from '../../src/queues/queues.service';
import { addDays, localDate } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, localServiceKey, SUPABASE_URL, type TestUser } from './support';

const TZ = 'Asia/Kolkata';
const DEVICE = uuidv7();
const H = 3600_000;
const ct = (label = 'sealed'): string => randomBytes(48).toString('base64') + Buffer.from(label).toString('base64').slice(0, 8);

/** The contract's pull columns (contracts/api/v1-capsules.md §3) — and nothing else. */
const PULL_COLUMNS = [
  'armed_at',
  'cooldown_until',
  'cycle',
  'deleted_at',
  'fired_at',
  'id',
  'opened_at',
  'opened_device_ts',
  'payload_ct',
  'sealed_at',
  'server_ts',
  'trigger_mood_id',
  'trigger_quadrant',
  'unlock_local_date',
  'unlock_type',
  'updated_at',
  'user_id',
];

describe('F4 capsules (e2e, live local Supabase + Redis)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const sealedDateCapsules: string[] = [];

  const http = () => request(app.getHttpServer());
  const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
  const newUser = async (label: string, tz = TZ): Promise<TestUser> => {
    const u = await createUser(`cap-${label}`);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate: '2004-02-10', uiLocale: 'en', timezone: tz, country: 'IN' }).expect(200);
    return u;
  };
  const push = (u: TestUser, mutations: unknown[]) =>
    as(u, http().post('/v1/sync/push')).send({ deviceId: DEVICE, mutations }).expect(200);
  const reasons = async (u: TestUser, mutations: unknown[]): Promise<string[]> =>
    (await push(u, mutations)).body.results.map((r: { status: string; reason?: string }) => r.reason ?? r.status);

  const todayLocal = () => localDate(new Date(), TZ);
  const seal = (payload: Record<string, unknown>, over: Record<string, unknown> = {}) => ({
    id: uuidv7(),
    entity: 'capsule',
    op: 'seal',
    deviceTs: new Date().toISOString(),
    tz: TZ,
    payload,
    ...over,
  });
  const dateCapsule = (days = 30, over: Record<string, unknown> = {}) => {
    const p = { id: uuidv7(), payloadCt: ct(), unlockType: 'date', unlockLocalDate: addDays(todayLocal(), days), ...over };
    sealedDateCapsules.push(p.id);
    return p;
  };
  const moodCapsule = (target: Record<string, unknown> = { triggerQuadrant: 'storm' }) => ({
    id: uuidv7(),
    payloadCt: ct(),
    unlockType: 'mood',
    ...target,
  });
  const op = (name: string, id: string, deviceTs = new Date().toISOString(), extra: Record<string, unknown> = {}) => ({
    id: uuidv7(),
    entity: 'capsule',
    op: name,
    deviceTs,
    payload: { id, ...extra },
  });
  /** A trigger capsule sealed 3 days ago (armed 2 days ago). */
  const armedTrigger = async (u: TestUser, target?: Record<string, unknown>): Promise<string> => {
    const p = moodCapsule(target);
    expect(await reasons(u, [seal(p, { deviceTs: new Date(Date.now() - 72 * H).toISOString() })])).toEqual(['applied']);
    return p.id;
  };

  /** What the app does: PostgREST select-own with the user's JWT. */
  const pull = async (u: TestUser, query = 'select=*&order=updated_at.asc,id.asc') => {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/capsules?${query}`, {
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${u.token}` },
    });
    return { status: res.status, body: (await res.json()) as Record<string, unknown>[] };
  };
  const row = async (id: string) =>
    (await db.query('select * from public.capsules where id = $1', [id])).rows[0] as Record<string, unknown> | undefined;
  const scheduleRow = async (id: string) =>
    (await db.query('select notify_at, notify_tz, notified_at from public.capsule_unlock_schedule where capsule_id = $1', [id]))
      .rows[0] as { notify_at: Date; notify_tz: string; notified_at: Date | null } | undefined;
  const unlockJob = (id: string) => app.get(QueuesService).queue('capsule-unlock').getJob(unlockJobId(id));
  const jobTime = async (id: string): Promise<number | null> => {
    const j = await unlockJob(id);
    return j ? j.timestamp + (j.delay ?? 0) : null;
  };

  // media helpers
  const uploadUrl = (u: TestUser, body: Record<string, unknown>) => as(u, http().post('/v1/media/upload-url')).send(body);
  const downloadUrl = (u: TestUser, path: string) => as(u, http().post('/v1/media/download-url')).send({ path });
  const putBytes = async (url: string, bytes: Buffer): Promise<number> => {
    const res = await fetch(url, { method: 'PUT', headers: { 'Content-Type': 'application/octet-stream' }, body: bytes });
    await res.arrayBuffer();
    return res.status;
  };
  const objects = async (prefix: string): Promise<string[]> =>
    (
      await db.query<{ name: string }>(
        `select name from storage.objects where bucket_id = 'private-media' and name like $1 || '%' order by name`,
        [prefix],
      )
    ).rows.map((r) => r.name);
  const blobStatus = async (path: string): Promise<number> => {
    const res = await fetch(`${SUPABASE_URL}/storage/v1/object/authenticated/private-media/${path}`, {
      headers: { apikey: localServiceKey(), Authorization: `Bearer ${localServiceKey()}` },
    });
    await res.arrayBuffer();
    return res.status;
  };

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
  });

  afterAll(async () => {
    const media = app.get(PrivateMediaStore);
    for (const u of users) await media.remove(await media.listUserObjects(db, u.id)).catch(() => undefined);
    await app.get(CapsuleUnlockService).unschedule(sealedDateCapsules).catch(() => undefined);
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
  });

  // ---------------------------------------------------------------- seal + pull
  describe('seal → select-own pull', () => {
    it('stores ciphertext + unlock metadata only; the owner pulls exactly the contract columns', async () => {
      const u = await newUser('seal');
      const d = dateCapsule(30);
      const m = moodCapsule({ triggerMoodId: 'overwhelmed' });
      const r = await push(u, [seal(d), seal(m)]);
      expect(r.body.results.map((x: { status: string }) => x.status)).toEqual(['applied', 'applied']);
      expect(r.body.snapshot).toMatchObject({ starlight: { total: 0 } }); // capsules earn nothing

      const { status, body } = await pull(u);
      expect(status).toBe(200);
      expect(body).toHaveLength(2);
      for (const c of body) expect(Object.keys(c).sort()).toEqual(PULL_COLUMNS);
      const date = body.find((c) => c.id === d.id)!;
      const mood = body.find((c) => c.id === m.id)!;
      expect(date).toMatchObject({
        user_id: u.id,
        unlock_type: 'date',
        unlock_local_date: d.unlockLocalDate,
        trigger_mood_id: null,
        trigger_quadrant: null,
        payload_ct: d.payloadCt,
        armed_at: null,
        cycle: 0,
        fired_at: null,
        opened_at: null,
        deleted_at: null,
      });
      expect(mood).toMatchObject({ unlock_type: 'mood', trigger_mood_id: 'overwhelmed', payload_ct: m.payloadCt, unlock_local_date: null });
      expect(Date.parse(mood.armed_at as string) - Date.parse(mood.sealed_at as string)).toBe(24 * H);
    });

    it('select-own: another user pulls nothing of it; clients cannot write through PostgREST; anon reads nothing', async () => {
      const owner = await newUser('owner');
      const stranger = await newUser('stranger');
      const d = dateCapsule(40);
      await push(owner, [seal(d)]);
      expect((await pull(stranger)).body).toEqual([]);
      expect((await pull(stranger, `select=id&id=eq.${d.id}`)).body).toEqual([]);

      const write = await fetch(`${SUPABASE_URL}/rest/v1/capsules`, {
        method: 'POST',
        headers: { apikey: localAnonKey(), Authorization: `Bearer ${owner.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: uuidv7(), user_id: owner.id, unlock_type: 'date', unlock_local_date: '2027-01-01', payload_ct: 'Y3Q=', sealed_at: new Date().toISOString() }),
      });
      expect([401, 403]).toContain(write.status);
      await write.arrayBuffer();
      const edit = await fetch(`${SUPABASE_URL}/rest/v1/capsules?id=eq.${d.id}`, {
        method: 'PATCH',
        headers: { apikey: localAnonKey(), Authorization: `Bearer ${owner.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ opened_at: new Date().toISOString(), opened_device_ts: new Date().toISOString() }),
      });
      expect([401, 403]).toContain(edit.status);
      await edit.arrayBuffer();
      expect((await row(d.id))?.opened_at).toBeNull();

      const anon = await fetch(`${SUPABASE_URL}/rest/v1/capsules?select=*`, { headers: { apikey: localAnonKey() } });
      expect(anon.ok ? ((await anon.json()) as unknown[]).length : 0).toBe(0);
    });

    it('sealed means sealed: an identical re-send is a no-op; changed content or unlock → capsule_sealed', async () => {
      const u = await newUser('immutable');
      const d = dateCapsule(20);
      await push(u, [seal(d)]);
      expect(
        await reasons(u, [
          seal(d),
          seal({ ...d, payloadCt: ct('edited') }),
          seal({ ...d, unlockLocalDate: addDays(d.unlockLocalDate, 1) }),
        ]),
      ).toEqual(['applied', 'capsule_sealed', 'capsule_sealed']);
      expect((await row(d.id))?.payload_ct).toBe(d.payloadCt);
    });

    it('date window: 7 days … 5 years after the seal date; outside → invalid_unlock_date', async () => {
      const u = await newUser('window');
      const fiveYears = addYears(todayLocal(), 5);
      const results = await reasons(u, [
        seal(dateCapsule(6)),
        seal(dateCapsule(7)),
        seal({ ...dateCapsule(0), unlockLocalDate: fiveYears }),
        seal({ ...dateCapsule(0), unlockLocalDate: addDays(fiveYears, 1) }),
        seal({ ...dateCapsule(0), unlockLocalDate: '2026-02-30' }),
      ]);
      expect(results).toEqual(['invalid_unlock_date', 'applied', 'applied', 'invalid_unlock_date', 'invalid_payload']);
    });

    it('Free: a 4th active trigger capsule → trigger_capsule_limit (nothing stored); date capsules unaffected', async () => {
      const u = await newUser('limit');
      await armedTrigger(u);
      await armedTrigger(u);
      const third = await armedTrigger(u);
      const fourth = moodCapsule({ triggerQuadrant: 'rain' });
      expect(await reasons(u, [seal(fourth), seal(dateCapsule(10))])).toEqual(['trigger_capsule_limit', 'applied']);
      expect(await row(fourth.id)).toBeUndefined();
      // "make it a date capsule" — the same capsule id, as a date capsule
      const asDate = { id: fourth.id, payloadCt: fourth.payloadCt, unlockType: 'date', unlockLocalDate: addDays(todayLocal(), 14) };
      sealedDateCapsules.push(fourth.id);
      expect(await reasons(u, [seal(asDate)])).toEqual(['applied']);
      // opening one frees a slot
      expect(await reasons(u, [op('open', third), seal(moodCapsule())])).toEqual(['applied', 'applied']);
    });
  });

  // ---------------------------------------------------------------- open / fire / rearm / delete
  describe('lifecycle', () => {
    it('open is one-way and records the real (server) time; an early date open is tolerated', async () => {
      const u = await newUser('open');
      const d = dateCapsule(60);
      await push(u, [seal(d)]);
      const t0 = Date.now();
      // the device clock was moved past the unlock date to peek: accepted, the server keeps the real time
      const peek = new Date(Date.parse(`${d.unlockLocalDate}T12:00:00Z`)).toISOString();
      expect(await reasons(u, [op('open', d.id, peek)])).toEqual(['applied']);
      const opened = await row(d.id);
      expect(Math.abs((opened?.opened_at as Date).getTime() - t0)).toBeLessThan(10_000);
      expect((opened?.opened_device_ts as Date).toISOString()).toBe(peek);
      expect(await jobTime(d.id)).toBeNull(); // its unlock push is cancelled
      expect(await scheduleRow(d.id)).toBeUndefined();

      expect(await reasons(u, [op('open', d.id)])).toEqual(['applied']);
      expect((await row(d.id))?.opened_at).toEqual(opened?.opened_at);
    });

    it('fire: at most once per cycle, the earliest device time wins; the cooldown is fire + 168 h', async () => {
      const u = await newUser('fire');
      const id = await armedTrigger(u);
      const t1 = new Date(Date.now() - 10 * H).toISOString();
      const t2 = new Date(Date.now() - 5 * H).toISOString();
      const t0 = new Date(Date.now() - 20 * H).toISOString();
      expect(await reasons(u, [op('fire', id, t1), op('fire', id, t2)])).toEqual(['applied', 'applied']);
      let r = await row(id);
      expect((r?.fired_at as Date).toISOString()).toBe(t1);
      // a second device fired it earlier while offline → its fire wins, and the cooldown starts there
      expect(await reasons(u, [op('fire', id, t0)])).toEqual(['applied']);
      r = await row(id);
      expect((r?.fired_at as Date).toISOString()).toBe(t0);
      expect((r?.cooldown_until as Date).getTime() - Date.parse(t0)).toBe(168 * H);
    });

    it('fire / open need an armed trigger capsule; ids, cycles and types are checked', async () => {
      const u = await newUser('fire-rules');
      const fresh = moodCapsule();
      const date = dateCapsule(30);
      await push(u, [seal(fresh), seal(date)]);
      const armed = await armedTrigger(u);
      expect(
        await reasons(u, [
          op('fire', fresh.id),
          op('open', fresh.id),
          op('fire', date.id),
          op('rearm', date.id),
          op('fire', uuidv7()),
          op('fire', armed, undefined, { cycle: 1 }),
          op('rearm', armed),
        ]),
      ).toEqual([
        'capsule_not_armed',
        'capsule_not_armed',
        'not_a_trigger_capsule',
        'not_a_trigger_capsule',
        'capsule_not_found',
        'stale_cycle',
        'capsule_not_opened',
      ]);
    });

    it('rearm ("Keep for next time") starts a new cycle; ops for the old cycle are stale', async () => {
      const u = await newUser('rearm');
      const id = await armedTrigger(u);
      const fireAt = new Date(Date.now() - 2 * H).toISOString();
      expect(await reasons(u, [op('fire', id, fireAt), op('open', id), op('rearm', id)])).toEqual(['applied', 'applied', 'applied']);
      const r = await row(id);
      expect(r).toMatchObject({ cycle: 1, fired_at: null, opened_at: null, opened_device_ts: null });
      expect((r?.cooldown_until as Date).getTime() - Date.parse(fireAt)).toBe(168 * H);
      expect(await reasons(u, [op('fire', id), op('fire', id, undefined, { cycle: 1 })])).toEqual(['stale_cycle', 'applied']);
    });

    it('delete → tombstone (content erased), wins over later ops, and the pull shows it', async () => {
      const u = await newUser('delete');
      const id = await armedTrigger(u, { triggerMoodId: 'lonely' });
      await push(u, [op('fire', id, new Date(Date.now() - H).toISOString())]);
      expect(await reasons(u, [op('delete', id)])).toEqual(['applied']);
      const pulled = (await pull(u, `select=*&id=eq.${id}`)).body[0];
      expect(pulled).toMatchObject({ id, payload_ct: null, trigger_mood_id: null, trigger_quadrant: null, unlock_local_date: null });
      expect(pulled.deleted_at).not.toBeNull();
      expect(pulled.cooldown_until).not.toBeNull(); // the fire still holds the global cooldown
      expect(
        await reasons(u, [op('open', id), op('fire', id), op('rearm', id), seal({ ...moodCapsule(), id }), op('delete', id), op('delete', uuidv7())]),
      ).toEqual(['capsule_deleted', 'capsule_deleted', 'capsule_deleted', 'capsule_deleted', 'applied', 'applied']);
    });

    it("a capsule id owned by someone else → id_conflict; deleting it is a silent no-op", async () => {
      const owner = await newUser('conflict-owner');
      const other = await newUser('conflict-other');
      const d = dateCapsule(15);
      await push(owner, [seal(d)]);
      expect(await reasons(other, [seal({ ...d, payloadCt: ct('mine') }), op('delete', d.id), op('open', d.id)])).toEqual([
        'id_conflict',
        'applied',
        'capsule_not_found',
      ]);
      expect(await row(d.id)).toMatchObject({ user_id: owner.id, payload_ct: d.payloadCt, deleted_at: null });
    });
  });

  // ---------------------------------------------------------------- media
  describe('capsule media', () => {
    it('upload before the seal → seal → an occupied slot is 409 capsule_sealed, an empty one can still be filled once', async () => {
      const u = await newUser('media');
      const d = dateCapsule(30);
      const voice = await uploadUrl(u, { kind: 'capsule_voice', recordId: d.id, bytes: 2048 }).expect(200);
      expect(voice.body.path).toBe(`${u.id}/capsules/${d.id}/voice`);
      const photo = await uploadUrl(u, { kind: 'capsule_photo', recordId: d.id, index: 0, bytes: 4096 }).expect(200);
      expect(photo.body.path).toBe(`${u.id}/capsules/${d.id}/photo-0`);
      const voiceBytes = randomBytes(2048);
      expect(await putBytes(voice.body.uploadUrl, voiceBytes)).toBe(200);
      expect(await putBytes(photo.body.uploadUrl, randomBytes(4096))).toBe(200);
      // a retry before the seal is still an upsert
      await uploadUrl(u, { kind: 'capsule_voice', recordId: d.id, bytes: 2048 }).expect(200);

      await push(u, [seal(d)]);
      const sealed = await uploadUrl(u, { kind: 'capsule_voice', recordId: d.id, bytes: 2048 }).expect(409);
      expect(sealed.body).toEqual({ code: 'capsule_sealed', message: expect.any(String) });
      await uploadUrl(u, { kind: 'capsule_photo', recordId: d.id, index: 0, bytes: 10 }).expect(409);
      const late = await uploadUrl(u, { kind: 'capsule_photo', recordId: d.id, index: 1, bytes: 1024 }).expect(200);
      expect(await putBytes(late.body.uploadUrl, randomBytes(1024))).toBe(200);

      const down = await downloadUrl(u, voice.body.path).expect(200);
      const got = await fetch(down.body.downloadUrl);
      expect(Buffer.from(await got.arrayBuffer()).equals(voiceBytes)).toBe(true);
      expect(await objects(`${u.id}/capsules/${d.id}/`)).toEqual([
        `${u.id}/capsules/${d.id}/photo-0`,
        `${u.id}/capsules/${d.id}/photo-1`,
        `${u.id}/capsules/${d.id}/voice`,
      ]);

      // delete → objects gone (rows and blobs), downloads 404, uploads 409 capsule_deleted
      expect(await reasons(u, [op('delete', d.id)])).toEqual(['applied']);
      expect(await objects(`${u.id}/capsules/${d.id}/`)).toEqual([]);
      expect(await blobStatus(voice.body.path)).not.toBe(200);
      await downloadUrl(u, voice.body.path).expect(404);
      const gone = await uploadUrl(u, { kind: 'capsule_photo', recordId: d.id, index: 2, bytes: 10 }).expect(409);
      expect(gone.body.code).toBe('capsule_deleted');
    });

    it('limits and validation: voice ≤ 2 MiB, photo ≤ 4 MiB, index 0–2 only for photos; paths stay in the caller’s prefix', async () => {
      const u = await newUser('media-limits');
      const other = await newUser('media-other');
      const id = uuidv7();
      await uploadUrl(u, { kind: 'capsule_voice', recordId: id, bytes: 2_097_152 }).expect(200);
      expect((await uploadUrl(u, { kind: 'capsule_voice', recordId: id, bytes: 2_097_153 }).expect(400)).body.code).toBe('media_too_large');
      await uploadUrl(u, { kind: 'capsule_photo', recordId: id, index: 2, bytes: 4_194_304 }).expect(200);
      expect((await uploadUrl(u, { kind: 'capsule_photo', recordId: id, index: 2, bytes: 4_194_305 }).expect(400)).body.code).toBe(
        'media_too_large',
      );
      for (const body of [
        { kind: 'capsule_photo', recordId: id, bytes: 10 },
        { kind: 'capsule_photo', recordId: id, index: 3, bytes: 10 },
        { kind: 'capsule_voice', recordId: id, index: 0, bytes: 10 },
      ]) {
        expect((await uploadUrl(u, body).expect(400)).body.code).toBe('invalid_request');
      }
      // someone else asking for the same capsule id gets their own prefix, and can never read ours
      const theirs = await uploadUrl(other, { kind: 'capsule_voice', recordId: id, bytes: 10 }).expect(200);
      expect(theirs.body.path).toBe(`${other.id}/capsules/${id}/voice`);
      await downloadUrl(other, `${u.id}/capsules/${id}/voice`).expect(404);
    });
  });

  // ---------------------------------------------------------------- unlock push
  describe('date-capsule unlock push', () => {
    it('one delayed job at 10:00 local on the unlock date; re-scheduled by the sweep when the profile zone changes', async () => {
      const u = await newUser('unlock');
      const d = dateCapsule(45);
      await push(u, [seal(d)]);
      const ist = unlockAt(d.unlockLocalDate, TZ).getTime();
      expect(Math.abs((await jobTime(d.id))! - ist)).toBeLessThan(5_000);
      expect(await scheduleRow(d.id)).toEqual({ notify_at: new Date(ist), notify_tz: TZ, notified_at: null });
      const job = await unlockJob(d.id);
      expect(job?.data).toEqual({ capsuleId: d.id }); // nothing else: no user id, no content, no date
      expect(job?.id).not.toContain(d.id);

      // the user flies to New York; the app re-sends the profile; the worker sweep moves the push to 10:00 there
      await as(u, http().post('/v1/profile')).send({ birthDate: '2004-02-10', uiLocale: 'en', timezone: 'America/New_York', country: 'IN' }).expect(200);
      await app.get(CapsuleUnlockService).sweep();
      const ny = unlockAt(d.unlockLocalDate, 'America/New_York').getTime();
      expect(Math.abs((await jobTime(d.id))! - ny)).toBeLessThan(5_000);
      expect(await scheduleRow(d.id)).toMatchObject({ notify_at: new Date(ny), notify_tz: 'America/New_York' });
    });

    it('at 10:00 the worker sends one content-free push (deduplicated per user + day); opened or deleted capsules send none', async () => {
      const u = await newUser('unlock-send', 'Asia/Kolkata');
      const a = dateCapsule(30);
      const b = dateCapsule(30); // same day → the same dedupe key
      const opened = dateCapsule(30);
      const deleted = dateCapsule(30);
      await push(u, [seal(a), seal(b), seal(opened), seal(deleted), op('open', opened.id), op('delete', deleted.id)]);
      expect(await jobTime(opened.id)).toBeNull();
      expect(await jobTime(deleted.id)).toBeNull();

      const unlock = app.get(CapsuleUnlockService);
      const notifications = app.get(NotificationsService);
      const spy = jest.spyOn(notifications, 'enqueue').mockResolvedValue(undefined);
      try {
        const at = unlockAt(a.unlockLocalDate, TZ);
        expect(await unlock.process(a.id, at)).toEqual({ status: 'notified' });
        expect(await unlock.process(b.id, at)).toEqual({ status: 'notified' });
        expect(await unlock.process(a.id, at)).toEqual({ status: 'already_notified' });
        expect(await unlock.process(opened.id, at)).toEqual({ status: 'skipped' });
        expect(await unlock.process(deleted.id, at)).toEqual({ status: 'skipped' });
        expect(spy.mock.calls).toEqual([
          [u.id, 'capsule_unlocked', a.id, { dedupeKey: a.unlockLocalDate }],
          [u.id, 'capsule_unlocked', b.id, { dedupeKey: b.unlockLocalDate }],
        ]);
        expect((await scheduleRow(a.id))?.notified_at).toBeInstanceOf(Date);
        // a notified capsule is never re-scheduled by the sweep
        await unlock.sweep();
        expect((await scheduleRow(a.id))?.notified_at).toBeInstanceOf(Date);
      } finally {
        spy.mockRestore();
      }
    });

    it('NotificationsService dedupes on the queue: the same user + key within the TTL is one job', async () => {
      const u = await newUser('dedupe');
      const q = app.get(QueuesService).queue('notifications');
      const key = `e2e-${uuidv7()}`;
      const before = await q.getJobCounts('waiting', 'delayed', 'active', 'completed', 'prioritized');
      await app.get(NotificationsService).enqueue(u.id, 'capsule_unlocked', uuidv7(), { dedupeKey: key, dedupeTtlMs: 60_000 });
      await app.get(NotificationsService).enqueue(u.id, 'capsule_unlocked', uuidv7(), { dedupeKey: key, dedupeTtlMs: 60_000 });
      const after = await q.getJobCounts('waiting', 'delayed', 'active', 'completed', 'prioritized');
      const total = (c: Record<string, number>) => Object.values(c).reduce((x, y) => x + y, 0);
      expect(total(after) - total(before)).toBe(1);
      // clean up our job (no worker runs in e2e)
      for (const j of await q.getJobs(['waiting', 'prioritized'])) if (j.data?.userId === u.id) await j.remove();
    });
  });

  // ---------------------------------------------------------------- account purge
  it('the account purge removes every capsule row (tombstones too), their schedule, media and unlock jobs', async () => {
    const u = await newUser('purge');
    const bystander = await newUser('purge-bystander');
    const d = dateCapsule(30);
    const kept = dateCapsule(30);
    const m = moodCapsule();
    const up = await uploadUrl(u, { kind: 'capsule_photo', recordId: d.id, index: 0, bytes: 64 }).expect(200);
    expect(await putBytes(up.body.uploadUrl, randomBytes(64))).toBe(200);
    const gone = dateCapsule(30);
    await push(u, [seal(d), seal(m), seal(gone), op('delete', gone.id)]);
    await push(bystander, [seal(kept)]);
    expect(await jobTime(d.id)).not.toBeNull();

    await as(u, http().post('/v1/account/deletion')).expect(202);
    await db.query(
      `update public.account_deletions set requested_at = now() - interval '8 days', scheduled_for = now() - interval '1 day'
        where user_id = $1`,
      [u.id],
    );
    const out = await purgeAccount(db, app.get(PrivateMediaStore), u.id, app.get(CapsuleUnlockService));
    expect(out.status).toBe('purged');
    expect(Number((await db.query('select count(*) from public.capsules where user_id = $1', [u.id])).rows[0].count)).toBe(0);
    expect(await scheduleRow(d.id)).toBeUndefined();
    expect(await jobTime(d.id)).toBeNull();
    expect(await objects(`${u.id}/`)).toEqual([]);
    // nobody else's capsule is touched
    expect(await row(kept.id)).toMatchObject({ user_id: bystander.id, deleted_at: null });
    expect(await jobTime(kept.id)).not.toBeNull();
  });
});
