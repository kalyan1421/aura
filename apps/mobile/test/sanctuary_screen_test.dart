import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/capsules/capsules_entry.dart';
import 'package:aura/src/features/sanctuary/breath_haptics.dart';
import 'package:aura/src/features/sanctuary/breath_pacer.dart';
import 'package:aura/src/features/sanctuary/breathe_session_screen.dart';
import 'package:aura/src/features/sanctuary/sanctuary_activities.dart';
import 'package:aura/src/features/sanctuary/sanctuary_screen.dart';
import 'package:aura/src/features/sanctuary/steps_activity_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _QuietHaptics implements BreathHaptics {
  @override
  void phaseStarted(BreathPhase phase) {}
}

/// The Sanctuary tab (F15 v1): the person's Aura as a still orb, Today's
/// minute, Breathe, the grounding library and the "Future you" slot, with
/// "I need help now" in the header.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    DateTime? now,
    String locale = 'en',
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(
            db: memoryDb(),
            time: now == null ? null : testTime(now),
            locale: locale,
          ),
          breathHapticsProvider.overrideWithValue(_QuietHaptics()),
        ],
        child: localized(
          const SanctuaryScreen(),
          locale: localeFromTag(locale),
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SanctuaryScreen)));

  testWidgets('top to bottom: the orb, Today\'s minute, Breathe, the '
      'grounding library, then the Future you slot', (tester) async {
    await pump(tester);
    final l = l10n(tester);
    expect(find.text('Sanctuary'), findsOneWidget);
    expect(find.byType(HelpNowButton), findsOneWidget);

    double y(Finder f) => tester.getTopLeft(f).dy;
    final today = find.text("Today's minute");
    final breathe = find.byKey(const ValueKey('sanctuary-breathe'));
    final grounding = find.text('Grounding');
    expect(y(today), lessThan(y(breathe)));
    expect(y(breathe), lessThan(y(grounding)));
    for (final a in groundingLibrary) {
      final tile = find.byKey(ValueKey('sanctuary-${a.name}'));
      await tester.scrollUntilVisible(tile, 200);
      expect(
        find.descendant(of: tile, matching: find.text(a.title(l))),
        findsOneWidget,
      );
    }
    // Last: the F4 "Future you" entry (renders nothing until capsules land).
    await tester.scrollUntilVisible(find.byType(CapsulesEntryTile), 200);
    expect(find.byType(CapsulesEntryTile), findsOneWidget);
    // No other people, counts or presence anywhere (REQ-SAN-07).
    expect(find.textContaining(RegExp(r'\d+ (people|here)')), findsNothing);
    await end(tester);
  });

  testWidgets('"I need help now" is within the first three focus stops, '
      'right after the title (REQ-SAN-08)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final order = tester.semantics.simulatedAccessibilityTraversal().toList();
    final labels = [for (final n in order.take(4)) n.getSemanticsData().label];
    final helpAt = labels.indexWhere((s) => s.contains('I need help now'));
    expect(helpAt, inInclusiveRange(0, 2), reason: '$labels');
    expect(labels.first, 'Sanctuary');
    semantics.dispose();
    await end(tester);
  });

  testWidgets('Today\'s minute: the same all day, the next one after the '
      '04:00 rollover (REQ-SAN-06)', (tester) async {
    // 15:30 IST, 8 Oct.
    await pump(tester, now: DateTime.utc(2026, 10, 8, 10));
    final l = l10n(tester);
    final oct8 = todaysMinuteFor(LocalDay.parse('2026-10-08'));
    final card = find.byKey(const ValueKey('sanctuary-today'));
    expect(
      find.descendant(of: card, matching: find.text(oct8.title(l))),
      findsOneWidget,
    );
    await end(tester);

    // 03:59 IST on 9 Oct is still the Aura day of 8 Oct.
    await pump(tester, now: DateTime.utc(2026, 10, 8, 22, 29));
    expect(
      find.descendant(of: card, matching: find.text(oct8.title(l))),
      findsOneWidget,
    );
    await end(tester);

    // 04:00 IST: a new Aura day, a new minute.
    await pump(tester, now: DateTime.utc(2026, 10, 8, 22, 30));
    final oct9 = todaysMinuteFor(LocalDay.parse('2026-10-09'));
    expect(oct9, isNot(oct8));
    expect(
      find.descendant(of: card, matching: find.text(oct9.title(l))),
      findsOneWidget,
    );
    await end(tester);
  });

  test('Today\'s minute rotates through the whole library, one per day', () {
    final start = LocalDay.parse('2026-10-08');
    final week = {
      for (var i = 0; i < todaysMinutePool.length; i++)
        todaysMinuteFor(start.addDays(i)),
    };
    expect(week, todaysMinutePool.toSet());
    expect(
      todaysMinuteFor(start),
      todaysMinuteFor(start.addDays(todaysMinutePool.length)),
    );
    // Never based on mood: land (Storm's minute) isn't in the rotation.
    expect(todaysMinutePool, isNot(contains(SanctuaryActivity.land)));
  });

  testWidgets('one tap opens an activity full screen; ✕ comes back', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sanctuary-breathe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BreatheSessionScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('breathe-start')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BreatheSessionScreen), findsNothing);

    final senses = find.byKey(const ValueKey('sanctuary-senses'));
    await tester.scrollUntilVisible(senses, 200);
    await tester.ensureVisible(senses);
    await tester.pumpAndSettle();
    await tester.tap(senses);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StepsActivityScreen), findsOneWidget);
    await end(tester);
  });

  testWidgets('cards are one button each, at least 48 dp tall, read as '
      'title and line', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final l = l10n(tester);
    final card = find.byKey(const ValueKey('sanctuary-breathe'));
    expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    final data = tester.getSemantics(
      find.descendant(of: card, matching: find.byType(InkWell)),
    );
    expect(data.label, contains(l.sanctuary_breatheCard));
    expect(data.label, contains(l.sanctuary_breatheCardBody));
    expect(data, isSemantics(isButton: true, hasTapAction: true));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await end(tester);
  });

  group('real fonts', () {
    final roboto = _robotoFiles();
    setUpAll(() async {
      if (roboto == null) return;
      await _load('CupertinoSystemText', roboto);
      await _load('CupertinoSystemDisplay', roboto);
      await _load('NotoSansTelugu', const [
        'assets/fonts/NotoSansTelugu-Regular.ttf',
        'assets/fonts/NotoSansTelugu-Medium.ttf',
        'assets/fonts/NotoSansTelugu-SemiBold.ttf',
      ]);
      await _load('NotoSansDevanagari', const [
        'assets/fonts/NotoSansDevanagari-Regular.ttf',
        'assets/fonts/NotoSansDevanagari-Medium.ttf',
        'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
      ]);
    });

    for (final tag in ['te', 'te-Latn', 'en', 'hi', 'hi-Latn']) {
      testWidgets('$tag at 200% text: every activity lays out (setup, '
          'running, the end), nothing overflows', (tester) async {
        await pump(tester, locale: tag, textScale: 2);
        final context = tester.element(find.byType(SanctuaryScreen));
        for (final a in SanctuaryActivity.values) {
          // Opened from here, as a card would.
          openSanctuaryActivity(context, a);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull, reason: '$tag ${a.name}');
          if (find
              .byKey(const ValueKey('breathe-start'))
              .evaluate()
              .isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('breathe-start')));
            await tester.pump(const Duration(milliseconds: 500));
          }
          if (find
              .byKey(const ValueKey('breathe-finish'))
              .evaluate()
              .isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('breathe-toggle')));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull, reason: '$tag ${a.name}');
            await tester.tap(find.byKey(const ValueKey('breathe-finish')));
            await tester.pump(const Duration(milliseconds: 500));
          }
          while (find
              .byKey(const ValueKey('steps-next'))
              .evaluate()
              .isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('steps-next')));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull, reason: '$tag ${a.name}');
          }
          expect(tester.takeException(), isNull, reason: '$tag ${a.name} end');
          await tester.tap(find.byKey(const ValueKey('activity-close')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        await end(tester);
      }, skip: roboto == null);

      testWidgets('$tag at 200% text: everything lays out, nothing '
          'overflows', (tester) async {
        await pump(tester, locale: tag, textScale: 2);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.byType(CapsulesEntryTile), 300);
        expect(tester.takeException(), isNull);
        await end(tester);
      }, skip: roboto == null); // Roboto not found in the Flutter SDK
    }
  });
}

List<String>? _robotoFiles() {
  final dirs = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    dirs.add('${dir.path}/material_fonts');
    dirs.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final d in dirs) {
    final files = [
      '$d/Roboto-Regular.ttf',
      '$d/Roboto-Medium.ttf',
      '$d/Roboto-Bold.ttf',
    ];
    if (files.every((f) => File(f).existsSync())) return files;
  }
  return null;
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}
