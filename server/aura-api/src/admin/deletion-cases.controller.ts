import { Body, Controller, Get, HttpCode, Param, Post, Query, Req, Res, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Request, Response } from 'express';
import { Public } from '../auth/public.decorator';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, clientAddress, uuidParam } from './admin-http';
import type { StaffUser } from './admin-types';
import { DeletionCasesService, LINK_TOKEN_RE, type DeletionCaseView } from './deletion-cases.service';
import { RateLimiter } from './rate-limit';

/** REQ-ADM-11 deletion cases in the console — Owner only (PRD 19 Roles: "deletion, grievances"). */
@Controller('admin/deletion-cases')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class DeletionCasesAdminController {
  constructor(private readonly cases: DeletionCasesService) {}

  /** `?status=open|closed|all` (default open). */
  @Get()
  async list(@Query() query: unknown): Promise<{ cases: DeletionCaseView[] }> {
    return { cases: await this.cases.list(query) };
  }

  /** Open a case from an emailed / grievance request; the one-time link goes to the address on the account. */
  @Post()
  @HttpCode(201)
  open(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<DeletionCaseView & { linkEmailed: boolean | null }> {
    return this.cases.open(staff, body);
  }

  @Get(':caseId')
  get(@Param('caseId') caseId: string): Promise<DeletionCaseView> {
    return this.cases.get(uuidParam(caseId));
  }

  @Post(':caseId/resend')
  @HttpCode(200)
  resend(@CurrentStaff() staff: StaffUser, @Param('caseId') caseId: string): Promise<DeletionCaseView & { linkEmailed: boolean }> {
    return this.cases.resend(staff, uuidParam(caseId));
  }

  /** `{ mode: 'grace' }` or `{ mode: 'immediate', reasonCode }` — only for a case the account holder confirmed. */
  @Post(':caseId/delete')
  @HttpCode(200)
  startDeletion(@CurrentStaff() staff: StaffUser, @Param('caseId') caseId: string, @Body() body: unknown): Promise<DeletionCaseView> {
    return this.cases.startDeletion(staff, uuidParam(caseId), body);
  }

  @Post(':caseId/close')
  @HttpCode(200)
  close(@CurrentStaff() staff: StaffUser, @Param('caseId') caseId: string, @Body() body: unknown): Promise<DeletionCaseView> {
    return this.cases.close(staff, uuidParam(caseId), body);
  }
}

// ------------------------------------------------------------------------------------------------ public page
const escapeHtml = (s: string): string =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string);

export type DeletionPageKind = 'ask' | 'verified' | 'declined' | 'expired' | 'invalid' | 'limited';

/**
 * The account holder's page (pure; unit-tested). No script, no external resources, no personal data: the request's
 * ticket number and what happens next. `ask` offers the two choices as POST forms (opening the link changes nothing);
 * their actions are relative (`<token>/confirm` from `/v1/deletion-requests/<token>`), so a path prefix in front of the
 * API keeps working.
 */
