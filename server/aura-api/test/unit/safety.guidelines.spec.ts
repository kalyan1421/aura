/**
 * F9 REQ-SAFE-04 community guidelines on the server (contracts/api/v1-rooms.md §1.1, §2.3, §2.4), and the caller's
 * own standing without a reason code (19 admin console, Minors & grooming SOP "no tipping off"):
 * - status: the required version (`safety_config.guidelines_version`) is accepted when the caller accepted it or a
 *   newer one;
 * - `POST /v1/safety/guidelines/accept`: validation, profile first, an older version → 409 guidelines_required with the
 *   version to accept, idempotent insert;
 * - `POST /v1/rooms/match`: 409 guidelines_required + version after the profile and room-access checks, before the
 *   pool choice and before any seat is taken; the 409 body carries `version` (GuidelinesRequiredFilter);
 * - `GET /v1/safety/me`: never a reason code, lane or report detail for any sanction kind; shadow-mutes never appear.
 * The live-database versions run in test/e2e/rooms.e2e-spec.ts.
 */
import { HttpStatus } from '@nestjs/common';
import { FILTER_CATCH_EXCEPTIONS } from '@nestjs/common/constants';
import type { CatalogueService } from '../../src/catalogue/catalogue.service';
import { ApiError } from '../../src/common/api-error';
import type { DbService } from '../../src/db/db.service';
import type { RoomsRepository } from '../../src/rooms/rooms.repository';
import { RoomsService } from '../../src/rooms/rooms.service';
import {
  assertGuidelinesAccepted,
  GuidelinesRequiredError,
  GuidelinesRequiredFilter,
  GuidelinesService,
  guidelinesStatus,
} from '../../src/safety/guidelines';
import { SANCTION_KINDS, SHADOW_SANCTIONS, type SanctionKind } from '../../src/safety/safety-types';
import { SafetyService } from '../../src/safety/safety.service';

const U = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const ACCEPTED_AT = new Date('2026-10-08T10:00:00Z');

interface Sanction {
  id: string;
  kind: SanctionKind;
  reason_code: string;
  created_at: Date;
  ends_at: Date | null;
}

/** An in-memory slice of the safety tables. Every SQL text is recorded; unknown SQL fails the test. */
class FakeDb {
  current = 1;
  profile = true;
  accepted = new Map<number, Date>();
  sanctions: Sanction[] = [];
  flags: Record<string, boolean> = {};
  pool: 'en' | 'te' | 'hi' = 'en';
  failInsert: string | null = null;
  readonly sql: string[] = [];
  txCount = 0;

  async query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    this.sql.push(text);
    const rows = (r: unknown[]) => ({ rows: r, rowCount: r.length });
    if (/from public\.guidelines_acceptances g/.test(text)) {
      const newest = [...this.accepted.keys()].sort((a, b) => b - a)[0];
      return rows([{ current: this.current, accepted_version: newest ?? null, accepted_at: newest ? this.accepted.get(newest) : null }]);
    }
    if (/insert into public\.guidelines_acceptances/.test(text)) {
      if (this.failInsert) throw Object.assign(new Error('insert failed'), { code: this.failInsert });
      const v = params[1] as number;
      if (this.accepted.has(v)) return rows([]);
      this.accepted.set(v, ACCEPTED_AT);
      return { rows: [], rowCount: 1 };
    }
    if (/select 1 from public\.profiles/.test(text)) return rows(this.profile ? [{ '?column?': 1 }] : []);
    if (/from public\.profiles/.test(text)) return rows(this.profile ? [{ language_pool: this.pool, timezone: 'Asia/Kolkata' }] : []);
    if (/from public\.feature_flags/.test(text)) return rows([{ enabled: this.flags[params[0] as string] ?? false }]);
    if (/select s\.kind, s\.ends_at from public\.sanctions s/.test(text)) {
      // roomAccess(): active room-access sanctions (the SQL names the kinds).
      return rows(this.sanctions.filter((s) => text.includes(`'${s.kind}'`)).map((s) => ({ kind: s.kind, ends_at: s.ends_at })));
    }
    if (/from public\.sanctions/.test(text) && Array.isArray(params[1])) {
      // SafetyService.me() notices: the kinds the service asks for, with only the columns it selects.
      const kinds = params[1] as string[];
      return rows(
        this.sanctions
          .filter((s) => kinds.includes(s.kind))
          .map((s) => ({
            id: s.id,
            kind: s.kind,
            created_at: s.created_at,
            ends_at: s.ends_at,
            ...(/reason_code/.test(text) ? { reason_code: s.reason_code } : {}),
          })),
      );
    }
    throw new Error(`unexpected SQL in fake: ${text.slice(0, 90)}`);
  }

  async withTx<T>(fn: (tx: FakeDb) => Promise<T>): Promise<T> {
    this.txCount += 1;
    return fn(this);
  }
}

