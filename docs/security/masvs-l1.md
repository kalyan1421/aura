# MASVS L1 self-assessment: Aura mobile app

**Scope:** PRD 20-timeline weeks 43–48, "MASVS L1", and the 09-technical-constraints NFR "OWASP MASVS L1 checklist before launch".
**Reviewed:** branch `fix/design-audit` after `c521ceb`, on 25 Sep 2026. **Reviewer:** Claude, for AK.
**App:** `apps/mobile` (Flutter 3.47.2 stable, `com.akvega.aura`, iOS 16+ / Android API 24+). The widget extension and Glance widget are included.
**Standard:** OWASP MASVS v2.1 controls. v2 moved the L1/L2/R split out of MASVS and into the MASTG testing profiles. "L1" here means the MAS-L1 profile: every control is assessed; controls or tests that are L2-only or R-only are marked as such; RESILIENCE is N/A at L1. PRIVACY is assessed in full because the store privacy labels depend on it (`docs/store/`).
**Server side** (NestJS, Supabase RLS, admin console) was reviewed separately in `docs/security/milestone-b-review.md` and is referenced, not repeated, here.
**Follow-ups closed** on 25 Sep 2026 after `49bd52a` (same branch): F-1, F-2, F-3, F-4, F-6, F-7 and Android release signing. See "Follow-ups closed" below; F-5 stays open.

## Summary

| Result | Count |
|---|---|
| Pass | 18 |
| Pass after fixes in this review | 5 (G-1 … G-5) |
| Follow-ups closed afterwards | 6 (F-1, F-2, F-3, F-4, F-6, F-7) + Android release signing |
| Gap, open (follow-up, does not block store submission) | 1 (F-5) |
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
| **STORAGE-1** The app securely stores sensitive data | **Pass** after G-2 and F-1 | **Database:** SQLite3MultipleCiphers via the `sqlite3` build hook (`pubspec.yaml` `hooks.user_defines.sqlite3.source: sqlite3mc`). The key is 32 bytes from `Random.secure()` (`lib/src/core/db/connection.dart:117`), stored in the Keychain/Keystore and applied with `PRAGMA key` as the first statement (`connection.dart:108`). **Secrets:** the DB key, the per-user data key, the under-13 lock and the install id are in `flutter_secure_storage` (`lib/src/core/security/secure_store.dart:25-34`). The Supabase session is there too since G-2. **Private content:** notes, voice notes and capsules are sealed with AES-256-GCM under the per-user data key before sync (`lib/src/core/security/note_cipher.dart:25-80`, DS-1); playback decrypts into temp files that are deleted after use (`lib/src/features/voice/voice_store.dart:70-80`). **Widget:** the App Group store holds only mood ids, the display state and the avatar PNG. Writes use `.completeFileProtectionUntilFirstUserAuthentication` (`ios/Runner/AuraWidgetChannel.swift:55`); Android uses `MODE_PRIVATE` prefs (`android/.../widget/AuraGlanceWidget.kt:87`). **F-1 (closed):** the App Group container is excluded from iCloud / Finder backup at every launch (`AuraWidgetChannel.excludeContainerFromBackup`). |
| **STORAGE-2** The app prevents leakage of sensitive data | **Pass** after G-1 and F-2 | **Backups:** Android has `allowBackup=false`, `fullBackupContent=false` and data-extraction rules that exclude every domain from cloud backup and device transfer (`AndroidManifest.xml:41-43`, `res/xml/data_extraction_rules.xml`). On iOS, the DB directory (G-1), `voice/` (`voice_store.dart:122-128`) and capsule media (`capsule_media_store.dart:42-44`) are all excluded. **Logs:** about 200 `debugPrint` calls, all of which log an error kind, status code or `runtimeType`, never content, ids, paths or tokens (`ApiException.toString` carries status and code only, `lib/src/core/net/aura_api.dart:9-60`). Note that `debugPrint` is not stripped in release (it goes to logcat and the iOS console), so the rule has to hold for every new log line; since F-2 an automated guard (`test/no_content_in_logs_test.dart`, server `test/unit/logs.no-content.spec.ts`) enforces it. **Notifications:** lock-screen copy never names a mood or quotes text (PRD 15; `features/push`). **Share cards:** built only from `ShareCardData`'s whitelisted fields (milestone line, stage, template palette, never mood or date: `lib/src/features/share/share_card_data.dart:7-20`, `share_card.dart:17-26`); the link token is random and never derived from the user id (`share_link.dart:15-17`). **Clipboard:** the app never copies personal text. **Screenshots / app switcher:** masking these is an L2 test (MASWE-0055), and the PRD asks for no screenshot block (share cards and screenshots are part of the growth loop); N/A at L1. |

