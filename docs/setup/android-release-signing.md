# Android release signing and Play App Signing

**Why:** until now `apps/mobile/android/app/build.gradle.kts` signed `release` builds with the **debug** key (the
Flutter template default), which Play rejects and which anyone with the Flutter SDK has. Release builds are now signed
with Aura's **upload key**, read from `apps/mobile/android/key.properties`, and **a release build fails** when that file
or the keystore is missing. It never falls back to the debug key. Debug and profile builds are unaffected.

(MASVS follow-up, docs/security/masvs-l1.md "Outside MASVS but found in passing".)

## How it works

| Build | Signing |
|---|---|
| `flutter run`, `flutter build apk --debug` | Debug key (unchanged) |
| `flutter build apk --profile` | Debug key (unchanged; Flutter's profile type copies debug) |
| `flutter build apk --release`, `flutter build appbundle`, `flutter run --release` | Upload key from `android/key.properties`. **Missing → the build stops** at `:app:verifyReleaseSigning` with a message that points here. |
| `AURA_DEBUG_SIGNED_RELEASE=1 flutter build apk --release` | Debug key, on purpose (a Gradle warning, visible with `-v`). Only for a throwaway local release build (e.g. checking the merged release manifest). Play refuses these. |

Git ignores `key.properties`, `*.jks` and `*.keystore` (`apps/mobile/android/.gitignore` and the root `.gitignore`).
The template `apps/mobile/android/key.properties.example` is committed.

## 1. Create the upload key (once, on AK's machine)

Keep the keystore **outside the repo** and back it up (password manager + an offline copy). With Play App Signing the
upload key can be reset if lost, but that takes a support request and days.

```sh
mkdir -p ~/keys/aura
keytool -genkeypair -v \
  -keystore ~/keys/aura/aura-upload.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias upload \
  -dname "CN=AKVega, O=AKVega, C=IN"
```

`keytool` comes with any JDK (Android Studio bundles one: `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`).
With PKCS12 the key password is the store password; use the same value for both fields below.

## 2. Point the build at it

```sh
cd apps/mobile/android
cp key.properties.example key.properties
```

```properties
storeFile=/Users/<you>/keys/aura/aura-upload.jks
storePassword=<the store password>
keyAlias=upload
keyPassword=<the same password>
```

`storeFile` may also be relative to `apps/mobile/android/`. Never commit `key.properties`; check with
`git check-ignore -v apps/mobile/android/key.properties`.

Then build:

```sh
cd apps/mobile
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=AURA_API_URL=https://… (the rest of the release defines)
```

Check the signature: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab` must show
`CN=AKVega`, never `CN=Android Debug`. For an APK use `$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs app-release.apk`
(APKs for API 24+ carry only v2/v3 signatures, which `keytool` can't read).

## 3. Play App Signing (first upload)

1. Play Console → create the app `com.akvega.aura` (AKVega developer account).
2. **Test and release → App integrity → App signing**: keep the default, **"Let Google manage and protect your app
   signing key"** (Play App Signing). Google generates and holds the *app signing key*; the key you created above is
   only the *upload key*.
3. Upload the first `.aab` (internal testing track is fine). Play registers its signing certificate as the upload key.
4. From **App integrity**, copy the **app signing key certificate** SHA-1 and SHA-256 (not the upload key's) and add
   them where Android identity is checked:
   - Firebase project → Android app `com.akvega.aura` → SHA certificate fingerprints (FCM, and Google sign-in via
     Firebase if used).
   - Google Cloud → the Android OAuth client for Sign in with Google (docs/setup/social-sign-in.md), package
     `com.akvega.aura` with the **app signing** SHA-1. Also add the upload key's SHA-1 if you sideload
     release builds signed locally.
   - `assetlinks.json` for App Links later (MASVS F-5): the app signing SHA-256.
5. Lost or leaked upload key: Play Console → App integrity → **Request upload key reset**, with a new keystore's
   certificate (`keytool -export -rfc -keystore new.jks -alias upload -file upload_certificate.pem`).

## 4. CI (later)

CI is parked. When it comes back: store the keystore as a base64 secret, write it and `key.properties` in the job, and
never print either. The build already fails closed without them.

## 5a. Always run the release build on a device or emulator before uploading

A release build is shrunk by R8; a debug build is not. Anything created by reflection can be stripped, and then the
app dies in release only. This already happened once: **WorkManager's Room database crashed every launch** of version
code 3 (`NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>`), found by running the release APK on an
emulator. The keep rules live in `apps/mobile/android/app/proguard-rules.pro` (WorkManager/Room and
flutter_local_notifications' Gson models). After any dependency change:

```sh
cd apps/mobile
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols-apk \
  --dart-define-from-file=config/public.json --dart-define-from-file=config/prod.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p com.akvega.aura -c android.intent.category.LAUNCHER 1
adb logcat -d -b crash          # must print nothing
```

Also **play a sound in Sanctuary → Sounds, press Home and pull down the notification shade**: an "Aura · Sounds" media
card with Pause must be there (`adb shell dumpsys media_session` shows `active=true`, `state=PLAYING`). Three Android-only
release bugs have been found this way, none visible in debug builds:

1. **Launch crash**: R8 stripped WorkManager's Room database (`proguard-rules.pro`).
2. **No media notification**: the resource shrinker deleted the `audio_service_*` button icons, which the plugin looks
   up by name, so it threw "You must specify an icon resource id to build a CustomAction" and never started the
   foreground service (`res/raw/keep.xml` keeps them, and `ic_stat_aura`, the icon every notification names in Dart).
3. **First play had no controls**: the media state was published before `prepare()` built the session
   (`sounds_controller.dart` `_prepare`).

To check what survived shrinking use `aapt2 dump resources app-release.apk | grep drawable/audio_service`: file
names inside the APK are shortened, so grepping `unzip -l` proves nothing.

Play never accepts the same version code twice: bump the `+N` in `pubspec.yaml` for every upload.

## 5. Verify locally

```sh
cd apps/mobile
# without key.properties: must fail with "Aura release signing is not configured"
flutter build apk --release
# debug builds are unaffected
flutter build apk --debug
```
