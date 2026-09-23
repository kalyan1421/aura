import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { isUuid } from '../common/uuid';
import { QueuesService } from '../queues/queues.service';
import { NOTIFICATION_JOB, NOTIFICATION_TYPES, type NotificationJobData, type NotificationType } from './notification-types';

export interface EnqueueOptions {
  /**
   * Pushes with the same (user, type, dedupeKey) collapse into one while the key lives (`dedupeTtlMs`), e.g. the
   * unlock date for `capsule_unlocked` ("1/day"). The Redis key is a hash — no user id or date is stored in it.
   */
  dedupeKey?: string;
  /** How long the dedupe key blocks duplicates. Default 36 h (one local day in any zone, plus slack). */
  dedupeTtlMs?: number;
}

export const DEFAULT_DEDUPE_TTL_MS = 36 * 3600_000;

/** Job options: short-lived — the job (and the user id in it) leaves Redis once handled. */
const JOB_OPTS = {
  attempts: 5,
  backoff: { type: 'exponential', delay: 30_000 },
  removeOnComplete: true,
  removeOnFail: { age: 24 * 3600 },
} as const;

/** Opaque dedupe id: sha256 over type, user and key. */
export const notificationDedupeId = (userId: string, type: NotificationType, key: string): string =>
  createHash('sha256').update(`${type}\n${userId.toLowerCase()}\n${key}`).digest('hex');

/**
 * The one way server code asks for a push: `enqueue(userId, type, opaqueId)` puts a job on the `notifications`
 * queue; the worker's NotificationDelivery applies the global rules (toggles, quiet hours, the 2/day cap with
 * precedence, pending deletion) and hands it to the transport (FCM, or log-only without credentials). Callers never
 * build copy or payloads — the type decides the generic, localized copy at delivery time — and never pass content.
 */
@Injectable()
export class NotificationsService {
  constructor(private readonly queues: QueuesService) {}

  async enqueue(userId: string, type: NotificationType, opaqueId: string | null, opts: EnqueueOptions = {}): Promise<void> {
    if (!isUuid(userId)) throw new TypeError('enqueue: userId must be a UUID');
    if (!(NOTIFICATION_TYPES as readonly string[]).includes(type)) throw new TypeError('enqueue: unknown notification type');
    if (opaqueId !== null && !isUuid(opaqueId)) throw new TypeError('enqueue: the opaque id must be a UUID (never content)');
    const data: NotificationJobData = { userId: userId.toLowerCase(), type, id: opaqueId === null ? null : opaqueId.toLowerCase() };
    await this.queues.queue('notifications').add(NOTIFICATION_JOB, data, {
      ...JOB_OPTS,
      ...(opts.dedupeKey !== undefined
        ? { deduplication: { id: notificationDedupeId(userId, type, opts.dedupeKey), ttl: opts.dedupeTtlMs ?? DEFAULT_DEDUPE_TTL_MS } }
        : {}),
    });
  }
}
