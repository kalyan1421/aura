/**
 * F4 sync entity `capsule` (contracts/api/v1-capsules.md §2) through SyncService, against in-memory repositories:
 * seal / open / fire / rearm / delete, limits, one-way open, earliest fire wins, tombstones win, post-commit effects.
 * (The same flows run against the real DB in test/e2e/capsules.e2e-spec.ts.)
 */
import { Logger } from '@nestjs/common';
import { CapsuleSyncHandler, markCapsuleEffects, newCapsuleEffects, rollbackCapsuleEffects } from '../../src/capsules/capsule-sync';
import type { CapsuleRow, NewCapsule } from '../../src/capsules/capsules.repository';
import { MAX_CAPSULE_CT_CHARS, MAX_PENDING_DATE_CAPSULES } from '../../src/capsules/capsules.schema';
import { uuidv7 } from '../../src/common/uuid';
import { capsuleObjectPath, capsuleObjectPrefix } from '../../src/media/media-paths';
import { SyncService } from '../../src/sync/sync.service';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const TZ = 'Asia/Kolkata';
const NOW = new Date('2026-10-08T10:00:00Z'); // 15:30 IST, 8 Oct
const H = 3600_000;
const at = (offsetMs: number): string => new Date(NOW.getTime() + offsetMs).toISOString();
const CT = Buffer.from('ciphertext: title, text, media refs, hardMoment').toString('base64');

class MemCapsules {
  rows = new Map<string, CapsuleRow>();
  schedules = new Set<string>();
  objects = new Set<string>();

  async lockById(_: unknown, id: string) {
    const r = this.rows.get(id);
    return r ? { ...r } : null;
  }
  async insert(_: unknown, c: NewCapsule) {
    if (this.rows.has(c.id)) throw Object.assign(new Error('duplicate key'), { code: '23505' });
    this.rows.set(c.id, { ...c, cycle: 0, firedAt: null, cooldownUntil: null, openedAt: null, openedDeviceTs: null, deletedAt: null });
    if (c.unlockType === 'date') this.schedules.add(c.id);
  }
  async countActiveTriggers(_: unknown, u: string, exceptId: string | null = null) {
    return [...this.rows.values()].filter((r) => r.userId === u && r.unlockType === 'mood' && !r.deletedAt && !r.openedAt && r.id !== exceptId)
      .length;
  }
  async countPendingDates(_: unknown, u: string) {
    return [...this.rows.values()].filter((r) => r.userId === u && r.unlockType === 'date' && !r.deletedAt && !r.openedAt).length;
  }
  async markOpened(_: unknown, id: string, openedAt: Date, openedDeviceTs: Date, fired: { firedAt: Date; cooldownUntil: Date } | null) {
    const r = this.rows.get(id)!;
    Object.assign(r, { openedAt, openedDeviceTs }, fired ?? {});
  }
  async setFired(_: unknown, id: string, firedAt: Date, cooldownUntil: Date) {
    Object.assign(this.rows.get(id)!, { firedAt, cooldownUntil });
  }
  async rearm(_: unknown, id: string, armedAt: Date) {
    const r = this.rows.get(id)!;
    Object.assign(r, { cycle: r.cycle + 1, armedAt, firedAt: null, openedAt: null, openedDeviceTs: null });
  }
  async tombstone(_: unknown, id: string, deletedAt: Date) {
    Object.assign(this.rows.get(id)!, { deletedAt, payloadCt: null, unlockLocalDate: null, triggerMoodId: null, triggerQuadrant: null });
  }
  async deleteSchedules(_: unknown, ids: string[]) {
    for (const id of ids) this.schedules.delete(id);
  }
  async listCapsuleObjects(_: unknown, u: string, ids: string[]) {
    return [...this.objects].filter((n) => ids.some((id) => n.startsWith(capsuleObjectPrefix(u, id)))).sort(); // order by name
  }
}

