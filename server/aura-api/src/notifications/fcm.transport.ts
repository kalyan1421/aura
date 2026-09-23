import { readFileSync } from 'node:fs';
import { Logger } from '@nestjs/common';
import { importPKCS8, SignJWT } from 'jose';
import { LogOnlyNotificationTransport } from './log-only.transport';
import type { DeliveryResult, DeviceTarget, NotificationTransport, PushMessage } from './notification-types';

/**
 * FCM HTTP v1 delivery (APNs through FCM), authenticated with a Google service account (OAuth 2.0 JWT bearer, signed
 * with `jose`; no firebase-admin dependency). Configuration — the worker reads one of:
 *   - `FCM_SERVICE_ACCOUNT_JSON`: the service-account JSON itself, or base64 of it;
 *   - `FCM_SERVICE_ACCOUNT_FILE` (or `GOOGLE_APPLICATION_CREDENTIALS`): a path to that JSON file;
 *   - optional `FCM_PROJECT_ID` to override the file's `project_id`.
 * Nothing configured (or unusable) → the log-only transport; the worker never crashes over it.
 *
 * Every message is content-free (PRD 12 rule 3): `data = { type, id? }` plus one generic line. Android: channel per
 * type, `VISIBILITY_PRIVATE` (a secure lock screen shows only the system's generic public version — "Aura", contents
 * hidden), a `tag` so repeats replace each other. iOS: alert with the same generic line, no title, `apns-collapse-id`
 * (for a capsule = its local notice id, so the push replaces the app's own notice), and an expiry. Tokens, ids and
 * copy are never logged; errors are logged by HTTP status and FCM error code only.
 */
export const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
export const GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token';
export const FCM_SEND_TIMEOUT_MS = 10_000;
/** Access tokens live 1 h; refresh 5 min early. */
const TOKEN_SLACK_MS = 5 * 60_000;

export interface FcmServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
  tokenUri: string;
}

export type ServiceAccountLoad = { account: FcmServiceAccount; problem: null } | { account: null; problem: string | null };

const nonEmpty = (v: string | undefined): string | undefined => (v && v.trim() !== '' ? v.trim() : undefined);

/** Parses the service account from the environment. Never throws; problems are described without values. */
export function loadFcmServiceAccount(
  env: NodeJS.ProcessEnv = process.env,
  readFile: (path: string) => string = (p) => readFileSync(p, 'utf8'),
): ServiceAccountLoad {
  const inline = nonEmpty(env.FCM_SERVICE_ACCOUNT_JSON);
  const path = nonEmpty(env.FCM_SERVICE_ACCOUNT_FILE) ?? nonEmpty(env.GOOGLE_APPLICATION_CREDENTIALS);
  if (!inline && !path) return { account: null, problem: null };
  let raw: string;
  if (inline) {
    raw = inline.startsWith('{') ? inline : Buffer.from(inline, 'base64').toString('utf8');
  } else {
    try {
      raw = readFile(path as string);
    } catch {
      return { account: null, problem: 'the service-account file cannot be read' };
    }
  }
  let json: Record<string, unknown>;
  try {
    json = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { account: null, problem: 'the service account is not valid JSON' };
  }
  const str = (k: string): string | undefined => (typeof json[k] === 'string' && json[k] !== '' ? (json[k] as string) : undefined);
  if (json.type !== undefined && json.type !== 'service_account') return { account: null, problem: 'not a service_account key' };
  const projectId = nonEmpty(env.FCM_PROJECT_ID) ?? str('project_id');
  const clientEmail = str('client_email');
  // Keys pasted into env files often carry literal "\n" sequences.
  const privateKey = str('private_key')?.replace(/\\n/g, '\n');
  if (!projectId || !clientEmail || !privateKey) {
    return { account: null, problem: 'project_id, client_email and private_key are required' };
  }
  if (!privateKey.includes('BEGIN PRIVATE KEY')) return { account: null, problem: 'private_key is not a PKCS#8 PEM key' };
  return { account: { projectId, clientEmail, privateKey, tokenUri: str('token_uri') ?? GOOGLE_TOKEN_URI }, problem: null };
}

/** The FCM v1 `message` for one install. Pure (tested); `nowMs` sets the APNs expiry. */
export function buildFcmMessage(target: DeviceTarget, m: PushMessage, nowMs: number): Record<string, unknown> {
  const data: Record<string, string> = { type: m.type };
  if (m.id) data.id = m.id;
  return {
    token: target.token,
    data,
    notification: { body: m.body },
    android: {
      priority: 'HIGH',
      ttl: `${m.ttlSeconds}s`,
      collapse_key: m.collapseKey,
      notification: {
        channel_id: m.channelId,
        visibility: 'PRIVATE',
        tag: m.collapseKey,
        default_sound: true,
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
        'apns-collapse-id': m.collapseKey,
        'apns-expiration': String(Math.floor(nowMs / 1000) + m.ttlSeconds),
      },
      payload: { aps: { alert: { body: m.body }, sound: 'default', 'thread-id': m.channelId } },
    },
  };
}

