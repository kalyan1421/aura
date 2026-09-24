import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/push/notification_prefs.dart';
import 'package:aura/src/features/push/push_inbox.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/settings/settings_screen.dart';
import 'package:aura/src/features/support/crisis_follow_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'voice_fakes.dart';

/// F14 Milestone B on the phone (contracts/api/v1-notifications.md §6–§10):
/// the new settings (per-type toggles, the opt-in wind-down reminder with its
/// time, habit nudges by habit id), the in-app notices and taps for the new
/// push types, and the crisis follow-up card (local only, 12–72 h, once).

class _SignedIn implements AuthRepository {
  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser =>
      const AuthUser(id: 'user-a', email: 'a@aura.test');
  @override
  Stream<AuthUser?> watchUser() async* {
    yield currentUser;
  }

  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<AppDatabase> _settings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 14000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = memoryDb();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(db: db, auth: _SignedIn()),
      clockProvider.overrideWithValue(FixedClock(testNow)),
      pushMessagingProvider.overrideWithValue(
        FakeMessaging()..granted = PushPermission.authorized,
      ),
      auraPlatformProvider.overrideWithValue(FakePlatform()),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: [
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    ),
  );
  await settleIo(tester);
  return db;
}

Future<List<Map<String, dynamic>>> _patches(
  WidgetTester tester,
  AppDatabase db,
) async {
  final rows = await io(tester, () => db.select(db.outbox).get());
  return [
    for (final r in rows)
      if (r.entity == 'notification_prefs')
        jsonDecode(r.payload) as Map<String, dynamic>,
  ];
}

// ---- push inbox -------------------------------------------------------------

class _Source implements PushInboxSource {
  @override
  Stream<PushEnvelope> get foreground => const Stream.empty();
  @override
  Stream<PushEnvelope> get opened => const Stream.empty();
  @override
  Future<PushEnvelope?> initial() async => null;
  @override
  Future<void> quietWhileOpen() async {}
}

class _NoCapsules implements CapsulePushBridge {
  @override
  Future<bool> shouldShow(String capsuleId) async => false;
  @override
  Future<void> open(BuildContext context, String? capsuleId) async {}
}

Future<(GoRouter, PushInbox)> _inbox(
  WidgetTester tester, {
  bool sanctuaryUsed = false,
}) async {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('home-page')),
      ),
      GoRoute(
        path: Routes.rooms,
        builder: (_, _) => const Scaffold(body: Text('rooms-page')),
      ),
    ],
  );
  final inbox = PushInbox(
    source: _Source(),
    router: PushRouter(
      router: () => router,
      gate: () => const GateState(stage: OnboardingStage.done),
      capsules: _NoCapsules.new,
    ),
    capsules: _NoCapsules.new,
    checkedInToday: () async => false,
    present: (push, open) => showPushNotice(router, push, open),
    sanctuaryUsedThisEvening: () async => sanctuaryUsed,
  );
  addTearDown(inbox.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildAuraTheme(const Locale('en')),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...systemLocalizationDelegates,
      ],
      routerConfig: router,
    ),
  );
  inbox.start();
  await tester.pumpAndSettle();
  return (router, inbox);
}