const asDb = (f: FakeDb): DbService => f as unknown as DbService;

describe('guidelines status and the gate', () => {
  it('never accepted → not accepted, the required version, nulls', async () => {
    const db = new FakeDb();
    expect(await guidelinesStatus(asDb(db), U)).toEqual({ version: 1, accepted: false, acceptedVersion: null, acceptedAt: null });
    await expect(assertGuidelinesAccepted(asDb(db), U)).rejects.toMatchObject({ status: 409, code: 'guidelines_required', version: 1 });
  });

  it('the required version, or a newer one, opens rooms; an older one does not', async () => {
    const db = new FakeDb();
    db.accepted.set(1, ACCEPTED_AT);
    expect(await guidelinesStatus(asDb(db), U)).toEqual({ version: 1, accepted: true, acceptedVersion: 1, acceptedAt: ACCEPTED_AT.toISOString() });
    await expect(assertGuidelinesAccepted(asDb(db), U)).resolves.toBeUndefined();

    db.current = 2; // material change: everyone is asked again
    expect(await guidelinesStatus(asDb(db), U)).toMatchObject({ version: 2, accepted: false, acceptedVersion: 1 });
    const err = await assertGuidelinesAccepted(asDb(db), U).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(GuidelinesRequiredError);
    expect(err).toBeInstanceOf(ApiError); // anywhere without the filter it is still a plain { code, message } 409
    expect(err).toMatchObject({ status: HttpStatus.CONFLICT, code: 'guidelines_required', version: 2 });

    db.accepted.set(3, ACCEPTED_AT); // an app that carried newer copy before the server asked for it
    expect(await guidelinesStatus(asDb(db), U)).toMatchObject({ version: 2, accepted: true, acceptedVersion: 3 });
  });
});

