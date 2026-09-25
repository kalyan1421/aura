# MASVS L1 self-assessment: Aura mobile app

**Scope:** PRD 20-timeline weeks 43–48, "MASVS L1", and the 09-technical-constraints NFR "OWASP MASVS L1 checklist before launch".
**Reviewed:** branch `fix/design-audit` after `c521ceb`, on 25 Sep 2026. **Reviewer:** Claude, for AK.
**App:** `apps/mobile` (Flutter 3.47.2 stable, `com.akvega.aura`, iOS 16+ / Android API 24+). The widget extension and Glance widget are included.
**Standard:** OWASP MASVS v2.1 controls. v2 moved the L1/L2/R split out of MASVS and into the MASTG testing profiles. "L1" here means the MAS-L1 profile: every control is assessed; controls or tests that are L2-only or R-only are marked as such; RESILIENCE is N/A at L1. PRIVACY is assessed in full because the store privacy labels depend on it (`docs/store/`).
**Server side** (NestJS, Supabase RLS, admin console) was reviewed separately in `docs/security/milestone-b-review.md` and is referenced, not repeated, here.

## Summary

| Result | Count |
|---|---|
| Pass | 18 |
| Pass after fixes in this review | 5 (G-1 … G-5) |
| Gap, open (follow-up, none blocks store submission on its own) | 7 (F-1 … F-7) |
| N/A at L1 | 5 |

**Fixed in this review**, each with regression tests:

| ID | Control | Gap | Fix | Test |
|---|---|---|---|---|
| G-1 | STORAGE-2 | The encrypted database file sat in iCloud backup: there was a `TODO(backup)` in `connection.dart`, and PRD 09 plus Apple 5.1.3 require the exclusion. | `openAppDatabase(…, excludeFromBackup:)` sets `isExcludedFromBackup` on the database directory (Application Support) at every launch, through the existing `com.akvega.aura/platform` channel. Failure is never fatal. `lib/src/core/db/connection.dart:29-72`, `lib/main.dart:31`. | `test/masvs_hardening_test.dart` "database backup exclusion" |
| G-2 | STORAGE-1 | The Supabase session (access and refresh token) was stored in supabase_flutter's default SharedPreferences: a plaintext plist on iOS, which is included in iCloud and iTunes backups, and plaintext XML on Android. | `SecureSessionStorage` keeps the session in the Keychain (`first_unlock_this_device`, so it never restores to another phone) or the Keystore. On upgrade it migrates the old copy and deletes it, so people stay signed in. It drops any session left by an earlier install, so no refresh happens before the DOB step (REQ-ACC-02). Used by both `Supabase.initialize` calls (the app and the widget's background refresh). `lib/src/core/security/secure_session_storage.dart`, `secure_store.dart:36-45`, `kv_store.dart` `sessionStore`. | `test/secure_session_storage_test.dart` (7) |
| G-3 | NETWORK-1 | minSdk is 24. Android 7.x and 8.x allow cleartext unless the app opts out, and the release manifest didn't. | `android:usesCleartextTraffic="false"` in `src/main`. `src/debug` and `src/profile` override it with `tools:replace` for the local dev stack. `android/app/src/main/AndroidManifest.xml:40`. | `masvs_hardening_test.dart` "Android manifest" |
| G-4 | NETWORK-1 | Release builds accepted any `AURA_API_URL` / `SUPABASE_URL`, including `http://`. | `releaseSafeBaseUrl` fails closed: a release build given a non-https URL runs offline-only. `Env.insecureReleaseConfig` lists the offending defines for the release checklist. `lib/src/core/env/env.dart:76-100, 163-177`. | `masvs_hardening_test.dart` "releaseSafeBaseUrl" |
| G-5 | PRIVACY-1/3 | There was no iOS privacy manifest for the app or the widget. The app's code (via `AuraWidgetCore`) uses App Group `UserDefaults`, a required-reason API, and App Store Connect rejects uploads with undeclared reasons (ITMS-91053). The `AD_ID` permission was not explicitly removed (PRD 13 principle 8). | Added `ios/Runner/PrivacyInfo.xcprivacy` (no tracking; collected types match `docs/store/app-privacy-labels.md`; UserDefaults `1C8F.1`, file timestamp `C617.1`) and `ios/AuraWidget/PrivacyInfo.xcprivacy` (UserDefaults `1C8F.1`), both in their targets' Resources phases. Added `AD_ID` with `tools:node="remove"` in the Android manifest. | `masvs_hardening_test.dart` "iOS", "no advertising id" |

