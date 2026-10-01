import IORedis, { type RedisOptions } from 'ioredis';

/** `redis[s]://[user[:pass]@]host[:port][/db]` → ioredis options usable by BullMQ. */
export function redisOptionsFromUrl(url: string): RedisOptions {
  const u = new URL(url);
  const db = u.pathname && u.pathname !== '/' ? Number(u.pathname.slice(1)) : 0;
  return {
    host: u.hostname,
    port: u.port ? Number(u.port) : 6379,
    username: u.username ? decodeURIComponent(u.username) : undefined,
    password: u.password ? decodeURIComponent(u.password) : undefined,
    db: Number.isFinite(db) ? db : 0,
    tls: u.protocol === 'rediss:' ? {} : undefined,
    maxRetriesPerRequest: null, // required by BullMQ blocking connections
    enableReadyCheck: true,
  };
}

const shared = new Map<string, IORedis>();

/**
 * ONE ioredis client per process (and URL) for every BullMQ Worker. A Worker given Redis *options* opens its own
 * command + blocking connections (2 each); given a client it only duplicates the blocking one (1 each). With 12 workers
 * that is 24 → 13 connections per instance. It matters on Render's Free Key Value (small connection cap): during a
 * deploy the old and new instance run together, and doubling 24+ connections made every deploy of this service time
 * out at the health check (Redis resets, `/health` 503). `maxRetriesPerRequest: null` is what BullMQ requires here.
 */
export function sharedWorkerConnection(url: string): IORedis {
  let c = shared.get(url);
  if (!c) {
    c = new IORedis({ ...redisOptionsFromUrl(url), keepAlive: 10_000 });
    c.on('error', () => undefined); // BullMQ's Workers report connection errors themselves; avoid unhandled 'error' events
    shared.set(url, c);
  }
  return c;
}

/** Closes and forgets the shared worker clients (app shutdown / tests). */
export function closeSharedWorkerConnections(): void {
  for (const c of shared.values()) c.disconnect();
  shared.clear();
}
