import { Body, Controller, Get, HttpCode, Injectable, Param, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { consoleRefusal } from './admin-errors';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, uuidParam } from './admin-http';
import { parse, staffAddSchema, staffUpdateSchema } from './admin.schemas';
import type { StaffRole, StaffUser } from './admin-types';

/**
 * The staff editor (PRD 19 Roles: "staff roles" are Owner business). The Owner adds an existing Supabase Auth user as
 * Owner / Moderator / Read-only analyst, changes roles and names, and disables or re-enables access — never deleting
 * (the audit trail keeps pointing at a real row). Everything goes through SECURITY DEFINER functions (migration
 * 20261005000016) that re-check in the database that the caller is an enabled Owner, refuse app accounts, stop an Owner
 * from demoting or disabling themselves, and never leave the console without an enabled Owner. Each change is written
 * to the audit log by the allowlist trigger with the Owner as the actor. Staff sign in with SSO + TOTP (REQ-ADM-01), so
 * a new person signs in once with their Workspace account (refused, "not on the allowlist") before being added.
 */
export interface StaffView {
  staffId: string;
  displayName: string;
  role: StaffRole;
  disabled: boolean;
  /** Staff account email (never an app account's). */
  email: string | null;
  lastSignInAt: string | null;
  totpEnrolled: boolean;
  /** Whether this account can pass the SSO first factor with the configured provider and domains. */
  sso: { provider: 'google'; domains: string[]; allowed: boolean };
  /** Other external identities (a reason SSO is refused: they could have produced the OAuth sign-in). */
  otherProviders: string[];
  createdAt: string;
  updatedAt: string;
  isMe: boolean;
}

interface StaffRow {
  staff_id: string;
  role: StaffRole;
  display_name: string;
  disabled: boolean;
  created_at: Date;
  updated_at: Date;
  email: string | null;
  last_sign_in_at: Date | null;
  has_totp: boolean;
  google_domains: string[];
  other_providers: string[];
}

@Injectable()
export class StaffService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly config: AdminConfig,
  ) {}

  async list(me: StaffUser): Promise<{ staff: StaffView[]; sso: { configured: boolean; provider: string | null; domains: string[] } }> {
    const r = await this.adminDb.query<StaffRow>('select * from public.admin_staff_list()');
    const sso = this.config.sso;
    return {
      staff: r.rows.map((s) => ({
        staffId: s.staff_id,
        displayName: s.display_name,
        role: s.role,
        disabled: s.disabled,
        email: s.email,
        lastSignInAt: s.last_sign_in_at ? s.last_sign_in_at.toISOString() : null,
        totpEnrolled: s.has_totp,
        sso: {
          provider: 'google',
          domains: s.google_domains,
          allowed: !!sso && s.other_providers.length === 0 && s.google_domains.some((d) => sso.domains.has(d)),
        },
        otherProviders: s.other_providers,
        createdAt: s.created_at.toISOString(),
        updatedAt: s.updated_at.toISOString(),
        isMe: s.staff_id === me.id,
      })),
      sso: { configured: !!sso, provider: sso?.provider ?? null, domains: sso ? [...sso.domains] : [] },
    };
  }

  async add(me: StaffUser, body: unknown): Promise<{ staffId: string }> {
    const b = parse(staffAddSchema, body);
    try {
      const r = await this.adminDb.query<{ id: string }>('select public.admin_staff_add($1, $2, $3, $4) as id', [me.actor, b.email, b.role, b.displayName]);
      return { staffId: r.rows[0].id };
    } catch (e) {
      throw consoleRefusal(e);
    }
  }

  async update(me: StaffUser, staffId: string, body: unknown): Promise<{ staffId: string; changed: boolean }> {
    const b = parse(staffUpdateSchema, body);
    try {
      const r = await this.adminDb.query<{ changed: boolean }>('select public.admin_staff_update($1, $2, $3, $4, $5) as changed', [
        me.actor,
        staffId,
        b.role ?? null,
        b.displayName ?? null,
        b.disabled ?? null,
      ]);
      return { staffId, changed: r.rows[0].changed };
    } catch (e) {
      throw consoleRefusal(e);
    }
  }
}

/** `/admin/staff*` — Owner only. */
@Controller('admin/staff')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class StaffController {
  constructor(private readonly staff: StaffService) {}

  @Get()
  list(@CurrentStaff() me: StaffUser): ReturnType<StaffService['list']> {
    return this.staff.list(me);
  }

  /** `{ email, role, displayName }` — the account must exist in Supabase Auth and must not be an app account. */
  @Post()
  @HttpCode(201)
  add(@CurrentStaff() me: StaffUser, @Body() body: unknown): Promise<{ staffId: string }> {
    return this.staff.add(me, body);
  }

  /** `{ role?, displayName?, disabled? }`. */
  @Post(':staffId')
  @HttpCode(200)
  update(@CurrentStaff() me: StaffUser, @Param('staffId') staffId: string, @Body() body: unknown): Promise<{ staffId: string; changed: boolean }> {
    return this.staff.update(me, uuidParam(staffId), body);
  }
}