## Control-by-control

Evidence is `path:line` relative to `apps/mobile/` unless a path says otherwise.

### MASVS-STORAGE

| Control | Status | Evidence and notes |
|---|---|---|
| **STORAGE-1** The app securely stores sensitive data | **Pass** after G-2; F-1 open | **Database:** SQLite3MultipleCiphers via the `sqlite3` build hook (`pubspec.yaml` `hooks.user_defines.sqlite3.source: sqlite3mc`). The key is 32 bytes from `Random.secure()` (`lib/src/core/db/connection.dart:117`), stored in the Keychain/Keystore and applied with `PRAGMA key` as the first statement (`connection.dart:108`). **Secrets:** the DB key, the per-user data key, the under-13 lock and the install id are in `flutter_secure_storage` (`lib/src/core/security/secure_store.dart:25-34`). The Supabase session is there too since G-2. **Private content:** notes, voice notes and capsules are sealed with AES-256-GCM under the per-user data key before sync (`lib/src/core/security/note_cipher.dart:25-80`, DS-1); playback decrypts into temp files that are deleted after use (`lib/src/features/voice/voice_store.dart:70-80`). **Widget:** the App Group store holds only mood ids, the display state and the avatar PNG. Writes use `.completeFileProtectionUntilFirstUserAuthentication` (`ios/Runner/AuraWidgetChannel.swift:55`); Android uses `MODE_PRIVATE` prefs (`android/.../widget/AuraGlanceWidget.kt:87`). **Open:** F-1 (widget App Group data is plaintext and in iCloud backup). |
| **STORAGE-2** The app prevents leakage of sensitive data | **Pass** after G-1; F-2 open | **Backups:** Android has `allowBackup=false`, `fullBackupContent=false` and data-extraction rules that exclude every domain from cloud backup and device transfer (`AndroidManifest.xml:41-43`, `res/xml/data_extraction_rules.xml`). On iOS, the DB directory (G-1), `voice/` (`voice_store.dart:122-128`) and capsule media (`capsule_media_store.dart:42-44`) are all excluded. **Logs:** about 200 `debugPrint` calls, all of which log an error kind, status code or `runtimeType`, never content, ids, paths or tokens (`ApiException.toString` carries status and code only, `lib/src/core/net/aura_api.dart:9-60`). Note that `debugPrint` is not stripped in release (it goes to logcat and the iOS console), so the rule has to hold for every new log line; F-2. **Notifications:** lock-screen copy never names a mood or quotes text (PRD 15; `features/push`). **Share cards:** built only from `ShareCardData`'s whitelisted fields (milestone line, stage, template palette, never mood or date: `lib/src/features/share/share_card_data.dart:7-20`, `share_card.dart:17-26`); the link token is random and never derived from the user id (`share_link.dart:15-17`). **Clipboard:** the app never copies personal text. **Screenshots / app switcher:** masking these is an L2 test (MASWE-0055), and the PRD asks for no screenshot block (share cards and screenshots are part of the growth loop); N/A at L1. |

### MASVS-CRYPTO

