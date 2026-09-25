import { CanActivate, ExecutionContext, Injectable, SetMetadata, createParamDecorator } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { decodeJwt, type JWTPayload } from 'jose';
import { InvalidTokenError, JwtVerifier } from '../auth/jwt-verifier';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { subjectHash } from '../safety/audit';
import { SYSTEM_ACTORS, auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminErrors } from './admin-errors';
import { isStaffRole, staffActor, type AdminRequest, type FirstFactor, type MfaState, type StaffRole, type StaffUser } from './admin-types';
import { RateLimiter } from './rate-limit';

export const ADMIN_ROLES = 'aura:adminRoles';
export const ADMIN_BEFORE_MFA = 'aura:adminBeforeMfa';

/** Which console roles may call a route. Every admin route must declare it; a route without it is refused. */
export const AdminRoles = (...roles: StaffRole[]): MethodDecorator & ClassDecorator => SetMetadata(ADMIN_ROLES, roles);

/**
 * Only the sign-in preflight (`GET /admin/session`): an allow-listed staff account that has not finished TOTP yet may
 * learn whether to enroll or answer a challenge. Nothing else is reachable before AAL2.
 */
export const AllowBeforeMfa = (): MethodDecorator => SetMetadata(ADMIN_BEFORE_MFA, true);

/** The verified staff member (set by AdminGuard). */
export const CurrentStaff = createParamDecorator((_: unknown, ctx: ExecutionContext): StaffUser => {
  const staff = ctx.switchToHttp().getRequest<AdminRequest>().staff;
  if (!staff) throw ApiError.unauthorized();
  return staff;
});

interface GuardRow {
  role: string | null;
  display_name: string | null;
  disabled: boolean | null;
  session_created_at: Date | null;
  session_not_after: Date | null;
  has_totp: boolean;
  is_app_account: boolean;
  /** Google Workspace domains (`hd` claim) of the account's Google identities. */
  google_domains?: string[] | null;
  /** Every identity provider the account has (`email`, `google`, `apple`, …). */
  providers?: string[] | null;
  /** Verified emails of the account's Google identities (for `ADMIN_SSO_ALLOWED_ACCOUNTS`). */
  google_emails?: string[] | null;
}

/**
 * One round trip: the allowlist row, the Supabase session behind the token (it must still exist — signing out revokes
 * the console at once), whether a verified TOTP factor exists, whether the account is also an app account, and its
 * identities (for the SSO check). Runs as the service role (it reads `auth.*`); nothing from it is returned to the
 * console.
 */
const GUARD_SQL = `
  select s.role, s.display_name, (s.disabled_at is not null) as disabled,
         ses.created_at as session_created_at, ses.not_after as session_not_after,
         exists (select 1 from auth.mfa_factors f
                  where f.user_id = q.uid and f.factor_type = 'totp' and f.status = 'verified') as has_totp,
         exists (select 1 from public.profiles p where p.user_id = q.uid) as is_app_account,
         coalesce((select array_agg(distinct lower(i.identity_data -> 'custom_claims' ->> 'hd'))
                     from auth.identities i
                    where i.user_id = q.uid and i.provider = 'google'
                      and i.identity_data -> 'custom_claims' ->> 'hd' is not null), '{}') as google_domains,
         coalesce((select array_agg(distinct lower(i.identity_data ->> 'email'))
                     from auth.identities i
                    where i.user_id = q.uid and i.provider = 'google'
                      and i.identity_data ->> 'email' is not null
                      and coalesce((i.identity_data ->> 'email_verified')::boolean, false)), '{}') as google_emails,
         coalesce((select array_agg(distinct i.provider) from auth.identities i where i.user_id = q.uid), '{}') as providers
    from (select $1::uuid as uid) q
    left join public.admin_staff s on s.staff_id = q.uid
    left join auth.sessions ses on ses.id = $2::uuid and ses.user_id = q.uid`;

