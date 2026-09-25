import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/insights/insights_screen.dart';
import 'package:aura/src/features/insights/look_back.dart';
import 'package:aura/src/features/insights/look_back_screen.dart';
import 'package:aura/src/features/insights/insight_cards.dart' show PlusLocked;
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura/src/features/voice/voice_loader.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'voice_fakes.dart';

/// F10 Look back (Milestone C, REQ-INS-08). Test "now" is Thu 8 Oct 2026,
/// 15:30 IST, so the weeks are 7–13 Sep 2026 (a month ago), 6–12 Apr 2026
/// (six months ago) and 6–12 Oct 2025 (a year ago).
///
/// Every safety gate has a negative test: hidden 3 h after a Storm or Rain
/// check-in, 24 h after a crisis sheet or the Safety Center, crisis-flagged
/// entries left out, notes and voice only on a further tap, never pushed or
/// shown on Home, the widget, a notification or a share path, and hideable
/// in Settings.

const _moodFor = {
  Quadrant.storm: 'anxious',
  Quadrant.rain: 'drained',
  Quadrant.moonlight: 'calm',
  Quadrant.sunrise: 'joyful',
};

const _crisisNote = 'honestly I just want to die';

/// Inserts a check-in made at noon IST on [day] (or at [at]).
Future<void> _seed(
  WidgetTester tester,
  AppDatabase db,
  String id,
  String day,
  Quadrant q, {
  DateTime? at,
  String? note,
  String? voiceFile,
  DateTime? deletedAt,
}) async {
  final d = LocalDay.parse(day);
  await io(
    tester,
    () => db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: id,
            moodId: _moodFor[q]!,
            quadrant: q.name,
            note: Value(note),
            localDay: day,
            deviceTs: at ?? DateTime.utc(d.year, d.month, d.day, 6, 30),
            tzOffsetMinutes: 330,
            tz: const Value('Asia/Kolkata'),
            voiceFile: Value(voiceFile),
            voiceMs: Value(voiceFile == null ? null : 9000),
            deletedAt: Value(deletedAt),
          ),
        ),
  );
}

/// A check-in a month back (in the 7–13 Sep week).
Future<void> _seedPast(WidgetTester tester, AppDatabase db) =>
    _seed(tester, db, 'past-1', '2026-09-08', Quadrant.moonlight);

Future<AppDatabase> _pump(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  bool plus = false,
  bool reduceMotion = false,
  Locale locale = const Locale('en'),
  double textScale = 1,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(390 * 3, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final database = memoryDb();
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
        ],
      ),
      GoRoute(
        path: Routes.safety,
        builder: (_, _) => const SafetyCenterScreen(),
      ),
      GoRoute(path: Routes.checkIn, builder: (_, _) => const Text('checkin')),
      GoRoute(path: Routes.rooms, builder: (_, _) => const Text('rooms')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...testOverrides(db: database, locale: locale.toLanguageTag()),
        plusActiveProvider.overrideWithValue(plus),
        deviceRegionProvider.overrideWithValue('IN'),
        ...extra,
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
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await settleIo(tester);
  return database;
}

Finder get _card => find.byKey(LookBackEntryCard.cardKey);

Finder get _sheetSizeAnimations => find.descendant(
  of: find.byKey(const ValueKey('look-back-day-sheet')),
  matching: find.byType(AnimatedSize),
);

Future<void> _scrollInsightsTo(WidgetTester tester, Finder f) async {
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

/// Scrolls Insights to the end, where the Look back card would be.
Future<void> _scrollInsightsToEnd(WidgetTester tester) async {
  await _scrollInsightsTo(
    tester,
    find.byKey(const ValueKey('insights-history')),
  );
}

Future<void> _openLookBack(WidgetTester tester) async {
  await _scrollInsightsTo(tester, _card);
  await tester.tap(_card);
  await settleIo(tester);
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(LookBackScreen), findsOneWidget);
}

