import 'package:aura/src/features/sanctuary/sounds/stem_manifest.dart';
import 'package:aura/src/features/sanctuary/sounds/wind_down.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// The night wind-down (PRD 06d, REQ-SAN-13): reshuffled per Aura day —
/// the same all day, different on consecutive days — and thinning out to
/// silence over ~20 minutes.
void main() {
  final base = [
    for (final s in StemManifest.bundled.listed)
      if (!s.isPlus) s,
  ];

  test('the pool is the free base set', () {
    expect({for (final s in base) s.id}, {
      'rain',
      'ocean',
      'wind',
      'night_insects',
      'singing_bowl',
      'chimes',
      'brown_noise',
    });
  });

  test('the same Aura day always gives the same order', () {
    const day = LocalDay(2026, 10, 8);
    final a = windDownOrderFor(day, base);
    final b = windDownOrderFor(day, base.reversed.toList());
    expect(a, b);
    expect(windDownPlanFor(day, base).order, a);
  });

  test('two consecutive Aura days never give the same order (2 years)', () {
    var day = const LocalDay(2026, 1, 1);
    var previous = windDownOrderFor(day, base);
    for (var i = 0; i < 730; i++) {
      day = day.addDays(1);
      final order = windDownOrderFor(day, base);
      expect(order, isNot(previous), reason: '$day');
      previous = order;
    }
  });

  test('it really reshuffles: many different orders over two months', () {
    final seen = <String>{};
    var day = const LocalDay(2026, 11, 1);
    for (var i = 0; i < 60; i++) {
      seen.add(windDownOrderFor(day, base).join(','));
      day = day.addDays(1);
    }
    expect(seen.length, greaterThan(40));
  });

  test('a lineup is a bed, then three other distinct stems', () {
    var day = const LocalDay(2026, 12, 1);
    for (var i = 0; i < 50; i++) {
      final order = windDownOrderFor(day, base);
      expect(order, hasLength(4));
      expect(order.toSet(), hasLength(4));
      expect(
        StemManifest.bundled.byId(order.first)!.role,
        StemRole.bed,
        reason: order.first,
      );
      day = day.addDays(1);
    }
  });

  test('a small pool still works (and an empty one gives nothing)', () {
    final two = [
      StemManifest.bundled.byId('brown_noise')!,
      StemManifest.bundled.byId('chimes')!,
    ];
    expect(windDownOrderFor(const LocalDay(2026, 10, 8), two), [
      'brown_noise',
      'chimes',
    ]);
    expect(windDownOrderFor(const LocalDay(2026, 10, 8), const []), isEmpty);
  });

  group('the plan', () {
    final plan = windDownPlanFor(const LocalDay(2026, 10, 8), base);

    double total(Duration t) =>
        plan.gainsAt(t).values.fold(0.0, (a, b) => a + b);

    test('starts silent and fades in over at least 2 s', () {
      expect(total(Duration.zero), 0);
      for (final g in plan.gainsAt(const Duration(seconds: 1)).values) {
        expect(g, lessThan(0.2));
      }
      expect(total(const Duration(seconds: 5)), greaterThan(1));
    });

    test('never more than four at once, and it thins out to silence', () {
      for (var s = 0; s <= 1200; s += 5) {
        final on = plan
            .gainsAt(Duration(seconds: s))
            .values
            .where((g) => g > 0)
            .length;
        expect(on, lessThanOrEqualTo(4));
      }
      expect(
        total(const Duration(minutes: 2)),
        greaterThan(total(const Duration(minutes: 10))),
      );
      expect(
        total(const Duration(minutes: 10)),
        greaterThan(total(const Duration(minutes: 18))),
      );
      expect(total(windDownLength), 0);
      expect(plan.isOver(windDownLength), isTrue);
      expect(plan.isOver(const Duration(minutes: 19)), isFalse);
    });

    test('about 20 minutes long', () {
      expect(plan.length, const Duration(minutes: 20));
    });
  });
}
