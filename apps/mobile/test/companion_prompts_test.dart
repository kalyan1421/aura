import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/companion/prompts.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Guided prompts (competitor plan #12, REQ-CHK-05): an optional, rotating
/// hint in empty private-writing fields; never saved.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final te = lookupAppLocalizations(const Locale('te'));

  group('promptFor', () {
    test('quadrant-aware pools of equal size; general ones before a mood', () {
      for (final q in Quadrant.values) {
        expect(
          promptPool(en, PromptSurface.checkInNote, quadrant: q),
          hasLength(3),
          reason: q.name,
        );
        expect(
          promptPool(en, PromptSurface.capsule, quadrant: q),
          hasLength(4),
          reason: q.name,
        );
      }
      expect(promptPool(en, PromptSurface.checkInNote), hasLength(3));
      expect(promptPool(en, PromptSurface.capsule), hasLength(3));
      expect(
        promptFor(en, surface: PromptSurface.checkInNote, seed: 0),
        "What's one small thing that helped today?",
      );
    });

    test('the same seed gives the same prompt; "Another" rotates through the '
        'pool and wraps', () {
      String p(int turn) => promptFor(
        en,
        surface: PromptSurface.checkInNote,
        quadrant: Quadrant.rain,
        seed: promptSeed('draft-1'),
        turn: turn,
      );
      expect(p(0), p(0));
      expect({p(0), p(1), p(2)}, hasLength(3));
      expect(p(3), p(0));
      expect(
        promptPool(en, PromptSurface.checkInNote, quadrant: Quadrant.rain),
        containsAll([p(0), p(1), p(2)]),
      );
    });

    test(
      'capsules get the target feeling\'s prompt among the general ones',
      () {
        final pool = promptPool(
          en,
          PromptSurface.capsule,
          quadrant: Quadrant.storm,
        );
        expect(pool.first, 'What helps when everything feels like too much?');
        expect(pool.skip(1), promptPool(en, PromptSurface.capsule));
      },
    );

    test('localized, and never a "why" in any language pool', () {
      for (final surface in PromptSurface.values) {
        for (final q in [null, ...Quadrant.values]) {
          final pe = promptPool(en, surface, quadrant: q);
          final pt = promptPool(te, surface, quadrant: q);
          for (var i = 0; i < pe.length; i++) {
            expect(pt[i], isNot(pe[i]));
            expect(
              RegExp(r'\bwhy\b', caseSensitive: false).hasMatch(pe[i]),
              isFalse,
              reason: pe[i],
            );
          }
        }
      }
    });

    test('promptSeed is stable and never negative', () {
      expect(
        promptSeed('019a0000-0000-7000-8000-000000000000'),
        promptSeed('019a0000-0000-7000-8000-000000000000'),
      );
      expect(promptSeed(''), greaterThanOrEqualTo(0));
      expect(promptSeed('a'), isNot(promptSeed('b')));
    });
  });

  group('in the check-in note', () {
    Future<void> pump(
      WidgetTester tester,
      AppDatabase db, {
      String locale = 'en',
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: db, locale: locale),
          child: localized(
            const CheckInScreen(),
            locale: localeFromTag(locale),
          ),
        ),
      );
      await settleIo(tester);
    }

    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> openDetails(WidgetTester tester, String mood) async {
      await tapVisible(tester, find.byKey(ValueKey('mood-$mood')));
      await tapVisible(tester, find.text('Add a tag or a few words'));
    }

    InputDecoration decoration(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('checkin-note')))
        .decoration!;

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the empty note shows the quadrant\'s prompt as a hint; '
        '"Another prompt" rotates it; typing hides it', (tester) async {
      await pump(tester, memoryDb());
      await openDetails(tester, 'lonely'); // Rain
      final rain = promptPool(
        en,
        PromptSurface.checkInNote,
        quadrant: Quadrant.rain,
      );
      final first = decoration(tester).hintText;
      expect(rain, contains(first));
      expect(
        decoration(tester).floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      expect(find.text(first!), findsOneWidget); // visible, not only focused

      await tapVisible(
        tester,
        find.byKey(const ValueKey('checkin-prompt-another')),
      );
      final second = decoration(tester).hintText;
      expect(second, isNot(first));
      expect(rain, contains(second));

      final note = find.byKey(const ValueKey('checkin-note'));
      await tester.enterText(note, 'a slow evening');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('checkin-prompt-another')),
        findsNothing,
      );
      // The hint fades out once there is text (InputDecorator keeps it in
      // the tree, invisible).
      final hint = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text(second!),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(hint.opacity, 0);
      await end(tester);
    });

    testWidgets('the prompt is never saved: an empty note stays empty', (
      tester,
    ) async {
      final db = memoryDb();
      await pump(tester, db);
      await openDetails(tester, 'calm');
      expect(decoration(tester).hintText, isNotNull);
      // The saved moment animates (the avatar): pump, don't settle.
      await tester.tap(find.byKey(const ValueKey('checkin-save')));
      await settleIo(tester);
      final row = (await io(tester, () => db.select(db.checkIns).get())).single;
      expect(row.note, isNull);
      final m = (await io(tester, () => db.select(db.outbox).get())).single;
      expect(m.needsNote, isFalse);
      await end(tester);
    });

    testWidgets('switched off (Settings): no hint, no "Another prompt"', (
      tester,
    ) async {
      final db = memoryDb();
      await io(tester, () => KvStore(db).set(guidedPromptsOffKey, 'true'));
      await pump(tester, db);
      await openDetails(tester, 'joyful');
      expect(decoration(tester).hintText, isNull);
      expect(
        find.byKey(const ValueKey('checkin-prompt-another')),
        findsNothing,
      );
      await end(tester);
    });

    testWidgets('Telugu: the prompt is in Telugu', (tester) async {
      await pump(tester, memoryDb(), locale: 'te');
      await tapVisible(tester, find.byKey(const ValueKey('mood-calm')));
      await tapVisible(tester, find.byIcon(Icons.add_rounded).first);
      final hint = decoration(tester).hintText!;
      expect(
        promptPool(te, PromptSurface.checkInNote, quadrant: Quadrant.moonlight),
        contains(hint),
      );
      await end(tester);
    });
  });
}
