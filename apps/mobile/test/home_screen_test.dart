import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/prefs/comfort_prefs.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/sync_service.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'shell_helpers.dart';

/// Home as the app shell's first tab (the other tabs, check-in and
/// settings are stand-ins; see shell_helpers.dart).
Widget _app(List<Override> overrides) =>
    shellTestApp(overrides, router: shellTestRouter());

/// The top of the app shell's navigation bar: Home's fold.
double _navTop(WidgetTester tester) =>
    tester.getRect(find.byKey(AuraNavBar.barKey)).top;

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _checkIn(WidgetTester tester, AppDatabase db) => io(
  tester,
  () => CheckInRepository(
    db,
    OutboxRepository(db, const Ids()),
    testTime(),
  ).save(id: const Ids().v7(), mood: moodById('calm')!),
);

ProgressView _view({
  AuraStage stage = AuraStage.spark,
  int total = 15,
  int today = 15,
  int stars = 0,
  bool hasActivity = true,
  StreakState streak = const StreakState(
    glowStreak: 3,
    lifetimeGlowDays: 5,
    restBank: 2,
  ),
  GlowStatus glow = GlowStatus.activeToday,
}) => ProgressView(
  loaded: true,
  today: const LocalDay(2026, 10, 8),
  avatar: AuraAvatarState(stage: stage, constellationStars: stars),
  todayStarlight: today,
  totalStarlight: total,
  streak: streak,
  glow: glow,
  provisional: false,
  hasActivity: hasActivity,
  awards: const {},
  localHue: null,
);

class _Held extends DeletionHold {
  @override
  DeletionPending? build() => const DeletionPending(userId: 'u1');
}

class _HiddenStreak extends ComfortController {
  @override
  ComfortPrefs build() => const ComfortPrefs(hideStreak: true);
}

/// Counts "Sync now" (an immediate push that skips retry backoff).
class _KickSync extends FakeSync {
  int get kicks => syncNowCalls;

  void setPhase(SyncPhase p) => (phase as ValueNotifier<SyncPhase>).value = p;
}