| Control | Status | Evidence and notes |
|---|---|---|
| **CRYPTO-1** Uses current strong cryptography | **Pass** | AES-256-GCM with a 96-bit random nonce, a 128-bit tag, and the record id as AAD (`note_cipher.dart:13-80`). Ed25519 signatures on remote config bundles (lexicon, helplines) (`lib/src/core/remote_config/signed_bundle.dart:16, 175`). SQLite3MultipleCiphers default cipher. Share and install tokens come from `Random.secure()`. No MD5/SHA-1/ECB, no custom crypto. |
| **CRYPTO-2** Key management follows best practice | **Pass** (F-3 note) | Keys are generated with `Random.secure()` and stored in the Keychain/Keystore, never hard-coded. The only compiled-in key is the Supabase **local-dev** publishable key, which is not a secret and is not used in release (`lib/src/core/env/env.dart:60-64`). The data key is wrapped server-side by `AURA_MASTER_KEY` (DS-1; rotation is a server follow-up, milestone-b-review §5.6). F-3: the DB key and data key use iOS `first_unlock` (not `…_this_device`), so they can travel in an *encrypted* iCloud backup. The DB file no longer does (G-1), so the key alone unlocks nothing; tightening it would orphan existing items, so it is recorded as a follow-up. |

### MASVS-AUTH

| Control | Status | Evidence and notes |
|---|---|---|
| **AUTH-1** Secure authentication and authorization protocols | **Pass** | Supabase GoTrue JWTs. Native Apple/Google sign-in via ID token with a nonce. Email OTP or magic link through PKCE (the supabase_flutter default; `lib/main.dart:48-53`), so an intercepted `aura://auth-callback` code is useless without the verifier. The server verifies JWTs (JWKS, aud/iss/exp), refuses anonymous and `service_role` sessions, and enforces RLS select-own (milestone-b-review §4). The app writes nothing directly: all writes go through `POST /v1/sync/push`. |
| **AUTH-2** Secure local authentication | **N/A** | No local or biometric unlock in v1. (`USE_BIOMETRIC` appears in the merged manifest from `flutter_secure_storage`, but the app never calls it.) |
| **AUTH-3** Additional authentication for sensitive operations | **N/A (L2)**; note | Account deletion needs a live session plus a 7-day grace period (`contracts/api/v1.md` "Account deletion"). No step-up is needed at L1. |

### MASVS-NETWORK

| Control | Status | Evidence and notes |
|---|---|---|
| **NETWORK-1** Secures all network traffic according to current best practices | **Pass** after G-3, G-4; F-4 note | iOS ATS is on, with no `NSAllowsArbitraryLoads` (`ios/Runner/Info.plist:46-51`). Android refuses cleartext in release (G-3), and release base URLs must be https (G-4). Signed Storage URLs are used only as issued; loopback rewriting applies only to local hosts (`aura_api.dart:79-96`). Realtime channels are private (`features/rooms/room_realtime.dart:390`, `features/ripples/ripple_channel.dart:43`). F-4: `NSAllowsLocalNetworking` is also in the release Info.plist, which permits http to `.local` and unqualified hosts. No production path uses it; move it to a Debug-only plist or xcconfig. |
| **NETWORK-2** Identity pinning for critical domains | **N/A (L2)** | No pinning, by design: Supabase and DigitalOcean certificate rotation would break a solo-maintained app. Revisit with the external pentest (milestone-b-review §5.16). |

### MASVS-PLATFORM

| Control | Status | Evidence and notes |
|---|---|---|
| **PLATFORM-1** Uses IPC mechanisms securely | **Pass** (F-5 note) | **Deep links:** `aura://` is allow-listed to 4 hosts with no parameters (`lib/src/core/router/deep_links.dart:27-32`), gated by the under-13 lock and onboarding (`deepLinkAction`), and they never replace a screen that may hold input. **Exported Android components:** `MainActivity` (launcher and deep links), the audio_service `AudioService` and `MediaButtonReceiver` (the media session needs both), `AuraWidgetReceiver`, and FCM receivers from Firebase; none takes app data. **Method channels:** `com.akvega.aura/platform`, `/age_signals`, `/store` and widget channels, all in-process. Age signals are never logged or sent raw (`MainActivity.kt`, `AppDelegate.swift`). **Widget:** the owner token keeps widget check-ins from being imported into another account (`lib/src/features/widget/widget_store.dart:55-60`). F-5: `aura://` is a custom scheme that another app can register. PKCE makes the auth callback safe, but moving to Universal Links / App Links (PRD 09 "GoRouter with Universal/App Links") is the durable fix. |
| **PLATFORM-2** Uses WebViews securely | **N/A** | No WebView. External pages (privacy, terms, subscription management) open in the system browser or StoreKit sheet (`lib/src/core/widgets/legal_links.dart:15`, `features/plus/plus_format.dart:80`); the Apple-on-Android OAuth goes through the browser via Supabase. |
| **PLATFORM-3** Uses the user interface securely | **Pass** (L1) | No sensitive data in notifications. The DOB field disables suggestions and autocorrect (`features/onboarding/dob_screen.dart:344-345`). Keyboard learning on the note field, and app-switcher masking, are L2 tests. |

