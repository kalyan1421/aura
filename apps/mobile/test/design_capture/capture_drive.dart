// Driving the app for the design captures: boot the real app over a
// [World], navigate, tap, scroll and pump without waiting for animations
// that never end.
import 'package:aura/src/app.dart';
import 'package:aura/src/core/entitlements/entitlement.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/avatar/avatar_assets.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'capture_harness.dart';
import 'capture_world.dart';

/// Real avatar art and shaders, loaded once (setUpAll).
late AvatarAssets captureAssets;

/// The fonts in use (for INDEX.md).
String captureFonts = '';

/// An onboarded, signed-in person with the real avatar art.
World world({
  String locale = 'en',
  GateState gate = const GateState(stage: OnboardingStage.done),
  bool checkedIn = true,
  Entitlement? entitlement,
  RemoteFlags flags = const RemoteFlags(),
  ProgressView? progress,
  bool sharePrompt = false,
  bool plusEnabled = true,
}) => World(
  plusEnabled: plusEnabled,
  locale: locale,
  gate: gate,
  assets: captureAssets,
  entitlement: entitlement,
  flags: flags,
  sharePrompt: sharePrompt,
  progress: progress ?? homeProgress(checkedIn: checkedIn),
);

// ---- driving the app ---------------------------------------------------------------

/// Pumps [frames] frames [step] apart (the avatar, orbs and pulses animate
/// forever, so nothing ever "settles").
Future<void> frames(
  WidgetTester tester, {
  int frames = 6,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Real async work (Drift, files) and a few frames.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  await settleIo(tester, rounds: rounds);
  await frames(tester, frames: 4);
}

/// The whole app (router, shell, theme) over [w]'s providers.
Future<ProviderContainer> boot(
  WidgetTester tester,
  World w, {
  Future<void> Function(World w)? seed,
}) async {
  if (seed != null) await tester.runAsync(() => seed(w));
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureRootKey,
      child: ProviderScope(overrides: w.overrides(), child: const AuraApp()),
    ),
  );
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(AuraApp)));
}

Future<void> go(
  WidgetTester tester,
  ProviderContainer c,
  String location, {
  Object? extra,
}) async {
  c.read(routerProvider).go(location, extra: extra);
  await settle(tester);
  await frames(tester, frames: 5);
}

Future<void> push(
  WidgetTester tester,
  ProviderContainer c,
  String location, {
  Object? extra,
}) async {
  // Not awaited: completes when the page is popped.
  c.read(routerProvider).push<void>(location, extra: extra);
  await settle(tester);
  await frames(tester, frames: 5);
}

/// Pushes [screen] on the root navigator (screens opened with a Navigator
/// route rather than a URL).
Future<void> pushScreen(
  WidgetTester tester,
  ProviderContainer c,
  Widget screen,
) async {
  final nav = c.read(routerProvider).routerDelegate.navigatorKey.currentState!;
  // Not awaited: completes when the page is popped.
  nav.push(MaterialPageRoute<void>(builder: (_) => screen));
  await settle(tester);
  await frames(tester, frames: 5);
}

/// The root navigator's context (to open sheets and dialogs).
BuildContext rootContext(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.navigatorKey.currentContext!;

Future<void> tapKey(WidgetTester tester, String key, {bool settleIo = false}) =>
    tapFinder(tester, find.byKey(ValueKey(key)), settleIo: settleIo);

Future<void> tapFinder(
  WidgetTester tester,
  Finder f, {
  bool settleIo = false,
}) async {
  await tester.ensureVisible(f.first);
  await frames(tester, frames: 3);
  await tester.tap(f.first);
  if (settleIo) {
    await settle(tester);
  }
  await frames(tester, frames: 6);
}

/// The screen's main list: the largest on-stage (hit-testable), vertically
/// scrolling Scrollable of the top route (other tabs and the routes below
/// stay in the tree).
Finder mainScrollable(WidgetTester tester) {
  final candidates = find.byType(Scrollable).hitTestable();
  Element? best;
  var area = -1.0;
  for (final e in candidates.evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final a = box.size.width * box.size.height;
    if (a > area) {
      area = a;
      best = e;
    }
  }
  if (best == null) return find.byType(Scrollable).first;
  final chosen = best;
  return find.byElementPredicate((e) => identical(e, chosen));
}

/// Scrolls the main (or [scrollable]) list by [dy] logical pixels.
Future<void> scrollBy(
  WidgetTester tester,
  double dy, {
  Finder? scrollable,
}) async {
  final s = scrollable ?? mainScrollable(tester);
  final state = tester.state<ScrollableState>(s);
  final pos = state.position;
  pos.jumpTo((pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent));
  await frames(tester, frames: 4);
}

Future<void> scrollToEnd(WidgetTester tester, {Finder? scrollable}) async {
  final s = scrollable ?? mainScrollable(tester);
  final pos = tester.state<ScrollableState>(s).position;
  pos.jumpTo(pos.maxScrollExtent);
  await frames(tester, frames: 4);
}

/// Scrolls until [f] is on screen (from the top of the list if it isn't
/// built yet). Returns false when the list has no such item.
Future<bool> reveal(WidgetTester tester, Finder f, {Finder? scrollable}) async {
  if (f.evaluate().isEmpty) {
    final s = scrollable ?? mainScrollable(tester);
    final pos = tester.state<ScrollableState>(s).position;
    pos.jumpTo(pos.minScrollExtent);
    await frames(tester, frames: 2);
    while (f.evaluate().isEmpty && pos.pixels < pos.maxScrollExtent) {
      pos.jumpTo((pos.pixels + 250).clamp(0, pos.maxScrollExtent));
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (f.evaluate().isEmpty) return false;
  }
  await tester.ensureVisible(f.first);
  await frames(tester, frames: 4);
  return true;
}
