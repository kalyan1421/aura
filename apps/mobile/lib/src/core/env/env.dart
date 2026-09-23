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

  /// Hindi and Hinglish are beta languages; hidden from pickers in alpha.
  static const bool betaLocales = bool.fromEnvironment('AURA_BETA_LOCALES');

  /// Debug tools (the /debug/avatar lab) — on in debug builds by default.
  static const bool debugTools = bool.fromEnvironment(
    'AURA_DEBUG_TOOLS',
    defaultValue: kDebugMode,
  );

  // ---- Analytics & crash reporting (PRD 13-analytics; docs/setup/analytics.md)
  // Empty → off: no SDK starts and nothing is sent (local dev, tests, CI).
  // Neither value is a secret (PostHog's project token and Sentry's DSN ship
  // inside every build).

  /// PostHog Cloud project token (`phc_…`).
  static const String posthogKey = String.fromEnvironment('AURA_POSTHOG_KEY');

  /// PostHog ingestion host: EU Cloud unless set (PRD `[ASSUMPTION]` EU).
  static const String posthogHost = String.fromEnvironment(
    'AURA_POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  /// Sentry DSN for crash reports.
  static const String sentryDsn = String.fromEnvironment('AURA_SENTRY_DSN');

  /// Sentry environment; defaults to `production` in release builds.
  static const String _sentryEnvironment = String.fromEnvironment(
    'AURA_SENTRY_ENV',
  );

  /// "Help improve Aura" before the person has chosen. Off (opt-in) unless
  /// the build says otherwise: default-on vs opt-in is a `[LEGAL]` decision
  /// (PRD principle 5), and no consent control is ever pre-ticked by
  /// default.
  static const bool analyticsDefaultOn = bool.fromEnvironment(
    'AURA_ANALYTICS_DEFAULT_ON',
  );

  static bool get hasPostHog =>
      posthogKey.trim().isNotEmpty && posthogHost.trim().isNotEmpty;
  static bool get hasSentry => sentryDsn.trim().isNotEmpty;
  static String get sentryEnvironment => _sentryEnvironment.isNotEmpty
      ? _sentryEnvironment
      : (kReleaseMode ? 'production' : 'development');

  /// The CLI's fixed local-dev publishable key (supabase/LOCAL.md). Not a
  /// secret; never used in release builds.
  static const String _localPublishableKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

  static bool get _isLocalBuild => !kReleaseMode;

  static String get _hostLoopback {
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  /// NestJS base URL (no trailing slash).
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _stripSlash(_apiUrl);
    return _isLocalBuild ? 'http://$_hostLoopback:3310' : '';
  }

  static String get supabaseUrl {
    if (_supabaseUrl.isNotEmpty) return _stripSlash(_supabaseUrl);
    return _isLocalBuild ? 'http://$_hostLoopback:55521' : '';
  }

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

  /// Shown in Settings; keep in step with pubspec `version`.
  static const String appVersion = '0.1.0 (1)';

  /// Supabase redirect for magic links and browser OAuth (Apple on Android);
  /// allow-listed in supabase/config.toml.
  static const String authRedirect = 'aura://auth-callback';

  static String _stripSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
