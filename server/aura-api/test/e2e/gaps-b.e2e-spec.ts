/**
 * Milestone B gaps (e2e, migration 20261005000025) against the live local stack: NestJS app, Postgres, Supabase Auth
 * with real TOTP staff, Mailpit (SMTP :55525, API :55524).
 *  1. Tonight's intention list in the console: Moderator reads, Owner adds / rewords / moves, every change audited,
 *     words linted, `GET /v1/intentions` serves every key's words (ETag), a retired preset stays with a room using it.
 *  2. The trial-ending email: sent once to the verified address in the account's language with the store price and
 *     the store's own page; skipped with auto-renew off or an unverified address; never twice.
 * Only this run's rows are touched: presets are created RETIRED (enabled false) with unique keys, so no pool's nightly
 * rotation changes while the suite runs; rooms and subscriptions are this run's own and are removed afterwards.
 */
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { MAILER, SmtpMailer, type Mailer } from '../../src/admin/mail/mailer';
import { DbService } from '../../src/db/db.service';
import { TrialEmailSender, dueTrialEmails } from '../../src/user-mail/trial-email.sender';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, type TestUser } from './support';

jest.setTimeout(90_000);

const MAILPIT = process.env.MAILPIT_URL ?? 'http://127.0.0.1:55524';
const SMTP = process.env.E2E_SMTP_URL ?? 'smtp://127.0.0.1:55525';

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

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function mailsTo(address: string): Promise<Array<{ ID: string; Subject: string }>> {
  const r = await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:"${address}"`)}`);
  return ((await r.json()) as { messages?: Array<{ ID: string; Subject: string }> }).messages ?? [];
}

async function mailTo(address: string, timeoutMs = 10_000): Promise<{ id: string; subject: string; text: string }> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const m = (await mailsTo(address))[0];
    if (m) {
      const full = (await (await fetch(`${MAILPIT}/api/v1/message/${m.ID}`)).json()) as { Text: string; Subject: string };
      return { id: m.ID, subject: full.Subject, text: full.Text };
    }
    if (Date.now() > end) throw new Error(`mailpit: no message to ${address}`);
    await sleep(150);
  }
}

const WORDS = {
  en: 'Put the phone in another room',
  te: 'ఫోన్ వేరే గదిలో పెడతాను',
  'te-Latn': 'Phone vere gadilo pedataanu',
  hi: 'फ़ोन दूसरे कमरे में',
  'hi-Latn': 'Phone doosre kamre mein',
};

