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
/// always in the 56 dp bar, never wrapping and never moving to a row of its
/// own. The labelled pill (one line, whole label) while it fits beside Back
/// and the title (which may shrink a little first); otherwise, and always
/// above 130% text, the heart-only button with the label kept for screen
/// readers. Always within the first three focus stops (REQ-A11Y-11).
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

enum _Mode { pill, heart, titleBelow }

/// Checks the bar on the open screen and returns how help is shown.
_Mode _expectHelpBar(
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
  // Always in the bar's actions: there is no row under the title any more.
  expect(find.byKey(HelpBarLayout.actionKey), findsOneWidget, reason: reason);

  final bar = tester.getRect(appBar);
  final toolbar = Rect.fromLTWH(bar.left, bar.top, bar.width, kToolbarHeight);
  final titleRect = tester.getRect(find.byKey(HelpBarLayout.titleKey));
  // A large title sits under the toolbar; otherwise the bar is one row.
  final below = titleRect.top >= toolbar.bottom - 0.5;
  if (!below) {
    expect(bar.height, closeTo(kToolbarHeight, 0.01), reason: reason);
  }
  final target = tester.getRect(
    find.descendant(of: help, matching: find.byType(OutlinedButton)),
  );
  expect(target.height, greaterThanOrEqualTo(48), reason: reason);
  expect(target.width, greaterThanOrEqualTo(48), reason: reason);
  expect(toolbar.contains(target.center), isTrue, reason: reason);
  expect(target.top, greaterThanOrEqualTo(toolbar.top - 0.01));
  expect(target.bottom, lessThanOrEqualTo(toolbar.bottom + 0.01));

  final titleText = _title(tester, title);
  if (below) {
    // Large title: under the bar, whole (never cut), help keeps its words.
    expect(titleText.didExceedMaxLines, isFalse, reason: '$reason: cut');
    expect(titleRect.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
    expect(_expectWholeLabel(tester, reason), 1, reason: '$reason: one line');
    return _Mode.titleBelow;
  }
  // The title: one line, in the bar, left of help.
  expect(titleText.maxLines, 1, reason: reason);
  expect(toolbar.contains(titleRect.center), isTrue, reason: reason);
  expect(titleRect.right, lessThanOrEqualTo(target.left + 0.5));

  final heart = find.descendant(
    of: help,
    matching: find.byKey(HelpNowButton.iconOnlyKey),
  );
  if (heart.evaluate().isNotEmpty) {
    // Heart only: the words live in the tooltip and the screen-reader label.
    final l = AppLocalizations.of(tester.element(help));
    expect(
      find.descendant(of: help, matching: find.byType(Tooltip)),
      findsOneWidget,
      reason: reason,
    );
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(of: help, matching: find.byType(Tooltip)),
          )
          .message,
      l.help_button,
    );
    expect(
      tester.getSemantics(help).label,
      contains(l.help_button),
      reason: reason,
    );
    return _Mode.heart;
  }
  // The pill: its whole label on one line, and the whole title shows.
  expect(_expectWholeLabel(tester, reason), 1, reason: '$reason: one line');
  expect(
    titleText.didExceedMaxLines,
    isFalse,
    reason: '$reason: the title is cut short beside the full pill',
  );
  return _Mode.pill;
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
    await _loadFont(AuraFonts.devanagari, const [
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
      'assets/fonts/NotoSansDevanagari-Medium.ttf',
      'assets/fonts/NotoSansDevanagari-SemiBold.ttf',
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
      ('hi', 2.0),
      ('hi-Latn', 2.0),
    ]) {
      testWidgets('${screen.name}, 390 dp, $tag, ${scale}x: help stays in '
          'the bar, never wraps, first three focus stops', (tester) async {
        _setSize(tester, phone, scale);
        final handle = tester.ensureSemantics();
        await _open(tester, screen, tag);
        final l = AppLocalizations.of(
          tester.element(find.byType(HelpNowButton)),
        );
        final title = screen.title(l);
        final reason = '${screen.name} $tag ${scale}x';
        final mode = _expectHelpBar(tester, title: title, reason: reason);
        if (scale >= 2) {
          // Above 130% text help is always the heart-only button.
          expect(mode, _Mode.heart, reason: reason);
        }
        _expectFocusOrder(tester, title: title, reason: reason);
        handle.dispose();
        await _close(tester);
      });
    }
  }

  testWidgets('Settings, en, 1.0x: the labelled pill in the bar', (
    tester,
  ) async {
    _setSize(tester, phone, 1);
    await _open(tester, _screens[0], 'en');
    expect(
      _expectHelpBar(tester, title: 'Settings', reason: 'Settings en'),
      _Mode.pill,
    );
    await _close(tester);
  });

  testWidgets('History, te-Latn, 1.0x ("Mee check-ins"): still one row, '
      'no overflow, help never wraps', (tester) async {
    _setSize(tester, phone, 1);
    await _open(tester, _screens[1], 'te-Latn');
    _expectHelpBar(tester, title: 'Mee check-ins', reason: 'History te-Latn');
    expect(find.byKey(HelpBarLayout.actionKey), findsOneWidget);
    await _close(tester);
  });

  testWidgets('at normal text, help never loses its words: a title that '
      "doesn't fit moves under the bar (History, en, 1.0x, 320–560 dp)", (
    tester,
  ) async {
    _Mode? last;
    var sawBelow = false;
    for (var width = 320.0; width <= 560; width += 10) {
      _setSize(tester, Size(width, 844), 1);
      await _open(tester, _screens[1], 'en');
      final reason = 'History en ${width.toInt()} dp';
      final mode = _expectHelpBar(
        tester,
        title: 'Your check-ins',
        reason: reason,
      );
      expect(mode, isNot(_Mode.heart), reason: reason);
      if (mode == _Mode.titleBelow) sawBelow = true;
      // Once the title fits in the bar, it stays there at every wider width.
      if (last == _Mode.pill) expect(mode, _Mode.pill, reason: reason);
      last = mode;
      await _close(tester);
    }
    expect(sawBelow, isTrue, reason: 'too narrow for both at 320 dp');
    expect(last, _Mode.pill);
  });
}
