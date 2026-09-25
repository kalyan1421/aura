import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration (`--dart-define` / `--dart-define-from-file`).
///
/// Local defaults target the dev stack from supabase/LOCAL.md and the NestJS
/// API on :3310. The Android emulator reaches the host via 10.0.2.2. Release
/// builds must pass real values; the local defaults only apply in debug/profile.
abstract final class Env {
  static const String _apiUrl = String.fromEnvironment('AURA_API_URL');
  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // ---- Social sign-in (F8 REQ-ACC-01; docs/setup/social-sign-in.md) --------
  // A button shows only when its provider is configured for this build (see
  // SocialSignInConfig). None of these values is a secret: OAuth client ids
  // identify the app and ship inside every build.

  /// Master switch for Sign in with Apple / Google. On by default, but each
  /// provider still needs its own values below; `false` hides both.
  static const bool socialSignIn = bool.fromEnvironment(
    'AURA_SOCIAL_SIGNIN',
    defaultValue: true,
  );

  /// Google OAuth **Web** client id: `serverClientId` on Android, and the
  /// audience of the ID token Supabase checks. Google is hidden without it.
  static const String googleWebClientId = String.fromEnvironment(
    'AURA_GOOGLE_WEB_CLIENT_ID',
  );

  /// Google OAuth **iOS** client id (iOS only). Its reversed form must also
  /// be the URL scheme in the gitignored `ios/Flutter/Secrets.xcconfig`.
  static const String googleIosClientId = String.fromEnvironment(
    'AURA_GOOGLE_IOS_CLIENT_ID',
  );

  /// Sign in with Apple is set up: the App ID has the capability and the
  /// Supabase Apple provider lists the bundle id. Native on iOS.
  static const bool appleSignIn = bool.fromEnvironment('AURA_APPLE_SIGNIN');

  /// Sign in with Apple on Android, through Supabase browser OAuth. Needs the
  /// Services ID, its key and an HTTPS callback in Supabase (hosted only).
  static const bool appleSignInAndroid = bool.fromEnvironment(
    'AURA_APPLE_SIGNIN_ANDROID',
  );

  /// Hindi and Hinglish (Milestone B): fully translated, but hidden from the
  /// pickers (and never chosen from a Hindi device language) until the crisis
  /// lexicon has reviewed hi / hi-Latn terms — without them, text written in
  /// Hindi never opens the crisis sheet (docs/l10n/hindi-review.md). Turn on
  /// with `--dart-define=AURA_BETA_LOCALES=true` for review builds.
  static const bool betaLocales = bool.fromEnvironment('AURA_BETA_LOCALES');

  /// Debug tools (the /debug/avatar lab) — on in debug builds by default.
  static const bool debugTools = bool.fromEnvironment(
    'AURA_DEBUG_TOOLS',
    defaultValue: kDebugMode,
  );

  /// The CLI's fixed local-dev publishable key (supabase/LOCAL.md). Not a
  /// secret; never used in release builds.
  static const String _localPublishableKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

  static bool get _isLocalBuild => !kReleaseMode;