function bearer(header: unknown): string | null {
  const m = typeof header === 'string' ? /^Bearer\s+(\S+)\s*$/i.exec(header) : null;
  return m ? m[1] : null;
}

/** The session's authentication methods (Supabase `amr`: `oauth`, `otp`, `password`, `totp`, …). */
function amrMethods(claims: JWTPayload): string[] {
  if (!Array.isArray(claims.amr)) return [];
  return claims.amr
    .map((m) => (typeof m === 'object' && m !== null ? (m as { method?: unknown }).method : m))
    .filter((m): m is string => typeof m === 'string');
}

function totpInToken(claims: JWTPayload): boolean {
  return claims.aal === 'aal2' && amrMethods(claims).includes('totp');
}

/** Second factors and refreshes: never a first factor. */
const NOT_FIRST_FACTORS = new Set(['totp', 'mfa/phone', 'mfa/webauthn', 'token_refresh', 'anonymous']);

/**
 * REQ-ADM-01: how this session's first factor happened.
 * - `sso`: an OAuth sign-in (`amr` oauth) by an account whose Google identity belongs to an allowed Workspace domain (the
 *   ID token's `hd` claim, which Supabase keeps in `identity_data.custom_claims`) and that has no other external identity
 *   that could have produced that OAuth sign-in (only `google`, plus the `email` identity Supabase may add).
 * - `dev`: any other sign-in (the console's email code; password grants in tests) — only while `ADMIN_ALLOW_EMAIL_LOGIN`
 *   is on (the default outside production, off by default in production).
 * - null: refused (`403 sso_required`). TOTP (AAL2) is required on top in every case.
 */
export function firstFactor(
  claims: JWTPayload,
  row: Pick<GuardRow, 'google_domains' | 'providers' | 'google_emails'>,
  cfg: Pick<AdminConfig, 'sso' | 'allowEmailLogin'>,
): FirstFactor | null {
  const methods = amrMethods(claims);
  if (cfg.sso && methods.includes('oauth')) {
    const providers = row.providers ?? [];
    const onlySso = providers.length > 0 && providers.every((p) => p === cfg.sso?.provider || p === 'email');
    const domainOk = (row.google_domains ?? []).some((d) => cfg.sso?.domains.has(d.toLowerCase()));
    const accountOk = (row.google_emails ?? []).some((e) => cfg.sso?.accounts.has(e.toLowerCase()));
    if (onlySso && (domainOk || accountOk)) return 'sso';
  }
  const first = methods.filter((m) => !NOT_FIRST_FACTORS.has(m));
  if (cfg.allowEmailLogin && first.length > 0) return 'dev';
  return null;
}

