import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import { auraDay } from '../rules';
import { ProgressionRepository } from './progression.repository';
import { computeSnapshot, hueWindow, type Snapshot } from './snapshot';

/**
 * Derives avatar/streak state from the append-only ledger + active days (DS-5).
 * `snapshot` is read-only; `recompute` also persists avatar_state + streak_state.
 */
@Injectable()
export class ProgressionService {
  constructor(private readonly repo: ProgressionRepository) {}

  async snapshot(q: Queryable, userId: string, tz: string, now = new Date()): Promise<Snapshot> {
    const today = auraDay(now, tz);
    const inputs = await this.repo.loadInputs(q, userId, today, hueWindow(today).from);
    return computeSnapshot(inputs, now, tz);
  }

  async recompute(q: Queryable, userId: string, tz: string, now = new Date()): Promise<Snapshot> {
    const snap = await this.snapshot(q, userId, tz, now);
    await this.repo.persist(q, userId, snap);
    return snap;
  }
}