describe('POST /v1/safety/guidelines/accept', () => {
  it('validation: an integer version 1–1000, nothing else; nothing touches the database', async () => {
    const db = new FakeDb();
    const svc = new GuidelinesService(asDb(db));
    for (const body of [undefined, null, {}, { version: 0 }, { version: -1 }, { version: 1.5 }, { version: '1' }, { version: 1001 }, { v: 1 }]) {
      await expect(svc.accept(U, body)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    }
    expect(db.sql).toEqual([]);
  });

  it('records the required version once (idempotent: the first accepted_at stays)', async () => {
    const db = new FakeDb();
    const svc = new GuidelinesService(asDb(db));
    const first = await svc.accept(U, { version: 1 });
    expect(first).toEqual({ version: 1, accepted: true, acceptedVersion: 1, acceptedAt: ACCEPTED_AT.toISOString() });
    expect(await svc.accept(U, { version: 1 })).toEqual(first);
    expect(db.accepted.size).toBe(1);
    expect(db.sql.filter((s) => /insert into public\.guidelines_acceptances/.test(s)).every((s) => /on conflict \(user_id, version\) do nothing/.test(s))).toBe(true);
  });

  it('a newer version than required is recorded (and satisfies the gate); an older one → 409 + the version to accept', async () => {
    const db = new FakeDb();
    db.current = 2;
    const svc = new GuidelinesService(asDb(db));
    const stale = await svc.accept(U, { version: 1 }).catch((e: unknown) => e);
    expect(stale).toBeInstanceOf(GuidelinesRequiredError);
    expect(stale).toMatchObject({ status: 409, code: 'guidelines_required', version: 2 });
    expect(db.accepted.size).toBe(0);
    expect(await svc.accept(U, { version: 3 })).toMatchObject({ version: 2, accepted: true, acceptedVersion: 3 });
  });

  it('needs a profile first (409 profile_required), also when it disappears mid-way (FK 23503)', async () => {
    const db = new FakeDb();
    db.profile = false;
    const svc = new GuidelinesService(asDb(db));
    await expect(svc.accept(U, { version: 1 })).rejects.toMatchObject({ status: 409, code: 'profile_required' });
    expect(db.accepted.size).toBe(0);
    db.profile = true;
    db.failInsert = '23503';
    await expect(svc.accept(U, { version: 1 })).rejects.toMatchObject({ status: 409, code: 'profile_required' });
    db.failInsert = '57014';
    await expect(svc.accept(U, { version: 1 })).rejects.toMatchObject({ code: '57014' }); // anything else is not hidden
  });
});

describe('GuidelinesRequiredFilter', () => {
  const host = (res: object) => ({ switchToHttp: () => ({ getResponse: () => res }) }) as never;

  it('catches only GuidelinesRequiredError and writes { code, message, version } with 409', () => {
    expect(Reflect.getMetadata(FILTER_CATCH_EXCEPTIONS, GuidelinesRequiredFilter)).toEqual([GuidelinesRequiredError]);
    const out: { status?: number; body?: unknown } = {};
    const res = {
      headersSent: false,
      status(s: number) {
        out.status = s;
        return this;
      },
      json(b: unknown) {
        out.body = b;
        return this;
      },
    };
    new GuidelinesRequiredFilter().catch(new GuidelinesRequiredError(2), host(res));
    expect(out).toEqual({ status: 409, body: { code: 'guidelines_required', message: expect.any(String), version: 2 } });
    expect(JSON.stringify(out.body)).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}/); // never an id
  });

  it('does nothing once headers are out', () => {
    const res = { headersSent: true, status: jest.fn(), json: jest.fn() };
    new GuidelinesRequiredFilter().catch(new GuidelinesRequiredError(1), host(res));
    expect(res.status).not.toHaveBeenCalled();
  });

  it('is wired on POST /v1/rooms/match and POST /v1/safety/guidelines/accept', async () => {
    const { RoomsController } = await import('../../src/rooms/rooms.controller');
    const { SafetyController } = await import('../../src/safety/safety.controller');
    expect(Reflect.getMetadata('__exceptionFilters__', RoomsController.prototype.match)).toEqual([GuidelinesRequiredFilter]);
    expect(Reflect.getMetadata('__exceptionFilters__', SafetyController.prototype.acceptGuidelines)).toEqual([GuidelinesRequiredFilter]);
  });
});

