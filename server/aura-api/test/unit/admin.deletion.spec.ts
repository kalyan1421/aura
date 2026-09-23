/**
 * REQ-ADM-11 deletion cases, service side: the one-time link goes to the address the DATABASE returns for the matched
 * account (never the address typed from the request), carries only a random token (the database keeps its SHA-256),
 * and no personal data ever reaches a URL, the audit log or the console; the public page changes nothing on GET and
 * only POSTs act; only a verified case can start the app's deletion (7-day grace, or immediate with a reason).
 */
import { AdminErrors, consoleRefusal } from '../../src/admin/admin-errors';
import type { AdminConfig } from '../../src/admin/admin-config';
import { parseAdminConfig } from '../../src/admin/admin-config';
import type { AdminDb } from '../../src/admin/admin-db';
import type { StaffUser } from '../../src/admin/admin-types';
import { deletionPage } from '../../src/admin/deletion-cases.controller';
import { DeletionCasesService, LINK_TOKEN_RE, newLinkToken, tokenHash } from '../../src/admin/deletion-cases.service';
import type { Mailer, MailMessage } from '../../src/admin/mail/mailer';
import { deletionVerificationMail } from '../../src/admin/mail/templates';
import type { AppConfig } from '../../src/config/app-config';
import type { DbService } from '../../src/db/db.service';

const OWNER = { id: '0192f0c2-7a4e-7c1a-9b3d-000000000001', actor: 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001', role: 'owner' } as StaffUser;
const CASE = '0192f0c2-7a4e-7c1a-9b3d-0000000000ca';
const ACCOUNT = '0192f0c2-7a4e-7c1a-9b3d-0000000000ac';
const APP = { masterKey: Buffer.alloc(32, 5) } as unknown as AppConfig;

type Row = Record<string, unknown>;

class FakeTx {
  constructor(
    private readonly log: Array<{ text: string; params: unknown[] }>,
    private readonly respond: (text: string, params: unknown[]) => Row[],
  ) {}
  async query(text: string, params: unknown[] = []): Promise<{ rows: Row[]; rowCount: number }> {
    this.log.push({ text, params });
    if (/insert into public\.moderation_actions/.test(text)) return { rows: [{ id: '1' }], rowCount: 1 };
    const rows = this.respond(text, params);
    return { rows, rowCount: rows.length };
  }
  async savepoint<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
    return fn(this);
  }
}

function caseRow(over: Row = {}): Row {
  return {
    id: CASE,
    ticket: 'DEL-7K3F9Q2M',
    channel: 'email',
    grievance_id: null,
    grievance_ticket: null,
    received_at: new Date(),
    status: 'awaiting_verification',
    account_id: ACCOUNT,
    account_email_masked: 'r•••@example.test',
    token_expires_at: new Date(Date.now() + 72 * 3_600_000),
    verification_sent_at: null,
    verification_attempts: 0,
    verified_at: null,
    declined_at: null,
    deletion_mode: null,
    deletion_reason: null,
    deletion_requested_at: null,
    deletion_requested_by: null,
    deletion_scheduled_for: null,
    deletion_pending: false,
    completed_at: null,
    held_records: 2,
    held_until: new Date(Date.now() + 100 * 86_400_000),
    closed_at: null,
    closed_by: null,
    close_outcome: null,
    created_by: OWNER.actor,
    created_at: new Date(),
    updated_at: new Date(),
    ...over,
  };
}

function build(respond: (text: string, params: unknown[]) => Row[], config: AdminConfig = parseAdminConfig({ PUBLIC_API_URL: 'https://api.aura.test' })) {
  const log: Array<{ text: string; params: unknown[] }> = [];
  const adminDb = {
    withTx: async <T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> => fn(new FakeTx(log, respond)),
    query: async (text: string, params: unknown[] = []) => new FakeTx(log, respond).query(text, params),
  } as unknown as AdminDb;
  const sent: MailMessage[] = [];
  const mailer: Mailer = { enabled: true, send: async (m) => void sent.push(m) };
  const svc = new DeletionCasesService(adminDb, {} as DbService, config, APP, mailer);
  const audits = () => log.filter((c) => /insert into public\.moderation_actions/.test(c.text)).map((c) => ({ action: c.params[1], detail: JSON.parse(c.params[5] as string) as Row, subject: c.params[3] }));
  return { svc, log, sent, audits };
}

