import { Injectable, Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import { GESTURES_SWEEP_JOB, GesturesPushSweep } from './gestures-push';
import { SCHEDULE_RECONCILE_JOB, SCHEDULE_SWEEP_JOB, ScheduleSweep } from './schedules';
import { WELCOME_BACK_SWEEP_JOB, WelcomeBackSweep } from './welcome-back';

/**
 * The worker's F14 Milestone B jobs on the `notifications` queue (NotificationDispatcher hands over the names it
 * doesn't know): `schedule-sweep` / `schedule-reconcile` (wind-down reminder, Lantern Hour, habit nudges —
 * schedules.ts), `welcome-back-sweep` (welcome-back.ts) and `gestures-sweep` (gestures-push.ts). Each enqueues `push`
 * jobs, which NotificationDelivery sends under the global rules.
 */
@Injectable()
export class MilestoneBJobs {
  private readonly logger = new Logger('Notifications');

  constructor(
    private readonly schedules: ScheduleSweep,
    private readonly welcomeBack: WelcomeBackSweep,
    private readonly gestures: GesturesPushSweep,
  ) {}

  static readonly JOB_NAMES: readonly string[] = [SCHEDULE_SWEEP_JOB, SCHEDULE_RECONCILE_JOB, WELCOME_BACK_SWEEP_JOB, GESTURES_SWEEP_JOB];

  async ensureSchedulers(): Promise<void> {
    await this.schedules.ensureSchedulers();
    await this.welcomeBack.ensureScheduler();
    await this.gestures.ensureScheduler();
  }

  /** Runs `job` when it is one of these; false otherwise (the dispatcher then logs it as unknown). */
  async handle(job: Job, now = new Date()): Promise<boolean> {
    switch (job.name) {
      case SCHEDULE_SWEEP_JOB:
        await this.schedules.sweep(now);
        return true;
      case SCHEDULE_RECONCILE_JOB: {
        const n = await this.schedules.reconcile(now);
        if (n) this.logger.log(`schedule reconcile: re-planned ${n}`);
        return true;
      }
      case WELCOME_BACK_SWEEP_JOB:
        await this.welcomeBack.sweep(now);
        return true;
      case GESTURES_SWEEP_JOB:
        await this.gestures.sweep(now);
        return true;
      default:
        return false;
    }
  }
}
