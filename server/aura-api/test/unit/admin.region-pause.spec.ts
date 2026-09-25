/**
 * Per-region pauses of Quiet Together and the Lantern Hour wind-down (PRD 19 "Configuration"): the console edits
 * `payload.pausedRegions` of `quiet_enabled` / `lantern_wind_down_enabled`, validated against the server's own region
 * list, with the audit row (keys and regions only) in the same transaction; the server's `isPaused` then honours it.
 */
import type { AdminDb } from '../../src/admin/admin-db';
import type { StaffUser } from '../../src/admin/admin-types';
import { RegionPauseService, pausedRegionsOf } from '../../src/admin/region-pause.service';
import type { DbService } from '../../src/db/db.service';
import { isPaused } from '../../src/quiet/quiet-flags';
import { TZ_REGIONS } from '../../src/rooms/regions';

type Row = { key: string; enabled: boolean; payload: unknown; updated_at: Date | null };

class FakeTx {
  readonly calls: Array<{ text: string; params: unknown[] }> = [];
  constructor(private readonly flags: Map<string, Row>) {}
  async query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    this.calls.push({ text, params });
    if (/insert into public\.moderation_actions/.test(text)) return { rows: [{ id: '1' }], rowCount: 1 };
    if (/^select key, enabled, payload, updated_at from public\.feature_flags where key = \$1 for update/.test(text)) {
      const r = this.flags.get(params[0] as string);
      return { rows: r ? [r] : [], rowCount: r ? 1 : 0 };
    }
    if (/where key = any/.test(text)) {
      const rows = [...this.flags.values()].filter((r) => (params[0] as string[]).includes(r.key)).sort((a, b) => a.key.localeCompare(b.key));
      return { rows, rowCount: rows.length };
    }
    if (/^update public\.feature_flags set payload/.test(text)) {
      const r = this.flags.get(params[0] as string)!;
      const next = { ...r, payload: { ...(r.payload as object), pausedRegions: JSON.parse(params[1] as string) }, updated_at: new Date('2026-09-25T10:00:00Z') };
      this.flags.set(r.key, next);
      return { rows: [next], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  }
  audits(): Array<{ actor: string; action: string; reasonCode: unknown; detail: Record<string, unknown> }> {
    return this.calls
      .filter((c) => /insert into public\.moderation_actions/.test(c.text))
      .map((c) => ({ actor: c.params[0] as string, action: c.params[1] as string, reasonCode: c.params[4], detail: JSON.parse(c.params[5] as string) }));
  }
}

class FakeDb {
  readonly txs: FakeTx[] = [];
  constructor(readonly flags: Map<string, Row>) {}
  async withTx<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
    const tx = new FakeTx(this.flags);
    this.txs.push(tx);
    return fn(tx);
  }
  query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    return this.withTx((tx) => tx.query(text, params));
  }
}

const OWNER: StaffUser = {
  id: '0192f0c2-7a4e-7c1a-9b3d-000000000001',
  role: 'owner',
  displayName: 'owner',
  email: null,
  sessionId: '0192f0c2-7a4e-7c1a-9b3d-0000000000aa',
  sessionStartedAt: new Date().toISOString(),
  sessionExpiresAt: new Date(Date.now() + 3_600_000).toISOString(),
  mfa: 'verified',
  actor: 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001',
};

function setup(): { svc: RegionPauseService; service: FakeDb; admin: FakeDb } {
  const flags = new Map<string, Row>([
    ['quiet_enabled', { key: 'quiet_enabled', enabled: true, payload: { pausedRegions: [] }, updated_at: null }],
    ['lantern_wind_down_enabled', { key: 'lantern_wind_down_enabled', enabled: true, payload: { pausedRegions: ['nowhere', 'americas'] }, updated_at: null }],
    ['rooms_enabled', { key: 'rooms_enabled', enabled: true, payload: {}, updated_at: null }],
  ]);
  const service = new FakeDb(flags);
  const admin = new FakeDb(flags);
  return { svc: new RegionPauseService(admin as unknown as AdminDb, service as unknown as DbService), service, admin };
}

