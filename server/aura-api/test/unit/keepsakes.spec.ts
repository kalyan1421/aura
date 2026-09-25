/**
 * F13 keepsakes, unit level: the rule's edge cases beyond the vectors, the awarding step against a scripted database
 * (dates in the person's zone, idempotent writes, the Lantern Hour watermark) and the contract guards —
 * REQ-SHR-05 (no product, gift, Stardust or Plus path grants a keepsake), REQ-SHR-06 / DS-10 / CI-8 (nothing but the
 * caller's own route ever reads keepsakes; no room, reflection, game or Quiet Together code mentions them) and the
 * one route takes no person selector.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { ROUTE_ARGS_METADATA } from '@nestjs/common/constants';
import type { QueryResult, QueryResultRow } from 'pg';
import { GIFT_PRODUCTS, PLUS_PRODUCTS, SKY_THEMES } from '../../src/billing/catalogue';
import type { Queryable } from '../../src/db/db';
import { awardKeepsakes, listOwnKeepsakes } from '../../src/keepsakes/award';
import { KEEPSAKE_KEYS, KEEPSAKES, earnedKeepsakes, sharePrompt } from '../../src/keepsakes/keepsake-rules';
import { KeepsakesController } from '../../src/keepsakes/keepsakes.controller';

const SRC = resolve(__dirname, '..', '..', 'src');

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? walk(p) : p.endsWith('.ts') ? [p] : [];
  });
}

/** A scripted database: answers by the first matching SQL fragment and records every statement. */
class FakeDb implements Queryable {
  readonly log: Array<{ sql: string; params: unknown[] }> = [];
  constructor(private readonly answers: Array<[RegExp, (params: unknown[]) => QueryResultRow[]]>) {}
  query<R extends QueryResultRow = QueryResultRow>(sql: string, params: unknown[] = []): Promise<QueryResult<R>> {
    this.log.push({ sql, params });
    const hit = this.answers.find(([re]) => re.test(sql));
    const rows = (hit ? hit[1](params) : []) as R[];
    return Promise.resolve({ rows, rowCount: /^\s*insert/i.test(sql) ? 1 : rows.length, command: '', oid: 0, fields: [] });
  }
  writes(): Array<{ sql: string; params: unknown[] }> {
    return this.log.filter((l) => /^\s*insert|^\s*update|^\s*delete/i.test(l.sql));
  }
}

const USER = '0199a1b2-0000-7000-8000-000000000001';

describe('keepsake rules (beyond the vectors)', () => {
  it('the catalogue keys match the migration check list (one source of truth per stack)', () => {
    const sql = readFileSync(resolve(__dirname, '..', '..', '..', '..', 'supabase', 'migrations', '20261005000026_keepsakes.sql'), 'utf8');
    const listed = [...sql.matchAll(/'([a-z0-9_]+)'/g)].map((m) => m[1]).filter((k) => KEEPSAKE_KEYS.includes(k));
    expect(new Set(listed)).toEqual(new Set(KEEPSAKE_KEYS));
    expect(KEEPSAKES).toHaveLength(13);
  });

  it('is pure: the same records always give the same keepsakes and days (idempotent awarding)', () => {
    const sources = {
      capsuleSeals: [{ day: '2026-10-05', amount: 1 }],
      sanctuarySeconds: [
        { day: '2026-10-06', amount: 3000 },
        { day: '2026-10-07', amount: 600 },
      ],
    };
    expect(earnedKeepsakes(sources)).toEqual(earnedKeepsakes(sources));
    expect(earnedKeepsakes(sources).map((k) => k.key)).toEqual(['capsule_sealed_first', 'sanctuary_minutes_60']);
  });

  it('a negative or broken tally is treated as none', () => {
    expect(earnedKeepsakes({ lanternNights: [{ day: '2026-10-08', amount: 1 }], lanternCounted: -3 })).toEqual([
      { key: 'lantern_hours_1', day: '2026-10-08' },
    ]);
  });

  it('share prompts never reward: they only name a milestone (REQ-SHR-03)', () => {
    const r = sharePrompt({ stage: 'glow', lifetimeGlowDays: 0, capsuleYears: 0, offered: [], hideGlow: false });
    expect(r).toEqual({ prompt: 'evolution:glow', offer: ['evolution:ember', 'evolution:glow'] });
  });
});

