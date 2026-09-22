import { Injectable } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { isQuadrant, type Quadrant } from '../rules';

interface Catalogue {
  moods: ReadonlyMap<string, Quadrant>;
  presetHabits: ReadonlySet<string>;
  loadedAt: number;
}

const TTL_MS = 5 * 60_000;

/** Read-through cache of the public catalogues (moods, preset habits) seeded from contracts/moods.json. */
@Injectable()
export class CatalogueService {
  private cache: Catalogue | null = null;
  private inflight: Promise<Catalogue> | null = null;

  constructor(private readonly db: DbService) {}

  private async load(): Promise<Catalogue> {
    const [moods, habits] = await Promise.all([
      this.db.query<{ id: string; quadrant: string }>('select id, quadrant from public.moods'),
      this.db.query<{ key: string }>('select key from public.preset_habits'),
    ]);
    const m = new Map<string, Quadrant>();
    for (const r of moods.rows) if (isQuadrant(r.quadrant)) m.set(r.id, r.quadrant);
    return { moods: m, presetHabits: new Set(habits.rows.map((r) => r.key)), loadedAt: Date.now() };
  }

  private async get(): Promise<Catalogue> {
    // An empty catalogue (seed not run yet) is never cached, so seeding takes effect immediately.
    if (this.cache && Date.now() - this.cache.loadedAt < TTL_MS && this.cache.moods.size > 0) return this.cache;
    this.inflight ??= this.load().finally(() => (this.inflight = null));
    this.cache = await this.inflight;
    return this.cache;
  }

  async moodQuadrant(moodId: string): Promise<Quadrant | undefined> {
    return (await this.get()).moods.get(moodId);
  }

  async isPresetHabit(key: string): Promise<boolean> {
    return (await this.get()).presetHabits.has(key);
  }
}
