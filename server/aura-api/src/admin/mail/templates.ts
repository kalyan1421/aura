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
