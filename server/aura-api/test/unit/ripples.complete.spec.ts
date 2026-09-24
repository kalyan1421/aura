import type { DbService } from '../../src/db/db.service';
import { addBreathCyclesToRoomLantern } from '../../src/rooms/lanterns';
import { RipplesService } from '../../src/ripples/ripples.service';

jest.mock('../../src/rooms/lanterns', () => ({ addBreathCyclesToRoomLantern: jest.fn(async () => ({ level: 1 })) }));

/**
 * `POST /v1/ripples/sessions/:id/complete` (contracts/api/v1-ripples.md §2.3) against a scripted transaction:
 * the server clock caps the claimed cycles, room sessions add their HUMAN cycles to the room lantern (F5 hook,
 * src/rooms/lanterns.ts), the echo row is written in its own transaction and carries nothing that identifies anyone.
 */
const NOW = new Date('2026-10-08T16:00:00Z');
const USER = '11111111-1111-4111-8111-111111111111';
const SESSION = '22222222-2222-4222-8222-222222222222';
const ROOM = '33333333-3333-4333-8333-333333333333';

interface Script {
  entry: 'quick' | 'room';
  /** How far into the session "now" is. */
  elapsedS: number;
  consentWithdrawn?: boolean;
  echoesFlag?: boolean;
}

function fakeDb(s: Script): { db: DbService; queries: Array<{ sql: string; params: unknown[] }>; txCount: () => number } {
  const queries: Array<{ sql: string; params: unknown[] }> = [];
  let tx = 0;
  const t0 = new Date(NOW.getTime() - s.elapsedS * 1000);
  const q = {
    query: async (sql: string, params: unknown[] = []) => {
      queries.push({ sql, params });
      const rows = (r: unknown[]) => ({ rows: r, rowCount: r.length });
      if (/select now\(\)/.test(sql)) return rows([{ now: NOW }]);
      if (/from public\.ripple_seats\s+where session_id = \$1 and user_id = \$2/.test(sql)) return rows([{ id: 'seat-a', seat: 1, completed_at: null }]);
      if (/from public\.ripple_sessions where id/.test(sql)) {
        return rows([
          {
            id: SESSION,
            entry: s.entry,
            room_id: s.entry === 'room' ? ROOM : null,
            start_rule: 'invite',
            t0,
            settle_ms: 10_000,
            inhale_ms: 4000,
            exhale_ms: 6000,
            cycles: 16,
            fade_ms: 10_000,
            pacer_version: 1,
            ends_at: new Date(t0.getTime() + 180_000),
            ended_at: null,
          },
        ]);
      }
      if (/from public\.feature_flags/.test(sql)) return rows(s.echoesFlag === false ? [{ enabled: false }] : []);
      if (/from public\.user_consents/.test(sql)) return rows(s.consentWithdrawn ? [{ withdrawn_at: NOW }] : []);
      return rows([]);
    },
  };
  const db = {
    withTx: async <T>(fn: (t: typeof q) => Promise<T>): Promise<T> => {
      tx += 1;
      return fn(q);
    },
    query: q.query,
  } as unknown as DbService;
  return { db, queries, txCount: () => tx };
}

const trace = { offsets: Array.from({ length: 32 }, (_, i) => (i % 3) - 1) };
const lantern = addBreathCyclesToRoomLantern as jest.MockedFunction<typeof addBreathCyclesToRoomLantern>;

describe('complete: cycles, the room-lantern hook and the unlinked echo', () => {
  beforeEach(() => lantern.mockClear());

  it('room session: the human cycles (capped by the server clock) light the room lantern', async () => {
    const f = fakeDb({ entry: 'room', elapsedS: 185 });
    await new RipplesService(f.db).complete(USER, SESSION, { cycles: 16, trace });
    expect(lantern).toHaveBeenCalledTimes(1);
    expect(lantern).toHaveBeenCalledWith(expect.anything(), ROOM, 16, NOW);
    const upd = f.queries.find((x) => /update public\.ripple_seats set cycles_done/.test(x.sql));
    expect(upd?.params).toEqual(['seat-a', 16, true, NOW]);
  });

  it('a claim beyond the clock is capped (30 s in → 2 cycles), and no echo under 12 cycles', async () => {
    const f = fakeDb({ entry: 'room', elapsedS: 30 });
    await new RipplesService(f.db).complete(USER, SESSION, { cycles: 16, trace });
    expect(lantern).toHaveBeenCalledWith(expect.anything(), ROOM, 2, NOW);
    expect(f.queries.some((x) => /echo_library/.test(x.sql))).toBe(false);
    expect(f.txCount()).toBe(1);
  });

  it('quick sessions never touch a lantern; the echo goes in its own transaction with no identifying value', async () => {
    const f = fakeDb({ entry: 'quick', elapsedS: 185 });
    await new RipplesService(f.db).complete(USER, SESSION, { cycles: 16, trace });
    expect(lantern).not.toHaveBeenCalled();
    expect(f.txCount()).toBe(2);
    const ins = f.queries.find((x) => /insert into echo_library\.recordings/.test(x.sql));
    expect(ins).toBeDefined();
    const flat = JSON.stringify(ins?.params);
    for (const secret of [USER, SESSION, ROOM, 'seat-a']) expect(flat).not.toContain(secret);
    expect(ins?.params).toEqual([1, trace.offsets, expect.any(Number), expect.any(Number), '2026-W41']);
  });

  it('opted out, or echoes switched off: no echo row', async () => {
    for (const s of [{ consentWithdrawn: true }, { echoesFlag: false }]) {
      const f = fakeDb({ entry: 'quick', elapsedS: 185, ...s });
      await new RipplesService(f.db).complete(USER, SESSION, { cycles: 16, trace });
      expect(f.queries.some((x) => /echo_library/.test(x.sql))).toBe(false);
    }
  });
});
