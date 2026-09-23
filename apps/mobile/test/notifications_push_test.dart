import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/push/push_inbox.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/push/push_service.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:aura/src/core/db/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'push_service_test.dart' show DevicesApi, FakeAuth;

/// F14 push handling in the app: payloads reduced to `{type, id, tag}`;
/// foreground → a calm in-app notice (never a system notification), the
/// reminder only when not checked in today, a capsule once and only when
/// the capsules feature hasn't announced it; taps / launches → the right
/// place; Android drops its own duplicate capsule notice.

const _capsule = '0192f0c3-1111-7c1a-9b3d-00000000beef';

class _Source implements PushInboxSource {
  final foregroundCtl = StreamController<PushEnvelope>.broadcast();
  final openedCtl = StreamController<PushEnvelope>.broadcast();
  PushEnvelope? launch;
  int quieted = 0;

  @override
  Stream<PushEnvelope> get foreground => foregroundCtl.stream;
  @override
  Stream<PushEnvelope> get opened => openedCtl.stream;
  @override
  Future<PushEnvelope?> initial() async {
    final l = launch;
    launch = null;
    return l;
  }

  @override
  Future<void> quietWhileOpen() async => quieted++;
}

class _Bridge implements CapsulePushBridge {
  bool show = true;
  final List<String> asked = [];
  final List<String?> opened = [];

  @override
  Future<bool> shouldShow(String capsuleId) async {
    asked.add(capsuleId);
    return show;
  }

  @override
  Future<void> open(BuildContext context, String? capsuleId) async {
    opened.add(capsuleId);
  }
}

class _World {
  _World(this.router, this.inbox, this.source, this.bridge);
  final GoRouter router;
  final PushInbox inbox;
  final _Source source;
  final _Bridge bridge;
  bool checkedIn = false;
  GateState gate = const GateState(stage: OnboardingStage.done);
}

Future<_World> _pump(WidgetTester tester, {PushEnvelope? launch}) async {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('home-page')),
      ),
      GoRoute(
        path: Routes.checkIn,
        builder: (_, _) => const Scaffold(body: Text('checkin-page')),
      ),
    ],
  );
  final source = _Source()..launch = launch;
  final bridge = _Bridge();
  late _World world;
  final inbox = PushInbox(
    source: source,
    router: PushRouter(
      router: () => router,
      gate: () => world.gate,
      capsules: () => bridge,
    ),
    capsules: () => bridge,
    checkedInToday: () async => world.checkedIn,
    present: (push, open) => showPushNotice(router, push, open),
  );
  world = _World(router, inbox, source, bridge);
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
  return world;
}

const _reminder = PushEnvelope(type: PushTypes.dailyReminder);
const _capsulePush = PushEnvelope(
  type: PushTypes.capsuleUnlocked,
  id: _capsule,
  tag: '402673000',
);

