/**
 * Pager rules (PRD 19 REQ-ADM-05 / REQ-ADM-15): round 0 on the first channels at once, retries inside a round,
 * escalation to the voice-call channel from 5 minutes unacknowledged, repeat every 5 minutes, a quick retry after a
 * round that reached nobody, and payloads that never carry content.
 */
import { parseAdminConfig } from '../../src/admin/admin-config';
import { DisabledMailer, type Mailer } from '../../src/admin/mail/mailer';
import { EmailChannel, WebhookChannel, buildChannels, webhookRequest, type FetchLike } from '../../src/admin/paging/channels';
import {
  channelsFor,
  deliverWithRetry,
  escalationLevel,
  nextAttemptAt,
  pageLines,
  pageTitle,
  runRound,
  type DeliveryResult,
  type PageChannel,
  type PagePayload,
} from '../../src/admin/paging/paging-rules';
import { SmtpError } from '../../src/admin/mail/smtp';

const NOW = new Date('2026-10-12T21:30:00.000Z');
const MIN = 60_000;

const payload = (over: Partial<PagePayload> = {}): PagePayload => ({
  pageId: '0192f0c2-7a4e-7c1a-9b3d-0000000000a1',
  kind: 'legal_order',
  reason: 'legal_order',
  lane: null,
  minorInvolved: false,
  isTest: true,
  ticket: 'LO-7K3F9Q2M',
  dueAt: new Date(NOW.getTime() + 178 * MIN).toISOString(),
  waitingMinutes: 2,
  round: 0,
  escalationLevel: 0,
  consoleUrl: 'http://localhost:3320/paging/0192f0c2-7a4e-7c1a-9b3d-0000000000a1',
  ...over,
});

class ScriptedChannel implements PageChannel {
  calls = 0;
  constructor(
    readonly name: PageChannel['name'],
    readonly level: 0 | 1,
    private readonly script: boolean[],
  ) {}
  async send(): Promise<DeliveryResult> {
    const ok = this.script[Math.min(this.calls, this.script.length - 1)];
    this.calls++;
    return ok ? { ok: true, httpStatus: 200, error: null, latencyMs: 5 } : { ok: false, httpStatus: 503, error: 'http_503', latencyMs: 5 };
  }
}

const instant = async (): Promise<void> => undefined;

describe('escalation and repeats', () => {
  const created = NOW;
  it('round 0 is level 0; from 5 minutes unacknowledged every round escalates', () => {
    expect(escalationLevel(0, created, NOW, 5)).toBe(0);
    expect(escalationLevel(1, created, new Date(NOW.getTime() + 4 * MIN), 5)).toBe(0); // a quick retry before 5 min
    expect(escalationLevel(1, created, new Date(NOW.getTime() + 5 * MIN), 5)).toBe(1);
    expect(escalationLevel(7, created, new Date(NOW.getTime() + 35 * MIN), 5)).toBe(1);
  });

  it('next round: +5 min after a delivered round, +1 min after a round that reached nobody', () => {
    expect(nextAttemptAt(NOW, true, 5).getTime() - NOW.getTime()).toBe(5 * MIN);
    expect(nextAttemptAt(NOW, false, 5).getTime() - NOW.getTime()).toBe(1 * MIN);
  });

  it('level 0 uses the first channels only; level 1 adds the escalation (voice-call) channel', () => {
    const chans = [new ScriptedChannel('webhook', 0, [true]), new ScriptedChannel('email', 0, [true]), new ScriptedChannel('escalation_webhook', 1, [true])];
    expect(channelsFor(chans, 0).map((c) => c.name)).toEqual(['webhook', 'email']);
    expect(channelsFor(chans, 1).map((c) => c.name)).toEqual(['webhook', 'email', 'escalation_webhook']);
  });

  it('a timeline: t=0 push + email; t=5 min adds the call; every channel is logged per attempt', async () => {
    const push = new ScriptedChannel('webhook', 0, [true]);
    const mail = new ScriptedChannel('email', 0, [true]);
    const call = new ScriptedChannel('escalation_webhook', 1, [true]);
    const chans = [push, mail, call];
    const r0 = await runRound(chans, escalationLevel(0, NOW, NOW, 5), payload(), [0, 1000], instant);
    expect(r0.delivered).toBe(true);
    expect(r0.attempts.map((a) => a.channel)).toEqual(['webhook', 'email']);
    const t5 = new Date(NOW.getTime() + 5 * MIN);
    const r1 = await runRound(chans, escalationLevel(1, NOW, t5, 5), payload({ round: 1 }), [0, 1000], instant);
    expect(r1.attempts.map((a) => [a.channel, a.level])).toEqual([
      ['webhook', 0],
      ['email', 0],
      ['escalation_webhook', 1],
    ]);
    expect(call.calls).toBe(1);
  });
});

