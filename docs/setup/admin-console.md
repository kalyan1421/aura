# Admin console v0 — setup, sign-in and runbook

The internal console for moderation, grievances, legal orders and 24×7 paging (PRD `19-admin-console.md`, F9 in
`06c-features-platform.md`, week 13 exit criterion "A test takedown order pages AK"). Milestone A scope.

| Piece | Where | What it does |
|---|---|---|
| Console | `apps/admin` (Next.js 16, App Router, port **3320**) | Server-rendered UI. Holds no database credentials and no service keys; talks only to the NestJS `/admin/*` routes with the staff member's own Supabase access token. No analytics, no third-party scripts, fonts or images. |
| Admin API | `server/aura-api/src/admin` (NestJS, `/admin/*`) | Staff guard (allowlist + TOTP/AAL2 + short sessions + roles) re-checked on every request; reads run under the `aura_admin` Postgres role; moderation actions go through the internal `ModerationService` (`src/safety`); every change writes the append-only, hash-chained `moderation_actions` log in the same transaction. |
| Public intakes | `POST /v1/grievances`, `GET /v1/grievances/officer`, `POST /v1/intake/legal-orders` | The grievance form (no login, rate-limited, auto-acknowledged) and the machine intake for emailed legal orders. |
| Pager | API fast path + worker (`src/admin/paging`, queue `admin-paging`) | Pages the Owner, retries, escalates at 5 min, repeats every 5 min until acknowledged; weekly drill. |
| Schema | `supabase/migrations/20261005000013_admin.sql` + `20261005000016_admin_completion.sql`; tests `supabase/tests/13_admin.test.sql`, `16_admin_completion.test.sql` | `aura_admin` role, `admin_staff`, `admin_grievances`, `admin_legal_orders`, `admin_pages`, `admin_page_deliveries`, `admin_mandatory_checklists`, `admin_deletion_cases`; the security-definer functions every console write goes through (§4). |

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
   | `ADMIN_CONSOLE_URL` | `http://localhost:3320` (the SSO callback is `<this>/login/callback`) |
   | `ADMIN_SSO_PROVIDER`, `ADMIN_SSO_DOMAIN` | empty locally (no Google button); §2 for production |
   | `ADMIN_ALLOW_EMAIL_LOGIN` | empty (the development email code is on with `NODE_ENV=development`; never in production) |

   Then `pnpm install && pnpm dev` → <http://localhost:3320>. Production: `pnpm build && pnpm start`.
5. **Mail**: every email (sign-in codes, grievance acknowledgements and replies, email pages) lands in Mailpit at
   <http://127.0.0.1:55524>.

## 2. How AK signs in (REQ-ADM-01: Google Workspace SSO + TOTP)

