import { Inject, Injectable, Logger } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { AdminConfig } from './admin-config';
import type { GrievanceCategory } from './clocks';
import { mailLocale, type MailLocale } from './mail/copy';
import { MAILER, mailErrorCode, type Mailer } from './mail/mailer';
import { grievanceAckMail, grievanceReplyMail, officerNewGrievanceMail, type GrievanceOutcome } from './mail/templates';

/**
 * Grievance email (service role): the automatic acknowledgement to the complainant (sent right after intake, retried by
 * the worker tick until it goes out — at most 5 tries), the Owner's content-free "new grievance" notice, and the
 * decision reply with the Grievance Appellate Committee route. Logs carry ticket ids and error codes only.
 */
const ACK_MAX_ATTEMPTS = 5;

interface GrievanceRow {
  id: string;
  ticket: string;
  category: GrievanceCategory;
  channel: string;
  complainant_name: string | null;
  complainant_email: string;
  locale: string | null;
  received_at: Date;
  resolve_due_at: Date;
  outcome: GrievanceOutcome | null;
  reply: string | null;
  ack_email_sent_at: Date | null;
  ack_email_attempts: number;
}

const COLS = `id, ticket, category, channel, complainant_name, complainant_email, locale, received_at, resolve_due_at, outcome, reply,
              ack_email_sent_at, ack_email_attempts`;

@Injectable()
export class GrievanceMail {
  private readonly logger = new Logger('GrievanceMail');

  constructor(
    private readonly db: DbService,
    private readonly config: AdminConfig,
    @Inject(MAILER) private readonly mailer: Mailer,
  ) {}

  get enabled(): boolean {
    return this.mailer.enabled;
  }

  /** The acknowledgement email; true when it went out now (or had already). */
  async sendAck(grievanceId: string): Promise<boolean> {
    const g = (await this.db.query<GrievanceRow>(`select ${COLS} from public.admin_grievances where id = $1`, [grievanceId])).rows[0];
    if (!g) return false;
    if (g.ack_email_sent_at) return true;
    if (!this.mailer.enabled || g.ack_email_attempts >= ACK_MAX_ATTEMPTS) return false;
    const mail = grievanceAckMail(
      { ticket: g.ticket, category: g.category, complainantName: g.complainant_name, receivedAt: g.received_at, resolveDueAt: g.resolve_due_at },
      this.config.officer,
      await this.ackLocale(g),
    );
    try {
      await this.mailer.send({ to: [g.complainant_email], ...mail, replyTo: this.config.officer.email, autoSubmitted: true });
      await this.db.query(
        `update public.admin_grievances set ack_email_sent_at = now(), ack_email_attempts = ack_email_attempts + 1, updated_at = now()
          where id = $1`,
        [g.id],
      );
      return true;
    } catch (e) {
      await this.db.query(`update public.admin_grievances set ack_email_attempts = ack_email_attempts + 1 where id = $1`, [g.id]);
      this.logger.warn(`acknowledgement for ${g.ticket} not sent (${mailErrorCode(e)})`);
      return false;
    }
  }

  /**
   * The acknowledgement's language: the app language of the Aura account that signs in with the complainant's address
   * (they get it in the language they use Aura in), else the language the grievance came in (`locale`, sent by the
   * form), else English. Only a language comes back; nothing about the account is kept or logged.
   */
  private async ackLocale(g: GrievanceRow): Promise<MailLocale> {
    const r = await this.db
      .query<{ ui_locale: string }>(
        `select p.ui_locale from auth.users u join public.profiles p on p.user_id = u.id
          where lower(u.email) = lower($1) and u.deleted_at is null limit 1`,
        [g.complainant_email],
      )
      .catch(() => ({ rows: [] as Array<{ ui_locale: string }> }));
    return mailLocale(r.rows[0]?.ui_locale ?? g.locale);
  }

  /** Content-free notice to the Grievance Officer's inbox (2-hour categories also page). */
  async notifyOfficer(grievanceId: string): Promise<void> {
    if (!this.mailer.enabled || !this.config.officer.email) return;
    const g = (await this.db.query<GrievanceRow>(`select ${COLS} from public.admin_grievances where id = $1`, [grievanceId])).rows[0];
    if (!g) return;
    const mail = officerNewGrievanceMail(
      { ticket: g.ticket, category: g.category, channel: g.channel, receivedAt: g.received_at, resolveDueAt: g.resolve_due_at },
      `${this.config.consoleUrl}/grievances/${g.id}`,
    );
    await this.mailer.send({ to: [this.config.officer.email], ...mail, autoSubmitted: true }).catch((e: unknown) => {
      this.logger.warn(`officer notice for ${g.ticket} not sent (${mailErrorCode(e)})`);
    });
  }

  /** The decision reply (with the appeal route). True when the server accepted it. */
  async sendReply(grievanceId: string): Promise<boolean> {
    const g = (await this.db.query<GrievanceRow>(`select ${COLS} from public.admin_grievances where id = $1`, [grievanceId])).rows[0];
    if (!g || !g.outcome || !g.reply || !this.mailer.enabled) return false;
    const mail = grievanceReplyMail({ ticket: g.ticket, receivedAt: g.received_at, outcome: g.outcome, reply: g.reply }, this.config.officer);
    try {
      await this.mailer.send({ to: [g.complainant_email], ...mail, replyTo: this.config.officer.email });
      await this.db.query(`update public.admin_grievances set reply_email_sent_at = now(), updated_at = now() where id = $1`, [g.id]);
      return true;
    } catch (e) {
      this.logger.warn(`reply for ${g.ticket} not sent (${mailErrorCode(e)})`);
      return false;
    }
  }

  /** Worker tick: acknowledgements that did not go out yet (SMTP was down, or the API restarted mid-send). */
  async retryPendingAcks(): Promise<number> {
    if (!this.mailer.enabled) return 0;
    const due = await this.db.query<{ id: string }>(
      `select id from public.admin_grievances
        where ack_email_sent_at is null and ack_email_attempts < $1
          and created_at < now() - interval '1 minute' and created_at > now() - interval '7 days'
        order by created_at limit 20`,
      [ACK_MAX_ATTEMPTS],
    );
    let sent = 0;
    for (const x of due.rows) if (await this.sendAck(x.id)) sent++;
    return sent;
  }
}