export function deletionPage(kind: DeletionPageKind, ticket: string | null, token?: string): string {
  const t = ticket ? escapeHtml(ticket) : '';
  const body: Record<DeletionPageKind, string> = {
    ask: `<h1>Delete your Aura account?</h1>
<p>Aura's Grievance Officer received a request to delete the account that signs in with the email address this link was sent to${t ? ` (request <strong>${t}</strong>)` : ''}.</p>
<p>If you made this request, press <strong>Delete my account</strong>. The account is switched off at once and deleted for good within 30 days (normally after 7 days, during which signing in to the app lets you keep it). Records the law requires us to keep are kept only as long as required.</p>
<form method="post" action="${token ? `${escapeHtml(token)}/confirm` : '#'}"><button type="submit" class="danger">Delete my account</button></form>
<form method="post" action="${token ? `${escapeHtml(token)}/decline` : '#'}"><button type="submit">This wasn't me</button></form>
<p class="small">If you did not ask for this, you can also simply close this page: nothing is deleted without your confirmation.</p>`,
    verified: `<h1>Thank you — request confirmed</h1>
<p>Your request${t ? ` <strong>${t}</strong>` : ''} is confirmed. Aura's Grievance Officer will now start deleting the account; it is deleted for good within 30 days.</p>
<p class="small">Changed your mind? Sign in to the Aura app within 7 days after the deletion starts and choose "Keep my account".</p>`,
    declined: `<h1>Thanks for telling us</h1>
<p>Nothing will be deleted. The request${t ? ` <strong>${t}</strong>` : ''} is marked as not made by you, and Aura's Grievance Officer will look into it.</p>`,
    expired: `<h1>This link has expired</h1>
<p>Nothing was deleted. If you still want your account deleted, reply to the Grievance Officer's email${t ? ` about request <strong>${t}</strong>` : ''} and we will send a new link — or delete the account in the app (Settings).</p>`,
    invalid: `<h1>This link can't be used</h1>
<p>It may have been used already or replaced by a newer one. Nothing was changed. To delete your account, use Settings in the Aura app, or write to Aura's Grievance Officer.</p>`,
    limited: `<h1>Please try again later</h1><p>Too many attempts from this connection. Nothing was changed.</p>`,
  };
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow"><title>Aura — account deletion</title>
<style>body{font:16px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:34rem;margin:3rem auto;padding:0 1rem;color:#1d1f24;background:#f6f5f2}
h1{font-size:1.4rem}button{font:inherit;padding:.6rem 1rem;margin:.25rem 0;border-radius:.5rem;border:1px solid #888;background:#fff;cursor:pointer}
button.danger{background:#9b1c1c;color:#fff;border-color:#9b1c1c}.small{font-size:.9rem;color:#555}form{margin:.5rem 0}
@media (prefers-color-scheme:dark){body{background:#16181d;color:#e8e6e1}button{background:#23262d;color:#e8e6e1}.small{color:#aaa}}</style>
</head><body><main>
${body[kind]}
<p class="small">Aura is published by AKVega.</p>
</main></body></html>`;
}

/**
 * The link in the verification email (REQ-ADM-11). Public (the account holder has no console account); rate-limited per
 * connection and overall; never cached, indexed or framed. GET only shows the choice; the POSTs act.
 */
@Controller('v1/deletion-requests')
@Public()
export class DeletionRequestsPublicController {
  constructor(
    private readonly cases: DeletionCasesService,
    private readonly limiter: RateLimiter,
  ) {}

  private send(res: Response, status: number, html: string): void {
    res
      .status(status)
      .set({
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
        Pragma: 'no-cache',
        'Referrer-Policy': 'no-referrer',
        'X-Robots-Tag': 'noindex, nofollow',
        'X-Frame-Options': 'DENY',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
      })
      .send(html);
  }

  private async allowed(req: Request): Promise<boolean> {
    const who = this.limiter.bucket(clientAddress(req) ?? 'unknown');
    const perClient = await this.limiter.hit(`deletion-link:ip:${who}`, 30, 3600);
    const global = await this.limiter.hit('deletion-link:global', 2000, 3600);
    return perClient && global;
  }

  @Get(':token')
  async page(@Param('token') token: string, @Req() req: Request, @Res() res: Response): Promise<void> {
    if (!(await this.allowed(req))) return this.send(res, 429, deletionPage('limited', null));
    if (!LINK_TOKEN_RE.test(token)) return this.send(res, 404, deletionPage('invalid', null));
    const l = await this.cases.lookup(token);
    if (l.state === 'valid') return this.send(res, 200, deletionPage('ask', l.ticket, token));
    return this.send(res, l.state === 'expired' ? 410 : 404, deletionPage(l.state, l.ticket));
  }

  @Post(':token/confirm')
  async confirm(@Param('token') token: string, @Req() req: Request, @Res() res: Response): Promise<void> {
    return this.act(token, false, req, res);
  }

  @Post(':token/decline')
  async decline(@Param('token') token: string, @Req() req: Request, @Res() res: Response): Promise<void> {
    return this.act(token, true, req, res);
  }

  private async act(token: string, decline: boolean, req: Request, res: Response): Promise<void> {
    if (!(await this.allowed(req))) return this.send(res, 429, deletionPage('limited', null));
    const r = await this.cases.confirm(token, decline);
    const status = r.outcome === 'verified' || r.outcome === 'declined' ? 200 : r.outcome === 'expired' ? 410 : 404;
    return this.send(res, status, deletionPage(r.outcome, r.ticket));
  }
}
