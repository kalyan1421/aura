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

  /// Apple and Google sign-in buttons are shown but disabled until this flag
  /// is on (providers are configured but disabled in supabase/config.toml).
  static const bool socialSignIn = bool.fromEnvironment('AURA_SOCIAL_SIGNIN');

  /// Hindi and Hinglish are beta languages; hidden from pickers in alpha.
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

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  static bool get hasApi => apiUrl.isNotEmpty;

  /// Shown in Settings; keep in step with pubspec `version`.
  static const String appVersion = '0.1.0 (1)';

  /// Supabase redirect for magic links (allow-listed in supabase/config.toml).
  static const String authRedirect = 'aura://auth-callback';

  static String _stripSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