describe('retries inside a round', () => {
  it('retries a failing channel with the configured waits and stops at the first success', async () => {
    const waits: number[] = [];
    const flaky = new ScriptedChannel('webhook', 0, [false, false, true]);
    const attempts = await deliverWithRetry(flaky, payload(), [0, 2000, 5000], async (ms) => {
      waits.push(ms);
    });
    expect(attempts.map((a) => [a.attempt, a.result.ok, a.result.error])).toEqual([
      [1, false, 'http_503'],
      [2, false, 'http_503'],
      [3, true, null],
    ]);
    expect(waits).toEqual([2000, 5000]);
  });

  it('gives up after the last try; the round is "not delivered" only if every channel failed', async () => {
    const dead = new ScriptedChannel('webhook', 0, [false]);
    const ok = new ScriptedChannel('email', 0, [true]);
    const one = await runRound([dead], 0, payload(), [0, 0, 0], instant);
    expect(one).toMatchObject({ delivered: false });
    expect(one.attempts).toHaveLength(3);
    expect((await runRound([dead, ok], 0, payload(), [0, 0, 0], instant)).delivered).toBe(true);
  });

  it('a channel that throws is logged as channel_error, not a crash', async () => {
    const boom: PageChannel = { name: 'webhook', level: 0, send: () => Promise.reject(new Error('x')) };
    const a = await deliverWithRetry(boom, payload(), [0], instant);
    expect(a[0].result).toMatchObject({ ok: false, error: 'channel_error' });
  });
});

describe('payloads carry no content', () => {
  const p = payload({ kind: 'report', lane: 'minors_grooming', minorInvolved: true, ticket: null, isTest: false });

  it('titles are ASCII (they travel as HTTP headers) and say kind, minor flag and deadline only', () => {
    const title = pageTitle(p, NOW);
    expect(title).toBe('Minors & grooming report | minor involved | due in 2 h 58 min');
    expect(/^[\x20-\x7e]+$/.test(title)).toBe(true);
    expect(pageTitle(payload({ dueAt: new Date(NOW.getTime() - 12 * MIN).toISOString() }), NOW)).toBe('TEST | Legal order LO-7K3F9Q2M | OVERDUE by 12 min');
    expect(pageLines(p, NOW).join('\n')).toContain(p.consoleUrl);
  });

  it('every webhook format sends only the page fields', () => {
    const allowed = new Set(Object.keys(p).concat(['event', 'title']));
    const json = JSON.parse(webhookRequest({ url: 'https://hooks.test/aura', format: 'json', token: 'secret-token' }, p, NOW).init.body) as Record<string, unknown>;
    expect(Object.keys(json).every((k) => allowed.has(k))).toBe(true);
    expect(json).toMatchObject({ event: 'aura.page', kind: 'report', lane: 'minors_grooming', minorInvolved: true });

    const ntfy = webhookRequest({ url: 'https://ntfy.sh/aura-ak', format: 'ntfy', token: 'tk' }, p, NOW);
    expect(ntfy.init.headers).toMatchObject({ Authorization: 'Bearer tk', Priority: '5', Click: p.consoleUrl, Title: pageTitle(p, NOW) });

    const slack = JSON.parse(webhookRequest({ url: 'https://hooks.slack.test/x', format: 'slack', token: null }, p, NOW).init.body) as { text: string };
    expect(slack.text).toContain(p.consoleUrl);

    const pd = JSON.parse(webhookRequest({ url: 'https://events.pagerduty.com/v2/enqueue', format: 'pagerduty', token: 'routing-key' }, p, NOW).init.body) as Record<string, unknown>;
    expect(pd).toMatchObject({ routing_key: 'routing-key', event_action: 'trigger', dedup_key: `aura-page-${p.pageId}` });
    expect((pd.payload as Record<string, unknown>).severity).toBe('critical');
  });

  it('webhook delivery: 2xx ok, other status → http_<code>, network failures → a code', async () => {
    const answer = (status: number): FetchLike => async () => ({ ok: status < 300, status, arrayBuffer: async () => new ArrayBuffer(0) });
    const target = { url: 'https://hooks.test/aura', format: 'json' as const, token: null };
    expect(await new WebhookChannel('webhook', 0, target, 1000, answer(204)).send(p)).toMatchObject({ ok: true, httpStatus: 204 });
    expect(await new WebhookChannel('webhook', 0, target, 1000, answer(502)).send(p)).toMatchObject({ ok: false, error: 'http_502' });
    const down: FetchLike = async () => {
      throw new TypeError('fetch failed');
    };
    expect(await new WebhookChannel('webhook', 0, target, 1000, down).send(p)).toMatchObject({ ok: false, error: 'network_error' });
  });

  it('email channel maps SMTP failures to their code', async () => {
    const failing: Mailer = { enabled: true, send: () => Promise.reject(new SmtpError('smtp_550')) };
    expect(await new EmailChannel(failing, ['ak@akvega.test']).send(p)).toMatchObject({ ok: false, error: 'smtp_550' });
  });

  it('channels come from the environment only (no console switch can mute them)', () => {
    expect(buildChannels(parseAdminConfig({}), new DisabledMailer())).toEqual([]);
    const cfg = parseAdminConfig({
      PAGING_WEBHOOK_URL: 'https://ntfy.sh/aura-ak',
      PAGING_WEBHOOK_FORMAT: 'ntfy',
      PAGING_EMAIL_TO: 'ak@akvega.test',
      PAGING_ESCALATION_WEBHOOK_URL: 'https://events.pagerduty.com/v2/enqueue',
      PAGING_ESCALATION_WEBHOOK_FORMAT: 'pagerduty',
      PAGING_ESCALATION_WEBHOOK_TOKEN: 'rk',
    });
    const mailer: Mailer = { enabled: true, send: async () => undefined };
    expect(buildChannels(cfg, mailer).map((c) => [c.name, c.level])).toEqual([
      ['webhook', 0],
      ['email', 0],
      ['escalation_webhook', 1],
    ]);
    // email needs SMTP too
    expect(buildChannels(cfg, new DisabledMailer()).map((c) => c.name)).toEqual(['webhook', 'escalation_webhook']);
  });
});
