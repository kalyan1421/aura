# Aura mobile (`com.akvega.aura`)

Flutter app for iOS + Android. Offline-first: every personal write lands in the
encrypted local Drift store and the outbox in one transaction, then syncs to
NestJS (`POST /v1/sync/push`). Riverpod 3 (codegen) · GoRouter · Freezed ·
Drift · Supabase Auth · gen-l10n.

## Run

```bash
# from repo root: dart pub get   (pub workspace)
cd apps/mobile
dart run build_runner build          # Riverpod / Freezed / JSON / Drift codegen
python3 tool/l10n_source.py && flutter gen-l10n   # after copy changes
flutter run                          # local stack defaults (debug/profile only)
```

Local defaults (debug/profile builds only; release must pass real values):

| define | default | notes |
|---|---|---|
| `AURA_API_URL` | `http://127.0.0.1:3310` (Android emulator `http://10.0.2.2:3310`) | NestJS |
| `SUPABASE_URL` | `http://127.0.0.1:55521` (emulator `10.0.2.2`) | supabase/LOCAL.md |
| `SUPABASE_PUBLISHABLE_KEY` | the CLI's fixed local publishable key | not a secret, local only |
| `AURA_SOCIAL_SIGNIN` | `false` | Apple / Google buttons shown but disabled |
| `AURA_BETA_LOCALES` | `false` | shows Hindi / Hinglish in pickers |
| `AURA_DEBUG_TOOLS` | `true` in debug | Settings → Avatar lab (`/debug/avatar`) |

Sign-in uses the email OTP; locally the code lands in Mailpit at
http://127.0.0.1:55524. The magic link redirects to `aura://auth-callback`
(registered on iOS + Android).

## Layout

```
lib/
  main.dart                 bootstrap: tz db, encrypted DB, gate state, Supabase
  l10n/                     ARB files (generated from tool/l10n_source.py) + gen-l10n output
  src/app.dart              MaterialApp.router, locale, lifecycle → sync
  src/core/                 env, theme tokens, router, db (Drift), sync (outbox,
                            push, pull), security (secure store, note cipher),
                            net (API client + Freezed DTOs), l10n, time, ids
  src/features/             onboarding (welcome, DOB gate, under-13 block, language),
                            auth (email code sign-in), checkin (F1), habits, home,
                            progress (local projection ⇄ server snapshot), avatar
                            (hybrid renderer + debug lab), support (help sheet,
                            grounding, lexicon seed), settings, profile,
                            push (FCM registration: PushService + explainer)
shaders/                    aura_glow.frag, aura_nebula.frag
assets/avatar/              aura_base.webp (runtime), aura_base.png (fallback), manifest.json
assets/fonts/               Noto Sans Telugu + Devanagari (OFL)
```

## Push (FCM registration)

Firebase project `aura-akvega`, initialised from Dart (`lib/firebase_options.dart`,
hand-written in the `flutterfire configure` shape). If Firebase fails to start,
the app starts anyway with push off. Only Cloud Messaging: no Analytics
(PostHog), no Crashlytics (Sentry). No `google-services` Gradle plugin: with
Dart-side options only Crashlytics / Performance need it.

- FCM auto-init is **off** (Info.plist `FirebaseMessagingAutoInitEnabled`,
  manifest `firebase_messaging_auto_init_enabled`), so no token exists until
  the user opts in. `PushService` turns it on after the soft ask and off at
  sign-out.
- The explainer ("Want a gentle nudge each evening?") shows once, when Done is
  tapped after a saved check-in; "Allow" fires the OS prompt, "Not now" never
  does (iOS registers provisional authorisation instead).
- Then: signed in + profile on the server → (iOS: APNs token) → FCM token →
  `PUT /v1/devices`; re-registers on token refresh; offline → retried after the
  next successful sync. Payloads are `{type, id?}` only; just the type is
  logged, in debug.
