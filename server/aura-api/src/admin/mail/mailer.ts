import { SmtpError, sendMail, smtpOptionsFromUrl, type MailAttachment, type SmtpOptions } from './smtp';

/** Plain-text email out of the console (grievance acknowledgements and replies, pages, deletion links, audit exports). */
export interface MailMessage {
  to: readonly string[];
  subject: string;
  text: string;
  replyTo?: string | null;
  autoSubmitted?: boolean;
  attachments?: readonly MailAttachment[];
}

export interface Mailer {
  readonly enabled: boolean;
  /** Throws `SmtpError` (with a short code) when the message was not accepted. */
  send(m: MailMessage): Promise<void>;
}

export const MAILER = Symbol('MAILER');

export class SmtpMailer implements Mailer {
  readonly enabled = true;

  constructor(
    private readonly options: SmtpOptions,
    private readonly from: string,
  ) {}

  static fromUrl(url: string, from: string): SmtpMailer {
    return new SmtpMailer(smtpOptionsFromUrl(url), from);
  }

  send(m: MailMessage): Promise<void> {
    return sendMail(this.options, {
      from: this.from,
      to: m.to,
      subject: m.subject,
      text: m.text,
      replyTo: m.replyTo,
      autoSubmitted: m.autoSubmitted,
      attachments: m.attachments,
    });
  }
}

/** SMTP_URL unset: nothing is sent; callers record `mail_not_configured`. */
export class DisabledMailer implements Mailer {
  readonly enabled = false;

  async send(): Promise<void> {
    throw new SmtpError('mail_not_configured', 'SMTP_URL is not set');
  }
}

/** A short error code for logs and the paging log (never the server's reply text). */
export function mailErrorCode(err: unknown): string {
  return err instanceof SmtpError ? err.code : 'smtp_error';
}