Future<void> _openDay(WidgetTester tester, String day) async {
  final cell = find.byKey(LookBackScreen.dayKey(LocalDay.parse(day)));
  await tester.ensureVisible(cell);
  await tester.tap(cell);
  await settleIo(tester);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Every test ends with an empty tree and a pump, so Drift's stream timers
/// finish (as the other screen suites do).
void _testWidgets(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

/// "Look back" as code or copy names it (`lookBack`, `look_back`,
/// `look-back`, "Look back"), not an unrelated `…_LOOKBACK_MS` window.
bool _mentionsLookBack(String src) =>
    src.contains('lookBack') ||
    src.contains('LookBack') ||
    RegExp('look[_ -]back', caseSensitive: false).hasMatch(src);

void main() {
  group('pull-only, inside Insights', () {
    _testWidgets('a past week with a check-in: the card at the end of '
        'Insights opens Look back with that week only (Free)', (tester) async {
      await _pump(tester, seed: (db) => _seedPast(tester, db));
      await _scrollInsightsToEnd(tester);
      expect(_card, findsOneWidget);
      expect(find.text('Look back'), findsOneWidget);
      await _openLookBack(tester);
      expect(find.text('A month ago'), findsOneWidget);
      expect(find.byKey(LookBackScreen.weekKey(1)), findsOneWidget);
      // Weeks with nothing to show are left out.
      expect(find.byKey(LookBackScreen.weekKey(6)), findsNothing);
      expect(find.byKey(LookBackScreen.weekKey(12)), findsNothing);
      // Look back is on the never-paywalled list (PRD F12).
      expect(find.byType(PlusLocked), findsNothing);
      // No share path anywhere on the screen (REQ-INS-08 negative).
      expect(find.byIcon(Icons.share_rounded), findsNothing);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
    });

    _testWidgets('all three weeks, newest first', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, 'a', '2026-09-08', Quadrant.moonlight);
          await _seed(tester, db, 'b', '2026-04-09', Quadrant.sunrise);
          await _seed(tester, db, 'c', '2025-10-12', Quadrant.rain);
        },
      );
      await _openLookBack(tester);
      final m = tester.getTopLeft(find.byKey(LookBackScreen.weekKey(1))).dy;
      final six = tester.getTopLeft(find.byKey(LookBackScreen.weekKey(6))).dy;
      await tester.ensureVisible(find.byKey(LookBackScreen.weekKey(12)));
      expect(find.text('Six months ago'), findsOneWidget);
      expect(find.text('A year ago'), findsOneWidget);
      expect(m, lessThan(six));
    });

    _testWidgets('no past week to show: no card (never an empty pull)', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) =>
            _seed(tester, db, 'recent', '2026-10-06', Quadrant.moonlight),
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });

    _testWidgets('the card never sits at the top of Insights: nothing is '
        'surfaced before the person scrolls to it', (tester) async {
      await _pump(tester, seed: (db) => _seedPast(tester, db));
      // The first screenful (care, weekly, month cards and the sky).
      expect(_card.hitTestable(), findsNothing);
    });

    _testWidgets('a deleted entry leaves Look back', (tester) async {
      await _pump(
        tester,
        seed: (db) => _seed(
          tester,
          db,
          'gone',
          '2026-09-08',
          Quadrant.rain,
          deletedAt: testNow,
        ),
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });
  });

  group('day → entries → note/voice only on a further tap', () {
    _testWidgets('tapping a day lists its entries without the note; the note '
        'opens on "Show note" and closes again', (tester) async {
      await _pump(
        tester,
        seed: (db) => _seed(
          tester,
          db,
          'n1',
          '2026-09-08',
          Quadrant.moonlight,
          note: 'Walked by the lake',
        ),
      );
      await _openLookBack(tester);
      expect(find.text('Walked by the lake'), findsNothing);
      await _openDay(tester, '2026-09-08');
      expect(find.byKey(const ValueKey('look-back-day-sheet')), findsOneWidget);
      expect(find.byKey(LookBackEntryTile.tileKey('n1')), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
      // First tap: the entry only. The note stays shut.
      expect(find.text('Walked by the lake'), findsNothing);
      expect(find.byKey(LookBackEntryTile.noteKey('n1')), findsNothing);

      await tester.tap(find.byKey(LookBackEntryTile.openKey('n1')));
      await tester.pumpAndSettle();
      expect(find.text('Walked by the lake'), findsOneWidget);

      await tester.tap(find.byKey(LookBackEntryTile.hideKey('n1')));
      await tester.pumpAndSettle();
      expect(find.text('Walked by the lake'), findsNothing);
    });

    _testWidgets('a voice note opens only on a further tap', (tester) async {
      final player = FakePlayer();
      await _pump(
        tester,
        extra: voiceOverrides(
          player: player,
          store: FakeVoiceStore(),
          loader: FakeLoader(
            (id, file, path) async =>
                const VoiceSource('/tmp/voice.m4a', isTemp: true),
          ),
        ),
        seed: (db) => _seed(
          tester,
          db,
          'v1',
          '2026-09-10',
          Quadrant.sunrise,
          voiceFile: 'rec.enc',
        ),
      );
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-10');
      expect(find.byKey(LookBackEntryTile.voiceKey('v1')), findsNothing);
      expect(find.text('Show voice note'), findsOneWidget);
      await tester.tap(find.byKey(LookBackEntryTile.openKey('v1')));
      await tester.pumpAndSettle();
      expect(find.byKey(LookBackEntryTile.voiceKey('v1')), findsOneWidget);
      expect(player.played, isEmpty); // nothing plays by itself
    });

    _testWidgets('an entry without a note or voice has nothing to open', (
      tester,
    ) async {
      await _pump(tester, seed: (db) => _seedPast(tester, db));
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-08');
      expect(find.byKey(LookBackEntryTile.openKey('past-1')), findsNothing);
    });

    _testWidgets('days without entries to show are not tappable', (
      tester,
    ) async {
      await _pump(tester, seed: (db) => _seedPast(tester, db));
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-09');
      expect(find.byKey(const ValueKey('look-back-day-sheet')), findsNothing);
    });
  });

  group('safety gates (negative tests)', () {
    _testWidgets('hidden for 3 h after a Storm check-in', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await _seed(
            tester,
            db,
            'storm-now',
            '2026-10-08',
            Quadrant.storm,
            at: testNow.subtract(const Duration(hours: 2, minutes: 59)),
          );
        },
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
      expect(find.text('Look back'), findsNothing);
    });

    _testWidgets('hidden for 3 h after a Rain check-in, even a deleted one', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await _seed(
            tester,
            db,
            'rain-now',
            '2026-10-08',
            Quadrant.rain,
            at: testNow.subtract(const Duration(hours: 1)),
            deletedAt: testNow,
          );
        },
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });

    _testWidgets('back once 3 h have passed; Moonlight never hides it', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await _seed(
            tester,
            db,
            'storm-earlier',
            '2026-10-08',
            Quadrant.storm,
            at: testNow.subtract(const Duration(hours: 3)),
          );
          await _seed(
            tester,
            db,
            'calm-now',
            '2026-10-08',
            Quadrant.moonlight,
            at: testNow.subtract(const Duration(minutes: 5)),
          );
        },
      );
      await _scrollInsightsTo(tester, _card);
      expect(_card, findsOneWidget);
    });

    _testWidgets('hidden for 24 h after a crisis sheet on this phone', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await KvStore(db).set(
            KvKeys.lookBackHelpAt,
            testNow
                .subtract(const Duration(hours: 23, minutes: 59))
                .toIso8601String(),
          );
        },
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });

    _testWidgets('back 24 h after the crisis sheet', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await KvStore(db).set(
            KvKeys.lookBackHelpAt,
            testNow.subtract(const Duration(hours: 24)).toIso8601String(),
          );
        },
      );
      await _scrollInsightsTo(tester, _card);
      expect(_card, findsOneWidget);
    });

    _testWidgets('opening "I need help now" from Look back closes it, with '
        'no reason given', (tester) async {
      final db = await _pump(tester, seed: (db) => _seedPast(tester, db));
      await _openLookBack(tester);
      expect(find.byKey(LookBackScreen.weekKey(1)), findsOneWidget);
      await tester.tap(find.byType(HelpNowButton).first);
      await settleIo(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SafetyCenterScreen), findsOneWidget);
      expect(
        await io(tester, () => KvStore(db).get(KvKeys.lookBackHelpAt)),
        isNotNull,
      );
      // Back from the Safety Center: Look back has closed.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await settleIo(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(LookBackScreen.closedKey), findsOneWidget);
      expect(find.text('Look back is closed for now.'), findsOneWidget);
      expect(find.byKey(LookBackScreen.weekKey(1)), findsNothing);
    });

    _testWidgets('the support sheet records the help time on this phone', (
      tester,
    ) async {
      final db = memoryDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db: db),
            deviceRegionProvider.overrideWithValue('IN'),
          ],
          child: localized(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSupportSheet(context, crisis: true),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settleIo(tester);
      final at = await io(tester, () => KvStore(db).get(KvKeys.lookBackHelpAt));
      expect(DateTime.parse(at!), testNow);
    });

    _testWidgets('crisis-flagged entries never appear: a lexicon match on '
        'the note and a check-in help was opened from', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, 'ok', '2026-09-08', Quadrant.sunrise);
          await _seed(
            tester,
            db,
            'crisis',
            '2026-09-08',
            Quadrant.storm,
            note: _crisisNote,
          );
          await _seed(tester, db, 'helped', '2026-09-08', Quadrant.storm);
          await markLookBackCheckInHelp(KvStore(db), 'helped');
        },
      );
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-08');
      expect(find.byKey(LookBackEntryTile.tileKey('ok')), findsOneWidget);
      expect(find.byKey(LookBackEntryTile.tileKey('crisis')), findsNothing);
      expect(find.byKey(LookBackEntryTile.tileKey('helped')), findsNothing);
      expect(find.text(_crisisNote), findsNothing);
      expect(find.text('Anxious'), findsNothing);
    });

    _testWidgets('a week whose only entries are crisis-flagged is not shown '
        '(and no card leads to it)', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seed(
            tester,
            db,
            'crisis',
            '2026-09-08',
            Quadrant.storm,
            note: _crisisNote,
          );
        },
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });

    _testWidgets('the star of a day never hints at a left-out entry', (
      tester,
    ) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seed(tester, db, 'ok', '2026-09-08', Quadrant.sunrise);
          await _seed(
            tester,
            db,
            'crisis',
            '2026-09-09',
            Quadrant.storm,
            note: _crisisNote,
          );
        },
      );
      await _openLookBack(tester);
      final sem = tester.getSemantics(
        find.byKey(LookBackScreen.dayKey(LocalDay.parse('2026-09-09'))),
      );
      expect(sem.label, contains('quiet sky'));
      expect(sem.label, isNot(contains('Storm')));
    });

    _testWidgets('the check-in screen flags a check-in the crisis sheet '
        'opened from (device-only)', (tester) async {
      final db = memoryDb();
      final kv = KvStore(db);
      await io(tester, () => markLookBackCheckInHelp(kv, 'x'));
      await io(tester, () => markLookBackCheckInHelp(kv, 'x'));
      await io(tester, () => markLookBackCheckInHelp(kv, 'y'));
      expect(
        await io(tester, () => kv.get(KvKeys.lookBackHelpCheckIns)),
        '["x","y"]',
      );
      expect(KvKeys.deviceScoped, contains(KvKeys.lookBackHelpCheckIns));
      expect(KvKeys.deviceScoped, contains(KvKeys.lookBackHelpAt));
      await db.close();
    });

    _testWidgets('hidden in Settings: no card at all', (tester) async {
      await _pump(
        tester,
        seed: (db) async {
          await _seedPast(tester, db);
          await setLookBackHidden(KvStore(db), hidden: true);
        },
      );
      await _scrollInsightsToEnd(tester);
      expect(_card, findsNothing);
    });

    _testWidgets('the Settings switch hides and shows it', (tester) async {
      final db = memoryDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db),
          child: localized(
            const Scaffold(body: Material(child: LookBackSettingsSwitch())),
          ),
        ),
      );
      await settleIo(tester);
      final sw = find.byKey(LookBackSettingsSwitch.switchKey);
      expect(tester.widget<SwitchListTile>(sw).value, isTrue);
      expect(find.text('Look back in Aura Sky'), findsOneWidget);
      await tester.tap(sw);
      await settleIo(tester);
      expect(
        await io(tester, () => KvStore(db).get(KvKeys.lookBackHidden)),
        'true',
      );
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      await tester.tap(sw);
      await settleIo(tester);
      expect(
        await io(tester, () => KvStore(db).get(KvKeys.lookBackHidden)),
        isNull,
      );
    });
  });

  group('never pushed, never on Home, the widget, a notification or a share '
      'path (REQ-INS-08 negative)', () {
    List<File> dartFiles(String dir) =>
        Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

    test('only Insights can open it; there is no route to deep-link', () {
      for (final f in dartFiles('lib')) {
        final path = f.path.replaceAll(r'\', '/');
        if (path.contains('/features/insights/')) continue;
        final src = f.readAsStringSync();
        expect(src.contains('look_back_screen.dart'), isFalse, reason: path);
        expect(src.contains('LookBackScreen'), isFalse, reason: path);
        expect(src.contains('LookBackEntryCard'), isFalse, reason: path);
      }
      final routes = File('lib/src/core/router/routes.dart').readAsStringSync();
      expect(routes.toLowerCase(), isNot(contains('look')));
    });

    test('Home, push, notifications, the widget, share and keepsakes never '
        'touch Look back', () {
      const barred = [
        'lib/src/features/home',
        'lib/src/features/push',
        'lib/src/features/notifications',
        'lib/src/features/widget',
        'lib/src/features/share',
        'lib/src/features/keepsakes',
      ];
      for (final dir in barred) {
        if (!Directory(dir).existsSync()) continue;
        for (final f in dartFiles(dir)) {
          final src = f.readAsStringSync();
          expect(_mentionsLookBack(src), isFalse, reason: f.path);
        }
      }
    });

    test('the server has no Look back notification or endpoint', () {
      const server = '../../server/aura-api/src';
      if (!Directory(server).existsSync()) return;
      for (final f
          in Directory(server)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.ts'))) {
        final path = f.path.replaceAll(r'\', '/');
        // The rule copy that keeps the engines in step (no endpoint uses it).
        if (path.endsWith('/rules/look-back.ts') ||
            path.endsWith('/rules/index.ts')) {
          continue;
        }
        expect(_mentionsLookBack(f.readAsStringSync()), isFalse, reason: path);
      }
    });
  });

  group('accessibility', () {
    _testWidgets('each day is one node with its date and quadrant in words '
        '(never colour alone)', (tester) async {
      await _pump(tester, seed: (db) => _seedPast(tester, db));
      await _openLookBack(tester);
      final sem = tester.getSemantics(
        find.byKey(LookBackScreen.dayKey(LocalDay.parse('2026-09-08'))),
      );
      expect(sem.label, contains('September 8'));
      expect(sem.label, contains('Moonlight'));
      expect(sem.hint, 'Shows this day\'s check-ins');
    });

    _testWidgets('Reduce Motion: the stars are still and the note opens '
        'without any animation', (tester) async {
      await _pump(
        tester,
        reduceMotion: true,
        seed: (db) => _seed(
          tester,
          db,
          'n1',
          '2026-09-08',
          Quadrant.moonlight,
          note: 'Walked by the lake',
        ),
      );
      await _openLookBack(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      await _openDay(tester, '2026-09-08');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(LookBackEntryTile.openKey('n1')));
      await tester.pump();
      // The note is there at once: no size animation, only the button's own
      // tap ink, which ends on its own.
      expect(find.text('Walked by the lake'), findsOneWidget);
      expect(_sheetSizeAnimations, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    _testWidgets('with motion on, the note eases open', (tester) async {
      await _pump(
        tester,
        seed: (db) => _seed(
          tester,
          db,
          'n1',
          '2026-09-08',
          Quadrant.moonlight,
          note: 'Walked by the lake',
        ),
      );
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-08');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(LookBackEntryTile.openKey('n1')));
      await tester.pump();
      expect(_sheetSizeAnimations, findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Walked by the lake'), findsOneWidget);
    });

    _testWidgets('200% text: no overflow', (tester) async {
      await _pump(
        tester,
        textScale: 2,
        seed: (db) async {
          await _seed(tester, db, 'a', '2026-09-08', Quadrant.moonlight);
          await _seed(tester, db, 'b', '2026-09-08', Quadrant.storm);
        },
      );
      await _openLookBack(tester);
      await _openDay(tester, '2026-09-08');
      expect(tester.takeException(), isNull);
    });

    for (final locale in const [
      Locale('te'),
      Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
      Locale('hi'),
      Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
    ]) {
      _testWidgets('renders in ${locale.toLanguageTag()}', (tester) async {
        await _pump(
          tester,
          locale: locale,
          seed: (db) => _seedPast(tester, db),
        );
        await _openLookBack(tester);
        final l = lookupAppLocalizations(locale);
        expect(find.text(l.insights_lookBackMonth), findsOneWidget);
        expect(find.text('Look back'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