### MASVS-CODE

| Control | Status | Evidence and notes |
|---|---|---|
| **CODE-1** Requires an up-to-date platform version | **Pass** | Min iOS 16 and API 24 (PRD 09); targetSdk follows the Flutter default, which meets the current Play requirement. |
| **CODE-2** Has a mechanism for enforcing app updates | **Gap, F-6** | No minimum-version gate. Remote config is signed and could carry `min_build`. It matters once a security fix must be forced; it isn't needed for submission. |
| **CODE-3** Only uses software components without known vulnerabilities | **Pass (manual)**; F-7 | Flutter 3.47.2 stable (26 Aug 2026). Resolved: supabase_flutter 2.17.2, gotrue 2.27.2, dio 5.11.1, flutter_secure_storage 11.2.0, sqlite3 3.6.0 (sqlite3mc), drift 2.35.0, cryptography 2.9.0, firebase_messaging 16.7.0, google_sign_in 7.2.0, sign_in_with_apple 8.2.0, in_app_purchase 3.3.1, share_plus 13.3.0, image_picker 1.2.3, url_launcher 6.3.2, flutter_local_notifications 22.3.1, go_router 18.0.1. No known advisories were found at review time, but no automated scanner runs yet. F-7: add `osv-scanner` over `pubspec.lock` in CI and before each release. **Dormant SDKs:** `posthog_flutter` 5.46.0 and `sentry_flutter` 9.30.1 are linked and bundled (their native frameworks and privacy manifests ship in the IPA) but never initialised. |
| **CODE-4** Validates and sanitizes all untrusted inputs | **Pass** | Remote lexicon and helplines are Ed25519-verified before use, and a release build rejects the dev key (`signed_bundle.dart`). Realtime `game:` events: the app acts only on numeric seat and enum fields and renders no free text (milestone-b-review §4). API responses are Freezed/json_serializable models. Deep links are allow-listed (PLATFORM-1). Photos are re-encoded with EXIF/GPS stripped on the phone (`features/capsules/capsule_media_store.dart:28, 125`). |

### MASVS-RESILIENCE

**N/A at L1** (MAS-R profile). Two notes for later: build release binaries with `--obfuscate --split-debug-info`, which also keeps symbol files for Sentry; and move device bans from the self-declared `X-Aura-Install` header to DeviceCheck / Play Integrity attestation (`lib/src/core/remote_config/install_id.dart:24-27`).

### MASVS-PRIVACY

