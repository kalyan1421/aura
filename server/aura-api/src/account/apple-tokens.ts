import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import type { Queryable } from '../db/db';
import { AppleRejectedError, AppleSignInClient, AppleUnavailableError, type AppleGrant } from './apple-sign-in';

/**
 * Sign in with Apple refresh tokens at rest (`public.apple_auth_tokens`, one row per account). Sealed like the DS-1
 * data keys in `user_data_keys`: AES-256-GCM with AURA_MASTER_KEY, stored as base64( iv[12] ‖ ciphertext ‖ tag[16] ),
 * with the user id bound as associated data so a sealed token copied onto another account's row never opens.
 * Tokens are never logged, returned or put in error messages.
 */
const IV_BYTES = 12;
const TAG_BYTES = 16;
const MAX_TOKEN_BYTES = 4096;

const aadFor = (userId: string): Buffer => Buffer.from(`aura:apple-refresh-token:v1:${userId.toLowerCase()}`, 'utf8');

export function sealAppleToken(masterKey: Buffer, userId: string, token: string): string {
  if (masterKey.length !== 32) throw new Error('master key must be 32 bytes');
  const plain = Buffer.from(token, 'utf8');
  if (plain.length === 0 || plain.length > MAX_TOKEN_BYTES) throw new Error('refresh token has an unexpected size');
  const iv = randomBytes(IV_BYTES);
  const c = createCipheriv('aes-256-gcm', masterKey, iv);
  c.setAAD(aadFor(userId));
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return Buffer.concat([iv, ct, c.getAuthTag()]).toString('base64');
}

/** Throws on a wrong key, another user's row or any tampering. */
export function openAppleToken(masterKey: Buffer, userId: string, sealed: string): string {
  const buf = Buffer.from(sealed, 'base64');
  if (buf.length <= IV_BYTES + TAG_BYTES) throw new Error('sealed token is too short');
  const d = createDecipheriv('aes-256-gcm', masterKey, buf.subarray(0, IV_BYTES));
  d.setAAD(aadFor(userId));
  d.setAuthTag(buf.subarray(buf.length - TAG_BYTES));
  return Buffer.concat([d.update(buf.subarray(IV_BYTES, buf.length - TAG_BYTES)), d.final()]).toString('utf8');
}

/** The code's Apple account is not this account's Sign in with Apple identity. */
export class AppleIdentityMismatchError extends Error {
  constructor() {
    super("The Apple account doesn't match this account's Sign in with Apple identity");
    this.name = 'AppleIdentityMismatchError';
  }
}

/** The stored token can't be opened (e.g. AURA_MASTER_KEY was replaced): it can never be revoked, retrying won't help. */
export class AppleTokenUnreadableError extends Error {
  constructor() {
    super('The stored Sign in with Apple token cannot be opened with the current master key');
    this.name = 'AppleTokenUnreadableError';
  }
}

export type AppleRevokeOutcome = 'none' | 'revoked' | 'refused';

interface TokenRow {
  client_id: string;
  wrapped_refresh_token: string;
}

/**
 * Stores and revokes an account's Sign in with Apple token. Used by the API (POST /v1/account/apple-auth; the
 * best-effort revoke when a deletion is requested) and by the worker's account purge.
 */
export class AppleTokenVault {
  constructor(
    private readonly masterKey: Buffer,
    readonly client: AppleSignInClient,
  ) {}

  get configured(): boolean {
    return this.client.configured;
  }

  /** Network only: the app's one-time authorization code → a refresh token. Throws AppleUnavailableError / AppleRejectedError. */
  exchange(authorizationCode: string): Promise<AppleGrant> {
    return this.client.exchangeCode(authorizationCode);
  }

  /**
   * Keeps a grant as the account's token, replacing an older one (never revoke on replace: revoking any token ends the
   * user's whole authorization, the new token included). The grant's Apple user must be this account's Sign in with
   * Apple identity (`auth.identities`, provider `apple`) → else AppleIdentityMismatchError. A purged auth user surfaces
   * as the FK error (23503).
   */
  async store(q: Queryable, userId: string, grant: AppleGrant): Promise<void> {
    if (!grant.subject) throw new AppleUnavailableError('no usable id_token in the response');
    const r = await q.query(
      `select 1 from auth.identities
        where user_id = $1 and provider = 'apple' and (provider_id = $2 or identity_data->>'sub' = $2) limit 1`,
      [userId, grant.subject],
    );
    if ((r.rowCount ?? 0) === 0) throw new AppleIdentityMismatchError();
    await q.query(
      `insert into public.apple_auth_tokens (user_id, client_id, wrapped_refresh_token) values ($1, $2, $3)
       on conflict (user_id) do update
         set client_id = excluded.client_id, wrapped_refresh_token = excluded.wrapped_refresh_token, updated_at = now()`,
      [userId, grant.clientId, sealAppleToken(this.masterKey, userId, grant.refreshToken)],
    );
  }

  /** Revokes a grant that will not be stored (its account is being purged). Best effort: never throws. */
  async discard(grant: AppleGrant, opts: { timeoutMs?: number } = {}): Promise<boolean> {
    try {
      await this.client.revokeRefreshToken(grant.refreshToken, grant.clientId, opts);
      return true;
    } catch {
      return false;
    }
  }

  async hasToken(q: Queryable, userId: string): Promise<boolean> {
    const r = await q.query('select 1 from public.apple_auth_tokens where user_id = $1', [userId]);
    return (r.rowCount ?? 0) > 0;
  }

  /**
   * Revokes the stored token at Apple, then deletes exactly that row (a token stored meanwhile by a new sign-in
   * stays). `none` = no token stored; `revoked` = Apple confirmed (or the token was already invalid); `refused` =
   * Apple refused the revoke request itself (retrying can't help: the row is deleted and the caller counts it as not
   * revoked). Throws AppleUnavailableError (not configured, unreachable, our credentials refused — retry later) or
   * AppleTokenUnreadableError (can never succeed).
   */
  async revokeStored(q: Queryable, userId: string, opts: { timeoutMs?: number } = {}): Promise<AppleRevokeOutcome> {
    const r = await q.query<TokenRow>(
      'select client_id, wrapped_refresh_token from public.apple_auth_tokens where user_id = $1',
      [userId],
    );
    const row = r.rows[0];
    if (!row) return 'none';
    if (!this.client.configured) throw new AppleUnavailableError('not configured');
    let token: string;
    try {
      token = openAppleToken(this.masterKey, userId, row.wrapped_refresh_token);
    } catch {
      throw new AppleTokenUnreadableError();
    }
    let outcome: AppleRevokeOutcome = 'revoked';
    try {
      await this.client.revokeRefreshToken(token, row.client_id, opts);
    } catch (err) {
      if (!(err instanceof AppleRejectedError)) throw err;
      outcome = 'refused';
    }
    await q.query('delete from public.apple_auth_tokens where user_id = $1 and wrapped_refresh_token = $2', [
      userId,
      row.wrapped_refresh_token,
    ]);
    return outcome;
  }

  /** Drops the stored token without revoking it (the purge gave up). Returns the rows removed. */
  async drop(q: Queryable, userId: string): Promise<number> {
    const r = await q.query('delete from public.apple_auth_tokens where user_id = $1', [userId]);
    return r.rowCount ?? 0;
  }
}