  static String get _hostLoopback {
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  /// NestJS base URL (no trailing slash). Release builds accept `https`
  /// only (see [releaseSafeBaseUrl]).
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) {
      return releaseSafeBaseUrl(_apiUrl, release: !_isLocalBuild);
    }
    return _isLocalBuild ? 'http://$_hostLoopback:3310' : '';
  }

  static String get supabaseUrl {
    if (_supabaseUrl.isNotEmpty) {
      return releaseSafeBaseUrl(_supabaseUrl, release: !_isLocalBuild);
    }
    return _isLocalBuild ? 'http://$_hostLoopback:55521' : '';
  }

  /// Base URLs a release build was given that it refuses (not `https`).
  /// Part of the release checklist, like [missingLegalConfig].
  static List<String> get insecureReleaseConfig => [
    if (_apiUrl.isNotEmpty &&
        releaseSafeBaseUrl(_apiUrl, release: true).isEmpty)
      'AURA_API_URL',
    if (_supabaseUrl.isNotEmpty &&
        releaseSafeBaseUrl(_supabaseUrl, release: true).isEmpty)
      'SUPABASE_URL',
  ];

  static String get supabaseKey {
    if (_supabaseKey.isNotEmpty) return _supabaseKey;
    return _isLocalBuild ? _localPublishableKey : '';
  }

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  static bool get hasApi => apiUrl.isNotEmpty;

  // ---- Legal & support (onboarding trust step, Settings → Help & Safety) --
  // Release builds MUST pass real values (lawyer-approved pages, the
  // Grievance Officer named in the privacy notice; F9, IT Rules). Local
  // builds get obvious placeholders so the rows can be exercised; release
  // builds hide a row whose value is missing (see [missingLegalConfig]).
  static const String _privacyUrl = String.fromEnvironment('AURA_PRIVACY_URL');
  static const String _termsUrl = String.fromEnvironment('AURA_TERMS_URL');
  static const String _supportEmail = String.fromEnvironment(
    'AURA_SUPPORT_EMAIL',
  );
  static const String _grievanceName = String.fromEnvironment(
    'AURA_GRIEVANCE_NAME',
  );
  static const String _grievanceEmail = String.fromEnvironment(
    'AURA_GRIEVANCE_EMAIL',
  );

  static String _orLocal(String value, String placeholder) =>
      value.isNotEmpty ? value : (_isLocalBuild ? placeholder : '');

  static String get privacyPolicyUrl =>
      _orLocal(_privacyUrl, 'https://example.com/aura/privacy');
  static String get termsUrl =>
      _orLocal(_termsUrl, 'https://example.com/aura/terms');

  /// Support inbox (wrong date of birth, account questions).
  static String get supportEmail =>
      _orLocal(_supportEmail, 'support@example.com');
  static String get grievanceOfficerName =>
      _orLocal(_grievanceName, 'Grievance Officer (placeholder)');
  static String get grievanceOfficerEmail =>
      _orLocal(_grievanceEmail, 'grievance@example.com');

  /// Legal/support defines a release build is missing (checked in CI).
  static List<String> get missingLegalConfig => [
    if (_privacyUrl.isEmpty) 'AURA_PRIVACY_URL',
    if (_termsUrl.isEmpty) 'AURA_TERMS_URL',
    if (_supportEmail.isEmpty) 'AURA_SUPPORT_EMAIL',
    if (_grievanceName.isEmpty) 'AURA_GRIEVANCE_NAME',
    if (_grievanceEmail.isEmpty) 'AURA_GRIEVANCE_EMAIL',
  ];

  // ---- Store pages (forced update, MASVS F-6; features/update) -----------
  // The App Store id is the numeric Apple ID from App Store Connect → App
  // Information. Without it the "Please update" button can't open the App
  // Store page and says so instead (release checklist: [missingStoreConfig]).
  static const String _appStoreId = String.fromEnvironment('AURA_APP_STORE_ID');

  /// Aura's App Store page, or `''` when [_appStoreId] isn't set.
  static String get appStoreUrl =>
      _appStoreId.isEmpty ? '' : 'https://apps.apple.com/app/id$_appStoreId';

  /// Aura's Google Play page (the package name is fixed).
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.akvega.aura';

  /// Store defines a release build is missing.
  static List<String> get missingStoreConfig => [
    if (_appStoreId.isEmpty) 'AURA_APP_STORE_ID',
  ];

  /// Shown in Settings; keep in step with pubspec `version`.
  static const String appVersion = '0.1.0 (1)';

  /// Supabase redirect for magic links and browser OAuth (Apple on Android);
  /// allow-listed in supabase/config.toml.
  static const String authRedirect = 'aura://auth-callback';
}

/// [url] without a trailing slash, or `''` when a [release] build was given
/// anything but an `https` URL with a host. Fails closed: the app then runs
/// offline-only (no API, no Supabase) instead of sending tokens, notes or the
/// date of birth in cleartext (MASVS-NETWORK-1, docs/security/masvs-l1.md).
/// Debug and profile builds accept `http` for the local dev stack.
String releaseSafeBaseUrl(String url, {required bool release}) {
  final trimmed = url.trim();
  final stripped = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  if (!release) return stripped;
  final uri = Uri.tryParse(stripped);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
  return stripped;
}
