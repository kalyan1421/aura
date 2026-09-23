# Admin console v0 — setup, sign-in and runbook

The internal console for moderation, grievances, legal orders and 24×7 paging (PRD `19-admin-console.md`, F9 in
`06c-features-platform.md`, week 13 exit criterion "A test takedown order pages AK"). Milestone A scope.

| Piece | Where | What it does |
|---|---|---|
| Console | `apps/admin` (Next.js 16, App Router, port **3320**) | Server-rendered UI. Holds no database credentials and no service keys; talks only to the NestJS `/admin/*` routes with the staff member's own Supabase access token. No analytics, no third-party scripts, fonts or images. |
| Admin API | `server/aura-api/src/admin` (NestJS, `/admin/*`) | Staff guard (allowlist + TOTP/AAL2 + short sessions + roles) re-checked on every request; reads run under the `aura_admin` Postgres role; moderation actions go through the internal `ModerationService` (`src/safety`); every change writes the append-only, hash-chained `moderation_actions` log in the same transaction. |
| Public intakes | `POST /v1/grievances`, `GET /v1/grievances/officer`, `POST /v1/intake/legal-orders` | The grievance form (no login, rate-limited, auto-acknowledged) and the machine intake for emailed legal orders. |
| Pager | API fast path + worker (`src/admin/paging`, queue `admin-paging`) | Pages the Owner, retries, escalates at 5 min, repeats every 5 min until acknowledged; weekly drill. |
| Schema | `supabase/migrations/20261005000013_admin.sql`, `supabase/tests/13_admin.test.sql` | `aura_admin` role, `admin_staff`, `admin_grievances`, `admin_legal_orders`, `admin_pages`, `admin_page_deliveries`, `admin_mandatory_checklists`. |

## 1. Local setup

1. **Supabase** (repo root). `supabase/config.toml` enables TOTP MFA (`[auth.mfa.totp]`) and exposes Mailpit's SMTP on
   **55525** (`[inbucket] smtp_port`). Both need a restart after pulling: `supabase stop && supabase start`, then
   `supabase migration up --include-all` and `supabase test db`.
