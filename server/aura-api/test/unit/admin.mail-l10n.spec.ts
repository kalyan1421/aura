/**
 * Localized emails to people (src/admin/mail/copy.ts + templates.ts): the grievance acknowledgement and the deletion
 * link in en / te / te-Latn, chosen from the account's app locale (Hindi / Hinglish / unknown → English), with the same
 * content rules in every language (no complaint text, the random-token link is the only URL, the ticket always
 * there), and the English wording unchanged. Telugu and Tenglish are drafts for native review
 * (docs/l10n/helplines-and-emails.md).
 */
import { parseAdminConfig } from '../../src/admin/admin-config';
import { GRIEVANCE_RULES, type GrievanceCategory } from '../../src/admin/clocks';
import { GrievanceMail } from '../../src/admin/grievance-mail';
import { MAIL_COPY, MAIL_LOCALES, mailLocale } from '../../src/admin/mail/copy';
import type { MailMessage } from '../../src/admin/mail/mailer';
import { deletionVerificationMail, grievanceAckMail, istTime } from '../../src/admin/mail/templates';
import type { DbService } from '../../src/db/db.service';

const OFFICER = { name: 'AK (Grievance Officer)', email: 'grievance@akvega.test', address: null };
const LINK = 'https://api.aura.test/v1/deletion-requests/AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';
const ACK = {
  ticket: 'GRV-7K3F9Q2M',
  category: 'general' as GrievanceCategory,
  complainantName: 'Asha',
  receivedAt: new Date('2026-10-05T06:30:00Z'),
  resolveDueAt: new Date('2026-10-12T06:30:00Z'),
};
const DEL = { ticket: 'DEL-7K3F9Q2M', link: LINK, expiresAt: new Date('2026-10-12T12:00:00Z'), graceDays: 7 };
const URL_RE = /https?:\/\/\S+/g;

describe('mail locale', () => {
  it('the five app languages as they are (Hindi and Hinglish too, Milestone B); unknown and none → English', () => {
    expect(MAIL_LOCALES).toEqual(['en', 'te', 'te-Latn', 'hi', 'hi-Latn']);
    for (const l of ['te', 'te-Latn', 'hi', 'hi-Latn']) expect(mailLocale(l)).toBe(l);
    for (const l of ['fr', 'hi-IN', '', null, undefined]) expect(mailLocale(l)).toBe('en');
  });

  it('the English category names are the console’s (clocks.ts), so nothing drifts', () => {
    for (const [k, rule] of Object.entries(GRIEVANCE_RULES)) expect(MAIL_COPY.en.categories[k as GrievanceCategory]).toBe(rule.label);
  });

  it('dates: Telugu months in te, English formats in te-Latn (PRD 18), always IST', () => {
    expect(istTime(DEL.expiresAt)).toMatch(/Oct 2026.*IST$/);
    expect(istTime(DEL.expiresAt, 'te-Latn')).toBe(istTime(DEL.expiresAt, 'en'));
    expect(istTime(DEL.expiresAt, 'te')).toMatch(/అక్టో.*IST$/);
    expect(istTime(DEL.expiresAt, 'hi')).toMatch(/अक्टू.*IST$/);
    expect(istTime(DEL.expiresAt, 'hi-Latn')).toBe(istTime(DEL.expiresAt, 'en'));
  });
});

