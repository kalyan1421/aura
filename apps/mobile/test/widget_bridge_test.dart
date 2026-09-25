import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/checkin/post_save.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/widget/widget_background.dart';
import 'package:aura/src/features/widget/widget_bridge.dart';
import 'package:aura/src/features/widget/widget_follow_up.dart';
import 'package:aura/src/features/widget/widget_prefs.dart';
import 'package:aura/src/features/widget/widget_settings_section.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'widget_fakes.dart';

/// The app side of F11 end to end: publish → the widget saves with the
/// published owner → the app imports once, nudges sync, republishes "done
/// today", and runs only the capsule step at this app open (no companion
/// response replays, PRD 06d).
void main() {
  late AppDatabase db;
  late MemoryWidgetHost host;
  late FakeSync sync;
  final capsuleSteps = <String>[];

  setUp(() {
    db = memoryDb();
    host = MemoryWidgetHost();
    sync = FakeSync();
    capsuleSteps.clear();
  });
  tearDown(() => db.close());

  /// Drift closes its stream queries on a timer after the tree goes.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> step(
    BuildContext context,
    WidgetRef ref, {
    required String checkInId,
    required Mood mood,
    required bool crisisShown,
  }) async {
    expect(crisisShown, isFalse);
    capsuleSteps.add('$checkInId:${mood.id}');
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    GateState gate = const GateState(stage: OnboardingStage.done),
  }) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: WidgetSettingsSection()),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db, sync: sync, gate: gate, widgetHost: host),
          routerProvider.overrideWithValue(router),
          moodTriggerCapsuleStepProvider.overrideWithValue(step),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(widgetBridgeProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...systemLocalizationDelegates,
              ],
              routerConfig: router,
              builder: (_, child) => WidgetCheckInFollowUp(child: child!),
            );
          },
        ),
      ),
    );
    await settleIo(tester, rounds: 10);
    return ProviderScope.containerOf(tester.element(find.byType(Consumer)));
  }

  testWidgets('publishes, imports a widget check-in once, republishes and '
      'runs the capsule step at this app open', (tester) async {
    await pumpApp(tester);

    final first = host.lastDisplay!;
    expect(first['ready'], true);
    expect(first['checkedInToday'], false);
    expect(first['awardsToday'], [10, 2, 2, 0]);
    expect(first.containsKey('lastMood'), isFalse); // off by default
    final owner = first['owner']! as String;
    expect(owner, isNotEmpty);

    // The widget saves "Calm" while the app runs (Android: same process).
    final id = const Ids().v7();
    host.pending = [
      widgetRecord(
        id: id,
        deviceTs: testNow,
        localDay: '2026-10-08',
        owner: owner,
      ),
    ];
    host.notifyChanged();
    await settleIo(tester, rounds: 10);

    final rows = await io(tester, () => db.select(db.checkIns).get());
    expect(rows.single.id, id);
    expect(rows.single.source, 'widget');
    expect(host.acked, [id]);
    expect(sync.writes, 1);
    expect(capsuleSteps, ['$id:calm']);

    final after = host.lastDisplay!;
    expect(after['checkedInToday'], true);
    expect(after['awardsToday'], [2, 2, 0, 0]);
    expect(after['owner'], owner);

    // A resume re-reads the store: nothing is imported twice.
    host.notifyChanged();
    await settleIo(tester, rounds: 6);
    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(1));
    expect(sync.writes, 1);
    expect(capsuleSteps, hasLength(1));
    await unmount(tester);
  });

  testWidgets('a check-in imported in the background gets its capsule step '
      'at this app open; an OS wake-up while the app runs imports and '
      'pushes here', (tester) async {
    // A background run (widget_background.dart) imported it and left the
    // capsule step for this open.
    final bgId = const Ids().v7();
    await tester.runAsync(() async {
      await db
          .into(db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              id: bgId,
              moodId: 'calm',
              quadrant: 'moonlight',
              deviceTs: testNow,
              tzOffsetMinutes: 330,
              tz: const Value('Asia/Kolkata'),
              localDay: '2026-10-08',
              source: const Value('widget'),
            ),
          );
      await rememberWidgetFollowUps(KvStore(db), [bgId]);
    });
    await pumpApp(tester);
    expect(capsuleSteps, ['$bgId:calm']);
    expect(
      await io(tester, () => KvStore(db).get(WidgetKvKeys.followUps)),
      isNull,
    );

    // iOS woke the app (engine alive) for a widget refresh.
    final owner = host.lastDisplay!['owner']! as String;
    final id = const Ids().v7();
    host.pending = [
      widgetRecord(
        id: id,
        deviceTs: testNow,
        localDay: '2026-10-08',
        owner: owner,
      ),
    ];
    expect(host.backgroundSync, isNotNull);
    var finished = false;
    unawaited(host.backgroundSync!().then((_) => finished = true));
    await settleIo(tester, rounds: 10);
    expect(finished, isTrue);
    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(2));
    expect(sync.drainCalls, 1);
    await unmount(tester);
    expect(host.backgroundSync, isNull);
  });

  testWidgets('before onboarding: "Open Aura to continue" only, nothing is '
      'imported', (tester) async {
    host.pending = [
      widgetRecord(id: const Ids().v7(), deviceTs: testNow, owner: 'x'),
    ];
    await pumpApp(tester, gate: const GateState(stage: OnboardingStage.dob));

    final d = host.lastDisplay!;
    expect(d['ready'], false);
    expect(d.containsKey('owner'), isFalse);
    expect(host.readCalls, 0);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);
    await unmount(tester);
  });

  testWidgets('Settings: "Show my last mood" and "Discreet widget" are off '
      'by default and republish the widget', (tester) async {
    final container = await pumpApp(tester);
    expect(container.read(widgetPrefsProvider), const WidgetPrefs());

    await tester.tap(find.byKey(const ValueKey('set-widget-discreet')));
    await settleIo(tester, rounds: 8);
    final d = host.lastDisplay!;
    expect(d['discreet'], true);
    expect(d.containsKey('quadrants'), isFalse);

    // A discreet widget never names a mood: the last-mood switch is off.
    final lastMood = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('set-widget-last-mood')),
    );
    expect(lastMood.onChanged, isNull);
    expect(lastMood.value, isFalse);
    await unmount(tester);
  });
}
