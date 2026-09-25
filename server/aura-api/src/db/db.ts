import { Pool, types, type PoolClient, type QueryResult, type QueryResultRow } from 'pg';

// DATE → keep 'YYYY-MM-DD' strings (never shift through a JS Date in the host tz).
types.setTypeParser(1082, (v: string) => v);

/** Anything that can run a query: the pool or a transaction. Repositories take this. */
export interface Queryable {
  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>>;
}

/** SQLSTATE of a pg error, if any. */
export function pgCode(err: unknown): string | undefined {
  const c = (err as { code?: unknown })?.code;
  return typeof c === 'string' && /^[0-9A-Z]{5}$/.test(c) ? c : undefined;
}

export function pgConstraint(err: unknown): string | undefined {
  const c = (err as { constraint?: unknown })?.constraint;
  return typeof c === 'string' ? c : undefined;
}

/** A transaction bound to one pooled client, with nested savepoints. */
export class Tx implements Queryable {
  private spSeq = 0;

  constructor(private readonly client: PoolClient) {}

  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>> {
    return this.client.query<R>(text, params);
  }

  /**
   * Run `fn` inside `SAVEPOINT`. On error the savepoint is rolled back (the outer
   * transaction stays usable) and the error is rethrown for the caller to classify.
   */
  async savepoint<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    const name = `sp_${++this.spSeq}`;
    await this.client.query(`SAVEPOINT ${name}`);
    try {
      const out = await fn(this);
      await this.client.query(`RELEASE SAVEPOINT ${name}`);
      return out;
    } catch (err) {
      await this.client.query(`ROLLBACK TO SAVEPOINT ${name}`);
      await this.client.query(`RELEASE SAVEPOINT ${name}`);
      throw err;
    }
  }
}

/**
 * With [caCert] the connection uses TLS verified against that CA only (hostname and chain checked); the URL's
 * `sslmode` is dropped so it can't downgrade that. Without it, the URL decides (local stacks use plain TCP).
 */
export function createPool(connectionString: string, max: number, caCert?: string | null): Pool {
  let url = connectionString;
  let ssl: { ca: string; rejectUnauthorized: true } | undefined;
  if (caCert) {
    const u = new URL(connectionString);
    u.searchParams.delete('sslmode');
    url = u.toString();
    ssl = { ca: caCert, rejectUnauthorized: true };
  }
  const pool = new Pool({
    connectionString: url,
    ...(ssl ? { ssl } : {}),
    max,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    application_name: 'aura-api',
  });
  // An idle client erroring (e.g. DB restart) must not crash the process.
  pool.on('error', () => undefined);
  return pool;
}

/** BEGIN … COMMIT, ROLLBACK on any error. */
export async function withTx<T>(pool: Pool, fn: (tx: Tx) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  let broken: Error | undefined;
  try {
    await client.query('BEGIN');
    const out = await fn(new Tx(client));
    await client.query('COMMIT');
    return out;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      broken = rollbackErr as Error; // connection is unusable: destroy it instead of pooling it
    }
    throw err;
  } finally {
    client.release(broken);
  }
}
