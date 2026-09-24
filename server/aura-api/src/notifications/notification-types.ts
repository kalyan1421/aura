import { isUuid } from '../common/uuid';

/**
 * Server-sent push types (PRD Notifications; F14 Milestone A ships the daily check-in reminder and the date-capsule
 * push). Payloads are content-free — global rule 3: only a type, an opaque id and generic copy; never a mood,
 * quadrant, title, text, pseudonym or date. Add a type here (and to `TYPE_RULES`, the copy catalogue and the app's
 * router) before enqueueing it. `rooms_pool_open`: "Tell me when they open" (06b F5 / 14-states) — once, when a language
 * pool the person waited for opens (pool-waitlist.ts).
 */
export const NOTIFICATION_TYPES = ['capsule_unlocked', 'daily_reminder', 'rooms_pool_open'] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const isNotificationType = (v: unknown): v is NotificationType =>
  (NOTIFICATION_TYPES as readonly unknown[]).includes(v);

/** BullMQ job name on the `notifications` queue (one job = one push to one user). */
export const NOTIFICATION_JOB = 'push';

/** What a `notifications` job carries: who, which type, and the opaque id the app fetches details for. */
export interface NotificationJobData {
  userId: string;
  type: NotificationType;
  /** Opaque record id (e.g. the capsule id), or null. Never content. */
  id: string | null;
}

/** Validates a job's data read back from Redis (anything else is dropped, never logged). */
export function parseNotificationJob(data: unknown): NotificationJobData | null {
  const d = data as Partial<NotificationJobData> | null;
  if (!d || typeof d !== 'object') return null;
  if (!isUuid(d.userId)) return null;
  if (!isNotificationType(d.type)) return null;
  if (d.id !== null && !isUuid(d.id)) return null;
  return { userId: d.userId.toLowerCase(), type: d.type, id: d.id === null ? null : d.id.toLowerCase() };
}

/**
 * Android notification channels (PRD 15-permissions: Reminders, Capsules, Rooms & Lantern Hour, Account — each can
 * be muted on its own). The app creates them; the ids are a contract with apps/mobile (features/push). `rooms` is
 * "Rooms & Lantern Hour" (the pool-open push now; Lantern Hour and gestures later).
 */
export const ANDROID_CHANNELS = ['reminders', 'capsules', 'rooms'] as const;
export type AndroidChannelId = (typeof ANDROID_CHANNELS)[number];

/** One rendered push for one device: content-free data + generic, localized copy. */
export interface PushMessage {
  type: NotificationType;
  /** Opaque record id, sent as `data.id` (the app fetches details after unlock). */
  id: string | null;
  /** Generic copy in the user's app language (discreet mode: the one gentle line). No title: the OS shows "Aura". */
  body: string;
  channelId: AndroidChannelId;
  /** A later push with the same key replaces this one (Android `tag`, APNs `apns-collapse-id`). */
  collapseKey: string;
  /** Not worth delivering after this long (FCM `android.ttl`, `apns-expiration`). */
  ttlSeconds: number;
}

/** One registered install (`public.device_tokens`). The token is never logged. */
export interface DeviceTarget {
  token: string;
  platform: 'ios' | 'android';
}

/**
 * - `sent`: accepted by FCM;
 * - `unregistered`: the token is dead (FCM `UNREGISTERED`) → its row is pruned;
 * - `transient`: try again later (429/5xx/network) — the job is retried when no device got it;
 * - `failed`: permanent for this message (bad credentials, APNs auth, …) — logged, not retried.
 */
export type DeliveryResult = 'sent' | 'unregistered' | 'transient' | 'failed';

/**
 * Delivery backend used by the worker: FCM HTTP v1 when a service account is configured, else log-only
 * (NotificationsModule). The rules (caps, quiet hours, toggles, discreet copy) are applied before it is called.
 */
export interface NotificationTransport {
  readonly name: string;
  send(target: DeviceTarget, message: PushMessage): Promise<DeliveryResult>;
}

/** Nest injection token for the transport (see NotificationsModule). */
export const NOTIFICATION_TRANSPORT = Symbol('NOTIFICATION_TRANSPORT');