/**
 * Console authentication and authorisation, re-checked on every request (PRD 19 REQ-ADM-01/02):
 *  1. a valid Supabase access token (signature, issuer, audience, expiry — the app's JwtVerifier);
 *  2. the account is on the `admin_staff` allowlist, enabled, and (if `ADMIN_ALLOWED_EMAILS` is set) listed there too;
 *  3. it is a staff-only account (no app profile) — an app user account can never sign in;
 *  4. its Supabase session still exists and is younger than `ADMIN_SESSION_MAX_HOURS` (short sessions);
 *  5. the session's first factor was SSO (Google Workspace, an allowed domain) — or the development email sign-in
 *     while `ADMIN_ALLOW_EMAIL_LOGIN` is on (default off in production) — else 403 `sso_required`;
 *  6. AAL2 reached with TOTP in this session and a verified TOTP factor still enrolled (SSO without MFA is denied);
 *  7. the route's roles include the staff member's role — otherwise 403, and the attempt is audited.
 * Denials for accounts that are not staff are audited once per session and hour (no raw account id: an HMAC).
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly verifier: JwtVerifier,
    private readonly db: DbService,
    private readonly admin: AdminConfig,
    private readonly app: AppConfig,
    private readonly limiter: RateLimiter,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    const roles = this.reflector.getAllAndOverride<StaffRole[] | undefined>(ADMIN_ROLES, targets);
    if (!roles || roles.length === 0) throw AdminErrors.routeNotConfigured();
    const beforeMfaOk = this.reflector.get<boolean | undefined>(ADMIN_BEFORE_MFA, ctx.getHandler()) === true;
    const req = ctx.switchToHttp().getRequest<AdminRequest>();
    const route = `${req.method} ${(req.route as { path?: string } | undefined)?.path ?? 'unknown'}`;

    const token = bearer(req.headers.authorization);
    if (!token) throw ApiError.unauthorized();
    let userId: string;
    try {
      userId = (await this.verifier.verify(token)).id;
    } catch (err) {
      if (err instanceof InvalidTokenError) throw ApiError.unauthorized('Invalid or expired access token.');
      throw err;
    }
    const claims = decodeJwt(token); // already verified above
    const sessionId = isUuid(claims.session_id) ? claims.session_id.toLowerCase() : null;
    if (!sessionId) throw AdminErrors.sessionExpired();
    const email = typeof claims.email === 'string' ? claims.email.toLowerCase() : null;

    const row = (await this.db.query<GuardRow>(GUARD_SQL, [userId, sessionId])).rows[0];
    const allowlisted = !!row?.role && isStaffRole(row.role) && !row.disabled;
    const emailOk = !this.admin.allowedEmails || (!!email && this.admin.allowedEmails.has(email));
    if (!row || !allowlisted || !emailOk) {
      await this.auditDenied(userId, sessionId, 'not_staff', route);
      throw AdminErrors.notStaff();
    }
    if (row.is_app_account) {
      await this.auditDenied(userId, sessionId, 'app_account', route);
      throw AdminErrors.appAccount();
    }
    const now = Date.now();
    const started = row.session_created_at;
    if (!started || (row.session_not_after && row.session_not_after.getTime() <= now)) throw AdminErrors.sessionExpired();
    const expiresAt = started.getTime() + this.admin.sessionMaxHours * 3_600_000;
    if (expiresAt <= now) throw AdminErrors.sessionExpired();

    // REQ-ADM-01: SSO first (or the development email sign-in where allowed), checked before any second factor.
    const factor = firstFactor(claims, row, this.admin);
    if (!factor) {
      await this.auditDenied(userId, sessionId, 'sso_required', route);
      throw AdminErrors.ssoRequired();
    }

    const mfa: MfaState = totpInToken(claims) && row.has_totp ? 'verified' : row.has_totp ? 'challenge' : 'enroll';
    const staff: StaffUser = {
      id: userId,
      role: row.role as StaffRole,
      displayName: row.display_name ?? 'Staff',
      email,
      sessionId,
      sessionStartedAt: started.toISOString(),
      sessionExpiresAt: new Date(expiresAt).toISOString(),
      mfa,
      firstFactor: factor,
      actor: staffActor(userId),
    };
    if (mfa !== 'verified' && !beforeMfaOk) throw AdminErrors.mfaRequired();
    if (!roles.includes(staff.role)) {
      // REQ-ADM-02: every forbidden attempt by a staff member is audited (not de-duplicated).
      await auditConsole(this.db, staff.actor, { action: 'access_denied', reasonCode: 'forbidden_role', detail: { route, role: staff.role } });
      throw AdminErrors.forbiddenRole();
    }
    req.staff = staff;
    return true;
  }

  private async auditDenied(userId: string, sessionId: string, reasonCode: string, route: string): Promise<void> {
    if (!(await this.limiter.once(`admin-denied:${this.limiter.bucket(`${sessionId}:${reasonCode}`)}`, 3600))) return;
    await auditConsole(this.db, SYSTEM_ACTORS.unknown, {
      action: 'access_denied',
      reasonCode,
      subjectHash: subjectHash(this.app.masterKey, userId),
      detail: { route },
    });
  }
}
