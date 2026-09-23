/** Admin console environment: safe defaults (the API boots without it), strict validation that names variables only. */
import { AdminConfigError, parseAdminConfig } from '../../src/admin/admin-config';

describe('admin config', () => {
  it('defaults: console on :3320, 12 h sessions, 5-minute repeat and escalation, weekly drill Monday 10:00 IST, mail and paging off', () => {
    const c = parseAdminConfig({});
    expect(c).toMatchObject({
      consoleUrl: 'http://localhost:3320',
      allowedEmails: null,
      sessionMaxHours: 12,
      smtpUrl: null,
      legalIntakeToken: null,
      officer: { name: 'Grievance Officer, AKVega', email: null, address: null },
    });
    expect(c.paging).toMatchObject({
      webhook: null,
      escalationWebhook: null,
      emailTo: [],
      repeatMinutes: 5,
      escalateAfterMinutes: 5,
      weeklyTestCron: '0 10 * * 1',
      weeklyTestTz: 'Asia/Kolkata',
      retryDelaysMs: [0, 2000, 5000],
    });
    expect(Object.isFrozen(c)).toBe(true);
  });

  it('parses lists and channels', () => {
    const c = parseAdminConfig({
      ADMIN_ALLOWED_EMAILS: 'AK@akvega.test, ops@akvega.test',
      PAGING_EMAIL_TO: 'ak@akvega.test',
      PAGING_WEBHOOK_URL: 'https://ntfy.sh/aura-ak',
      PAGING_WEBHOOK_FORMAT: 'ntfy',
      PAGING_WEEKLY_TEST_CRON: 'off',
      PAGING_RETRY_DELAYS_MS: '0, 500',
      ADMIN_CONSOLE_URL: 'https://admin.aura.test/',
    });
    expect([...(c.allowedEmails ?? [])]).toEqual(['ak@akvega.test', 'ops@akvega.test']);
    expect(c.paging.webhook).toEqual({ url: 'https://ntfy.sh/aura-ak', format: 'ntfy', token: null });
    expect(c.paging.weeklyTestCron).toBeNull();
    expect(c.paging.retryDelaysMs).toEqual([0, 500]);
    expect(c.consoleUrl).toBe('https://admin.aura.test');
  });

  it('rejects bad values by variable name, never echoing the value', () => {
    const bad = (): unknown =>
      parseAdminConfig({ SMTP_URL: 'mailto:secret-value', PAGING_WEBHOOK_URL: 'ftp://secret-host', LEGAL_INTAKE_TOKEN: 'short-secret' });
    expect(bad).toThrow(AdminConfigError);
    try {
      bad();
    } catch (e) {
      const m = (e as Error).message;
      expect(m).toContain('SMTP_URL');
      expect(m).toContain('PAGING_WEBHOOK_URL');
      expect(m).toContain('LEGAL_INTAKE_TOKEN');
      expect(m).not.toContain('secret');
    }
    expect(() => parseAdminConfig({ PAGING_WEBHOOK_URL: 'https://events.pagerduty.com/v2/enqueue', PAGING_WEBHOOK_FORMAT: 'pagerduty' })).toThrow(
      /routing key/,
    );
  });
});