- **Sign-out** unregisters push, ends the session and wipes every personal row
  and user-scoped key on the phone (`SignOutService`); only the under-13 lock,
  DB key, device id, language and an owed FCM `deleteToken()` stay.
- iOS: `Runner/Runner.entitlements` (`aps-environment`) + background mode
  `remote-notification`. Push needs the APNs `.p8` key uploaded in the Firebase
  console and the Push Notifications capability on the App ID.

## Encryption

- **Local DB:** Drift on SQLite3MultipleCiphers (`PRAGMA key` with a random
  256-bit key from Keychain/Keystore). `package:sqlite3` 3.x selects the cipher
  build through a build-hook user-define — **Flutter reads user-defines only
  from the workspace-root `pubspec.yaml`**, so this block must live there (it is
  also mirrored in this package's pubspec for documentation):

  ```yaml
  hooks:
    user_defines:
      sqlite3:
        source: sqlite3mc
  ```

  Without it the app runs on plain SQLite (the `PRAGMA key` is ignored).
  Verified separately: with the define, the file header is encrypted
  (`PRAGMA cipher` → `chacha20`) and unreadable without the key.
- **Notes:** encrypted on device with the per-user data key from
  `GET /v1/keys/data-key` (AES-256-GCM, `0x01 | nonce(12) | ct | tag(16)`,
  base64, record id as associated data) right before push. The outbox payload
  never holds plaintext; rows with a note wait until the key is available.

## Localization — NEEDS NATIVE REVIEW

`en`, `te`, `te-Latn` (Tenglish) ship in alpha; `hi` / `hi-Latn` files exist and
fall back to English (TODO, beta). Flutter names romanized ARB files by script
code: `app_te_Latn.arb` with `"@@locale": "te_Latn"` →
`Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn')`.

**All Telugu and Tenglish UI copy in `tool/l10n_source.py` is a first draft and
NEEDS NATIVE REVIEW** (10+ native speakers per the PRD), especially the stage
names (రవ్వ / నిప్పు కణిక / వెలుగు / తేజస్సు / నక్షత్ర మండలం), quadrant names,
habit labels and every string on the help sheet. Mood names come from
`contracts/moods.json` (also drafts). System strings (Material/Cupertino) for
`te-Latn` / `hi-Latn` fall back to English. Telugu/Devanagari text uses the
bundled Noto fonts with line height 1.55.

The crisis-lexicon seed in `lib/src/features/support/crisis_lexicon.dart` is a
placeholder for the F9 lexicon bundle and also NEEDS NATIVE + safe-messaging
review.

## Avatar

`AuraAvatar` = pure function of `AuraAvatarState` + time. Hybrid: the character
art (`assets/avatar/aura_base.webp`) is the base; everything alive is code.
Layers, back to front: shader aura glow (hue, glowLevel, stage halo) → Resting
Nebula shader clouds → orbs/ring arcs behind the body → the breathing base
(±2 % scale, ~4 px float, 6 s cycle / 9 s resting, ≤ 18 % hue tint) → Nebula
front wisps → brow + heart glints → orbs/ring arcs in front → sparkles and
particles → constellation arc. All positions come from `manifest.json`
(normalized anchors + ring paths with depth), so a new base needs only a new
manifest. Tiers: High / Low (frames over budget) / Still (Reduce Motion).
Fallbacks: shader → painter-only → plain base → painted orb (never blank).
Debug lab: Settings → Avatar lab, or `/debug/avatar`.

## Tests

`flutter test` — check-in (2-tap save → outbox), under-13 gate (+ relaunch),
avatar smoke (every stage × resting × tier × shader on/off) + goldens (every
stage × resting, base art loaded), sync (profile first, push/ack, note
ciphertext, backoff, dead-letter), l10n, projection. Domain rule vectors run in
`packages/aura_domain` (`dart test`). Regenerate goldens with
`flutter test --update-goldens test/avatar_painter_test.dart`.
