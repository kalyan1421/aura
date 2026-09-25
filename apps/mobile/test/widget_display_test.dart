import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/widget/widget_display.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app hands the widget (F11 "Shows", privacy defaults, Discreet
/// widget, provisional Starlight).
void main() {
  final today = LocalDay.parse('2026-10-08');
  const tz = 'Asia/Kolkata';
  AppLocalizations l10n(String tag) =>
      lookupAppLocalizations(localeFromTag(tag));

  ProgressEvent checkIn(String id, DateTime at, {String day = '2026-10-08'}) =>
      ProgressEvent.checkIn(
        id: id,
        deviceTs: at,
        localDay: LocalDay.parse(day),
        quadrant: Quadrant.rain,
        timezone: tz,
      );

  WidgetDisplayInput input({
    bool ready = true,
    bool discreet = false,
    bool showLastMood = false,
    int? streak,
    Set<String> triggers = const {},
  }) => WidgetDisplayInput(
    ready: ready,
    owner: 'owner-1',
    today: today,
    timezone: tz,
    checkedInToday: true,
    lastMood: moodById('anxious'),
    showLastMood: showLastMood,
    discreet: discreet,
    streakDays: streak,
    capsuleWaiting: true,
    triggerMoodIds: triggers,
    awardsToday: const [2, 2, 0, 0],
    awardsFreshDay: const [10, 2, 2, 0],
    hasAvatar: true,
  );

  /// Every string value anywhere in [json].
  Iterable<String> texts(Object? json) sync* {
    switch (json) {
      case final String s:
        yield s;
      case final Map<Object?, Object?> m:
        for (final v in m.values) {
          yield* texts(v);
        }
      case final List<Object?> list:
        for (final v in list) {
          yield* texts(v);
        }
    }
  }

  group('provisional Starlight (RULES.md §3, from the shared rules)', () {
    test('a fresh day: 10, then 2, 2, then nothing', () {
      final a = widgetAwards(const [], today, tz);
      expect(a.today, [10, 2, 2, 0]);
      expect(a.freshDay, [10, 2, 2, 0]);
    });

    test('after one check-in today the widget earns 2', () {
      final a = widgetAwards(
        [
          checkIn('a', DateTime.utc(2026, 10, 8, 4)),
          // Yesterday's check-ins don't count toward today.
          checkIn('y', DateTime.utc(2026, 10, 7, 4), day: '2026-10-07'),
        ],
        today,
        tz,
      );
      expect(a.today, [2, 2, 0, 0]);
    });

    test('the daily cap of 60 holds across habits', () {
      final events = [
        checkIn('a', DateTime.utc(2026, 10, 8, 4)),
        for (var i = 0; i < 10; i++)
          ProgressEvent.habit(
            id: 'h$i',
            deviceTs: DateTime.utc(2026, 10, 8, 5, i),
            localDay: today,
            habitId: 'habit-$i',
            timezone: tz,
          ),
      ];
      // 10 + 5 × 10 = 60: the widget promises nothing more today.
      expect(widgetAwards(events, today, tz).today, [0, 0, 0, 0]);
      expect(widgetAwards(events, today, tz).freshDay, [10, 2, 2, 0]);
    });
  });

  test('not set up (signed out / under-13 lock): only "Open Aura to '
      'continue", no owner, no moods, no avatar', () {
    final d = buildWidgetDisplay(input(ready: false), l10n('en'), 'en');
    expect(d['ready'], false);
    expect(d.containsKey('owner'), isFalse);
    expect(d.containsKey('quadrants'), isFalse);
    expect(d.containsKey('lastMood'), isFalse);
    expect(d.containsKey('avatar'), isFalse);
    expect((d['s']! as Map)['openApp'], 'Open Aura to continue');
  });

  test('default: the grid, today done, awards; no last mood (off by '
      'default)', () {
    final d = buildWidgetDisplay(input(streak: 3), l10n('en'), 'en');
    expect(d['ready'], true);
    expect(d['owner'], 'owner-1');
    expect(d['auraDay'], '2026-10-08');
    expect(d['checkedInToday'], true);
    expect(d['avatar'], true);
    expect(d.containsKey('lastMood'), isFalse);
    expect(d['streak'], 'Glow streak · 3 days');
    expect(d['capsuleWaiting'], true);
    expect(d['savedAward'], {
      '10': 'Saved · +10 Starlight',
      '2': 'Saved · +2 Starlight',
    });
    final s = d['s']! as Map;
    expect(s['prompt'], 'How are you feeling?');
    expect(s['needHelp'], 'Need help');
    expect(s['capsuleWaiting'], 'Something from past you is waiting');
    final quadrants = (d['quadrants']! as List).cast<Map<String, Object?>>();
    expect(quadrants.map((q) => q['id']), [
      for (final q in Quadrant.values) q.name,
    ]);
    for (final q in quadrants) {
      expect(q['moods'], hasLength(4));
    }
    expect(
      [
        for (final q in quadrants)
          ...(q['moods']! as List).map((m) => (m as Map)['id']),
      ],
      [for (final m in moodCatalog) m.id],
    );
  });

  test('"Show my last mood" on: the last mood line, in the app language', () {
    final d = buildWidgetDisplay(
      input(showLastMood: true),
      l10n('te-Latn'),
      'te-Latn',
    );
    expect(d['lastMood'], {
      'id': 'anxious',
      'quadrant': 'storm',
      'text': 'Last: ${moodById('anxious')!.nameFor('te-Latn')}',
    });
    expect((d['s']! as Map)['prompt'], 'Meeku ippudu ela anipistondi?');
  });

  test('a hidden streak is never sent', () {
    final d = buildWidgetDisplay(input(), l10n('en'), 'en');
    expect(d.containsKey('streak'), isFalse);
  });

  test('REQ-WID-04 Discreet widget: no "Aura", no mood or quadrant word, no '
      'avatar, no last mood, no streak, in every language', () {
    final words = <String>{
      for (final m in moodCatalog)
        for (final n in m.names.values) n.toLowerCase(),
      for (final tag in AuraLocales.all)
        for (final q in Quadrant.values) _quadrant(l10n(tag), q).toLowerCase(),
    };
    for (final tag in AuraLocales.all) {
      final l = l10n(tag);
      for (final ready in [true, false]) {
        final d = buildWidgetDisplay(
          input(
            ready: ready,
            discreet: true,
            showLastMood: true,
            streak: 5,
            triggers: {'anxious'},
          ),
          l,
          tag,
        );
        expect(d['discreet'], true);
        expect(d.containsKey('quadrants'), isFalse);
        expect(d.containsKey('lastMood'), isFalse);
        expect(d.containsKey('streak'), isFalse);
        expect(d.containsKey('triggerMoods'), isFalse);
        expect(d['avatar'], anyOf(isNull, false));
        for (final text in texts(d)) {
          expect(
            text.toLowerCase(),
            isNot(contains('aura')),
            reason: '$tag: $text',
          );
          for (final w in words) {
            expect(
              RegExp(
                '(^|[^\\p{L}])${RegExp.escape(w)}(\$|[^\\p{L}])',
                unicode: true,
              ).hasMatch(text.toLowerCase()),
              isFalse,
              reason: '$tag: "$text" contains "$w"',
            );
          }
        }
      }
    }
  });

  test('every widget string exists in all five languages', () {
    for (final tag in AuraLocales.all) {
      final d = buildWidgetDisplay(
        input(showLastMood: true, streak: 2),
        l10n(tag),
        tag,
      );
      final s = (d['s']! as Map).cast<String, String>();
      expect(s.keys.toSet(), {
        'prompt',
        'checkIn',
        'openApp',
        'doneToday',
        'saved',
        'needHelp',
        'back',
        'capsuleWaiting',
      });
      for (final v in s.values) {
        expect(v.trim(), isNotEmpty);
      }
    }
  });
}

String _quadrant(AppLocalizations l, Quadrant q) => switch (q) {
  Quadrant.storm => l.quadrant_storm,
  Quadrant.rain => l.quadrant_rain,
  Quadrant.moonlight => l.quadrant_moonlight,
  Quadrant.sunrise => l.quadrant_sunrise,
};