/** Just enough of SyncRepository for capsule-only pushes (idempotency). */
class MemSync {
  mutations = new Map<string, { status: 'applied' | 'rejected'; reason: string | null }>();
  async lockUser() {}
  async findMutation(_: unknown, u: string, id: string) {
    return this.mutations.get(`${u}:${id}`) ?? null;
  }
  async recordMutation(_: unknown, m: { userId: string; mutationId: string; status: 'applied' | 'rejected'; reason: string | null }) {
    this.mutations.set(`${m.userId}:${m.mutationId}`, { status: m.status, reason: m.reason });
  }
}

interface Harness {
  service: SyncService;
  caps: MemCapsules;
  unlock: { schedule: jest.Mock; unschedule: jest.Mock };
  media: { configured: boolean; remove: jest.Mock };
}

function harness(over: { unlockFails?: boolean; mediaConfigured?: boolean; mediaFails?: boolean } = {}): Harness {
  const caps = new MemCapsules();
  const tx = { savepoint: <T>(fn: () => Promise<T>) => fn() };
  const db = { withTx: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx) };
  const moods: Record<string, string> = { overwhelmed: 'storm', anxious: 'storm', calm: 'moonlight', lonely: 'rain' };
  const catalogue = { moodQuadrant: async (id: string) => moods[id] };
  const unlock = {
    schedule: jest.fn(async () => {
      if (over.unlockFails) throw new Error('redis down');
      return 1;
    }),
    unschedule: jest.fn(async () => {
      if (over.unlockFails) throw new Error('redis down');
    }),
  };
  const media = {
    configured: over.mediaConfigured ?? true,
    remove: jest.fn(async (names: string[]) => {
      if (over.mediaFails) throw new Error('storage down');
      for (const n of names) caps.objects.delete(n);
      return names.length;
    }),
  };
  const handler = new CapsuleSyncHandler(caps as never, catalogue as never, unlock as never, media as never, {} as never);
  const service = new SyncService(
    db as never,
    new MemSync() as never,
    { require: async () => ({ timezone: TZ }) } as never,
    catalogue as never,
    { recompute: async () => ({ snapshot: true }) } as never,
    media as never,
    handler,
  );
  return { service, caps, unlock, media };
}

const push = (h: Harness, mutations: unknown[], user = USER, now = NOW) =>
  h.service.push(user, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations }, now);
const statusOf = async (h: Harness, mutations: unknown[], user = USER) =>
  (await push(h, mutations, user)).results.map((r) => (r.status === 'rejected' ? r.reason : r.status));

const seal = (payload: Record<string, unknown>, over: Record<string, unknown> = {}) => ({
  id: uuidv7(),
  entity: 'capsule',
  op: 'seal',
  deviceTs: NOW.toISOString(),
  payload,
  ...over,
});
const dateCapsule = (unlockLocalDate = '2026-11-08', over: Record<string, unknown> = {}) => ({
  id: uuidv7(),
  payloadCt: CT,
  unlockType: 'date',
  unlockLocalDate,
  ...over,
});
const moodCapsule = (target: Record<string, unknown> = { triggerQuadrant: 'storm' }) => ({
  id: uuidv7(),
  payloadCt: CT,
  unlockType: 'mood',
  ...target,
});
const op = (name: string, id: string, deviceTs = NOW.toISOString(), payload: Record<string, unknown> = {}) => ({
  id: uuidv7(),
  entity: 'capsule',
  op: name,
  deviceTs,
  payload: { id, ...payload },
});

/** A trigger capsule sealed 3 days ago (armed 2 days ago). */
async function armedTrigger(h: Harness, target: Record<string, unknown> = { triggerQuadrant: 'storm' }): Promise<string> {
  const p = moodCapsule(target);
  expect(await statusOf(h, [seal(p, { deviceTs: at(-72 * H) })])).toEqual(['applied']);
  return p.id;
}

