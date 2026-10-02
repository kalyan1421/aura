# Social sign-in setup: Sign in with Apple and Google

> **Update 2 Oct 2026: Aura v1 ships without Sign in with Apple.** The Apple button, the `sign_in_with_apple`
> plugin, the iOS `com.apple.developer.applesignin` entitlement and the `AURA_APPLE_SIGNIN*` flags are removed from
> the app. Sign-in is the email code everywhere, plus Google on Android. Because App Store 4.8 only lets an iOS app
> offer Google when it also offers Sign in with Apple, **iOS release builds show no social button**. The Apple
> sections below describe the old design and apply only if Apple sign-in is added back; with it comes the key and the
> four `APPLE_*` server values. The server's `POST /v1/account/apple-auth` and token revocation stay in place but
> dormant (no client calls them).

**For:** AK. **Scope:** F8 REQ-ACC-01 (Apple, Google, email link; email scope only) and REQ-ACC-04 (platform age signals).
**Code:** `apps/mobile/lib/src/features/auth/` · `supabase/config.toml` (`[auth.external.apple]`, `[auth.external.google]`) · `supabase/migrations/20261005000011_strip_oauth_profile.sql`.

## How it works

1. The sign-in screen shows Apple and Google only when this build has what each provider needs (see [Build configuration](#3-build-configuration)). An unconfigured provider has no button, so there's never a button that can't work.
2. Tapping one opens the platform's own sheet: Sign in with Apple on iOS, Credential Manager on Android, GoogleSignIn on iOS. The sheet returns an **ID token**. The app asks for the **email scope only** and never requests or sends a name.
3. The app sends that token to Supabase (`signInWithIdToken`, `POST /auth/v1/token?grant_type=id_token`). Supabase checks:
   - the token's **audience** against the provider's client-ID list;
   - its **nonce**. The app makes a random raw nonce, gives the provider `sha256(raw)` and gives Supabase the raw value.
4. Supabase returns a session. From here the app does exactly what it does after an email code: checks whether the account is scheduled for deletion ("Keep my account?"), then goes to the first check-in (onboarding) or back to the previous screen (standalone).
5. Apple on **Android** has no native sheet. It uses Supabase browser OAuth, and the session comes back through `aura://auth-callback`, the same way the magic link does.
6. Before any auth call (email code, Apple or Google), the app reads the platform **age signal** and waits at most 1 s ([details below](#8-platform-age-signals-req-acc-04)).

### Why "Google login is not working" before this change

- `supabase/config.toml` had `[auth.external.google] enabled = false`, and Apple was off too. The running GoTrue reported `google: false`, and `/authorize?provider=google` answered `400 Unsupported provider: provider is not enabled`.
- No Google OAuth clients existed. `GoogleService-Info.plist` had no `CLIENT_ID`/`REVERSED_CLIENT_ID`, `google-services.json` had `"oauth_client": []`, and no `SUPABASE_AUTH_EXTERNAL_GOOGLE_*` values were set. GoTrue was literally configured with the string `env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)`.
- The app used browser OAuth (`signInWithOAuth`) behind `AURA_SOCIAL_SIGNIN`. It now uses the native ID-token flow that Supabase recommends for mobile.

## 1. Google Cloud / Firebase (project `aura-akvega`)

Aura doesn't use Firebase Auth. The Firebase console is just the quickest way to create the OAuth clients in the same Google Cloud project.

1. **Consent screen.** Google Cloud console → *Google Auth Platform* (APIs & Services → OAuth consent screen), project `aura-akvega`.
   - Branding: app name **Aura**, support email, logo, privacy policy and terms URLs, authorised domain.
   - Audience: **External**. Use "Testing" with test users until you publish.
   - Data access: add only `openid` and `…/auth/userinfo.email`. Google's native SDKs still include the basic profile (name, picture) in the ID token; see [Privacy](#7-privacy-email-only).
2. **Web client (required on both platforms).**
   - Either enable *Authentication → Sign-in method → Google* in the Firebase console, which creates "Web client (auto created by Google Service)", or use *Clients → Create client → Web application* ("Aura Supabase").
   - Note its **Client ID** (`…apps.googleusercontent.com`) and **Client secret**.
   - Authorised redirect URI, needed only for browser OAuth: `https://<project-ref>.supabase.co/auth/v1/callback`.
3. **iOS client.** *Create client → iOS*.
   - Bundle ID `com.akvega.aura`, Team ID `AQLMTLP6PD`.
   - Note the **Client ID** and the **iOS URL scheme**. The scheme is the reversed client ID: `com.googleusercontent.apps.<…>`.
4. **Android clients: one per signing certificate.** *Create client → Android*, package `com.akvega.aura`, plus the certificate's **SHA-1**:
   - **Debug:**

     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
     ```

     `android/app/build.gradle.kts` currently signs `release` with the debug key too, so this one also covers local `--release` runs.
   - **Release / Play:** Play Console → *Test and release → App integrity → App signing*. Add the **app signing key** SHA-1. Add the **upload key** SHA-1 as well if you install upload-signed builds directly.
   - Alternatively, add the SHA-1s in Firebase → Project settings → the Android app. Firebase creates the Android OAuth clients for you.
   - Nothing about the Android client goes into the app. Google matches package name + SHA-1 at sign-in, and the app only needs the **Web** client ID (`serverClientId`).
5. **Re-download the config files** and replace them so they match the new clients:
   - `apps/mobile/ios/Runner/GoogleService-Info.plist` (it will now have `CLIENT_ID` and `REVERSED_CLIENT_ID`);
   - `apps/mobile/android/app/google-services.json` (its `oauth_client` list is no longer empty).

   The app reads the IDs from `--dart-define` (there's no google-services Gradle plugin), but stale files are confusing, and `lib/firebase_options.dart` should keep matching them.

## 2. Apple Developer (team `AQLMTLP6PD`)

1. **App ID `com.akvega.aura`.** Enable **Sign in with Apple** ("Enable as a primary App ID") and **Declared Age Range**. `Runner.entitlements` already has `com.apple.developer.applesignin` and `com.apple.developer.declared-age-range`.
   - With automatic signing, Xcode or `flutter run` on a device regenerates the profile.
   - Simulator builds don't need the portal step. Device builds fail to sign until the capabilities are on the App ID.
2. Nothing else is needed for **native iOS**. The ID token's audience is the bundle ID, which goes in the Supabase client-ID list (sections 4 and 5).
3. **Only for Apple on Android** (browser OAuth; hosted Supabase only, because Apple requires an HTTPS return URL):
   - **Services ID**, for example `com.akvega.aura.signin`. Enable Sign in with Apple → *Configure*:
     - primary App ID `com.akvega.aura`;
     - domain `<project-ref>.supabase.co`;
     - return URL `https://<project-ref>.supabase.co/auth/v1/callback`.
   - **Key.** *Keys → +*, enable Sign in with Apple and pick the primary App ID. Download the `.p8` (you can only download it once) and note the **Key ID**.
   - **Client secret.** Generate the JWT from Team ID + Key ID + Services ID + `.p8`. Supabase's Apple guide has a generator. **It expires after at most 6 months:** put a renewal reminder in the calendar.
4. **Account deletion (App Review 5.1.1(v)).** Apple requires apps that offer Sign in with Apple to **revoke the user's Apple tokens** when the account is deleted, using the Sign in with Apple REST API. Implemented: the app sends Apple's one-time `authorizationCode` to NestJS right after sign-in, NestJS keeps the refresh token (sealed) and revokes it when the deletion is requested and in the purge. It needs a **Sign in with Apple key** on the server: see [section 10](#10-apple-token-revocation-account-deletion-app-review-511v).

## 3. Build configuration

### iOS URL scheme: `apps/mobile/ios/Flutter/Secrets.xcconfig` (gitignored)

```bash
cp apps/mobile/ios/Flutter/Secrets.xcconfig.example apps/mobile/ios/Flutter/Secrets.xcconfig
# then set the reversed iOS client id:
# AURA_GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234-abcd
```

`Debug.xcconfig` and `Release.xcconfig` include it with `#include?`. `Info.plist` registers `$(AURA_GOOGLE_REVERSED_CLIENT_ID)` as a URL scheme.

Without the file, a placeholder keeps the build valid. Tapping Google then shows "That sign-in option isn't ready yet", because GoogleSignIn refuses to start without its scheme.

### `--dart-define`s (none of these are secrets)

| Define | Default | Meaning |
|---|---|---|
| `AURA_SOCIAL_SIGNIN` | `true` | Master switch. `false` hides Apple and Google in this build. |
| `AURA_GOOGLE_WEB_CLIENT_ID` | — | Web client ID. Required for Google on both platforms. It's the `serverClientId` on Android and the audience Supabase checks. |
| `AURA_GOOGLE_IOS_CLIENT_ID` | — | iOS client ID. Required for Google on iOS. |
| `AURA_APPLE_SIGNIN` | `false` | Sign in with Apple is set up (App ID capability + Supabase lists the bundle ID). Shows the native Apple button on iOS. |
| `AURA_APPLE_SIGNIN_ANDROID` | `false` | Apple's browser flow is set up (Services ID + key in hosted Supabase). Shows Apple on Android. |

**App Store 4.8.** On iOS, Google is offered only when Apple is too. **Release and profile builds enforce this.** A debug build shows Google alone, so you can try it before Apple is ready, and it hides Google otherwise. For anything that goes to TestFlight or App Review, pass `AURA_APPLE_SIGNIN=true` together with the Google IDs.

Keep the values in a gitignored define file. `apps/mobile/.env.social` is already ignored by the root `.env.*` rule:

```bash
# apps/mobile/.env.social
AURA_GOOGLE_WEB_CLIENT_ID=1234-web.apps.googleusercontent.com
AURA_GOOGLE_IOS_CLIENT_ID=1234-ios.apps.googleusercontent.com
AURA_APPLE_SIGNIN=true
```

```bash
cd apps/mobile
flutter run -d "iPhone 17 Pro" --dart-define-from-file=.env.social   # iOS simulator
flutter run -d emulator-5554   --dart-define-from-file=.env.social   # Android emulator (Google Play image, signed into a Google account)
```

- **iOS simulator:** Sign in with Apple needs an Apple Account signed in under Settings.
- **Physical phone against the local stack:** also pass `SUPABASE_URL=http://<Mac LAN IP>:55521` and `AURA_API_URL=http://<Mac LAN IP>:3310`.

## 4. Supabase, local

1. Create **`supabase/.env`**. It's gitignored, and the CLI loads it automatically:

   ```bash
   # Google: WEB client id FIRST, then the iOS client id (comma-separated, no spaces).
   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=1234-web.apps.googleusercontent.com,1234-ios.apps.googleusercontent.com
   # Only for browser OAuth (not used by the app's native flow):
   SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=GOCSPX-…
   # Apple: the bundle id (native iOS). For Android/web, put the Services ID first:
   #   com.akvega.aura.signin,com.akvega.aura
   SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID=com.akvega.aura
   # Only for Apple's browser flow (Android); leave unset for iOS-only:
   # SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=<client-secret JWT>
   ```

2. **Restart the stack.** Provider settings are read only at start:

   ```bash
   supabase stop && supabase start        # from the repo root
   supabase migration up --include-all   # if 20261005000011_strip_oauth_profile.sql isn't applied yet
   ```

   While a variable is unset, the CLI prints `WARN: environment variable is unset: …` and starts anyway. The provider is then "enabled" with a placeholder client ID, so a real token gets `Unacceptable audience`, and the app shows "That sign-in option isn't ready yet. Use your email for now."

3. **Check:**

   ```bash
   curl -s http://127.0.0.1:55521/auth/v1/settings -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" | jq .external
   # → "apple": true, "google": true
   ```

`skip_nonce_check` stays **false** for both providers, iOS included. Supabase's guide says to skip it on iOS because GoogleSignIn-iOS used to put its own random nonce in the token. `google_sign_in_ios` ≥ 6.1 (GoogleSignIn-iOS 9) passes the app's nonce through, and Credential Manager on Android does the same. Turning the check off would let any Google token minted for an accepted client ID be replayed against Aura.

## 5. Supabase, hosted (dashboard)

- **Authentication → Sign In / Providers → Google**
  - Enabled.
  - **Client IDs:** `<WEB client id>,<iOS client id>`, web first.
  - **Client Secret:** the web client's secret (browser OAuth only).
  - **Skip nonce check:** off.
- **Authentication → Sign In / Providers → Apple**
  - Enabled.
  - **Client IDs:** `com.akvega.aura`. With Android/web, use `com.akvega.aura.signin,com.akvega.aura`, Services ID first.
  - **Secret Key (for OAuth):** the client-secret JWT (Android/web only; renew every 6 months).
- **Authentication → URL Configuration**
  - Redirect URLs include `aura://auth-callback`, for the magic link and Apple on Android.
- **Callback URL** shown on the provider pages (`https://<project-ref>.supabase.co/auth/v1/callback`): use it as the Google web client's redirect URI and the Apple Services ID return URL.
- **Database:** deploy the migrations (`supabase db push`), including `20261005000011_strip_oauth_profile.sql`.

## 6. Errors people can see

Every failure is a calm inline notice (`InlineNotice`). Closing Apple's or Google's sheet shows nothing. Tokens and emails are never logged; only error types are.

| What happened | Message | Usual cause |
|---|---|---|
| Sheet closed | *(nothing)* | — |
| Provider not ready | "That sign-in option isn't ready yet. Use your email for now." | Provider disabled / not restarted (`provider_disabled`). Client ID missing from the list (`Unacceptable audience`). Apple error 1000 (capability not on the App ID, or no Apple Account on the simulator). iOS URL scheme missing (`Secrets.xcconfig`). Android `[28444] Developer console is not set up correctly` (package / SHA-1 / web client ID mismatch). |
| No connection | "It looks like you're offline. Try again when you're connected." | Supabase unreachable; `NSURLErrorDomain`. |
| Anything else | "That didn't go through. Try again, or sign in another way." | E.g. `Nonces mismatch`: `skip_nonce_check` must stay false, and the token must come from this app's current sign-in. |

## 7. Privacy: email only

- **Apple:** the app requests the **email scope only** and never the name. Apple's `givenName`/`familyName` are never requested, read or sent. The email may be a private relay address. Treat that as normal; never ask for "a real email" (HIG).
- **Google:** Aura asks for nothing beyond email, but Google's native SDKs always put the basic profile (name, picture) in the ID token, and Supabase Auth copies token claims into `auth.users.raw_user_meta_data` and `auth.identities.identity_data`.
  - Migration **`20261005000011_strip_oauth_profile.sql`** adds `BEFORE INSERT OR UPDATE` triggers that drop `name`, `full_name`, `given_name`, `family_name`, `middle_name`, `nickname`, `preferred_username`, `user_name`, `picture`, `avatar_url`, `profile`, `website`, `gender`, `birthdate`, `zoneinfo`, `locale` and `slug` before anything is stored. This applies to every sign-in and to `updateUser(data: …)`.
  - It keeps `sub`, `email`, `email_verified`, `phone_verified`, `iss`, `provider_id` and `custom_claims`, which GoTrue uses.
  - Tested with pgTAP (`supabase/tests/11_strip_oauth_profile.test.sql`) and end to end through GoTrue. Email-OTP sign-in still works.
  - One gap the trigger can't close: GoTrue signs the *first* session from its in-memory user, so that one response still carries the name. The app refreshes the session right after a Google sign-in, so the session saved on the phone (and the token sent to NestJS) comes from the stripped database row.
- **Apple sign-in in the future:** if the name is ever wanted, it would need a PRD change. Don't call `updateUser` with Apple's name.

## 8. Platform age signals (REQ-ACC-04)

- The sign-in screen starts reading as soon as it opens. Any auth action (send code, Apple, Google, or "continue without an account") waits **at most 1 s** for the answer.
- **Signal under 13 → the existing under-13 block** (`GateController.blockUnder13`), whatever the DOB. No email is sent and no account is created.
- **Signal under 18 → the invisible under-18 flag** (the `minorUntil` key), even with an adult DOB. It's only ever extended, never shortened.
- **No signal, a declined share, or no answer within 1 s → the DOB alone.** A signal never hides a feature.
- **iOS 26.2+** (`AppDelegate.swift`, channel `com.akvega.aura/age_signals`): Apple's Declared Age Range is requested only where `AgeRangeService.isEligibleForAgeFeatures` is true, i.e. regions whose law requires age assurance, such as Texas. Nobody else sees Apple's share sheet. iOS < 26.2 → no signal. Needs the Declared Age Range capability (section 2). Test with sandbox age scenarios under Settings → Developer.
- **Android** (`MainActivity.kt`): Play Age Signals `com.google.android.play:age-signals:0.0.4` (beta; Brazil and Texas now). Shows no UI. Outside covered regions it returns no signal. Test with `FakeAgeSignalsManager` or Play Console test tracks.
- **On the server too:** the app sends the band it read with the next `POST /v1/profile` (`ageSignal: "under18"`, once per reading; contracts/api/v1.md "Onboarding / profile"). NestJS keeps it in the server-only `public.minor_signals` (local date + 5 years, only ever extended) and `user_is_minor()` combines it with the DOB, so the minors lane, stricter moderation and analytics exclusion apply even with an adult DOB. It is never returned to anyone. `ageSignal: "under13"` is refused like an under-13 DOB (the app blocks before sign-in anyway).

## 9. Branding

- **Apple:** a custom button in the HIG **white** style for dark backgrounds, with Apple's logo artwork (`AppleLogoPainter` from `sign_in_with_apple`), the approved title "Continue with Apple" (localized), a title at 43% of the button height, and a pill corner radius to match Aura's buttons. It's 56 dp, so it's never smaller than the email button.
- **Google:** the **dark** theme (`#131314` fill, 1 px `#8E918F` stroke, `#E3E3E3` label) with the standard-colour "G".
  - The G is drawn as a vector from Google's pre-approved asset (`GoogleGMarkPainter`): the same path, conic gradient and highlights as `signin-assets.zip`.
  - Google's spec is scaled uniformly to 56 dp, and the label is "Continue with Google".
  - **One deviation:** Google specifies **Google Sans Medium** for the label, and the app uses the platform font at medium weight (Roboto on Android) because the font isn't bundled. To comply fully:
    1. Download Google Sans from fonts.google.com (OFL).
    2. Add a Medium instance under `apps/mobile/assets/fonts/`.
    3. Register it in `pubspec.yaml`.
    4. Set `fontFamily` on the label style in `GoogleSignInButton`.

## 10. Apple token revocation (account deletion, App Review 5.1.1(v))

**Why:** an app that offers Sign in with Apple must revoke the user's Apple tokens when they delete their account (PRD F8 REQ-ACC-11 "Apple token revoked"). Native Sign in with Apple hands the app a one-time **authorization code** (valid 5 minutes) next to the ID token. Supabase only needs the ID token, so without this step nobody ever holds a token that could be revoked.

**How it works** (contracts/api/v1.md "Sign in with Apple token"):

1. After a native Apple sign-in succeeds with Supabase, the app sends the code once, in the background, to `POST /v1/account/apple-auth` and ignores the answer. Sign-in never waits for it or depends on it.
2. NestJS exchanges the code at `https://appleid.apple.com/auth/token`, checks that the Apple user (`sub`) is this account's Apple identity, and keeps only the **refresh token**, sealed with `AURA_MASTER_KEY` (AES-256-GCM, like the notes' data keys) in `public.apple_auth_tokens`. Tokens and codes are never logged.
3. When the person asks to delete the account, NestJS revokes the token at `https://appleid.apple.com/auth/revoke` straight away (best effort). The worker's purge revokes anything still stored before it deletes the account. If Apple can't be reached, the purge retries hourly for up to **72 hours** after the 7-day grace period, then deletes the token unrevoked (logged as `appleAbandoned`).

**Setup (once, Apple Developer, team `AQLMTLP6PD`):**

1. **Keys → +** → name it (for example "Aura Sign in with Apple"), tick **Sign in with Apple**, *Configure* → primary App ID `com.akvega.aura` → *Save* → *Continue* → *Register*.
   - If you already made a key for Apple on Android (section 2, step 3), reuse it: one key serves every client of the team.
2. **Download the `.p8`.** Apple lets you download it only once: store it in the password manager, never in the repo.
3. Note the **Key ID** (10 characters) and the **Team ID** (`AQLMTLP6PD`).
4. Set these on **both** the API and the worker (DigitalOcean app env, or `server/aura-api/.env` locally):

   ```bash
   APPLE_TEAM_ID=AQLMTLP6PD
   APPLE_KEY_ID=ABC123DEFG               # the key's id
   APPLE_CLIENT_ID=com.akvega.aura       # the bundle id: native iOS codes are issued to it
   # The .p8 contents. Any of: the PEM with real newlines (quoted), the PEM on one line with \n escapes, or just
   # the base64 body between the BEGIN/END lines.
   APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg…\n-----END PRIVATE KEY-----"
   ```

5. Restart the API and the worker. The worker logs a warning at start while any of the four is missing.

**Checks:**

- Without the four values, `POST /v1/account/apple-auth` answers `503 apple_unavailable` (the app ignores it) and the worker warns at start. Sign-in keeps working.
- With them, a sign-in with Apple on a device adds one row to `public.apple_auth_tokens` for that account (`select user_id, client_id, created_at from public.apple_auth_tokens;` — the token itself is sealed).
- Deleting that account removes the row within seconds, and Aura disappears from the Apple Account's "Sign in with Apple" list (iOS Settings → Apple Account → Sign-In & Security → Sign in with Apple).

**Notes:**

- The client secret is minted per call (ES256 JWT, 1 hour), so there is **nothing to renew every 6 months** here. The Android/browser client secret in section 5 still expires.
- **Apple on Android** (browser OAuth through Supabase) returns no authorization code to the app, so those accounts have no stored token. Revoking them needs Supabase's provider refresh token (follow-up).
- Replacing `AURA_MASTER_KEY` makes stored tokens unreadable: the purge then drops them unrevoked.