describe('Milestone B gaps (e2e): intention list editor, trial-ending email', () => {
  let app: INestApplication;
  let db: Pool;
  let owner: TestUser;
  let moderator: TestUser;
  const users: TestUser[] = [];
  const savedEnv: Record<string, string | undefined> = {};
  const run = randomBytes(3).toString('hex');
  const keyA = `e2e_gapsb_${run}_a`;
  const keyB = `e2e_gapsb_${run}_b`;
  const roomIds: string[] = [];
  const subscriptionIds: string[] = [];
  const mailIds: string[] = [];

  const http = () => request(app.getHttpServer());
  const as = (u: { token: string }, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);

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

  async function auditRows(action: string, key: string): Promise<Array<{ actor: string; reason_code: string | null; detail: Record<string, unknown> }>> {
    return (
      await db.query<{ actor: string; reason_code: string | null; detail: Record<string, unknown> }>(
        `select actor, reason_code, detail from public.moderation_actions where action = $1 and detail ->> 'key' = $2 order by id`,
        [action, key],
      )
    ).rows;
  }

  beforeAll(async () => {
    for (const [k, v] of Object.entries({ ADMIN_ALLOWED_EMAILS: '', SMTP_URL: SMTP, MAIL_FROM: 'Aura e2e <no-reply@aura.test>' })) {
      savedEnv[k] = process.env[k];
      process.env[k] = v;
    }
    app = await bootApp();
    db = dbPool();
    owner = await staff('gapsb-owner', 'owner');
    moderator = await staff('gapsb-mod', 'moderator');
  });

  afterAll(async () => {
    if (db) {
      if (roomIds.length) await db.query('delete from public.rooms where id = any($1::uuid[])', [roomIds]);
      await db.query('delete from public.room_intention_presets where key = any($1)', [[keyA, keyB]]);
      await db.query('delete from public.room_intention_texts where key = any($1)', [[keyA, keyB]]);
      if (subscriptionIds.length) await db.query('delete from public.subscriptions where id = any($1::uuid[])', [subscriptionIds]);
      await db.query('delete from public.admin_staff where staff_id = any($1::uuid[])', [users.map((u) => u.id)]);
    }
    for (const id of mailIds) await fetch(`${MAILPIT}/api/v1/messages`, { method: 'DELETE', body: JSON.stringify({ IDs: [id] }) }).catch(() => undefined);
    for (const u of users) await deleteUser(u.id);
    await db?.end();
    await app?.close();
    for (const [k, v] of Object.entries(savedEnv)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  });

  // ------------------------------------------------------------------------------------------ 1. intention list

  describe('Tonight’s intention list (PRD 19 "the Tonight’s intention list per language")', () => {
    it('a Moderator reads every pool, the words in five languages and the next 14 nights', async () => {
      const res = await as(moderator, http().get('/admin/intentions')).expect(200);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(res.body.locales).toEqual(['en', 'te', 'te-Latn', 'hi', 'hi-Latn']);
      expect(res.body.pools.map((p: { pool: string }) => p.pool)).toEqual(['en', 'te', 'hi']);
      const en = res.body.pools[0];
      expect(en.rotation).toHaveLength(14);
      const enabled = en.presets.filter((p: { enabled: boolean }) => p.enabled).map((p: { key: string }) => p.key);
      for (const night of en.rotation) expect(enabled).toContain(night.key);
      const sleep = res.body.words.find((w: { key: string }) => w.key === 'sleep_before_midnight');
      expect(sleep.texts).toEqual({
        en: 'Sleep before midnight',
        te: 'అర్ధరాత్రి లోపు నిద్రపోవాలి',
        'te-Latn': 'Ardharaatri lopu nidrapovaali',
        hi: 'आधी रात से पहले सोना',
        'hi-Latn': 'Aadhi raat se pehle sona',
      });
    });

    it('a Moderator cannot change the list (403, nothing written)', async () => {
      await as(moderator, http().post('/admin/intentions/presets'))
        .send({ pool: 'hi', key: keyA, texts: WORDS, enabled: false, reasonCode: 'e2e_add' })
        .expect(403);
      await as(moderator, http().post('/admin/intentions/words/sleep_before_midnight')).send({ texts: WORDS, reasonCode: 'e2e' }).expect(403);
      expect((await db.query('select 1 from public.room_intention_texts where key = $1', [keyA])).rowCount).toBe(0);
      // REQ-ADM-02: the attempt is audited.
      const denied = await db.query<{ detail: { route: string } }>(
        `select detail from public.moderation_actions where actor = $1 and action = 'access_denied' order by id`,
        [`staff:${moderator.id}`],
      );
      expect(denied.rows.map((r) => r.detail.route)).toEqual(expect.arrayContaining([expect.stringContaining('/admin/intentions')]));
    });

    it('words are linted: guilt, clinical and scoring words, the wrong script and a missing language are refused', async () => {
      const res = await as(owner, http().post('/admin/intentions/presets'))
        .send({
          pool: 'hi',
          key: keyA,
          enabled: false,
          reasonCode: 'e2e_add',
          texts: { ...WORDS, en: "Don't miss your streak", te: 'Phone down', 'hi-Latn': 'Kal se behtar' },
        })
        .expect(422);
      expect(res.body.code).toBe('intention_words_rejected');
      expect(res.body.details).toEqual(
        expect.arrayContaining([
          'en: has a guilt, loss or urgency word ("miss")',
          'en: has a guilt, loss or urgency word ("streak*")',
          expect.stringMatching(/^te: is not in its language’s script/),
          'hi-Latn: has a scoring or comparison word ("behtar")',
        ]),
      );
      const { hi: _hi, ...four } = WORDS;
      await as(owner, http().post('/admin/intentions/presets')).send({ pool: 'hi', key: keyA, enabled: false, texts: four, reasonCode: 'e2e_add' }).expect(400);
      expect((await db.query('select 1 from public.room_intention_texts where key = $1', [keyA])).rowCount).toBe(0);
    });

    it('the Owner adds a new key with its words (retired here, so no pool’s rotation changes), audited', async () => {
      const res = await as(owner, http().post('/admin/intentions/presets'))
        .send({ pool: 'hi', key: keyA, texts: WORDS, enabled: false, reasonCode: 'e2e_add' })
        .expect(201);
      expect(res.body).toMatchObject({ newWords: true, preset: { pool: 'hi', key: keyA, enabled: false, inUseTonight: 0 } });
      const audit = await auditRows('intention_preset_add', keyA);
      expect(audit).toHaveLength(1);
      expect(audit[0]).toMatchObject({ actor: `staff:${owner.id}`, reason_code: 'e2e_add', detail: { pool: 'hi', key: keyA, enabled: false, newWords: true } });
      expect(JSON.stringify(audit[0].detail)).not.toContain(WORDS.en); // keys and pools only, never the words

      // The same key in another pool reuses its words; sending words again is refused.
      await as(owner, http().post('/admin/intentions/presets')).send({ pool: 'te', key: keyA, texts: WORDS, enabled: false, reasonCode: 'e2e_add' }).expect(409);
      const again = await as(owner, http().post('/admin/intentions/presets')).send({ pool: 'te', key: keyA, enabled: false, reasonCode: 'e2e_add' }).expect(201);
      expect(again.body.newWords).toBe(false);
      await as(owner, http().post('/admin/intentions/presets')).send({ pool: 'te', key: keyA, enabled: false, reasonCode: 'e2e_add' }).expect(409);
      // A new key without words is refused.
      await as(owner, http().post('/admin/intentions/presets')).send({ pool: 'en', key: keyB, enabled: false, reasonCode: 'e2e_add' }).expect(400);

      const list = await as(moderator, http().get('/admin/intentions')).expect(200);
      const hi = list.body.pools.find((p: { pool: string }) => p.pool === 'hi');
      expect(hi.presets.find((p: { key: string }) => p.key === keyA)).toMatchObject({ enabled: false });
      expect(hi.rotation.map((n: { key: string }) => n.key)).not.toContain(keyA); // retired: not in the rotation
      expect(list.body.words.find((w: { key: string }) => w.key === keyA)).toMatchObject({ texts: WORDS, pools: ['hi', 'te'] });
    });

    it('the Owner rewords a key (audited with which languages changed) and moves a preset', async () => {
      const texts = { ...WORDS, en: 'Phone in another room tonight' };
      const res = await as(owner, http().post(`/admin/intentions/words/${keyA}`)).send({ texts, reasonCode: 'e2e_reword' }).expect(200);
      expect(res.body.changed).toEqual(['en']);
      expect(res.body.words).toMatchObject({ key: keyA, texts });
      const same = await as(owner, http().post(`/admin/intentions/words/${keyA}`)).send({ texts, reasonCode: 'e2e_reword' }).expect(200);
      expect(same.body.changed).toEqual([]);
      expect(await auditRows('intention_words_edit', keyA)).toEqual([
        expect.objectContaining({ reason_code: 'e2e_reword', detail: { key: keyA, changed: ['en'] } }),
      ]);
      await as(owner, http().post('/admin/intentions/words/no_such_key_here')).send({ texts, reasonCode: 'e2e' }).expect(404);

      const moved = await as(owner, http().post(`/admin/intentions/presets/hi/${keyA}`)).send({ position: 9999, reasonCode: 'e2e_move' }).expect(200);
      expect(moved.body.preset).toMatchObject({ position: 9999, enabled: false });
      expect(await auditRows('intention_preset_move', keyA)).toEqual([
        expect.objectContaining({ reason_code: 'e2e_move', detail: expect.objectContaining({ pool: 'hi', position: 9999, previousEnabled: false }) }),
      ]);
      await as(owner, http().post(`/admin/intentions/presets/xx/${keyA}`)).send({ position: 1, reasonCode: 'e2e' }).expect(404);
      await as(owner, http().post(`/admin/intentions/presets/hi/${keyA}`)).send({ reasonCode: 'e2e' }).expect(400);
    });

    it('GET /v1/intentions: public, every key’s words (retired ones too), ETag → 304', async () => {
      const res = await http().get('/v1/intentions').expect(200);
      expect(res.headers.etag).toMatch(/^"in-/);
      const a = res.body.intentions.find((i: { key: string }) => i.key === keyA);
      expect(a.texts['te-Latn']).toBe(WORDS['te-Latn']);
      expect(res.body.intentions.map((i: { key: string }) => i.key)).toEqual(expect.arrayContaining(['sleep_before_midnight', 'slow_breaths']));
      await http().get('/v1/intentions').set('If-None-Match', res.headers.etag as string).expect(304);
    });

    it('a retired preset never disappears from a room already showing it tonight', async () => {
      const roomId = randomUUID();
      roomIds.push(roomId);
      await db.query(
        `insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at,
                                   lantern_hour_at, intention_key)
         values ($1, 'hi', 'storm', 'south_asia', 'anxious', 'lighthouse', now(), now() + interval '19 hours', now() + interval '23 hours',
                 now() + interval '8 days', now() - interval '10 minutes', $2)`,
        [roomId, keyA],
      );
      const list = await as(moderator, http().get('/admin/intentions')).expect(200);
      const hi = list.body.pools.find((p: { pool: string }) => p.pool === 'hi');
      expect(hi.presets.find((p: { key: string }) => p.key === keyA)).toMatchObject({ enabled: false, inUseTonight: 1 });
      // The room keeps its key (write-once) and its words stay served and can't be deleted, by any role.
      await expect(db.query(`update public.rooms set intention_key = 'slow_breaths' where id = $1`, [roomId])).rejects.toThrow(/intention_fixed/);
      await expect(db.query('delete from public.room_intention_texts where key = $1', [keyA])).rejects.toThrow();
      const copy = await http().get('/v1/intentions').expect(200);
      expect(copy.body.intentions.map((i: { key: string }) => i.key)).toContain(keyA);
    });
  });

  // ------------------------------------------------------------------------------------------ 2. trial-ending email

  describe('Trial-ending email (PRD 12: push + in-app card + email)', () => {
    let sender: TrialEmailSender;

    async function trialUser(label: string, uiLocale: string, opts: { autoRenew?: boolean; verified?: boolean } = {}): Promise<{ user: TestUser; sub: string }> {
      const user = await createUser(label);
      users.push(user);
      await as(user, http().post('/v1/profile')).send({ birthDate: '1996-03-14', uiLocale, timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
      // No quiet hours for this account, so the email goes whatever time the suite runs.
      await db.query(
        `insert into public.notification_prefs (user_id, quiet_start, quiet_end) values ($1, '00:00', '00:00')
         on conflict (user_id) do update set quiet_start = '00:00', quiet_end = '00:00'`,
        [user.id],
      );
      if (opts.verified === false) await db.query('update auth.users set email_confirmed_at = null where id = $1', [user.id]);
      await db.query(
        `insert into public.billing_accounts (user_id, account_token, trial_reminder_at) values ($1, $2, now())
         on conflict (user_id) do update set trial_reminder_at = now()`,
        [user.id, randomUUID()],
      );
      const sub = (
        await db.query<{ id: string }>(
          `insert into public.subscriptions (owner_user_id, store, store_ref, product_id, environment, state, auto_renew, trial_ends_at,
                                             expires_at, price_display)
           values ($1, 'apple', $2, 'aura_plus_monthly', 'sandbox', 'trial', $3, now() + interval '47 hours', now() + interval '47 hours', '₹49.00')
           returning id`,
          [user.id, `e2e-gapsb-${randomBytes(6).toString('hex')}`, opts.autoRenew ?? true],
        )
      ).rows[0].id;
      subscriptionIds.push(sub);
      return { user, sub };
    }

    const ledger = async (sub: string) =>
      (await db.query<{ state: string; reason: string | null; attempts: number; locale: string | null }>(
        'select state, reason, attempts, locale from public.trial_ending_emails where subscription_id = $1',
        [sub],
      )).rows[0];

    beforeAll(() => {
      const mailer = app.get<Mailer>(MAILER, { strict: false });
      expect(mailer).toBeInstanceOf(SmtpMailer);
      sender = new TrialEmailSender(app.get(DbService), mailer);
    });

    it('is due once the reminder is claimed, and goes once to the verified address in the account’s language', async () => {
      const { user, sub } = await trialUser('gapsb-trial-te', 'te');
      expect((await dueTrialEmails(db, new Date(), 1000)).map((d) => d.subscriptionId)).toContain(sub);

      expect(await sender.process(sub, user.id)).toEqual({ outcome: 'sent' });
      const mail = await mailTo(user.email);
      mailIds.push(mail.id);
      expect(mail.subject).toMatch(/^Aura Plus: మీ ఉచిత నెల .+తో ముగుస్తుంది$/);
      expect(mail.text).toContain('తర్వాత నెలకు ₹49.00');
      expect(mail.text).toContain('https://apps.apple.com/account/subscriptions');
      expect(mail.text).not.toMatch(/unsubscribe|streak|mood/i);
      expect(await ledger(sub)).toEqual({ state: 'sent', reason: null, attempts: 1, locale: 'te' });

      // Never twice: a second run (retry, restart, second worker) is a duplicate and the sweep no longer lists it.
      expect(await sender.process(sub, user.id)).toEqual({ outcome: 'duplicate' });
      expect((await dueTrialEmails(db, new Date(), 1000)).map((d) => d.subscriptionId)).not.toContain(sub);
      await sleep(300);
      expect(await mailsTo(user.email)).toHaveLength(1);
    });

    it('is not sent when auto-renew is already off, nor to an unverified address (recorded, never retried)', async () => {
      const off = await trialUser('gapsb-trial-off', 'en', { autoRenew: false });
      expect(await sender.process(off.sub, off.user.id)).toEqual({ outcome: 'skipped', reason: 'auto_renew_off' });
      expect(await ledger(off.sub)).toMatchObject({ state: 'skipped', reason: 'auto_renew_off' });

      const unverified = await trialUser('gapsb-trial-unv', 'hi-Latn', { verified: false });
      expect(await sender.process(unverified.sub, unverified.user.id)).toEqual({ outcome: 'skipped', reason: 'email_unverified' });
      expect(await ledger(unverified.sub)).toMatchObject({ state: 'skipped', reason: 'email_unverified' });
      expect(await sender.process(unverified.sub, unverified.user.id)).toEqual({ outcome: 'skipped', reason: 'email_unverified' });

      await sleep(300);
      expect(await mailsTo(off.user.email)).toHaveLength(0);
      expect(await mailsTo(unverified.user.email)).toHaveLength(0);
    });

    it('is skipped for an account pending deletion', async () => {
      const { user, sub } = await trialUser('gapsb-trial-del', 'en');
      await db.query(`insert into public.account_deletions (user_id, scheduled_for) values ($1, now() + interval '7 days')`, [user.id]);
      expect(await sender.process(sub, user.id)).toEqual({ outcome: 'skipped', reason: 'account_deleted' });
      await sleep(300);
      expect(await mailsTo(user.email)).toHaveLength(0);
    });
  });
});
