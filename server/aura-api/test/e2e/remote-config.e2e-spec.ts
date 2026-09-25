/**
 * Remote flags, signed reversible lexicon versions and device bans (PRD 19 REQ-ADM-12 / REQ-ADM-14), end to end
 * against the live local stack: NestJS app, Postgres (migration 20261005000017), Supabase Auth with real TOTP staff
 * sessions (AAL2), Redis.
 *
 * Covers: GET /v1/config (public, ETag / 304, a console flag flip shows up), the rooms kill switch (503 rooms_paused),
 * lexicon upload → vectors gate → test samples → publish → signed download the app can verify → rollback (crisis
 * removals need an explicit yes) → audit rows, a tampered stored envelope failing verification, immutable versions;
 * device bans: install recorded on profile, instant-ban service call, 403 device_banned on profile / devices / match,
 * account routes still open, console list / ban / lift (Owner only; Moderator 403 audited), a ban outliving the account.
 */
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { DeviceBansService } from '../../src/devices/device-bans.service';
import { installHash } from '../../src/devices/install-id';
import { AppConfig } from '../../src/config/app-config';
import { baselineLexicon } from '../../src/remote-config/lexicon/document';
import { LexiconService } from '../../src/remote-config/lexicon.service';
import { RemoteConfigService } from '../../src/remote-config/remote-config.service';
import { BundleSigner, trustedKeys, verifyBundle } from '../../src/remote-config/signing';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, type TestUser } from './support';

jest.setTimeout(90_000);

const ADULT_DOB = '1994-07-21';
const DEV_KEYS = trustedKeys([BundleSigner.dev().publicKeyBase64]);

function base32Decode(s: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const c of s.replace(/=+$/, '').toUpperCase()) {
    const i = alphabet.indexOf(c);
    if (i < 0) continue;
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function totp(secret: string, at = Date.now()): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)));
  const h = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

