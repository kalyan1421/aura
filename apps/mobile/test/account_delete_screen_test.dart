import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/widgets/inline_notice.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/account/delete_account_screen.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/settings/settings_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// "Delete my account" (F8 REQ-ACC-11, Apple 5.1.1(v)): three taps from
/// Settings, explains scope / grace / store subscriptions / connection,
/// Cancel first; the phone is wiped only after the server accepted.

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');
final _purge = DateTime.utc(2026, 10, 15, 10);

class _Auth implements AuthRepository {
  _Auth(this.user);

  AuthUser? user;
  final _users = StreamController<AuthUser?>.broadcast();

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() async* {
    yield user;
    yield* _users.stream;
  }

  @override
  Future<String?> accessToken() async => user == null ? null : 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {
    user = null;
    _users.add(null);
  }
}

class _Account implements AccountRepository {
  int requests = 0;
  Object? failRequest;

  @override
  Future<DateTime> requestDeletion() async {
    requests++;
    final e = failRequest;
    if (e != null) throw e;
    return _purge;
  }

  @override
  Future<DateTime?> scheduledDeletion() async => null;
  @override
  Future<void> cancelDeletion() async {}
}

List<Override> _overrides(
  AppDatabase db,
  AuthRepository auth,
  AccountRepository account, {
  required bool online,
}) {
  final t = testTime();
  return [
    appDatabaseProvider.overrideWithValue(db),
    secureStoreProvider.overrideWithValue(MemorySecureStore()),
    timeContextProvider.overrideWithValue(t),
    initialTimezoneProvider.overrideWithValue(t.timezone),
    timezoneResolverProvider.overrideWithValue(() async => t.timezone),
    authRepositoryProvider.overrideWithValue(auth),
    syncControllerProvider.overrideWithValue(FakeSync()),
    connectivityProvider.overrideWith((ref) => Stream.value(online)),
    nowProvider.overrideWith((ref) => Stream.value(t.now())),
    initialGateProvider.overrideWithValue(
      const GateState(stage: OnboardingStage.done),
    ),
    initialLocaleTagProvider.overrideWithValue('en'),
    accountRepositoryProvider.overrideWithValue(account),
  ];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AppDatabase db,
  required _Auth auth,
  required _Account account,
  bool online = true,
  String initial = Routes.settings,
}) async {
  tester.view.physicalSize = const Size(1170, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: _overrides(db, auth, account, online: online),
  );
  addTearDown(container.dispose);
  final gate = ValueNotifier(container.read(gateControllerProvider));
  container.listen(gateControllerProvider, (_, next) => gate.value = next);
  final router = GoRouter(
    initialLocation: initial,
    refreshListenable: gate,
    redirect: (_, s) =>
        gate.value.onboarded || s.matchedLocation == Routes.welcome
        ? null
        : Routes.welcome,
    routes: [
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: Routes.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const Scaffold(body: Text('welcome-stub')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildAuraTheme(const Locale('en')),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        routerConfig: router,
      ),
    ),
  );
  await settleIo(tester);
  return container;
}

Future<AppDatabase> _dbWithACheckIn(WidgetTester tester) async {
  final db = memoryDb();
  await tester.runAsync(
    () => CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    ).save(id: const Ids().v7(), mood: moodById('calm')!, note: 'private'),
  );
  return db;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final _deleteButton = find.byKey(const ValueKey('acct-delete'));

void main() {
  testWidgets('three taps from Settings: explains what goes, the 7-day grace '
      'and store subscriptions; Cancel is first and focused; confirming '
      'schedules it, wipes the phone, shows the date, then Welcome', (
    tester,
  ) async {
    final db = await _dbWithACheckIn(tester);
    final auth = _Auth(_alice);
    final account = _Account();
    final c = await _pump(tester, db: db, auth: auth, account: account);

    // Tap 1: Settings → the deletion screen.
    await tester.tap(find.byKey(const ValueKey('set-delete-account')));
    await tester.pumpAndSettle();
    for (final text in [
      'Deleting your account removes:',
      'Your check-ins and notes',
      'Your habits',
      "Your Starlight and your Aura's growth",
      'Your account and the email you sign in with',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byKey(const ValueKey('acct-grace')), findsOneWidget);
    expect(find.textContaining('App Store or Google Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-blocked')), findsNothing);

    // Tap 2: the explicit button → the confirmation. Cancel changes nothing.
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    final dialog = tester.widget<AlertDialog>(
      find.byKey(const ValueKey('acct-confirm-dialog')),
    );
    final first = dialog.actions!.first as TextButton;
    expect(first.key, const ValueKey('acct-confirm-cancel'));
    expect(first.autofocus, isTrue);
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('acct-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(account.requests, 0);

    // Tap 3: confirm.
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('acct-confirm-delete')));
    await settleIo(tester, rounds: 10);

    expect(account.requests, 1);
    expect(auth.currentUser, isNull);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);
    expect(await io(tester, () => db.select(db.outbox).get()), isEmpty);
    expect(
      find.text(
        'It will be deleted on October 15, 2026. Sign in again before then '
        'to keep it.',
      ),
      findsOneWidget,
    );
    // Still here until the person is done reading.
    expect(c.read(gateControllerProvider).stage, OnboardingStage.done);

    await tester.tap(find.byKey(const ValueKey('acct-done')));
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(c.read(gateControllerProvider).stage, OnboardingStage.welcome);
    expect(find.text('welcome-stub'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('offline: a calm notice and the button waits for a connection', (
    tester,
  ) async {
    await _pump(
      tester,
      db: memoryDb(),
      auth: _Auth(_alice),
      account: _Account(),
      online: false,
      initial: Routes.deleteAccount,
    );
    expect(
      find.descendant(
        of: find.byType(InlineNotice),
        matching: find.text(
          'Deleting your account needs a connection. Connect to the '
          'internet, then try again.',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_deleteButton).onPressed, isNull);
    await _unmount(tester);
  });

  testWidgets('a failed request wipes nothing and offers a retry', (
    tester,
  ) async {
    final db = await _dbWithACheckIn(tester);
    final auth = _Auth(_alice);
    final account = _Account()
      ..failRequest = const ApiException(code: 'x', isNetwork: true);
    await _pump(
      tester,
      db: db,
      auth: auth,
      account: account,
      initial: Routes.deleteAccount,
    );

    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('acct-confirm-delete')));
    await settleIo(tester);

    expect(
      find.text(
        "We couldn't reach Aura, and nothing has been deleted. Check your "
        'connection and try again.',
      ),
      findsOneWidget,
    );
    expect(auth.currentUser, isNotNull);
    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(1));

    account.failRequest = null;
    await tester.tap(find.byKey(const ValueKey('acct-retry')));
    await settleIo(tester, rounds: 10);
    expect(account.requests, 2);
    expect(find.byKey(const ValueKey('acct-scheduled')), findsOneWidget);
    expect(auth.currentUser, isNull);
    await tester.tap(find.byKey(const ValueKey('acct-done')));
    await settleIo(tester);
    await _unmount(tester);
  });

  testWidgets('signed out: there is no account to delete', (tester) async {
    await _pump(
      tester,
      db: memoryDb(),
      auth: _Auth(null),
      account: _Account(),
      initial: Routes.deleteAccount,
    );
    expect(find.byKey(const ValueKey('acct-blocked')), findsOneWidget);
    expect(tester.widget<FilledButton>(_deleteButton).onPressed, isNull);
    await _unmount(tester);
  });
}
