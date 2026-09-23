import { createHash, randomBytes } from 'node:crypto';
import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { deletionDateFor, DELETION_GRACE_DAYS } from '../account/account.schema';
import { REQUEST_REVOKE_TIMEOUT_MS } from '../account/account.service';
import { AppleTokenVault } from '../account/apple-tokens';
import { AppConfig } from '../config/app-config';
import { pgCode, pgConstraint, type Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { subjectHash } from '../safety/audit';
import { auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { AdminErrors, consoleRefusal } from './admin-errors';
import { deletionCaseSchema, deletionCloseSchema, deletionListSchema, deletionScheduleSchema, parse } from './admin.schemas';
import type { StaffUser } from './admin-types';
import { newTicket } from './grievances.service';
import { MAILER, mailErrorCode, type Mailer } from './mail/mailer';
import { deletionVerificationMail } from './mail/templates';

/**
 * Deletion cases (PRD 19 "Grievances and deletion", REQ-ADM-11): "Emailed or grievance requests are verified via a
 * magic link to the account email; data deleted within 30 days, except records the law requires (hashed audit rows,
 * evidence holds)."
 *
 * How nobody can delete someone else's account:
 *  1. the Owner types the address the request names; the database matches it to an app account (never a staff account)
 *     and returns the address stored ON THE ACCOUNT — the one-time link goes there, never to whoever wrote in;
 *  2. the link carries only a random 256-bit token (no personal data in any URL); the database keeps its SHA-256,
 *     it expires (`DELETION_LINK_TTL_HOURS`), works once, and dies if the account's email changes meanwhile;
 *  3. opening the link changes nothing (mail scanners open links): the holder must press "Delete my account" (a POST);
 *     "This wasn't me" declines the case;
 *  4. only that public route (service role) can mark a case verified — the console's `aura_admin` role cannot — and only a
 *     verified case can start the deletion (both enforced in the database, migration 20261005000016);
 *  5. the deletion is the app's own: deactivated at once, purged by the hourly job after the 7-day grace (sign-in +
 *     "Keep my account" still restores it) — or at the next hourly run for an immediate one with an audited reason;
 *  6. every step is audited (HMAC subject, ticket, never the email); evidence holds about the account survive the purge
 *     until `hold_until` (LEGAL_HOLD_TABLES), and the case records how many.
 * The console only ever sees a masked address ("a•••@example.com") and a hashed account id.
 */
export type DeletionCaseStatus =
  | 'awaiting_verification'
  | 'verified'
  | 'declined'
  | 'deletion_scheduled'
  | 'completed'
  | 'closed'
  | 'no_account'
  | 'staff_account';

export interface DeletionCaseView {
  caseId: string;
  ticket: string;
  channel: string;
  grievanceId: string | null;
  grievanceTicket: string | null;
  receivedAt: string;
  status: DeletionCaseStatus;
  /** Masked while the account exists (e.g. `a•••@example.com`); null once it is gone or never matched. */
  accountEmailMasked: string | null;
  /** HMAC of the account id (the audit log's subject hash), to cross-reference moderation history. */
  subjectHash: string | null;
  verification: { sentAt: string | null; expiresAt: string | null; attempts: number; verifiedAt: string | null; declinedAt: string | null };
  deletion: {
    mode: 'grace' | 'immediate';
    reasonCode: string | null;
    requestedAt: string;
    requestedBy: string | null;
    scheduledFor: string | null;
    /** An account_deletions row still exists (false after "Keep my account" or once purged). */
    pending: boolean;
  } | null;
  /** Evidence rows about the account under legal hold (kept past the deletion until hold_until). */
  legalHold: { records: number; until: string | null };
  completedAt: string | null;
  closedAt: string | null;
  closedBy: string | null;
  closeOutcome: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  allowed: { resend: boolean; startDeletion: boolean; close: boolean };
}

interface CaseRow {
  id: string;
  ticket: string;
  channel: string;
  grievance_id: string | null;
  grievance_ticket: string | null;
  received_at: Date;
  status: DeletionCaseStatus;
  account_id: string | null;
  account_email_masked: string | null;
  token_expires_at: Date | null;
  verification_sent_at: Date | null;
  verification_attempts: number;
  verified_at: Date | null;
  declined_at: Date | null;
  deletion_mode: 'grace' | 'immediate' | null;
  deletion_reason: string | null;
  deletion_requested_at: Date | null;
  deletion_requested_by: string | null;
  deletion_scheduled_for: Date | null;
  deletion_pending: boolean;
  completed_at: Date | null;
  held_records: number | null;
  held_until: Date | null;
  closed_at: Date | null;
  closed_by: string | null;
  close_outcome: string | null;
  created_by: string;
  created_at: Date;
  updated_at: Date;
}

/** Link tokens: 32 random bytes, base64url (43 characters). Only their SHA-256 is stored. */
export const LINK_TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;
export const newLinkToken = (): string => randomBytes(32).toString('base64url');
export const tokenHash = (token: string): string => createHash('sha256').update(token, 'utf8').digest('hex');

/** The public actor of the confirmation link in the audit log. */
export const DELETION_LINK_ACTOR = 'public:deletion_link';

const iso = (d: Date | null): string | null => (d ? d.toISOString() : null);

export type ConfirmOutcome = 'verified' | 'declined' | 'expired' | 'invalid';

@Injectable()
export class DeletionCasesService {
  private readonly logger = new Logger('DeletionCases');

  constructor(
    private readonly adminDb: AdminDb,
    private readonly db: DbService,
    private readonly config: AdminConfig,
    private readonly app: AppConfig,
    @Inject(MAILER) private readonly mailer: Mailer,
    /** Global (QueuesModule): the deletion revokes Sign in with Apple like the app's route does (best effort). */
    @Optional() private readonly apple?: AppleTokenVault,
  ) {}

  private hash(userId: string): string {
    return subjectHash(this.app.masterKey, userId);
  }

  private link(token: string): string {
    return `${this.config.publicApiUrl}/v1/deletion-requests/${token}`;
  }

  private view(r: CaseRow): DeletionCaseView {
    const waiting = r.status === 'awaiting_verification';
    const restored = r.status === 'deletion_scheduled' && !r.deletion_pending;
    return {
      caseId: r.id,
      ticket: r.ticket,
      channel: r.channel,
      grievanceId: r.grievance_id,
      grievanceTicket: r.grievance_ticket,
      receivedAt: r.received_at.toISOString(),
      status: r.status,
      accountEmailMasked: r.account_email_masked,
      subjectHash: r.account_id ? this.hash(r.account_id) : null,
      verification: {
        sentAt: iso(r.verification_sent_at),
        expiresAt: iso(r.token_expires_at),
        attempts: r.verification_attempts,
        verifiedAt: iso(r.verified_at),
        declinedAt: iso(r.declined_at),
      },
      deletion:
        r.deletion_requested_at && r.deletion_mode
          ? {
              mode: r.deletion_mode,
              reasonCode: r.deletion_reason,
              requestedAt: r.deletion_requested_at.toISOString(),
              requestedBy: r.deletion_requested_by,
              scheduledFor: iso(r.deletion_scheduled_for),
              pending: r.deletion_pending,
            }
          : null,
      legalHold: { records: r.held_records ?? 0, until: iso(r.held_until) },
      completedAt: iso(r.completed_at),
      closedAt: iso(r.closed_at),
      closedBy: r.closed_by,
      closeOutcome: r.close_outcome,
      createdBy: r.created_by,
      createdAt: r.created_at.toISOString(),
      updatedAt: r.updated_at.toISOString(),
      allowed: {
        resend: waiting,
        startDeletion: r.status === 'verified',
        close: waiting || r.status === 'verified' || r.status === 'declined' || restored,
      },
    };
  }

  async list(query: unknown): Promise<DeletionCaseView[]> {
    const q = parse(deletionListSchema, query);
    const r = await this.adminDb.query<CaseRow>('select * from public.admin_deletion_cases_list($1, $2)', [q.status ?? 'open', 200]);
    return r.rows.map((x) => this.view(x));
  }

  async get(caseId: string): Promise<DeletionCaseView> {
    const r = (await this.adminDb.query<CaseRow>(`select * from public.admin_deletion_cases_list('all', 1, $1)`, [caseId])).rows[0];
    if (!r) throw AdminErrors.notFound('That deletion case does not exist.');
    return this.view(r);
  }

  /** Open a case from an emailed / grievance request and send the one-time link to the account's own address. */
  async open(staff: StaffUser, body: unknown): Promise<DeletionCaseView & { linkEmailed: boolean | null }> {
    const b = parse(deletionCaseSchema, body);
    const token = newLinkToken();
    const expiresAt = new Date(Date.now() + this.config.deletionLinkTtlHours * 3_600_000);
    let opened: { case_id: string; status: DeletionCaseStatus; account_id: string | null; send_to: string | null; ticket: string };
    try {
      opened = await this.adminDb.withTx(async (tx) => {
        for (let attempt = 0; ; attempt++) {
          const ticket = newTicket('DEL');
          try {
            const r = (
              await tx.savepoint((sp: Tx) =>
                sp.query<{ case_id: string; status: DeletionCaseStatus; account_id: string | null; send_to: string | null }>(
                  'select * from public.admin_deletion_case_open($1, $2, $3, $4, $5, $6, $7, $8)',
                  [ticket, b.email, b.channel, new Date(b.receivedAt), b.grievanceId ?? null, tokenHash(token), expiresAt, staff.actor],
                ),
              )
            ).rows[0];
            await auditConsole(tx, staff.actor, {
              action: 'deletion_case_opened',
              reasonCode: r.status,
              subjectHash: r.account_id ? this.hash(r.account_id) : null,
              detail: { caseId: r.case_id, ticket, channel: b.channel, grievanceId: b.grievanceId ?? null, matched: r.account_id !== null },
            });
            return { ...r, ticket };
          } catch (e) {
            if (pgCode(e) === '23505' && pgConstraint(e) === 'admin_deletion_cases_ticket_key' && attempt < 5) continue;
            // Two opens for one account at the same moment: the partial unique index answers like the function does.
            if (pgCode(e) === '23505' && pgConstraint(e) === 'admin_deletion_cases_one_open_idx') {
              throw AdminErrors.conflict('open_case_exists', 'That account already has an open deletion case.');
            }
            if (pgCode(e) === '23503') throw AdminErrors.notFound('That grievance does not exist.');
            throw e;
          }
        }
      });
    } catch (e) {
      throw consoleRefusal(e);
    }
    let linkEmailed: boolean | null = null;
    if (opened.send_to) linkEmailed = await this.sendLink(staff, opened.case_id, opened.ticket, opened.send_to, token, expiresAt);
    return { ...(await this.get(opened.case_id)), linkEmailed };
  }

  /** A fresh link (the old one stops working), again to the address on the account. */
  async resend(staff: StaffUser, caseId: string): Promise<DeletionCaseView & { linkEmailed: boolean }> {
    const token = newLinkToken();
    const expiresAt = new Date(Date.now() + this.config.deletionLinkTtlHours * 3_600_000);
    let sendTo: string;
    let ticket: string;
    try {
      ({ sendTo, ticket } = await this.adminDb.withTx(async (tx) => {
        const r = (
          await tx.query<{ account_id: string; send_to: string }>('select * from public.admin_deletion_case_reissue($1, $2, $3)', [
            caseId,
            tokenHash(token),
            expiresAt,
          ])
        ).rows[0];
        const t = (await tx.query<{ ticket: string }>(`select ticket from public.admin_deletion_cases_list('all', 1, $1)`, [caseId])).rows[0].ticket;
        await auditConsole(tx, staff.actor, {
          action: 'deletion_link_reissued',
          subjectHash: this.hash(r.account_id),
          detail: { caseId, ticket: t },
        });
        return { sendTo: r.send_to, ticket: t };
      }));
    } catch (e) {
      throw consoleRefusal(e);
    }
    const linkEmailed = await this.sendLink(staff, caseId, ticket, sendTo, token, expiresAt);
    return { ...(await this.get(caseId)), linkEmailed };
  }

  /** After commit: email the link; the case records the attempt either way (never fails the request). */
  private async sendLink(staff: StaffUser, caseId: string, ticket: string, to: string, token: string, expiresAt: Date): Promise<boolean> {
    let ok = false;
    let error: string | null = null;
    if (!this.mailer.enabled) {
      error = 'mail_not_configured';
    } else {
      const mail = deletionVerificationMail({ ticket, link: this.link(token), expiresAt, graceDays: DELETION_GRACE_DAYS }, this.config.officer);
      try {
        await this.mailer.send({ to: [to], ...mail, replyTo: this.config.officer.email, autoSubmitted: true });
        ok = true;
      } catch (e) {
        error = mailErrorCode(e);
        this.logger.warn(`deletion link for ${ticket} not sent (${error})`);
      }
    }
    await this.adminDb
      .withTx(async (tx) => {
        await tx.query('select public.admin_deletion_case_mark_sent($1, $2)', [caseId, ok]);
        await auditConsole(tx, staff.actor, {
          action: ok ? 'deletion_link_sent' : 'deletion_link_not_sent',
          reasonCode: error,
          detail: { caseId, ticket, expiresAt: expiresAt.toISOString() },
        });
      })
      .catch((e: unknown) => this.logger.warn(`deletion link bookkeeping failed (${(e as Error).name})`));
    return ok;
  }

  /**
   * Start the deletion for a VERIFIED case: the app's own schedule (7-day grace, or immediate with an audited reason),
   * device tokens removed, then (best effort, like the app's route) the Sign in with Apple token revoked.
   */
  async startDeletion(staff: StaffUser, caseId: string, body: unknown): Promise<DeletionCaseView> {
    const b = parse(deletionScheduleSchema, body);
    const immediate = b.mode === 'immediate';
    const reason = b.mode === 'immediate' ? b.reasonCode : null;
    let accountId: string;
    try {
      accountId = await this.adminDb.withTx(async (tx) => {
        const r = (
          await tx.query<{ account_id: string; scheduled_for: Date }>('select * from public.admin_deletion_case_schedule($1, $2, $3, $4, $5)', [
            caseId,
            immediate,
            immediate ? null : deletionDateFor(new Date()),
            reason,
            staff.actor,
          ])
        ).rows[0];
        const t = (await tx.query<{ ticket: string }>(`select ticket from public.admin_deletion_cases_list('all', 1, $1)`, [caseId])).rows[0].ticket;
        await auditConsole(tx, staff.actor, {
          action: 'deletion_scheduled',
          reasonCode: reason ?? 'grace',
          subjectHash: this.hash(r.account_id),
          detail: { caseId, ticket: t, mode: b.mode, scheduledFor: r.scheduled_for.toISOString() },
        });
        return r.account_id;
      });
    } catch (e) {
      throw consoleRefusal(e);
    }
    await this.revokeAppleBestEffort(accountId);
    return this.get(caseId);
  }

  private async revokeAppleBestEffort(accountId: string): Promise<void> {
    if (!this.apple?.configured) return; // the purge revokes (or waits for configuration)
    try {
      await this.apple.revokeStored(this.db, accountId, { timeoutMs: REQUEST_REVOKE_TIMEOUT_MS });
    } catch (e) {
      this.logger.warn(`deletion case: Apple token not revoked yet (${(e as Error).name}); the purge retries`);
    }
  }

  async close(staff: StaffUser, caseId: string, body: unknown): Promise<DeletionCaseView> {
    const b = parse(deletionCloseSchema, body);
    try {
      await this.adminDb.withTx(async (tx) => {
        await tx.query('select public.admin_deletion_case_close($1, $2, $3)', [caseId, b.outcome, staff.actor]);
        const t = (await tx.query<{ ticket: string }>(`select ticket from public.admin_deletion_cases_list('all', 1, $1)`, [caseId])).rows[0].ticket;
        await auditConsole(tx, staff.actor, { action: 'deletion_case_closed', reasonCode: b.outcome, detail: { caseId, ticket: t } });
      });
    } catch (e) {
      throw consoleRefusal(e);
    }
    return this.get(caseId);
  }

  // ------------------------------------------------------------------------------------------------ public link
  /** What a link points at, without changing anything (opening a link never confirms it). */
  async lookup(token: string): Promise<{ state: 'valid' | 'expired' | 'invalid'; ticket: string | null }> {
    if (!LINK_TOKEN_RE.test(token)) return { state: 'invalid', ticket: null };
    const r = (await this.db.query<{ ticket: string; state: 'valid' | 'expired' }>('select * from public.deletion_case_lookup($1)', [tokenHash(token)])).rows[0];
    return r ? { state: r.state, ticket: r.ticket } : { state: 'invalid', ticket: null };
  }

  /** The account holder confirms ("Delete my account") or declines ("This wasn't me"). Service role only. */
  async confirm(token: string, decline: boolean): Promise<{ outcome: ConfirmOutcome; ticket: string | null }> {
    if (!LINK_TOKEN_RE.test(token)) return { outcome: 'invalid', ticket: null };
    return this.db.withTx(async (tx) => {
      const r = (
        await tx.query<{ case_id: string | null; ticket: string | null; outcome: ConfirmOutcome; account_id: string | null }>(
          'select * from public.deletion_case_confirm($1, $2)',
          [tokenHash(token), decline],
        )
      ).rows[0];
      if (r?.case_id && r.outcome !== 'invalid') {
        await auditConsole(tx, DELETION_LINK_ACTOR, {
          action: r.outcome === 'verified' ? 'deletion_case_verified' : r.outcome === 'declined' ? 'deletion_case_declined' : 'deletion_link_expired',
          subjectHash: r.account_id ? this.hash(r.account_id) : null,
          detail: { caseId: r.case_id, ticket: r.ticket },
        });
      }
      return { outcome: r?.outcome ?? 'invalid', ticket: r?.ticket ?? null };
    });
  }
}
