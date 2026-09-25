// Forced update (MASVS-CODE-2, docs/security/masvs-l1.md F-6): the server's
// `minAppVersion` (GET /v1/config) against this install's version, and the
// calm "Please update Aura" screen that keeps "I need help now" reachable.
import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/env/env.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/remote_config/app_version.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura/src/features/update/update_required.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

AppVersion _v(String s) => AppVersion.tryParse(s)!;

class _Reader implements InstalledVersionReader {
  _Reader(this.version);
  final AppVersion? version;
  @override
  Future<AppVersion?> read() async => version;
}

class _Min extends MinAppVersionNotifier {
  _Min(this.initial);
  final MinAppVersions initial;
  @override
  MinAppVersions build() => initial;
  void set(MinAppVersions v) => state = v;
}

void main() {
  group('AppVersion (same rules as server app-version.ts)', () {
    test('parses x[.y[.z]][+build] and nothing else', () {
      expect(_v('1.4.0+57'), const AppVersion(1, 4, 0, 57));
      expect(_v('2'), const AppVersion(2));
      expect(_v(' 1.2 '), const AppVersion(1, 2));
      for (final bad in [
        '',
        'v1.2.0',
        '1.2.0-beta',
        '1..2',
        '1.2.3.4',
        'latest',
        12,
        null,
      ]) {
        expect(AppVersion.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test(
      'compares numerically; build breaks a tie only when both have one',
      () {
        expect(_v('1.10.0').compareTo(_v('1.9.9')), greaterThan(0));
        expect(_v('1.2').compareTo(_v('1.2.0')), 0);
        expect(_v('1.2.0+5') < _v('1.2.0+12'), isTrue);
        expect(_v('1.2.0+5').compareTo(_v('1.2.0')), 0);
        expect(_v('0.9.0+99') < _v('1.0.0'), isTrue);
      },
    );

    test('update required only when both sides are known (fail open)', () {
      expect(isUpdateRequired(_v('1.0.0+3'), _v('1.1.0')), isTrue);
      expect(isUpdateRequired(_v('1.1.0+3'), _v('1.1.0')), isFalse);
      expect(isUpdateRequired(_v('1.2.0'), _v('1.1.0')), isFalse);
      expect(isUpdateRequired(null, _v('9.0.0')), isFalse);
      expect(isUpdateRequired(_v('0.1.0'), null), isFalse);
    });
  });

  group('config document minAppVersion', () {
    Map<String, dynamic> doc([Object? min]) => {
      'configVersion': 'c1-x',
      'pollSeconds': 240,
      'flags': <String, dynamic>{},
      'minAppVersion': ?min,
    };

    test('per platform; junk and unknown platforms are dropped', () {
      final d = RemoteConfigDoc.fromJson(
        doc({'ios': '1.2.0', 'android': 'latest', 'web': '9.0.0'}),
      );
      expect(d.minAppVersion.forPlatform(TargetPlatform.iOS), _v('1.2.0'));
      expect(d.minAppVersion.forPlatform(TargetPlatform.android), isNull);
      expect(d.minAppVersion.forPlatform(TargetPlatform.macOS), isNull);
    });

    test('absent or malformed → no minimum (older servers, typos)', () {
      expect(RemoteConfigDoc.fromJson(doc()).minAppVersion.isEmpty, isTrue);
      expect(
        RemoteConfigDoc.fromJson(doc('1.2.0')).minAppVersion.isEmpty,
        isTrue,
      );
    });
  });

  group('update gate', () {
    ProviderContainer container({
      AppVersion? installed,
      MinAppVersions min = MinAppVersions.none,
      TargetPlatform platform = TargetPlatform.android,
    }) {
      final c = ProviderContainer(
        overrides: [
          installedVersionReaderProvider.overrideWithValue(_Reader(installed)),
          minAppVersionProvider.overrideWith(() => _Min(min)),
          updatePlatformProvider.overrideWithValue(platform),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('this platform\'s minimum against the installed version', () async {
      final min = MinAppVersions.fromJson({'ios': '2.0.0', 'android': '1.0.0'});
      final android = container(installed: _v('1.0.0+4'), min: min);
      await android.read(installedAppVersionProvider.future);
      expect(android.read(updateRequiredProvider), isFalse);

      final ios = container(
        installed: _v('1.0.0+4'),
        min: min,
        platform: TargetPlatform.iOS,
      );
      await ios.read(installedAppVersionProvider.future);
      expect(ios.read(updateRequiredProvider), isTrue);

      final unknown = container(min: min, platform: TargetPlatform.iOS);
      await unknown.read(installedAppVersionProvider.future);
      expect(unknown.read(updateRequiredProvider), isFalse);
    });

    test(
      'follows the server: raised minimum → required, lowered → not',
      () async {
        final c = container(installed: _v('1.0.0+4'));
        await c.read(installedAppVersionProvider.future);
        expect(c.read(updateRequiredProvider), isFalse);
        final min = c.read(minAppVersionProvider.notifier) as _Min;
        min.set(MinAppVersions.fromJson({'android': '1.1.0'}));
        expect(c.read(updateRequiredProvider), isTrue);
        min.set(MinAppVersions.none);
        expect(c.read(updateRequiredProvider), isFalse);
      },
    );
  });

  group('updateRedirect (every navigation passes it)', () {
    test('while required: everything lands on the update screen except the '
        'Safety Center', () {
      for (final loc in [
        Routes.root,
        Routes.home,
        Routes.checkIn,
        Routes.rooms,
        Routes.settings,
        '/insights/history',
      ]) {
        expect(
          updateRedirect(required: true, location: loc),
          Routes.updateRequired,
          reason: loc,
        );
      }
      expect(
        updateRedirect(required: true, location: Routes.updateRequired),
        isNull,
      );
      expect(updateRedirect(required: true, location: Routes.safety), isNull);
    });

    test('once lifted: the update screen bounces to the root; nothing else '
        'is touched', () {
      expect(
        updateRedirect(required: false, location: Routes.updateRequired),
        Routes.root,
      );
      expect(updateRedirect(required: false, location: Routes.home), isNull);
      expect(updateRedirect(required: false, location: Routes.safety), isNull);
    });
  });

  testWidgets('a deep link or go() cannot get past it; help opens and closes '
      'back onto it; lifting the minimum lets the app through', (tester) async {
    final required = ValueNotifier<bool>(true);
    addTearDown(required.dispose);
    final router = GoRouter(
      initialLocation: Routes.home,
      refreshListenable: required,
      redirect: (_, state) => updateRedirect(
        required: required.value,
        location: state.matchedLocation,
      ),
      routes: [
        GoRoute(path: Routes.root, redirect: (_, _) => Routes.home),
        GoRoute(path: Routes.home, builder: (_, _) => const Text('home')),
        GoRoute(path: Routes.checkIn, builder: (_, _) => const Text('checkin')),
        GoRoute(path: Routes.safety, builder: (_, _) => const Text('safety')),
        GoRoute(
          path: Routes.updateRequired,
          builder: (_, _) =>
              const UpdateRequiredScreen(platform: TargetPlatform.android),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAuraTheme(const Locale('en')),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);

    // The widget's aura://checkin, a notification tap, any go()/push().
    router.go(Routes.checkIn);
    await tester.pumpAndSettle();
    expect(find.text('checkin'), findsNothing);
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    unawaited(router.push(Routes.checkIn));
    await tester.pumpAndSettle();
    expect(find.text('checkin'), findsNothing);

    // Help is never locked, and closing it returns to the update screen.
    unawaited(router.push(Routes.safety));
    await tester.pumpAndSettle();
    expect(find.text('safety'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);

    required.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  group('UpdateRequiredScreen', () {
    Future<List<Uri>> pump(
      WidgetTester tester, {
      TargetPlatform platform = TargetPlatform.android,
      bool opens = true,
      Locale locale = const Locale('en'),
    }) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          child: localized(
            UpdateRequiredScreen(
              platform: platform,
              opener: (uri) async {
                opened.add(uri);
                return opens;
              },
            ),
            locale: locale,
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('calm copy, store button, help stays in the top bar', (
      tester,
    ) async {
      final opened = await pump(tester);
      expect(find.text('Please update Aura'), findsOneWidget);
      expect(find.textContaining('stays safe'), findsOneWidget);
      expect(find.byType(HelpNowButton), findsOneWidget);
      expect(find.text('Update on Google Play'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-open-store')));
      await tester.pump();
      expect(opened, [Uri.parse(Env.playStoreUrl)]);
      expect(find.byKey(const ValueKey('update-store-failed')), findsNothing);
    });

    testWidgets('a store that does not open says so', (tester) async {
      await pump(tester, opens: false);
      await tester.tap(find.byKey(const ValueKey('update-open-store')));
      await tester.pump();
      expect(find.byKey(const ValueKey('update-store-failed')), findsOneWidget);
    });

    testWidgets('iPhone: App Store wording; without an App Store id the '
        'button explains instead of opening a wrong page', (tester) async {
      final opened = await pump(tester, platform: TargetPlatform.iOS);
      expect(find.text('Update in the App Store'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-open-store')));
      await tester.pump();
      if (Env.appStoreUrl.isEmpty) {
        expect(opened, isEmpty);
        expect(
          find.byKey(const ValueKey('update-store-failed')),
          findsOneWidget,
        );
      } else {
        expect(opened, [Uri.parse(Env.appStoreUrl)]);
      }
    });

    testWidgets('every locale has its own copy', (tester) async {
      for (final tag in ['en', 'te', 'te-Latn', 'hi', 'hi-Latn']) {
        final locale = localeFromTag(tag);
        await pump(tester, locale: locale);
        final l = lookupAppLocalizations(locale);
        expect(find.text(l.update_title), findsOneWidget, reason: tag);
        if (tag != 'en') {
          expect(l.update_title, isNot('Please update Aura'), reason: tag);
        }
      }
    });

    testWidgets('back does nothing; "I need help now" opens the Safety Center '
        'above it', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: Routes.safety,
            builder: (_, _) => const Scaffold(body: Text('safety-center')),
          ),
        ],
      );
      addTearDown(router.dispose);
      const locale = Locale('en');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: buildAuraTheme(locale),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...systemLocalizationDelegates,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      router.routerDelegate.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const UpdateRequiredScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Please update Aura'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Please update Aura'), findsOneWidget);

      await tester.tap(find.byType(HelpNowButton));
      await tester.pumpAndSettle();
      expect(find.text('safety-center').hitTestable(), findsOneWidget);
    });
  });
}