describe('grievance acknowledgement', () => {
  it('English is word for word what it was', () => {
    const m = grievanceAckMail(ACK, OFFICER);
    expect(m.subject).toBe('Aura: we received your grievance GRV-7K3F9Q2M');
    expect(m.text).toContain("Thank you for writing to Aura's Grievance Officer. This email acknowledges your grievance.");
    expect(m.text).toContain('Category: Complaint about content or conduct');
    expect(m.text).toContain('(within 7 days of receipt)');
    expect(m.text).toContain('If someone is in immediate danger, call your local emergency number (India: 112).');
  });

  it.each(MAIL_LOCALES)('%s: the ticket, both clocks, the officer and the safety line; no URL, no complaint', (locale) => {
    const m = grievanceAckMail({ ...ACK, category: 'unlawful_content' }, OFFICER, locale);
    const c = MAIL_COPY[locale];
    expect(m.subject).toContain(ACK.ticket);
    expect(m.text).toContain(`: ${ACK.ticket}`);
    expect(m.text).toContain(istTime(ACK.receivedAt, locale));
    expect(m.text).toContain(istTime(ACK.resolveDueAt, locale));
    expect(m.text).toContain(c.categories.unlawful_content);
    expect(m.text).toContain(c.withinHours(36));
    expect(m.text).toContain(OFFICER.email);
    expect(m.text).toContain(c.safety);
    expect(m.text.match(URL_RE)).toBeNull();
  });

  it('Telugu and Tenglish really are in those languages', () => {
    expect(grievanceAckMail(ACK, OFFICER, 'te').subject).toBe('Aura: మీ ఫిర్యాదు GRV-7K3F9Q2M మాకు అందింది');
    expect(grievanceAckMail(ACK, OFFICER, 'te').text).toContain('నమస్కారం Asha గారు,');
    expect(grievanceAckMail(ACK, OFFICER, 'te-Latn').subject).toBe('Aura: mee grievance GRV-7K3F9Q2M maaku andindi');
    expect(grievanceAckMail(ACK, OFFICER, 'te-Latn').text).toContain('7 rojullo');
  });

  it('Hindi and Hinglish really are in those languages (no English fallback)', () => {
    expect(grievanceAckMail(ACK, OFFICER, 'hi').subject).toBe('Aura: आपकी शिकायत GRV-7K3F9Q2M हमें मिल गई है');
    expect(grievanceAckMail(ACK, OFFICER, 'hi').text).toContain('नमस्ते Asha जी,');
    expect(grievanceAckMail(ACK, OFFICER, 'hi-Latn').subject).toBe('Aura: aapki grievance GRV-7K3F9Q2M humein mil gayi hai');
    expect(grievanceAckMail(ACK, OFFICER, 'hi-Latn').text).toContain('7 dinon ke andar');
    expect(deletionVerificationMail(DEL, OFFICER, 'hi').subject).toMatch(/[\u0900-\u097F]/);
    expect(deletionVerificationMail(DEL, OFFICER, 'hi-Latn').subject).toContain('request confirm karein');
  });
});

describe('deletion link email', () => {
  it.each(MAIL_LOCALES)('%s: the link is the only URL and is untouched; ticket, expiry, 30 days, grace, safety', (locale) => {
    const m = deletionVerificationMail(DEL, OFFICER, locale);
    expect(m.subject).toContain(DEL.ticket);
    expect(m.text.match(URL_RE)).toEqual([LINK]);
    expect(m.text).toContain(istTime(DEL.expiresAt, locale));
    expect(m.text).toMatch(/30/);
    expect(m.text).toContain(MAIL_COPY[locale].deletion.next(7));
    // The confirmation page's buttons are English, so every language names them in English.
    expect(m.text).toContain('"Delete my account"');
    expect(m.text).toContain('"This wasn\'t me"');
    expect(m.text).toContain(MAIL_COPY[locale].safety);
  });

  it('English unchanged', () => {
    const m = deletionVerificationMail(DEL, OFFICER);
    expect(m.subject).toBe('Aura: confirm the request to delete your account (DEL-7K3F9Q2M)');
    expect(m.text).toContain('nothing is deleted without your confirmation');
  });
});

describe('GrievanceMail picks the account’s app language', () => {
  const grievance = (locale: string | null) => ({
    id: 'g1',
    ticket: ACK.ticket,
    category: 'general',
    channel: 'web_form',
    complainant_name: null,
    complainant_email: 'Asha@Example.test',
    locale,
    received_at: ACK.receivedAt,
    resolve_due_at: ACK.resolveDueAt,
    outcome: null,
    reply: null,
    ack_email_sent_at: null,
    ack_email_attempts: 0,
  });
  const run = async (accountLocale: string | null, formLocale: string | null) => {
    const sent: MailMessage[] = [];
    const params: unknown[][] = [];
    const db = {
      query: async (sql: string, p: unknown[]) => {
        params.push(p);
        if (sql.includes('from public.admin_grievances')) return { rows: [grievance(formLocale)], rowCount: 1 };
        if (sql.includes('from auth.users')) return { rows: accountLocale ? [{ ui_locale: accountLocale }] : [], rowCount: 1 };
        return { rows: [], rowCount: 1 };
      },
    } as unknown as DbService;
    const mail = new GrievanceMail(db, parseAdminConfig({}), { enabled: true, send: async (m) => void sent.push(m) });
    expect(await mail.sendAck('g1')).toBe(true);
    return { subject: sent[0].subject, params };
  };

  it('the account’s app language first', async () => {
    const r = await run('te', 'en');
    expect(r.subject).toContain('మీ ఫిర్యాదు');
    expect(r.params).toContainEqual(['Asha@Example.test']);
  });

  it('no account: the language the grievance came in; then English', async () => {
    expect((await run(null, 'te-Latn')).subject).toContain('maaku andindi');
    expect((await run(null, null)).subject).toContain('we received your grievance');
    expect((await run('hi-Latn', 'te')).subject).toContain('humein mil gayi hai');
    expect((await run('fr', 'te')).subject).toContain('we received your grievance');
  });
});
