/**
 * Console actions and their audit rows (PRD 19 "Audit log", REQ-ADM-02, REQ-SAFE-08): every console change writes an
 * audit row in the SAME transaction as the change, refusals are audited, and moderation actions go through the
 * internal ModerationService with the staff actor and a reason code. Fakes record every SQL statement per transaction.
 */
import { AdminErrors } from '../../src/admin/admin-errors';
import type { AdminDb } from '../../src/admin/admin-db';
import type { StaffUser } from '../../src/admin/admin-types';
import { ConsoleConfigService } from '../../src/admin/console-config.service';
import type { GrievanceMail } from '../../src/admin/grievance-mail';
import { LegalOrdersService } from '../../src/admin/legal-orders.service';
import { ModerationConsoleService } from '../../src/admin/moderation-console.service';
import { PagingConsoleService } from '../../src/admin/paging-console.service';
import type { PagingService } from '../../src/admin/paging/paging.service';
import type { AppConfig } from '../../src/config/app-config';
import type { DbService } from '../../src/db/db.service';
import { ModerationError, type ModerationService } from '../../src/safety/moderation.service';

type Responder = (text: string, params: unknown[]) => { rows: unknown[]; rowCount?: number } | undefined;

class FakeTx {
  readonly calls: Array<{ text: string; params: unknown[] }> = [];
  constructor(private readonly responder: Responder) {}
  async query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    this.calls.push({ text, params });
    if (/insert into public\.moderation_actions/.test(text)) return { rows: [{ id: String(this.calls.length) }], rowCount: 1 };
    const r = this.responder(text, params) ?? { rows: [] };
    return { rows: r.rows, rowCount: r.rowCount ?? r.rows.length };
  }
  async savepoint<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
    return fn(this);
  }
  audits(): Array<{ actor: string; action: string; reportId: unknown; reasonCode: unknown; detail: Record<string, unknown> }> {
    return this.calls
      .filter((c) => /insert into public\.moderation_actions/.test(c.text))
      .map((c) => ({
        actor: c.params[0] as string,
        action: c.params[1] as string,
        reportId: c.params[2],
        reasonCode: c.params[4],
        detail: JSON.parse(c.params[5] as string) as Record<string, unknown>,
      }));
  }
}

class FakeAdminDb {
  readonly txs: FakeTx[] = [];
  constructor(private readonly responder: Responder = () => undefined) {}
  async withTx<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
    const tx = new FakeTx(this.responder);
    this.txs.push(tx);
    return fn(tx);
  }
  query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    return this.withTx((tx) => tx.query(text, params));
  }
  allAudits(): ReturnType<FakeTx['audits']> {
    return this.txs.flatMap((t) => t.audits());
  }
}

const staff = (role: StaffUser['role']): StaffUser => ({
  id: `0192f0c2-7a4e-7c1a-9b3d-00000000000${role === 'owner' ? 1 : 2}`,
  role,
  displayName: role,
  email: null,
  sessionId: '0192f0c2-7a4e-7c1a-9b3d-0000000000aa',
  sessionStartedAt: new Date().toISOString(),
  sessionExpiresAt: new Date(Date.now() + 3_600_000).toISOString(),
  mfa: 'verified',
  actor: `staff:0192f0c2-7a4e-7c1a-9b3d-00000000000${role === 'owner' ? 1 : 2}`,
});
const OWNER = staff('owner');
const MODERATOR = staff('moderator');
const REPORT = '0192f0c2-7a4e-7c1a-9b3d-0000000000r1'.replace('r1', 'f1');
const HOLD = '0192f0c2-7a4e-7c1a-9b3d-0000000000e1';
const APP = { masterKey: Buffer.alloc(32, 3) } as unknown as AppConfig;

function fakeModeration(): jest.Mocked<Pick<ModerationService, 'act' | 'liftSanction'>> {
  return {
    act: jest.fn().mockResolvedValue({ reportId: REPORT, status: 'actioned', sanctionId: 's1', strikeId: null, activeStrikes: null }),
    liftSanction: jest.fn().mockResolvedValue(undefined),
  };
}

