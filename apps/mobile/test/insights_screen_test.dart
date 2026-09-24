import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/insights/insight_cards.dart';
import 'package:aura/src/features/insights/insights_providers.dart';
import 'package:aura/src/features/insights/insights_screen.dart';
import 'package:aura/src/features/insights/month_in_stars_screen.dart';
import 'package:aura/src/features/insights/sky_calendar.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// F10 Aura Sky (Milestone B): the sky calendar, the weekly insight card,
/// "Your month in stars", the care card, empty and low-data states,
/// Plus-locked depth and accessibility. Test "today" is Thursday
/// 8 Oct 2026 (IST): the week started Mon 5 Oct, so the weekly card covers
/// 28 Sep – 4 Oct and the month recap is September.

const _moodFor = {
  Quadrant.storm: 'anxious',
  Quadrant.rain: 'drained',
  Quadrant.moonlight: 'calm',
  Quadrant.sunrise: 'joyful',
};

int _seq = 0;

/// Inserts a check-in made at noon IST on [day] (live, stamped in IST).
Future<void> _seed(
  WidgetTester tester,
  AppDatabase db,
  String day,
  Quadrant q, {
  List<String> tags = const [],
}) async {
  final d = LocalDay.parse(day);
  final at = DateTime.utc(d.year, d.month, d.day, 6, 30);
  await io(
    tester,
    () => db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: 'c-${_seq++}',
            moodId: _moodFor[q]!,
            quadrant: q.name,
            tags: Value(tags),
            localDay: day,
            deviceTs: at,
            tzOffsetMinutes: 330,
            tz: const Value('Asia/Kolkata'),
          ),
        ),
  );
}

Future<void> _seedHabit(
  WidgetTester tester,
  AppDatabase db,
  String habitId,
  String day,
) async {
  final d = LocalDay.parse(day);
  final at = DateTime.utc(d.year, d.month, d.day, 6, 30);
  await io(tester, () async {
    await db
        .into(db.habits)
        .insertOnConflictUpdate(
          HabitsCompanion.insert(
            id: habitId,
            kind: 'preset',
            presetKey: const Value('move'),
            createdAt: at,
            updatedAt: at,
          ),
        );
    await db
        .into(db.habitLogs)
        .insert(
          HabitLogsCompanion.insert(
            id: 'h-${_seq++}',
            habitId: habitId,
            localDay: day,
            deviceTs: at,
            tz: const Value('Asia/Kolkata'),
          ),
        );
  });
}

List<String> _days(String from, int n) => [
  for (var i = 0; i < n; i++) LocalDay.parse(from).addDays(i).toIso(),
];

/// The week 28 Sep – 4 Oct: 14 check-ins; Study with Storm Mon–Thu, Move
/// done Mon–Wed (the RULES.md §10 `weekly` vector data).
Future<void> _seedLastWeek(WidgetTester tester, AppDatabase db) async {
  final days = _days('2026-09-28', 7);
  for (var i = 0; i < 7; i++) {
    if (i < 3) {
      await _seed(tester, db, days[i], Quadrant.storm, tags: ['study']);
      await _seed(tester, db, days[i], Quadrant.storm);
      await _seedHabit(tester, db, 'habit-move', days[i]);
    } else if (i == 3) {
      await _seed(tester, db, days[i], Quadrant.sunrise, tags: ['study']);
      await _seed(tester, db, days[i], Quadrant.rain);
    } else {
      await _seed(tester, db, days[i], Quadrant.moonlight);
      await _seed(tester, db, days[i], Quadrant.rain);
    }
  }
}

