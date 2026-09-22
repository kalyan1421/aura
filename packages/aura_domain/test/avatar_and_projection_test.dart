import 'package:aura_domain/aura_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AuraAvatarState', () {
    test('clamps out-of-range values instead of throwing (REQ-AVA-06)', () {
      final s = AuraAvatarState(
        ringCount: 5,
        glowLevel: -2,
        constellationStars: 40,
        hue: -30,
      );
      expect(s.ringCount, 3);
      expect(s.glowLevel, 0);
      expect(s.constellationStars, 12);
      expect(s.hue, 330);
      expect(AuraAvatarState(hue: double.nan).hue, AuraAvatarState.defaultHue);
      expect(s.copyWith(ringCount: 9).ringCount, 3);
    });

    test('is a value type with an immutable cosmetic set', () {
      final a = AuraAvatarState(equippedCosmetics: {'halo'});
      final b = AuraAvatarState(equippedCosmetics: {'halo'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(() => a.equippedCosmetics.add('x'), throwsUnsupportedError);
    });

    test('stage never regresses via atLeast', () {
      expect(AuraStage.spark.atLeast(AuraStage.glow), AuraStage.glow);
      expect(AuraStage.radiance.atLeast(AuraStage.glow), AuraStage.radiance);
      expect(AuraStage.fromName('bogus'), AuraStage.spark);
    });
  });

  group('LocalDay', () {
    test('parses, formats and does exact day arithmetic', () {
      final d = LocalDay.parse('2026-03-29');
      expect(d.addDays(3).toIso(), '2026-04-01');
      expect(LocalDay.parse('2026-10-08').daysSince(d), 193);
      expect(LocalDay.tryParse('nope'), isNull);
    });
  });

  group('glowStatus copy states', () {
    final base = StreakState(
      glowStreak: 3,
      restBank: 2,
      lastActiveDay: LocalDay.parse('2026-10-05'),
    );
    test('active / continuing / covered / carries on', () {
      expect(
        glowStatus(base, LocalDay.parse('2026-10-05')),
        GlowStatus.activeToday,
      );
      expect(
        glowStatus(base, LocalDay.parse('2026-10-06')),
        GlowStatus.continuing,
      );
      expect(
        glowStatus(base, LocalDay.parse('2026-10-08')),
        GlowStatus.restCovered,
      );
      expect(
        glowStatus(base, LocalDay.parse('2026-10-09')),
        GlowStatus.carriesOn,
      );
      expect(
        glowStatus(StreakState.initial, LocalDay.parse('2026-10-09')),
        GlowStatus.fresh,
      );
    });
  });

  group('projectProgress', () {
    const tz = 'Asia/Kolkata';
    final now = DateTime.parse('2026-10-08T10:00:00Z'); // 15:30 IST
    final today = LocalDay.parse('2026-10-08');

    test('3 check-ins + 9 habits in a day = 59 (REQ-AVA-02)', () {
      final events = <ProgressEvent>[
        for (var i = 0; i < 3; i++)
          ProgressEvent.checkIn(
            id: 'c$i',
            deviceTs: now.subtract(Duration(minutes: 30 - i)),
            localDay: today,
            quadrant: Quadrant.rain,
          ),
        for (var i = 0; i < 9; i++)
          ProgressEvent.habit(
            id: 'h$i',
            deviceTs: now.subtract(Duration(minutes: 20 - i)),
            localDay: today,
            habitId: 'habit$i',
          ),
      ];
      final p = projectProgress(events: events, now: now, timezone: tz);
      expect(p.todayStarlight, 59);
      expect(p.totalStarlight, 59);
      expect(p.streak.glowStreak, 1);
      expect(p.avatar.hue, closeTo(175, 0.001));
      expect(p.avatar.isResting, isFalse);
    });

    test('backfill earns nothing and is not active-day evidence', () {
      final p = projectProgress(
        events: [
          ProgressEvent.checkIn(
            id: 'b',
            deviceTs: now,
            localDay: today.addDays(-1),
            quadrant: Quadrant.storm,
          ),
        ],
        now: now,
        timezone: tz,
      );
      expect(p.totalStarlight, 0);
      expect(p.streak.lifetimeGlowDays, 0);
      // Still part of the recent mood mix.
      expect(p.hue, closeTo(275, 0.001));
    });

    test('deleted check-ins keep Starlight and glow days, leave the hue', () {
      final p = projectProgress(
        events: [
          ProgressEvent.checkIn(
            id: 'd',
            deviceTs: now,
            localDay: today,
            quadrant: Quadrant.storm,
            deleted: true,
          ),
        ],
        now: now,
        timezone: tz,
        previousHue: 45,
      );
      expect(p.totalStarlight, 10);
      expect(p.streak.lifetimeGlowDays, 1);
      expect(p.hue, isNull);
      expect(p.avatar.hue, 45);
    });

    test('traits from Breathe and Sleep completions; resting after 3 days', () {
      final events = <ProgressEvent>[];
      for (var d = 0; d < 6; d++) {
        final ts = now.subtract(Duration(days: 10 - d));
        final day = auraDay(ts, tz);
        events
          ..add(
            ProgressEvent.habit(
              id: 'b$d',
              deviceTs: ts,
              localDay: day,
              habitId: 'hb',
              habitKey: PresetHabitKeys.breathe,
            ),
          )
          ..add(
            ProgressEvent.habit(
              id: 's$d',
              deviceTs: ts,
              localDay: day,
              habitId: 'hs',
              habitKey: PresetHabitKeys.sleepOnTime,
            ),
          );
      }
      final p = projectProgress(events: events, now: now, timezone: tz);
      expect(p.avatar.ringCount, 1);
      expect(p.avatar.glowLevel, 1);
      expect(p.avatar.isResting, isTrue);
      expect(p.totalStarlight, 60);
    });

    test('moments: wake-up and evolve play once per id', () {
      final before = AuraAvatarState(isResting: true);
      final after = AuraAvatarState(stage: AuraStage.ember);
      final m = momentsBetween(before, after, causeId: 'c1');
      expect(m.map((e) => e.kind), [
        AvatarMomentKind.wakeUp,
        AvatarMomentKind.evolve,
      ]);
      expect(m.last.id, 'evolve:ember');
    });
  });
}
