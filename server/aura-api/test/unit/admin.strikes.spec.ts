/**
 * REQ-ADM-07 strike automation and REQ-ADM-03 least privilege in ModerationService (the internal API the console
 * wraps): every query runs in an aura_admin transaction (AdminDb), state changes go through the migration-16 definer
 * functions, the 4th active strike bans automatically (audited as system:strike_ladder, evidence held 180 days from the
 * ban), a crisis-flagged item never strikes, and the queue never touches auth.users or the reporter's identity.
 * The database is a fake that answers each statement by pattern and records it.
 */
import { AdminDb } from '../../src/admin/admin-db';
import type { AppConfig } from '../../src/config/app-config';
import type { DbService } from '../../src/db/db.service';
import { ModerationError, ModerationService, STRIKE_LADDER_ACTOR } from '../../src/safety/moderation.service';

type Row = Record<string, unknown>;
type Responder = (text: string, params: unknown[]) => Row[] | Error | undefined;

class FakeTx {
  readonly calls: Array<{ text: string; params: unknown[] }> = [];
  constructor(private readonly responder: Responder) {}
  async query(text: string, params: unknown[] = []): Promise<{ rows: Row[]; rowCount: number }> {
    this.calls.push({ text, params });
    if (/insert into public\.moderation_actions/.test(text)) return { rows: [{ id: String(this.calls.length) }], rowCount: 1 };
    const r = this.responder(text, params);
    if (r instanceof Error) throw r;
    return { rows: r ?? [], rowCount: (r ?? []).length };
  }
  audits(): Array<{ actor: string; action: string; reasonCode: unknown; detail: Row }> {
    return this.calls
      .filter((c) => /insert into public\.moderation_actions/.test(c.text))
      .map((c) => ({ actor: c.params[0] as string, action: c.params[1] as string, reasonCode: c.params[4], detail: JSON.parse(c.params[5] as string) as Row }));
  }
  called(re: RegExp): Array<{ text: string; params: unknown[] }> {
    return this.calls.filter((c) => re.test(c.text));
  }
}

/** The real AdminDb over a fake DbService: proves every transaction switches to aura_admin first. */
function adminDbWith(responder: Responder): { adminDb: AdminDb; txs: FakeTx[] } {
  const txs: FakeTx[] = [];
  const db = {
    async withTx<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
      const tx = new FakeTx(responder);
      txs.push(tx);
      return fn(tx);
    },
  } as unknown as DbService;
  return { adminDb: new AdminDb(db), txs };
}

const APP = { masterKey: Buffer.alloc(32, 9) } as unknown as AppConfig;
const REPORT = '0192f0c2-7a4e-7c1a-9b3d-0000000000f1';
const SUBJECT = '0192f0c2-7a4e-7c1a-9b3d-0000000000c1';
const HOLD = '0192f0c2-7a4e-7c1a-9b3d-0000000000e1';
const STAFF = 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001';

const report = (over: Row = {}): Row => ({
  report_id: REPORT,
  status: 'open',
  lane: 'harassment',
  reason: 2,
  target_user_id: SUBJECT,
  evidence_hold_id: HOLD,
  crisis_flagged: false,
  ...over,
});

function responder(opts: { report?: Row; activeStrikes?: number; banned?: boolean; holds?: string[]; strikeError?: Error; installs?: string[] }): Responder {
  return (text) => {
    if (/admin_report_for_action/.test(text)) return [opts.report ?? report()];
    if (/from public\.safety_config/.test(text)) return [{ report_daily_limit: 20, under13_reports_to_pause: 2, evidence_hold_days: 180, strike_ttl_days: 90 }];
    if (/admin_add_strike/.test(text)) return opts.strikeError ?? [{ strike_id: 'strike-1', active_strikes: opts.activeStrikes ?? 1 }];
    if (/kind in \('social_ban','account_ban'\)/.test(text)) return opts.banned ? [{ '?column?': 1 }] : [];
    if (/admin_add_sanction/.test(text)) return [{ id: 'sanction-1' }];
    if (/distinct r\.evidence_hold_id/.test(text)) return (opts.holds ?? [HOLD]).map((id) => ({ id }));
    if (/admin_hide_account_from_rooms/.test(text)) return [{ n: 1 }];
    if (/select install_hash from public\.device_installs/.test(text)) return (opts.installs ?? []).map((install_hash) => ({ install_hash }));
    if (/insert into public\.device_bans/.test(text)) return (opts.installs ?? []).map((install_hash) => ({ install_hash }));
    if (/update public\.evidence_holds/.test(text)) return [{}];
    return [];
  };
}