describe('Remote config, signed lexicon versions, device bans (e2e)', () => {
  let app: INestApplication;
  let db: Pool;
  let masterKey: Buffer;
  const users: TestUser[] = [];
  const reportIds: string[] = [];
  const installs: string[] = [];
  const savedEnv: Record<string, string | undefined> = {};
  // A throwaway flag only this run flips: flipping a real one (e.g. rooms_pool_hi) races other suites and a live worker.
  const probeFlag = `e2e_probe_${randomUUID().slice(0, 8)}`;
  let savedCurrent: { version: number } | null = null;
  let createdVersions: number[] = [];
  let owner: TestUser;
  let moderator: TestUser;

  const http = () => request(app.getHttpServer());
  const as = (u: { token: string }, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);
  const newInstall = (): string => {
    const id = randomBytes(32).toString('base64url');
    installs.push(id);
    return id;
  };
  const refresh = (): void => {
    app.get(RemoteConfigService).invalidate();
    (app.get(LexiconService) as unknown as { cached: unknown }).cached = null;
  };

  async function gotrue(path: string, token: string, body?: unknown): Promise<Record<string, unknown>> {
    const res = await fetch(`${SUPABASE_URL}/auth/v1${path}`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`gotrue ${path}: ${res.status} ${text}`);
    return text ? (JSON.parse(text) as Record<string, unknown>) : {};
  }

  async function staff(label: string, role: 'owner' | 'moderator'): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await db.query('insert into public.admin_staff (staff_id, role, display_name) values ($1, $2, $3)', [u.id, role, `E2E ${label}`]);
    const factor = await gotrue('/factors', u.token, { factor_type: 'totp', friendly_name: `e2e-${randomBytes(3).toString('hex')}` });
    const secret = (factor.totp as { secret: string }).secret;
    const challenge = await gotrue(`/factors/${factor.id as string}/challenge`, u.token);
    const verified = await gotrue(`/factors/${factor.id as string}/verify`, u.token, { challenge_id: challenge.id, code: totp(secret) });
    return { ...u, token: verified.access_token as string };
  }

  async function appUser(label: string): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    return u;
  }

  const profile = (u: TestUser, install?: string): request.Test => {
    let r = as(u, http().post('/v1/profile'));
    if (install) r = r.set('X-Aura-Install', install).set('X-Aura-Platform', 'ios');
    return r.send({ birthDate: ADULT_DOB, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' });
  };

  beforeAll(async () => {
    for (const [k, v] of Object.entries({ ADMIN_ALLOWED_EMAILS: '', LEXICON_SIGNING_KEY: '', REMOTE_CONFIG_CACHE_MS: '0', APP_MIN_VERSION_IOS: '', APP_MIN_VERSION_ANDROID: '0.1.0' })) {
      savedEnv[k] = process.env[k];
      process.env[k] = v;
    }
    app = await bootApp();
    db = dbPool();
    masterKey = app.get(AppConfig).masterKey;
    await db.query(`insert into public.feature_flags (key, enabled, description) values ($1, false, 'e2e probe (remote-config suite)')`, [probeFlag]);
    savedCurrent = (await db.query<{ version: number }>(`select version from public.signed_bundle_current where kind = 'crisis_lexicon'`)).rows[0] ?? null;
    owner = await staff('rc-owner', 'owner');
    moderator = await staff('rc-mod', 'moderator');
  });

  afterAll(async () => {
    if (db) {
      await db.query('delete from public.feature_flags where key = $1', [probeFlag]);
      await db.query(`update public.feature_flags set enabled = true where key = 'rooms_enabled'`);
      // Put the live lexicon back the way it was, then drop this run's versions (only non-live ones can go).
      if (savedCurrent) {
        const live = (await db.query<{ version: number }>(`select version from public.signed_bundle_current where kind = 'crisis_lexicon'`)).rows[0];
        if (live?.version !== savedCurrent.version) {
          await app.get(LexiconService).publish('staff:e2e-cleanup', { version: savedCurrent.version, reasonCode: 'e2e_cleanup', allowCrisisRemovals: true });
        }
      } else {
        await db.query(`delete from public.signed_bundle_current where kind = 'crisis_lexicon'`);
      }
      if (createdVersions.length) {
        await db.query(`delete from public.signed_bundle_versions where kind = 'crisis_lexicon' and version = any($1::int[])`, [createdVersions]);
      }
      await db.query('delete from public.device_bans where install_hash = any($1::text[])', [installs.map((i) => installHash(masterKey, i))]);
      await db.query('delete from public.reports where id = any($1::uuid[])', [reportIds]);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
    for (const [k, v] of Object.entries(savedEnv)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  });

  // ================================================================== flags
  describe('GET /v1/config', () => {
    it('is public, lists the flags and kill switches, and answers If-None-Match with 304', async () => {
      refresh();
      const r = await http().get('/v1/config').expect(200);
      expect(r.headers['cache-control']).toBe('no-cache');
      expect(r.headers.etag).toBe(`"${r.body.configVersion}"`);
      expect(r.body.pollSeconds).toBeLessThanOrEqual(300);
      expect(r.body.flags).toMatchObject({ rooms_pool_hi: { enabled: expect.any(Boolean) }, rooms_enabled: { enabled: expect.any(Boolean) } });
      await http().get('/v1/config').set('If-None-Match', r.headers.etag).expect(304);
      // Nothing about the caller: the same document with or without a session.
      const u = await appUser('rc-anon');
      expect((await as(u, http().get('/v1/config')).expect(200)).body).toEqual(r.body);
    });

    it('a flag flipped in the console reaches the document (new ETag) — no release needed', async () => {
      refresh();
      const before = await http().get('/v1/config').expect(200);
      expect(before.body.flags[probeFlag].enabled).toBe(false);
      const flip = await as(owner, http().post(`/admin/config/flags/${probeFlag}`)).send({ enabled: true, reasonCode: 'e2e_flag_flip' });
      expect(flip.status).toBe(200);
      refresh();
      const after = await http().get('/v1/config').set('If-None-Match', before.headers.etag).expect(200);
      expect(after.body.flags[probeFlag].enabled).toBe(true);
      expect(after.headers.etag).not.toBe(before.headers.etag);
      const touched = await db.query<{ updated_at: Date }>('select updated_at from public.feature_flags where key = $1', [probeFlag]);
      expect(Date.now() - touched.rows[0].updated_at.getTime()).toBeLessThan(60_000);
    });

    it('minAppVersion (MASVS F-6): env baseline, raised by the min_app_version flag while it is on', async () => {
      const saved = (await db.query<{ enabled: boolean; payload: unknown; description: string | null }>(
        'select enabled, payload, description from public.feature_flags where key = $1',
        ['min_app_version'],
      )).rows[0];
      try {
        await db.query('delete from public.feature_flags where key = $1', ['min_app_version']);
        refresh();
        const envOnly = await http().get('/v1/config').expect(200);
        expect(envOnly.body.minAppVersion).toEqual({ android: '0.1.0' });
        await db.query(
          `insert into public.feature_flags (key, enabled, payload, description) values ('min_app_version', true, $1::jsonb, 'e2e min version')`,
          [JSON.stringify({ ios: '2.0.0', android: '0.0.9' })],
        );
        refresh();
        const raised = await http().get('/v1/config').set('If-None-Match', envOnly.headers.etag).expect(200);
        expect(raised.body.minAppVersion).toEqual({ ios: '2.0.0', android: '0.1.0' });
        // Switched off in the console: back to the env values at once.
        const off = await as(owner, http().post('/admin/config/flags/min_app_version')).send({ enabled: false, reasonCode: 'e2e_min_version' });
        expect(off.status).toBe(200);
        refresh();
        expect((await http().get('/v1/config').expect(200)).body.minAppVersion).toEqual({ android: '0.1.0' });
      } finally {
        await db.query('delete from public.feature_flags where key = $1', ['min_app_version']);
        if (saved) {
          await db.query('insert into public.feature_flags (key, enabled, payload, description) values ($1, $2, $3::jsonb, $4)', [
            'min_app_version',
            saved.enabled,
            JSON.stringify(saved.payload ?? {}),
            saved.description,
          ]);
        }
        refresh();
      }
    });

    it('rooms kill switch: rooms_enabled off → POST /v1/rooms/match 503 rooms_paused', async () => {
      const u = await appUser('rc-rooms');
      await profile(u).expect(200);
      await db.query(`update public.feature_flags set enabled = false where key = 'rooms_enabled'`);
      refresh();
      const r = await as(u, http().post('/v1/rooms/match')).send({ quadrant: 'moonlight', moodId: 'calm', timezone: 'Asia/Kolkata' });
      expect(r.status).toBe(503);
      expect(r.body.code).toBe('rooms_paused');
      expect((await http().get('/v1/config').expect(200)).body.flags.rooms_enabled.enabled).toBe(false);
      await db.query(`update public.feature_flags set enabled = true where key = 'rooms_enabled'`);
      refresh();
      const again = await as(u, http().post('/v1/rooms/match')).send({ quadrant: 'moonlight', moodId: 'calm', timezone: 'Asia/Kolkata' });
      expect(again.status).not.toBe(503);
    });
  });

  // ================================================================== lexicon versions
  describe('signed lexicon versions', () => {
    let next: number;

    const lexicon = (version: number, extra: Array<Record<string, unknown>> = []): Record<string, unknown> => {
      const doc = structuredClone(baselineLexicon()) as unknown as Record<string, unknown>;
      doc.version = version;
      (doc.entries as unknown[]).push(...extra);
      return doc;
    };
    const NEW_ENTRY = { id: 'en.no_way_out_e2e', language: 'en', kind: 'crisis', phrase: 'no way out for me', variants: ['theres no way out for me'] };

    beforeAll(async () => {
      const max = (await db.query<{ v: number | null }>(`select max(version) as v from public.signed_bundle_versions where kind = 'crisis_lexicon'`)).rows[0].v;
      next = Math.max(max ?? 1, 1) + 1;
      if (!(await db.query(`select 1 from public.signed_bundle_versions where kind = 'crisis_lexicon' and version = 1`)).rowCount) {
        const r = await as(owner, http().post('/admin/lexicons/crisis/versions/baseline')).expect(201);
        expect(r.body).toMatchObject({ version: 1, entries: baselineLexicon().entries.length });
        createdVersions.push(1);
      }
    });

    it('the overview shows the signing key (dev here) and the stored versions; a Moderator may read, not publish', async () => {
      const r = await as(owner, http().get('/admin/lexicons/crisis')).expect(200);
      expect(r.headers['cache-control']).toBe('no-store');
      expect(r.body).toMatchObject({ kind: 'crisis_lexicon', bundledVersion: 1, signing: { available: true, keyId: 'ba9afcf9c1f7ab25', devKey: true } });
      expect(r.body.versions.map((v: { version: number }) => v.version)).toContain(1);
      await as(moderator, http().get('/admin/lexicons/crisis')).expect(200);
      const denied = await as(moderator, http().post('/admin/lexicons/crisis/publish')).send({ version: 1, reasonCode: 'nope' });
      expect(denied.status).toBe(403);
      expect(denied.body.code).toBe('forbidden_role');
      await as(moderator, http().post('/admin/lexicons/crisis/versions')).send({ lexicon: lexicon(next) }).expect(403);
    });

    it('refuses an invalid lexicon, and one that fails the contract vectors (details say which)', async () => {
      const bad = lexicon(next);
      bad.name = 'something.else';
      const invalid = await as(owner, http().post('/admin/lexicons/crisis/versions')).send({ lexicon: bad }).expect(422);
      expect(invalid.body).toMatchObject({ code: 'lexicon_invalid', details: [expect.stringContaining('name')] });

      const weakened = lexicon(next);
      weakened.entries = (weakened.entries as Array<{ id: string }>).filter((e) => e.id !== 'en.kill_myself');
      const failed = await as(owner, http().post('/admin/lexicons/crisis/versions')).send({ lexicon: weakened }).expect(422);
      expect(failed.body.code).toBe('lexicon_vectors_failed');
      expect(failed.body.details[0]).toMatchObject({ source: 'contract', expected: 'crisis', actual: 'none' });

      const ownFail = await as(owner, http().post('/admin/lexicons/crisis/versions'))
        .send({ lexicon: lexicon(next), vectors: [{ text: 'no way out for me', verdict: 'crisis', why: 'needs the new entry' }] })
        .expect(422);
      expect(ownFail.body.details).toEqual([expect.objectContaining({ source: 'version', index: 0 })]);
      expect((await db.query(`select 1 from public.signed_bundle_versions where kind = 'crisis_lexicon' and version = $1`, [next])).rowCount).toBe(0);
    });

    it('upload → test on samples → publish → the app downloads a bundle it can verify (ETag / 304)', async () => {
      const up = await as(owner, http().post('/admin/lexicons/crisis/versions'))
        .send({ lexicon: lexicon(next, [NEW_ENTRY]), vectors: [{ text: 'there is no way out for me', verdict: 'crisis' }], note: 'e2e' })
        .expect(201);
      createdVersions.push(next);
      expect(up.body).toMatchObject({ version: next, entries: baselineLexicon().entries.length + 1 });
      expect(up.body.diff).toMatchObject({ added: ['en.no_way_out_e2e'], crisisFormsRemoved: 0, crisisFormsAdded: 2 });
      await as(owner, http().post('/admin/lexicons/crisis/versions')).send({ lexicon: lexicon(next, [NEW_ENTRY]) }).expect(409);

      const t = await as(moderator, http().post('/admin/lexicons/crisis/test'))
        .send({ version: next, samples: ['no way out for me', 'dying of boredom', 'tea with amma'] })
        .expect(200);
      expect(t.body.results.map((x: { verdict: string }) => x.verdict)).toEqual(['crisis', 'soft', 'none']);

      const pub = await as(owner, http().post('/admin/lexicons/crisis/publish')).send({ version: next, reasonCode: 'e2e_publish' }).expect(200);
      expect(pub.body).toMatchObject({ version: next, keyId: 'ba9afcf9c1f7ab25', action: 'lexicon_publish' });
      refresh();

      const dl = await http().get('/v1/lexicon/crisis').expect(200);
      expect(dl.headers.etag).toBe(`"lx-${pub.body.seq}"`);
      const payload = verifyBundle(dl.body, DEV_KEYS, 'crisis_lexicon');
      expect(payload).toMatchObject({ kind: 'crisis_lexicon', version: next, seq: pub.body.seq });
      expect((payload.content as { entries: Array<{ id: string }> }).entries.map((e) => e.id)).toContain('en.no_way_out_e2e');
      expect(payload.vectors).toEqual(expect.arrayContaining([expect.objectContaining({ text: 'there is no way out for me', verdict: 'crisis' })]));
      await http().get('/v1/lexicon/crisis').set('If-None-Match', dl.headers.etag).expect(304);

      const cfg = await http().get('/v1/config').expect(200);
      expect(cfg.body.bundles.crisis_lexicon).toEqual({ version: next, seq: pub.body.seq });
      const again = await as(owner, http().post('/admin/lexicons/crisis/publish')).send({ version: next, reasonCode: 'e2e_publish' }).expect(409);
      expect(again.body.code).toBe('already_live');
    });

    it('rollback to v1 needs an explicit yes (it drops crisis forms), signs a NEW envelope with a higher seq, and is audited', async () => {
      const live = (await http().get('/v1/lexicon/crisis').expect(200)).body;
      const liveSeq = verifyBundle(live, DEV_KEYS, 'crisis_lexicon').seq;
      const refused = await as(owner, http().post('/admin/lexicons/crisis/publish')).send({ version: 1, reasonCode: 'e2e_rollback' }).expect(409);
      expect(refused.body).toMatchObject({ code: 'crisis_terms_removed', details: { crisisFormsRemoved: 2, removedEntries: ['en.no_way_out_e2e'] } });

      const rb = await as(owner, http().post('/admin/lexicons/crisis/publish'))
        .send({ version: 1, reasonCode: 'e2e_rollback', allowCrisisRemovals: true })
        .expect(200);
      expect(rb.body).toMatchObject({ version: 1, previousVersion: next, action: 'lexicon_rollback' });
      expect(rb.body.seq).toBeGreaterThan(liveSeq);
      refresh();
      const p = verifyBundle((await http().get('/v1/lexicon/crisis').expect(200)).body, DEV_KEYS, 'crisis_lexicon');
      expect(p).toMatchObject({ version: 1, seq: rb.body.seq });

      const audit = await db.query<{ actor: string; action: string; reason_code: string; detail: Record<string, unknown> }>(
        `select actor, action, reason_code, detail from public.moderation_actions
          where action in ('lexicon_upload','lexicon_publish','lexicon_rollback') and detail ->> 'kind' = 'crisis_lexicon'
          order by id desc limit 3`,
      );
      expect(audit.rows.map((r) => r.action)).toEqual(['lexicon_rollback', 'lexicon_publish', 'lexicon_upload']);
      expect(audit.rows[0]).toMatchObject({ actor: `staff:${owner.id}`, reason_code: 'e2e_rollback', detail: { version: 1, previousVersion: next, crisisFormsRemoved: 2 } });
      // Each of these rows is linked into the hash chain (prev_hash = the row before it).
      const links = await db.query<{ prev_hash: string | null; row_hash: string; before: string | null }>(
        `select a.prev_hash, a.row_hash,
                (select b.row_hash from public.moderation_actions b where b.id < a.id order by b.id desc limit 1) as before
           from public.moderation_actions a
          where a.action in ('lexicon_upload','lexicon_publish','lexicon_rollback') and a.detail ->> 'kind' = 'crisis_lexicon'
          order by a.id desc limit 3`,
      );
      for (const l of links.rows) {
        expect(l.row_hash).toMatch(/^[0-9a-f]{64}$/);
        expect(l.prev_hash).toBe(l.before);
      }
      const overview = await as(owner, http().get('/admin/lexicons/crisis')).expect(200);
      expect(overview.body.history[0]).toMatchObject({ action: 'lexicon_rollback', reasonCode: 'e2e_rollback' });
      expect(overview.body.live).toMatchObject({ version: 1 });
    });

    it('versions never change; a tampered stored envelope fails the app-side check', async () => {
      await expect(db.query(`update public.signed_bundle_versions set note = 'x' where kind = 'crisis_lexicon' and version = $1`, [next])).rejects.toMatchObject({
        code: 'AR020',
      });
      await expect(db.query(`update public.signed_bundle_current set seq = 1 where kind = 'crisis_lexicon'`)).rejects.toMatchObject({ code: 'AR021' });
      const row = (await db.query<{ payload: string }>(`select payload from public.signed_bundle_current where kind = 'crisis_lexicon'`)).rows[0];
      const json = JSON.parse(Buffer.from(row.payload, 'base64').toString('utf8')) as { content: { entries: Array<{ id: string }> } };
      json.content.entries = json.content.entries.filter((e) => e.id !== 'en.suicide');
      const forged = Buffer.from(JSON.stringify(json), 'utf8').toString('base64');
      const seq = Date.now() + 1000;
      await db.query(`update public.signed_bundle_current set payload = $1, seq = $2 where kind = 'crisis_lexicon'`, [forged, seq]);
      refresh();
      const served = (await http().get('/v1/lexicon/crisis').expect(200)).body;
      expect(() => verifyBundle(served, DEV_KEYS, 'crisis_lexicon')).toThrow(/bad_signature/);
      // Put a properly signed envelope back.
      await app.get(LexiconService).publish('staff:e2e', { version: 1, reasonCode: 'e2e_repair', resign: true });
      refresh();
      verifyBundle((await http().get('/v1/lexicon/crisis').expect(200)).body, DEV_KEYS, 'crisis_lexicon');
    });
  });

  // ================================================================== device bans
  describe('device bans', () => {
    it('records the install on a successful profile call (hashed), never on a refused one', async () => {
      const u = await appUser('rc-dev-a');
      const install = newInstall();
      await profile(u, install).expect(200);
      const rows = await db.query<{ install_hash: string; platform: string }>('select install_hash, platform from public.device_installs where user_id = $1', [u.id]);
      expect(rows.rows).toEqual([{ install_hash: installHash(masterKey, install), platform: 'ios' }]);
      expect(JSON.stringify(rows.rows)).not.toContain(install);

      const kid = await appUser('rc-dev-kid');
      await as(kid, http().post('/v1/profile'))
        .set('X-Aura-Install', newInstall())
        .send({ birthDate: `${new Date().getUTCFullYear() - 10}-01-01`, uiLocale: 'en', timezone: 'Asia/Kolkata' })
        .expect(403);
      expect((await db.query('select 1 from public.device_installs where user_id = $1', [kid.id])).rowCount).toBe(0);
    });

    it('instant ban of an account bans its phones: 403 device_banned on profile / devices / match, account routes stay open', async () => {
      const a = await appUser('rc-ban-a');
      const install = newInstall();
      await profile(a, install).expect(200);
      await as(a, http().put('/v1/devices')).set('X-Aura-Install', install).send({ token: `fcm-${randomBytes(12).toString('hex')}`, platform: 'ios' }).expect(204);

      const out = await app.get(DeviceBansService).banDevicesForAccount(a.id, 'minor_sexual_content', { actor: 'staff:e2e-instant-ban' });
      expect(out).toEqual({ devices: 1, newlyBanned: 1 });
      expect(await app.get(DeviceBansService).banDevicesForAccount(a.id, 'minor_sexual_content', { actor: 'staff:e2e-instant-ban' })).toEqual({
        devices: 1,
        newlyBanned: 0,
      });

      const refusedProfile = await profile(a, install).expect(403);
      expect(refusedProfile.body).toEqual({ code: 'device_banned', message: "This device can't use Aura." });
      await as(a, http().put('/v1/devices')).set('X-Aura-Install', install).send({ token: 'fcm-x', platform: 'ios' }).expect(403);
      const match = await as(a, http().post('/v1/rooms/match')).set('X-Aura-Install', install).send({ quadrant: 'rain', moodId: 'lonely' });
      expect(match.body.code).toBe('device_banned');
      // The account itself can still see its status and delete itself; public routes never check the install.
      await as(a, http().get('/v1/account')).set('X-Aura-Install', install).expect(200);
      await http().get('/v1/config').set('X-Aura-Install', install).expect(200);

      // A brand-new account on the same phone is refused at sign-in / onboarding.
      const b = await appUser('rc-ban-b');
      expect((await profile(b, install).expect(403)).body.code).toBe('device_banned');
      // Another phone is fine.
      await profile(b, newInstall()).expect(200);

      const audit = await db.query<{ subject_hash: string; detail: Record<string, unknown> }>(
        `select subject_hash, detail from public.moderation_actions where action = 'device_ban' and actor = 'staff:e2e-instant-ban' order by id desc limit 1`,
      );
      expect(audit.rows[0].detail).toEqual({ scope: 'account', devices: 1, newlyBanned: 0 });
      expect(JSON.stringify(audit.rows)).not.toContain(a.id);
    });

    it('console: the Owner lists the devices of a reported account, bans, lists and lifts; a Moderator gets 403 (audited)', async () => {
      const c = await appUser('rc-console-c');
      const reporter = await appUser('rc-console-r');
      await profile(reporter).expect(200);
      const install = newInstall();
      await profile(c, install).expect(200);
      const reportId = (
        await db.query<{ id: string }>(
          `insert into public.reports (source, reporter_user_id, reason, lane, target_kind, target_ref, target_user_id, sla_due_at)
           values ('user', $1, 3, 'harassment', 'room', gen_random_uuid(), $2, now() + interval '1 day') returning id`,
          [reporter.id, c.id],
        )
      ).rows[0].id;
      reportIds.push(reportId);

      const list = await as(owner, http().get('/admin/devices')).query({ reportId }).expect(200);
      expect(list.headers['cache-control']).toBe('no-store');
      expect(list.body.devices).toEqual([
        expect.objectContaining({ deviceId: installHash(masterKey, install), platform: 'ios', banId: null }),
      ]);
      expect(JSON.stringify(list.body)).not.toContain(c.id);

      const denied = await as(moderator, http().post(`/admin/devices/${installHash(masterKey, install)}/ban`)).send({ reasonCode: 'e2e' });
      expect(denied.status).toBe(403);
      const deniedAudit = await db.query(
        `select 1 from public.moderation_actions where action = 'access_denied' and actor = $1 and detail ->> 'route' like '%/admin/devices/:deviceId/ban'`,
        [`staff:${moderator.id}`],
      );
      expect(deniedAudit.rowCount).toBeGreaterThan(0);

      const ban = await as(owner, http().post('/admin/devices/ban-account')).send({ reportId, reasonCode: 'grooming' }).expect(200);
      expect(ban.body).toEqual({ devices: 1, newlyBanned: 1 });
      expect((await profile(c, install).expect(403)).body.code).toBe('device_banned');
      const one = await as(owner, http().post(`/admin/devices/${installHash(masterKey, install)}/ban`)).send({ reasonCode: 'grooming' }).expect(200);
      expect(one.body).toMatchObject({ alreadyBanned: true });

      const bans = await as(owner, http().get('/admin/devices/bans')).expect(200);
      const mine = bans.body.bans.find((b: { deviceId: string }) => b.deviceId === installHash(masterKey, install));
      expect(mine).toMatchObject({ reasonCode: 'grooming', reportId, createdBy: `staff:${owner.id}`, liftedAt: null });

      await as(owner, http().post(`/admin/devices/bans/${mine.banId}/lift`)).send({ reasonCode: 'appeal_upheld' }).expect(200);
      await as(owner, http().post(`/admin/devices/bans/${mine.banId}/lift`)).send({ reasonCode: 'appeal_upheld' }).expect(404);
      await profile(c, install).expect(200);
      const lifted = await as(owner, http().get('/admin/devices/bans')).query({ status: 'lifted' }).expect(200);
      expect(lifted.body.bans.find((b: { banId: string }) => b.banId === mine.banId)).toMatchObject({ liftReason: 'appeal_upheld', liftedBy: `staff:${owner.id}` });
    });

    it('a ban outlives the account: after the account is gone, a new account on that phone is still refused', async () => {
      const d = await appUser('rc-gone-d');
      const install = newInstall();
      await profile(d, install).expect(200);
      await app.get(DeviceBansService).banDevicesForAccount(d.id, 'threats', { actor: 'staff:e2e' });
      await deleteUser(d.id);
      expect((await db.query('select 1 from public.device_installs where user_id = $1', [d.id])).rowCount).toBe(0);
      expect((await db.query('select 1 from public.device_bans where install_hash = $1 and lifted_at is null', [installHash(masterKey, install)])).rowCount).toBe(1);
      const e = await appUser('rc-gone-e');
      expect((await profile(e, install).expect(403)).body.code).toBe('device_banned');
    });
  });
});
