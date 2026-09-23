import { Injectable } from '@nestjs/common';
import type { QueryResult, QueryResultRow } from 'pg';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';

/** The Postgres role console reads and console writes run under (migration 20261005000013). */
export const ADMIN_DB_ROLE = 'aura_admin';

/**
 * Database access for the admin console: every query runs in a transaction that first does
 * `SET LOCAL ROLE aura_admin`, so what the console can read and change is enforced by Postgres grants, not only by
 * this code — no private tables, no auth schema, no reporter identity (PRD 19 "Access model", REQ-ADM-03). The role
 * resets at COMMIT/ROLLBACK, so the pooled connection goes back to the service role.
 */
@Injectable()
export class AdminDb implements Queryable {
  constructor(private readonly db: DbService) {}

  withTx<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.withTx(async (tx) => {
      await tx.query(`set local role ${ADMIN_DB_ROLE}`);
      return fn(tx);
    });
  }

  query<R extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<R>> {
    return this.withTx((tx) => tx.query<R>(text, params));
  }
}