describe('every ModerationService query runs as aura_admin', () => {
  it('each transaction starts with SET LOCAL ROLE aura_admin', async () => {
    const { adminDb, txs } = adminDbWith(responder({}));
    const mod = new ModerationService(adminDb, APP);
    await mod.act({ reportId: REPORT, action: 'dismiss', actor: STAFF });
    await mod.listQueue();
    await mod.pendingMandatoryReports();
    expect(txs.length).toBeGreaterThanOrEqual(3);
    for (const tx of txs) expect(tx.calls[0].text).toBe('set local role aura_admin');
  });

  it('REQ-ADM-03: the queue reads no auth.users and no reporter identity; account age comes from the definer function', async () => {
    const { adminDb, txs } = adminDbWith(() => []);
    await new ModerationService(adminDb, APP).listQueue({ limit: 5 });
    const sql = txs[0].calls[1].text;
    expect(sql).not.toMatch(/auth\.users/);
    expect(sql).not.toMatch(/reporter_user_id/);
    expect(sql).toMatch(/public\.admin_account_age_days\(r\.target_user_id\)/);
  });

  it('no direct write: state changes only through the definer functions', async () => {
    const { adminDb, txs } = adminDbWith(responder({ activeStrikes: 3 }));
    await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF, reasonCode: 'harassment' });
    const writes = txs[0].calls.map((c) => c.text).filter((t) => /^\s*(insert|update|delete)/i.test(t));
    expect(writes.every((t) => /insert into public\.moderation_actions/.test(t))).toBe(true);
  });
});

