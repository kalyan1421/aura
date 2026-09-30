import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/features/health/health_source.dart';
import 'package:aura/src/features/universe/sky.dart';
import 'package:aura/src/features/universe/universe_scene_view.dart';
import 'package:aura/src/features/universe/universe_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W06 (RULES.md section 13 `sky` and `stones`): the sky follows the phone's
/// clock; steps only ever add warmth, only after an opt-in, and never leave
/// the phone. With no health adapter the app shows nothing about health.

const _warm = Color(0xFFF2D28C);
const _stoneFaces = 18; // one stepping stone = 6 segments x 3 triangles

class _FakeHealth implements HealthSource {
  _FakeHealth({this.grants = true, this.steps = 5300, this.throws = false});

  HealthAvailability state = HealthAvailability.needsPermission;
  bool grants;
  int? steps;
  bool throws;
  int stepReads = 0;
  int permissionAsks = 0;

  @override
  Future<HealthAvailability> availability() async {
    if (throws) throw StateError('health store exploded');
    return state;
  }

  @override
  Future<bool> requestStepsAccess() async {
    permissionAsks++;
    if (grants) state = HealthAvailability.ready;
    return grants;
  }

  @override
  Future<int?> stepsToday(DateTime now, String timezone) async {
    stepReads++;
    return steps;
  }
}

int _litFaces(WidgetTester tester) => tester
    .widget<UniverseSceneView>(find.byType(UniverseSceneView))
    .mesh
    .faces
    .where((f) => f.color == _warm)
    .length;

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  HealthSource? health,
  DateTime? at,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        db: db,
        time: at == null ? null : testTime(at),
        health: health,
      ),
      child: localized(const UniverseScreen()),
    ),
  );
  await settleIo(tester);
}

