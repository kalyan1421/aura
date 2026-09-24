import 'dart:io';

import 'package:aura/src/features/plus/paywall_gate.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-PAY-06 (P0): the paywall never appears within 24 h of onboarding, in a
/// crisis flow or the rest of that day, on Nebula wake-up, straight after a
/// Storm or Rain check-in, on an under-13 locked device, or as a gate on the
/// never-paywalled list; at most once a day unprompted, always with a free
/// path. Every rule below is a NEGATIVE test of that list.
void main() {
  final now = DateTime.utc(2026, 10, 20, 10); // 15:30 IST
  const today = LocalDay(2026, 10, 20);
  PaywallContext ctx({
    bool plus = false,
    bool locked = false,
    DateTime? allowedFrom,
    bool noProfile = false,
    LocalDay? crisis,
    Quadrant? lastQ,
    Duration? lastAgo,
    LocalDay? shown,
  }) => PaywallContext(
    now: now,
    today: today,
    plusActive: plus,
    deviceLocked: locked,
    allowedFrom: noProfile
        ? null
        : (allowedFrom ?? now.subtract(const Duration(days: 2))),
    crisisDay: crisis,
    lastCheckInQuadrant: lastQ,
    lastCheckInAt: lastAgo == null ? null : now.subtract(lastAgo),
    unpromptedShownDay: shown,
  );

  group('allowed: limit screens and Settings', () {
    test('the day’s first limit screen shows the explainer; later that day only a link', () {
      for (final s in PaywallSurface.values.where((s) => s.isLimitScreen)) {
        expect(decidePaywall(s, ctx()), PaywallMode.explainer, reason: s.name);
        expect(
          decidePaywall(s, ctx(shown: today)),
          PaywallMode.link,
          reason: '$s once a day',
        );
      }
      expect(
        decidePaywall(
          PaywallSurface.soundsStem,
          ctx(shown: const LocalDay(2026, 10, 19)),
        ),
        PaywallMode.explainer,
      );
    });
    test('Settings is the person’s own choice: not counted as unprompted', () {
      expect(
        decidePaywall(PaywallSurface.settings, ctx(shown: today)),
        PaywallMode.explainer,
      );
    });
    test('with Plus there is nothing to offer', () {
      for (final s in PaywallSurface.values) {
        expect(decidePaywall(s, ctx(plus: true)), PaywallMode.none);
      }
    });
    test('a moon or sunrise check-in, or a storm one 3 h ago, is not "straight after"', () {
      expect(
        decidePaywall(
          PaywallSurface.insightsDepth,
          ctx(lastQ: Quadrant.moonlight, lastAgo: Duration.zero),
        ),
        PaywallMode.explainer,
      );
      expect(
        decidePaywall(
          PaywallSurface.insightsDepth,
          ctx(lastQ: Quadrant.sunrise, lastAgo: const Duration(minutes: 1)),
        ),
        PaywallMode.explainer,
      );
      expect(
        decidePaywall(
          PaywallSurface.insightsDepth,
          ctx(lastQ: Quadrant.storm, lastAgo: heavyCheckInWindow),
        ),
        PaywallMode.explainer,
      );
      expect(
        decidePaywall(
          PaywallSurface.insightsDepth,
          ctx(crisis: const LocalDay(2026, 10, 19)),
        ),
        PaywallMode.explainer,
      );
    });
  });

  group('never (P0 negatives): only "Part of Aura Plus"', () {
    void never(String why, PaywallContext c) {
      for (final s in PaywallSurface.values) {
        expect(
          decidePaywall(s, c),
          PaywallMode.lockedOnly,
          reason: '$why · ${s.name}',
        );
      }
    }

    test('within 24 h of onboarding (install day)', () {
      never(
        'onboarded 2 h ago',
        ctx(allowedFrom: now.add(const Duration(hours: 22))),
      );
      never(
        'exactly at the boundary minus a second',
        ctx(allowedFrom: now.add(const Duration(seconds: 1))),
      );
    });
    test(
      'before the account is known (no profile / no server answer yet)',
      () => never('no profile', ctx(noProfile: true)),
    );
    test(
      'in a crisis flow or the rest of that day',
      () => never('crisis sheet today', ctx(crisis: today)),
    );
    test(
      'straight after a Storm check-in',
      () => never(
        'storm 5 min ago',
        ctx(lastQ: Quadrant.storm, lastAgo: const Duration(minutes: 5)),
      ),
    );
    test(
      'straight after a Rain check-in',
      () => never(
        'rain 2 h ago',
        ctx(lastQ: Quadrant.rain, lastAgo: const Duration(hours: 2)),
      ),
    );
    test(
      'on an under-13 locked device',
      () => never('device lock', ctx(locked: true)),
    );
    test('the unprompted mark never overrides an exclusion', () {
      never('crisis + already shown', ctx(crisis: today, shown: today));
    });
  });

  test('there is no paywall surface for a never-paywalled place', () {
    // PRD: limit screens (4th mood-trigger capsule, long voice, Plus theme,
    // extra Sounds stem, deeper Insights) and Settings — nothing else.
    expect(PaywallSurface.values.map((s) => s.name).toList(), [
      'capsuleTriggerLimit',
      'capsuleLongVoice',
      'plusSky',
      'soundsStem',
      'insightsDepth',
      'settings',
    ]);
  });

  group('source scan: never-paywalled features carry no paywall entry', () {
    // Check-in, habits, rest days, rooms, Breath Ripples, date capsules, crisis
    // support, Sanctuary (Breathe, grounding, Today's minute, base Sounds, the
    // night wind-down), the companion response, "A minute for you", Nebula
    // wake-up (avatar), Look back / keepsakes (history, progress), onboarding.
    const neverDirs = [
      'lib/src/features/checkin',
      'lib/src/features/habits',
      'lib/src/features/rooms',
      'lib/src/features/ripples',
      'lib/src/features/support',
      'lib/src/features/safety',
      'lib/src/features/sanctuary',
      'lib/src/features/companion',
      'lib/src/features/avatar',
      'lib/src/features/history',
      'lib/src/features/progress',
      'lib/src/features/onboarding',
      'lib/src/features/home',
      'lib/src/features/capsules',
      'lib/src/features/reflections',
    ];
    // The only files there allowed to open the Plus note, each for its own
    // PRD limit screen.
    const allowed = {
      'lib/src/features/sanctuary/sounds/sounds_screen.dart':
          'extra Sounds stem',
      'lib/src/features/capsules/capsule_composer_screen.dart':
          '4th mood-trigger capsule',
    };
    final entry = RegExp(
      r'PaywallScreen|openPlus\(|PlusLimitNote|PlusOpenButton|showPlusNoteSheet|plusRoute',
    );

    for (final dir in neverDirs) {
      test(dir, () {
        final d = Directory(dir);
        if (!d.existsSync()) return;
        for (final f
            in d
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))) {
          final path = f.path.replaceAll('\\', '/');
          if (allowed.containsKey(path)) continue;
          expect(
            entry.hasMatch(f.readAsStringSync()),
            isFalse,
            reason: '$path must not open a paywall',
          );
        }
      });
    }

    test('the allowed files open only their own surface', () {
      expect(
        File('lib/src/features/sanctuary/sounds/sounds_screen.dart')
            .readAsStringSync(),
        contains('PaywallSurface.soundsStem'),
      );
      expect(
        File('lib/src/features/capsules/capsule_composer_screen.dart')
            .readAsStringSync(),
        contains('PaywallSurface.capsuleTriggerLimit'),
      );
      // Date capsules never hit the limit: the Plus button sits only in the
      // trigger-limit notice.
      final composer = File(
        'lib/src/features/capsules/capsule_composer_screen.dart',
      ).readAsStringSync();
      expect(RegExp(r'PlusOpenButton\(').allMatches(composer).length, 1);
    });

    test('Breath Ripples, Quiet Together and the crisis sheet never offer a gift or purchase', () {
      for (final dir in [
        'lib/src/features/ripples',
        'lib/src/features/support',
        'lib/src/features/safety',
      ]) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        for (final f
            in d
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))) {
          expect(
            f.readAsStringSync(),
            isNot(contains('gift_sheet.dart')),
            reason: f.path,
          );
          expect(
            f.readAsStringSync(),
            isNot(contains('purchase_controller.dart')),
            reason: f.path,
          );
        }
      }
    });
  });
}
