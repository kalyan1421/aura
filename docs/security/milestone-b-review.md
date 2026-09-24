# Milestone B security review: NestJS / Supabase RPC boundary

**Scope:** PRD 20-timeline, weeks 28–29: "security review of the NestJS/RPC boundary".
**Reviewed:** branch `fix/design-audit` at `c30fa95`, reviewed 24 Sep 2026. **Reviewer:** Claude, for AK.
**Outcome:** no Critical or High issues. There are 2 Medium and 5 Low/Informational findings, and all 7 are fixed with regression tests. Residual risks and items that need AK are in section 5.

## 1. Scope

| Layer | What was reviewed |
|---|---|
| Postgres / Supabase | All 23 migrations as applied to the local stack. For every table in `public` and `echo_library`: RLS, grants to `anon` and `authenticated` (table, column and sequence level), default privileges, every function (SECURITY DEFINER, `search_path`, EXECUTE grants), `realtime.messages` policies, the `private-media` bucket and `storage.objects` policies, and the grants of the console role `aura_admin`. |
| NestJS (`server/aura-api/src`) | The global guard chain (auth, pending deletion, account closed, device ban, kill switch). Every controller route: public, app user, staff, webhook or token. `AdminGuard`: allowlist, staff vs app account, session age, SSO first factor, AAL2/TOTP, roles. JWT verification. IDOR on every `:id` route. DS-10 mappers and Realtime payloads. Billing: Apple JWS chain, Google Pub/Sub OIDC, ownership, idempotency. SQL construction. Input validation and body limits. Logging and error responses. Rate limits. Config and secret handling. |
| Admin console (`apps/admin/src`) | Server actions, session sealing and cookies, SSO/PKCE callback, the MFA flow, the proxy (middleware) and CSP, route handlers (evidence export), exposure of data and tokens to the browser. |
| Mobile app | Only its use of Supabase: reads are select-own only, it makes no direct writes or RPCs, and Realtime channels are private. |

**Out of scope:** hosted Supabase and DigitalOcean configuration (not visible from the repo, see section 5), mobile binary hardening, and load testing.

## 2. Method

1. **Catalogue queries** against the live local database (`supabase migration up` applied), rather than reading SQL alone. This is how SR-3 and SR-4 were found, and how the "fine" list in section 4 was confirmed.
2. **Reading each code path end to end**, from controller to service to repository or SQL, for every route that takes an id or is public. A grep sweep over all SQL template literals checked for interpolated identifiers.
3. **A live check against the local GoTrue, Storage and PostgREST** for every suspected issue before calling it a finding. For example, a 6 MiB + 1 byte PUT was accepted on a voice upload URL signed for 16 bytes (SR-3), and GoTrue v2.186.0 was probed for enrolling a second factor at AAL1 (SR-6).
4. **Fix plus regression test for each finding.** Where possible the test was confirmed to fail without the fix: the SR-3 e2e fails with the bucket limit set back to `null`.
5. **A catalogue-wide pgTAP invariant test** (`24_security_review.test.sql`). It enumerates the catalogue at run time, so a future migration that forgets RLS, a revoke or `search_path` fails CI without anyone updating a list.

## 3. Findings

| ID | Severity | Title | Status |
|---|---|---|---|
| SR-1 | Medium | Console email-code sign-in fails open when `NODE_ENV` is unset, and is honoured in production | Fixed |
| SR-2 | Medium | Per-client rate limits on public routes collapse into one global bucket behind a load balancer | Fixed |
| SR-3 | Low | `private-media` signed uploads are not size-bound: 50 MiB instead of at most 6 MiB | Fixed |
| SR-4 | Low | New functions are client-callable RPCs by default | Fixed (hardening + invariants) |
| SR-5 | Low | Anonymous Supabase sessions are accepted as full accounts | Fixed (fail closed) |
| SR-6 | Low | Console TOTP enrolment action does not check enrolment state | Fixed (defence in depth; GoTrue already refuses) |
| SR-7 | Info | Console sends no HSTS | Fixed |

### SR-1: Console email-code sign-in fails open (Medium)

