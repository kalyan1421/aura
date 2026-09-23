import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/widgets/help_app_bar.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/account/delete_account_screen.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/history/history_screen.dart';
import 'package:aura/src/features/settings/settings_screen.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// "I need help now" on the secondary screens' top bars ([helpAppBar]):
/// in the 56 dp bar on one line only when it truly fits beside Back and the
/// whole title; otherwise in its own row under the title, never clipped,
/// never overflowing, and always within the first three focus stops
/// (REQ-A11Y-11).
///
/// Drawn with real fonts, not the test font (about twice as wide): Roboto
/// from the Flutter SDK stands in for the phone's system font under the
/// theme's iOS family names, plus the bundled Noto Sans Telugu.

class _Account implements AccountRepository {
  @override
  Future<DateTime> requestDeletion() async => DateTime.utc(2026, 10, 15);
  @override
  Future<DateTime?> scheduledDeletion() async => null;
  @override
  Future<void> cancelDeletion() async {}
}

typedef _Screen = ({
  String name,
  Widget Function() build,
  String Function(AppLocalizations) title,
});

final List<_Screen> _screens = [
  (
    name: 'Settings',
    build: () => const SettingsScreen(),
    title: (l) => l.settings_title,
  ),
  (
    name: 'History',
    build: () => const HistoryScreen(),
    title: (l) => l.history_title,
  ),
  (
    name: 'Check-in',
    build: () => const CheckInDetailScreen(id: 'missing'),
    title: (l) => l.history_entryTitle,
  ),
  (
    name: 'Delete my account',
    build: () => const DeleteAccountScreen(),
    title: (l) => l.acct_deleteTitle,
  ),
];

Future<void> _loadFont(String family, Iterable<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

/// The SDK's Roboto files (from FLUTTER_ROOT, or found above the test
/// runner's own executable inside the SDK cache).
List<String> _robotoFiles() {
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
  throw StateError('Roboto not found in the Flutter SDK cache');
}

void _setSize(WidgetTester tester, Size logical, double scale) {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Opens [screen] on top of a stub page, so it has a Back button.
Future<void> _open(WidgetTester tester, _Screen screen, String tag) async {
  final locale = localeFromTag(tag);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/screen', builder: (_, _) => screen.build()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(db: memoryDb(), locale: tag),
        accountRepositoryProvider.overrideWithValue(_Account()),
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
      ),
    ),
  );
  await settleIo(tester);
  router.push('/screen');
  await settleIo(tester);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The label's paragraph inside the help button (the icon is a RichText
/// too).
RenderParagraph _helpLabel(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: find.byType(HelpNowButton),
          matching: find.byType(Text),
        ),
        matching: find.byType(RichText),
      ),
    );

/// The title's paragraph in the bar.
RenderParagraph _title(WidgetTester tester, String title) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: find.byType(AppBar),
          matching: find.text(title),
        ),
        matching: find.byType(RichText),
      ),
    );

/// Lines the help label takes; every glyph must sit inside the button's
/// visible shape.
int _expectWholeLabel(WidgetTester tester, String reason) {
  final button = find.byType(HelpNowButton);
  final material = find
      .descendant(of: button, matching: find.byType(Material))
      .first;
  final rect = tester.getRect(material);
  final path = tester.widget<Material>(material).shape!.getOuterPath(rect);
  final paragraph = _helpLabel(tester);
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  final text = paragraph.text.toPlainText();
  final lineTops = <int>{};
  var glyphs = 0;
  var offset = 0;
  for (final cluster in text.characters) {
    final start = offset;
    offset += cluster.length;
    if (cluster.trim().isEmpty) continue; // spaces hang past a wrap
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: offset),
    )) {
      final r = box.toRect().deflate(0.5);
      if (r.isEmpty) continue;
      glyphs++;
      lineTops.add(box.top.round());
      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ]) {
        final p = paragraph.localToGlobal(corner);
        expect(
          path.contains(p),
          isTrue,
          reason: '$reason: "$cluster" at $p is outside the button $rect',
        );
      }
    }
  }
  expect(glyphs, greaterThan(0), reason: reason);
  return lineTops.length;
}

enum _Place { bar, below }