2. **Redis**: `docker compose -f infra/docker-compose.yml up -d`.
3. **API + worker** (`server/aura-api`): add the admin block of `.env.example` to `.env` (at minimum
   `SMTP_URL=smtp://127.0.0.1:55525` and `GRIEVANCE_OFFICER_EMAIL`), then `pnpm start:dev` (API :3310) and
   `pnpm start:worker:dev` (worker :3311 — the pager's 30-second tick, repeats, escalation and the weekly drill run here).
4. **Console** (`apps/admin`): copy `.env.example` to `.env.local` and fill in:

   | Variable | Local value |
   |---|---|
   | `AURA_API_URL` | `http://127.0.0.1:3310` |
   | `SUPABASE_URL` | `http://127.0.0.1:55521` |
   | `SUPABASE_ANON_KEY` | the local anon / publishable key (`supabase/LOCAL.md`) — used server-side only |
   | `ADMIN_COOKIE_SECRET` | `openssl rand -base64 48` |
   | `ADMIN_SESSION_MAX_HOURS` | `12` (keep equal to the API's) |

   Then `pnpm install && pnpm dev` → <http://localhost:3320>. Production: `pnpm build && pnpm start`.
5. **Mail**: every email (sign-in codes, grievance acknowledgements and replies, email pages) lands in Mailpit at
   <http://127.0.0.1:55524>.

## 2. How AK signs in

Staff accounts are **separate Supabase Auth users**, never app accounts (the guard refuses an account that has an app
profile). There is no sign-up in the console.

1. **Create the staff account once** (Owner, SQL or Studio):
   - Studio → Authentication → *Add user* → e.g. `ak+console@akvega.com`, *Auto confirm*; or
     `curl -X POST $SUPABASE_URL/auth/v1/admin/users -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H 'Content-Type: application/json' -d '{"email":"ak+console@akvega.com","email_confirm":true}'`
   - allow-list it:
     ```sql
     insert into public.admin_staff (staff_id, role, display_name)
     select id, 'owner', 'AK' from auth.users where email = 'ak+console@akvega.com';
     ```
     Every change to `admin_staff` (grant, role change, disable, removal) is written to the audit log by a trigger.
     Disable instead of deleting: `update public.admin_staff set disabled_at = now() where …`.
   - Optional second gate: `ADMIN_ALLOWED_EMAILS=ak+console@akvega.com` on the API.
2. **Sign in** at the console: email → 6-digit code from the email (Mailpit locally) → the console checks, before any
   second factor, that the account is staff (anything else is signed out with "This account cannot use the console").
3. **First time**: *Set up an authenticator* shows a QR code (and the key for manual entry); scan it with 1Password /
   Google Authenticator / Authy and enter the 6-digit code. **Every later sign-in**: email code + authenticator code.
   Only AAL2 sessions with a verified TOTP factor reach any data.
4. **Sessions** end 12 h after sign-in (cookie and API both enforce it); access tokens refresh silently. *Sign out*
   revokes the Supabase session, so its tokens stop working at once. Sign-in and sign-out are audited.
5. **Lost authenticator** (Owner break-glass): remove the factor with the Auth admin API
   (`DELETE /auth/v1/admin/users/{id}/factors/{factorId}`, service key) or Studio, note it in the ops log, then enroll
   again at the next sign-in.

**SSO later.** The PRD's target is Google Workspace SSO + TOTP. v0 uses the email code as the first factor; SSO slots in
by enabling the Google provider for the staff domain (checking the `hd` claim) and swapping the console's first step.
TOTP (AAL2) stays mandatory either way — the NestJS guard does not care how the first factor happened.

## 3. Roles (PRD 19 "Roles")

| Role | Sees / does |
|---|---|
| **Owner** (AK) | Everything below plus: bans and unbans, the minors & grooming SOP (mandatory reports, evidence export), grievances (incl. complainant contact), legal orders, paging, audit log, kill switches. |
| **Moderator** | Now, Queue, report items, dismiss / warn / strike / shadow-mute (≤ 7 days) / suspend (24 h, 7 d) / pause; lifting non-ban sanctions; aggregate stats. |
| **Read-only analyst** | Aggregate stats only. |

A refused attempt returns `403 forbidden_role` and is audited (REQ-ADM-02; e.g. a Moderator calling
`POST /admin/devices/{id}/ban`). Routes without a declared role are refused (fail closed).

## 4. The privacy boundary

- Console reads run in a transaction that does `SET LOCAL ROLE aura_admin`. That role has **no** grant on check-ins,
  notes, habits, capsules, keys, ledgers, consents, device tokens, `profiles` (so no `birth_date`), no usage on the
  `auth` schema (no email / phone), no `reports.reporter_user_id` (reporters are never identified) and no
  `room_members.user_id`. `13_admin.test.sql` asserts all of it, including "no privilege on any other public table".
- Subjects appear as an HMAC (`subjectHash`, the same one the audit log uses) plus the room pseudonym and an
  "Under 18" boolean — never a DOB, email, phone or raw account id. Capsules and notes are ciphertext and there is no
  decrypt route anywhere.
- Moderation **actions** call `ModerationService` (src/safety), which runs as the service role and writes its own
  audit row. Moving those under `aura_admin` needs its queue query to stop joining `auth.users` and its room broadcast
  to go through a definer function — a follow-up for the safety module owner.
- The only way identifiers leave: the Owner's **evidence export** (break-glass, purpose required, audited with the
  bundle's SHA-256; the reporter is withheld).

## 5. 24×7 paging

Pages carry kind, lane, "minor involved", ticket id, deadline, wait time and a console link — **never content**.

| What pages | When |
|---|---|
| Legal orders (court / government, incl. drills) | at once, 24×7 |
| Grievances: nudity / CSAM, non-consensual intimate imagery (2 h) | at once, 24×7 |
| Reports the safety module flags `pages` (L1 sexual / contact involving a minor; L0 crisis in India's Lantern Hour) | within 30 s (worker sweep) |
| Crisis reports within 5 min of (or past) their SLA | within 30 s |
| Weekly drill | `PAGING_WEEKLY_TEST_CRON` (default Monday 10:00 IST) |

Round 0 goes to the **push webhook** and **email** at once; from **5 minutes** unacknowledged every round also hits
the **escalation webhook** (the voice call); rounds repeat every **5 minutes** until someone acknowledges (console →
Paging, the page link, or acknowledging the legal order) or the item is closed. Each channel gets quick retries inside
a round; every attempt is logged (`admin_page_deliveries`: channel, round, attempt, HTTP status or error code). Test
pages stop after 3 rounds. There is no console setting to mute any of this — channels come from the API environment.

Channel setup (API `.env`):

| Channel | Example |
|---|---|
| Push: **ntfy** (phone app, priority 5 bypasses Do Not Disturb when allowed) | `PAGING_WEBHOOK_URL=https://ntfy.sh/<private-topic>` `PAGING_WEBHOOK_FORMAT=ntfy` `PAGING_WEBHOOK_TOKEN=<ntfy access token>` |
| Push: **Slack** incoming webhook | `PAGING_WEBHOOK_FORMAT=slack` |
| Escalation / voice call: **PagerDuty** Events v2 (high-urgency service with phone rules) | `PAGING_ESCALATION_WEBHOOK_URL=https://events.pagerduty.com/v2/enqueue` `PAGING_ESCALATION_WEBHOOK_FORMAT=pagerduty` `PAGING_ESCALATION_WEBHOOK_TOKEN=<routing key>` |
| Escalation via a **Twilio Studio** flow or any JSON receiver | `PAGING_ESCALATION_WEBHOOK_FORMAT=json` (+ optional bearer token) |
| Email | `PAGING_EMAIL_TO=ak@akvega.com` (needs `SMTP_URL`) |

**Local drill ("A test takedown order pages AK").** Start any local receiver, e.g.
`node -e "require('http').createServer((q,s)=>{let b='';q.on('data',c=>b+=c);q.on('end',()=>{console.log(q.url,b);s.end('ok')})}).listen(8099)"`,
set `PAGING_WEBHOOK_URL=http://127.0.0.1:8099/page`, `PAGING_ESCALATION_WEBHOOK_URL=http://127.0.0.1:8099/call`,
`PAGING_EMAIL_TO=ak@aura.test`, restart API + worker, then console → **Legal orders → Send a test takedown order**.
The receiver prints the page within a second, Mailpit shows the email, and after 5 minutes (worker running) the
`/call` escalation arrives; acknowledge to stop. `test/e2e/admin.e2e-spec.ts` automates exactly this.

## 6. Grievances (Grievance Officer: AK)

IT Rules 2021 as amended 20 Feb 2026 (PRD 19; legal review still required): acknowledge within 24 h, resolve within
7 days; unlawful content 36 h; nudity / CSAM and intimate images 2 h (these page).

- **In-app form and website**: `POST /v1/grievances` `{ category, email, name?, description, contentLocation?, locale?, channel? }`
  → `201 { ticket: "GRV-…", resolveBy, officer, appeal }`. No login; 5 per client per hour and 300 per hour overall
  (Redis; client addresses are only kept as an HMAC with a 1-hour TTL). The response is the acknowledgement; an
  acknowledgement email follows (retried by the worker up to 5 times), and the officer gets a content-free notice.
  `GET /v1/grievances/officer` returns the officer's name, email, address, timelines and categories for the app's
  Help & Safety screen and the website.
- **Emailed / posted grievances**: console → Grievances → *Record an emailed grievance* (the clock runs from when it
  was received).
- **Resolve**: outcome + reply; the email always adds the Grievance Appellate Committee route (30 days,
  https://gac.gov.in) `[LEGAL: confirm wording]`.
- Grievances hold the complainant's contact email: retention is a `[LEGAL]` decision (not purged yet).

## 7. Legal orders

Owner only; 3 hours **from receipt**. Record them in the console (Legal orders → *Record an order*), or let a mail relay
post them: `POST /v1/intake/legal-orders` with `Authorization: Bearer $LEGAL_INTAKE_TOKEN` and
`{ source, authority, reference?, receivedAt?, summary, targets?, isTest? }` → `201 { ticket, dueAt }` (404 while the
token is unset). Acknowledge (stops paging; the clock keeps running), then close as *actioned* or *rejected* with a note;
the audit row records whether the 3-hour window was met. Disclosure questions go to counsel.

## 8. Minors & grooming SOP support

In the Minors & grooming lane the Owner's **Ban** is the instant-ban step: account closed (the person sees only the
generic closure notice), evidence hold extended to ≥ 180 days from the ban, and a mandatory-report task opens.
Console → **Mandatory reports** shows the checklist (evidence preserved, account banned and bundle exported are
automatic; POCSO / NCRP / NCMEC preparation, counsel and "no tipping off" are ticked by the Owner), the audited
evidence export, and closes the task only with an external reference or an Owner-recorded legal reason (REQ-ADM-14).
The filing itself follows the lawyer's SOP (action A3); the console files nothing.

## 9. Kill switches

v0 flips the feature flags that exist (`feature_flags`, today `rooms_pool_hi`), with a reason code in the audit log;
`matching_config` / `safety_config` are shown read-only. Reduced mode, hold-all, per-pool reflections, sign-ups and the
Milestone B/C switches arrive with the features they switch off.

## 10. API (all `/admin/*` routes need a staff AAL2 token)

| Route | Roles |
|---|---|
| `GET /admin/session` (also before TOTP: says `enroll` / `challenge`), `POST /admin/session/started`, `POST /admin/session/ended` | all |
| `GET /admin/stats` | all |
| `GET /admin/work`, `GET /admin/queue?lane&limit`, `GET /admin/reports/:id`, `POST /admin/reports/:id/actions` `{ action, reasonCode, hours? }` | Owner, Moderator (ban: Owner) |
| `GET /admin/sanctions?active&subject`, `POST /admin/sanctions/:id/lift` `{ reasonCode }` | Owner, Moderator (unban: Owner) |
| `GET /admin/mandatory-reports`, `POST /admin/mandatory-reports/:holdId/checklist`, `POST /admin/mandatory-reports/:holdId/record`, `POST /admin/evidence/:holdId/export` `{ purpose }` | Owner |
| `GET/POST /admin/grievances`, `GET /admin/grievances/:id`, `POST …/:id/acknowledge`, `POST …/:id/resolve` | Owner |
| `GET/POST /admin/legal-orders`, `GET /admin/legal-orders/:id`, `POST …/:id/acknowledge`, `POST …/:id/close` | Owner |
| `GET /admin/paging/status`, `GET /admin/pages`, `GET /admin/pages/:id`, `POST /admin/pages/:id/ack`, `POST /admin/pages/test` | Owner |
| `GET /admin/config`, `POST /admin/config/flags/:key` `{ enabled, reasonCode }`, `GET /admin/audit`, `GET /admin/audit/verify` | Owner |
| `POST /admin/devices/:id/ban` | Owner (501 until DeviceCheck / Play Integrity exist) |

## 11. Tests

- `cd server/aura-api && pnpm test` (unit: guard, action → audit, clocks and work order, pager retries / escalation /
  payloads, SMTP client, evidence view and export, config) · `pnpm test:e2e` (`admin.e2e-spec.ts`: live Auth with real
  TOTP, Mailpit, local webhook) · `pnpm lint`.
- `supabase test db` (`13_admin.test.sql`).
- `cd apps/admin && pnpm typecheck && pnpm lint && pnpm test && pnpm build`.

## 12. Production checklist

- API: `SMTP_URL` (a real provider), `MAIL_FROM`, `GRIEVANCE_OFFICER_*`, paging channels (push + escalation + email),
  `LEGAL_INTAKE_TOKEN` if a relay is used, `ADMIN_CONSOLE_URL`, optionally `ADMIN_ALLOWED_EMAILS`. Run the worker.
- If the API's database user is not `postgres`: `grant aura_admin to <that role> with inherit false, set true;`.
- Behind a load balancer, configure Express `trust proxy` so the grievance rate limit sees client addresses.
- Console: its own subdomain over TLS, `ADMIN_COOKIE_SECRET` from a secret store, `NODE_ENV=production` (secure
  cookies); consider an IP allowlist at the edge.
- Enable TOTP MFA on the hosted project (free), create the Owner staff account, run the drill, and keep the weekly drill on.

## 13. Not in v0 (PRD gaps)

Google Workspace SSO (email code + TOTP instead) · device bans (no DeviceCheck / Play Integrity yet) · console PWA Web
Push and FCM paging to AK's device (use ntfy / PagerDuty webhooks) · a staff editor (SQL + audit trigger) · deletion
cases (REQ-ADM-11) · lexicon editor, signed lexicon versions and config editing beyond flags · reflections items and
omni-moderation scores (F6, Milestone B) · reduced mode / hold-all switches · nightly audit export and the 2-hour queue
session cap · grievance retention and localized (te / hi) grievance email copy · inbound email parsing (orders arrive
through the intake API or the console).