describe('capsules via SyncService (in-memory)', () => {
  beforeAll(() => Logger.overrideLogger(false));

  describe('seal', () => {
    it('stores ciphertext + unlock metadata; a date capsule is scheduled after commit', async () => {
      const h = harness();
      const p = dateCapsule();
      const r = await push(h, [seal(p, { tz: TZ })]);
      expect(r.results[0]).toEqual({ id: expect.any(String), status: 'applied' });
      expect(r.snapshot).toEqual({ snapshot: true });
      expect(h.caps.rows.get(p.id)).toMatchObject({
        userId: USER,
        unlockType: 'date',
        unlockLocalDate: '2026-11-08',
        payloadCt: CT,
        sealedAt: NOW,
        armedAt: null,
        cycle: 0,
      });
      expect(h.unlock.schedule).toHaveBeenCalledWith([p.id]);
    });

    it('a trigger capsule arms 24 h after sealing and schedules nothing', async () => {
      const h = harness();
      const p = moodCapsule({ triggerMoodId: 'overwhelmed' });
      expect(await statusOf(h, [seal(p)])).toEqual(['applied']);
      expect(h.caps.rows.get(p.id)).toMatchObject({ unlockType: 'mood', triggerMoodId: 'overwhelmed', triggerQuadrant: null });
      expect(h.caps.rows.get(p.id)?.armedAt?.toISOString()).toBe(at(24 * H));
      expect(h.unlock.schedule).not.toHaveBeenCalled();
    });

    it.each<[string, Record<string, unknown>, Record<string, unknown>, string]>([
      ['no deviceTs', dateCapsule(), { deviceTs: undefined }, 'invalid_payload'],
      ['plaintext instead of ciphertext', dateCapsule('2026-11-08', { payloadCt: '{"title": "Dear me"}' }), {}, 'invalid_payload'],
      ['ciphertext over 128 KiB', dateCapsule('2026-11-08', { payloadCt: 'A'.repeat(MAX_CAPSULE_CT_CHARS + 1) }), {}, 'invalid_payload'],
      ['empty ciphertext', dateCapsule('2026-11-08', { payloadCt: '' }), {}, 'invalid_payload'],
      ['a date capsule with a trigger', dateCapsule('2026-11-08', { triggerQuadrant: 'storm' }), {}, 'invalid_payload'],
      ['both mood and quadrant', moodCapsule({ triggerMoodId: 'anxious', triggerQuadrant: 'storm' }), {}, 'invalid_payload'],
      ['neither mood nor quadrant', moodCapsule({}), {}, 'invalid_payload'],
      ['an unknown quadrant', moodCapsule({ triggerQuadrant: 'thunder' }), {}, 'invalid_payload'],
      ['an unknown mood', moodCapsule({ triggerMoodId: 'ecstatic' }), {}, 'unknown_mood'],
      ['a malformed date', dateCapsule('2026-02-30'), {}, 'invalid_payload'],
      ['an unknown tz', dateCapsule(), { tz: 'Mars/Olympus' }, 'invalid_tz'],
    ])('rejects %s', async (_, payload, over, reason) => {
      const h = harness();
      expect(await statusOf(h, [seal(payload, over)])).toEqual([reason]);
      expect(h.caps.rows.size).toBe(0);
    });

    it('capsule ops are their own: capsule:upsert and check_in:seal are unknown_op', async () => {
      const h = harness();
      expect(await statusOf(h, [{ ...seal(dateCapsule()), op: 'upsert' }])).toEqual(['unknown_op']);
      expect(
        await statusOf(h, [{ id: uuidv7(), entity: 'check_in', op: 'seal', deviceTs: NOW.toISOString(), payload: { id: uuidv7() } }]),
      ).toEqual(['unknown_op']);
    });

    it('window: 7 days … 5 years after the seal date (in the device zone); a broken clock cannot go past +5 y', async () => {
      const h = harness();
      const results = await statusOf(h, [
        seal(dateCapsule('2026-10-14')), // 6 days
        seal(dateCapsule('2026-10-15')), // 7 days
        seal(dateCapsule('2031-10-08')), // 5 years
        seal(dateCapsule('2031-10-09')), // 5 years + 1 day
        // 01:30 IST on 9 Oct (still 8 Oct in UTC): the seal date is 9 Oct, so 15 Oct is too soon …
        seal(dateCapsule('2026-10-15'), { deviceTs: '2026-10-08T20:00:00Z', tz: TZ }),
        // … but in New York that instant is 8 Oct 16:00, so 15 Oct is fine.
        seal(dateCapsule('2026-10-15'), { deviceTs: '2026-10-08T20:00:00Z', tz: 'America/New_York' }),
        // A device clock 10 years ahead: relative window fine, but > 5 y + 2 d past the server's today.
        seal(dateCapsule('2036-10-20'), { deviceTs: '2036-10-08T10:00:00Z' }),
      ]);
      expect(results).toEqual([
        'invalid_unlock_date',
        'applied',
        'applied',
        'invalid_unlock_date',
        'invalid_unlock_date',
        'applied',
        'invalid_unlock_date',
      ]);
    });

    it('sealed means sealed: an identical re-send is a no-op, any change is capsule_sealed', async () => {
      const h = harness();
      const p = dateCapsule();
      expect(await statusOf(h, [seal(p)])).toEqual(['applied']);
      expect(
        await statusOf(h, [
          seal(p), // the same seal under a new mutation id
          seal({ ...p, payloadCt: Buffer.from('edited').toString('base64') }),
          seal({ ...p, unlockLocalDate: '2026-12-08' }),
          seal({ id: p.id, payloadCt: CT, unlockType: 'mood', triggerQuadrant: 'storm' }),
        ]),
      ).toEqual(['applied', 'capsule_sealed', 'capsule_sealed', 'capsule_sealed']);
      expect(h.caps.rows.get(p.id)).toMatchObject({ payloadCt: CT, unlockLocalDate: '2026-11-08' });
    });

    it("another user's capsule id → id_conflict (their row untouched)", async () => {
      const h = harness();
      const p = dateCapsule();
      await push(h, [seal(p)], OTHER);
      expect(await statusOf(h, [seal({ ...p, payloadCt: Buffer.from('mine').toString('base64') })])).toEqual(['id_conflict']);
      expect(h.caps.rows.get(p.id)).toMatchObject({ userId: OTHER, payloadCt: CT });
    });

    it('Free: a 4th active trigger capsule is refused (nothing stored); date capsules never hit it; an opened one frees a slot', async () => {
      const h = harness();
      const ids = [await armedTrigger(h), await armedTrigger(h), await armedTrigger(h)];
      const fourth = moodCapsule({ triggerMoodId: 'lonely' });
      expect(await statusOf(h, [seal(fourth), seal(dateCapsule())])).toEqual(['trigger_capsule_limit', 'applied']);
      expect(h.caps.rows.has(fourth.id)).toBe(false);
      // "make it a date capsule": the same capsule id, re-sealed as a date capsule under a new mutation id
      expect(await statusOf(h, [seal({ id: fourth.id, payloadCt: CT, unlockType: 'date', unlockLocalDate: '2027-01-01' })])).toEqual([
        'applied',
      ]);
      // opening one frees a slot
      expect(await statusOf(h, [op('open', ids[0], at(-1 * H))])).toEqual(['applied']);
      expect(await statusOf(h, [seal(moodCapsule())])).toEqual(['applied']);
    });

    it('fair use: at most 200 pending date capsules', async () => {
      const h = harness();
      const first = await push(h, Array.from({ length: MAX_PENDING_DATE_CAPSULES }, () => seal(dateCapsule())));
      expect(first.results.every((r) => r.status === 'applied')).toBe(true);
      expect(await statusOf(h, [seal(dateCapsule())])).toEqual(['date_capsule_limit']);
    });

    it('replays follow the sync rules (applied → duplicate, rejected → same reason)', async () => {
      const h = harness();
      const ok = seal(dateCapsule());
      const bad = seal(dateCapsule('2026-10-09'));
      expect(await statusOf(h, [ok, bad])).toEqual(['applied', 'invalid_unlock_date']);
      expect(await statusOf(h, [ok, bad])).toEqual(['duplicate', 'invalid_unlock_date']);
      expect(h.unlock.schedule).toHaveBeenCalledTimes(1);
    });
  });

  describe('open', () => {
    it('is one-way: the first open wins and records the server time; early date opens are tolerated', async () => {
      const h = harness();
      const p = dateCapsule('2027-10-08');
      await push(h, [seal(p)]);
      // The device clock says it's 2027 (moved forward to peek): accepted, the server records the real time.
      expect(await statusOf(h, [op('open', p.id, '2027-10-08T05:00:00Z')])).toEqual(['applied']);
      expect(h.caps.rows.get(p.id)).toMatchObject({ openedAt: NOW, openedDeviceTs: new Date('2027-10-08T05:00:00Z') });
      expect(h.unlock.unschedule).toHaveBeenCalledWith([p.id]);
      const later = new Date(NOW.getTime() + 5 * H);
      await push(h, [op('open', p.id, later.toISOString())], USER, later);
      expect(h.caps.rows.get(p.id)?.openedAt).toEqual(NOW);
    });

    it('opening a trigger capsule that never reported a fire implies the fire (and it must be armed)', async () => {
      const h = harness();
      const id = await armedTrigger(h);
      expect(await statusOf(h, [op('open', id, at(-1 * H))])).toEqual(['applied']);
      const row = h.caps.rows.get(id)!;
      expect(row.firedAt?.toISOString()).toBe(at(-1 * H));
      expect(row.cooldownUntil?.toISOString()).toBe(at(167 * H));
      const fresh = moodCapsule();
      await push(h, [seal(fresh)]); // arms tomorrow
      expect(await statusOf(h, [op('open', fresh.id, at(1 * H))])).toEqual(['capsule_not_armed']);
    });
  });

  describe('fire', () => {
    it('sets fired_at and a 168 h cooldown; a later report changes nothing; an earlier one wins', async () => {
      const h = harness();
      const id = await armedTrigger(h);
      expect(await statusOf(h, [op('fire', id, at(-10 * H))])).toEqual(['applied']);
      expect(h.caps.rows.get(id)).toMatchObject({ firedAt: new Date(at(-10 * H)), cooldownUntil: new Date(at(158 * H)) });
      expect(await statusOf(h, [op('fire', id, at(-5 * H))])).toEqual(['applied']); // later → no change
      expect(h.caps.rows.get(id)?.firedAt?.toISOString()).toBe(at(-10 * H));
      expect(await statusOf(h, [op('fire', id, at(-20 * H))])).toEqual(['applied']); // earlier → wins
      expect(h.caps.rows.get(id)).toMatchObject({ firedAt: new Date(at(-20 * H)), cooldownUntil: new Date(at(148 * H)) });
    });

    it('a fire stamped in the future is recorded at the server time (a fast clock cannot stretch the cooldown)', async () => {
      const h = harness();
      const id = await armedTrigger(h);
      await push(h, [op('fire', id, at(30 * 24 * H))]);
      expect(h.caps.rows.get(id)).toMatchObject({ firedAt: NOW, cooldownUntil: new Date(at(168 * H)) });
    });

    it('rejects date capsules, unarmed capsules, unknown / foreign ids and stale cycles', async () => {
      const h = harness();
      const date = dateCapsule();
      const arming = moodCapsule();
      await push(h, [seal(date), seal(arming)]);
      const armed = await armedTrigger(h);
      const theirs = moodCapsule();
      await push(h, [seal(theirs, { deviceTs: at(-72 * H) })], OTHER);
      expect(
        await statusOf(h, [
          op('fire', date.id),
          op('fire', arming.id),
          op('fire', uuidv7()),
          op('fire', theirs.id, at(-1 * H)),
          op('fire', armed, at(-1 * H), { cycle: 1 }),
          op('fire', armed, at(-1 * H), { cycle: -1 }),
        ]),
      ).toEqual(['not_a_trigger_capsule', 'capsule_not_armed', 'capsule_not_found', 'capsule_not_found', 'stale_cycle', 'invalid_payload']);
      expect(h.caps.rows.get(theirs.id)?.firedAt).toBeNull();
    });
  });

  describe('rearm ("Keep for next time")', () => {
    it('starts a new cycle armed at the re-arm time; the cooldown of the fire stays; old-cycle ops are stale', async () => {
      const h = harness();
      const id = await armedTrigger(h);
      expect(await statusOf(h, [op('fire', id, at(-3 * H)), op('open', id, at(-3 * H)), op('rearm', id, at(-2 * H))])).toEqual([
        'applied',
        'applied',
        'applied',
      ]);
      expect(h.caps.rows.get(id)).toMatchObject({
        cycle: 1,
        armedAt: new Date(at(-2 * H)),
        firedAt: null,
        openedAt: null,
        openedDeviceTs: null,
        cooldownUntil: new Date(at(165 * H)),
        payloadCt: CT,
      });
      // another device, still on cycle 0
      expect(await statusOf(h, [op('open', id, at(-1 * H)), op('fire', id, at(-1 * H))])).toEqual(['stale_cycle', 'stale_cycle']);
      expect(await statusOf(h, [op('fire', id, at(-1 * H), { cycle: 1 })])).toEqual(['applied']);
    });

    it('needs an opened trigger capsule and a free slot', async () => {
      const h = harness();
      const date = dateCapsule();
      await push(h, [seal(date)]);
      const a = await armedTrigger(h);
      expect(await statusOf(h, [op('rearm', date.id), op('rearm', a)])).toEqual(['not_a_trigger_capsule', 'capsule_not_opened']);
      await push(h, [op('open', a, at(-1 * H))]);
      await armedTrigger(h);
      await armedTrigger(h);
      await armedTrigger(h); // 3 active again
      expect(await statusOf(h, [op('rearm', a, at(-1 * H))])).toEqual(['trigger_capsule_limit']);
      expect(h.caps.rows.get(a)).toMatchObject({ cycle: 0 });
      expect(h.caps.rows.get(a)?.openedAt).not.toBeNull();
    });
  });

  describe('delete', () => {
    it('tombstones (content and target erased, cooldown kept) and wins over every later op', async () => {
      const h = harness();
      const id = await armedTrigger(h, { triggerMoodId: 'overwhelmed' });
      await push(h, [op('fire', id, at(-2 * H))]);
      h.caps.objects.add(capsuleObjectPath(USER, id, 'voice'));
      h.caps.objects.add(capsuleObjectPath(USER, id, 'photo-0'));
      const other = capsuleObjectPath(USER, uuidv7(), 'voice');
      h.caps.objects.add(other);

      expect(await statusOf(h, [op('delete', id)])).toEqual(['applied']);
      expect(h.caps.rows.get(id)).toMatchObject({
        deletedAt: NOW,
        payloadCt: null,
        triggerMoodId: null,
        triggerQuadrant: null,
        cooldownUntil: new Date(at(166 * H)),
      });
      expect(h.media.remove).toHaveBeenCalledWith(
        [capsuleObjectPath(USER, id, 'photo-0'), capsuleObjectPath(USER, id, 'voice')].sort(),
        { timeoutMs: 5000 },
      );
      expect([...h.caps.objects]).toEqual([other]);

      const p = moodCapsule({ triggerMoodId: 'overwhelmed' });
      expect(
        await statusOf(h, [
          seal({ ...p, id }),
          op('open', id),
          op('fire', id),
          op('rearm', id),
          op('delete', id), // idempotent
        ]),
      ).toEqual(['capsule_deleted', 'capsule_deleted', 'capsule_deleted', 'capsule_deleted', 'applied']);
      expect(h.media.remove).toHaveBeenCalledTimes(1);
    });

    it('a date capsule: its schedule row goes in the transaction, the job after commit', async () => {
      const h = harness();
      const p = dateCapsule();
      await push(h, [seal(p)]);
      expect(h.caps.schedules.has(p.id)).toBe(true);
      await push(h, [op('delete', p.id)]);
      expect(h.caps.schedules.has(p.id)).toBe(false);
      expect(h.unlock.unschedule).toHaveBeenCalledWith([p.id]);
    });

    it("unknown or someone else's id → silent no-op (their capsule untouched)", async () => {
      const h = harness();
      const theirs = dateCapsule();
      await push(h, [seal(theirs)], OTHER);
      expect(await statusOf(h, [op('delete', uuidv7()), op('delete', theirs.id)])).toEqual(['applied', 'applied']);
      expect(h.caps.rows.get(theirs.id)).toMatchObject({ deletedAt: null, payloadCt: CT });
      expect(h.media.remove).not.toHaveBeenCalled();
    });
  });

  describe('after commit (best-effort)', () => {
    it('seal + open + delete in one push: schedule only what is still pending', async () => {
      const h = harness();
      const a = dateCapsule();
      const b = dateCapsule();
      const c = dateCapsule();
      await push(h, [seal(a), seal(b), seal(c), op('open', b.id), op('delete', c.id)]);
      expect(h.unlock.unschedule).toHaveBeenCalledWith([b.id, c.id]);
      // schedule() gets every sealed id and itself skips opened/deleted ones (SQL filter).
      expect(h.unlock.schedule).toHaveBeenCalledWith([a.id, b.id, c.id]);
    });

    it('Redis or Storage failures never change the push result', async () => {
      const h = harness({ unlockFails: true, mediaFails: true });
      const p = dateCapsule();
      const q = await (async () => {
        const id = await armedTrigger(h);
        h.caps.objects.add(capsuleObjectPath(USER, id, 'voice'));
        return id;
      })();
      expect(await statusOf(h, [seal(p), op('delete', q)])).toEqual(['applied', 'applied']);
      expect(h.caps.rows.get(q)?.deletedAt).toEqual(NOW);
    });

    it('without a service key, media cleanup is skipped (the account purge takes the rest)', async () => {
      const h = harness({ mediaConfigured: false });
      const id = await armedTrigger(h);
      expect(await statusOf(h, [op('delete', id)])).toEqual(['applied']);
      expect(h.media.remove).not.toHaveBeenCalled();
    });

    it('effects of a rolled-back mutation are forgotten', () => {
      const fx = newCapsuleEffects();
      fx.schedule.push('a');
      const mark = markCapsuleEffects(fx);
      fx.schedule.push('b');
      fx.unschedule.push('c');
      fx.removeMedia.push('d');
      rollbackCapsuleEffects(fx, mark);
      expect(fx).toEqual({ schedule: ['a'], unschedule: [], removeMedia: [] });
    });
  });

  it('without the capsule handler (older wiring) capsule mutations are unknown_entity', async () => {
    const tx = { savepoint: <T>(fn: () => Promise<T>) => fn() };
    const service = new SyncService(
      { withTx: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx) } as never,
      new MemSync() as never,
      { require: async () => ({ timezone: TZ }) } as never,
      {} as never,
      { recompute: async () => ({}) } as never,
      {} as never,
    );
    const r = await service.push(USER, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations: [seal(dateCapsule())] }, NOW);
    expect(r.results[0]).toMatchObject({ status: 'rejected', reason: 'unknown_entity' });
  });
});
