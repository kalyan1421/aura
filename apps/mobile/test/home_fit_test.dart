import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/habits/habit_repository.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'shell_helpers.dart';

/// Home's fold (the top of the app shell's navigation bar) with real fonts
/// instead of the (twice as wide) test font:
/// the theme's iOS typography names `CupertinoSystemText` /
/// `CupertinoSystemDisplay`, which on a phone resolve to the system font.
/// Here they are SF Pro (macOS's SFNS.ttf, the iPhone's font; its weight
/// axis follows FontWeight) or, off macOS, Roboto from the Flutter SDK.
/// Phones carry their real safe areas.
///
/// Print the measured avatar sizes and habit rows:
///   AURA_HOME_FIT=1 flutter test test/home_fit_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sf = ['/System/Library/Fonts/SFNS.ttf'];
  final sdkFonts =
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts';
  final roboto = [
    '$sdkFonts/Roboto-Regular.ttf',
    '$sdkFonts/Roboto-Medium.ttf',
    '$sdkFonts/Roboto-Bold.ttf',
  ];
  bool present(List<String> paths) => paths.every((p) => File(p).existsSync());
  final system = present(sf)
      ? sf
      : present(roboto)
      ? roboto
      : null;
  final fontName = system == sf ? 'SF Pro' : 'Roboto';
  // Without either font (neither macOS nor a Flutter SDK checkout) the test
  // font would be measured instead, which says nothing about a phone.
  final skip = system == null;
  final report = Platform.environment['AURA_HOME_FIT'] == '1';

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  setUpAll(() async {
    if (system == null) return;
    await load('CupertinoSystemText', system);
    await load('CupertinoSystemDisplay', system);
    // The theme's fallbacks for Indic scripts.
    await load(AuraFonts.telugu, const [
      'assets/fonts/NotoSansTelugu-Regular.ttf',
      'assets/fonts/NotoSansTelugu-Medium.ttf',
      'assets/fonts/NotoSansTelugu-SemiBold.ttf',
    ]);
    await load(AuraFonts.devanagari, const [
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
      'assets/fonts/NotoSansDevanagari-Medium.ttf',
      'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
    ]);
  });

  /// Home as the first tab of the real app shell (other tabs stubbed).
  Widget app(String tag, List<Override> overrides) =>
      shellTestApp(overrides, router: shellTestRouter(), tag: tag);

  /// [phone] in logical pixels with its status bar / home indicator insets.
  void setPhone(WidgetTester tester, _Phone phone) {
    const ratio = 3.0;
    tester.view.physicalSize = phone.size * ratio;
    tester.view.devicePixelRatio = ratio;
    final insets = FakeViewPadding(
      top: phone.top * ratio,
      bottom: phone.bottom * ratio,
    );
    tester.view.padding = insets;
    tester.view.viewPadding = insets;
    addTearDown(tester.view.reset);
  }

  Future<void> checkIn(WidgetTester tester, AppDatabase db) => io(
    tester,
    () => CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    ).save(id: const Ids().v7(), mood: moodById('calm')!),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  /// Every preset chip's rect, in order.
  List<Rect> chips(WidgetTester tester) => [
    for (final p in presetHabits) rectOf(tester, 'habit-${p.key}'),
  ];

  int rowsOf(List<Rect> rects) => {for (final r in rects) r.top}.length;

  /// The bottom of Home's scroll viewport: the navigation bar starts here.
  double foldOf(WidgetTester tester) =>
      tester.getRect(find.byType(ListView)).bottom;

  /// The top of the app shell's navigation bar.
  double navTop(WidgetTester tester) =>
      tester.getRect(find.byKey(AuraNavBar.barKey)).top;

  const common = [
    _Phone('iPhone 14 · 390×844', Size(390, 844), top: 47, bottom: 34),
    _Phone('iPhone 16 · 393×852', Size(393, 852), top: 59, bottom: 34),
    _Phone('iPhone 16 Pro · 402×874', Size(402, 874), top: 62, bottom: 34),
  ];
  const se = _Phone('iPhone SE · 375×667', Size(375, 667), top: 20, bottom: 0);

  group('common phones, 1.0 text: every habit chip above the navigation bar '
      'without scrolling, avatar ≥ $homeAvatarFloor', () {
    for (final phone in common) {
      for (final tag in const ['en', 'te-Latn']) {
        for (final newUser in const [true, false]) {
          final who = newUser ? 'new user' : 'after a check-in';
          testWidgets('${phone.name}, $tag, $who', (tester) async {
            setPhone(tester, phone);
            final db = memoryDb();
            if (!newUser) await checkIn(tester, db);
            await tester.pumpWidget(
              app(tag, testOverrides(db: db, locale: tag)),
            );
            await settleIo(tester);
            expect(tester.takeException(), isNull);

            final fold = foldOf(tester);
            expect(fold, lessThanOrEqualTo(navTop(tester)));
            expect(
              find.byKey(const ValueKey('home-glow-card')),
              newUser ? findsNothing : findsOneWidget,
            );

            final rects = chips(tester);
            // The six presets wrap (three rows at these widths: the
            // simulator's "Kadalika · Shwaasa · Diary" is the second).
            expect(rowsOf(rects), greaterThanOrEqualTo(2));
            for (final (i, r) in rects.indexed) {
              final key = 'habit-${presetHabits[i].key}';
              // The whole chip, 48 dp tap target included (its margins are
              // what keep the rows of pills apart).
              expect(r.height, greaterThanOrEqualTo(48), reason: key);
              expect(
                r.bottom,
                lessThanOrEqualTo(fold + precisionErrorTolerance),
                reason: '$key ($fontName)',
              );
            }
            for (final key in [
              'home-stage-progress',
              'home-history',
              if (!newUser) 'home-glow-card',
              'habits-edit',
            ]) {
              expect(rectOf(tester, key).bottom, lessThanOrEqualTo(fold));
            }

            // No scrolling needed to see them: Home is at rest.
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            expect(scroll.position.pixels, 0);

            final avatar = rectOf(tester, 'home-avatar');
            expect(avatar.height, greaterThanOrEqualTo(homeAvatarFloor));
            expect(avatar.height, lessThanOrEqualTo(homeAvatarMax));
            if (report) {
              // ignore: avoid_print
              print(
                '${phone.name} $tag $who [$fontName]: avatar '
                '${avatar.width.toStringAsFixed(1)}×'
                '${avatar.height.toStringAsFixed(1)}, '
                '${rowsOf(rects)} habit rows, last row ends '
                '${(fold - rects.last.bottom).toStringAsFixed(1)} dp above '
                'the fold',
              );
            }
            await close(tester);
          }, skip: skip);
        }
      }
    }

    testWidgets('Reduce Motion lays Home out the same', (tester) async {
      const phone = _Phone(
        'iPhone 16 Pro · 402×874',
        Size(402, 874),
        top: 62,
        bottom: 34,
      );
      Future<(Rect, Rect)> measure({required bool reduce}) async {
        setPhone(tester, phone);
        if (reduce) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
        }
        final db = memoryDb();
        await checkIn(tester, db);
        await tester.pumpWidget(
          app('te-Latn', testOverrides(db: db, locale: 'te-Latn')),
        );
        await settleIo(tester);
        expect(tester.takeException(), isNull);
        final result = (
          rectOf(tester, 'home-avatar'),
          rectOf(tester, 'habit-${presetHabits.last.key}'),
        );
        expect(
          result.$2.bottom,
          lessThanOrEqualTo(foldOf(tester) + precisionErrorTolerance),
        );
        await close(tester);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        return result;
      }

      final normal = await measure(reduce: false);
      final reduced = await measure(reduce: true);
      expect(reduced, normal);
    }, skip: skip);
  });

  group('iPhone SE (375×667), 1.0 text', () {
    for (final tag in const ['en', 'te-Latn']) {
      for (final newUser in const [true, false]) {
        final who = newUser ? 'new user' : 'after a check-in';
        testWidgets('$tag, $who: the whole first habit row is above the '
            'navigation bar', (tester) async {
          setPhone(tester, se);
          final db = memoryDb();
          if (!newUser) await checkIn(tester, db);
          await tester.pumpWidget(app(tag, testOverrides(db: db, locale: tag)));
          await settleIo(tester);
          expect(tester.takeException(), isNull);

          final fold = foldOf(tester);
          final rects = chips(tester);
          final firstRow = rects.where((r) => r.top == rects.first.top);
          expect(firstRow, isNotEmpty);
          for (final r in firstRow) {
            expect(r.bottom, lessThanOrEqualTo(fold + precisionErrorTolerance));
          }
          final avatar = rectOf(tester, 'home-avatar');
          expect(avatar.height, greaterThanOrEqualTo(homeAvatarFloorCompact));
          if (report) {
            // ignore: avoid_print
            print(
              '${se.name} $tag $who [$fontName]: avatar '
              '${avatar.width.toStringAsFixed(1)}×'
              '${avatar.height.toStringAsFixed(1)}, ${rowsOf(rects)} habit '
              'rows, last row ${rects.last.bottom <= fold ? 'visible' : 'below the fold'}',
            );
          }
          await close(tester);
        }, skip: skip);
      }
    }
  });

  group('200% text: nothing overflows, Home scrolls to the last habit', () {
    for (final phone in [se, ...common]) {
      for (final tag in const ['en', 'te-Latn']) {
        testWidgets('${phone.name}, $tag', (tester) async {
          setPhone(tester, phone);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final db = memoryDb();
          await checkIn(tester, db);
          await tester.pumpWidget(app(tag, testOverrides(db: db, locale: tag)));
          await settleIo(tester);
          expect(tester.takeException(), isNull);

          final avatar = rectOf(tester, 'home-avatar');
          expect(
            avatar.height,
            greaterThanOrEqualTo(
              phone.size.height < 700
                  ? homeAvatarFloorCompact
                  : homeAvatarFloor,
            ),
          );
          final last = find.byKey(ValueKey('habit-${presetHabits.last.key}'));
          await tester.scrollUntilVisible(
            last,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(foldOf(tester) + precisionErrorTolerance),
          );
          await close(tester);
        }, skip: skip);
      }
    }
  });

  group('when everything cannot fit, the avatar keeps its floor and Home '
      'scrolls', () {
    testWidgets('custom habits (more chip rows)', (tester) async {
      setPhone(tester, common.first);
      final db = memoryDb();
      await checkIn(tester, db);
      await io(tester, () async {
        final habits = HabitRepository(
          db,
          OutboxRepository(db, const Ids()),
          testTime(),
          const Ids(),
        );
        for (final name in ['Stretch', 'Read a page', 'Call home']) {
          await habits.addCustom(name);
        }
      });
      await tester.pumpWidget(app('en', testOverrides(db: db)));
      await settleIo(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Call home'), findsOneWidget);

      final avatar = rectOf(tester, 'home-avatar');
      expect(avatar.height, greaterThanOrEqualTo(homeAvatarFloor));
      // The first row still shows at rest; the rest is a scroll away.
      final rects = chips(tester);
      expect(
        rects.first.bottom,
        lessThanOrEqualTo(foldOf(tester) + precisionErrorTolerance),
      );
      final last = find.text('Call home');
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await close(tester);
    }, skip: skip);

    testWidgets('the deletion-pending card above the avatar', (tester) async {
      setPhone(tester, common.first);
      final db = memoryDb();
      await checkIn(tester, db);
      await tester.pumpWidget(
        app('en', [
          ...testOverrides(db: db),
          deletionHoldProvider.overrideWith(_Held.new),
        ]),
      );
      await settleIo(tester);
      expect(tester.takeException(), isNull);
      final card = rectOf(tester, 'acct-pending-card');
      final avatar = rectOf(tester, 'home-avatar');
      expect(card.bottom, lessThanOrEqualTo(avatar.top));
      expect(avatar.height, greaterThanOrEqualTo(homeAvatarFloor));
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('habit-${presetHabits.last.key}')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await close(tester);
    }, skip: skip);
  });
}

class _Phone {
  const _Phone(this.name, this.size, {required this.top, required this.bottom});

  final String name;
  final Size size;

  /// Safe-area insets (status bar / Dynamic Island, home indicator).
  final double top;
  final double bottom;
}

class _Held extends DeletionHold {
  @override
  DeletionPending? build() => const DeletionPending(userId: 'u1');
}