describe('REQ-ADM-07 strike ladder', () => {
  it('strikes 1–3: warning → 24 h shadow-mute → 7-day room suspension, applied by the striking moderator', async () => {
    const cases: Array<[number, string, number | null]> = [
      [1, 'warning', null],
      [2, 'shadow_mute', 24],
      [3, 'room_suspension', 168],
    ];
    for (const [n, kind, hours] of cases) {
      const { adminDb, txs } = adminDbWith(responder({ activeStrikes: n }));
      const out = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF, reasonCode: 'harassment' });
      expect(out).toMatchObject({ status: 'actioned', activeStrikes: n, strikeId: 'strike-1', sanctionId: 'sanction-1', autoBan: null });
      const sanction = txs[0].called(/admin_add_sanction/)[0].params;
      expect(sanction).toEqual([REPORT, kind, 'harassment', hours, STAFF, 'moderator']);
      expect(txs[0].audits().map((a) => a.action)).toEqual(['strike']);
    }
  });

  it('the 4th active strike bans automatically: permanent social ban, audited as the ladder, evidence ≥ 180 days, rooms told', async () => {
    const { adminDb, txs } = adminDbWith(responder({ activeStrikes: 4, holds: [HOLD, '0192f0c2-7a4e-7c1a-9b3d-0000000000e2'] }));
    const out = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF, reasonCode: 'harassment' });
    expect(out).toMatchObject({ status: 'actioned', activeStrikes: 4, sanctionId: 'sanction-1', autoBan: { sanctionId: 'sanction-1', alreadyBanned: false, evidenceHolds: 2 } });
    const tx = txs[0];
    expect(tx.called(/admin_add_sanction/)[0].params).toEqual([REPORT, 'social_ban', 'harassment', null, STAFF, 'auto']);
    expect(tx.called(/admin_extend_evidence_hold/).map((c) => c.params)).toEqual([
      [HOLD, 180],
      ['0192f0c2-7a4e-7c1a-9b3d-0000000000e2', 180],
    ]);
    const audits = tx.audits();
    expect(audits.map((a) => [a.actor, a.action])).toEqual([
      [STAFF, 'strike'],
      [STRIKE_LADDER_ACTOR, 'auto_strike_ban'],
    ]);
    expect(audits[1]).toMatchObject({ reasonCode: 'fourth_active_strike', detail: { activeStrikes: 4, sanction: 'social_ban', evidenceHolds: 2, holdDays: 180 } });
    expect(JSON.stringify(audits)).not.toContain(SUBJECT); // an HMAC, never the account id
    expect(tx.called(/admin_hide_account_from_rooms/)).toHaveLength(1);
  });

  it('a 5th strike on an account already banned adds the strike but never a second ban', async () => {
    const { adminDb, txs } = adminDbWith(responder({ activeStrikes: 5, banned: true }));
    const out = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF, reasonCode: 'harassment' });
    expect(out).toMatchObject({ activeStrikes: 5, sanctionId: null, autoBan: { alreadyBanned: true } });
    expect(txs[0].called(/admin_add_sanction/)).toHaveLength(0);
    expect(txs[0].called(/admin_hide_account_from_rooms/)).toHaveLength(0);
  });

  it('REQ-ADM-07 negative: a crisis-flagged item never adds a strike (checked before any write)', async () => {
    for (const r of [report({ crisis_flagged: true }), report({ lane: 'crisis', reason: 1 })]) {
      const { adminDb, txs } = adminDbWith(responder({ report: r }));
      await expect(new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF })).rejects.toMatchObject({
        code: 'crisis_never_strikes',
      });
      expect(txs[0].called(/admin_add_strike/)).toHaveLength(0);
      expect(txs[0].audits()).toEqual([]);
    }
  });

  it('the database refusal (strikes_never_crisis, SQLSTATE AR040) surfaces as the same ModerationError', async () => {
    const refusal = Object.assign(new Error('crisis_never_strikes'), { code: 'AR040' });
    const { adminDb } = adminDbWith(responder({ strikeError: refusal }));
    const err = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'strike', actor: STAFF }).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ModerationError);
    expect(err).toMatchObject({ code: 'crisis_never_strikes' });
  });

  it('the minors & grooming ban keeps its evidence 180 days from the ban and marks the mandatory report', async () => {
    const { adminDb, txs } = adminDbWith(responder({ report: report({ lane: 'minors_grooming', reason: 5 }) }));
    await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'ban', actor: STAFF, reasonCode: 'grooming' });
    expect(txs[0].called(/admin_extend_evidence_hold/)[0]).toMatchObject({ text: expect.stringContaining('$2, true'), params: [HOLD, 180] });
    expect(txs[0].called(/admin_add_sanction/)[0].params).toEqual([REPORT, 'account_ban', 'grooming', null, STAFF, 'moderator']);
  });

  it('REQ-ADM-14: the account ban also bans every install of the account and snapshots their HMACs, in the same transaction', async () => {
    const installs = ['a'.repeat(64), 'b'.repeat(64)];
    const { adminDb, txs } = adminDbWith(responder({ report: report({ lane: 'minors_grooming', reason: 5 }), installs }));
    const out = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action: 'ban', actor: STAFF, reasonCode: 'grooming' }, new Date('2026-10-12T10:00:00Z'));
    expect(out.devices).toEqual({ devices: 2, newlyBanned: 2, snapshotted: true });
    expect(txs).toHaveLength(1);
    const texts = txs[0].calls.map((c) => c.text);
    const off = texts.indexOf('set local role none');
    const back = texts.lastIndexOf('set local role aura_admin');
    const ban = texts.findIndex((t) => /insert into public\.device_bans/.test(t));
    const snap = texts.findIndex((t) => /update public\.evidence_holds/.test(t));
    // Only the device step leaves aura_admin (its tables are the devices module's), and it comes straight back.
    expect(off).toBeGreaterThan(0);
    expect(off).toBeLessThan(ban);
    expect(ban).toBeLessThan(snap);
    expect(snap).toBeLessThan(back);
    expect(texts.slice(back).some((t) => /admin_resolve_report/.test(t))).toBe(true);
    expect(txs[0].called(/insert into public\.device_bans/)[0].params).toEqual([SUBJECT, 'grooming', expect.stringMatching(/^[0-9a-f]{64}$/), REPORT, STAFF]);
    // HMACs only: the snapshot gets the install hashes, never an install id or the account id.
    expect(txs[0].called(/update public\.evidence_holds/)[0].params).toEqual([HOLD, installs, '2026-10-12T10:00:00.000Z']);
    expect(txs[0].audits().map((a) => a.action)).toEqual(['device_ban', 'ban']);
    expect(txs[0].audits()[0]).toMatchObject({ actor: STAFF, reasonCode: 'grooming', detail: { scope: 'account', devices: 2, newlyBanned: 2 } });
  });

  it('negative: warnings, strikes and the 4th-strike social ban never ban devices', async () => {
    for (const [action, activeStrikes] of [['warn', 1], ['strike', 4]] as const) {
      const { adminDb, txs } = adminDbWith(responder({ activeStrikes, installs: ['c'.repeat(64)] }));
      const out = await new ModerationService(adminDb, APP).act({ reportId: REPORT, action, actor: STAFF, reasonCode: 'harassment' });
      expect(out.devices).toBeNull();
      expect(txs[0].called(/device_bans|device_installs|set local role none/)).toHaveLength(0);
    }
  });

  it('closed or unknown reports and bad input are refused', async () => {
    const closed = adminDbWith(responder({ report: report({ status: 'actioned' }) }));
    await expect(new ModerationService(closed.adminDb, APP).act({ reportId: REPORT, action: 'warn', actor: STAFF })).rejects.toMatchObject({ code: 'report_closed' });
    const none = adminDbWith(() => []);
    await expect(new ModerationService(none.adminDb, APP).act({ reportId: REPORT, action: 'warn', actor: STAFF })).rejects.toMatchObject({ code: 'report_not_found' });
    await expect(new ModerationService(none.adminDb, APP).act({ reportId: REPORT, action: 'warn', actor: STAFF, reasonCode: 'Bad Code' })).rejects.toMatchObject({
      code: 'invalid_input',
    });
  });
});