Staff accounts are **separate Supabase Auth users**, never app accounts: the guard refuses any account that has an app
profile, on every request. There is no sign-up in the console. The first factor is **Google Workspace SSO** (Supabase's
Google provider, PKCE, restricted to AKVega's Workspace domain); the second is **TOTP**, always. The email code is a
**development-only** first factor: on by default only when `NODE_ENV` is `development` / `test` (unset or unknown
`NODE_ENV` fails closed: `403 sso_required`, audited) and **refused in production** — the API refuses to boot with
`ADMIN_ALLOW_EMAIL_LOGIN=true` and `NODE_ENV=production`, and the console never offers the form in production
(docs/security/milestone-b-review.md SR-1). A staging stack without SSO runs with `NODE_ENV=development`.

### What AK configures once (production)

1. **Google Cloud** (the same project as the app's Google sign-in, docs/setup/social-sign-in.md): the Supabase Google
   provider already uses the **Web** OAuth client. Nothing new is needed there unless the Web client does not yet list
   `https://<project-ref>.supabase.co/auth/v1/callback` as an authorised redirect URI — add it. The consent screen stays
   *External* (app users sign in with it too); the Workspace restriction is enforced by the API, not by Google.
2. **Google Workspace**: create the console identity, e.g. `ak@akvega.com` (or `console@akvega.com`), with 2-step
   verification on. **Never use that account to sign in to the Aura app** — it would get an app profile and the console
   would refuse it (`staff_account_is_app_account`) until the profile is deleted.
3. **Supabase** (hosted project): Authentication → Providers → Google stays enabled (it is, for the app); Authentication
   → **MFA → TOTP enabled**; Authentication → URL Configuration → **Redirect URLs**: add
   `https://console.<your-domain>/login/callback`. Locally that is `http://localhost:3320/login/callback` (add it to
   `additional_redirect_urls` in `supabase/config.toml` only if you test SSO locally with real Google credentials).
4. **API env**: `ADMIN_SSO_PROVIDER=google`, `ADMIN_SSO_ALLOWED_DOMAINS=akvega.com` (comma-separated), leave
   `ADMIN_ALLOW_EMAIL_LOGIN` unset, `NODE_ENV=production`.
5. **Console env**: `ADMIN_SSO_PROVIDER=google`, `ADMIN_SSO_DOMAIN=akvega.com` (sent to Google as the `hd` hint and
   the account chooser is forced), `ADMIN_CONSOLE_URL=https://console.<your-domain>`, `NODE_ENV=production` (the
   email-code form disappears).
6. **Allow-list the Workspace account** — it must exist in Supabase Auth first, so sign in once with *Sign in with
   Google Workspace* (the console refuses it with "This account cannot use the console" — that is expected), then:
   ```sql
   insert into public.admin_staff (staff_id, role, display_name)
   select id, 'owner', 'AK' from auth.users where email = 'ak@akvega.com';
   ```
   Later staff are added in the console (**Staff**, §9) the same way: they sign in once, then the Owner adds them.
   Optional second gate: `ADMIN_ALLOWED_EMAILS=ak@akvega.com` on the API.

### Every sign-in

1. Console → *Sign in with Google Workspace* → Google (account chooser, Workspace domain) → back to
   `/login/callback`. The API accepts the session only if its first factor was Google (`amr` = `oauth`), the Google
   identity's hosted domain (`hd`) is in `ADMIN_SSO_ALLOWED_DOMAINS`, and the account is allow-listed and not an app
   account. A personal Gmail or another domain is refused (`sso_required`, audited).
2. **First time**: *Set up an authenticator* shows a QR code; scan it with 1Password / Google Authenticator / Authy and
   enter the code. **Every later sign-in**: Google + authenticator code. Only AAL2 sessions reach any data.
3. **Sessions** end 12 h after sign-in (cookie and API both enforce it); access tokens refresh silently. *Sign out*
   revokes the Supabase session at once. Sign-in (with its first factor: `sso` / `dev`) and sign-out are audited.
4. **Lost authenticator** (Owner break-glass): remove the factor with the Auth admin API
   (`DELETE /auth/v1/admin/users/{id}/factors/{factorId}`, service key) or Studio, note it in the ops log, then enroll
   again at the next sign-in.

**Development**: without SSO configured the login page shows the email code (Mailpit locally). The e2e suite boots a
second API as production would be and proves the email path is refused there and SSO + TOTP works.

## 3. Roles (PRD 19 "Roles")

| Role | Sees / does |
|---|---|
| **Owner** (AK) | Everything below plus: bans and unbans (account **and devices**), device bans, the minors & grooming SOP (mandatory reports, evidence export), grievances (incl. complainant contact), deletion cases, legal orders, paging, audit log and its export, kill switches, lexicon publish / rollback, staff. |
| **Moderator** | Now, Queue, report items, dismiss / warn / strike / shadow-mute (≤ 7 days) / suspend (24 h, 7 d) / pause; lifting non-ban sanctions; reading and testing the crisis lexicon; aggregate stats. |
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
- **Least privilege (REQ-ADM-03)**: moderation reads **and actions** (`ModerationService`, src/safety) run as
  `aura_admin` too. The queue no longer joins `auth.users` (account age comes from `admin_account_age_days`, a definer
  function returning a number). Every write goes through a `security definer` function in migration 16 that checks its
  own preconditions — `admin_add_strike`, `admin_add_sanction`, `admin_resolve_report`, `admin_extend_evidence_hold`
  (only ever extends), `admin_lift_sanction`, `admin_record_mandatory_report`, `admin_hide_account_from_rooms` (the
  room broadcast), the staff editor and deletion-case functions, `admin_audit_anchor` (the chain check). `aura_admin`
  gets `execute` on those and nothing more; `16_admin_completion.test.sql` asserts it, and `13_admin.test.sql`'s "no
  privilege on any other public table" still holds.
- One exception, by design: the account ban's **device** step (§8) switches back to the service role inside the same
  transaction (`set local role none`), because the device tables belong to the devices module (migration 17) and
  `aura_admin` has no grant on them; it drops back to `aura_admin` straight after. The devices module's own console
  routes (`/admin/devices*`, `/admin/lexicons*`) run as the service role (their module's choice).
- The only way identifiers leave: the Owner's **evidence export** (break-glass, purpose required, audited with the
  bundle's SHA-256; the reporter is withheld).

## 5. 24×7 paging

Pages carry kind, lane, "minor involved", ticket id, deadline, wait time and a console link — **never content**.

| What pages | When |
|---|---|
| Legal orders (court / government, incl. drills) | at once, 24×7 |
| Grievances: nudity / CSAM, non-consensual intimate imagery (2 h) | at once, 24×7 |
| **L0 crisis report filed in India's Lantern Hour, or in the Lantern Hour of the room's region** (REQ-ADM-05) | **at once** (API fast path when the report is filed; the worker sweep backs it up within 30 s) |
| **Any crisis report still open 5 minutes after filing**, at any hour (`PAGING_CRISIS_AFTER_MINUTES`) | within 30 s |
| Reports the safety module flags `pages` (L1 sexual / contact involving a minor) | within 30 s (worker sweep) |
| Crisis reports within 5 min of (or past) their SLA | within 30 s |
| Weekly drill | `PAGING_WEEKLY_TEST_CRON` (default Monday 10:00 IST) |

Round 0 goes to the **push webhook** and **email** at once; from **5 minutes** unacknowledged every round also hits
the **escalation webhook** (the voice call); rounds repeat every **5 minutes** until someone acknowledges (console →
Paging, the page link, or acknowledging the legal order) or the item is closed. Each channel gets quick retries inside
a round; every attempt is logged (`admin_page_deliveries`: channel, round, attempt, HTTP status or error code). Test
pages stop after 3 rounds. There is no console setting to mute any of this — channels come from the API environment.

**REQ-ADM-05 reading.** PRD 19 says L0 alerts reach the Owner's phone "in India's Lantern Hour or near SLA", and 06c F9
says crisis items unassigned for 5 minutes page 24×7. The safer combination is implemented: at once in India's (or the
room region's) Lantern Hour, and outside it after 5 minutes open — no overnight exception. The push carries no content
(kind, lane, wait, link); the call joins at 5 minutes; repeats every 5 minutes until acknowledged. First deliveries go
ahead of due repeats, so a fresh crisis page is never stuck behind a backlog.

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

## 8. Minors & grooming SOP support, bans and devices

In the Minors & grooming lane the Owner's **Ban** is the instant-ban step (REQ-ADM-14 "one confirm action bans account
and device"): account closed (the person sees only the generic closure notice), **every install seen for the account
banned** in the same transaction (`device_bans`, audited `device_ban`), the install **HMACs** added to the report's
evidence snapshot (`snapshot.devicesAtBan = { installHashes, at }` — never a raw install id), evidence hold extended to
≥ 180 days from the ban, and a mandatory-report task opens. Every Owner **Ban** (any lane) bans the devices the same
way; the report page says how many were newly banned.

**Devices** (Owner): the report page lists the subject's installs (hashed) with *Ban device* / *Ban all devices of this
account*; **Device bans** lists active / lifted bans and lifts one (an upheld appeal; the ban stays in the history). A
banned phone sees "This device can't use Aura" and can still delete its account. Limits and attestation:
docs/setup/lexicon-and-flags.md.

**Strike ladder (REQ-ADM-07)**: 1 warning → 2 a 24 h shadow-mute → 3 a 7-day room suspension → **the 4th active strike
bans automatically** (a permanent social ban: rooms, reflections and games off, solo features keep working; source
`auto`, audited separately as `system:strike_ladder` / `fourth_active_strike`, and the evidence behind the active
strikes is held ≥ 180 days from the ban). A 5th strike on a banned account never stacks a second ban. Strikes stop
counting 90 days after issue (`safety_config.strike_ttl_days`). A **crisis-flagged item never adds a strike**: the
crisis report itself, or any other non-dismissed crisis report on the same item or the same person in the same room;
refused in the service and by the `strikes_never_crisis` trigger whoever inserts. The ladder's social ban does **not**
ban devices (the phone keeps the solo features; device bans stay an Owner decision).
Console → **Mandatory reports** shows the checklist (evidence preserved, account banned and bundle exported are
automatic; POCSO / NCRP / NCMEC preparation, counsel and "no tipping off" are ticked by the Owner), the audited
evidence export, and closes the task only with an external reference or an Owner-recorded legal reason (REQ-ADM-14).
The filing itself follows the lawyer's SOP (action A3); the console files nothing.

## 9. Kill switches, lexicon, staff, queue sessions, audit export

**Kill switches** (Owner, audited with a reason code): every `feature_flags` row with its description and last change —
`rooms_enabled`, `rooms_pool_hi`, and (off by default) **`reduced_mode`** and **`hold_all`**. Turn reduced mode on before
being unreachable. Today both are recorded and reach the app through `GET /v1/config`; their effects arrive with the
features they switch (reduced mode pauses reflections and throttles sign-ups; hold-all sends every new reflection to a
human — reflections are F6, Milestone B; the sign-up throttle refuses new profiles beyond `payload.signupsPerHour`
(default 20) in the last hour with `503 signups_throttled`, existing accounts untouched — contracts/api/v1.md "Reduced mode"). `matching_config` / `safety_config` are
read-only in v0.

**Crisis lexicon** (console → Lexicon; contracts/api/v1.md "Crisis lexicon versions"): overview of the live signed
version, signing key status and stored versions; *Test on samples* (Owner and Moderator; samples are not stored or
logged); Owner: *Store the bundled baseline*, *Store a new version* (JSON; checked against contracts/safety and its own
test cases; not live until published), *Publish* / *Roll back to this* (a rollback is a publish of an older version;
removing crisis phrases needs *Allow crisis removals*). Signing keys: docs/setup/lexicon-and-flags.md.

**Staff** (Owner; PRD 19 "Staff roles"): list, add (the person signs in once first, then is added by email; app
accounts are refused), change role or name, disable / enable. Every change is audited with the Owner as actor (the
`admin_staff` trigger reads the acting staff id). You cannot change or disable yourself, and the last active Owner
cannot be removed.

**Queue sessions** (PRD 19): after **2 hours** of non-urgent review (`ADMIN_QUEUE_SESSION_MINUTES`) the console shows
"Time for a break" for **15 minutes** (`ADMIN_QUEUE_BREAK_MINUTES`); crisis and paging items stay open throughout. Kept
in Redis per staff member (fails open if Redis is down); the cap is audited once per session.

**Nightly audit export**: the worker writes every audit row since the last export as NDJSON + a manifest (row range,
SHA-256, chain verified) to `ADMIN_AUDIT_EXPORT_DIR` (files 0600) and/or emails it to `ADMIN_AUDIT_EXPORT_EMAIL`,
at `ADMIN_AUDIT_EXPORT_CRON` (default 02:30 IST). Console → Audit log shows the last export and has *Export now*. Each
export is itself audited (`audit_export` / `audit_export_failed`). Keep the directory on storage AK backs up (or point
the email at an archive mailbox).

**Deletion cases (REQ-ADM-11)** (Owner; console → Deletion cases): for deletion requests that arrive by email, post or
a grievance. *Open a case* with the address the requester names and when it arrived; a verification link goes **only
to the email on the account** (never shown to staff, never in a URL; the link carries a random token, stored hashed,
valid `DELETION_LINK_TTL_HOURS`). No account → the case says so; a staff account → refused. Nothing is deleted until
the account holder confirms on the link (they can also decline). Then the Owner starts the app's own deletion: **7-day
grace** (the holder can still cancel in the app) or **immediate** with a reason (`under_13_confirmed`,
`requester_asked_immediate`, `legal_requirement`). The purge completes the case automatically; evidence holds about the
account survive until their `hold_until`. Every step is audited with the ticket (`DEL-…`); only one open case per account.

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
| `GET /admin/config`, `POST /admin/config/flags/:key` `{ enabled, reasonCode }`, `GET /admin/audit`, `GET /admin/audit/verify`, `GET/POST /admin/audit/exports` | Owner |
| `GET /admin/staff`, `POST /admin/staff` `{ email, role, displayName }`, `POST /admin/staff/:staffId` `{ role?, displayName?, disabled? }` | Owner |
| `GET /admin/deletion-cases?status`, `POST /admin/deletion-cases` `{ email, channel, receivedAt, grievanceId? }`, `GET …/:id`, `POST …/:id/resend`, `POST …/:id/delete` `{ mode: grace \| immediate, reasonCode? }`, `POST …/:id/close` `{ outcome }` | Owner |
| `GET /v1/deletion-requests/:token`, `POST …/:token/confirm`, `POST …/:token/decline` (the account holder's link; public, rate-limited) | — |
| `GET /admin/lexicons/crisis`, `GET …/versions/:v`, `POST …/test` · `POST …/versions`, `POST …/versions/baseline`, `POST …/publish` | Owner + Moderator · Owner |
| `GET /admin/devices?reportId`, `POST /admin/devices/ban-account`, `POST /admin/devices/:deviceId/ban`, `GET /admin/devices/bans?status`, `POST /admin/devices/bans/:banId/lift` | Owner |

## 11. Tests

- `cd server/aura-api && pnpm test` (unit: guard incl. SSO first factor, action → audit, strike ladder and device ban
  (`admin.strikes.spec.ts`), crisis paging, queue sessions, deletion cases, audit export, clocks and work order, pager
  retries / escalation / payloads, SMTP client, evidence view and export, config) · `pnpm test:e2e`
  (`admin.e2e-spec.ts`: live Auth with real TOTP and a simulated Workspace SSO session, Mailpit, local webhook) ·
  `pnpm lint`.
- `supabase test db` (`13_admin.test.sql`, `16_admin_completion.test.sql`).
- `cd apps/admin && pnpm typecheck && pnpm lint && pnpm test && pnpm build`.

## 12. Production checklist

- API: `SMTP_URL` (a real provider), `MAIL_FROM`, `GRIEVANCE_OFFICER_*`, paging channels (push + escalation + email),
  `LEGAL_INTAKE_TOKEN` if a relay is used, `ADMIN_CONSOLE_URL`, `PUBLIC_API_URL` (the deletion link),
  `ADMIN_SSO_PROVIDER` + `ADMIN_SSO_ALLOWED_DOMAINS` (§2), `ADMIN_AUDIT_EXPORT_DIR` and/or `_EMAIL`, optionally
  `ADMIN_ALLOWED_EMAILS`. Run the worker (paging, drill, audit export).
- If the API's database user is not `postgres`: `grant aura_admin to <that role> with inherit false, set true;`.
- Behind a load balancer, set `TRUST_PROXY` on the API (the hop count, e.g. `1`, or the balancer's addresses/CIDRs) so
  the grievance, deletion-link and legal-intake rate limits see client addresses (SR-2 in docs/security/milestone-b-review.md).
- Console: its own subdomain over TLS, `ADMIN_COOKIE_SECRET` from a secret store, `NODE_ENV=production` (secure
  cookies); consider an IP allowlist at the edge.
- Enable TOTP MFA on the hosted project (free), create the Owner staff account, run the drill, and keep the weekly drill on.

## 13. Not in v0 (PRD gaps)

Console PWA Web Push and FCM paging to AK's device (use ntfy / PagerDuty webhooks) · reduced-mode and hold-all
*effects* beyond reflections and the sign-up throttle (both wired in Milestone B) ·
DeviceCheck / Play Integrity attestation for device bans · config editing beyond flags (matching / safety values stay
read-only) · reflections items and omni-moderation scores (F6, Milestone B) · grievance retention and localized
(te / hi) grievance and deletion-verification email copy · inbound email parsing (orders and deletion requests arrive
through the intake API or the console) · the analyst dashboard beyond aggregate counts · per-staff quality review
(PRD 19 post-v0).