- **Where:** `server/aura-api/src/admin/admin-config.ts` (`allowEmailLogin: truthy(flag) ?? !production`, where `production = NODE_ENV === 'production'`) and `apps/admin/src/lib/sign-in-modes.ts` (same default).
- **Why it matters:** `server/aura-api/package.json`'s `start` runs `node dist/main.js` without setting `NODE_ENV`, and `config.schema.ts` defaults it to `development`. A production deploy that forgets `NODE_ENV` therefore accepts the development email-code first factor. Separately, `ADMIN_ALLOW_EMAIL_LOGIN=true` was honoured in production, with only a warning.
- **Impact:** an attacker who controls an allow-listed staff mailbox skips Google Workspace SSO. That also skips Workspace 2-step verification, device policy, the domain check and off-boarding, which breaks REQ-ADM-01 ("Staff sign-in requires SSO + TOTP"). The attacker calls GoTrue `/otp` and `/verify` directly with the public anon key, so the console's own form doesn't matter. TOTP is still required, which is why this is Medium and not High.
- **Fix:**
  - **API:** `ADMIN_ALLOW_EMAIL_LOGIN=true` with `NODE_ENV=production` refuses to boot (`AdminConfigError`). Email login is on by default only when `NODE_ENV` is explicitly `development` or `test`. An unset or unknown value fails closed.
  - **Console:** never offers the form in production (no override), and is off when `NODE_ENV` is unset or unknown.
  - Docs updated in `docs/setup/admin-console.md` and `.env.example`.
- **Tests:** `test/unit/admin.guard.spec.ts` ("email sign-in is on only for NODE_ENV development / test and never in production") and `apps/admin/test/sign-in.test.mts`.
- **Behaviour change for AK:** a staging stack without SSO must run with `NODE_ENV=development` on both the API and the console, or configure SSO.

### SR-2: Rate limits collapse behind a load balancer (Medium)

- **Where:** `src/admin/admin-http.ts` `clientAddress()` returns `req.ip`. Nothing set Express `trust proxy`, and there was no way to configure it. The setup doc said "configure Express `trust proxy`", but that needed a code change.
- **Impact:** in the planned DigitalOcean deployment, every request's `req.ip` is the balancer's address. The per-client limits then become single global buckets:
  - The public grievance form allows 5 per hour per IP. The 6th grievance in any hour, from anyone in the country, gets `429`. That is a statutory channel (IT Rules 2021, REQ-SAFE-11), and anyone can shut it with five requests an hour.
  - Deletion-link pages allow 30 per hour.
  - Legal-order intake allows 60 per hour.
- **Fix:** new optional `TRUST_PROXY` env var, applied in `configureApp` through `applyTrustProxy()`. It takes a hop count (1–10) or a list of addresses, CIDRs or Express keywords. `true` is refused, because it would trust a client-sent `X-Forwarded-For` and let anyone choose their own bucket. The default is trust nothing, which is the same behaviour as before.
- **Tests:** `test/unit/security-review.spec.ts` uses a real Express app. It checks that the default ignores XFF, that 1 hop gives two clients two buckets, that a spoofed leading XFF entry is ignored, and that only a listed proxy is trusted. `test/unit/config.spec.ts` covers parsing and rejection of `true` and junk.
- **Needs AK:** set `TRUST_PROXY=1`, or the load balancer's CIDR, in production.

### SR-3: `private-media` uploads are not size-bound (Low)

- **Where:** `supabase/migrations/20261005000002_storage_private_media.sql` creates the bucket with `file_size_limit = null`. `MediaService.uploadUrl` checks the client-declared `bytes` against the per-kind limit (1, 2, 4 or 6 MiB). A signed upload token can't carry a size, though, so Storage only enforced the project-wide 50 MiB.
- **Verified:** a 6 MiB + 1 byte PUT succeeded on a voice URL requested with `bytes: 16`.
- **Impact:** storage cost and abuse. Every account can park about 50 MiB per slot, and slots overwrite. The data is ciphertext only, so nothing is disclosed.
- **Fix:** migration `20261005000024` sets the bucket's `file_size_limit` to 6 MiB, the largest object the API ever signs for (`PLUS_CAPSULE_VOICE_BYTES`).
- **Tests:** pgTAP 24 ("SR-3: private-media is private and capped at 6 MiB") and `test/e2e/security-review.e2e-spec.ts` ("SR-3: a signed upload URL cannot carry more than the bucket cap"). The e2e test was confirmed to fail with the cap removed.
- **Residual:** within 6 MiB, the per-kind limits still rest on the declared size. A voice note can be up to 6 MiB rather than 1 MiB. This is accepted; the fix would be separate buckets per kind.

