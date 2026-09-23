import { Logger } from '@nestjs/common';
import type { DeliveryResult, DeviceTarget, NotificationTransport, PushMessage } from './notification-types';

/**
 * Used when no FCM service account is configured (local dev, CI): records that a push would have been delivered —
 * the type only, never the user id, record id, copy or device token — and reports it as sent, so the global rules
 * (caps, quiet hours, dedupe) behave exactly as in production.
 */
export class LogOnlyNotificationTransport implements NotificationTransport {
  readonly name = 'log-only';
  private readonly logger = new Logger('Notifications');
  /** Count per type since start (handy in tests and the worker log). */
  readonly sent = new Map<string, number>();

  async send(_target: DeviceTarget, message: PushMessage): Promise<DeliveryResult> {
    this.sent.set(message.type, (this.sent.get(message.type) ?? 0) + 1);
    this.logger.log(`push ${message.type} (log-only transport: set FCM_SERVICE_ACCOUNT_JSON to deliver)`);
    return 'sent';
  }
}
