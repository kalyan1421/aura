# Aura — local Supabase

Supabase CLI **v2.75.0**, `project_id = "aura"`, Postgres 17. Start/stop from the repo root:
`supabase start` · `supabase db reset` (migrations + `seed.sql`) · `supabase test db` (pgTAP in `supabase/tests/`) · `supabase status -o env`.

All values below are the CLI's fixed local-dev defaults. They are **not secrets** and must never be used outside localhost.

## URLs

| What | Value |
|---|---|
| API (Kong gateway) — `SUPABASE_URL` | `http://127.0.0.1:55521` |
| REST (PostgREST) | `http://127.0.0.1:55521/rest/v1` |
| Auth (GoTrue) | `http://127.0.0.1:55521/auth/v1` |
| Storage | `http://127.0.0.1:55521/storage/v1` |
| DB | `postgresql://postgres:postgres@127.0.0.1:55522/postgres` |
| Studio | `http://127.0.0.1:55523` |
| Mailpit (Inbucket) — magic-link / OTP emails | `http://127.0.0.1:55524` (JSON API: `/api/v1/messages`) |
| Analytics (Logflare) | `http://127.0.0.1:55527` |
| Shadow DB (`db diff`) | port `55520` |
| Pooler | port `55529` — **disabled** (`[db.pooler] enabled = false`); connect to the DB directly |

## Keys

| Name | Value |
|---|---|
| anon key (legacy JWT, HS256) | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0` |
| service_role key (legacy JWT, HS256) | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU` |
| publishable key (new-style `apikey`, = anon) | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` |
| secret key (new-style `apikey`, = service_role) | `sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz` |
| JWT secret (HS256) | `super-secret-jwt-token-with-at-least-32-characters-long` |

## JWT verification (for NestJS)

**User access tokens are ES256 (asymmetric), not HS256.** Verified by decoding a real token and checking its
signature against the JWKS:

| Claim / header | Value |
|---|---|
| `alg` / `kid` | `ES256` / `b81269f1-21d8-4f2e-b719-c2240a840d90` (EC P-256; the CLI's built-in default local signing key — stable across `stop/start/db reset`, may change on CLI upgrade, so always resolve by `kid`) |
| JWKS URL | `http://127.0.0.1:55521/auth/v1/.well-known/jwks.json` (public, no `apikey` header needed; 1 key) |
| `iss` | `http://127.0.0.1:55521/auth/v1` |
| `aud` | `authenticated` |
| `role` | `authenticated` |
| `sub` | the user's `auth.users.id` (→ `user_id`) |
| `exp` | `iat + 3600` (`jwt_expiry` default) |

- The HS256 **JWT secret only signs the legacy anon / service_role keys** — an HS256-only verifier will reject every user token.
  GoTrue/PostgREST accept `HS256,RS256,ES256`, but GoTrue *issues* user tokens with the ES256 key.
- Recommended: `jose` `createRemoteJWKSet(new URL(SUPABASE_URL + '/auth/v1/.well-known/jwks.json'))` +
  `jwtVerify(token, jwks, { issuer: SUPABASE_URL + '/auth/v1', audience: 'authenticated', algorithms: ['ES256'] })`.
- Alternatively `GET /auth/v1/user` with `Authorization: Bearer <token>` + `apikey: <anon>` returns the user (network round-trip).

## Create a test user and get an access token (tested)

Email confirmations are off locally (`enable_confirmations = false`), so password users are usable immediately.

```bash
eval "$(supabase status -o env)"   # API_URL, ANON_KEY, SERVICE_ROLE_KEY, MAILPIT_URL, ...

# 1a. Create a user (admin API, service role) — idempotency: 422 email_exists if it already exists
curl -s -X POST "$API_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@aura.test","password":"aura-dev-pass-1","email_confirm":true}'

# 1b. …or self sign-up with the anon key (returns a session straight away)
curl -s -X POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"bob@aura.test","password":"aura-dev-pass-1"}'

# 2. Sign in → access token
TOKEN=$(curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"alice@aura.test","password":"aura-dev-pass-1"}' | jq -r .access_token)

# 3. Use it
curl -s "$API_URL/rest/v1/avatar_state?select=*" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN"   # [] until NestJS creates the row
curl -s http://localhost:3310/v1/me/snapshot -H "Authorization: Bearer $TOKEN"                              # NestJS
```

Passwordless (what the app uses) — email OTP / magic link, code read from Mailpit:

```bash
# same shell as above (needs API_URL / ANON_KEY / MAILPIT_URL from `supabase status -o env`)
curl -s -X POST "$API_URL/auth/v1/otp" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"carol@aura.test","create_user":true}'
CODE=$(curl -s "$MAILPIT_URL/api/v1/search?query=to:carol@aura.test&limit=1" | jq -r '.messages[0].Snippet' | grep -oE '[0-9]{6}')
TOKEN=$(curl -s -X POST "$API_URL/auth/v1/verify" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"type\":\"email\",\"email\":\"carol@aura.test\",\"token\":\"$CODE\"}" | jq -r .access_token)
```

The magic link in the same email redirects to `site_url` = `aura://auth-callback` (allow-listed redirects:
`aura://auth-callback`, `http://localhost:3000`). Apple / Google providers are configured but `enabled = false`
(`SUPABASE_AUTH_EXTERNAL_{APPLE,GOOGLE}_{CLIENT_ID,SECRET}` env placeholders).

## What clients can and cannot do (enforced + pgTAP-tested)

- `anon` / `authenticated`: **no INSERT/UPDATE/DELETE/TRUNCATE on any public table** (grant level → `403 42501 permission denied`).
  Tables added by future migrations inherit this via default privileges.
- `authenticated` reads **own rows only** in `profiles, user_consents, check_ins, habits, habit_logs, starlight_ledger,
  active_days, avatar_state, streak_state, notification_prefs`. `anon` reads none of them (`[]`).
- `user_data_keys, sync_mutations, device_tokens, crisis_events`: no client privileges at all (`403`).
- `moods`, `preset_habits`, `feature_flags`: readable by `anon` and `authenticated`.
- `public.user_is_minor(uuid)`: server only (postgres / service_role); clients get `403`.
- NestJS connects with the DB URL as `postgres` (owner, bypasses RLS) or uses the service_role key.
- `profiles_min_age` is `birth_date <= current_date - 13 years` evaluated in the **DB's UTC date**. If NestJS computes
  age in the user's timezone (e.g. IST, ahead of UTC), a user on their 13th birthday before 05:30 IST passes the API
  check but the insert fails with `23514` — compute age against the UTC date too, or map `23514` → `403 under_13`.

## Storage

Bucket **`private-media`** — private, no `storage.objects` policies. Clients can't list/read/upload directly
(verified: direct upload → RLS error, public URL → 404). Flow (tested):

1. NestJS (service role): `POST /storage/v1/object/upload/sign/private-media/<user_id>/<path>` → `{ url, token }`
   (supabase-js: `storage.from('private-media').createSignedUploadUrl(path)`).
2. App: `PUT $API_URL/storage/v1<url>` with `apikey: <anon>` and the (client-encrypted) bytes
   (supabase-js: `uploadToSignedUrl(path, token, file)`).
3. Download: NestJS `POST /storage/v1/object/sign/private-media/<path>` `{"expiresIn":60}` → `signedURL`.

## Seed

`supabase/seed.sql` is generated — edit `contracts/moods.json`, then `python3 supabase/scripts/gen_seed.py` and `supabase db reset`.
