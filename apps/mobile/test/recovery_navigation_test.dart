import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/keepsakes/keepsakes_providers.dart';
import 'package:aura/src/features/keepsakes/keepsakes_screen.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/rooms/room_status.dart';
import 'package:aura/src/features/rooms/rooms_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'keepsakes_fakes.dart';

void main() {
  for (final (name, screen, failure, action, destination)
      in <(String, Widget, ApiException?, String, String)>[
        (
          'Keepsakes expired session',
          const KeepsakesScreen(),
          const ApiException(code: 'signed_out', status: 401),
          'keepsakes-sign-in',
          Routes.signIn,
        ),
        (
          'Keepsakes account restriction',
          const KeepsakesScreen(),
          const ApiException(code: 'account_deletion_pending', status: 403),
          'keepsakes-account',
          Routes.settings,
        ),
        (
          'Rooms expired session',
          const Scaffold(
            body: RoomsFailureNotice(
              failure: RoomsFailure(RoomsFailureKind.signedOut),
            ),
          ),
          null,
          'rooms-failure-sign-in',
          Routes.signIn,
        ),
      ]) {
    testWidgets('$name opens the appropriate recovery destination', (
      tester,
    ) async {
      final db = memoryDb();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
            path: Routes.signIn,
            builder: (_, _) =>
                const Scaffold(body: Text('Sign-in destination')),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, _) =>
                const Scaffold(body: Text('Account destination')),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db: db),
            keepsakesApiProvider.overrideWithValue(
              FakeKeepsakesApi()..error = failure,
            ),
            progressViewProvider.overrideWithValue(progressFor()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildAuraTheme(const Locale('en')),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...systemLocalizationDelegates,
            ],
          ),
        ),
      );
      await settleIo(tester);
      expect(find.byKey(ValueKey(action)), findsOneWidget);
      expect(find.byKey(const ValueKey('keepsakes-retry')), findsNothing);
      await tester.tap(find.byKey(ValueKey(action)));
      await tester.pumpAndSettle();
      expect(
        find.text(
          destination == Routes.signIn
              ? 'Sign-in destination'
              : 'Account destination',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
