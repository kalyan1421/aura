import { Module } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { NotificationDelivery } from './delivery.service';
import { createNotificationTransport } from './fcm.transport';
import { NotificationDispatcher } from './notification-dispatcher';
import { NotificationPrefsSyncHandler } from './notification-prefs';
import { NOTIFICATION_TRANSPORT, type NotificationTransport } from './notification-types';
import { NotificationsService } from './notifications.service';
import { ReminderScheduler } from './reminder.service';

/**
 * Push notifications (PRD 12-notifications; F14 Milestone A: daily check-in reminder + date capsule unlocked).
 * - `NotificationsService.enqueue(userId, type, opaqueId, { dedupeKey })` — producer (API and worker).
 * - `NotificationPrefsSyncHandler` — sync entity `notification_prefs` (SyncModule), re-plans the daily reminder.
 * - `NotificationDispatcher` — the worker's `notifications` queue processor: `push` → `NotificationDelivery` (global
 *   rules, then `NOTIFICATION_TRANSPORT`); `reminder-sweep` / `reminder-reconcile` → `ReminderScheduler`.
 * - Transport: FCM HTTP v1 when `FCM_SERVICE_ACCOUNT_JSON` / `FCM_SERVICE_ACCOUNT_FILE` is set, else log-only.
 * DbService / QueuesService / AppConfig come from global modules.
 */
@Module({
  providers: [
    NotificationsService,
    NotificationDelivery,
    ReminderScheduler,
    NotificationDispatcher,
    NotificationPrefsSyncHandler,
    // AppConfig first: it merges `.env` into process.env before the service account is read.
    {
      provide: NOTIFICATION_TRANSPORT,
      useFactory: (_config: AppConfig): NotificationTransport => createNotificationTransport(),
      inject: [AppConfig],
    },
  ],
  exports: [NotificationsService, NotificationDispatcher, NotificationDelivery, ReminderScheduler, NotificationPrefsSyncHandler],
})
export class NotificationsModule {}