describe('moderation actions from the console', () => {
  const reportRow: Responder = (text) =>
    /select lane, evidence_hold_id from public\.reports/.test(text) ? { rows: [{ lane: 'minors_grooming', evidence_hold_id: HOLD }] } : undefined;

  it('REQ-ADM-02: a Moderator cannot ban — 403, audited, and ModerationService is never called', async () => {
    const db = new FakeAdminDb(reportRow);
    const mod = fakeModeration();
    const svc = new ModerationConsoleService(db as unknown as AdminDb, mod as unknown as ModerationService, APP);
    await expect(svc.act(MODERATOR, REPORT, { action: 'ban', reasonCode: 'grooming' })).rejects.toMatchObject({ code: 'forbidden_role', status: 403 });
    expect(mod.act).not.toHaveBeenCalled();
    expect(db.allAudits()).toEqual([
      {
        actor: MODERATOR.actor,
        action: 'access_denied',
        reportId: REPORT,
        reasonCode: 'forbidden_role',
        detail: { route: 'POST /admin/reports/:id/actions', attempted: 'ban', role: 'moderator' },
      },
    ]);
  });

  it('a Moderator’s shadow-mute is capped at 7 days', async () => {
    const db = new FakeAdminDb(reportRow);
    const mod = fakeModeration();
    const svc = new ModerationConsoleService(db as unknown as AdminDb, mod as unknown as ModerationService, APP);
    await expect(svc.act(MODERATOR, REPORT, { action: 'shadow_mute', reasonCode: 'harassment', hours: 720 })).rejects.toMatchObject({ code: 'forbidden_role' });
    await svc.act(MODERATOR, REPORT, { action: 'shadow_mute', reasonCode: 'harassment', hours: 168 });
    expect(mod.act).toHaveBeenCalledWith({ reportId: REPORT, action: 'shadow_mute', actor: MODERATOR.actor, reasonCode: 'harassment', hours: 168 });
  });

  it('every action needs a reason code (the audit row carries it)', async () => {
    const svc = new ModerationConsoleService(new FakeAdminDb(reportRow) as unknown as AdminDb, fakeModeration() as unknown as ModerationService, APP);
    await expect(svc.act(OWNER, REPORT, { action: 'dismiss' })).rejects.toMatchObject({ code: 'invalid_request', status: 400 });
    await expect(svc.act(OWNER, REPORT, { action: 'dismiss', reasonCode: 'Not A Code' })).rejects.toMatchObject({ code: 'invalid_request' });
  });

  it('Owner ban in the minors lane: ModerationService.act (which writes the audit row), paging stops, SOP checklist opens', async () => {
    const db = new FakeAdminDb(reportRow);
    const mod = fakeModeration();
    const svc = new ModerationConsoleService(db as unknown as AdminDb, mod as unknown as ModerationService, APP);
    const out = await svc.act(OWNER, REPORT, { action: 'ban', reasonCode: 'grooming' });
    expect(mod.act).toHaveBeenCalledWith({ reportId: REPORT, action: 'ban', actor: OWNER.actor, reasonCode: 'grooming', hours: undefined });
    expect(out.mandatoryReport).toEqual({ evidenceHoldId: HOLD });
    const after = db.txs[db.txs.length - 1].calls.map((c) => c.text);
    expect(after.some((t) => /update public\.admin_pages set status = 'resolved'/.test(t))).toBe(true);
    expect(after.some((t) => /insert into public\.admin_mandatory_checklists/.test(t))).toBe(true);
  });

  it('ModerationService refusals become HTTP errors (crisis reports never strike → 409)', async () => {
    const mod = fakeModeration();
    mod.act.mockRejectedValueOnce(new ModerationError('crisis_never_strikes'));
    const svc = new ModerationConsoleService(new FakeAdminDb(reportRow) as unknown as AdminDb, mod as unknown as ModerationService, APP);
    await expect(svc.act(OWNER, REPORT, { action: 'strike', reasonCode: 'harassment' })).rejects.toMatchObject({ status: 409, code: 'crisis_never_strikes' });
  });

  it('unban (lifting a ban) is Owner-only and a Moderator’s attempt is audited', async () => {
    const db = new FakeAdminDb((text) =>
      /select kind, report_id from public\.sanctions/.test(text) ? { rows: [{ kind: 'account_ban', report_id: REPORT }] } : undefined,
    );
    const mod = fakeModeration();
    const svc = new ModerationConsoleService(db as unknown as AdminDb, mod as unknown as ModerationService, APP);
    await expect(svc.lift(MODERATOR, HOLD, { reasonCode: 'appeal_upheld' })).rejects.toMatchObject({ code: 'forbidden_role' });
    expect(mod.liftSanction).not.toHaveBeenCalled();
    expect(db.allAudits()[0]).toMatchObject({ action: 'access_denied', detail: { attempted: 'unban' } });
    await svc.lift(OWNER, HOLD, { reasonCode: 'appeal_upheld' });
    expect(mod.liftSanction).toHaveBeenCalledWith(HOLD, OWNER.actor, 'appeal_upheld');
  });

  it('checklist ticks and the break-glass export are audited in the same transaction as the change', async () => {
    const db = new FakeAdminDb((text) => {
      if (/select 1 from public\.evidence_holds/.test(text)) return { rows: [{ '?column?': 1 }] };
      if (/from public\.evidence_holds where id/.test(text)) {
        return {
          rows: [
            {
              id: HOLD,
              report_id: REPORT,
              item_kind: 'member',
              item_ref: null,
              reason: 'minors_grooming:contact_info',
              account_ids: ['0192f0c2-7a4e-7c1a-9b3d-0000000000c1'],
              snapshot: { report: { reporterMemberId: 'm-rep', note: 'x' }, members: [{ memberId: 'm-sub', accountId: '0192f0c2-7a4e-7c1a-9b3d-0000000000c1', pseudonym: 'Quiet Comet' }] },
              created_at: new Date(),
              hold_until: new Date(Date.now() + 180 * 86_400_000),
              mandatory_report_required: true,
              reported_to: null,
              report_ref: null,
              legal_reason: null,
            },
          ],
        };
      }
      return undefined;
    });
    const svc = new ModerationConsoleService(db as unknown as AdminDb, fakeModeration() as unknown as ModerationService, APP);
    await svc.setChecklistItem(OWNER, HOLD, { item: 'counsel_consulted', done: true });
    const tick = db.txs[db.txs.length - 1];
    expect(tick.calls.some((c) => /insert into public\.admin_mandatory_checklists/.test(c.text))).toBe(true);
    expect(tick.audits()).toEqual([expect.objectContaining({ actor: OWNER.actor, action: 'mandatory_checklist', reasonCode: 'counsel_consulted' })]);

    const out = await svc.exportEvidence(OWNER, HOLD, { purpose: 'mandatory_report' });
    const exp = db.txs[db.txs.length - 1];
    expect(exp.audits()).toEqual([
      expect.objectContaining({ action: 'evidence_export', reasonCode: 'mandatory_report', detail: expect.objectContaining({ sha256: out.bundle.integrity.canonicalJsonSha256 }) }),
    ]);
    // Break-glass carries the subject's account id but never the reporter.
    expect(JSON.stringify(out.bundle)).toContain('0192f0c2-7a4e-7c1a-9b3d-0000000000c1');
    expect(JSON.stringify(out.bundle)).not.toContain('m-rep');
    await expect(svc.exportEvidence(OWNER, HOLD, { purpose: 'curiosity' })).rejects.toMatchObject({ code: 'invalid_request' });
  });
});

