import type { GrievanceOfficer } from '../admin-config';
import { GAC_APPEAL_TEXT, GRIEVANCE_RULES, type GrievanceCategory } from '../clocks';

/**
 * Email copy for grievances (English, v0). Acknowledgements and replies never quote the complaint back; officer
 * notifications carry no complaint text and no complainant address (the console shows them to the Owner).
 */
const IST = new Intl.DateTimeFormat('en-IN', {
  timeZone: 'Asia/Kolkata',
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

export function istTime(d: Date): string {
  return `${IST.format(d)} IST`;
}

function window(hours: number): string {
  if (hours % 24 === 0 && hours >= 48) return `within ${hours / 24} days`;
  return `within ${hours} hours`;
}

function officerLines(o: GrievanceOfficer): string[] {
  const contact = [o.name, o.email, o.address].filter((x): x is string => !!x).join(', ');
  return [`Grievance Officer: ${contact}`, 'Aura is published by AKVega.'];
}

const SAFETY_LINE = 'If someone is in immediate danger, call your local emergency number (India: 112).';

export interface GrievanceMailFields {
  ticket: string;
  category: GrievanceCategory;
  complainantName: string | null;
  receivedAt: Date;
  resolveDueAt: Date;
}

export function grievanceAckMail(g: GrievanceMailFields, officer: GrievanceOfficer): { subject: string; text: string } {
  const rule = GRIEVANCE_RULES[g.category];
  const hello = g.complainantName ? `Hello ${g.complainantName.replace(/[\r\n]+/g, ' ').slice(0, 120)},` : 'Hello,';
  return {
    subject: `Aura: we received your grievance ${g.ticket}`,
    text: [
      hello,
      '',
      "Thank you for writing to Aura's Grievance Officer. This email acknowledges your grievance.",
      '',
      `Ticket: ${g.ticket}`,
      `Received: ${istTime(g.receivedAt)}`,
      `Category: ${rule.label}`,
      `We will resolve it by: ${istTime(g.resolveDueAt)} (${window(rule.resolveHours)} of receipt)`,
      '',
      'Please quote your ticket number if you write to us again. You can reply to this email.',
      '',
      ...officerLines(officer),
      '',
      SAFETY_LINE,
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
 * ACCOUNT (never to wherever the request came from). No personal data in the link: a random token only.
 */
export function deletionVerificationMail(
  c: { ticket: string; link: string; expiresAt: Date; graceDays: number },
  officer: GrievanceOfficer,
): { subject: string; text: string } {
  return {
    subject: `Aura: confirm the request to delete your account (${c.ticket})`,
    text: [
      'Hello,',
      '',
      `Aura's Grievance Officer received a request to delete the Aura account that signs in with this email address (request ${c.ticket}).`,
      '',
      'If you made this request, open the link below and press "Delete my account":',
      c.link,
      '',
      `The link works once, until ${istTime(c.expiresAt)}.`,
      '',
      "If you did not ask for this, you don't need to do anything: nothing is deleted without your confirmation. You can also open the link and press \"This wasn't me\".",
      '',
      `What happens next: once you confirm, Aura starts the same deletion as the in-app option. The account is switched off straight away and deleted for good within 30 days (normally after ${c.graceDays} days, during which signing in to the app lets you keep it). Records the law requires us to keep (for example about reported content) are kept only as long as required.`,
      '',
      ...officerLines(officer),
      '',
      SAFETY_LINE,
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
