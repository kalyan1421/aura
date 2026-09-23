import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/companion/companion_lines.dart';
import 'package:aura/src/features/companion/companion_response.dart';
import 'package:aura/src/features/companion/prompts.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The companion response after a live check-in (PRD 06d, REQ-CMP-01…03).
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final te = lookupAppLocalizations(const Locale('te'));
  final teLatn = lookupAppLocalizations(localeFromTag('te-Latn'));

  List<String> allKeys() => [
    for (final q in Quadrant.values) ...CompanionLines.keys(q),
    ...CompanionLines.keys(null),
  ];

  group('the pools', () {
    test('equal for every quadrant: 8 lines each, plus 4 neutral ones', () {
      for (final q in Quadrant.values) {
        expect(CompanionLines.keys(q), hasLength(8), reason: q.name);
        expect(CompanionLines.perQuadrant, 8);
      }
      expect(CompanionLines.keys(null), hasLength(4));
      final texts = [for (final k in allKeys()) CompanionLines.text(en, k)];
      expect(texts.toSet(), hasLength(texts.length), reason: 'all distinct');
    });

    test(
      'every line is in Telugu and Tenglish (never an English fallback)',
      () {
        for (final k in allKeys()) {
          final e = CompanionLines.text(en, k);
          expect(CompanionLines.text(te, k), isNot(e), reason: k);
          expect(CompanionLines.text(te, k), matches(RegExp('[ఀ-౿]')));
          expect(CompanionLines.text(teLatn, k), isNot(e), reason: k);
        }
      },
    );

    test('copy rules: no advice, diagnosis, cheerleading, "why" or '
        'promises, and never a separate friend talking (REQ-CMP-03)', () {
      final banned = RegExp(
        r"\b(should|try|trying|calm down|cheer up|anxiety|depressed|"
        r"depression|disorder|because|why|will be fine|it'll be|don't worry|"
        r"must|need to|have to)\b",
        caseSensitive: false,
      );
      final firstPerson = RegExp(r"\b(I|I'm|I've|me|my|we|us)\b");
      for (final k in allKeys()) {
        final line = CompanionLines.text(en, k);
        expect(banned.hasMatch(line), isFalse, reason: '$k: $line');
        expect(firstPerson.hasMatch(line), isFalse, reason: '$k: $line');
        expect(line.contains('!'), isFalse, reason: '$k: $line');
      }
    });

    test('equal warmth: lines of every quadrant are of similar length', () {
      double mean(Quadrant q) {
        final lines = [
          for (final k in CompanionLines.keys(q)) CompanionLines.text(en, k),
        ];
        return lines.map((s) => s.length).reduce((a, b) => a + b) /
            lines.length;
      }

      final means = [for (final q in Quadrant.values) mean(q)];
      final spread =
          means.reduce((a, b) => a > b ? a : b) -
          means.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(8), reason: '$means');
    });
  });

  group('the pick', () {
    test('the same check-in always gets the same line, from its quadrant', () {
      for (final q in Quadrant.values) {
        final a = pickCompanionLine(
          quadrant: q,
          afterCrisis: false,
          seed: promptSeed('check-in-1'),
        );
        final b = pickCompanionLine(
          quadrant: q,
          afterCrisis: false,
          seed: promptSeed('check-in-1'),
        );
        expect(a, b);
        expect(CompanionLines.keys(q), contains(a));
      }
    });

    test('never one of the last 5 shown', () {
      final recent = <String>[];
      for (var i = 0; i < 40; i++) {
        final k = pickCompanionLine(
          quadrant: Quadrant.rain,
          afterCrisis: false,
          seed: promptSeed('c$i'),
          recent: recent,
        );
        expect(recent.take(5), isNot(contains(k)), reason: 'round $i');
        recent.insert(0, k);
      }
    });

    test('after a crisis sheet: the neutral pool, whatever the quadrant, '
        'and not the line shown last', () {
      for (final q in Quadrant.values) {
        final k = pickCompanionLine(
          quadrant: q,
          afterCrisis: true,
          seed: 7,
          recent: const ['neutral1', 'neutral2', 'neutral3', 'neutral4'],
        );
        expect(CompanionLines.keys(null), contains(k));
        expect(k, isNot('neutral1'));
      }
    });

    testWidgets('CompanionMemory keeps the last 5 lines on this phone', (
      tester,
    ) async {
      final db = memoryDb();
      final memory = CompanionMemory(KvStore(db));
      final shown = <String>[];
      for (var i = 0; i < 7; i++) {
        shown.add(
          await io(
            tester,
            () => memory.pickFor(
              checkInId: 'id-$i',
              quadrant: Quadrant.sunrise,
              afterCrisis: false,
            ),
          ),
        );
      }
      for (var i = 1; i < shown.length; i++) {
        final window = shown.sublist(i - (i < 5 ? i : 5), i);
        expect(window, isNot(contains(shown[i])), reason: '$shown');
      }
      final raw = await io(
        tester,
        () => KvStore(db).get('companion.recent_lines'),
      );
      final kept = (jsonDecode(raw!) as List<dynamic>).cast<String>();
      expect(kept, shown.reversed.take(5).toList());
    });
  });

  group('the reaction', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: Center(child: child),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('≤ 2 s, the same for every quadrant; only the tint differs '
        '(REQ-CMP-01)', (tester) async {
      final durations = <Duration>{};
      final shapes = <String>{};
      for (final q in Quadrant.values) {
        await pump(
          tester,
          CompanionReaction(
            quadrant: q,
            child: const SizedBox.square(dimension: 200),
          ),
        );
        final animate = tester.widget<Animate>(
          find.byKey(const ValueKey('companion-reaction')),
        );
        expect(animate.duration, lessThanOrEqualTo(const Duration(seconds: 2)));
        expect(animate.duration, CompanionReaction.total);
        durations.add(animate.duration);
        final glow = tester.widget<Animate>(
          find.byKey(const ValueKey('companion-glow')),
        );
        expect(glow.duration, lessThanOrEqualTo(const Duration(seconds: 2)));
        shapes.add('${animate.duration}/${glow.duration}');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('companion-reaction')),
            matching: find.byType(ShaderMask),
          ),
          findsOneWidget,
          reason: 'the shimmer',
        );
        await end(tester);
      }
      expect(durations, hasLength(1));
      expect(shapes, hasLength(1));
    });

    testWidgets('Reduce Motion: nothing moves at all; the line crossfades in '
        'within 300 ms (REQ-CMP-02)', (tester) async {
      await pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompanionReaction(
              quadrant: Quadrant.storm,
              child: SizedBox.square(dimension: 200),
            ),
            CompanionLine('A line'),
          ],
        ),
        reduceMotion: true,
      );
      expect(find.byKey(const ValueKey('companion-reaction')), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      final line = tester.widget<Animate>(
        find.ancestor(
          of: find.byKey(const ValueKey('companion-line')),
          matching: find.byType(Animate),
        ),
      );
      expect(
        line.duration,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      await end(tester);
    });

    testWidgets('the line is announced once to screen readers (a live '
        'region)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const CompanionLine('Rain is part of your sky too.'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getSemantics(find.text('Rain is part of your sky too.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
      await end(tester);
    });
  });

  test('AppLocalizations lookup covers the alpha locales', () {
    expect(en.companion_storm1, isNotEmpty);
    expect(
      AppLocalizations.supportedLocales.map(tagFromLocale),
      containsAll(['en', 'te', 'te-Latn']),
    );
  });
}
