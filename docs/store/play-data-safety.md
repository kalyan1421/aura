# Google Play Data safety form: Aura

**For:** Play Console → App content → Data safety, for `com.akvega.aura` (developer AKVega). PRD 20-timeline weeks 43–48.
**Derived from the code** on branch `fix/design-audit` after `c521ceb` (25 Sep 2026). **Keep in step with** `docs/store/app-privacy-labels.md` (same data, Apple's categories).
**Status:** draft answers for AK. Items marked `[LEGAL]` or `[VERIFY]` need confirming.

## 1. Ground rules used (Play definitions)

- **Collected** means transmitted off the device. On-device-only processing is not collected: the crisis lexicon, the Play Age Signals value, Look back and Sanctuary. Envelope-encrypted content still counts as collected, because AKVega's server can unwrap it.
- **Shared** means transferred to a third party. Transfers to **service providers** that process data on AKVega's behalf are **not sharing**: Supabase, DigitalOcean, OpenAI moderation (`store: false`), Firebase Cloud Messaging and Google Play Billing. Nothing is sold or passed to advertisers. **Answer: no data shared.**
- **Ephemeral:** nothing is declared ephemeral, since everything collected is stored.
- The binary contains **no ad SDK and no AD_ID**. `com.google.android.gms.permission.AD_ID` is removed in `AndroidManifest.xml` and verified in the merged release manifest. Firebase Analytics is deactivated (`firebase_analytics_collection_deactivated`), and FCM auto-init is off until the user opts in to push.

## 2. Overview answers

| Question | Answer | Basis |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | §3 |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | HTTPS only in release: `usesCleartextTraffic="false"` (`android/app/src/main/AndroidManifest.xml`), and release base URLs must be https (`lib/src/core/env/env.dart` `releaseSafeBaseUrl`). Supabase and FCM use TLS. |
| Do you provide a way for users to request that their data is deleted? | **Yes** | In app, plus a web route (§5) |
| Account creation methods | Email OTP / magic link, Sign in with Google (plus Sign in with Apple via browser OAuth on Android when `AURA_APPLE_SIGNIN_ANDROID` is on) | `features/auth/` |
| Delete account URL (**required** for apps with accounts) | **Needs AK:** publish `https://<domain>/delete-account` (see §5) | Play User Data policy |
| Committed to the Play Families Policy? | **No**. Aura is not directed at children (13+, under-13s blocked). Target audience in Play Console: **13–15, 16–17, 18+** `[LEGAL]` (see `age-rating.md`). | F8 |
| Independent security review (MASA) | **No** (optional). The MASVS L1 self-assessment is in `docs/security/masvs-l1.md`. A MASA (App Defense Alliance) validation can be added later. | — |

## 3. Data types

Every row is **collected: yes, shared: no**. "Required" means the user can't use the feature without it.

| Play category → type | Collected | Required / optional | Purposes | What it is in Aura | Justified by (code / table) |
|---|---|---|---|---|---|
| Personal info → **Email address** | Yes | Required (sign-in) | App functionality, Account management | Sign-in identity; deletion-case verification; the trial-ending email | Supabase `auth.users`; `server/aura-api/src/user-mail/`; `admin_deletion_cases` |
| Personal info → Name | **No** | — | — | Google name and picture claims are stripped; Apple asks for no name | `supabase/migrations/20261005000011_strip_oauth_profile.sql` |
| Personal info → **User IDs** | Yes | Required | App functionality, Account management | Supabase `user_id`; `obfuscatedAccountId` on Play purchases | `public.profiles`; `server/aura-api/src/billing/billing.tokens.ts` |
| Personal info → **Other info** | Yes | Required (DOB); automatic (rest) | App functionality, Account management; DOB also Fraud prevention, security and compliance (age gate) | **Full date of birth** (DS-6). Under-18 platform-signal flag. UI locale and language pool. Timezone and region from device settings. Consents. | `public.profiles.birth_date`, `minor_signals`, `user_consents`; `POST /v1/profile` |
| Personal info → Address, Phone, Race and ethnicity, Political or religious beliefs, Sexual orientation | **No** | — | — | Aura collects no gender, caste or religion fields | — |
| Financial info → **Purchase history** | Yes | Optional (only if buying) | App functionality | Plus subscription state, sky cosmetics, gifts and the Stardust ledger, verified via the Play Developer API and RTDN | `public.subscriptions`, `purchases`, `entitlements`, `gifts`, `stardust_ledger`, `user_cosmetics`, `store_notifications` |
| Financial info → Payment info, Credit score, Other | **No** | — | — | Google Play handles payment | — |
| Health and fitness → **Health info** | Yes | Required (the core check-in) | App functionality | Mood check-ins (mood, quadrant, tags, day), treated as health data (PRD F9, Play health policy). **Never used for ads.** | `public.check_ins` |
| Health and fitness → Fitness info | **No** | — | — | No Health Connect. Breathing sessions are usage, see App activity. | — |
| Messages → Emails, SMS or MMS, **Other in-app messages** | **No** `[VERIFY]` | — | — | There are no messages between users (no DMs, no replies). Room reflections are declared as user-generated content below. If Play review reads reflections as "in-app messages", move that row here (App functionality, optional). | F6; PRD 22 |
| Photos and videos → **Photos** | Yes | Optional | App functionality | Up to 3 photos per time capsule, via the Android Photo Picker, EXIF/GPS stripped, encrypted, private | `features/capsules/`; `private-media` bucket |
| Audio → **Voice or sound recordings** | Yes | Optional | App functionality | Voice notes on check-ins and capsules, encrypted before upload | `features/voice/`; `check_ins.voice_path`; `private-media` |
| Audio → Music files, Other audio | **No** | — | — | Sounds stems are downloaded to the phone, not uploaded | — |
| Files and docs, Calendar, Contacts | **No** | — | — | — | — |
| App activity → **App interactions** | Yes | Automatic | App functionality | Room memberships, gestures, Breath Ripples seats, Quiet Together joins, Sanctuary sessions (activity, duration), notification preferences, guidelines acceptance, active days, keepsakes | `room_members`, `room_gestures`, `ripple_seats`, `quiet_members`, `sanctuary_sessions`, `notification_prefs`, `guidelines_acceptances`, `active_days`, `keepsakes` |
| App activity → **Other user-generated content** | Yes | Optional | App functionality | Private notes and capsule text (encrypted). Custom habit and tag names. **Room reflections**: ≤ 200 characters, shown to room members under a pseudonym, moderated (lexicon, then OpenAI omni-moderation, then human); final decisions also kept de-identified to train Aura's own safety filters (Settings opt-out; never under-18 authors; REQ-SAFE-16). Reports. | `check_ins.note_ct`, `capsules.payload_ct`, `habits`, `reflections`, `reports`, `moderation_corpus` |
| App activity → In-app search history, Installed apps, Other actions | **No** | — | — | — | — |
| Web browsing | **No** | — | — | No WebView | — |
| App info and performance → Crash logs, Diagnostics, Other | **No, today** | — | — | Sentry is linked but never started (§4) | `pubspec.yaml` |
| Device or other IDs → **Device or other IDs** | Yes | Automatic | App functionality; Fraud prevention, security and compliance | Random **install id** (`X-Aura-Install`, HMAC-stored, device bans REQ-ADM-14); **FCM token** after push opt-in. No Android ID, no AD_ID. | `lib/src/core/remote_config/install_id.dart`; `device_installs`, `device_bans`, `device_tokens` |
| Location → Approximate, Precise | **No** | — | — | No location permission. The region comes from settings, declared under Other info. `[VERIFY]` | PRD 15 |

**Not declared, with the reason:**
- Crisis sheet and helpline counters (`crisis_events`) carry no user or device id (DS-7): anonymous aggregates.
- Echo breath traces (`echo_library.recordings`) have no link to anyone.

## 4. What changes when PostHog and Sentry are switched on

Both are dependencies (`posthog_flutter`, `sentry_flutter`) but are **not initialised anywhere in `lib/`**. The Data safety form describes what the app *does*, so today they are not declared. **Update the form in the same release that turns either on.**

| Change | Form update |
|---|---|
| PostHog (18+ only, explicit events, random analytics UUID, IP discarded; PRD 13) | App activity → **App interactions**: add purpose **Analytics**. Device or other IDs: add **Analytics** if the analytics UUID counts as an identifier `[LEGAL]`. PostHog Cloud is a service provider, so still **not shared**. Collection stays automatic, but PRD 13 principle 5 gives 18+ users a "Help improve Aura" toggle; if it defaults off, mark it **optional** `[LEGAL]`. |
| Sentry | App info and performance → **Crash logs** and **Diagnostics**: collected, purpose **App functionality** (and Analytics if performance data is used for product decisions). Keep `sendDefaultPii` off. |
| Any ad or attribution SDK | Not planned (PRD 13 principle 8). It would change "shared" and require AD_ID, so don't add one without revisiting this file. |

## 5. Account deletion: the in-app path and the required web link

**In app (Apple 5.1.1(v), REQ-ACC-11):** Settings → Account → **Delete my account** → the screen explains what is deleted, the 7-day grace period, and that store subscriptions are cancelled in the store → confirm. This calls `POST /v1/account/deletion`, then the phone is wiped and signed out (`apps/mobile/lib/src/features/account/delete_account_screen.dart`; `contracts/api/v1.md` "Account deletion"). Signing in within 7 days offers "Keep my account". After that, the hourly `account-purge` job deletes every row in `PERSONAL_TABLES`, the private-media objects and the auth user, and revokes the Apple token (`server/aura-api/src/account/account-purge.ts`). That is well inside the 30 days the PRD promises.

**Web link (required by Play for apps with accounts; must work without reinstalling the app):**
- **What exists in code:** a deletion request by email or grievance form becomes a **deletion case**. The owner sends a verification link to the address on the account. The public page `GET /v1/deletion-requests/:token` lets the account holder confirm or decline (`server/aura-api/src/admin/deletion-cases.controller.ts:105-160`, REQ-ADM-11). The public grievance form is `POST /v1/grievances` (no login).
- **What AK must publish:** `https://<domain>/delete-account`, a static page on the website that:
  1. names **Aura** and **AKVega**, as the Play form requires the app or developer name on the page;
  2. describes the in-app path above;
  3. offers the web route: a form posting to `/v1/grievances` with category `data_request` ("My data or my account"), or the support/grievance email. Either one lands in the Grievance Officer's inbox. The owner then opens a deletion case, and the verification link goes to the email on the account (the requester never picks the address);
  4. lists what is deleted (check-ins, notes, voice, capsules and media, habits, rooms and reflections, keys, device tokens, profile including DOB), what is kept and for how long (purchase and tax records as law requires, evidence holds for 180 days, hashed audit rows) `[LEGAL]`, and the timing (7-day grace, then purge, always within 30 days).
- Enter that URL in Play Console → Data safety → "Delete account URL". Play also has an optional "delete data without deleting the account" URL. Aura has no partial-deletion flow except deleting individual check-ins in History, so answer **No** unless AK adds one.

## 6. Checklist before submitting

1. Fill in §2 and §3 in Play Console. Export the CSV and keep it next to this file for the next update.
2. Publish the deletion page (§5) and the privacy policy. Put the privacy policy URL in both Play Console and the app (`AURA_PRIVACY_URL`).
3. Also file the Health apps declaration (Play Console → App content → Health apps). Aura is **not** a medical device and makes no health claims (`apps/mobile/store/`). Pick the category closest to "stress management, relaxation, mental wellness" `[VERIFY]` the exact wording in the current form.
4. Declare the foreground service (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, Sounds) with a short video (PRD 15). This is a separate App content item.
5. Re-run whenever a table with a `user_id` or a new SDK is added.