describe('awardKeepsakes (scripted database)', () => {
  const base = (over: Partial<Record<string, (p: unknown[]) => QueryResultRow[]>> = {}): FakeDb =>
    new FakeDb([
      [/pg_advisory_xact_lock/, () => []],
      [/from public\.profiles/, over.profile ?? (() => [{ timezone: 'Asia/Kolkata' }])],
      [/from public\.capsules/, over.capsules ?? (() => [{ sealed: null, opened: null }])],
      [/from public\.active_days/, over.glow ?? (() => [])],
      [/from public\.ripple_seats/, over.ripple ?? (() => [{ ended: null }])],
      [/from public\.keepsake_tallies/, over.tally ?? (() => [])],
      [/from public\.room_members/, over.nights ?? (() => [])],
      [/from public\.sanctuary_sessions/, over.sanctuary ?? (() => [])],
    ]);

  it('no profile: nothing is read beyond it and nothing is written', async () => {
    const db = base({ profile: () => [] });
    await expect(awardKeepsakes(db, USER)).resolves.toEqual({ added: [], newNights: 0 });
    expect(db.writes()).toEqual([]);
  });

  it('takes the per-user lock first (serialises with the sync push and the worker)', async () => {
    const db = base();
    await awardKeepsakes(db, USER);
    expect(db.log[0].sql).toMatch(/pg_advisory_xact_lock\(hashtextextended\('aura:user:'/);
  });

  it('dates a seal by the Aura day in the person\'s zone (04:00 rollover)', async () => {
    // 02:00 IST on 6 Oct = 20:30 UTC on 5 Oct → Aura day 5 Oct; opened 05:00 IST on 13 Oct → 13 Oct.
    const db = base({ capsules: () => [{ sealed: new Date('2026-10-05T20:30:00Z'), opened: new Date('2026-10-12T23:30:00Z') }] });
    const out = await awardKeepsakes(db, USER);
    expect(out.added).toEqual(['capsule_sealed_first', 'capsule_opened_first']);
    const inserts = db.writes().filter((w) => /into public\.keepsakes/.test(w.sql));
    expect(inserts.map((w) => w.params)).toEqual([
      [USER, 'capsule_sealed_first', '2026-10-05'],
      [USER, 'capsule_opened_first', '2026-10-13'],
    ]);
    expect(inserts.every((w) => /on conflict \(user_id, keepsake_key\) do nothing/.test(w.sql))).toBe(true);
  });

  it('Lantern Hour nights continue the tally and move its watermark to the latest night', async () => {
    const through = new Date('2026-10-01T15:30:00Z');
    const n1 = new Date('2026-10-02T15:30:00Z');
    const n2 = new Date('2026-10-03T15:30:00Z');
    const db = base({
      tally: () => [{ lantern_nights: 8, lantern_through: through }],
      nights: (p) => {
        expect(p[2]).toBe(through); // only nights after the watermark
        return [{ night: n1 }, { night: n2 }];
      },
    });
    const out = await awardKeepsakes(db, USER);
    expect(out).toEqual({ added: ['lantern_hours_10'], newNights: 2 });
    const tally = db.writes().find((w) => /into public\.keepsake_tallies/.test(w.sql));
    expect(tally?.params).toEqual([USER, 10, n2]);
    const k = db.writes().find((w) => /into public\.keepsakes/.test(w.sql));
    expect(k?.params).toEqual([USER, 'lantern_hours_10', '2026-10-03']);
  });

  it('no new night: the tally is left alone', async () => {
    const db = base({ tally: () => [{ lantern_nights: 3, lantern_through: new Date('2026-10-01T15:30:00Z') }] });
    await awardKeepsakes(db, USER);
    expect(db.writes()).toEqual([]);
  });

  it('reads no content column (notes, capsule payloads, moods, pseudonyms)', async () => {
    const db = base();
    await awardKeepsakes(db, USER);
    const sql = db.log.map((l) => l.sql).join('\n');
    for (const col of ['payload_ct', 'note_ct', 'mood_id', 'quadrant', 'pseudonym', 'tags', 'voice_path', 'birth_date', 'intention_key']) {
      expect(sql).not.toContain(col);
    }
  });

  it('lists only the caller\'s rows, in catalogue order', async () => {
    const db = new FakeDb([
      [
        /from public\.keepsakes/,
        (p) => {
          expect(p).toEqual([USER]);
          return [
            { keepsake_key: 'sanctuary_minutes_60', earned_on: '2026-10-09' },
            { keepsake_key: 'capsule_sealed_first', earned_on: '2026-10-05' },
          ];
        },
      ],
    ]);
    await expect(listOwnKeepsakes(db, USER)).resolves.toEqual([
      { key: 'capsule_sealed_first', earnedOn: '2026-10-05' },
      { key: 'sanctuary_minutes_60', earnedOn: '2026-10-09' },
    ]);
    expect(db.log[0].sql).toMatch(/where user_id = \$1/);
  });
});

describe('contract guards', () => {
  it('REQ-SHR-05: no product, gift, sky or Stardust path is or grants a keepsake', () => {
    const ids = [...PLUS_PRODUCTS, ...GIFT_PRODUCTS.map((g) => g.productId), ...SKY_THEMES.map((t) => t.id)];
    for (const id of ids) {
      expect(id).not.toMatch(/keepsake|seal/);
      expect(KEEPSAKE_KEYS).not.toContain(id);
    }
  });

  it('REQ-SHR-05 / REQ-SHR-06 / DS-10: only the keepsakes module, the purge, the owner’s own data export and the module wiring mention keepsakes', () => {
    // account-export.ts: the person's own export (F8 REQ-ACC-12) lists their own keepsakes; it answers only its caller.
    const allowed = new Set(['keepsakes', 'account/account-purge.ts', 'account/account-export.ts', 'app.module.ts', 'worker.module.ts']);
    const offenders = walk(SRC)
      .map((p) => relative(SRC, p))
      .filter((rel) => !allowed.has(rel) && !allowed.has(rel.split('/')[0]))
      .filter((rel) => /keepsake/i.test(readFileSync(join(SRC, rel), 'utf8').replace(/^\s*(\*|\/\/).*$/gm, '')));
    // Billing (products, gifts, Stardust, Plus), rooms, reflections, Breath Ripples, Quiet Together, sync and
    // progression never read or write a keepsake.
    expect(offenders).toEqual([]);
  });

  it('nothing outside src/keepsakes imports it (self-contained; the feature can be cut)', () => {
    const importers = walk(SRC)
      .map((p) => relative(SRC, p))
      .filter((rel) => !rel.startsWith('keepsakes/'))
      .filter((rel) => /from '\.\.?\/(\.\.\/)*keepsakes\//.test(readFileSync(join(SRC, rel), 'utf8')));
    expect(importers.sort()).toEqual(['app.module.ts', 'worker.module.ts']);
  });

  it('the only route is GET /v1/keepsakes and it takes no person selector (no @Param, no @Query, no @Body)', () => {
    expect(Reflect.getMetadata('path', KeepsakesController)).toBe('v1/keepsakes');
    const methods = Object.getOwnPropertyNames(KeepsakesController.prototype).filter((m) => m !== 'constructor');
    expect(methods).toEqual(['mine']);
    const mine = KeepsakesController.prototype.mine as unknown as object;
    expect(Reflect.getMetadata('path', mine)).toBe('/');
    expect(Reflect.getMetadata('method', mine)).toBe(0); // RequestMethod.GET
    const args = Reflect.getMetadata(ROUTE_ARGS_METADATA, KeepsakesController, 'mine') as Record<string, unknown>;
    expect(Object.keys(args)).toHaveLength(1);
    expect(Object.keys(args)[0]).toMatch(/__customRouteArgs__/); // @CurrentUser() only
  });
});
