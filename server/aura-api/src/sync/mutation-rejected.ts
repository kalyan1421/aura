import { pgCode } from '../db/db';

/** A domain rejection: the mutation is recorded as `rejected` with this reason; the batch continues. */
export class MutationRejected extends Error {
  constructor(readonly reason: string) {
    super(reason);
    this.name = 'MutationRejected';
  }
}

export const reject = (reason: string): never => {
  throw new MutationRejected(reason);
};

/**
 * Map an error thrown inside a mutation's savepoint to a rejection reason, or
 * `undefined` when it is not the mutation's fault (then the whole push fails and
 * the client retries).
 */
export function rejectionReason(err: unknown): string | undefined {
  if (err instanceof MutationRejected) return err.reason;
  const code = pgCode(err);
  if (!code) return undefined;
  if (code === '23505') return 'conflict';
  if (code === '23503') return 'invalid_reference';
  if (code.startsWith('22') || code === '23514' || code === '23502') return 'invalid_payload';
  return undefined;
}