### MASVS-CRYPTO

| Control | Status | Evidence and notes |
|---|---|---|
| **CRYPTO-1** Uses current strong cryptography | **Pass** | AES-256-GCM with a 96-bit random nonce, a 128-bit tag, and the record id as AAD (`note_cipher.dart:13-80`). Ed25519 signatures on remote config bundles (lexicon, helplines) (`lib/src/core/remote_config/signed_bundle.dart:16, 175`). SQLite3MultipleCiphers default cipher. Share and install tokens come from `Random.secure()`. No MD5/SHA-1/ECB, no custom crypto. |
| **CRYPTO-2** Key management follows best practice | **Pass** (F-3 closed) | Keys are generated with `Random.secure()` and stored in the Keychain/Keystore, never hard-coded. The only compiled-in key is the Supabase **local-dev** publishable key, which is not a secret and is not used in release (`lib/src/core/env/env.dart:60-64`). The data key is wrapped server-side by `AURA_MASTER_KEY` (DS-1; rotation is a server follow-up, milestone-b-review §5.6). F-3 (closed): the DB key and the per-user data keys are now `first_unlock_this_device`, so they never travel in a backup or a Quick Start transfer; older items move on first read (`DeviceBoundKeyStore`). |

### MASVS-AUTH

| Control | Status | Evidence and notes |
|---|---|---|
| **AUTH-1** Secure authentication and authorization protocols | **Pass** | Supabase GoTrue JWTs. Native Apple/Google sign-in via ID token with a nonce. Email OTP or magic link through PKCE (the supabase_flutter default; `lib/main.dart:48-53`), so an intercepted `aura://auth-callback` code is useless without the verifier. The server verifies JWTs (JWKS, aud/iss/exp), refuses anonymous and `service_role` sessions, and enforces RLS select-own (milestone-b-review §4). The app writes nothing directly: all writes go through `POST /v1/sync/push`. |
| **AUTH-2** Secure local authentication | **N/A** | No local or biometric unlock in v1. (`USE_BIOMETRIC` appears in the merged manifest from `flutter_secure_storage`, but the app never calls it.) |
| **AUTH-3** Additional authentication for sensitive operations | **N/A (L2)**; note | Account deletion needs a live session plus a 7-day grace period (`contracts/api/v1.md` "Account deletion"). No step-up is needed at L1. |

### MASVS-NETWORK

