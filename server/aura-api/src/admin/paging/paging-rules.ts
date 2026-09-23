/**
 * On-call paging rules (PRD 19 "Single operator and on-call", REQ-ADM-05 / REQ-ADM-15), pure and unit-tested:
 * round 0 goes out at once on the level-0 channels (push-style webhook + email); from `escalateAfter` (5 min) without
 * an acknowledgement every round also uses the level-1 channel (the "voice call" webhook, e.g. PagerDuty / Twilio);
 * rounds repeat every `repeat` (5 min) until acknowledged or the item is closed. A round where nothing was delivered
 * is retried after a minute, and every channel gets a few quick retries inside a round.
 */
export type PageKind = 'legal_order' | 'grievance' | 'report' | 'test';
export type ChannelName = 'webhook' | 'escalation_webhook' | 'email';

export interface PagePayload {
  pageId: string;
  kind: PageKind;
  reason: string;
  lane: string | null;
  minorInvolved: boolean;
  isTest: boolean;
  /** Ticket id of an order / grievance (not content). */
  ticket: string | null;
  dueAt: string | null;
  /** Minutes since the item arrived (or the test page was raised). */
  waitingMinutes: number;
  round: number;
  escalationLevel: 0 | 1;
  consoleUrl: string;
}

export interface DeliveryResult {
  ok: boolean;
  httpStatus: number | null;
  /** A short code (`http_503`, `timeout`, `smtp_550`, …), never a response body. */
  error: string | null;
  latencyMs: number;
}

export interface PageChannel {
  readonly name: ChannelName;
  /** 0 = from the first round; 1 = escalation, from `escalateAfter`. */
  readonly level: 0 | 1;
  send(p: PagePayload): Promise<DeliveryResult>;
}

export interface DeliveryAttempt {
  channel: ChannelName;
  level: 0 | 1;
  attempt: number;
  result: DeliveryResult;
}

const MIN = 60_000;

export function escalationLevel(round: number, pageCreatedAt: Date, now: Date, escalateAfterMinutes: number): 0 | 1 {
  if (round === 0) return 0;
  return now.getTime() - pageCreatedAt.getTime() >= escalateAfterMinutes * MIN ? 1 : 0;
}

export function channelsFor(channels: readonly PageChannel[], level: 0 | 1): PageChannel[] {
  return channels.filter((c) => c.level <= level);
}

/** Next round: the repeat interval after a delivered round, one minute (at most) after a round that reached nobody. */
export function nextAttemptAt(now: Date, delivered: boolean, repeatMinutes: number): Date {
  return new Date(now.getTime() + (delivered ? repeatMinutes : Math.min(1, repeatMinutes)) * MIN);
}

export const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

/** One channel: first try plus retries (waiting `delays[i]` before try i+1), stopping at the first success. */
export async function deliverWithRetry(
  channel: PageChannel,
  payload: PagePayload,
  delays: readonly number[],
  wait: (ms: number) => Promise<void> = sleep,
): Promise<DeliveryAttempt[]> {
  const attempts: DeliveryAttempt[] = [];
  const tries = Math.max(1, delays.length);
  for (let i = 0; i < tries; i++) {
    if (i > 0 && delays[i] > 0) await wait(delays[i]);
    let result: DeliveryResult;
    try {
      result = await channel.send(payload);
    } catch {
      result = { ok: false, httpStatus: null, error: 'channel_error', latencyMs: 0 };
    }
    attempts.push({ channel: channel.name, level: channel.level, attempt: i + 1, result });
    if (result.ok) break;
  }
  return attempts;
}

/** A whole round: every channel of the level in parallel, each with its retries. */
export async function runRound(
  channels: readonly PageChannel[],
  level: 0 | 1,
  payload: PagePayload,
  delays: readonly number[],
  wait: (ms: number) => Promise<void> = sleep,
): Promise<{ attempts: DeliveryAttempt[]; delivered: boolean }> {
  const selected = channelsFor(channels, level);
  const perChannel = await Promise.all(selected.map((c) => deliverWithRetry(c, payload, delays, wait)));
  const attempts = perChannel.flat();
  return { attempts, delivered: attempts.some((a) => a.result.ok) };
}

// ------------------------------------------------------------------------------------------------ copy (no content)
const KIND_LABEL: Record<PageKind, string> = {
  legal_order: 'Legal order',
  grievance: 'Grievance',
  report: 'Report',
  test: 'Test page',
};

const LANE_LABEL: Record<string, string> = {
  crisis: 'Crisis',
  minors_grooming: 'Minors & grooming',
  harassment: 'Harassment',
  spam: 'Spam / other',
};

function minutesText(m: number): string {
  const abs = Math.abs(m);
  const h = Math.floor(abs / 60);
  const mm = abs % 60;
  return h > 0 ? `${h} h ${mm} min` : `${mm} min`;
}

/** One-line ASCII title (it also travels as an HTTP header), e.g. "TEST | Legal order LO-7K3F9Q2M | due in 2 h 58 min". */
export function pageTitle(p: PagePayload, now: Date = new Date()): string {
  const parts: string[] = [];
  if (p.isTest) parts.push('TEST');
  const kind = p.kind === 'report' && p.lane ? `${LANE_LABEL[p.lane] ?? p.lane} report` : KIND_LABEL[p.kind];
  parts.push(p.ticket ? `${kind} ${p.ticket}` : kind);
  if (p.minorInvolved) parts.push('minor involved');
  if (p.dueAt) {
    const left = Math.floor((Date.parse(p.dueAt) - now.getTime()) / MIN);
    parts.push(left >= 0 ? `due in ${minutesText(left)}` : `OVERDUE by ${minutesText(left)}`);
  } else {
    parts.push(`waiting ${minutesText(p.waitingMinutes)}`);
  }
  return parts.join(' | ');
}

/** Plain-text body for email / ntfy. */
export function pageLines(p: PagePayload, now: Date = new Date()): string[] {
  return [
    pageTitle(p, now),
    `Waiting: ${minutesText(p.waitingMinutes)}${p.round > 0 ? ` | repeat ${p.round}` : ''}${p.escalationLevel > 0 ? ' | escalated' : ''}`,
    `Open and acknowledge: ${p.consoleUrl}`,
    'Pages never contain content. Acknowledge in the console to stop the repeats.',
  ];
}
