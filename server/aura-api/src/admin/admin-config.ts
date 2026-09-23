import { z } from 'zod';

/**
 * Admin console configuration (docs/setup/admin-console.md). Every variable is optional so the API and worker boot
 * without them: mail and paging then stay off and the console says so (`GET /admin/paging/status`). A malformed value
 * fails fast at boot with the variable's name, never its value.
 */
export type WebhookFormat = 'json' | 'ntfy' | 'slack' | 'pagerduty';

export interface WebhookTarget {
  url: string;
  format: WebhookFormat;
  /** Bearer token (json / ntfy), PagerDuty routing key, or unset. Never logged. */
  token: string | null;
}

export interface GrievanceOfficer {
  name: string;
  email: string | null;
  address: string | null;
}

export class AdminConfig {
  /** Base URL of the console, used for links in pages and emails. */
  readonly consoleUrl: string;
  /** Optional second gate on top of `admin_staff`: when set, the staff account's email must be listed. */
  readonly allowedEmails: ReadonlySet<string> | null;
  /** Staff sessions older than this (from the Supabase sign-in) are refused, even with a fresh access token. */
  readonly sessionMaxHours: number;
  readonly officer: GrievanceOfficer;
  readonly grievancePerIpPerHour: number;
  readonly grievanceGlobalPerHour: number;
  /** `smtp://[user:pass@]host:port[?starttls=required|off]` or `smtps://…`. Null = email off. */
  readonly smtpUrl: string | null;
  readonly mailFrom: string;
  readonly paging: {
    webhook: WebhookTarget | null;
    escalationWebhook: WebhookTarget | null;
    emailTo: readonly string[];
    repeatMinutes: number;
    escalateAfterMinutes: number;
    /** Test pages stop after this many rounds if nobody acknowledges them. */
    testMaxRounds: number;
    /** BullMQ cron for the weekly test page, or null (off). */
    weeklyTestCron: string | null;
    weeklyTestTz: string;
    /** Per-channel attempts inside one round (first try + retries) and the waits between them. */
    retryDelaysMs: readonly number[];
    timeoutMs: number;
  };
  /** Shared secret for `POST /v1/intake/legal-orders` (e.g. an email-to-webhook relay). Null = route off. */
  readonly legalIntakeToken: string | null;

  constructor(v: Omit<AdminConfig, never>) {
    this.consoleUrl = v.consoleUrl;
    this.allowedEmails = v.allowedEmails;
    this.sessionMaxHours = v.sessionMaxHours;
    this.officer = Object.freeze({ ...v.officer });
    this.grievancePerIpPerHour = v.grievancePerIpPerHour;
    this.grievanceGlobalPerHour = v.grievanceGlobalPerHour;
    this.smtpUrl = v.smtpUrl;
    this.mailFrom = v.mailFrom;
    this.paging = Object.freeze({ ...v.paging, emailTo: Object.freeze([...v.paging.emailTo]) });
    this.legalIntakeToken = v.legalIntakeToken;
    Object.freeze(this);
  }
}

const blankToUndefined = (v: unknown): unknown => (typeof v === 'string' && v.trim() === '' ? undefined : v);
const opt = <T extends z.ZodType>(s: T) => z.preprocess(blankToUndefined, s.optional());
const int = (min: number, max: number, dflt: number) =>
  z.preprocess(blankToUndefined, z.coerce.number().int().min(min).max(max).default(dflt));
const httpUrl = z.url({ protocol: /^https?$/ });
const email = z.email();
const csv = (item: z.ZodType<string>) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? v.split(',').map((s) => s.trim()).filter(Boolean) : v),
    z.array(item).default([]),
  );
const format = z.preprocess(blankToUndefined, z.enum(['json', 'ntfy', 'slack', 'pagerduty']).default('json'));

