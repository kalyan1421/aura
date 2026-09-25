import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REQ-PAY-01 "Store billing via `in_app_purchase`, PBL v8. Neg: static scan
/// finds no RevenueCat or Razorpay SDK, UPI intent or external purchase
/// link." (PRD 06c F12, DS-9; Apple 3.1.1, Play Billing.) CI is parked, so
/// this runs with `flutter test`.

/// The workspace lock file (pub workspace at the repo root).
final File _lock = File('../../pubspec.lock');

/// Resolved packages: name → version.
Map<String, String> _packages() {
  final out = <String, String>{};
  String? name;
  for (final line in _lock.readAsLinesSync()) {
    final pkg = RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line);
    if (pkg != null) {
      name = pkg.group(1);
      continue;
    }
    final version = RegExp(r'^    version: "([^"]+)"').firstMatch(line);
    if (version != null && name != null) out[name] = version.group(1)!;
  }
  return out;
}

/// Third-party billing / payment SDKs Aura must never ship (DS-9: own
/// validation in NestJS; no Razorpay or UPI checkout for digital goods).
final RegExp _forbiddenPackage = RegExp(
  r'^(purchases_flutter|purchases_ui_flutter|revenuecat.*|razorpay.*|'
  r'.*_razorpay|cashfree.*|paytm.*|phonepe.*|upi.*|.*_upi|.*upi_pay.*|'
  r'stripe.*|flutter_stripe|paypal.*|juspay.*|hypersdk.*|instamojo.*)$',
);

/// Source text that would mean a payment path outside the stores.
final RegExp _forbiddenSource = RegExp(
  r'(revenuecat|razorpay|upi://|upi:pay|"upi"|tez://|phonepe://|paytmmp://|'
  r'android\.intent\.action\.VIEW[^\n]*upi|checkout\.stripe|paypal\.com/'
  r'checkout)',
  caseSensitive: false,
);

Iterable<File> _files(String dir, Set<String> exts) sync* {
  final d = Directory(dir);
  if (!d.existsSync()) return;
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final p = e.path;
    if (p.contains('/build/') || p.contains('/.dart_tool/')) continue;
    if (exts.any(p.endsWith)) yield e;
  }
}

void main() {
  test('no third-party billing or payment SDK is resolved', () {
    final hits = _packages().keys.where(_forbiddenPackage.hasMatch).toList();
    expect(hits, isEmpty, reason: 'forbidden billing SDKs: $hits');
  });

  test('store billing goes through in_app_purchase with Play Billing 8', () {
    final pkgs = _packages();
    expect(pkgs, contains('in_app_purchase'));
    // in_app_purchase_android 0.5.0 moved to Play Billing Library 8.0.0
    // (required since 31 Aug 2026, PRD F12 [STORE]).
    final android = pkgs['in_app_purchase_android'];
    expect(android, isNotNull);
    final parts = android!.split('.').map(int.parse).toList();
    final atLeast050 = parts[0] > 0 || parts[1] >= 5;
    expect(atLeast050, isTrue, reason: 'in_app_purchase_android $android');
  });

  test('no UPI intent, external checkout or third-party billing in app '
      'code, manifests or plists', () {
    final hits = <String>[];
    final files = [
      ..._files('lib', {'.dart'}),
      ..._files('android/app/src', {'.kt', '.java', '.xml', '.kts'}),
      ..._files('ios/Runner', {'.swift', '.plist', '.m', '.h'}),
      ..._files('ios/AuraWidget', {'.swift', '.plist'}),
      File('android/app/build.gradle.kts'),
    ];
    for (final f in files) {
      if (!f.existsSync()) continue;
      final text = f.readAsStringSync();
      for (final m in _forbiddenSource.allMatches(text)) {
        hits.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
