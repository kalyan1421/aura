import 'dart:io';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

/// Real fonts instead of the (about twice as wide) test font: Roboto from
/// the Flutter SDK under the theme's iOS family names, plus the bundled
/// Noto Sans Telugu (as test/help_app_bar_test.dart does).
Future<void> loadRealFonts() async {
  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final roboto = _robotoFiles();
  await load('CupertinoSystemText', roboto);
  await load('CupertinoSystemDisplay', roboto);
  await load(AuraFonts.telugu, const [
    'assets/fonts/NotoSansTelugu-Regular.ttf',
    'assets/fonts/NotoSansTelugu-Medium.ttf',
    'assets/fonts/NotoSansTelugu-SemiBold.ttf',
  ]);
}

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

/// A tab's stand-in: a long list (to check that each tab keeps its scroll
/// position) with its own name at the top.
class StubTab extends StatelessWidget {
  const StubTab(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView.builder(
        key: ValueKey('$name-list'),
        itemCount: 60,
        itemBuilder: (context, i) => SizedBox(
          height: 64,
          child: Text(i == 0 ? '$name-page' : '$name row $i'),
        ),
      ),
    ),
  );
}

/// A full-screen stand-in above the shell (check-in, settings) with a
/// text field that keeps what was typed, a Done that pops and "I need help
/// now" style access to the Safety Center.
class StubPage extends StatelessWidget {
  const StubPage(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Text('$name-page'),
          TextField(key: ValueKey('$name-field')),
          TextButton(
            key: ValueKey('$name-done'),
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

/// The real [AppShell] with the real [HomeScreen] (unless [home] replaces
/// it), stand-ins for the other tabs, and the real Safety Center above the
/// shell.
GoRouter shellTestRouter({
  String initialLocation = Routes.home,
  Widget? home,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, _) => home ?? const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.sanctuary,
              builder: (_, _) => const StubTab('sanctuary'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.rooms,
              builder: (_, _) => const StubTab('rooms'),
              routes: [
                GoRoute(
                  path: 'more',
                  builder: (_, _) => const StubPage('rooms-more'),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.insights,
              builder: (_, _) => const StubTab('insights'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: Routes.checkIn, builder: (_, _) => const StubPage('checkin')),
    GoRoute(
      path: Routes.settings,
      builder: (_, _) => const StubPage('settings'),
    ),
    GoRoute(path: Routes.safety, builder: (_, _) => const SafetyCenterScreen()),
  ],
);

/// [router] in a localized app ([tag] is an Aura locale tag).
Widget shellTestApp(
  List<Override> overrides, {
  required GoRouter router,
  String tag = 'en',
}) {
  final locale = localeFromTag(tag);
  return ProviderScope(
    overrides: overrides,
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
  );
}