const schema = z.object({
  ADMIN_CONSOLE_URL: z.preprocess(blankToUndefined, httpUrl.default('http://localhost:3320')),
  ADMIN_ALLOWED_EMAILS: csv(email),
  ADMIN_SESSION_MAX_HOURS: int(1, 24, 12),
  GRIEVANCE_OFFICER_NAME: z.preprocess(blankToUndefined, z.string().min(1).max(120).default('Grievance Officer, AKVega')),
  GRIEVANCE_OFFICER_EMAIL: opt(email),
  GRIEVANCE_OFFICER_ADDRESS: opt(z.string().min(1).max(300)),
  GRIEVANCE_RATE_PER_IP_HOUR: int(1, 1000, 5),
  GRIEVANCE_RATE_GLOBAL_HOUR: int(1, 100_000, 300),
  SMTP_URL: opt(z.string().regex(/^smtps?:\/\/[^\s]+$/, 'must be smtp://… or smtps://…')),
  MAIL_FROM: z.preprocess(blankToUndefined, z.string().min(3).max(200).default('Aura <no-reply@localhost>')),
  PAGING_WEBHOOK_URL: opt(httpUrl),
  PAGING_WEBHOOK_FORMAT: format,
  PAGING_WEBHOOK_TOKEN: opt(z.string().min(1).max(500)),
  PAGING_ESCALATION_WEBHOOK_URL: opt(httpUrl),
  PAGING_ESCALATION_WEBHOOK_FORMAT: format,
  PAGING_ESCALATION_WEBHOOK_TOKEN: opt(z.string().min(1).max(500)),
  PAGING_EMAIL_TO: csv(email),
  PAGING_REPEAT_MINUTES: int(1, 60, 5),
  PAGING_ESCALATE_AFTER_MINUTES: int(1, 60, 5),
  PAGING_TEST_MAX_ROUNDS: int(1, 20, 3),
  PAGING_WEEKLY_TEST_CRON: z.preprocess(blankToUndefined, z.string().max(100).default('0 10 * * 1')),
  PAGING_WEEKLY_TEST_TZ: z.preprocess(blankToUndefined, z.string().max(64).default('Asia/Kolkata')),
  PAGING_RETRY_DELAYS_MS: z.preprocess(
    (v) => (typeof v === 'string' && v.trim() !== '' ? v.split(',').map((s) => Number(s.trim())) : undefined),
    z.array(z.number().int().min(0).max(60_000)).min(1).max(10).default([0, 2000, 5000]),
  ),
  PAGING_TIMEOUT_MS: int(500, 30_000, 5000),
  LEGAL_INTAKE_TOKEN: opt(z.string().min(32, 'must be at least 32 characters').max(500)),
});

export class AdminConfigError extends Error {}

function webhook(url: string | undefined, fmt: WebhookFormat, token: string | undefined): WebhookTarget | null {
  return url ? { url, format: fmt, token: token ?? null } : null;
}

/** Parse the admin variables from an env record; throws listing the offending variable names only. */
export function parseAdminConfig(env: Record<string, string | undefined>): AdminConfig {
  const r = schema.safeParse(env);
  if (!r.success) {
    const lines = r.error.issues.map((i) => `  - ${i.path.join('.') || '(env)'}: ${i.message}`);
    throw new AdminConfigError(`Invalid admin console environment:\n${lines.join('\n')}`);
  }
  const e = r.data;
  if (e.PAGING_WEBHOOK_FORMAT === 'pagerduty' && e.PAGING_WEBHOOK_URL && !e.PAGING_WEBHOOK_TOKEN) {
    throw new AdminConfigError('Invalid admin console environment:\n  - PAGING_WEBHOOK_TOKEN: the PagerDuty routing key is required');
  }
  if (e.PAGING_ESCALATION_WEBHOOK_FORMAT === 'pagerduty' && e.PAGING_ESCALATION_WEBHOOK_URL && !e.PAGING_ESCALATION_WEBHOOK_TOKEN) {
    throw new AdminConfigError(
      'Invalid admin console environment:\n  - PAGING_ESCALATION_WEBHOOK_TOKEN: the PagerDuty routing key is required',
    );
  }
  const cron = e.PAGING_WEEKLY_TEST_CRON.trim().toLowerCase() === 'off' ? null : e.PAGING_WEEKLY_TEST_CRON.trim();
  return new AdminConfig({
    consoleUrl: e.ADMIN_CONSOLE_URL.replace(/\/+$/, ''),
    allowedEmails: e.ADMIN_ALLOWED_EMAILS.length ? new Set(e.ADMIN_ALLOWED_EMAILS.map((x) => x.toLowerCase())) : null,
    sessionMaxHours: e.ADMIN_SESSION_MAX_HOURS,
    officer: { name: e.GRIEVANCE_OFFICER_NAME, email: e.GRIEVANCE_OFFICER_EMAIL ?? null, address: e.GRIEVANCE_OFFICER_ADDRESS ?? null },
    grievancePerIpPerHour: e.GRIEVANCE_RATE_PER_IP_HOUR,
    grievanceGlobalPerHour: e.GRIEVANCE_RATE_GLOBAL_HOUR,
    smtpUrl: e.SMTP_URL ?? null,
    mailFrom: e.MAIL_FROM,
    paging: {
      webhook: webhook(e.PAGING_WEBHOOK_URL, e.PAGING_WEBHOOK_FORMAT, e.PAGING_WEBHOOK_TOKEN),
      escalationWebhook: webhook(e.PAGING_ESCALATION_WEBHOOK_URL, e.PAGING_ESCALATION_WEBHOOK_FORMAT, e.PAGING_ESCALATION_WEBHOOK_TOKEN),
      emailTo: e.PAGING_EMAIL_TO,
      repeatMinutes: e.PAGING_REPEAT_MINUTES,
      escalateAfterMinutes: e.PAGING_ESCALATE_AFTER_MINUTES,
      testMaxRounds: e.PAGING_TEST_MAX_ROUNDS,
      weeklyTestCron: cron,
      weeklyTestTz: e.PAGING_WEEKLY_TEST_TZ,
      retryDelaysMs: e.PAGING_RETRY_DELAYS_MS,
      timeoutMs: e.PAGING_TIMEOUT_MS,
    },
    legalIntakeToken: e.LEGAL_INTAKE_TOKEN ?? null,
  });
}
