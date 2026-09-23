import { Controller, Get, HttpStatus, Module, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AdminWorkerModule } from './admin/paging/paging.worker';
import { CapsuleUnlockModule } from './capsules/capsule-unlock.module';
import { ConfigModule } from './config/config.module';
import { DbModule } from './db/db.module';
import { DbService } from './db/db.service';
import { probe } from './health/health.controller';
import { NotificationsModule } from './notifications/notifications.module';
import { QueuesModule } from './queues/queues.module';
import { QueuesService } from './queues/queues.service';
import { WorkerHostService } from './queues/worker-host.service';

/** `GET /health` on :3311 — redis, db, worker state and the last heartbeat. */
@Controller('health')
class WorkerHealthController {
  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly host: WorkerHostService,
  ) {}

  @Get()
  async health(@Res() res: Response): Promise<void> {
    const [db, redis] = await Promise.all([probe(() => this.db.ping()), probe(() => this.queues.ping())]);
    const workers = this.host.running ? 'ok' : 'error';
    const ok = db === 'ok' && redis === 'ok' && workers === 'ok';
    res.status(ok ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE).json({
      status: ok ? 'ok' : 'error',
      db,
      redis,
      workers,
      queues: this.host.queueNames,
      lastHeartbeatAt: this.host.lastHeartbeatAt?.toISOString() ?? null,
    });
  }
}

/** Worker process (src/worker.ts): BullMQ processors + tiny health endpoint. No auth, no API routes. */
@Module({
  // AdminWorkerModule: the admin console's pager (30 s tick, repeats / escalation, weekly test page).
  imports: [ConfigModule, DbModule, QueuesModule, NotificationsModule, CapsuleUnlockModule, AdminWorkerModule],
  controllers: [WorkerHealthController],
  providers: [WorkerHostService],
})
export class WorkerModule {}