### SR-4: New functions are client-callable by default (Low, hardening)

- **Where:** Postgres grants EXECUTE on every new function to `PUBLIC`, and Supabase's default privileges add `anon` and `authenticated` in `public`. Every SECURITY DEFINER function is therefore a PostgREST RPC (`/rest/v1/rpc/<name>`) unless its migration revokes it.
- **Current state:** all 48 current functions were checked. Clients execute only `realtime_topic_allowed` and `ripples_topic_allowed`, each of which answers only for the caller's own membership, plus one trigger function that can't be called directly. The protection depends entirely on each migration remembering the revoke, and one slip on an `admin_*` function would be Critical.
- **Fix:** migration 24 runs `alter default privileges for role postgres revoke execute on functions from public`, plus the same for `anon, authenticated in schema public`. A client-callable function now needs an explicit `grant`, which is what migrations 10 and 21 already do. The migration also revokes the trigger function's leftover grant.
- **Tests:** pgTAP 24 creates a probe function and asserts that `anon` and `authenticated` can't execute it (`42501`) while `service_role` can. It also asserts that clients execute exactly the two topic checks.

### SR-5: Anonymous Supabase sessions accepted (Low)

- **Where:** `JwtVerifier` parses `is_anonymous`, but nothing enforced it.
- **Impact:** anonymous sign-ins are off in `supabase/config.toml`. On the hosted project, though, they are a single dashboard toggle. If that toggle were turned on, every anonymous session would be a full account (rooms, reflections, gifts) with no email or OAuth identity behind it. It would also bypass the sign-up friction that bans and device locks rely on.
- **Fix:** `AuthGuard` refuses anonymous sessions with `401 anonymous_session`.
- **Test:** `test/unit/auth-guard.spec.ts` ("SR-5: refuses a valid but anonymous Supabase session").

### SR-6: Console TOTP enrolment doesn't check enrolment state (Low)

- **Where:** `apps/admin/src/app/mfa/actions.ts` `startEnroll`. A server action can be called directly, whatever the page shows. The action only checked `stage === 'aal1'`.
- **Impact, in theory:** someone holding only the first factor (for example a phished Workspace password on an allow-listed account) could enrol their own authenticator and reach AAL2. The `AdminGuard` would accept that, because `has_totp` means any verified factor.
- **Verified mitigated by the platform:** GoTrue v2.186.0 refuses to enrol a new factor at AAL1 once one is verified (`403 insufficient_aal`).
- **Fix (defence in depth):** `startEnroll` now asks `GET /admin/session` and refuses unless `mfa === 'enroll'`.
- **Test:** `test/e2e/security-review.e2e-spec.ts` ("SR-6 …") pins the GoTrue behaviour. A GoTrue downgrade or change would fail CI.

### SR-7: No HSTS on the console (Informational)

- **Fix:** `apps/admin/next.config.ts` sends `Strict-Transport-Security: max-age=63072000; includeSubDomains` in production builds.

## 4. Checked and found fine

**Database (catalogue-wide; pgTAP 24 now enforces this).**
- Row-level security is on for all 72 tables in `public` and `echo_library`.
- **Client writes:**
  - No `anon` or `authenticated` role holds INSERT, UPDATE, DELETE or TRUNCATE, at table or column level.
  - No write policy exists, and no sequence is usable by a client.
  - `echo_library` has no client `USAGE`.
- **Read policies:**
  - `using (true)` appears only on `moods`, `preset_habits` and `feature_flags`.
  - Every other client policy is exactly `user_id = auth.uid()` for `authenticated`.
  - No table with a `user_id` column has an `anon` policy.
