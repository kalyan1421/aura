import 'dart:math' as math;

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'shell_helpers.dart';

/// The app shell (AK, 23 Sep 2026): Home · Sanctuary · [Check in] · Rooms ·
/// Insights. Four peer destinations with icon + label + container, a
/// distinct centre Check in action, per-tab state, 48 dp targets, screen
/// reader semantics, 200% text and Reduce Motion.

void _phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Future<void> _saveCheckIn(WidgetTester tester, AppDatabase db) => io(
  tester,
  () => CheckInRepository(
    db,
    OutboxRepository(db, const Ids()),
    testTime(),
  ).save(id: const Ids().v7(), mood: moodById('calm')!),
);

/// The shell with stand-in tabs (Home too, unless [realHome]).
Future<GoRouter> _pump(
  WidgetTester tester, {
  AppDatabase? db,
  String tag = 'en',
  String at = Routes.home,
  bool realHome = false,
}) async {
  final router = shellTestRouter(
    initialLocation: at,
    home: realHome ? null : const StubTab('home'),
  );
  await tester.pumpWidget(
    shellTestApp(
      testOverrides(db: db ?? memoryDb(), locale: tag),
      router: router,
      tag: tag,
    ),
  );
  await settleIo(tester);
  return router;
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _tab(ShellTab tab) => find.byKey(AuraNavBar.tabKey(tab));
final Finder _checkIn = find.byKey(AuraNavBar.checkInKey);
final Finder _bar = find.byKey(AuraNavBar.barKey);

/// The icon shown in [tab]'s slot.
IconData? _iconOf(WidgetTester tester, ShellTab tab) => tester
    .widget<Icon>(find.descendant(of: _tab(tab), matching: find.byType(Icon)))
    .icon;

/// The container behind [tab]'s icon.
BoxDecoration _containerOf(WidgetTester tester, ShellTab tab) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: _tab(tab),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

ScrollPosition _scrollOf(WidgetTester tester, String name) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey('$name-list'), skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
      ),
    )
    .position;

