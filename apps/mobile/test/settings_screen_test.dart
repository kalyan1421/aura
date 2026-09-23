import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/prefs/comfort_prefs.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/widgets/help_app_bar.dart';
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

import 'package:aura/src/features/support/support_sheet.dart';

import 'helpers.dart';

/// Settings: Language · Comfort · Account · Help & Safety · About
/// (REQ-A11Y-08, F3 hide streak, F8 REQ-ACC-11, F9 REQ-SAFE-11/12).

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
  DateTime? scheduled;
  int cancels = 0;

  @override
  Future<DateTime> requestDeletion() async => scheduled = _purge;
  @override
  Future<DateTime?> scheduledDeletion() async => scheduled;
  @override
  Future<void> cancelDeletion() async {
    cancels++;
    scheduled = null;
  }
}

List<Override> _overrides(
  AppDatabase db,
  AuthRepository auth,
  AccountRepository account,
) {
  final t = testTime();
  return [
    appDatabaseProvider.overrideWithValue(db),
    secureStoreProvider.overrideWithValue(MemorySecureStore()),
    timeContextProvider.overrideWithValue(t),
    initialTimezoneProvider.overrideWithValue(t.timezone),
    timezoneResolverProvider.overrideWithValue(() async => t.timezone),
    authRepositoryProvider.overrideWithValue(auth),
    syncControllerProvider.overrideWithValue(FakeSync()),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    nowProvider.overrideWith((ref) => Stream.value(t.now())),
    initialGateProvider.overrideWithValue(
      const GateState(stage: OnboardingStage.done),
    ),
    initialLocaleTagProvider.overrideWithValue('en'),
    accountRepositoryProvider.overrideWithValue(account),
  ];
}

