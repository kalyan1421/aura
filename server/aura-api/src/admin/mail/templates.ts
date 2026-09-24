import type { GrievanceOfficer } from '../admin-config';
import { GAC_APPEAL_TEXT, GRIEVANCE_RULES, type GrievanceCategory } from '../clocks';
import { MAIL_COPY, type MailLocale } from './copy';

/**
 * Email copy for grievances and deletion cases. The acknowledgement and the deletion link go out in the person's
 * language (en / te / te-Latn, from copy.ts — the one place their wording lives); the decision reply and staff mail
 * are English. Acknowledgements and replies never quote the complaint back; officer notifications carry no complaint
 * text and no complainant address (the console shows them to the Owner).
 */
const formats = new Map<string, Intl.DateTimeFormat>();

/** A date and time in IST (the Grievance Officer's clock), written the way `locale` writes dates (PRD 18). */
export function istTime(d: Date, locale: MailLocale = 'en'): string {
  const tag = MAIL_COPY[locale].dateLocale;
  let f = formats.get(tag);
  if (!f) {
    f = new Intl.DateTimeFormat(tag, {
      timeZone: 'Asia/Kolkata',
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
    formats.set(tag, f);
  }
  return `${f.format(d)} IST`;
}

function window(hours: number, locale: MailLocale): string {
  const c = MAIL_COPY[locale];
  if (hours % 24 === 0 && hours >= 48) return c.withinDays(hours / 24);
  return c.withinHours(hours);
}

function officerLines(o: GrievanceOfficer, locale: MailLocale = 'en'): string[] {
  const c = MAIL_COPY[locale];
  const contact = [o.name, o.email, o.address].filter((x): x is string => !!x).join(', ');
  return [c.officer(contact), c.publisher];
}

export interface GrievanceMailFields {
  ticket: string;
  category: GrievanceCategory;
  complainantName: string | null;
  receivedAt: Date;
  resolveDueAt: Date;
}

export function grievanceAckMail(g: GrievanceMailFields, officer: GrievanceOfficer, locale: MailLocale = 'en'): { subject: string; text: string } {
  const c = MAIL_COPY[locale];
  const rule = GRIEVANCE_RULES[g.category];
  const hello = g.complainantName ? c.helloNamed(g.complainantName.replace(/[\r\n]+/g, ' ').slice(0, 120)) : c.hello;
  return {
    subject: c.ack.subject(g.ticket),
    text: [
      hello,
      '',
      c.ack.intro,
      '',
      `${c.ack.ticket}: ${g.ticket}`,
      `${c.ack.received}: ${istTime(g.receivedAt, locale)}`,
      `${c.ack.category}: ${c.categories[g.category]}`,
      c.ack.resolveBy(istTime(g.resolveDueAt, locale), window(rule.resolveHours, locale)),
      '',
      c.ack.quoteTicket,
      '',
      ...officerLines(officer, locale),
      '',
      c.safety,
    ].join('\n'),
  };
}

export const OUTCOME_LABELS = {
  action_taken: 'We took action on the content or account you reported.',
  no_action: 'We reviewed your grievance and did not find a breach of our rules or the law.',
  referred: 'We referred your grievance to the appropriate authority.',
  duplicate: 'This grievance duplicates one we have already resolved.',
  withdrawn: 'The grievance was withdrawn.',
} as const;
export type GrievanceOutcome = keyof typeof OUTCOME_LABELS;

export function grievanceReplyMail(
  g: { ticket: string; receivedAt: Date; outcome: GrievanceOutcome; reply: string },
  officer: GrievanceOfficer,
): { subject: string; text: string } {
  return {
    subject: `Aura: decision on your grievance ${g.ticket}`,
    text: [
      'Hello,',
      '',
      `Your grievance ${g.ticket} (received ${istTime(g.receivedAt)}) has been resolved.`,
      '',
      g.reply.trim(),
      '',
      `Outcome: ${OUTCOME_LABELS[g.outcome]}`,
      '',
      GAC_APPEAL_TEXT,
      '',
      ...officerLines(officer),
    ].join('\n'),
  };
}

/**
 * REQ-ADM-11: the one-time confirmation link for an emailed / grievance deletion request, sent to the address ON THE
 * ACCOUNT (never to wherever the request came from), in the account's app language. No personal data in the link: a
 * random token only.
 */
export function deletionVerificationMail(
  c: { ticket: string; link: string; expiresAt: Date; graceDays: number },
  officer: GrievanceOfficer,
  locale: MailLocale = 'en',
): { subject: string; text: string } {
  const t = MAIL_COPY[locale];
  return {
    subject: t.deletion.subject(c.ticket),
    text: [
      t.hello,
      '',
      t.deletion.intro(c.ticket),
      '',
      t.deletion.ifYou,
      c.link,
      '',
      t.deletion.linkWorks(istTime(c.expiresAt, locale)),
      '',
      t.deletion.ifNot,
      '',
      t.deletion.next(c.graceDays),
      '',
      ...officerLines(officer, locale),
      '',
      t.safety,
    ].join('\n'),
  };
}

export function officerNewGrievanceMail(
  g: { ticket: string; category: GrievanceCategory; channel: string; receivedAt: Date; resolveDueAt: Date },
  link: string,
): { subject: string; text: string } {
  const rule = GRIEVANCE_RULES[g.category];
  return {
    subject: `[Aura console] New grievance ${g.ticket}: resolve by ${istTime(g.resolveDueAt)}`,
    text: [
      `Ticket: ${g.ticket}`,
      `Category: ${rule.label}${rule.pages ? ' (2-hour clock, paging)' : ''}`,
      `Channel: ${g.channel}`,
      `Received: ${istTime(g.receivedAt)}`,
      `Resolve by: ${istTime(g.resolveDueAt)}`,
      '',
      `Open in the console: ${link}`,
      '',
      'The complaint text and the complainant address are only in the console.',
    ].join('\n'),
  };
}