describe('link tokens', () => {
  it('32 random bytes, base64url; only the SHA-256 is stored', () => {
    const a = newLinkToken();
    expect(a).toMatch(LINK_TOKEN_RE);
    expect(newLinkToken()).not.toBe(a);
    expect(tokenHash(a)).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('opening a case', () => {
  it('sends the link to the address ON THE ACCOUNT (from the database), never to the typed one; audited without the email', async () => {
    const { svc, log, sent, audits } = build((text) => {
      if (/admin_deletion_case_open/.test(text)) return [{ case_id: CASE, status: 'awaiting_verification', account_id: ACCOUNT, send_to: 'Real.Holder@Example.test' }];
      if (/admin_deletion_cases_list/.test(text)) return [caseRow()];
      return [];
    });
    const out = await svc.open(OWNER, { email: 'real.holder@example.test', channel: 'email', receivedAt: new Date(Date.now() - 3_600_000).toISOString() });
    expect(out).toMatchObject({ caseId: CASE, status: 'awaiting_verification', linkEmailed: true, accountEmailMasked: 'r•••@example.test' });
    expect(sent).toHaveLength(1);
    expect(sent[0].to).toEqual(['Real.Holder@Example.test']);
    const link = /https:\/\/api\.aura\.test\/v1\/deletion-requests\/([A-Za-z0-9_-]{43})/.exec(sent[0].text);
    expect(link).not.toBeNull();
    // The database got the token's hash, never the token; the URL carries nothing personal.
    const open = log.find((c) => /admin_deletion_case_open/.test(c.text));
    expect(open?.params[5]).toBe(tokenHash((link as RegExpExecArray)[1]));
    expect(JSON.stringify(open?.params)).not.toContain((link as RegExpExecArray)[1]);
    expect((link as RegExpExecArray)[0]).not.toMatch(/holder|example|%40|@/i);
    // Audited (opened + link sent), with an HMAC subject and never the email or the account id.
    expect(audits().map((a) => a.action)).toEqual(['deletion_case_opened', 'deletion_link_sent']);
    expect(audits()[0].subject).toMatch(/^[0-9a-f]{64}$/);
    const blob = JSON.stringify(audits()) + JSON.stringify(out);
    expect(blob).not.toMatch(/holder@|Real\.Holder/i);
    expect(blob).not.toContain(ACCOUNT);
  });

  it('no app account (or a staff account) → nothing is sent', async () => {
    const { svc, sent } = build((text) => {
      if (/admin_deletion_case_open/.test(text)) return [{ case_id: CASE, status: 'no_account', account_id: null, send_to: null }];
      if (/admin_deletion_cases_list/.test(text)) return [caseRow({ status: 'no_account', account_id: null, account_email_masked: null, closed_at: new Date() })];
      return [];
    });
    const out = await svc.open(OWNER, { email: 'nobody@example.test', channel: 'email', receivedAt: new Date().toISOString() });
    expect(out).toMatchObject({ status: 'no_account', linkEmailed: null, subjectHash: null });
    expect(sent).toEqual([]);
  });

  it('validates the request (email, channel, receipt time not in the future)', async () => {
    const { svc } = build(() => []);
    await expect(svc.open(OWNER, { email: 'x', channel: 'email', receivedAt: new Date().toISOString() })).rejects.toMatchObject({ code: 'invalid_request' });
    await expect(svc.open(OWNER, { email: 'a@b.test', channel: 'sms', receivedAt: new Date().toISOString() })).rejects.toMatchObject({ code: 'invalid_request' });
    await expect(
      svc.open(OWNER, { email: 'a@b.test', channel: 'email', receivedAt: new Date(Date.now() + 3_600_000).toISOString() }),
    ).rejects.toMatchObject({ code: 'invalid_request' });
  });
});

describe('starting the deletion', () => {
  it('grace: the app’s 7-day schedule; immediate: now, with one of the audited reasons', async () => {
    const { svc, log, audits } = build((text) => {
      if (/admin_deletion_case_schedule/.test(text)) return [{ account_id: ACCOUNT, scheduled_for: new Date(Date.now() + 7 * 86_400_000) }];
      if (/admin_deletion_cases_list/.test(text)) return [caseRow({ status: 'deletion_scheduled' })];
      return [];
    });
    await svc.startDeletion(OWNER, CASE, { mode: 'grace' });
    const grace = log.find((c) => /admin_deletion_case_schedule/.test(c.text))?.params as unknown[];
    expect(grace[1]).toBe(false);
    expect(Math.abs((grace[2] as Date).getTime() - (Date.now() + 7 * 86_400_000))).toBeLessThan(5_000);
    expect(grace[3]).toBeNull();
    expect(audits().map((a) => a.action)).toEqual(['deletion_scheduled']);

    await svc.startDeletion(OWNER, CASE, { mode: 'immediate', reasonCode: 'under_13_confirmed' });
    const imm = log.filter((c) => /admin_deletion_case_schedule/.test(c.text))[1].params;
    expect(imm.slice(1, 4)).toEqual([true, null, 'under_13_confirmed']);
    await expect(svc.startDeletion(OWNER, CASE, { mode: 'immediate' })).rejects.toMatchObject({ code: 'invalid_request' });
    await expect(svc.startDeletion(OWNER, CASE, { mode: 'immediate', reasonCode: 'because' })).rejects.toMatchObject({ code: 'invalid_request' });
  });

  it('the database refusals become clear HTTP errors (nothing is deleted before the holder confirms)', () => {
    const e = consoleRefusal(Object.assign(new Error('case_not_verified'), { code: 'AR040' }));
    expect(e).toMatchObject({ status: 409, code: 'case_not_verified' });
    expect(consoleRefusal(Object.assign(new Error('forbidden_role'), { code: 'AR040' }))).toMatchObject({ status: 403 });
    expect(consoleRefusal(Object.assign(new Error('something_new'), { code: 'AR040' }))).toMatchObject({ status: 400, code: 'invalid_request' });
    const other = new Error('boom');
    expect(consoleRefusal(other)).toBe(other);
    expect(AdminErrors.notFound().status).toBe(404);
  });
});

describe('the account holder’s page and email', () => {
  it('GET shows a choice (two POST forms, relative actions, no script); results carry the ticket only', () => {
    const token = newLinkToken();
    const ask = deletionPage('ask', 'DEL-7K3F9Q2M', token);
    expect(ask).toContain(`<form method="post" action="${token}/confirm">`);
    expect(ask).toContain(`<form method="post" action="${token}/decline">`);
    expect(ask).not.toMatch(/<script|https?:\/\//i);
    for (const k of ['verified', 'declined', 'expired', 'invalid', 'limited'] as const) {
      const page = deletionPage(k, 'DEL-7K3F9Q2M');
      expect(page).not.toContain('<form');
      expect(page).not.toContain(token);
    }
    expect(deletionPage('verified', '<b>x</b>')).toContain('&lt;b&gt;x&lt;/b&gt;');
  });

  it('the confirmation route refuses malformed tokens without touching the database', async () => {
    const db = { withTx: jest.fn(), query: jest.fn() } as unknown as DbService;
    const svc = new DeletionCasesService({} as AdminDb, db, parseAdminConfig({}), APP, { enabled: false, send: jest.fn() });
    expect(await svc.confirm('not-a-token', false)).toEqual({ outcome: 'invalid', ticket: null });
    expect(await svc.lookup('../../etc/passwd')).toEqual({ state: 'invalid', ticket: null });
    expect((db as unknown as { withTx: jest.Mock }).withTx).not.toHaveBeenCalled();
  });

  it('the email explains what happens and that nothing is deleted without confirmation', () => {
    const m = deletionVerificationMail(
      { ticket: 'DEL-7K3F9Q2M', link: 'https://api.aura.test/v1/deletion-requests/abc', expiresAt: new Date('2026-10-12T12:00:00Z'), graceDays: 7 },
      { name: 'AK (Grievance Officer)', email: 'grievance@akvega.test', address: null },
    );
    expect(m.subject).toContain('DEL-7K3F9Q2M');
    expect(m.text).toContain('https://api.aura.test/v1/deletion-requests/abc');
    expect(m.text).toContain('nothing is deleted without your confirmation');
    expect(m.text).toContain('within 30 days');
  });
});