/// Checks the bar on the open screen and returns where help is.
_Place _expectHelpBar(
  WidgetTester tester, {
  required String title,
  required String reason,
}) {
  expect(tester.takeException(), isNull, reason: reason);
  final help = find.byType(HelpNowButton);
  expect(help, findsOneWidget, reason: reason);
  final appBar = find.byType(AppBar);
  expect(
    find.descendant(of: appBar, matching: help),
    findsOneWidget,
    reason: reason,
  );

  final inBar = find.byKey(HelpBarLayout.actionKey);
  final below = find.byKey(HelpBarLayout.bottomKey);
  expect(
    inBar.evaluate().length + below.evaluate().length,
    1,
    reason: '$reason: help is either in the bar or under it',
  );

  final bar = tester.getRect(appBar);
  final toolbar = Rect.fromLTWH(bar.left, bar.top, bar.width, kToolbarHeight);
  final target = tester.getRect(
    find.descendant(of: help, matching: find.byType(OutlinedButton)),
  );
  expect(target.height, greaterThanOrEqualTo(48), reason: reason);
  final lines = _expectWholeLabel(tester, reason);
  final titleText = _title(tester, title);

  if (inBar.evaluate().isNotEmpty) {
    // One line, inside the 56 dp row, and the whole title still shows.
    expect(lines, 1, reason: '$reason: one line in the bar');
    expect(toolbar.contains(target.center), isTrue, reason: reason);
    expect(target.top, greaterThanOrEqualTo(toolbar.top - 0.01));
    expect(target.bottom, lessThanOrEqualTo(toolbar.bottom + 0.01));
    expect(
      titleText.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(titleText.size.width + 0.5),
      reason: '$reason: the title is cut short',
    );
    return _Place.bar;
  }

  // Its own row under the title's row, holding the whole button.
  final row = tester.getRect(below);
  expect(row.top, closeTo(toolbar.bottom, 0.01), reason: reason);
  expect(row.bottom, lessThanOrEqualTo(bar.bottom + 0.01), reason: reason);
  for (final corner in [
    target.topLeft,
    target.topRight,
    target.bottomLeft,
    target.bottomRight,
  ]) {
    expect(
      row.inflate(0.01).contains(corner),
      isTrue,
      reason: '$reason: button $target is outside its row $row',
    );
  }
  // End-aligned (directional), not stretched edge to edge.
  expect(target.right, closeTo(row.right - HelpBarLayout.endInset, 0.5));
  expect(target.left, greaterThanOrEqualTo(row.left + 1));
  // Sized for the button: no clipping, no slack beyond the bottom inset.
  expect(
    row.height - target.height,
    inInclusiveRange(
      HelpBarLayout.bottomInset - 0.01,
      HelpBarLayout.bottomInset + 1,
    ),
    reason: '$reason: row ${row.height} for a ${target.height} button',
  );
  // The title keeps its own row.
  final titleRect = tester.getRect(
    find.descendant(of: appBar, matching: find.text(title)),
  );
  expect(toolbar.contains(titleRect.center), isTrue, reason: reason);
  return _Place.below;
}