- **Definer functions:**
  - Every SECURITY DEFINER function pins its `search_path`: 46 use `''`, and `user_is_minor` and `stardust_balance_guard` use `public` / `public, pg_temp`.
  - No client, console or service role can `CREATE` in `public`, `echo_library` or `extensions`, so those search paths can't be hijacked.
- **Admin functions:** the `admin_*` and `deletion_case_*` definer functions are executable only by `aura_admin` or the owner, never by clients.
- **Realtime and storage:**
  - `realtime.messages` policies are for `authenticated` only, and each one is gated by a membership function. Clients can write only to `game:<session>`; rooms, member and `ripples:` topics are server-send only, through `realtime.send(…, private => true)`.
  - The mobile app joins with `RealtimeChannelConfig(private: true)`.
  - `private-media` is private, with no `storage.objects` policies. The e2e test confirms a user token can't list, read or upload, not even under its own prefix.
- **Console role:** `aura_admin` writes only `admin_grievances`, `admin_legal_orders`, `admin_mandatory_checklists`, `admin_pages`, `moderation_actions` and `feature_flags.enabled`. It has no grant on check-ins, notes, habits, capsules or `birth_date` (REQ-ADM-03; pgTAP 13).

**NestJS.**
- **Guards:**
  - Every route is covered by the global `AuthGuard` except the deliberate `@Public()` ones: health, config, lexicon, helplines, the grievance form, deletion links (token), legal intake (bearer token, compared in constant time), and the billing webhooks (self-authenticating).
  - Every `/admin` route has `@UseGuards(AdminGuard)` and an explicit `@AdminRoles`; a route without roles is refused.
  - Owner-only routes: staff, config and flags, audit, deletion cases, legal orders, grievances, paging, devices, mandatory reports, evidence export, and lexicon/helpline publish.
- **JWT:** ES256/RS256 via JWKS, with HS256 only if a legacy secret is configured. Audience, issuer and expiry are checked, `role` must be `authenticated`, and `sub` must be a UUID. `service_role` tokens are refused.
- **AdminGuard:** checks the allowlist, refuses app accounts, requires the Supabase session to still exist and to be at most 12 h old, requires the SSO first factor with domain via the `hd` claim and no other external identity, requires AAL2 with TOTP and a verified factor, and audits denials using an HMAC rather than the raw id.
- **IDOR:** every id-taking route is scoped to the caller:
  - Sync: check-in, habit and habit-log `id_conflict`; voice path must equal `<uid>/voice/<id>`.
  - Capsules: owner check after `lockById`.
  - Media: `isOwnMediaPath`, with foreign paths returned as 404.
  - Rooms and reflections: membership, plus `room_id` and author checks on delete.
  - Ripples: tickets, seats and sessions filtered by `user_id`.
  - Safety: blocks by `blocker_user_id`.
  - Gifts: `sender_user_id`; delivery matches sender, product and an unused purchase.
  - Billing ownership: an existing live owner is never moved (`owned_elsewhere`).
- **DS-10:**
  - Rooms, ripples, reflections and lantern REST responses and Realtime payloads carry ids, pseudonyms, seat numbers and enums only, and the existing contract scans cover them.
  - Received gifts carry no sender, not even a pseudonym.
  - Safety views (`/me`, `/reports`, `/blocks`) carry no lane, minor flag, reason code or target identity.
- **Webhooks:**
  - **Apple:** JWS with `alg` ES256 and a 3-certificate `x5c`. The intermediate must chain to the bundled Apple roots, not the header root, and carry the WWDR OID; the leaf must carry the receipt-signing OID; validity is checked at `signedDate`.
  - **Checks after verification:** bundle id and `appAppleId`, then idempotency on `notificationUUID`.
  - **Google:** the Pub/Sub OIDC token is RS256 against Google's JWKS, with `iss`, `aud` equal to the configured endpoint, `email` equal to the configured service account, and `email_verified`. It fails closed when not configured, and purchases are always re-read from the Play API.
  - Client purchase verification always confirms with the store's server API.
