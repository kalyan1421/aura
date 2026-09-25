import { Injectable } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { awardKeepsakes, listOwnKeepsakes, type OwnKeepsake } from './award';

/**
 * F13 keepsakes for the caller (contracts/api/v1-keepsakes.md). There is deliberately no method that takes another
 * person's id from a request: keepsakes are never visible to strangers (DS-10, CI-8).
 */
@Injectable()
export class KeepsakesService {
  constructor(private readonly db: DbService) {}

  /** Awards anything newly reached (idempotent, from records NestJS already holds), then returns the caller's own. */
  mine(userId: string, now = new Date()): Promise<{ keepsakes: OwnKeepsake[] }> {
    return this.db.withTx(async (tx) => {
      await awardKeepsakes(tx, userId, now);
      return { keepsakes: await listOwnKeepsakes(tx, userId) };
    });
  }
}