class _SignedIn implements AuthRepository {
  static const _user = AuthUser(id: 'u1');

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(_user);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The avatar animates forever, so `pumpAndSettle` never settles: pump
/// long enough for a sheet to open or close.
Future<void> _sheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('layout (item 1)', () {
    test('the avatar gets what the content below leaves of the viewport, '
        'within its floor and 340', () {
      // Room to spare: all of it goes to the avatar.
      expect(homeAvatarHeight(viewport: 625, below: 436), 189);
      expect(homeAvatarHeight(viewport: 640, below: 436), 204);
      // Not enough: the floor holds and Home scrolls.
      expect(homeAvatarHeight(viewport: 500, below: 436), homeAvatarFloor);
      expect(
        homeAvatarHeight(
          viewport: 521,
          below: 436,
          floor: homeAvatarFloorCompact,
        ),
        homeAvatarFloorCompact,
      );
      // Tall screens: never past the cap.
      expect(homeAvatarHeight(viewport: 2000, below: 436), homeAvatarMax);
      expect(homeAvatarMax, 340);
    });

    testWidgets('when everything fits, the avatar takes exactly the rest: '
        'the last habit row ends at the navigation bar', (tester) async {
      // Wide enough for the (wide) test font's chips to fit, short enough
      // that the avatar stays under its cap.
      _setSize(tester, const Size(800, 800));
      final db = memoryDb();
      await _checkIn(tester, db);
      await tester.pumpWidget(_app(testOverrides(db: db)));
      await settleIo(tester);
      expect(tester.takeException(), isNull);

      final fold = tester.getRect(find.byType(ListView)).bottom;
      expect(fold, closeTo(_navTop(tester), 0.01));
      final last = tester.getRect(
        find.byKey(ValueKey('habit-${presetHabits.last.key}')),
      );
      expect(last.bottom, closeTo(fold, 0.01));
      final avatar = tester.getSize(find.byKey(const ValueKey('home-avatar')));
      expect(avatar.height, greaterThan(homeAvatarFloor));
      expect(avatar.height, lessThan(homeAvatarMax));
      await _close(tester);
    });

    for (final size in const [Size(375, 667), Size(390, 844)]) {
      testWidgets(
        'no overflow at ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
          _setSize(tester, size);
          final db = memoryDb();
          await _checkIn(tester, db);
          await tester.pumpWidget(_app(testOverrides(db: db)));
          await settleIo(tester);

          expect(tester.takeException(), isNull);
          final avatar = tester.getSize(
            find.byKey(const ValueKey('home-avatar')),
          );
          expect(avatar.height, inInclusiveRange(140, 340));
          await _close(tester);
        },
      );
    }

    // With the test font (twice as wide as a phone's) the chips need more
    // rows than on a phone, so here the guarantee is the first row. Every
    // row with real fonts and safe areas: test/home_fit_test.dart.
    for (final (size, minAvatar) in const [
      (Size(375, 667), homeAvatarFloorCompact),
      (Size(390, 844), homeAvatarFloor),
    ]) {
      final name = '${size.width.toInt()}×${size.height.toInt()}';
      for (final newUser in [false, true]) {
        testWidgets('$name${newUser ? ' (new user)' : ''}: stats row, glow '
            'card and the whole first habit row sit above the navigation bar '
            'without scrolling', (tester) async {
          _setSize(tester, size);
          final db = memoryDb();
          if (!newUser) await _checkIn(tester, db);
          await tester.pumpWidget(_app(testOverrides(db: db)));
          await settleIo(tester);
          expect(tester.takeException(), isNull);

          final fold = tester.getRect(find.byType(ListView)).bottom;
          expect(fold, lessThanOrEqualTo(_navTop(tester)));
          final keys = [
            'home-stage-progress',
            if (!newUser) 'home-glow-card',
            'habits-edit',
            // Every chip in the first row, not just the first one.
            for (final p in presetHabits)
              if (tester.getRect(find.byKey(ValueKey('habit-${p.key}'))).top ==
                  tester
                      .getRect(find.byKey(const ValueKey('habit-hydrate')))
                      .top)
                'habit-${p.key}',
          ];
          expect(keys, contains('habit-hydrate'));
          for (final key in keys) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.bottom, lessThanOrEqualTo(fold), reason: key);
          }
          // The avatar stays the hero: never under its floor.
          final avatar = tester.getSize(
            find.byKey(const ValueKey('home-avatar')),
          );
          expect(avatar.height, greaterThanOrEqualTo(minAvatar));
          await _close(tester);
        });
      }
    }

    for (final size in const [Size(375, 667), Size(390, 844)]) {
      testWidgets('200% text at ${size.width.toInt()}×${size.height.toInt()}: '
          'nothing overflows and Home still scrolls to the habits', (
        tester,
      ) async {
        _setSize(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = memoryDb();
        await _checkIn(tester, db);
        await tester.pumpWidget(_app(testOverrides(db: db)));
        await settleIo(tester);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('habit-go_outside')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _close(tester);
      });
    }

    testWidgets('the decorative wordmark shows when "I need help now" fits '
        'beside it, steps aside first when it would not, and help never '
        'wraps (the heart only when even the pill alone does not fit)', (
      tester,
    ) async {
      final wordmark = find.byKey(const ValueKey('home-wordmark'));
      final heart = find.byKey(HelpNowButton.iconOnlyKey);
      // Wide enough for both on one line (the test font is wide).
      _setSize(tester, const Size(700, 900));
      await tester.pumpWidget(_app(testOverrides(db: memoryDb())));
      await settleIo(tester);
      expect(wordmark, findsOneWidget);
      expect(find.text('I need help now'), findsOneWidget);
      await _close(tester);

      // Room for the pill but not the wordmark too: the wordmark goes.
      _setSize(tester, const Size(420, 900));
      await tester.pumpWidget(_app(testOverrides(db: memoryDb())));
      await settleIo(tester);
      expect(wordmark, findsNothing);
      expect(find.text('I need help now'), findsOneWidget);
      expect(heart, findsNothing);
      await _close(tester);

      // Not even the pill alone: the heart, never a wrapped label.
      _setSize(tester, const Size(320, 667));
      await tester.pumpWidget(_app(testOverrides(db: memoryDb())));
      await settleIo(tester);
      expect(find.text('I need help now'), findsNothing);
      expect(heart, findsOneWidget);
      await _close(tester);
    });
  });

  group('Starlight row (item 2)', () {
    test('progress toward the next stage uses the domain thresholds', () {
      final p = stageProgressFor(AuraStage.spark, 15)!;
      expect(p.next, AuraStage.ember);
      expect(p.next.threshold, AuraStage.ember.threshold);
      expect(p.fraction, closeTo(15 / AuraStage.ember.threshold, 1e-9));
      // The shown stage can be ahead of the local total: clamped, never < 0.
      expect(stageProgressFor(AuraStage.glow, 120)!.fraction, 0);
      expect(stageProgressFor(AuraStage.constellation, 5000), isNull);
    });

    testWidgets('day one: stage name, quiet bar toward Ember, today\'s '
        'Starlight; no repeated total', (tester) async {
      _setSize(tester, const Size(390, 844));
      final semantics = tester.ensureSemantics();
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db),
          progressViewProvider.overrideWithValue(_view()),
        ]),
      );
      await settleIo(tester);

      expect(find.text('Spark'), findsOneWidget);
      expect(find.text('Ember'), findsOneWidget);
      expect(find.text('15 Starlight today'), findsOneWidget);
      expect(find.text('15 in all'), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('home-stage-progress')),
      );
      expect(bar.value, closeTo(0.15, 1e-9));
      expect(
        find.bySemanticsLabel(
          RegExp('Spark, 15 of 100 Starlight toward Ember'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
      await _close(tester);
    });

    testWidgets('Constellation shows its stars instead of a bar', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final semantics = tester.ensureSemantics();
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db),
          progressViewProvider.overrideWithValue(
            _view(stage: AuraStage.constellation, total: 4200, stars: 2),
          ),
        ]),
      );
      await settleIo(tester);

      expect(find.byKey(const ValueKey('home-stage-progress')), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(10));
      expect(
        find.bySemanticsLabel(RegExp('Constellation, 2 of 12 stars')),
        findsOneWidget,
      );
      semantics.dispose();
      await _close(tester);
    });
  });

  group('glow card (item 3)', () {
    testWidgets('star icon, not fire; the rest-day row explains rest days', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db),
          progressViewProvider.overrideWithValue(_view()),
        ]),
      );
      await settleIo(tester);

      expect(find.byIcon(Icons.local_fire_department_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-glow-card')),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Glow streak · 3 days'), findsOneWidget);
      final row = find.byKey(const ValueKey('home-rest-days'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));

      await tester.tap(row);
      await _sheet(tester);
      expect(find.text('Rest days'), findsOneWidget);
      expect(
        find.text('Every 4 glow days earn a rest day. You can keep up to 3.'),
        findsOneWidget,
      );
      expect(
        find.text("Every glow day you've had stays with you."),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('rest-close')));
      await _sheet(tester);
      expect(find.text('Rest days'), findsNothing);
      await _close(tester);
    });

    testWidgets('Hide streak number keeps glow days and rest days', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db),
          progressViewProvider.overrideWithValue(_view()),
          comfortControllerProvider.overrideWith(_HiddenStreak.new),
        ]),
      );
      await settleIo(tester);

      expect(find.textContaining('Glow streak'), findsNothing);
      expect(find.text('Your glow'), findsOneWidget);
      expect(find.text('5 glow days in all'), findsOneWidget);
      expect(find.text('2 rest days saved'), findsOneWidget);
      await _close(tester);
    });
  });

  group('history line (item 4)', () {
    testWidgets('"Your check-ins" when none today; opens the Insights tab '
        '(the history)', (tester) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(_app(testOverrides(db: db)));
      await settleIo(tester);

      final line = find.byKey(const ValueKey('home-history'));
      expect(find.text('Your check-ins'), findsOneWidget);
      expect(tester.getSize(line).height, greaterThanOrEqualTo(48));
      await tester.tap(line);
      await settleIo(tester);
      expect(find.text('insights-page'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(AuraNavBar.tabKey(ShellTab.insights))),
        isSemantics(isSelected: true, hasSelectedState: true),
      );
      await _close(tester);
    });

    testWidgets('counts today\'s check-ins', (tester) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await _checkIn(tester, db);
      await _checkIn(tester, db);
      await tester.pumpWidget(_app(testOverrides(db: db)));
      await settleIo(tester);

      expect(find.text('2 check-ins today'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      await _close(tester);
    });
  });

  group('sync indicator (item 7)', () {
    testWidgets('signed in and online: state, explanation and Sync now', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      final sync = _KickSync()..setPhase(SyncPhase.idle);
      await tester.pumpWidget(
        _app(testOverrides(db: db, sync: sync, auth: _SignedIn())),
      );
      await settleIo(tester);

      final indicator = find.byKey(const ValueKey('home-sync'));
      expect(tester.getSize(indicator).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(indicator).height, greaterThanOrEqualTo(48));
      await tester.tap(indicator);
      await _sheet(tester);

      expect(find.byKey(const ValueKey('sync-sheet-status')), findsOneWidget);
      expect(
        find.text('Everything is saved on this phone and in your account.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sync-now')));
      await tester.pump();
      expect(sync.kicks, 1);

      sync.setPhase(SyncPhase.syncing);
      await tester.pump();
      expect(find.text('Syncing…'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('sync-now')),
      );
      expect(button.onPressed, isNull);
      await _close(tester);
    });

    testWidgets('offline: "Saved on this phone", no Sync now', (tester) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(_app(testOverrides(db: db))); // phase offline
      await settleIo(tester);

      await tester.tap(find.byKey(const ValueKey('home-sync')));
      await _sheet(tester);
      expect(find.text('Saved on this phone'), findsWidgets);
      expect(
        find.text(
          "You're offline. Everything is safe on this phone and syncs "
          "when you're back online.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sync-now')), findsNothing);
      await _close(tester);
    });
  });

  group('account deletion hold', () {
    testWidgets('a scheduled deletion shows "Keep my account?" on Home', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db, auth: _SignedIn()),
          deletionHoldProvider.overrideWith(_Held.new),
        ]),
      );
      await settleIo(tester);
      expect(find.byKey(const ValueKey('acct-pending-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('no hold: no card', (tester) async {
      _setSize(tester, const Size(390, 844));
      final db = memoryDb();
      await tester.pumpWidget(_app(testOverrides(db: db)));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('acct-pending-card')), findsNothing);
      await _close(tester);
    });
  });

  group("check-in entry (item 8): the shell's centre action, not a bar on "
      'Home', () {
    testWidgets('Home has no check-in bar of its own', (tester) async {
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(_app(testOverrides(db: memoryDb())));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('home-checkin')), findsNothing);
      expect(find.byKey(AuraNavBar.checkInKey), findsOneWidget);
      await tester.tap(find.byKey(AuraNavBar.checkInKey));
      await settleIo(tester);
      expect(find.text('checkin-page'), findsOneWidget);
      await _close(tester);
    });

    Future<bool> pulses(WidgetTester tester, {required bool reduce}) async {
      _setSize(tester, const Size(390, 844));
      if (reduce) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final db = memoryDb();
      await tester.pumpWidget(
        _app([
          ...testOverrides(db: db),
          progressViewProvider.overrideWithValue(
            _view(hasActivity: false, total: 0, today: 0),
          ),
        ]),
      );
      await settleIo(tester);
      final animated = find
          .descendant(
            of: find.byKey(AuraNavBar.checkInKey),
            matching: find.byType(Animate),
          )
          .evaluate()
          .isNotEmpty;
      await _close(tester);
      return animated;
    }

    testWidgets('the new-user check-in pulse plays normally', (tester) async {
      expect(await pulses(tester, reduce: false), isTrue);
    });

    testWidgets('no pulse under Reduce Motion', (tester) async {
      expect(await pulses(tester, reduce: true), isFalse);
    });
  });
}