- **SQL:** all SQL is parameterized. The only interpolations are constant column lists, `PERSONAL_TABLES` table names, a typed `'subscriptions' | 'purchases'`, `set local role aura_admin`, and savepoint names.
- **Input validation:** zod schemas on every body. UUID path parameters go through `pathId`/`uuidParam`. The JSON body limit is 2 MB, sync accepts at most 200 mutations, the Apple JWS at most 100 kB, and text and tag limits are checked in code points.
- **Logging and errors:**
  - No request body is logged. Sync and media logs carry counts and error kinds, never ids, paths or text.
  - Error responses are `{code, message}`; a 500 says only "Something went wrong."; JSON parse errors never echo the body.
  - Rate-limit keys are HMACs of the IP.
- **Rate limits:** the grievance form, deletion links and legal intake are limited per client and globally. Reports have a daily limit, reflections per-room and daily limits, gifts 5 per day, ripple invites 1 per 10 minutes, and room joins per quadrant per 24 h. Gestures have floods, shadow-mutes and minimum intervals. Sign-up has GoTrue's limits plus the reduced-mode throttle, and there is one waiting ripple ticket per user.
- **Secrets:**
  - No real secrets are in the repo. The `test/fixtures/billing/test-ca` keys are a test CA that production code never trusts, and the JWT in a unit test is the public Supabase demo token.
  - The lexicon dev signing key is refused in production, and release app builds don't trust it.
  - Config errors name the variable, never its value.

**Admin console.**
- **Server actions:** every action goes through `requireSession()`, which needs the AAL2 stage, and the API re-checks everything. The console has no service key.
- **Cookies:**
  - Sealed with AES-256-GCM and a random 96-bit IV; the key needs at least 32 characters and there is no dev fallback.
  - `httpOnly`, `Secure` in production, SameSite=Strict for the session and Lax for PKCE, and expiry enforced 3 times.
- **SSO:** a PKCE verifier in a sealed 10-minute cookie, no redirect parameter (so no open redirect), and error text is never reflected.
- **Headers and CSRF:** a strict nonce CSP with `frame-ancestors 'none'`. The evidence export checks Origin, validates the id as a UUID, and allowlists the purpose.
- **Browser exposure:** no token or `NEXT_PUBLIC_` secret reaches the browser.

**Mobile app.** It reads only own rows (`capsules`, `notification_prefs` select), makes no Supabase writes or RPCs, and uses private Realtime channels. On `game:` it acts only on numeric seat and enum fields (no free text is rendered), and treats `session_start` and `session_end` as hints.

## 5. Residual risks and items for AK

**Production configuration (needs AK; not visible from the repo):**
1. **Set `NODE_ENV=production`** on the API, worker and console. The main config still defaults an unset `NODE_ENV` to `development`. SR-1 no longer depends on it, but the remote-config dev signing key would then be accepted, and release apps would reject those bundles. Consider making `NODE_ENV` required.
2. **Set `TRUST_PROXY`** (SR-2).
3. **Hosted Supabase:**
   - Turn Realtime "Allow public access" off, so only private channels exist and the anon key can't be used as an unmoderated relay.
   - Keep anonymous sign-ins off.
   - Turn email confirmations on.
   - Keep auth rate limits at their defaults or stricter.
   - Allow only `aura://auth-callback` and `https://console.<domain>/login/callback` as redirect URLs.
   - Keep the JWT expiry at 1 h or less.
   - Make sure the `private-media` bucket limit (migration 24) is applied.
4. **GoTrue sees the console server's IP** for staff verify calls. Set `GOTRUE_RATE_LIMIT_HEADER` and forward the client IP from the console, or accept that one attacker can lock staff sign-in for about 5 minutes at a time.
5. **Restrict the Firebase API keys** in `google-services.json` and `GoogleService-Info.plist` (public by design) to the app ids in Google Cloud.

**Key management:**

6. **`AURA_MASTER_KEY`** wraps every user data key (DS-1) and derives the HMAC keys for billing tokens, rate limits and audit subject hashes. It has no rotation mechanism: `user_data_keys.key_id` exists, but master re-wrap isn't implemented. Write a rotation and backup runbook, and hold the key in the DigitalOcean secret store with access limited to AK.
7. **Other secrets to store and rotate the same way:** `LEXICON_SIGNING_KEY`, the Apple IAP `.p8`, the Google Play service account JSON, the FCM credentials, `LEGAL_INTAKE_TOKEN` (a static bearer token; rotate it on any relay change), the console session secret, and `SUPABASE_SERVICE_ROLE_KEY`.