| Control | Status | Evidence and notes |
|---|---|---|
| **NETWORK-1** Secures all network traffic according to current best practices | **Pass** after G-3, G-4, F-4 | iOS ATS is fully on in Release and Profile: `Info.plist` has no `NSAppTransportSecurity` dictionary at all (F-4). Android refuses cleartext in release (G-3), and release base URLs must be https (G-4). Signed Storage URLs are used only as issued; loopback rewriting applies only to local hosts (`aura_api.dart:79-96`). Realtime channels are private (`features/rooms/room_realtime.dart:390`, `features/ripples/ripple_channel.dart:43`). F-4 (closed): `NSAllowsLocalNetworking` (for the local dev stack) is added to Debug builds only, by a build phase. |
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
| **CODE-2** Has a mechanism for enforcing app updates | **Pass** after F-6 | `GET /v1/config` carries `minAppVersion` per platform; an older app shows a calm full-screen "Please update Aura" with the store link, keeps "I need help now" reachable and deletes nothing (`lib/src/features/update/update_required.dart`). |
| **CODE-3** Only uses software components without known vulnerabilities | **Pass** after F-7 | Flutter 3.47.2 stable (26 Aug 2026). Resolved: supabase_flutter 2.17.2, gotrue 2.27.2, dio 5.11.1, flutter_secure_storage 11.2.0, sqlite3 3.6.0 (sqlite3mc), drift 2.35.0, cryptography 2.9.0, firebase_messaging 16.7.0, google_sign_in 7.2.0, sign_in_with_apple 8.2.0, in_app_purchase 3.3.1, share_plus 13.3.0, image_picker 1.2.3, url_launcher 6.3.2, flutter_local_notifications 22.3.1, go_router 18.0.1. F-7 (closed): `tools/audit/deps.sh` scans all three lockfiles; its first run found multer 2.2.0 (3 high, 1 low, DoS) under `@nestjs/platform-express` 11.2.5, fixed by the in-range update to 11.2.6 (multer 2.4.0). The API never parses multipart, so it wasn't reachable. **Dormant SDKs:** `posthog_flutter` 5.46.0 and `sentry_flutter` 9.30.1 are linked and bundled (their native frameworks and privacy manifests ship in the IPA) but never initialised. |
| **CODE-4** Validates and sanitizes all untrusted inputs | **Pass** | Remote lexicon and helplines are Ed25519-verified before use, and a release build rejects the dev key (`signed_bundle.dart`). Realtime `game:` events: the app acts only on numeric seat and enum fields and renders no free text (milestone-b-review §4). API responses are Freezed/json_serializable models. Deep links are allow-listed (PLATFORM-1). Photos are re-encoded with EXIF/GPS stripped on the phone (`features/capsules/capsule_media_store.dart:28, 125`). |

### MASVS-RESILIENCE

**N/A at L1** (MAS-R profile). Two notes for later: build release binaries with `--obfuscate --split-debug-info`, which also keeps symbol files for Sentry; and move device bans from the self-declared `X-Aura-Install` header to DeviceCheck / Play Integrity attestation (`lib/src/core/remote_config/install_id.dart:24-27`).

### MASVS-PRIVACY

| Control | Status | Evidence and notes |
|---|---|---|
| **PRIVACY-1** Minimizes access to sensitive data and resources | **Pass** | No location, contacts, camera, photo library read or ATT. Photos come from PHPicker / the Android Photo Picker. The microphone is requested only on first tap, and push only after the soft ask (PRD 15; `AndroidManifest.xml:3-28`, `Info.plist:34-45`). Google profile claims are stripped server-side (`supabase/migrations/20261005000011_strip_oauth_profile.sql`). FCM auto-init is off until the opt-in (`AndroidManifest.xml:91`, `Info.plist:69`), and Firebase Analytics is deactivated (`AndroidManifest.xml:105`, `Info.plist:72`). `AD_ID` is removed (G-5). |
| **PRIVACY-2** Prevents identification of the user | **Pass** | Pseudonyms are fresh per room, and no `user_id` reaches any stranger-facing payload (DS-10; contract tests). The install id is random, never hardware-derived, and stored as an HMAC server-side (`install_id.dart:9-27`). Crisis events are aggregate only (DS-7). |
| **PRIVACY-3** Transparent about data collection and usage | **Pass** after G-5 | The privacy manifests (G-5) match `docs/store/app-privacy-labels.md` and `docs/store/play-data-safety.md`. Permission strings follow PRD 15. The privacy policy URL is required in release builds (`Env.missingLegalConfig`). |
| **PRIVACY-4** Offers user control over their data | **Pass** | In-app deletion in 3 taps or fewer (`features/account/delete_account_screen.dart`; `POST /v1/account/deletion`, then a 7-day grace, then a full purge including storage and the Apple token). There is also a web and email route through verified deletion cases (`server/aura-api/src/admin/deletion-cases.controller.ts:105`). Look back and the streak number can be turned off. Echo recordings are opt-out (PRD 10). Export (REQ-ACC-12) is built (26 Sep 2026): Settings › Account › "Download a copy of my data" makes JSON + readable HTML + a check-in CSV on the phone and hands them to the share sheet, with `GET /v1/account/export` for server-held records; the screen warns that the files aren't encrypted (contracts/api/v1.md "Data export"). |

## Open follow-ups

| ID | Control | Item | Suggested fix | Size |
|---|---|---|---|---|
| F-5 | PLATFORM-1 | `aura://` custom scheme for auth and deep links. | Universal Links / App Links on the marketing domain (AASA and `assetlinks.json`, with the Play **app signing** SHA-256), then add the https redirect to the Supabase allow-list. | M |