Future<AppDatabase> _pump(
  WidgetTester tester, {
  AppDatabase? db,
  Future<void> Function(AppDatabase db)? seed,
  bool plus = false,
  bool reduceMotion = false,
  Locale locale = const Locale('en'),
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final database = db ?? memoryDb();
  if (seed != null) await seed(database);
  final router = GoRouter(
    initialLocation: Routes.insights,
    routes: [
      GoRoute(
        path: Routes.insights,
        builder: (_, _) => const InsightsScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (_, _) => const Text('history page'),
          ),
          GoRoute(path: 'month', builder: (_, _) => const MonthInStarsScreen()),
        ],
      ),
      GoRoute(path: Routes.rooms, builder: (_, _) => const Text('rooms page')),
      GoRoute(
        path: Routes.checkIn,
        builder: (_, _) => const Text('checkin page'),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (_, s) => Text('entry ${s.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...testOverrides(db: database, locale: locale.toLanguageTag()),
        plusActiveProvider.overrideWithValue(plus),
      ],
      child: MaterialApp.router(
        theme: buildAuraTheme(locale),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      ),
    ),
  );
  await settleIo(tester);
  return database;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('insights-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Every test ends with an empty tree and a pump, so Drift's stream timers
/// finish (as the other screen suites do).
void _testWidgets(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

void main() {
  setUp(() => _seq = 0);

  group('empty and low-data states', () {
    _testWidgets('no check-ins: a quiet sky, Check in, 0/7 and no cards', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Aura Sky'), findsOneWidget);
      expect(find.byKey(const ValueKey('insights-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('insights-checkin')), findsOneWidget);
      expect(find.byKey(SkyCalendar.monthViewKey), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(WeeklyInsightCard.cardKey), findsNothing);
      expect(find.byKey(MonthInStarsCard.cardKey), findsNothing);
      expect(find.byKey(CareCard.cardKey), findsNothing);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('insights-patterns-gate')),
      );
      expect(
        find.text('Patterns appear after 7 check-ins (0/7)'),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('insights-list')),
        const Offset(0, 2000),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('insights-checkin')));
      await settleIo(tester);
      expect(find.text('checkin page'), findsOneWidget);
    });

    _testWidgets('REQ-INS-01: 6 check-ins show 6/7 and no patterns', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          for (final d in _days('2026-10-02', 6)) {
            await _seed(tester, db, d, Quadrant.moonlight);
          }
        },
      );
      expect(find.byKey(const ValueKey('insights-empty')), findsNothing);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('insights-patterns-gate')),
      );
      expect(
        find.text('Patterns appear after 7 check-ins (6/7)'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('insights-patterns')), findsNothing);
    });

    _testWidgets('REQ-INS-01 negative: 7 check-ins over 4 days show none', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          for (final d in [
            '2026-10-02',
            '2026-10-02',
            '2026-10-03',
            '2026-10-03',
            '2026-10-04',
            '2026-10-04',
            '2026-10-05',
          ]) {
            await _seed(tester, db, d, Quadrant.moonlight);
          }
        },
      );
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('insights-patterns-gate')),
      );
      expect(
        find.text('Patterns appear after check-ins on 5 different days (4/5)'),
        findsOneWidget,
      );
    });

    _testWidgets(
      'enough data, nothing strong: "no clear patterns", no caveat',
      (tester) async {
        await _pump(
          tester,
          seed: (db) async {
            final qs = [...Quadrant.values, ...Quadrant.values];
            final days = _days('2026-09-30', 8);
            for (var i = 0; i < 8; i++) {
              await _seed(tester, db, days[i], qs[i]);
            }
          },
        );
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('insights-patterns-none')),
        );
        expect(
          find.text('No clear patterns right now. Your sky is still here.'),
          findsOneWidget,
        );
      },
    );
  });

  group('patterns (30 days, free)', () {
    _testWidgets('a passing pattern shows in words, never a number', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          final mix = [
            ...List.filled(5, Quadrant.moonlight),
            Quadrant.sunrise,
            Quadrant.sunrise,
            Quadrant.rain,
            Quadrant.rain,
            Quadrant.storm,
          ];
          final days = _days('2026-09-29', 10);
          for (var i = 0; i < 10; i++) {
            await _seed(tester, db, days[i], mix[i]);
          }
        },
      );
      await _scrollTo(tester, find.byKey(const ValueKey('insights-patterns')));
      final text = find.text('Moonlight showed up most often in your sky.');
      expect(text, findsOneWidget);
      expect(
        RegExp(r'[0-9%]').hasMatch(tester.widget<Text>(text).data!),
        isFalse,
      );
      expect(find.byKey(PlusLocked.lockedKey), findsOneWidget);
      expect(find.text('From your last 30 days'), findsOneWidget);
    });
  });

  group('weekly insight card (REQ-INS-06)', () {
    _testWidgets('Free: one pattern from the week just ended; hide keeps it '
        'hidden this week', (tester) async {
      final db = await _pump(tester, seed: (db) => _seedLastWeek(tester, db));
      expect(find.byKey(WeeklyInsightCard.cardKey), findsOneWidget);
      expect(find.text('From your past week'), findsOneWidget);
      final sentence = tester.widget<Text>(
        find.byKey(const ValueKey('insights-weekly-text')),
      );
      expect(
        sentence.data,
        'On check-ins with Study, Storm showed up more often.',
      );
      expect(RegExp(r'[0-9%]').hasMatch(sentence.data!), isFalse);

      await tester.tap(find.byKey(const ValueKey('insights-weekly-hide')));
      await settleIo(tester);
      expect(find.byKey(WeeklyInsightCard.cardKey), findsNothing);
      expect(
        await io(tester, () => db.getValue(InsightsKeys.weeklyHidden)),
        '2026-10-05',
      );
    });

    _testWidgets('Plus: habit × mood can be the week\'s pattern', (
      tester,
    ) async {
      await _pump(tester, plus: true, seed: (db) => _seedLastWeek(tester, db));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('insights-weekly-text')))
            .data,
        'On days you did Move, Storm showed up more often.',
      );
    });

    _testWidgets('negative: a week with nothing passing has no card', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          final days = _days('2026-09-28', 7);
          final qs = [...Quadrant.values, ...Quadrant.values.take(3)];
          for (var i = 0; i < 7; i++) {
            await _seed(tester, db, days[i], qs[i]);
          }
        },
      );
      expect(find.byKey(WeeklyInsightCard.cardKey), findsNothing);
    });

    _testWidgets('a hidden card from an older week does not hide this one', (
      tester,
    ) async {
      final db = memoryDb();
      await io(
        tester,
        () => db.setValue(InsightsKeys.weeklyHidden, '2026-09-28'),
      );
      await _pump(tester, db: db, seed: (db) => _seedLastWeek(tester, db));
      expect(find.byKey(WeeklyInsightCard.cardKey), findsOneWidget);
    });
  });

  group('Your month in stars (REQ-INS-07)', () {
    Future<void> september(WidgetTester tester, AppDatabase db) async {
      final qs = [
        Quadrant.rain,
        Quadrant.rain,
        Quadrant.sunrise,
        Quadrant.moonlight,
      ];
      final days = _days('2026-09-10', 4);
      for (var i = 0; i < 4; i++) {
        await _seed(tester, db, days[i], qs[i]);
      }
      await _seed(tester, db, '2026-09-10', Quadrant.storm);
    }

    _testWidgets('the card leads to the free recap; deeper review is locked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, seed: (db) => september(tester, db));
      expect(find.byKey(MonthInStarsCard.cardKey), findsOneWidget);
      expect(find.text('September 2026 in your sky'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('insights-month-open')));
      await settleIo(tester);
      expect(find.byType(MonthInStarsScreen), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('4 days checked in'), findsOneWidget);
      expect(find.text('Rain: 2 check-ins'), findsOneWidget);
      expect(find.text('Storm: 1 check-in'), findsOneWidget);
      expect(find.byKey(MonthInStarsScreen.skyKey), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'A sky of 5 stars, one for each check-in in September 2026',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.byKey(PlusLocked.lockedKey), 200);
      expect(find.byKey(PlusLocked.lockedKey), findsOneWidget);
      expect(find.byKey(const ValueKey('month-deeper')), findsNothing);
      handle.dispose();
    });

    _testWidgets('Plus sees the deeper review (here: nothing strong)', (
      tester,
    ) async {
      await _pump(tester, plus: true, seed: (db) => september(tester, db));
      await tester.tap(find.byKey(const ValueKey('insights-month-open')));
      await settleIo(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('month-deeper-none')),
        200,
      );
      expect(find.byKey(PlusLocked.lockedKey), findsNothing);
    });

    _testWidgets('hide keeps it hidden for the month; no card for an empty '
        'month', (tester) async {
      await _pump(tester, seed: (db) => september(tester, db));
      await tester.tap(find.byKey(const ValueKey('insights-month-hide')));
      await settleIo(tester);
      expect(find.byKey(MonthInStarsCard.cardKey), findsNothing);
    });

    _testWidgets('a quiet previous month shows no card', (tester) async {
      await _pump(
        tester,
        seed: (db) => _seed(tester, db, '2026-10-02', Quadrant.rain),
      );
      expect(find.byKey(MonthInStarsCard.cardKey), findsNothing);
    });
  });

  group('care card (REQ-INS-04)', () {
    Future<void> heavy(WidgetTester tester, AppDatabase db) async {
      final days = _days('2026-09-30', 9);
      for (var i = 0; i < 9; i++) {
        await _seed(
          tester,
          db,
          days[i],
          i == 8
              ? Quadrant.sunrise
              : (i.isEven ? Quadrant.storm : Quadrant.rain),
        );
      }
    }

    _testWidgets('8 of 9 Storm or Rain: support and a room, set aside for '
        'the day', (tester) async {
      await _pump(tester, seed: (db) => heavy(tester, db));
      expect(find.byKey(CareCard.cardKey), findsOneWidget);
      expect(find.text("It's been a heavy couple of weeks"), findsOneWidget);
      expect(
        find.byKey(const ValueKey('insights-care-support')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('insights-care-later')));
      await settleIo(tester);
      expect(find.byKey(CareCard.cardKey), findsNothing);
    });

    _testWidgets('"Find a room" opens Rooms', (tester) async {
      await _pump(tester, seed: (db) => heavy(tester, db));
      await tester.tap(find.byKey(const ValueKey('insights-care-room')));
      await settleIo(tester);
      expect(find.text('rooms page'), findsOneWidget);
    });

    _testWidgets('mixed weeks: no care card', (tester) async {
      await _pump(tester, seed: (db) => _seedLastWeek(tester, db));
      expect(find.byKey(CareCard.cardKey), findsNothing);
    });
  });

  group('sky calendar', () {
    _testWidgets('each day reads its quadrant in words; quiet days are plain '
        'sky; a tap shows the day\'s entries', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, '2026-10-06', Quadrant.storm);
          await _seed(tester, db, '2026-10-06', Quadrant.storm);
          await _seed(tester, db, '2026-10-07', Quadrant.rain);
          await _seed(tester, db, '2026-10-07', Quadrant.sunrise);
        },
      );
      expect(
        find.bySemanticsLabel('Tuesday, October 6, Storm, 2 check-ins'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Wednesday, October 7, Rain and Sunrise equally, 2 check-ins',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Thursday, October 1, quiet sky'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(SkyCalendar.dayKey(LocalDay.parse('2026-10-06'))),
      );
      await settleIo(tester);
      expect(find.byKey(const ValueKey('insights-day-sheet')), findsOneWidget);
      expect(find.text('Anxious'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('insights-day-entry-c-0')));
      await settleIo(tester);
      expect(find.text('entry c-0'), findsOneWidget);
      handle.dispose();
    });

    _testWidgets('rest days show as a faint ring, read as "a rest day"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, '2026-10-04', Quadrant.moonlight);
          await _seed(tester, db, '2026-10-06', Quadrant.moonlight);
        },
      );
      expect(
        find.bySemanticsLabel('Monday, October 5, a rest day'),
        findsOneWidget,
      );
      handle.dispose();
    });

    _testWidgets('month navigation and the year view', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, '2026-08-20', Quadrant.sunrise);
          await _seed(tester, db, '2026-10-02', Quadrant.rain);
          await _seed(tester, db, '2026-10-03', Quadrant.rain);
        },
      );
      // No future months.
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('sky-next')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('sky-prev')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(find.text('Year'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(SkyCalendar.yearViewKey), findsOneWidget);
      await _scrollTo(tester, find.byKey(SkyCalendar.monthTileKey(10)));
      expect(
        find.bySemanticsLabel('October 2026, 2 days checked in'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('September 2026, a quiet sky'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(SkyCalendar.monthTileKey(8)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(SkyCalendar.monthTileKey(8)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(SkyCalendar.monthViewKey), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
      // August is the first month with data: no going further back.
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('sky-prev')))
            .onPressed,
        isNull,
      );
      handle.dispose();
    });

    _testWidgets('the sky shimmers slowly, and is still under Reduce Motion', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) => _seed(tester, db, '2026-10-06', Quadrant.storm),
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());

      await _pump(
        tester,
        reduceMotion: true,
        seed: (db) => _seed(tester, db, '2026-10-06', Quadrant.storm),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    _testWidgets('all check-ins stays one tap away (History reachable)', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) => _seed(tester, db, '2026-10-06', Quadrant.storm),
      );
      await _scrollTo(tester, find.byKey(const ValueKey('insights-history')));
      await tester.tap(find.byKey(const ValueKey('insights-history')));
      await settleIo(tester);
      expect(find.text('history page'), findsOneWidget);
    });
  });

  group('Plus gates depth only (REQ-INS-05)', () {
    _testWidgets('Free: the sky, patterns and lifetime stats show; any range '
        'is locked with calm copy', (tester) async {
      await _pump(tester, seed: (db) => _seedLastWeek(tester, db));
      expect(find.byKey(SkyCalendar.monthViewKey), findsOneWidget);
      await _scrollTo(tester, find.byKey(PlusLocked.lockedKey));
      expect(
        find.text(
          'Any range and habits alongside moods come with Aura Plus. '
          'Your sky and 30-day patterns are always free.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('insights-range')), findsNothing);
      await _scrollTo(tester, find.byKey(const ValueKey('insights-lifetime')));
      expect(find.text('14 check-ins'), findsOneWidget);
      expect(find.text('7 days in your sky'), findsOneWidget);
    });

    _testWidgets('Plus: pick any range', (tester) async {
      await _pump(tester, plus: true, seed: (db) => _seedLastWeek(tester, db));
      await _scrollTo(tester, find.byKey(const ValueKey('insights-range')));
      expect(find.byKey(PlusLocked.lockedKey), findsNothing);
      await tester.tap(find.byKey(const ValueKey('insights-range-days7')));
      await tester.pump(const Duration(milliseconds: 300));
      // The last 7 days (2–8 Oct) hold 6 of the week's check-ins.
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('insights-patterns-gate')),
      );
      expect(
        find.text('Patterns appear after 7 check-ins (6/7)'),
        findsOneWidget,
      );
    });
  });

  group('accessibility', () {
    _testWidgets('tap targets, labels and contrast (narrow phone)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, width: 360, seed: (db) => _seedLastWeek(tester, db));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    _testWidgets('200% text: no overflow on the sky and cards', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, seed: (db) => _seedLastWeek(tester, db));
      expect(tester.takeException(), isNull);
      expect(find.byKey(WeeklyInsightCard.cardKey), findsOneWidget);
    });

    _testWidgets('Telugu and Tenglish render the sky', (tester) async {
      await _pump(
        tester,
        locale: const Locale('te'),
        seed: (db) => _seedLastWeek(tester, db),
      );
      expect(find.text('Aura Sky'), findsOneWidget);
      expect(find.text('మీ గత వారం నుండి'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        locale: localeFromTag('te-Latn'),
        seed: (db) => _seedLastWeek(tester, db),
      );
      expect(find.text('Mee last week nundi'), findsOneWidget);
    });

    _testWidgets('Hindi and Hinglish render the sky', (tester) async {
      await _pump(
        tester,
        locale: const Locale('hi'),
        seed: (db) => _seedLastWeek(tester, db),
      );
      expect(find.text('Aura Sky'), findsOneWidget);
      expect(find.text('आपके पिछले हफ़्ते से'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        locale: localeFromTag('hi-Latn'),
        seed: (db) => _seedLastWeek(tester, db),
      );
      expect(find.text('Aapke pichhle hafte se'), findsOneWidget);
    });

    _testWidgets('200% text in Hindi (Devanagari): no overflow on the sky and '
        'cards', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        locale: const Locale('hi'),
        seed: (db) => _seedLastWeek(tester, db),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(WeeklyInsightCard.cardKey), findsOneWidget);
    });
  });
}
