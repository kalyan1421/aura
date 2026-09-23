import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Tag limit hint, reusable custom tags and the saved moment (F1;
/// REQ-A11Y-08 reduced motion; live save status).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
    Future<void> Function(CheckInRepository repo, FixedClock clock)? seed,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = memoryDb();
    if (seed != null) {
      final clock = FixedClock(testNow.subtract(const Duration(hours: 3)));
      final repo = CheckInRepository(
        db,
        OutboxRepository(db, const Ids()),
        TimeContext(clock: clock, timezone: 'Asia/Kolkata'),
      );
      await io(tester, () => seed(repo, clock));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db),
        child: localized(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: const CheckInScreen(),
            ),
          ),
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

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('at the tag limit a calm hint appears instead of ignoring '
      'taps', (tester) async {
    await pump(tester);
    await openDetails(tester, 'calm');
    final hint = find.text('Up to 10 tags');
    expect(hint, findsNothing);

    for (final t in contextTags) {
      await tapVisible(tester, find.byKey(ValueKey('tag-$t')));
    }
    expect(hint, findsOneWidget);
    expect(
      tester.getSemantics(hint),
      isSemantics(isLiveRegion: true, label: 'Up to 10 tags'),
    );

    // An 11th tag is added as a chip but not selected.
    final field = find.byKey(const ValueKey('checkin-custom-tag'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'exams');
    await tapVisible(
      tester,
      find.byKey(const ValueKey('checkin-custom-tag-add')),
    );
    final chip = find.byKey(const ValueKey('tag-exams'));
    expect(chip, findsOneWidget);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    await tapVisible(tester, chip);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);

    // Freeing one lets it in.
    await tapVisible(tester, find.byKey(const ValueKey('tag-work')));
    expect(hint, findsNothing);
    await tapVisible(tester, chip);
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    await done(tester);
  });

  testWidgets('recent custom tags come back as chips (newest first, never '
      'from deleted check-ins); a typed name that exists selects it', (
    tester,
  ) async {
    await pump(
      tester,
      seed: (repo, clock) async {
        const ids = Ids();
        const hour = Duration(hours: 1);
        await repo.save(id: ids.v7(), mood: moodById('calm')!, tags: ['exams']);
        clock.instant = clock.instant.add(hour);
        final gone = ids.v7();
        await repo.save(id: gone, mood: moodById('calm')!, tags: ['secret']);
        await repo.delete(gone);
        clock.instant = clock.instant.add(hour);
        await repo.save(id: ids.v7(), mood: moodById('calm')!, tags: ['gym']);
      },
    );
    await openDetails(tester, 'proud');

    final gym = find.byKey(const ValueKey('tag-gym'));
    final exams = find.byKey(const ValueKey('tag-exams'));
    expect(gym, findsOneWidget);
    expect(exams, findsOneWidget);
    expect(find.byKey(const ValueKey('tag-secret')), findsNothing);
    final a = tester.getTopLeft(gym);
    final b = tester.getTopLeft(exams);
    expect(a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx), isTrue);

    final field = find.byKey(const ValueKey('checkin-custom-tag'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'FAMILY');
    await tapVisible(
      tester,
      find.byKey(const ValueKey('checkin-custom-tag-add')),
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('tag-family')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('tag-FAMILY')), findsNothing);

    // New custom tags stop at 20 characters.
    await tester.enterText(field, 'a' * 30);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('checkin-custom-tag-add')),
    );
    expect(
      find.byKey(ValueKey('tag-${'a' * maxCustomTagLength}')),
      findsOneWidget,
    );
    await done(tester);
  });

  testWidgets('saved moment: help first, no "coming soon" room button, a '
      'live saved line, and the Starlight scale + shimmer', (tester) async {
    await pump(tester);
    await tapVisible(tester, find.byKey(const ValueKey('mood-joyful')));
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    expect(find.byType(HelpNowButton), findsOneWidget);
    expect(find.text('Join a room of people feeling this'), findsNothing);
    expect(find.text('Coming soon'), findsNothing);
    expect(
      tester.getSemantics(find.text('Saved on this phone')),
      isSemantics(isLiveRegion: true),
    );
    final animate = find.ancestor(
      of: find.byKey(const ValueKey('checkin-starlight')),
      matching: find.byType(Animate),
    );
    expect(tester.widget<Animate>(animate).duration.inMilliseconds, 2200);
    expect(
      find.descendant(of: animate, matching: find.byType(ShaderMask)),
      findsOneWidget, // the shimmer
    );
    await done(tester);
  });

  testWidgets('Reduce Motion: Starlight only fades (≤ 300 ms), no scale or '
      'shimmer', (tester) async {
    await pump(tester, reduceMotion: true);
    await tapVisible(tester, find.byKey(const ValueKey('mood-joyful')));
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);

    expect(find.text('+10 Starlight'), findsOneWidget);
    final animate = find.ancestor(
      of: find.byKey(const ValueKey('checkin-starlight')),
      matching: find.byType(Animate),
    );
    expect(
      tester.widget<Animate>(animate).duration,
      lessThanOrEqualTo(const Duration(milliseconds: 300)),
    );
    expect(
      find.descendant(of: animate, matching: find.byType(ShaderMask)),
      findsNothing,
    );
    await done(tester);
  });
}
