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
import { isStaffRole, staffActor, type AdminRequest, type MfaState, type StaffRole, type StaffUser } from './admin-types';
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
}

/**
 * One round trip: the allowlist row, the Supabase session behind the token (it must still exist — signing out revokes
 * the console at once), whether a verified TOTP factor exists, and whether the account is also an app account.
 * Runs as the service role (it reads `auth.*`); nothing from it is returned to the console.
 */
const GUARD_SQL = `
  select s.role, s.display_name, (s.disabled_at is not null) as disabled,
         ses.created_at as session_created_at, ses.not_after as session_not_after,
         exists (select 1 from auth.mfa_factors f
                  where f.user_id = q.uid and f.factor_type = 'totp' and f.status = 'verified') as has_totp,
         exists (select 1 from public.profiles p where p.user_id = q.uid) as is_app_account
    from (select $1::uuid as uid) q
    left join public.admin_staff s on s.staff_id = q.uid
    left join auth.sessions ses on ses.id = $2::uuid and ses.user_id = q.uid`;

function bearer(header: unknown): string | null {
  const m = typeof header === 'string' ? /^Bearer\s+(\S+)\s*$/i.exec(header) : null;
  return m ? m[1] : null;
}

function totpInToken(claims: JWTPayload): boolean {
  if (claims.aal !== 'aal2' || !Array.isArray(claims.amr)) return false;
  return claims.amr.some((m) => typeof m === 'object' && m !== null && (m as { method?: unknown }).method === 'totp');
}

/**
 * Console authentication and authorisation, re-checked on every request (PRD 19 REQ-ADM-01/02):
 *  1. a valid Supabase access token (signature, issuer, audience, expiry — the app's JwtVerifier);
 *  2. the account is on the `admin_staff` allowlist, enabled, and (if `ADMIN_ALLOWED_EMAILS` is set) listed there too;
 *  3. it is a staff-only account (no app profile);
 *  4. its Supabase session still exists and is younger than `ADMIN_SESSION_MAX_HOURS` (short sessions);
 *  5. AAL2 reached with TOTP in this session and a verified TOTP factor still enrolled;
 *  6. the route's roles include the staff member's role — otherwise 403, and the attempt is audited.
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
