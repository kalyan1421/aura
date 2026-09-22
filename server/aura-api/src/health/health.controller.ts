import { Controller, Get, HttpStatus, Res } from '@nestjs/common';
import type { Response } from 'express';
import { Public } from '../auth/public.decorator';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';

type Check = 'ok' | 'error';

export async function probe(fn: () => Promise<void>, timeoutMs = 2000): Promise<Check> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      fn(),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout')), timeoutMs);
      }),
    ]);
    return 'ok';
  } catch {
    return 'error';
  } finally {
    if (timer) clearTimeout(timer);
  }
}

/** `GET /health` → `200 { status, db, redis }` (503 when a dependency is down). No auth. */
@Controller('health')
export class HealthController {
  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
  ) {}

  @Public()
  @Get()
  async health(@Res() res: Response): Promise<void> {
    const [db, redis] = await Promise.all([probe(() => this.db.ping()), probe(() => this.queues.ping())]);
    const ok = db === 'ok' && redis === 'ok';
    res.status(ok ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE).json({ status: ok ? 'ok' : 'error', db, redis });
  }
}