void main() {
  group('payloads', () {
    test(
      'only type, a UUID id and a numeric tag are kept; content never is',
      () {
        final e = pushEnvelope({
          'type': 'capsule_unlocked',
          'id': _capsule.toUpperCase(),
          'title': 'Dear me',
          'mood': 'anxious',
        }, tag: '402673000');
        expect(e, _capsulePush);
        expect(e.toString(), isNot(contains(_capsule)));
        expect(
          pushEnvelope({'type': 'daily_reminder', 'id': 'You wrote…'})?.id,
          isNull,
        );
        expect(
          pushEnvelope({'type': 'capsule_unlocked'}, tag: 'capsule:x')?.tag,
          isNull,
        );
        expect(pushEnvelope({'id': _capsule}), isNull);
        expect(capsuleNoticeIdOf(_capsulePush), 402673000);
        expect(
          capsuleNoticeIdOf(
            const PushEnvelope(type: 'daily_reminder', tag: '5'),
          ),
          isNull,
        );
      },
    );
  });

  group('foreground: a calm in-app notice, never a system notification', () {
    testWidgets('the reminder shows the PRD line with "Check in", which opens '
        'the check-in', (tester) async {
      final w = await _pump(tester);
      expect(w.source.quieted, 1); // iOS presentation off while open
      w.source.foregroundCtl.add(_reminder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text("A quiet minute for you. How's today feeling?"),
        findsOneWidget,
      );
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      expect(find.text('checkin-page'), findsOneWidget);
    });

    testWidgets('no reminder notice once checked in today', (tester) async {
      final w = await _pump(tester);
      w.checkedIn = true;
      await w.inbox.onForeground(_reminder);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('push-notice-daily_reminder')),
        findsNothing,
      );
    });

    testWidgets('a capsule: shown once per capsule, only when the capsules '
        'feature says this phone hasn\'t announced it', (tester) async {
      final w = await _pump(tester);
      await w.inbox.onForeground(_capsulePush);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Something you sealed is ready to open.'),
        findsOneWidget,
      );
      expect(w.bridge.asked, [_capsule]);

      ScaffoldMessenger.of(tester.element(find.text('home-page')))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await w.inbox.onForeground(_capsulePush); // the same capsule again
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Something you sealed is ready to open.'), findsNothing);
      expect(w.bridge.asked, [_capsule]);

      w.bridge.show = false; // opened here, or its local notice already fired
      const other = PushEnvelope(
        type: PushTypes.capsuleUnlocked,
        id: '0192f0c3-2222-7c1a-9b3d-00000000cafe',
      );
      await w.inbox.onForeground(other);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Something you sealed is ready to open.'), findsNothing);

      await w.inbox.onForeground(
        const PushEnvelope(type: PushTypes.capsuleUnlocked),
      );
      await w.inbox.onForeground(const PushEnvelope(type: 'lantern_hour'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('"Open" on the capsule notice opens the capsules', (
      tester,
    ) async {
      final w = await _pump(tester);
      await w.inbox.onForeground(_capsulePush);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(w.bridge.opened, [_capsule]);
    });
  });

  group('taps and launches', () {
    testWidgets('a tapped reminder opens the check-in; a tapped capsule the '
        'capsules', (tester) async {
      final w = await _pump(tester);
      w.source.openedCtl.add(_capsulePush);
      await tester.pumpAndSettle();
      expect(w.bridge.opened, [_capsule]);
      w.source.openedCtl.add(_reminder);
      await tester.pumpAndSettle();
      expect(find.text('checkin-page'), findsOneWidget);
    });

    testWidgets('a notification that launched the app is followed once the '
        'first screen is up', (tester) async {
      final w = await _pump(tester, launch: _reminder);
      await tester.pumpAndSettle();
      expect(find.text('checkin-page'), findsOneWidget);
      expect(w.source.launch, isNull);
    });

    testWidgets('the gate wins: during onboarding or the under-13 lock a tap '
        'goes nowhere', (tester) async {
      final w = await _pump(tester);
      w.gate = const GateState(stage: OnboardingStage.dob);
      w.source.openedCtl.add(_reminder);
      w.source.openedCtl.add(_capsulePush);
      await tester.pumpAndSettle();
      expect(find.text('home-page'), findsOneWidget);
      expect(w.bridge.opened, isEmpty);
    });
  });

  group('Android background', () {
    test('the duplicate local capsule notice for that date is cancelled '
        '(id = the push tag); nothing else is touched', () async {
      final cancelled = <int>[];
      Future<void> cancel(int id) async => cancelled.add(id);
      expect(
        await dropDuplicateCapsuleNotice(_capsulePush, cancel: cancel),
        isTrue,
      );
      expect(
        await dropDuplicateCapsuleNotice(_reminder, cancel: cancel),
        isFalse,
      );
      expect(
        await dropDuplicateCapsuleNotice(
          const PushEnvelope(type: PushTypes.capsuleUnlocked, id: _capsule),
          cancel: cancel,
        ),
        isFalse,
      );
      expect(cancelled, [402673000]);
      expect(
        await dropDuplicateCapsuleNotice(
          _capsulePush,
          cancel: (_) async => throw Exception('plugin'),
        ),
        isFalse, // never throws
      );
    });
  });

  group('wiring', () {
    test('push off in this build (or a registration-only fake): the inbox is '
        'inert', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          ...testOverrides(db: db),
          pushMessagingProvider.overrideWithValue(FakeMessaging()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(pushInboxProvider).isActive, isFalse);
    });

    test(
      '"checked in today" reads this phone\'s check-ins for the Aura day',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        expect(await checkedInOn(db, '2026-10-08'), isFalse);
        await db
            .into(db.checkIns)
            .insert(
              CheckInsCompanion.insert(
                id: '0192f0c3-3333-7c1a-9b3d-000000000001',
                moodId: 'calm',
                quadrant: 'moonlight',
                localDay: '2026-10-08',
                tzOffsetMinutes: 330,
                deviceTs: testNow,
                tz: const Value('Asia/Kolkata'),
              ),
            );
        expect(await checkedInOn(db, '2026-10-08'), isTrue);
        expect(await checkedInOn(db, '2026-10-09'), isFalse);
        await (db.update(db.checkIns))
            .write(CheckInsCompanion(deletedAt: Value(testNow)));
        expect(await checkedInOn(db, '2026-10-08'), isFalse); // deleted
        expect(LocalDay.tryParse('2026-10-08'), isNotNull);
      },
    );
  });

  group('PushService: asking from Settings (PRD 15-permissions)', () {
    Future<(PushService, KvStore, FakeMessaging)> service({
      Map<String, dynamic>? softAsk,
      bool available = true,
    }) async {
      final db = memoryDb();
      addTearDown(db.close);
      final kv = KvStore(db);
      if (softAsk != null) await kv.setJson(KvKeys.pushSoftAsk, softAsk);
      final m = FakeMessaging();
      final push = PushService(
        messaging: available ? m : null,
        auth: FakeAuth(),
        api: DevicesApi(),
        kv: kv,
        hasProfile: () async => true,
        hasCheckedIn: () async => true,
        clock: FixedClock(testNow),
      );
      addTearDown(push.dispose);
      return (push, kv, m);
    }

    String ago(int days) =>
        testNow.subtract(Duration(days: days)).toIso8601String();

    test('never asked → may ask; a decline < 30 days ago → only the Settings '
        'link; 30+ days → the one re-ask; after it → never again', () async {
      expect(await (await service()).$1.mayAskAgain(), isTrue);
      expect(
        await (await service(softAsk: {'answer': 'notNow', 'at': ago(29)})).$1
            .mayAskAgain(),
        isFalse,
      );
      expect(
        await (await service(softAsk: {'answer': 'notNow', 'at': ago(30)})).$1
            .mayAskAgain(),
        isTrue,
      );
      expect(
        await (await service(
          softAsk: {'answer': 'allow', 'at': ago(90), 'reaskedAt': ago(40)},
        )).$1.mayAskAgain(),
        isFalse,
      );
      expect(await (await service(available: false)).$1.mayAskAgain(), isFalse);
      expect(await (await service(available: false)).$1.permission(), isNull);
    });

    test('requestFromSettings: the OS prompt, recorded as the re-ask when '
        'there was an answer before', () async {
      final (push, kv, m) = await service(
        softAsk: {'answer': 'notNow', 'at': ago(31)},
      );
      expect(await push.requestFromSettings(), PushPermission.authorized);
      expect(m.requests, [false]);
      final ask = await kv.getJson(KvKeys.pushSoftAsk);
      expect(ask, {
        'answer': 'allow',
        'at': ago(31),
        'reaskedAt': testNow.toIso8601String(),
      });

      final (first, kv2, _) = await service();
      await first.requestFromSettings();
      expect(
        (await kv2.getJson(KvKeys.pushSoftAsk))!.containsKey('reaskedAt'),
        isFalse,
      );
    });
  });
}