describe('per-region kill switches (quiet_enabled, lantern_wind_down_enabled)', () => {
  it('reads both flags with the server region list; unknown stored names are dropped', async () => {
    const { svc } = setup();
    const view = await svc.get();
    expect(view.regions).toEqual(TZ_REGIONS);
    expect(view.flags.map((f) => [f.key, f.enabled, f.pausedRegions])).toEqual([
      ['lantern_wind_down_enabled', true, ['americas']],
      ['quiet_enabled', true, []],
    ]);
  });

  it('pause then resume: payload edited by the service role, audited in the same transaction (keys and regions only)', async () => {
    const { svc, service, admin } = setup();
    const paused = await svc.setPaused(OWNER, 'quiet_enabled', 'south_asia', true, { reasonCode: 'lantern_hour_incident' });
    expect(paused).toMatchObject({ key: 'quiet_enabled', enabled: true, pausedRegions: ['south_asia'] });
    expect(admin.txs).toHaveLength(0); // aura_admin may not write payloads
    expect(service.txs).toHaveLength(1);
    expect(service.txs[0].audits()).toEqual([
      {
        actor: OWNER.actor,
        action: 'config_region_pause',
        reasonCode: 'lantern_hour_incident',
        detail: { key: 'quiet_enabled', region: 'south_asia', pausedRegions: ['south_asia'], previous: [] },
      },
    ]);
    // The server's own check now pauses that region only.
    const row = service.flags.get('quiet_enabled')!;
    expect(isPaused(row, 'south_asia')).toBe(true);
    expect(isPaused(row, 'europe_africa')).toBe(false);

    await svc.setPaused(OWNER, 'quiet_enabled', 'americas', true, { reasonCode: 'x' });
    const resumed = await svc.setPaused(OWNER, 'quiet_enabled', 'south_asia', false, { reasonCode: 'resolved' });
    expect(resumed.pausedRegions).toEqual(['americas']);
    expect(service.txs[2].audits()[0]).toMatchObject({ action: 'config_region_resume', detail: { previous: ['americas', 'south_asia'], pausedRegions: ['americas'] } });
  });

  it('pausing twice keeps one entry; the list stays in region order', async () => {
    const { svc } = setup();
    await svc.setPaused(OWNER, 'lantern_wind_down_enabled', 'east_asia_pacific', true, { reasonCode: 'a' });
    const again = await svc.setPaused(OWNER, 'lantern_wind_down_enabled', 'east_asia_pacific', true, { reasonCode: 'a' });
    expect(again.pausedRegions).toEqual(['americas', 'east_asia_pacific']);
  });

  it('validation: other flags and unknown regions are 404, a missing reason is 400; nothing written', async () => {
    const { svc, service } = setup();
    await expect(svc.setPaused(OWNER, 'rooms_enabled', 'south_asia', true, { reasonCode: 'x' })).rejects.toMatchObject({ status: 404 });
    await expect(svc.setPaused(OWNER, 'quiet_enabled', 'mars', true, { reasonCode: 'x' })).rejects.toMatchObject({ status: 404 });
    await expect(svc.setPaused(OWNER, 'quiet_enabled', 'south_asia', true, {})).rejects.toMatchObject({ code: 'invalid_request' });
    await expect(svc.setPaused(OWNER, 'quiet_enabled', 'south_asia', true, { reasonCode: 'x', extra: 1 })).rejects.toMatchObject({ code: 'invalid_request' });
    expect(service.txs).toHaveLength(0);
  });

  it('pausedRegionsOf tolerates junk payloads', () => {
    expect(pausedRegionsOf(null)).toEqual([]);
    expect(pausedRegionsOf({ pausedRegions: 'south_asia' })).toEqual([]);
    expect(pausedRegionsOf({ pausedRegions: ['south_asia', 'south_asia', 7, 'americas'] })).toEqual(['americas', 'south_asia']);
  });
});