interface FcmErrorBody {
  error?: {
    status?: string;
    details?: { '@type'?: string; errorCode?: string }[];
  };
}

/** FCM v1 error → delivery result. Only an explicit `UNREGISTERED` prunes a token (never a guess from a status). */
export function classifyFcmError(status: number, body: unknown): Exclude<DeliveryResult, 'sent'> {
  const details = (body as FcmErrorBody | null)?.error?.details ?? [];
  if (details.some((d) => d.errorCode === 'UNREGISTERED')) return 'unregistered';
  if (status === 429 || status >= 500) return 'transient';
  return 'failed'; // 400 INVALID_ARGUMENT, 401 (after a refresh), 403 SENDER_ID_MISMATCH / THIRD_PARTY_AUTH_ERROR, 404
}

/** The error code FCM put in the body (for logs), never anything else from it. */
function fcmCode(body: unknown): string {
  const e = (body as FcmErrorBody | null)?.error;
  return e?.details?.find((d) => d.errorCode)?.errorCode ?? e?.status ?? 'unknown';
}

class OAuthError extends Error {
  constructor(readonly permanent: boolean, status: number) {
    super(`oauth token request failed: HTTP ${status}`);
    this.name = 'OAuthError';
  }
}

export class FcmTransport implements NotificationTransport {
  readonly name = 'fcm';
  private readonly logger = new Logger('FCM');
  private cached: { token: string; expiresAt: number } | null = null;
  private inflight: Promise<string> | null = null;

  constructor(
    private readonly account: FcmServiceAccount,
    private readonly http: typeof fetch = fetch,
    private readonly clock: () => number = Date.now,
  ) {}

  get projectId(): string {
    return this.account.projectId;
  }

  async send(target: DeviceTarget, message: PushMessage): Promise<DeliveryResult> {
    try {
      let res = await this.post(await this.accessToken(), target, message);
      if (res.status === 401) {
        this.cached = null; // expired or revoked: one fresh token, one retry
        res = await this.post(await this.accessToken(), target, message);
      }
      if (res.ok) {
        await res.arrayBuffer().catch(() => undefined);
        return 'sent';
      }
      const body: unknown = await res.json().catch(() => null);
      const result = classifyFcmError(res.status, body);
      if (result !== 'unregistered') this.logger.warn(`send ${message.type}: HTTP ${res.status} ${fcmCode(body)} → ${result}`);
      return result;
    } catch (err) {
      if (err instanceof OAuthError) {
        this.logger.warn(err.message);
        return err.permanent ? 'failed' : 'transient';
      }
      this.logger.warn(`send ${message.type}: ${err instanceof Error ? err.name : 'error'} → transient`);
      return 'transient'; // network error, timeout
    }
  }

  private post(accessToken: string, target: DeviceTarget, message: PushMessage): Promise<Response> {
    return this.http(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.account.projectId)}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: buildFcmMessage(target, message, this.clock()) }),
      signal: AbortSignal.timeout(FCM_SEND_TIMEOUT_MS),
    });
  }

  /** A cached OAuth access token, refreshed before it expires (one request at a time). */
  private async accessToken(): Promise<string> {
    const c = this.cached;
    if (c && c.expiresAt - TOKEN_SLACK_MS > this.clock()) return c.token;
    this.inflight ??= this.fetchToken().finally(() => {
      this.inflight = null;
    });
    return this.inflight;
  }

  private async fetchToken(): Promise<string> {
    const nowSec = Math.floor(this.clock() / 1000);
    const assertion = await new SignJWT({ scope: FCM_SCOPE })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(this.account.clientEmail)
      .setAudience(this.account.tokenUri)
      .setIssuedAt(nowSec)
      .setExpirationTime(nowSec + 3600)
      .sign(await importPKCS8(this.account.privateKey, 'RS256'));
    const res = await this.http(this.account.tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }).toString(),
      signal: AbortSignal.timeout(FCM_SEND_TIMEOUT_MS),
    });
    if (!res.ok) {
      await res.arrayBuffer().catch(() => undefined);
      // 400/401 = the key or the clock is wrong: retrying won't help.
      throw new OAuthError(res.status >= 400 && res.status < 500 && res.status !== 429, res.status);
    }
    const j = (await res.json()) as { access_token?: unknown; expires_in?: unknown };
    if (typeof j.access_token !== 'string') throw new OAuthError(false, res.status);
    const ttl = typeof j.expires_in === 'number' ? j.expires_in : 3600;
    this.cached = { token: j.access_token, expiresAt: this.clock() + ttl * 1000 };
    return j.access_token;
  }
}

/**
 * The worker's transport: FCM when a usable service account is configured, else log-only. A present-but-broken
 * configuration is reported (without values) and falls back to log-only rather than crashing.
 */
export function createNotificationTransport(env: NodeJS.ProcessEnv = process.env): NotificationTransport {
  const r = loadFcmServiceAccount(env);
  if (r.account) return new FcmTransport(r.account);
  if (r.problem) new Logger('Notifications').warn(`FCM service account unusable (${r.problem}); pushes are log-only`);
  return new LogOnlyNotificationTransport();
}