**Accepted design risks:**

8. **Breath Ripples Realtime:** Supabase Broadcast doesn't authenticate the sender, so the `seat` in client events is self-declared. A seat holder can spoof another seat's breath, pulse or gesture, or a server-named event, within their own session. The app renders no free text, treats server events as hints, and rate-limits per seat. A flood signal creates at most one review-queue report per seat, with no automatic sanction, and any member can already call `POST …/flood` directly. If abuse shows up, relay events through the server or sign them per seat.
9. **Sandbox purchases:** `BILLING_ACCEPT_SANDBOX` defaults to `true`, which App Review needs. As a result, TestFlight and sandbox purchases grant real Plus on the production backend, which matters with a public TestFlight link in the beta. Consider flagging sandbox-sourced entitlements or expiring them at the public launch.
10. **Media sizes:** per-kind media limits rest on the declared size, within the 6 MiB bucket cap (SR-3).
11. **Unhandled-error logs** include `err.message`. Some Postgres messages quote the input value, such as `invalid input syntax for type …: "…"`. Every body is zod-validated first, so none of the paths reviewed reach that with personal text. Consider scrubbing quoted values in `ApiExceptionFilter`.
12. **No global per-user or per-IP throttle** on authenticated `/v1` routes; `/v1/sync/push` accepts 2 MB bodies. Add limits at the edge (load balancer or CDN) before the public launch.
13. **Staff capabilities:** `aura_admin` can execute `user_is_minor` and the `admin_*` definer functions by design, with the API as the gate and every action audited. A compromised Owner session can do everything an Owner can: sanctions, deletions and evidence export. Keep SSO, TOTP and 12 h sessions, keep the Owner count at 1–2, and review the audit export.
14. **Console low items:**
    - Prefetch requests skip the proxy, and with it the CSP and `no-store`; the pages still re-check the session.
    - The session cookie has no `__Host-` prefix.
    - The PKCE and session cookies share one seal key without AAD binding.
    - An `Origin: null` on the evidence export returns 500 instead of 403, which still fails closed.
    - All low; fix when next touching the console.
15. **Apple certificate revocation:** OCSP isn't checked for the Apple certificate chain. Apple's library makes it optional.

**Before the public launch:**

16. Commission an external penetration test covering the PostgREST and Realtime surface with real tokens, the console (SSO, MFA, server actions), the billing webhooks, and the public routes.

## 6. Files changed

| File | Change |
|---|---|
| `supabase/migrations/20261005000024_security_review.sql` | SR-3 bucket cap; SR-4 default function privileges, plus the trigger-function revoke |
| `supabase/tests/24_security_review.test.sql` | 22 catalogue-wide invariants (new) |
| `server/aura-api/src/admin/admin-config.ts` | SR-1: fail closed, and refused in production |
| `server/aura-api/src/config/config.schema.ts`, `src/config/app-config.ts`, `src/bootstrap.ts` | SR-2 `TRUST_PROXY` |
| `server/aura-api/src/auth/auth.guard.ts` | SR-5: refuse anonymous sessions |
| `server/aura-api/test/unit/admin.guard.spec.ts`, `config.spec.ts`, `auth-guard.spec.ts`, `security-review.spec.ts` (new) | Unit regressions |
| `server/aura-api/test/e2e/security-review.e2e-spec.ts` (new) | PostgREST, Storage and GoTrue boundary; SR-3 and SR-6 |
| `server/aura-api/.env.example`, `docs/setup/admin-console.md` | `TRUST_PROXY`; the email-code rules |
| `apps/admin/src/lib/sign-in-modes.ts`, `apps/admin/test/sign-in.test.mts` | SR-1 (console) |
| `apps/admin/src/app/mfa/actions.ts` | SR-6 |
| `apps/admin/next.config.ts` | SR-7 HSTS |
