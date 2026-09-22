import { Injectable, OnModuleDestroy } from '@nestjs/common';
import type { Pool, QueryResult, QueryResultRow } from 'pg';
import { AppConfig } from '../config/app-config';
import { createPool, withTx, type Queryable, type Tx } from './db';

/** Service-role Postgres access (bypasses RLS — the API is the only writer of personal tables). */
@Injectable()
export class DbService implements Queryable, OnModuleDestroy {
  readonly pool: Pool;

  constructor(config: AppConfig) {
    this.pool = createPool(config.databaseUrl, config.dbPoolMax);
  }

  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>> {
    return this.pool.query<R>(text, params);
  }

  withTx<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return withTx(this.pool, fn);
  }

  async ping(): Promise<void> {
    await this.pool.query('select 1');
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
