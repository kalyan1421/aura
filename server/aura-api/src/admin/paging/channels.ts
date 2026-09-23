import type { AdminConfig, WebhookTarget } from '../admin-config';
import { mailErrorCode, type Mailer } from '../mail/mailer';
import { pageLines, pageTitle, type ChannelName, type DeliveryResult, type PageChannel, type PagePayload } from './paging-rules';

/**
 * Paging channels. Level 0: a push-style webhook (ntfy topic on AK's phone, Slack, or any JSON receiver) and SMTP email.
 * Level 1 (after 5 minutes unacknowledged): an escalation webhook, e.g. PagerDuty high-urgency or a Twilio Studio
 * flow that places the voice call from a number on AK's Do Not Disturb allow-list. Payloads carry lane, minor flag,
 * ticket id, deadline and wait time — never content (PRD 19).
 */
export interface WebhookRequest {
  url: string;
  init: { method: 'POST'; headers: Record<string, string>; body: string };
}

/** Pure: the HTTP request for one page on one webhook (unit-tested per format). */
export function webhookRequest(target: WebhookTarget, p: PagePayload, now: Date = new Date()): WebhookRequest {
  const title = pageTitle(p, now);
  const auth: Record<string, string> = target.token && target.format !== 'pagerduty' ? { Authorization: `Bearer ${target.token}` } : {};
  switch (target.format) {
    case 'ntfy':
      return {
        url: target.url,
        init: {
          method: 'POST',
          headers: {
            ...auth,
            'Content-Type': 'text/plain; charset=utf-8',
            Title: title,
            Priority: p.isTest ? '4' : '5',
            Tags: p.isTest ? 'test_tube' : 'rotating_light',
            Click: p.consoleUrl,
          },
          body: pageLines(p, now).slice(1).join('\n'),
        },
      };
    case 'slack':
      return {
        url: target.url,
        init: {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ text: `${p.isTest ? ':test_tube:' : ':rotating_light:'} ${title}\n<${p.consoleUrl}|Open in the console>` }),
        },
      };
    case 'pagerduty':
      return {
        url: target.url,
        init: {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            routing_key: target.token,
            event_action: 'trigger',
            dedup_key: `aura-page-${p.pageId}`,
            payload: {
              summary: `Aura: ${title}`.slice(0, 1024),
              severity: p.isTest ? 'info' : 'critical',
              source: 'aura-admin',
              component: p.kind,
              custom_details: {
                kind: p.kind,
                reason: p.reason,
                lane: p.lane,
                minorInvolved: p.minorInvolved,
                ticket: p.ticket,
                dueAt: p.dueAt,
                waitingMinutes: p.waitingMinutes,
                round: p.round,
              },
            },
            links: [{ href: p.consoleUrl, text: 'Open in the Aura console' }],
          }),
        },
      };
    default:
      return {
        url: target.url,
        init: {
          method: 'POST',
          headers: { ...auth, 'Content-Type': 'application/json' },
          body: JSON.stringify({ event: 'aura.page', title, ...p }),
        },
      };
  }
}

export type FetchLike = (url: string, init: RequestInit) => Promise<{ ok: boolean; status: number; arrayBuffer(): Promise<ArrayBuffer> }>;

export class WebhookChannel implements PageChannel {
  constructor(
    readonly name: Extract<ChannelName, 'webhook' | 'escalation_webhook'>,
    readonly level: 0 | 1,
    private readonly target: WebhookTarget,
    private readonly timeoutMs: number,
    private readonly fetchImpl: FetchLike = fetch as unknown as FetchLike,
  ) {}

  async send(p: PagePayload): Promise<DeliveryResult> {
    const t0 = Date.now();
    const { url, init } = webhookRequest(this.target, p);
    try {
      const res = await this.fetchImpl(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(this.timeoutMs) });
      await res.arrayBuffer().catch(() => undefined); // drain; the body is never stored
      return res.ok
        ? { ok: true, httpStatus: res.status, error: null, latencyMs: Date.now() - t0 }
        : { ok: false, httpStatus: res.status, error: `http_${res.status}`, latencyMs: Date.now() - t0 };
    } catch (e) {
      const name = (e as Error)?.name;
      return { ok: false, httpStatus: null, error: name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network_error', latencyMs: Date.now() - t0 };
    }
  }
}

export class EmailChannel implements PageChannel {
  readonly name = 'email' as const;
  readonly level = 0 as const;

  constructor(
    private readonly mailer: Mailer,
    private readonly to: readonly string[],
  ) {}

  async send(p: PagePayload): Promise<DeliveryResult> {
    const t0 = Date.now();
    try {
      await this.mailer.send({ to: this.to, subject: `[Aura page] ${pageTitle(p)}`, text: pageLines(p).join('\n'), autoSubmitted: true });
      return { ok: true, httpStatus: null, error: null, latencyMs: Date.now() - t0 };
    } catch (e) {
      return { ok: false, httpStatus: null, error: mailErrorCode(e), latencyMs: Date.now() - t0 };
    }
  }
}

export const PAGE_CHANNELS = Symbol('PAGE_CHANNELS');

/** The configured channels (docs/setup/admin-console.md "Paging"). An empty list is logged as `no_channels`. */
export function buildChannels(config: AdminConfig, mailer: Mailer, fetchImpl?: FetchLike): PageChannel[] {
  const out: PageChannel[] = [];
  const p = config.paging;
  if (p.webhook) out.push(new WebhookChannel('webhook', 0, p.webhook, p.timeoutMs, fetchImpl));
  if (p.emailTo.length > 0 && mailer.enabled) out.push(new EmailChannel(mailer, p.emailTo));
  if (p.escalationWebhook) out.push(new WebhookChannel('escalation_webhook', 1, p.escalationWebhook, p.timeoutMs, fetchImpl));
  return out;
}