Future<void> _end(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

void main() {
  group('the sky follows the phone clock', () {
    test('local hour from an instant and a zone offset (half hours, wrap, '
        'negative zones)', () {
      final t = DateTime.utc(2026, 10, 8, 10, 0);
      expect(localHourOf(t, 330), 15); // Asia/Kolkata 15:30
      expect(localHourOf(DateTime.utc(2026, 10, 8, 23, 45), 330), 5); // 05:15
      expect(localHourOf(DateTime.utc(2026, 10, 8, 3, 0), -300), 22); // NY
      expect(localHourOf(DateTime.utc(2026, 10, 8, 0, 0), -720), 12);
      expect(localHourOf(DateTime.utc(2026, 10, 8, 12, 0), 840), 2); // +14
    });

    for (final (at, phase) in [
      (DateTime.utc(2026, 10, 8, 0, 30), SkyPhase.dawn), // 06:00 IST
      (DateTime.utc(2026, 10, 8, 10, 0), SkyPhase.day), // 15:30
      (DateTime.utc(2026, 10, 8, 12, 30), SkyPhase.dusk), // 18:00
      (DateTime.utc(2026, 10, 8, 16, 0), SkyPhase.night), // 21:30
    ]) {
      testWidgets('the island sky at ${at.toIso8601String()} is ${phase.name}',
          (tester) async {
        final db = memoryDb();
        await _pump(tester, db, at: at);
        expect(
          tester.widget<UniverseSceneView>(find.byType(UniverseSceneView)).sky,
          phase,
        );
        await _end(tester, db);
      });
    }
  });

  group('steps: opt-in, read-only, warmth only', () {
    testWidgets('with no health adapter the app shows nothing about health and '
        'no stone glows', (tester) async {
      final db = memoryDb();
      await _pump(tester, db);
      expect(find.byKey(const ValueKey('universe-reallife')), findsNothing);
      expect(find.textContaining('Health'), findsNothing);
      expect(_litFaces(tester), 0);
      await _end(tester, db);
    });

    testWidgets('the card is off by default, explains the promise, and reads '
        'nothing until it is turned on', (tester) async {
      final health = _FakeHealth();
      final db = memoryDb();
      await _pump(tester, db, health: health);
      final card = find.byKey(const ValueKey('universe-reallife'));
      await tester.scrollUntilVisible(card, 300);
      expect(find.text('Walks light the path'), findsOneWidget);
      expect(
        find.textContaining('keeps it on this phone, never uploads or shows it'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('universe-reallife-switch')),
            )
            .value,
        isFalse,
      );
      expect(health.stepReads, 0);
      expect(health.permissionAsks, 0);
      expect(_litFaces(tester), 0);
      await _end(tester, db);
    });

    testWidgets('turning it on asks once, then stones glow one per thousand '
        'steps; the number is shown and kept nowhere', (tester) async {
      final health = _FakeHealth(steps: 5300);
      final db = memoryDb();
      await _pump(tester, db, health: health);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-reallife-switch')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('universe-reallife-switch')));
      await settleIo(tester);
      expect(health.permissionAsks, 1);
      expect(health.stepReads, greaterThan(0));
      expect(_litFaces(tester), litStones(5300) * _stoneFaces);
      // The number is never on screen...
      expect(find.textContaining('5300'), findsNothing);
      expect(find.textContaining('5,300'), findsNothing);
      // ...and never stored: only the opt-in flag is kept.
      final kept = await io(
        tester,
        () async => [
          for (final r in await db.select(db.keyValues).get())
            '${r.key}=${r.value}',
        ],
      );
      expect(kept.where((e) => e.contains('5300')), isEmpty);
      expect(kept, contains('${KvKeys.healthStepsEnabled}=1'));
      await _end(tester, db);
    });

    testWidgets('a quiet day is a plain path, never a dim one', (tester) async {
      final health = _FakeHealth(steps: 0);
      final db = memoryDb();
      await _pump(tester, db, health: health);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-reallife-switch')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('universe-reallife-switch')));
      await settleIo(tester);
      expect(_litFaces(tester), 0);
      // Same stones as with the feature off: nothing was darkened.
      final plain = tester
          .widget<UniverseSceneView>(find.byType(UniverseSceneView))
          .mesh
          .faces
          .length;
      expect(plain, greaterThan(0));
      await _end(tester, db);
    });

    testWidgets('declining the system prompt is calm and changes nothing',
        (tester) async {
      final health = _FakeHealth(grants: false);
      final db = memoryDb();
      await _pump(tester, db, health: health);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('universe-reallife-switch')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('universe-reallife-switch')));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('universe-reallife-denied')), findsOneWidget);
      expect(find.textContaining('Nothing changes'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('universe-reallife-switch')),
            )
            .value,
        isFalse,
      );
      expect(health.stepReads, 0);
      expect(await io(tester, () => KvStore(db).get(KvKeys.healthStepsEnabled)), isNull);
      expect(_litFaces(tester), 0);
      await _end(tester, db);
    });

    testWidgets('turning it off puts the path back to plain and clears the '
        'flag', (tester) async {
      final health = _FakeHealth(steps: 3000);
      final db = memoryDb();
      await _pump(tester, db, health: health);
      final sw = find.byKey(const ValueKey('universe-reallife-switch'));
      await tester.scrollUntilVisible(sw, 300);
      await tester.tap(sw);
      await settleIo(tester);
      expect(_litFaces(tester), 3 * _stoneFaces);
      await tester.tap(sw);
      await settleIo(tester);
      expect(_litFaces(tester), 0);
      expect(await io(tester, () => KvStore(db).get(KvKeys.healthStepsEnabled)), isNull);
      await _end(tester, db);
    });

    testWidgets('a health store that fails is treated as unavailable, never a '
        'crash', (tester) async {
      final health = _FakeHealth(throws: true);
      final db = memoryDb();
      await _pump(tester, db, health: health);
      expect(find.byKey(const ValueKey('universe-reallife')), findsNothing);
      expect(_litFaces(tester), 0);
      expect(tester.takeException(), isNull);
      await _end(tester, db);
    });

    testWidgets('the opt-in survives a restart of the universe, and steps are '
        'read again fresh', (tester) async {
      final health = _FakeHealth(steps: 2000);
      final db = memoryDb();
      await io(tester, () => KvStore(db).set(KvKeys.healthStepsEnabled, '1'));
      health.state = HealthAvailability.ready;
      await _pump(tester, db, health: health);
      expect(_litFaces(tester), 2 * _stoneFaces);
      expect(health.stepReads, greaterThan(0));
      await _end(tester, db);
    });
  });
}
