// Release-config guard. Compiled with the release build's own define file, so it sees exactly what
// `flutter build --release --dart-define-from-file=<file>` bakes in:
//
//   .github/scripts/check-release-config.sh apps/mobile/env/alpha.json
//
// It lives outside apps/mobile/test so the normal `flutter test` never runs it (it fails without real defines).
// Release builds hide a legal/support row whose define is missing (Env.missingLegalConfig) and have no backend
// defaults at all, so a release built without these values ships a broken app.
import 'package:aura/src/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

const _apiUrl = String.fromEnvironment('AURA_API_URL');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);
const _legalUrls = {
  'AURA_PRIVACY_URL': String.fromEnvironment('AURA_PRIVACY_URL'),
  'AURA_TERMS_URL': String.fromEnvironment('AURA_TERMS_URL'),
};
const _emails = {
  'AURA_SUPPORT_EMAIL': String.fromEnvironment('AURA_SUPPORT_EMAIL'),
  'AURA_GRIEVANCE_EMAIL': String.fromEnvironment('AURA_GRIEVANCE_EMAIL'),
};

/// Hosts that only make sense on a developer machine, or are the local-build placeholders.
final _placeholderHost = RegExp(
  r'^(localhost|127\.|10\.0\.2\.2$|0\.0\.0\.0$|192\.168\.|example\.(com|org|net)$|.*\.example\.(com|org|net)$|.*\.test$|.*\.local$|.*\.invalid$|.*\.localhost$)',
);

String? _problemWithUrl(String name, String value) {
  if (value.isEmpty) return '$name is not set';
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) return '$name is not a URL';
  if (uri.scheme != 'https') return '$name must use https';
  if (_placeholderHost.hasMatch(uri.host)) {
    return '$name points at a local or placeholder host (${uri.host})';
  }
  return null;
}

void main() {
  test('legal and support defines are all set (Env.missingLegalConfig)', () {
    expect(
      Env.missingLegalConfig,
      isEmpty,
      reason:
          'Release builds hide these rows when the define is missing: '
          '${Env.missingLegalConfig.join(', ')}',
    );
  });

  test('backend defines point at real HTTPS hosts', () {
    final problems = [
      _problemWithUrl('AURA_API_URL', _apiUrl),
      _problemWithUrl('SUPABASE_URL', _supabaseUrl),
      if (_supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY is not set',
      if (_supabaseKey.startsWith('sb_secret_'))
        'SUPABASE_PUBLISHABLE_KEY is a secret key; ship the publishable key',
      if (_supabaseKey == 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH')
        'SUPABASE_PUBLISHABLE_KEY is the local CLI key',
    ].nonNulls;
    expect(problems, isEmpty, reason: problems.join('; '));
  });

  test('legal links are HTTPS and not placeholders', () {
    final problems = [
      for (final e in _legalUrls.entries) _problemWithUrl(e.key, e.value),
    ].nonNulls;
    expect(problems, isEmpty, reason: problems.join('; '));
  });

  test('support and grievance emails look real', () {
    final problems = [
      for (final e in _emails.entries) _problemWithEmail(e.key, e.value),
    ].nonNulls;
    expect(problems, isEmpty, reason: problems.join('; '));
  });
}

String? _problemWithEmail(String name, String value) {
  final match = RegExp(r'^[^@\s]+@([^@\s]+\.[^@\s]+)$').firstMatch(value);
  if (match == null) return '$name is not an email address';
  if (_placeholderHost.hasMatch(match.group(1)!)) {
    return '$name uses a placeholder domain';
  }
  return null;
}