/// Help is within the first three focus stops, after Back and the title.
void _expectFocusOrder(
  WidgetTester tester, {
  required String title,
  required String reason,
}) {
  final context = tester.element(find.byType(HelpNowButton));
  final l = AppLocalizations.of(context);
  final back = MaterialLocalizations.of(context).backButtonTooltip;
  final order = tester.semantics.simulatedAccessibilityTraversal().toList();
  String label(int i) => order[i].getSemanticsData().label;
  final helpAt = order.indexWhere(
    (n) => n.getSemanticsData().label.contains(l.help_button),
  );
  final titleAt = order.indexWhere((n) => n.getSemanticsData().label == title);
  final backAt = order.indexWhere((n) => n.getSemanticsData().label == back);
  final stops = [for (var i = 0; i < order.length && i < 4; i++) label(i)];
  expect(helpAt, inInclusiveRange(0, 2), reason: '$reason: $stops');
  expect(backAt, 0, reason: '$reason: $stops');
  expect(titleAt, 1, reason: '$reason: $stops');
  expect(helpAt, 2, reason: '$reason: $stops');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final roboto = _robotoFiles();
    // The theme's iOS type families (Typography.material2021 on iOS).
    await _loadFont('CupertinoSystemText', roboto);
    await _loadFont('CupertinoSystemDisplay', roboto);
    await _loadFont(AuraFonts.telugu, [
      'assets/fonts/NotoSansTelugu-Regular.ttf',
      'assets/fonts/NotoSansTelugu-Medium.ttf',
      'assets/fonts/NotoSansTelugu-SemiBold.ttf',
    ]);
  });

  const phone = Size(390, 844);

  for (final screen in _screens) {
    for (final (tag, scale) in const [
      ('en', 1.0),
      ('te-Latn', 1.0),
      ('te', 1.0),
      ('en', 2.0),
      ('te-Latn', 2.0),
      ('te', 2.0),
    ]) {
      testWidgets('${screen.name}, 390 dp, $tag, ${scale}x: help fits where '
          'it sits, whole, first three focus stops', (tester) async {
        _setSize(tester, phone, scale);
        final handle = tester.ensureSemantics();
        await _open(tester, screen, tag);
        final l = AppLocalizations.of(
          tester.element(find.byType(HelpNowButton)),
        );
        final title = screen.title(l);
        final reason = '${screen.name} $tag ${scale}x';
        final place = _expectHelpBar(tester, title: title, reason: reason);
        if (scale >= 2) {
          // On a 390 dp phone, 200% text never shares the bar with Back and
          // the title.
          expect(place, _Place.below, reason: reason);
        }
        if (place == _Place.below && scale == 1) {
          // At 100% the row under the title is wide enough for one line.
          expect(_expectWholeLabel(tester, reason), 1, reason: reason);
        }
        _expectFocusOrder(tester, title: title, reason: reason);
        handle.dispose();
        await _close(tester);
      });
    }
  }

  testWidgets('Settings, en, 1.0x: help stays in the bar on one line', (
    tester,
  ) async {
    _setSize(tester, phone, 1);
    await _open(tester, _screens[0], 'en');
    expect(
      _expectHelpBar(tester, title: 'Settings', reason: 'Settings en'),
      _Place.bar,
    );
    await _close(tester);
  });

  testWidgets('History, te-Latn, 1.0x ("Mee check-ins"): help moves under '
      'the title on one line, no overflow', (tester) async {
    _setSize(tester, phone, 1);
    await _open(tester, _screens[1], 'te-Latn');
    expect(
      _expectHelpBar(tester, title: 'Mee check-ins', reason: 'History te-Latn'),
      _Place.below,
    );
    expect(_expectWholeLabel(tester, 'History te-Latn'), 1);
    expect(find.text('Naaku ippude help kaavali'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('it moves under the title only when the bar is truly too '
      'narrow (History, en, 1.0x, 320–520 dp)', (tester) async {
    _Place? last;
    var sawBelow = false;
    for (var width = 320.0; width <= 520; width += 10) {
      _setSize(tester, Size(width, 844), 1);
      await _open(tester, _screens[1], 'en');
      final reason = 'History en ${width.toInt()} dp';
      final place = _expectHelpBar(
        tester,
        title: 'Your check-ins',
        reason: reason,
      );
      if (place == _Place.below) {
        sawBelow = true;
        // What the bar would need, from the drawn widgets: Back, spacing,
        // the whole title, spacing, the one-line button and its inset.
        final title = _title(tester, 'Your check-ins');
        final button = tester.getSize(
          find
              .descendant(
                of: find.byType(HelpNowButton),
                matching: find.byType(Material),
              )
              .first,
        );
        final need =
            kToolbarHeight +
            2 * NavigationToolbar.kMiddleSpacing +
            title.getMaxIntrinsicWidth(double.infinity) +
            button.width +
            HelpBarLayout.endInset;
        // oneLineWidth keeps ~2 dp of slack for the border and icon gap.
        expect(need, greaterThan(width - 3), reason: reason);
      }
      // Once it fits, it stays in the bar at every wider width.
      if (last == _Place.bar) expect(place, _Place.bar, reason: reason);
      last = place;
      await _close(tester);
    }
    expect(sawBelow, isTrue, reason: 'too narrow at 320 dp');
    expect(last, _Place.bar);
  });
}