void main() {
  group('NotificationPrefs (Milestone B fields)', () {
    test('defaults: gestures and welcome back on; the rest opt-in', () {
      const p = NotificationPrefs();
      expect(p.gestures, isTrue);
      expect(p.welcomeBack, isTrue);
      expect(p.lanternHour, isFalse);
      expect(p.windDownEnabled, isFalse);
      expect(p.windDownTime, isNull);
      expect(p.habitNudges, isEmpty);
    });

    test('a patch / the server row applies; habit nudges are a map of '
        'times, malformed entries dropped', () {
      final p = const NotificationPrefs().apply({
        PrefFields.windDownEnabled: true,
        PrefFields.windDownTime: '22:30:00',
        PrefFields.lanternHour: true,
        PrefFields.habitNudges: {'ABC': '09:00', 'x': 'later'},
      });
      expect(p.windDownTime, const DayTime(22, 30));
      expect(p.habitNudges, {'abc': const DayTime(9, 0)});
      expect(p.toJson()[PrefFields.habitNudges], {'abc': '09:00'});
      expect(NotificationPrefs.fromJson(p.toJson()), p);
      expect(
        const NotificationPrefs(windDownTime: DayTime(23, 30))
            .windDownInsideQuietHours,
        isTrue,
      );
    });
  });

  group('Settings › Notifications', () {
    testWidgets('the new toggles are patches of just that setting; the '
        'wind-down reminder turns on at the suggested 22:30', (tester) async {
      final db = await _settings(tester);
      for (final k in [
        'set-ntf-gestures',
        'set-ntf-lantern',
        'set-ntf-wind-down',
        'set-ntf-welcome-back',
      ]) {
        await tester.ensureVisible(_key(k));
        await tester.tap(_key(k));
        await settleIo(tester);
      }
      expect(await _patches(tester, db), [
        {'gestures': false},
        {'lanternHour': true},
        {'windDownTime': '22:30', 'windDownEnabled': true},
        {'welcomeBack': false},
      ]);
      expect(
        find.text(
          "A few quiet minutes at 22:30. Not sent once you've used "
          'Sanctuary that evening.',
        ),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('habit nudges: a preset gets its row, then its time travels '
        'as the whole id → time map', (tester) async {
      final db = await _settings(tester);
      await tester.ensureVisible(_key('set-ntf-habit-hydrate'));
      await tester.tap(_key('set-ntf-habit-hydrate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // the suggested 09:00
      await settleIo(tester);
      final habits = await io(tester, () => db.select(db.habits).get());
      final hydrate = habits.singleWhere((h) => h.presetKey == 'hydrate');
      expect(await _patches(tester, db), [
        {
          'habitNudges': {hydrate.id: '09:00'},
        },
      ]);
      final outbox = await io(tester, () => db.select(db.outbox).get());
      expect(outbox.first.entity, 'habit'); // the habit row travels first
      await _unmount(tester);
    });
  });

  group('push inbox', () {
    testWidgets('gestures: a notice once per room; "Open room" never shows a '
        'name or count', (tester) async {
      final (_, inbox) = await _inbox(tester);
      const push = PushEnvelope(
        type: PushTypes.gesturesReceived,
        id: '0192f0c3-2222-7c1a-9b3d-0000000000aa',
      );
      await inbox.onForeground(push);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('People in your room sent you warmth.'), findsOneWidget);
      expect(find.text('Open room'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await inbox.onForeground(push);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Lantern Hour: notice, and "See rooms" opens Rooms', (
      tester,
    ) async {
      final (_, inbox) = await _inbox(tester);
      await inbox.onForeground(const PushEnvelope(type: PushTypes.lanternHour));
      await tester.pumpAndSettle();
      expect(
        find.text('Lantern Hour is on. Others are here tonight.'),
        findsOneWidget,
      );
      await tester.tap(find.text('See rooms'));
      await tester.pumpAndSettle();
      expect(find.text('rooms-page'), findsOneWidget);
    });

    testWidgets('wind-down: quiet once Sanctuary was used this evening; '
        'welcome back never shows while Aura is open', (tester) async {
      final (_, inbox) = await _inbox(tester, sanctuaryUsed: true);
      await inbox.onForeground(
        const PushEnvelope(type: PushTypes.windDownReminder),
      );
      await inbox.onForeground(const PushEnvelope(type: PushTypes.welcomeBack));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('wind-down and habit nudges: generic notices', (tester) async {
      final (_, inbox) = await _inbox(tester);
      await inbox.onForeground(
        const PushEnvelope(type: PushTypes.windDownReminder),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('A few quiet minutes before sleep, whenever you want them.'),
        findsOneWidget,
      );
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await inbox.onForeground(const PushEnvelope(type: PushTypes.habitNudge));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text("A small habit or two, whenever you're ready."),
        findsOneWidget,
      );
    });
  });

  group('crisis follow-up (in-app only)', () {
    test('due 12–72 h after the sheet, once per event', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final kv = KvStore(db);
      final shown = DateTime.utc(2026, 10, 8, 15);
      expect(await takeCrisisFollowUp(kv, shown), isFalse); // nothing yet
      await recordCrisisSheetShown(kv, shown);
      expect(
        await takeCrisisFollowUp(kv, shown.add(const Duration(hours: 11))),
        isFalse,
      );
      expect(
        await takeCrisisFollowUp(kv, shown.add(const Duration(hours: 13))),
        isTrue,
      );
      expect(
        await takeCrisisFollowUp(kv, shown.add(const Duration(hours: 14))),
        isFalse, // once
      );
      // A later event, opened too late: nothing.
      final again = shown.add(const Duration(days: 3));
      await recordCrisisSheetShown(kv, again);
      expect(
        await takeCrisisFollowUp(kv, again.add(const Duration(hours: 73))),
        isFalse,
      );
    });

    testWidgets('the card: the calm line, "I need help now", and Close', (
      tester,
    ) async {
      final db = memoryDb();
      await io(
        tester,
        () => recordCrisisSheetShown(
          KvStore(db),
          testNow.subtract(const Duration(hours: 20)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(const Scaffold(body: CrisisFollowUpCard())),
        ),
      );
      await settleIo(tester);
      expect(
        find.text(
          'Just checking in. However today feels, help is one tap away.',
        ),
        findsOneWidget,
      );
      expect(_key('crisis-follow-up-help'), findsOneWidget);
      await tester.tap(_key('crisis-follow-up-close'));
      await tester.pump();
      expect(_key('crisis-follow-up'), findsNothing);
      await _unmount(tester);
    });
  });
}