/// Settings inside a small router (Settings → delete screen; Welcome once
/// the gate leaves `done`).
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AppDatabase db,
  AuthRepository? auth,
  _Account? account,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 7200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: _overrides(db, auth ?? _Auth(_alice), account ?? _Account()),
  );
  addTearDown(container.dispose);
  final gate = ValueNotifier(container.read(gateControllerProvider));
  container.listen(gateControllerProvider, (_, next) => gate.value = next);
  final router = GoRouter(
    initialLocation: Routes.settings,
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

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('sections in order, each announced as a heading', (tester) async {
    await _pump(tester, db: memoryDb());
    final handle = tester.ensureSemantics();
    var lastY = -1.0;
    for (final (key, title) in [
      ('language', 'Language'),
      ('comfort', 'Comfort'),
      ('account', 'Account'),
      ('help', 'Help & Safety'),
      ('about', 'About'),
    ]) {
      final f = find.byKey(ValueKey('set-section-$key'));
      expect(f, findsOneWidget, reason: key);
      final y = tester.getTopLeft(f).dy;
      expect(y, greaterThan(lastY), reason: '$key is out of order');
      lastY = y;
      expect(tester.getSemantics(f), isSemantics(isHeader: true, label: title));
    }
    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('Comfort switches write the device preferences', (tester) async {
    final db = memoryDb();
    final c = await _pump(tester, db: db);
    expect(find.text("Also follows your phone's setting"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-reduce-motion')));
    await tester.tap(find.byKey(const ValueKey('set-haptics')));
    await tester.tap(find.byKey(const ValueKey('set-hide-streak')));
    await settleIo(tester);

    expect(
      c.read(comfortControllerProvider),
      const ComfortPrefs(reduceMotion: true, haptics: false, hideStreak: true),
    );
    expect(await io(tester, () => KvStore(db).getJson(KvKeys.comfort)), {
      'reduceMotion': true,
      'haptics': false,
      'hideStreak': true,
    });
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('set-hide-streak'))),
      isSemantics(hasToggledState: true, isToggled: true),
    );
    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('Writing prompts: on by default; switching it off is a device '
      'preference that survives sign-out', (tester) async {
    final db = memoryDb();
    await _pump(tester, db: db);
    final prompts = find.byKey(const ValueKey('set-guided-prompts'));
    await tester.scrollUntilVisible(
      prompts,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<SwitchListTile>(prompts).value, isTrue);

    await tester.tap(prompts);
    await settleIo(tester);

    expect(tester.widget<SwitchListTile>(prompts).value, isFalse);
    expect(
      await io(tester, () => KvStore(db).get(KvKeys.guidedPromptsOff)),
      'true',
    );
    expect(KvKeys.deviceScoped, contains(KvKeys.guidedPromptsOff));
    await _unmount(tester);
  });

  testWidgets("when the phone already reduces motion the switch is on and "
      'locked', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, db: memoryDb());

    final sw = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('set-reduce-motion')),
    );
    expect(sw.value, isTrue);
    expect(sw.onChanged, isNull);
    expect(find.text("Also follows your phone's setting"), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Account: signed out offers sign-in only', (tester) async {
    await _pump(tester, db: memoryDb(), auth: _Auth(null));
    expect(find.byKey(const ValueKey('set-sign-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-sign-out')), findsNothing);
    expect(find.byKey(const ValueKey('set-delete-account')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Account: signed in shows the email, Sign out and "Delete my '
      'account", which opens the deletion screen', (tester) async {
    await _pump(tester, db: memoryDb());
    expect(find.text('Signed in as a@aura.test'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-delete-account')));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Help & Safety: disclaimer, legal links, Grievance Officer and '
      'support email', (tester) async {
    await _pump(tester, db: memoryDb());
    expect(
      find.text('Aura is not a medical device or an emergency service.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('legal-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-terms')), findsOneWidget);

    final grievance = find.byKey(const ValueKey('set-grievance'));
    expect(
      find.descendant(of: grievance, matching: find.text('Grievance Officer')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: grievance,
        matching: find.textContaining('grievance@example.com'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('set-support')),
        matching: find.text('support@example.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('Version 0.1.0 (1)'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Sign out with unsynced items: a titled warning, "Stay signed '
      'in" first; "Sign out anyway" wipes and goes to Welcome', (tester) async {
    final db = memoryDb();
    final auth = _Auth(_alice);
    await tester.runAsync(
      () => CheckInRepository(
        db,
        OutboxRepository(db, const Ids()),
        testTime(),
      ).save(id: const Ids().v7(), mood: moodById('calm')!),
    );
    final c = await _pump(tester, db: db, auth: auth);

    await tester.tap(find.byKey(const ValueKey('set-sign-out')));
    await settleIo(tester);
    expect(find.text('Sign out of Aura?'), findsOneWidget);
    expect(
      find.text("1 thing hasn't synced yet. Stay signed in until it does?"),
      findsOneWidget,
    );
    final dialog = tester.widget<AlertDialog>(
      find.byKey(const ValueKey('set-sign-out-dialog')),
    );
    final first = dialog.actions!.first as TextButton;
    expect(first.key, const ValueKey('set-stay'));
    expect(first.autofocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('set-stay')));
    await settleIo(tester);
    expect(auth.currentUser, isNotNull);

    await tester.tap(find.byKey(const ValueKey('set-sign-out')));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('set-sign-out-anyway')));
    await settleIo(tester);
    expect(auth.currentUser, isNull);
    expect(c.read(gateControllerProvider).stage, OnboardingStage.welcome);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);
    await _unmount(tester);
  });

  testWidgets('a deletion that sync found pending is offered at the top: '
      '"Keep my account" cancels it', (tester) async {
    final account = _Account()..scheduled = _purge;
    final c = await _pump(tester, db: memoryDb(), account: account);
    expect(find.byKey(const ValueKey('acct-pending-card')), findsNothing);

    await tester.runAsync(
      () => c.read(deletionHoldProvider.notifier).reportFromSync(),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('acct-pending-card')), findsOneWidget);
    expect(
      find.text(
        'Your account is set to be deleted on October 15, 2026. Keep it?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('acct-keep')));
    await settleIo(tester);
    expect(account.cancels, 1);
    expect(find.byKey(const ValueKey('acct-pending-card')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('"I need help now" leaves the 56 dp app bar at large text so '
      'it is never cut off: its own row under the title', (tester) async {
    final help = find.byType(HelpNowButton);
    final action = find.byKey(HelpBarLayout.actionKey);
    final below = find.byKey(HelpBarLayout.bottomKey);

    // Room beside the title (the test font is about twice as wide as real
    // ones, so a wide phone): in the bar, on one line, bar still 56 dp.
    await _pump(tester, db: memoryDb(), width: 600);
    expect(find.descendant(of: action, matching: help), findsOneWidget);
    expect(below, findsNothing);
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    expect(tester.getSize(help).height, lessThanOrEqualTo(kToolbarHeight));
    await _unmount(tester);

    // 200% text: its own row under the title, inside the app bar, whole.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, db: memoryDb());
    expect(tester.takeException(), isNull);
    expect(action, findsNothing);
    expect(find.descendant(of: below, matching: help), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: below),
      findsOneWidget,
    );
    final title = tester.getRect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
    );
    final row = tester.getRect(below);
    final button = tester.getRect(help);
    expect(title.bottom, lessThanOrEqualTo(row.top));
    expect(row.top, closeTo(kToolbarHeight, 0.01));
    expect(button.top, greaterThanOrEqualTo(row.top - 0.01));
    expect(button.bottom, lessThanOrEqualTo(row.bottom + 0.01));
    expect(button.right, lessThanOrEqualTo(row.right + 0.01));
    expect(
      tester.getRect(find.byType(AppBar)).bottom,
      closeTo(row.bottom, 0.01),
    );
    await _unmount(tester);
  });
}
