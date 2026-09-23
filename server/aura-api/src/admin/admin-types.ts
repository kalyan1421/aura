import type { Request } from 'express';

/** PRD 19 "Roles". The Owner is AK; Moderator is the first hire (defined now); analysts see aggregates only. */
export const STAFF_ROLES = ['owner', 'moderator', 'analyst'] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];
export const isStaffRole = (v: unknown): v is StaffRole => typeof v === 'string' && (STAFF_ROLES as readonly string[]).includes(v);

/** Where the staff member is in the two-factor flow (Supabase MFA, TOTP). */
export type MfaState = 'verified' | 'challenge' | 'enroll';

/** How the session's first factor happened: SSO (Google Workspace) or the development email sign-in (REQ-ADM-01). */
export type FirstFactor = 'sso' | 'dev';

/** A verified console caller (AdminGuard). Staff accounts are Supabase Auth users that are not app accounts. */
export interface StaffUser {
  id: string;
  role: StaffRole;
  displayName: string;
  email: string | null;
  sessionId: string;
  sessionStartedAt: string;
  /** When the guard stops accepting this session (sign-in + ADMIN_SESSION_MAX_HOURS). */
  sessionExpiresAt: string;
  mfa: MfaState;
  /** Set by AdminGuard: `sso` (Google Workspace) or `dev` (the email sign-in, development only). */
  firstFactor?: FirstFactor;
  /** The audit actor for this person: `staff:<auth user id>`. */
  actor: string;
}

export type AdminRequest = Request & { staff?: StaffUser };

export const staffActor = (staffId: string): string => `staff:${staffId}`;
