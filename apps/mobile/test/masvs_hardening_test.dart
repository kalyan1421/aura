// MASVS L1 launch hardening (docs/security/masvs-l1.md). Regression tests
// for the gaps fixed before Milestone C:
//  - release builds refuse non-HTTPS API / Supabase base URLs (NETWORK-1);
//  - the database directory is excluded from iCloud backup (STORAGE-2,
//    PRD 09 "DB file excluded from iCloud backup", Apple 5.1.3);
//  - Android refuses cleartext in release on API 24–27 too, keeps backup
//    off, and strips the advertising-id permission (NETWORK-1, STORAGE-2,
//    PRIVACY);
//  - iOS ships privacy manifests (app + widget) that declare no tracking,
//    registered in the Xcode project, and ATS stays on (PRIVACY, NETWORK);
//  - follow-ups: the ATS local-networking exception is Debug-only (F-4), the
//    widget App Group container is out of backup (F-1), and Android release
//    builds never fall back to the debug key (release signing).
import 'dart:io';

import 'package:aura/src/core/db/connection.dart';
import 'package:aura/src/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('releaseSafeBaseUrl', () {
    test('release accepts https and strips a trailing slash', () {
      expect(
        releaseSafeBaseUrl('https://api.example.com/', release: true),
        'https://api.example.com',
      );
      expect(
        releaseSafeBaseUrl('https://x.supabase.co', release: true),
        'https://x.supabase.co',
      );
    });

    test('release refuses http, other schemes and junk (fails closed)', () {
      for (final bad in [
        'http://api.example.com',
        'http://10.0.2.2:3310',
        'ftp://api.example.com',
        'api.example.com',
        'https://',
        '::not a url::',
      ]) {
        expect(releaseSafeBaseUrl(bad, release: true), '', reason: bad);
      }
    });

    test('debug and profile keep http for the local dev stack', () {
      expect(
        releaseSafeBaseUrl('http://127.0.0.1:3310/', release: false),
        'http://127.0.0.1:3310',
      );
    });

    test('this test build has no insecure release config', () {
      expect(Env.insecureReleaseConfig, isEmpty);
    });
  });

  group('database backup exclusion', () {
    test('excludes the database directory', () async {
      final calls = <String>[];
      await excludeDatabaseDirFromBackup(
        () async => Directory('/app/Library/Application Support'),
        (p) async => calls.add(p),
      );
      expect(calls, ['/app/Library/Application Support']);
    });

    test('a failure never stops the app from starting', () async {
      await expectLater(
        excludeDatabaseDirFromBackup(
          () async => Directory('/x'),
          (_) async => throw Exception('channel missing'),
        ),
        completes,
      );
      await expectLater(
        excludeDatabaseDirFromBackup(
          () async => throw const FileSystemException('no dir'),
          (_) async {},
        ),
        completes,
      );
    });
  });

  group('Android manifest', () {
    final main = _read('android/app/src/main/AndroidManifest.xml');

    test('release refuses cleartext and keeps backup off', () {
      expect(main, contains('android:usesCleartextTraffic="false"'));
      expect(main, isNot(contains('android:usesCleartextTraffic="true"')));
      expect(main, contains('android:allowBackup="false"'));
      expect(main, contains('android:fullBackupContent="false"'));
      expect(
        main,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(main, isNot(contains('android:debuggable')));
    });

    test('no advertising id (merged in by some Google libraries)', () {
      expect(
        main,
        matches(
          RegExp(
            r'com\.google\.android\.gms\.permission\.AD_ID"\s+'
            r'tools:node="remove"',
          ),
        ),
      );
    });

    test('only debug and profile allow cleartext, for the local stack', () {
      for (final flavor in ['debug', 'profile']) {
        final m = _read('android/app/src/$flavor/AndroidManifest.xml');
        expect(m, contains('android:usesCleartextTraffic="true"'));
        expect(m, contains('tools:replace="android:usesCleartextTraffic"'));
      }
    });

    test('backup rules exclude every domain from cloud and transfer', () {
      final rules = _read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body = RegExp(
          '<$section>(.*?)</$section>',
          dotAll: true,
        ).firstMatch(rules)!.group(1)!;
        for (final domain in [
          'root',
          'file',
          'database',
          'sharedpref',
          'external',
        ]) {
          expect(
            body,
            contains('domain="$domain" path="."'),
            reason: '$section $domain',
          );
        }
      }
    });
  });

  group('iOS', () {
    test('ATS stays on (no arbitrary loads)', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, isNot(contains('NSExceptionAllowsInsecureHTTPLoads')));
    });

    test('app and widget privacy manifests declare no tracking', () {
      for (final path in [
        'ios/Runner/PrivacyInfo.xcprivacy',
        'ios/AuraWidget/PrivacyInfo.xcprivacy',
      ]) {
        final m = _read(path);
        expect(
          m,
          matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')),
          reason: path,
        );
        expect(
          m,
          matches(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>')),
          reason: path,
        );
        // The App Group store (widget) is UserDefaults: reason 1C8F.1.
        expect(m, contains('1C8F.1'), reason: path);
        // No collected type is used for tracking.
        expect(
          m,
          isNot(
            matches(
              RegExp(r'NSPrivacyCollectedDataTypeTracking</key>\s*<true/>'),
            ),
          ),
          reason: path,
        );
      }
    });

    test('both manifests are bundled (Resources build phases)', () {
      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
      final inResources = RegExp(
        r'/\* PrivacyInfo\.xcprivacy in Resources \*/,',
      ).allMatches(pbx).length;
      expect(inResources, 2);
    });

    // F-4: http to localhost / *.local only in Debug builds.
    test('the ATS local-networking exception is Debug-only', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(plist, isNot(contains('<key>NSAllowsLocalNetworking</key>')));
      expect(plist, isNot(contains('<key>NSAppTransportSecurity</key>')));
      final script = _read('ios/scripts/ats_debug_only.sh');
      expect(script, contains('Debug*)'));
      expect(script, contains('NSAllowsLocalNetworking bool true'));
      expect(script, contains('exit 1'), reason: 'release/profile guard');
      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
      // Registered in the Runner target, after the Info.plist is processed.
      expect(RegExp(r'/\* ATS \(Debug only\) \*/,').allMatches(pbx).length, 1);
      expect(pbx, contains(r'scripts/ats_debug_only.sh'));
    });

    // F-1: the widget's App Group container stays out of iCloud backup.
    test('the widget App Group container is excluded from backup', () {
      final swift = _read('ios/Runner/AuraWidgetChannel.swift');
      expect(swift, contains('static func excludeContainerFromBackup()'));
      expect(swift, contains('isExcludedFromBackup = true'));
      expect(
        RegExp(
          r'static func register\(messenger: FlutterBinaryMessenger\) \{\s*'
          r'excludeContainerFromBackup\(\)',
        ).hasMatch(swift),
        isTrue,
        reason: 'applied at every launch (app and headless engines)',
      );
    });
  });

  // Release signing (docs/setup/android-release-signing.md): a release build
  // never falls back to the debug key.
  group('Android release signing', () {
    final gradle = _read('android/app/build.gradle.kts');

    test('release signs with key.properties and fails without it', () {
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('verifyReleaseSigning'));
      expect(gradle, contains('"preReleaseBuild"'));
      expect(gradle, contains('throw GradleException('));
      expect(
        gradle,
        isNot(
          matches(
            RegExp(
              r'release \{\s*signingConfig = signingConfigs\.getByName\("debug"\)',
            ),
          ),
        ),
      );
    });

    test(
      'keystores and key.properties are git-ignored; the example is not',
      () {
        final ignore = _read('android/.gitignore');
        expect(ignore, contains('key.properties'));
        expect(ignore, contains('**/*.jks'));
        expect(File('android/key.properties.example').existsSync(), isTrue);
      },
    );
  });
}