void main() {
  group('five positions, localized', () {
    for (final (tag, labels) in const [
      ('en', ['Home', 'Sanctuary', 'Check in', 'Rooms', 'Insights']),
      ('te', ['హోమ్', 'ప్రశాంత నిలయం', 'చెక్-ఇన్', 'రూమ్‌లు', 'అవగాహన']),
      ('te-Latn', ['Home', 'Sanctuary', 'Check in', 'Rooms', 'Insights']),
    ]) {
      testWidgets('$tag: Home · Sanctuary · [Check in] · Rooms · Insights', (
        tester,
      ) async {
        _phone(tester);
        await _pump(tester, tag: tag);
        final slots = [
          _tab(ShellTab.home),
          _tab(ShellTab.sanctuary),
          _checkIn,
          _tab(ShellTab.rooms),
          _tab(ShellTab.insights),
        ];
        final lefts = [for (final s in slots) tester.getRect(s).left];
        expect(lefts, orderedEquals([...lefts]..sort()));
        for (final (i, label) in labels.indexed) {
          expect(
            find.descendant(of: slots[i], matching: find.text(label)),
            findsOneWidget,
            reason: '$tag slot $i',
          );
        }
        expect(tester.takeException(), isNull);
        await _end(tester);
      });
    }
  });

  testWidgets('semantics: destinations are selectable buttons with their '
      'place; Check in is a button that is never selected', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(_tab(ShellTab.home)),
      isSemantics(
        label: 'Home',
        hint: 'Tab 1 of 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_tab(ShellTab.insights)),
      isSemantics(
        label: 'Insights',
        hint: 'Tab 4 of 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_checkIn),
      isSemantics(
        label: 'Check in',
        hint: 'Starts a new check-in',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );

    // A screen-reader double tap switches tabs.
    tester.semantics.tap(find.semantics.byLabel('Rooms'));
    await tester.pumpAndSettle();
    expect(find.text('rooms-page'), findsOneWidget);
    expect(
      tester.getSemantics(_tab(ShellTab.rooms)),
      isSemantics(
        label: 'Rooms',
        hint: 'Tab 3 of 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
    await _end(tester);
  });

  testWidgets('the active tab shows by icon, container and label weight, '
      'not colour alone', (tester) async {
    _phone(tester);
    await _pump(tester);

    expect(_iconOf(tester, ShellTab.home), Icons.home_rounded);
    expect(_iconOf(tester, ShellTab.sanctuary), Icons.spa_outlined);
    expect(_containerOf(tester, ShellTab.home).border, isNotNull);
    expect(
      (_containerOf(tester, ShellTab.home).border! as Border).top.color.a,
      greaterThan(0.5),
    );
    expect(
      (_containerOf(tester, ShellTab.sanctuary).border! as Border).top.color.a,
      0,
    );
    FontWeight? weight(ShellTab t) => tester
        .widget<Text>(find.descendant(of: _tab(t), matching: find.byType(Text)))
        .style
        ?.fontWeight;
    expect(weight(ShellTab.home), FontWeight.w700);
    expect(weight(ShellTab.sanctuary), FontWeight.w500);

    await tester.tap(_tab(ShellTab.sanctuary));
    await tester.pumpAndSettle();
    expect(find.text('sanctuary-page'), findsOneWidget);
    expect(_iconOf(tester, ShellTab.sanctuary), Icons.spa_rounded);
    expect(_iconOf(tester, ShellTab.home), Icons.home_outlined);
    expect(weight(ShellTab.sanctuary), FontWeight.w700);

    // The Check in orb is a filled circle: unlike any destination.
    final orb = tester.widget<Container>(
      find.byKey(const ValueKey('shell-checkin-orb')),
    );
    expect((orb.decoration! as BoxDecoration).shape, BoxShape.circle);
    await _end(tester);
  });

  testWidgets('every item is a 48 dp target with a label', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await _pump(tester);
    for (final slot in [
      _tab(ShellTab.home),
      _tab(ShellTab.sanctuary),
      _checkIn,
      _tab(ShellTab.rooms),
      _tab(ShellTab.insights),
    ]) {
      final size = tester.getSize(slot);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await _end(tester);
  });

  testWidgets('each tab keeps its own scroll position and state', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);

    await tester.drag(
      find.byKey(const ValueKey('home-list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final home = _scrollOf(tester, 'home').pixels;
    expect(home, greaterThan(0));

    await tester.tap(_tab(ShellTab.sanctuary));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('sanctuary-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final sanctuary = _scrollOf(tester, 'sanctuary').pixels;
    expect(sanctuary, greaterThan(home));

    await tester.tap(_tab(ShellTab.home));
    await tester.pumpAndSettle();
    expect(_scrollOf(tester, 'home').pixels, home);
    await tester.tap(_tab(ShellTab.sanctuary));
    await tester.pumpAndSettle();
    expect(_scrollOf(tester, 'sanctuary').pixels, sanctuary);
    await _end(tester);
  });

  testWidgets('tapping the open tab again returns it to its first screen', (
    tester,
  ) async {
    _phone(tester);
    final router = await _pump(tester, at: Routes.rooms);
    router.push('${Routes.rooms}/more');
    await tester.pumpAndSettle();
    expect(find.text('rooms-more-page'), findsOneWidget);
    expect(_bar, findsOneWidget); // inside the tab: the bar stays

    await tester.tap(_tab(ShellTab.home));
    await tester.pumpAndSettle();
    await tester.tap(_tab(ShellTab.rooms));
    await tester.pumpAndSettle();
    // Switching back keeps where the tab was...
    expect(find.text('rooms-more-page'), findsOneWidget);
    // ...and tapping it again goes to its first screen.
    await tester.tap(_tab(ShellTab.rooms));
    await tester.pumpAndSettle();
    expect(find.text('rooms-page'), findsOneWidget);
    expect(find.text('rooms-more-page'), findsNothing);
    await _end(tester);
  });

  testWidgets('Check in opens the full-screen check-in above the shell and '
      'comes back to the tab it came from', (tester) async {
    _phone(tester);
    await _pump(tester, at: Routes.rooms);

    await tester.tap(_checkIn);
    await tester.pumpAndSettle();
    expect(find.text('checkin-page'), findsOneWidget);
    // Above the shell: the bar is covered.
    expect(_bar.hitTestable(), findsNothing);

    // Never a second one on top.
    openCheckIn(tester.element(find.byType(AppShell, skipOffstage: false)));
    await tester.pumpAndSettle();
    expect(find.text('checkin-page'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('checkin-done')));
    await tester.pumpAndSettle();
    expect(find.text('checkin-page'), findsNothing);
    expect(find.text('rooms-page'), findsOneWidget);
    expect(
      tester.getSemantics(_tab(ShellTab.rooms)),
      isSemantics(isSelected: true, hasSelectedState: true),
    );
    await _end(tester);
  });

  testWidgets('system back on another tab goes to Home', (tester) async {
    _phone(tester);
    await _pump(tester, at: Routes.insights);
    expect(find.text('insights-page'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Settings opens from the Home top bar, never a tab', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, realHome: true);
    expect(
      find.descendant(of: _bar, matching: find.textContaining('Settings')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester);
    expect(find.text('settings-page'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('ShellSettingsButton and isShellTabRoot for other tab roots', (
    tester,
  ) async {
    _phone(tester);
    final roots = <bool>[];
    final router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(shell: shell),
          branches: [
            for (final path in [
              Routes.home,
              Routes.sanctuary,
              Routes.rooms,
              Routes.insights,
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, _) => Scaffold(
                      appBar: AppBar(actions: const [ShellSettingsButton()]),
                      body: Builder(
                        builder: (context) {
                          roots.add(isShellTabRoot(context));
                          return const Text('tab');
                        },
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => Builder(
            builder: (context) {
              roots.add(isShellTabRoot(context));
              return const StubPage('settings');
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      shellTestApp(testOverrides(db: memoryDb()), router: router),
    );
    await settleIo(tester);
    expect(roots.last, isTrue);
    await tester.tap(find.byKey(const ValueKey('shell-settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings-page'), findsOneWidget);
    expect(roots.last, isFalse);
    await _end(tester);
  });

  group('first-run pulse on Check in', () {
    Finder pulse() =>
        find.descendant(of: _checkIn, matching: find.byType(Animate));

    testWidgets('a new user: it pulses once, and not again on tab changes', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester);
      expect(pulse(), findsOneWidget);
      final orb = find.byKey(const ValueKey('shell-checkin-orb'));
      final rest = tester.getSize(orb).width; // layout size: unscaled
      Future<List<double>> sample(Duration total) async {
        final widths = <double>[];
        for (
          var t = Duration.zero;
          t < total;
          t += const Duration(milliseconds: 50)
        ) {
          await tester.pump(const Duration(milliseconds: 50));
          widths.add(tester.getRect(orb).width); // painted: scaled
        }
        return widths;
      }

      final first = await sample(const Duration(milliseconds: 2500));
      expect(first.reduce(math.max), greaterThan(rest + 2)); // it pulsed
      expect(first.last, closeTo(rest, 0.01)); // and settled back

      await tester.tap(_tab(ShellTab.sanctuary));
      final again = await sample(const Duration(milliseconds: 2500));
      expect(again.reduce(math.max), closeTo(rest, 0.01)); // once only
      await _end(tester);
    });

    testWidgets('after a check-in: no pulse', (tester) async {
      _phone(tester);
      final db = memoryDb();
      await _saveCheckIn(tester, db);
      await _pump(tester, db: db);
      expect(pulse(), findsNothing);
      await _end(tester);
    });

    testWidgets('Reduce Motion: no pulse, and the tab container changes '
        'without animating', (tester) async {
      _phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester);
      expect(pulse(), findsNothing);
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: _tab(ShellTab.home),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(container.duration, Duration.zero);
      await _end(tester);
    });
  });

  group('200% text (real fonts): nothing overflows, labels stay whole and '
      'break only between words, targets stay 48 dp', () {
    setUpAll(loadRealFonts);

    for (final width in const [390.0, 320.0]) {
      for (final tag in const ['en', 'te', 'te-Latn', 'hi', 'hi-Latn']) {
        testWidgets('${width.toInt()} dp, $tag', (tester) async {
          _phone(tester, Size(width, 844));
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(tester, tag: tag);
          expect(tester.takeException(), isNull);

          final bar = tester.getRect(_bar);
          for (final slot in [
            _tab(ShellTab.home),
            _tab(ShellTab.sanctuary),
            _checkIn,
            _tab(ShellTab.rooms),
            _tab(ShellTab.insights),
          ]) {
            final rect = tester.getRect(slot);
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(bar.contains(rect.center), isTrue);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: slot, matching: find.byType(RichText)).last,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final text = paragraph.text.toPlainText();
            // Each word on one line, inside its slot.
            var offset = 0;
            for (final word in text.split(' ')) {
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: offset,
                  extentOffset: offset + word.length,
                ),
              );
              offset += word.length + 1;
              expect(
                {for (final b in boxes) b.top.round()},
                hasLength(1),
                reason: '"$word" in "$text" is broken across lines',
              );
              for (final b in boxes) {
                final r = b.toRect();
                final topLeft = paragraph.localToGlobal(r.topLeft);
                final bottomRight = paragraph.localToGlobal(r.bottomRight);
                expect(topLeft.dx, greaterThanOrEqualTo(rect.left - 0.5));
                expect(bottomRight.dx, lessThanOrEqualTo(rect.right + 0.5));
                expect(bottomRight.dy, lessThanOrEqualTo(bar.bottom + 0.5));
              }
            }
          }
          await _end(tester);
        });
      }
    }
  });
}
