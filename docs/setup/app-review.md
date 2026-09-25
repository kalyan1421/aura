# App Review / Play review sign-in

Aura is passwordless: people sign in with a 6-digit email code (or Apple / Google). Store reviewers can't read the
review account's inbox, so the API lets **one** configured account sign in with a **fixed 6-digit code** that goes in
the review notes. Nothing in the app mentions it.

## How it works

1. The reviewer types the review email on the sign-in screen and taps **Email me a code**. The app asks Supabase for a
   code as usual (Supabase does send an email to that address — nobody needs to read it).
2. The reviewer types the fixed code. Supabase refuses it (it isn't the code it emailed), so the app, with the same
   email and code, calls `POST /v1/auth/review-sign-in` (`apps/mobile/lib/src/features/auth/auth_repository.dart`,
   `SupabaseAuthRepository.verifyEmailCode`).
3. The API (`server/aura-api/src/auth/review-sign-in.ts`) answers only if **both** `REVIEW_ACCOUNT_EMAIL` and
   `REVIEW_ACCOUNT_CODE` are set, the email matches (case-insensitive) and the code matches (constant-time). It then
   mints an ordinary Supabase session for that account with the GoTrue admin API (`generate_link` type `magiclink` →
   `email_otp` → `verify` type `email`; no extra email) and returns `{ access_token, refresh_token, expires_in }`.
4. The app makes that its Supabase session (`auth.setSession`) and carries on exactly like any sign-in.

Anything else — a person's wrong or expired code, another email, the route switched off — reads exactly like a wrong
code: the API answers the same `401 invalid_code` (or `404` when unconfigured), and the app shows its normal message.
Limits and records:

- **5 attempts per client address per hour** (Redis, HMAC'd address) → `429 rate_limited`.
- Each successful use is written to the hash-chained audit log (`moderation_actions`, action `review_sign_in`, the
  account as a subject hash only). The code, the email and the tokens are never logged.
- Needs `SUPABASE_SERVICE_ROLE_KEY` on the API (already set in production for private media); without it the route
  answers `503 review_sign_in_unavailable`.

## Setting it up (AK, before each submission)

1. **Create the review account as a normal account.** Use a real mailbox you control (e.g. a Gmail alias such as
   `you+aurareview@gmail.com`), so Supabase's ordinary code email in step 1 above is delivered somewhere harmless.
   On a phone with the production build: onboard (date of birth **18+ years ago**, language English), sign in with
   that email and the code Supabase emails you, do a first check-in and accept the room guidelines if you like. This
   makes the account look like a real, settled adult account. (If you skip this, the reviewer's own first sign-in
   creates the account and they go through onboarding themselves — that also works.)
2. **Pick a random 6-digit code** (the app's code field takes exactly 6 digits), e.g. `python3 -c "import secrets;
   print(f'{secrets.randbelow(10**6):06d}')"`. Don't reuse it anywhere.
3. **Set the API env vars** on Render (the API service), then redeploy / restart:

   ```
   REVIEW_ACCOUNT_EMAIL=you+aurareview@gmail.com
   REVIEW_ACCOUNT_CODE=123456
   ```

   Both are secrets. Either one unset or malformed (code not exactly 6 digits, email without `@`) → the route is off.
4. **Check it** from a terminal (use a different code first to see the 401):

   ```
   curl -s -X POST https://<api-host>/v1/auth/review-sign-in -H 'Content-Type: application/json' \
     -d '{"email":"you+aurareview@gmail.com","code":"123456"}' | head -c 80
   ```

   A `200` with `access_token` means it works. Then sign in once on a real device with the fixed code.
5. **App Review notes** (App Store Connect → the version → App Review Information; Play Console → App content → App
   access → "All or some functionality is restricted" → add instructions):

   ```
   Aura signs in with a one-time email code. For review, use this account:
   1. Enter the email below and tap "Email me a code".
   2. On the next screen, type the code below and tap Continue.
   Email: you+aurareview@gmail.com
   Code: 123456
   (This code is fixed for review; you don't need access to the inbox.)
   The first launch asks for a date of birth — use any date 18+ years ago.
   ```

   Leave the "Password" field empty in App Store Connect if a separate field is shown, or put the code there and say
   so in the notes. Sign in with Apple / Google also work with any account.
6. **After approval**, unset both env vars (the route goes back to 404). Rotate the code for every new submission.

## Tests

- Server unit: `server/aura-api/test/unit/review-sign-in.spec.ts` (config, generic 401s, rate limit, GoTrue flow).
- Server e2e: `server/aura-api/test/e2e/review-sign-in.e2e-spec.ts` (live local Supabase: env unset → 404; a real
  session that the API accepts and GoTrue refreshes; audit row; 429).
- App: `apps/mobile/test/auth_review_sign_in_test.dart` (the real repository over a mocked GoTrue: fallback signs in;
  a wrong code keeps the normal error; offline skips the fallback; the sign-in screen shows no hint).
