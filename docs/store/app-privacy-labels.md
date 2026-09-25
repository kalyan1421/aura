# App Store privacy labels ("App Privacy"): Aura

**For:** App Store Connect → App Privacy, for `com.akvega.aura` (publisher AKVega). PRD 20-timeline weeks 43–48 ("Data Safety / privacy labels").
**Derived from the code** on branch `fix/design-audit` after `c521ceb` (25 Sep 2026), not from the PRD alone. **Keep in step with** `apps/mobile/ios/Runner/PrivacyInfo.xcprivacy` (the app's privacy manifest) and `docs/store/play-data-safety.md`.
**Status:** draft answers for AK. Items marked `[LEGAL]` need the lawyer and the privacy notice to agree. Items marked `[VERIFY]` need checking in App Store Connect.

## 1. Ground rules used

- **"Collected"** means Apple's definition: data transmitted off the device where AKVega or its processors can access it for longer than it takes to service the request in real time.
  - Data processed only on the phone is **not collected**. This covers the crisis lexicon, the Play/Apple age signal value, companion lines, Look back and the Sanctuary pacer.
  - Envelope-encrypted content (DS-1) **still counts as collected**, because AKVega's server can unwrap the per-user data key. It is not end-to-end encrypted.
- **Processors are not "third parties" for labels.** Supabase, DigitalOcean, OpenAI (moderation, `store: false`), Firebase Cloud Messaging and Apple/Google billing all act for AKVega. Their data is declared as AKVega's own collection.
- **Linked to identity:** everything tied to the Supabase `user_id` is linked. Aura has no unlinked product analytics yet.
- **Tracking:** none. Aura has no ad SDKs, no IDFA, no ATT prompt, no data broker sharing and no cross-app linking. The PrivacyInfo manifest declares `NSPrivacyTracking = false` with no tracking domains.
- **Under-13s** are blocked before any account exists (F8), so nothing is collected from them.

## 2. Answers

**"Do you or your third-party partners collect data from this app?" → Yes.**
**"Data Used to Track You" → None.**

| Apple data type | Collected? | Linked? | Tracking? | Purposes | What it is in Aura | Justified by (code / table) |
|---|---|---|---|---|---|---|
| **Contact Info → Email Address** | Yes | Yes | No | App Functionality | The sign-in identity: email OTP or magic link, Sign in with Apple (the email or its relay) and Google (email scope only). Also used for deletion-case verification and the trial-ending email. | Supabase `auth.users`; `apps/mobile/lib/src/features/auth/`; `server/aura-api/src/user-mail/trial-ending-email.ts`; `admin_deletion_cases` |
| Contact Info → Name | **No** | — | — | — | Apple sign-in asks for no full name. Google name and picture claims are stripped server-side. | `supabase/migrations/20261005000011_strip_oauth_profile.sql`; PRD F8 REQ-ACC-01 |
| Contact Info → Phone, Physical Address, Other | **No** | — | — | — | No phone OTP in v1. | — |
| **Health & Fitness → Health** | Yes | Yes | No | App Functionality | Mood check-ins (mood, quadrant, tags, local day). Mood data is treated as health data (PRD F9 "Mood data as health data", Apple 5.1.3). **Not** used for ads or data mining. `[VERIFY]`: Apple's "Health" type is phrased around medical data. Declaring it is the conservative reading, and it matches the PRD. | `public.check_ins` (`mood_id`, `quadrant`, `tags`); sync push `server/aura-api/src/sync/` |
| Health & Fitness → Fitness | **No** | — | — | — | Breathing sessions store activity and duration only, as usage (see Product Interaction), not exercise data. No HealthKit. | `public.sanctuary_sessions` |
| **User Content → Photos or Videos** | Yes | Yes | No | App Functionality | Up to 3 photos per time capsule. Picked with PHPicker, EXIF/GPS stripped on the phone, sealed with the data key, stored in the private bucket. Never shown to anyone else. | `features/capsules/capsule_media_store.dart`; `private-media` bucket; `public.capsules.media_paths` |
| **User Content → Audio Data** | Yes | Yes | No | App Functionality | Voice notes on check-ins and capsules, sealed with AES-256-GCM before upload. | `features/voice/voice_store.dart`; `check_ins.voice_path`; `private-media` |
| **User Content → Other User Content** | Yes | Yes | No | App Functionality | Private notes (encrypted) and capsule text (encrypted). Custom habit and tag names. **Reflections** (≤ 200 characters, posted to a mood room and visible to its members under a pseudonym; moderated by the on-device lexicon, then OpenAI omni-moderation, then a human; final decisions are also kept **de-identified** (text + language + label + week, no link to the person) to train Aura's own safety filters, with a Settings opt-out and never for under-18 authors, REQ-SAFE-16). Reports filed. | `check_ins.note_ct`, `capsules.payload_ct`, `habits`, `public.reflections`, `public.reports`, `public.moderation_corpus`; `server/aura-api/src/reflections/decide.ts` (OpenAI `store: false`), `src/reflections/corpus.ts` |
| User Content → Emails or Text Messages, Gameplay Content, Customer Support | **No** / see note | — | — | — | No DMs or messages. Breath Ripples keeps timings, not "content". Grievance tickets come in through a web or in-app form with an email for the reply `[VERIFY]`: if AK treats grievances as in-app "Customer Support", declare Customer Support (linked, App Functionality). | `server/aura-api/src/admin/grievances.controller.ts` |
| **Identifiers → User ID** | Yes | Yes | No | App Functionality | The Supabase `user_id` (UUID). Push registration, purchases (`appAccountToken`), sync. | `public.profiles`; `device_tokens`; billing `billing.tokens.ts` |
| **Identifiers → Device ID** | Yes | Yes | No | App Functionality (includes security and fraud prevention) | (1) The **install id**: random, stored in the Keychain, sent as `X-Aura-Install` on sign-in, push registration and room match, and kept only as an HMAC (device bans, REQ-ADM-14). (2) The **FCM registration token**, after push opt-in. No IDFA or IDFV. | `lib/src/core/remote_config/install_id.dart`; `public.device_installs`, `device_bans`, `device_tokens` |
| **Purchases → Purchase History** | Yes | Yes | No | App Functionality | Plus subscription state, cosmetics (skies), gifts and the Stardust ledger, validated by NestJS from App Store Server API / Notifications V2. Card details never reach Aura. | `public.subscriptions`, `purchases`, `entitlements`, `gifts`, `stardust_ledger`, `user_cosmetics`, `store_notifications` |
| Financial Info | **No** | — | — | — | Payments are handled by Apple. | — |
| **Usage Data → Product Interaction** | Yes | Yes | No | App Functionality | Server-side records the product needs: room memberships, gestures sent, Breath Ripples seats, Quiet Together joins, Sanctuary sessions (activity, duration), notification prefs, guidelines acceptance, active days, keepsakes. **Not analytics**: no PostHog events are sent (see §4). | `room_members`, `room_gestures`, `ripple_seats`, `quiet_members`, `sanctuary_sessions`, `notification_prefs`, `guidelines_acceptances`, `active_days`, `keepsakes` |
| Usage Data → Advertising Data, Other Usage Data | **No** | — | — | — | No ads. | — |
| Diagnostics (Crash, Performance, Other) | **No, today** | — | — | — | Sentry is linked in the binary but never started (§4). The server logs no request bodies. | `pubspec.yaml`; `lib/` has no `SentryFlutter.init` |
| Location (Precise, Coarse) | **No** | — | — | — | No location permission. `country` comes from the device region setting and `timezone` from the tz setting, not location services (declared under Other Data, below). `[VERIFY]` with the lawyer that region-from-settings needn't be "Coarse Location". | `features/profile/profile_service.dart:160-168`; PRD 15 "Location: not requested" |
| Contacts, Browsing History, Search History, Sensitive Info | **No** | — | — | — | Aura collects no gender, religion, caste or similar fields. | — |
| **Other Data → Other Data Types** | Yes | Yes | No | App Functionality | **Full date of birth** (DS-6: age gate, invisible under-18 protections). **Under-18 platform signal flag** (a boolean, only when a store age signal says under 18 but the DOB says adult). UI locale, language pool, IANA timezone and `tz_region`, device-region country (matching and Lantern Hour). Consents. | `public.profiles.birth_date`, `minor_signals`, `user_consents`; `POST /v1/profile` (`api_models.dart:132-140`) |

**Not collected even though they touch the network:**
- Crisis sheet and helpline taps go to an unauthenticated **aggregate counter** (`crisis_events`: surface, locale, country, time; no user or device id; DS-7). This is aggregate operational data, not data about a user.
- Echo breath traces (`echo_library.recordings`) are stored with **no link to anyone**. If AK wants them declared anyway: Product Interaction, **not linked**.

## 3. Where each answer shows up for the user

- The privacy policy, linked in App Store Connect and in the app (`Env.privacyPolicyUrl`; release builds refuse to ship without `AURA_PRIVACY_URL`), must list every row above, including OpenAI (cross-border moderation of reflections), Supabase (ap-south-1), DigitalOcean (Mumbai) and FCM `[LEGAL]`.
- **Account deletion (Apple 5.1.1(v))**, in the app: Settings → Account → "Delete my account" → confirm (3 taps or fewer), then `POST /v1/account/deletion`. After a 7-day grace period the hourly purge deletes every personal table (`server/aura-api/src/account/account-purge.ts` `PERSONAL_TABLES`), the private-media objects and the auth user, and revokes the Apple token. Purchase and tax records and evidence holds are kept only as the law requires `[LEGAL]`.

## 4. What changes when PostHog and Sentry are switched on

Both packages are in `apps/mobile/pubspec.yaml` (`posthog_flutter` 5.46.0, `sentry_flutter` 9.30.1) and their native frameworks ship in the app, but no Dart code initialises either. There is no `lib/src/core/analytics/` yet, despite the pubspec comment. Their own SDK privacy manifests are bundled:

| SDK | Its manifest declares |
|---|---|
| PostHog | Product Interaction and Other Usage Data, not linked, purpose Analytics |
| Sentry | Crash Data, Performance Data and Other Diagnostic Data, not linked, purpose App Functionality |

Xcode's privacy report will list those types today. Apple treats App Store Connect answers as the source of truth, so either answer as below at launch or remove the two packages until they are wired `[VERIFY]` in the pre-submission dry-run.

When they are turned on (PRD 13: 18+ only, explicit events, `distinct_id` = random analytics UUID, IP discarded):

| Change | New or changed answer |
|---|---|
| PostHog for 18+ users | **Usage Data → Product Interaction**: add purpose **Analytics**. Linked stays **Yes**: the analytics UUID maps to `user_id` in Postgres (PRD 13 principle 4), so treat it as linked unless the lawyer agrees otherwise `[LEGAL]`. |
| PostHog global properties (`country`, `app_language`, `plan`, `acq_channel`) | Covered by Product Interaction and Other Data, purpose **Analytics**. |
| PostHog identifiers | **Identifiers → User ID**: add purpose **Analytics** (the analytics UUID). |
| Sentry | **Diagnostics → Crash Data** and **Performance Data** (plus Other Diagnostic Data if breadcrumbs are on). Purpose **App Functionality**. **Not linked** only if Sentry never receives `user.id` or the install id. Keep `sendDefaultPii` off and scrub breadcrumbs of routes that carry ids. |
| Tracking | Still **No**. Neither SDK may be pointed at an ad or attribution network. |
| PrivacyInfo.xcprivacy | Add the same types and purposes to `ios/Runner/PrivacyInfo.xcprivacy`. |

## 5. Checklist before submitting

1. Enter §2 in App Store Connect → App Privacy. Keep "Data Not Used to Track You".
2. Add the privacy policy URL (App Information) and the Terms of Use (EULA) link for subscriptions (`apps/mobile/store/README.md`).
3. Generate Xcode's privacy report from the archive (Organizer → Generate Privacy Report). Every type in it should appear in §2, or be explained by §4.
4. Re-check this file whenever a new table with a `user_id` is added (the e2e suite already fails if `PERSONAL_TABLES` misses one), or whenever a new SDK arrives.