## Follow-ups closed (25 Sep 2026)

| ID | Control | Status | What changed | Tests / evidence |
|---|---|---|---|---|
| F-1 | STORAGE-1/2 | **Done** | The App Group container (the widget's UserDefaults plist under `Library/Preferences`, the avatar PNG) is excluded from iCloud / Finder backup at every launch, from the app and the headless background engine: `isExcludedFromBackup` on the container, `Library` and `Library/Preferences` (a directory covers its contents and survives the atomic rewrites inside it), plus the avatar file after each write (`ios/Runner/AuraWidgetChannel.swift` `excludeContainerFromBackup`). **Minimisation reviewed, no change needed:** pending check-ins are mood-only (client id, mood id, day, owner token) and dropped once the app acknowledges them; the display state carries a last mood only when "Show my last mood" is on and nothing in Discreet mode; `triggerMoods` (mood ids with a capsule trigger, needed for the in-widget "Something from past you is waiting") is the only other personal hint. Widget behaviour is unchanged (the flag doesn't affect access). Plaintext at rest stays by design: the extension can't hold the database key, and the data is protected by `…UntilFirstUserAuthentication` file protection. Android was already covered by the backup rules. | `masvs_hardening_test.dart` "the widget App Group container is excluded from backup" (source check; the Swift runs only on device) |
| F-2 | STORAGE-2 | **Done** | Automated guards parse the code (Dart `package:analyzer`, TypeScript compiler API) and fail on a log argument that names sensitive data (notes, reflections, capsules, voice, DOB/birth, email, tokens/session/password/secret/OTP, text/body/content, paths), unless it ends in a content-free member (`.runtimeType`, `.length`, `.code`, …), or that stringifies an exception (`$e`, `e.message`, `String(err)`, `err.stack`). Reviewed exceptions live in an allowlist with a reason, and stale entries fail. **App:** no hits in `lib/**` (every log already used `runtimeType`/codes). **Server:** 4 real hits fixed with `src/common/log-scrub.ts` (quoted values in driver/parser error text become `"…"`, SQL identifiers kept): the unhandled-error filter's message **and stack** (milestone-b-review §5.11), BullMQ job-failure messages (`worker-host`, `user-mail`), and the storage-outage warning. 15 allowlist entries with reasons (bootstrap config errors, Redis/BullMQ connection errors, fixed OAuth messages, a mail error code). | `apps/mobile/test/no_content_in_logs_test.dart` (fixture + all of `lib/`), `server/aura-api/test/unit/logs.no-content.spec.ts` (fixture + all of `src/`, scrubber cases) |
| F-3 | CRYPTO-2 | **Done** | The DB key and per-user data keys are Keychain `…AfterFirstUnlockThisDeviceOnly` (`DeviceBoundKeyStore`, `lib/src/core/security/secure_store.dart`; used by `main.dart` and the widget's headless run). **No data loss on a new phone:** the DB file is already excluded from backup (G-1), so a restored key had nothing to open (the server is the restore path, PRD 16), and the data key is fetched again from `GET /v1/keys/data-key` after sign-in (wrapped server-side, DS-1). Only unsynced outbox items are lost on migration, as before. "After first unlock" keeps the widget background sync working on a locked phone. **Existing installs** move on first read (iOS only): flutter_secure_storage 11 finds an item at any accessibility and rewrites it at the new one; if that rewrite fails the value is written back, so the DB key is never lost; a marker makes it one-time; the headless background run only reads. The under-13 lock and the install id stay `first_unlock` (both survive reinstall either way). | `test/device_bound_keys_test.dart` (6) |
| F-4 | NETWORK-1 | **Done** | `Runner/Info.plist` has no `NSAppTransportSecurity`. The "ATS (Debug only)" Run Script phase (`ios/scripts/ats_debug_only.sh`, after Info.plist processing) adds `NSAllowsLocalNetworking` to `Debug*` builds and **fails** a Release or Profile build that contains any ATS exception. Verified: `flutter build ios --simulator --debug` → present; `flutter build ios --profile --no-codesign` → no ATS key in `build/ios/iphoneos/Runner.app/Info.plist`; the script exits 1 on a tainted Profile plist. | `masvs_hardening_test.dart` "the ATS local-networking exception is Debug-only" |
| F-6 | CODE-2 | **Done** | Server: `minAppVersion {ios?, android?}` in `GET /v1/config`, from `APP_MIN_VERSION_IOS/ANDROID` (validated at boot) and, while on, the `min_app_version` flag payload (the higher wins; switching the flag off drops back at once). App: reads its real version from the OS (`appVersion` on `com.akvega.aura/platform`), compares, and shows `UpdateRequiredScreen` above everything: calm copy in all 5 locales, the App Store / Google Play button, "I need help now" in the top bar (opens the Safety Center above it), Back disabled, nothing deleted or signed out; it goes away when the minimum is lowered. Unknown version or malformed value → no gate (fail open). contracts/api/v1.md "Remote config", docs/setup/lexicon-and-flags.md §4a. | Server `remote-config.spec.ts` (5), `remote-config.e2e-spec.ts` "minAppVersion"; app `test/update_required_test.dart` (13) |
| F-7 | CODE-3 | **Done** | `tools/audit/deps.sh`: `pnpm audit --prod` for `server/aura-api` and `apps/admin`; Dart advisories for `pubspec.lock` via `osv-scanner` when installed, else a direct api.osv.dev batch query (Pub ecosystem = GitHub advisories); `flutter pub outdated` as information. Exit 1 on any advisory, 2 when a check couldn't run. Run before every release and after dependency bumps (CI is parked). First run: multer, fixed (see CODE-3); now clean (260 Dart packages, both pnpm projects). | Run `bash tools/audit/deps.sh` |
| — | (release) | **Done** | Android release builds are signed from `android/key.properties` and **fail** without it (`:app:verifyReleaseSigning` runs before `preReleaseBuild`); no silent debug-key fallback. `AURA_DEBUG_SIGNED_RELEASE=1` is an explicit escape hatch for throwaway local builds (verified: builds, merged release manifest still has `usesCleartextTraffic=false`). `key.properties`, `*.jks`, `*.keystore` git-ignored; `android/key.properties.example`; `docs/setup/android-release-signing.md` (keystore, Play App Signing, SHA fingerprints). Verified: no file → fails naming the file; a file missing `keyPassword` → fails naming it; a complete file with a throwaway keystore → APK signed by that key (`apksigner`), keystore deleted after. | `masvs_hardening_test.dart` "Android release signing" |

**Outside MASVS but found in passing:**
- ~~`android/app/build.gradle.kts` signs `release` with the **debug** keystore.~~ Fixed (see "Follow-ups closed"). AK still has to create the upload key and enrol in Play App Signing (`docs/setup/android-release-signing.md`).
- `aps-environment` in `Runner.entitlements` is `development`. Xcode sets production on archive with a distribution profile; check the archived entitlements before submitting.
- PostHog and Sentry are linked and dormant. Their SDK privacy manifests (PostHog: product interaction and other usage data; Sentry: crash, performance and other diagnostic data, all "not linked") are bundled and show up in Xcode's privacy report. See `docs/store/app-privacy-labels.md` §4 for what to change when they are switched on. The alternative is to remove both packages until then.

## How to re-run

```sh
cd apps/mobile
flutter analyze && flutter test test/masvs_hardening_test.dart test/secure_session_storage_test.dart \
  test/no_content_in_logs_test.dart test/device_bound_keys_test.dart test/update_required_test.dart
flutter build ios --simulator --debug && flutter build apk --debug
# F-4: no ATS exception outside Debug (device build, no signing needed):
flutter build ios --profile --no-codesign && plutil -p build/ios/iphoneos/Runner.app/Info.plist | grep -i allows   # prints nothing
# release manifest check (no cleartext, no AD_ID); without key.properties use the explicit debug-signed escape hatch:
AURA_DEBUG_SIGNED_RELEASE=1 flutter build apk --release && grep -E 'usesCleartextTraffic|AD_ID' build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
# server log guard and remote config:
(cd ../../server/aura-api && pnpm test && pnpm lint)
# dependency scan (F-7):
bash ../../tools/audit/deps.sh
```