describe('other console changes write their audit row in the same transaction', () => {
  it('flipping a kill switch: update + audit (reason, previous value) together', async () => {
    const db = new FakeAdminDb((text) => (/select enabled from public\.feature_flags/.test(text) ? { rows: [{ enabled: false }] } : undefined));
    const svc = new ConsoleConfigService(db as unknown as AdminDb, {} as ModerationService);
    await expect(svc.setFlag(OWNER, 'rooms_pool_hi', { enabled: true, reasonCode: 'hindi_moderation_ready' })).resolves.toEqual({ key: 'rooms_pool_hi', enabled: true });
    const tx = db.txs[0];
    expect(tx.calls.map((c) => c.text).some((t) => /update public\.feature_flags set enabled/.test(t))).toBe(true);
    expect(tx.audits()).toEqual([
      { actor: OWNER.actor, action: 'config_flag', reportId: null, reasonCode: 'hindi_moderation_ready', detail: { key: 'rooms_pool_hi', enabled: true, previous: false } },
    ]);
    await expect(svc.setFlag(OWNER, 'rooms_pool_hi', { enabled: true })).rejects.toMatchObject({ code: 'invalid_request' });
  });

  it('acknowledging a legal-order page also acknowledges the order, audited', async () => {
    const PAGE = '0192f0c2-7a4e-7c1a-9b3d-0000000000p1'.replace('p1', 'a1');
    const ORDER = '0192f0c2-7a4e-7c1a-9b3d-0000000000b1';
    const db = new FakeAdminDb((text) => {
      if (/update public\.admin_pages set status = 'acknowledged'/.test(text)) return { rows: [{ kind: 'legal_order', ref_id: ORDER, reason: 'legal_order' }] };
      if (/from public\.admin_pages p/.test(text)) {
        return {
          rows: [
            {
              id: PAGE,
              kind: 'legal_order',
              ref_id: ORDER,
              reason: 'legal_order',
              lane: null,
              minor_involved: false,
              is_test: true,
              due_at: new Date(),
              status: 'acknowledged',
              round: 1,
              escalation_level: 0,
              next_attempt_at: new Date(),
              last_delivered_at: new Date(),
              acknowledged_at: new Date(),
              acknowledged_by: OWNER.actor,
              created_at: new Date(),
              ticket: 'LO-00000001',
              total: 2,
              ok: 2,
              last_error: null,
            },
          ],
        };
      }
      return undefined;
    });
    const svc = new PagingConsoleService(db as unknown as AdminDb, {} as PagingService, {} as never, {} as GrievanceMail);
    const view = await svc.acknowledge(OWNER, PAGE);
    expect(view.status).toBe('acknowledged');
    const tx = db.txs[0];
    expect(tx.calls.some((c) => /update public\.admin_legal_orders set status = 'acknowledged'/.test(c.text))).toBe(true);
    expect(tx.audits()).toEqual([expect.objectContaining({ actor: OWNER.actor, action: 'page_acknowledged', reasonCode: 'legal_order' })]);
  });

  it('closing a legal order stops its page and is audited with whether it met the 3 h deadline', async () => {
    const ORDER = '0192f0c2-7a4e-7c1a-9b3d-0000000000b2';
    const db = new FakeAdminDb((text) => {
      if (/update public\.admin_legal_orders\s+set status = \$2/.test(text)) return { rows: [{ ticket: 'LO-00000002', overdue: false }] };
      if (/select \* from public\.admin_legal_orders where id/.test(text)) {
        return {
          rows: [
            {
              id: ORDER,
              ticket: 'LO-00000002',
              source: 'government',
              authority: 'Test',
              reference: null,
              received_at: new Date(),
              due_at: new Date(Date.now() + 3_600_000),
              summary: 'x',
              targets: null,
              intake_channel: 'console',
              is_test: true,
              status: 'actioned',
              acknowledged_at: new Date(),
              acknowledged_by: OWNER.actor,
              closed_at: new Date(),
              closed_by: OWNER.actor,
              resolution_note: 'Removed',
              created_by: OWNER.actor,
              created_at: new Date(),
            },
          ],
        };
      }
      return undefined;
    });
    const svc = new LegalOrdersService({} as DbService, db as unknown as AdminDb, {} as PagingService);
    await svc.close(OWNER, ORDER, { status: 'actioned', note: 'Content removed at 03:10 IST' });
    const tx = db.txs[0];
    expect(tx.calls.some((c) => /update public\.admin_pages set status = 'resolved'/.test(c.text))).toBe(true);
    expect(tx.audits()).toEqual([
      expect.objectContaining({ action: 'legal_order_closed', reasonCode: 'actioned', detail: { legalOrderId: ORDER, ticket: 'LO-00000002', withinDeadline: true } }),
    ]);
    expect(AdminErrors.notFound().status).toBe(404);
  });
});