describe('POST /v1/rooms/match: the guidelines gate', () => {
  const service = (db: FakeDb) =>
    new RoomsService(asDb(db), {} as RoomsRepository, { moodQuadrant: async () => 'storm' } as unknown as CatalogueService);
  const body = { quadrant: 'storm', moodId: 'anxious' };

  it('not accepted → 409 guidelines_required + version, before any seat is taken', async () => {
    const db = new FakeDb();
    await expect(service(db).match(U, body)).rejects.toMatchObject({ status: 409, code: 'guidelines_required', version: 1 });
    expect(db.txCount).toBe(0);
  });

  it('order: 400 → 409 profile_required → 403 rooms_suspended / account_closed → 409 guidelines_required → pool choice', async () => {
    const db = new FakeDb();
    await expect(service(db).match(U, { quadrant: 'storm' })).rejects.toMatchObject({ status: 400 });
    db.profile = false;
    await expect(service(db).match(U, body)).rejects.toMatchObject({ code: 'profile_required' });
    db.profile = true;
    db.sanctions = [{ id: 's1', kind: 'room_suspension', reason_code: 'grooming', created_at: ACCEPTED_AT, ends_at: new Date(Date.now() + 3_600_000) }];
    await expect(service(db).match(U, body)).rejects.toMatchObject({ code: 'rooms_suspended' });
    db.sanctions = [{ id: 's2', kind: 'account_ban', reason_code: 'grooming', created_at: ACCEPTED_AT, ends_at: null }];
    await expect(service(db).match(U, body)).rejects.toMatchObject({ code: 'account_closed' });
    db.sanctions = [];
    db.pool = 'hi'; // Hindi + Hinglish rooms not open yet: the guidelines still come first
    await expect(service(db).match(U, body)).rejects.toMatchObject({ code: 'guidelines_required' });
    db.accepted.set(1, ACCEPTED_AT);
    await expect(service(db).match(U, body)).rejects.toMatchObject({ code: 'language_pool_unavailable' });
    expect(db.txCount).toBe(0);
  });
});

describe('GET /v1/safety/me: no tipping off', () => {
  const FORBIDDEN = /reason|lane|grooming|minor|under_?13|strike|report/i;
  const sanction = (kind: SanctionKind, reason_code = 'grooming'): Sanction => ({
    id: `00000000-0000-4000-8000-${String(SANCTION_KINDS.indexOf(kind) + 1).padStart(12, '0')}`,
    kind,
    reason_code,
    created_at: ACCEPTED_AT,
    ends_at: kind === 'warning' || kind === 'rooms_pause' || kind === 'social_ban' || kind === 'account_ban' ? null : new Date(Date.now() + 86_400_000),
  });

  it.each(SANCTION_KINDS)('%s: no reason code, lane or report detail anywhere in the response', async (kind) => {
    const db = new FakeDb();
    db.sanctions = [sanction(kind), sanction(kind, 'minor_sexual_content')];
    const me = await new SafetyService(asDb(db)).me(U);
    expect(JSON.stringify(me)).not.toMatch(FORBIDDEN);
    for (const n of me.notices) expect(Object.keys(n).sort()).toEqual(['createdAt', 'kind', 'noticeId', 'until']);
    // The reason code is never even read for the person's own view.
    expect(db.sql.some((s) => /reason_code/.test(s))).toBe(false);
  });

  it('shadow-mutes stay invisible: no notice, rooms available', async () => {
    for (const kind of SHADOW_SANCTIONS) {
      const db = new FakeDb();
      db.sanctions = [sanction(kind)];
      const me = await new SafetyService(asDb(db)).me(U);
      expect(me).toMatchObject({ rooms: 'available', until: null, notices: [] });
    }
  });

  it('what the person does see: the kind, when, until when, and the guidelines status', async () => {
    const db = new FakeDb();
    db.accepted.set(1, ACCEPTED_AT);
    db.sanctions = [sanction('rooms_pause', 'under_13_reports'), sanction('warning', 'harassment'), sanction('gesture_shadow_mute', 'gesture_flood')];
    const me = await new SafetyService(asDb(db)).me(U);
    expect(me).toEqual({
      rooms: 'suspended',
      until: null,
      notices: [
        { noticeId: expect.any(String), kind: 'suspension', createdAt: ACCEPTED_AT.toISOString(), until: null },
        { noticeId: expect.any(String), kind: 'warning', createdAt: ACCEPTED_AT.toISOString(), until: null },
      ],
      guidelines: { version: 1, accepted: true, acceptedVersion: 1, acceptedAt: ACCEPTED_AT.toISOString() },
    });
    const closed = new FakeDb();
    closed.sanctions = [sanction('account_ban')];
    expect(await new SafetyService(asDb(closed)).me(U)).toMatchObject({
      rooms: 'closed',
      notices: [{ kind: 'account_closed' }],
      guidelines: { version: 1, accepted: false },
    });
  });
});