| Control | Status | Evidence and notes |
|---|---|---|
| **PRIVACY-1** Minimizes access to sensitive data and resources | **Pass** | No location, contacts, camera, photo library read or ATT. Photos come from PHPicker / the Android Photo Picker. The microphone is requested only on first tap, and push only after the soft ask (PRD 15; `AndroidManifest.xml:3-28`, `Info.plist:34-45`). Google profile claims are stripped server-side (`supabase/migrations/20261005000011_strip_oauth_profile.sql`). FCM auto-init is off until the opt-in (`AndroidManifest.xml:91`, `Info.plist:69`), and Firebase Analytics is deactivated (`AndroidManifest.xml:105`, `Info.plist:72`). `AD_ID` is removed (G-5). |
| **PRIVACY-2** Prevents identification of the user | **Pass** | Pseudonyms are fresh per room, and no `user_id` reaches any stranger-facing payload (DS-10; contract tests). The install id is random, never hardware-derived, and stored as an HMAC server-side (`install_id.dart:9-27`). Crisis events are aggregate only (DS-7). |
| **PRIVACY-3** Transparent about data collection and usage | **Pass** after G-5 | The privacy manifests (G-5) match `docs/store/app-privacy-labels.md` and `docs/store/play-data-safety.md`. Permission strings follow PRD 15. The privacy policy URL is required in release builds (`Env.missingLegalConfig`). |
| **PRIVACY-4** Offers user control over their data | **Pass** | In-app deletion in 3 taps or fewer (`features/account/delete_account_screen.dart`; `POST /v1/account/deletion`, then a 7-day grace, then a full purge including storage and the Apple token). There is also a web and email route through verified deletion cases (`server/aura-api/src/admin/deletion-cases.controller.ts:105`). Look back and the streak number can be turned off. Echo recordings are opt-out (PRD 10). Export (REQ-ACC-12, P1) is not built yet; it is tracked in the PRD, not here. |

## Open follow-ups

None of these blocks store submission alone. F-1, F-2 and F-4 are small; do them before the review dry-run if time allows.

| ID | Control | Item | Suggested fix | Size |
|---|---|---|---|---|
| F-1 | STORAGE-1/2 | iOS widget App Group data (pending mood-only check-ins, display state, avatar PNG) is plaintext and in iCloud backup. Android is covered by the backup rules. | Set `isExcludedFromBackup` on the App Group container's `Library` directory from the app (`AuraWidgetChannel.swift`). Keep pending check-ins to mood ids (they already are). | S |
| F-2 | STORAGE-2 | The "no content in logs" rule depends on review; `debugPrint` prints in release. | Add a lint test that fails on `debugPrint(` lines interpolating anything other than `runtimeType`, `.code`, `.kind`, `.name` or status. Or route logging through a wrapper that is silent in release. | S |
| F-3 | CRYPTO-2 | The DB key and data key are `first_unlock`, not `…_this_device`. | Migrate on read: write the value to a `this_device` item, then delete the old one. Needs care, because a lost DB key resets the local DB. | M |
| F-4 | NETWORK-1 | `NSAllowsLocalNetworking` is in the release `Info.plist`. | Put the ATS exception in a Debug-only `Info-Debug.plist` or an `INFOPLIST_PREPROCESS` define. | S |
| F-5 | PLATFORM-1 | `aura://` custom scheme for auth and deep links. | Universal Links / App Links on the marketing domain (AASA and `assetlinks.json`), then add the https redirect to the Supabase allow-list. | M |
| F-6 | CODE-2 | No forced-update mechanism. | Add `min_build` to the signed remote config, plus a calm "please update" screen that keeps Safety Center reachable. | S–M |
| F-7 | CODE-3 | No automated dependency scan. | `osv-scanner --lockfile=pubspec.lock` (and the pnpm lockfiles) in CI and the release checklist. | S |

**Outside MASVS but found in passing:**
- `android/app/build.gradle.kts` still signs `release` with the **debug** keystore (the Flutter template TODO). Create the upload key and a `key.properties`-based `signingConfig` before the first Play upload, and enrol in Play App Signing.
- `aps-environment` in `Runner.entitlements` is `development`. Xcode sets production on archive with a distribution profile; check the archived entitlements before submitting.
- PostHog and Sentry are linked and dormant. Their SDK privacy manifests (PostHog: product interaction and other usage data; Sentry: crash, performance and other diagnostic data, all "not linked") are bundled and show up in Xcode's privacy report. See `docs/store/app-privacy-labels.md` §4 for what to change when they are switched on. The alternative is to remove both packages until then.

## How to re-run

```sh
cd apps/mobile
flutter analyze && flutter test test/masvs_hardening_test.dart test/secure_session_storage_test.dart
flutter build ios --simulator --debug && flutter build apk --debug
# release manifest check (no cleartext, no AD_ID):
flutter build apk --release && grep -E 'usesCleartextTraffic|AD_ID' build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
```
