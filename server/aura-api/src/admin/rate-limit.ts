import { createHmac, hkdfSync } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { QueuesService } from '../queues/queues.service';

/**
 * Fixed-window counters in Redis for the public, unauthenticated console-adjacent routes (grievance form, legal-order
 * intake) and for de-duplicating "denied" audit rows. Client addresses are never stored: keys hold an HMAC of the IP
 * under a key derived from the master key, and expire with their window. If Redis is unavailable the limiter lets the
 * request through (a statutory grievance channel must not go dark because a cache is down) and logs it.
 */
@Injectable()
export class RateLimiter {
  private readonly logger = new Logger('AdminRateLimit');
  private readonly key: Buffer;

  constructor(
    private readonly queues: QueuesService,
    config: AppConfig,
  ) {
    this.key = Buffer.from(hkdfSync('sha256', config.masterKey, Buffer.alloc(0), 'aura/admin-rate-limit/v1', 32));
  }

  /** Opaque, non-reversible bucket id for a client address (or any other identifier). */
  bucket(value: string): string {
    return createHmac('sha256', this.key).update(value).digest('hex').slice(0, 32);
  }

  /** Counts one hit; true while the window's count is within `limit`. */
  async hit(name: string, limit: number, windowSeconds: number): Promise<boolean> {
    const k = `aura:rl:${name}`;
    try {
      const res = await this.queues.redis.multi().incr(k).expire(k, windowSeconds, 'NX').exec();
      const n = Number(res?.[0]?.[1] ?? 0);
      return n <= limit;
    } catch (e) {
      this.logger.warn(`rate limiter unavailable (${(e as Error).name}); allowing`);
      return true;
    }
  }

  /** True the first time `name` is seen within `ttlSeconds` (SET NX). Errors count as "first". */
  async once(name: string, ttlSeconds: number): Promise<boolean> {
    try {
      return (await this.queues.redis.set(`aura:once:${name}`, '1', 'EX', ttlSeconds, 'NX')) === 'OK';
    } catch {
      return true;
    }
  }
}
