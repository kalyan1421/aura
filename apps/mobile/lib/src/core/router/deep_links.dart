import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/gate_controller.dart';
import 'routes.dart';

/// `aura://` links: `aura://checkin`, `aura://safety`, `aura://sanctuary`
/// (notifications, widgets, shortcuts). The platform hands them to the
/// router (Flutter deep linking): at launch as the first location, while
/// running as a new one.
///
/// They respect the gate: the under-13 lock and onboarding win (the link
/// then does nothing: the gate already shows where the person is), except
/// the Safety Center, which opens in every state. Check-in and Safety open
/// above whatever is showing, so closing them returns there; a tab link
/// switches tabs, but never replaces a screen that may hold unsaved input.
///
/// `aura://auth-callback` belongs to Supabase (it finishes a magic-link
/// sign-in itself): the router never navigates for it.
abstract final class DeepLinks {
  static const String scheme = 'aura';
  static const String authCallbackHost = 'auth-callback';

  /// Link host → in-app location.
  static const Map<String, String> targets = {
    'checkin': Routes.checkIn,
    'safety': Routes.safety,
    'sanctuary': Routes.sanctuary,
  };

  /// Opened above the current screen rather than instead of it.
  static const Set<String> overlays = {Routes.checkIn, Routes.safety};

  /// Screens a `go` must not replace (typed or picked, not yet saved).
  static bool mayHoldInput(String location) =>
      location == Routes.checkIn ||
      location == Routes.onboardingSignIn ||
      location == Routes.signIn ||
      location.startsWith('${Routes.history}/');

  static bool isAppLink(Uri uri) => uri.scheme == scheme;

  static String _name(Uri uri) =>
      (uri.host.isNotEmpty
              ? uri.host
              : uri.pathSegments.isEmpty
              ? ''
              : uri.pathSegments.first)
          .toLowerCase();

  static bool isAuthCallback(Uri uri) =>
      isAppLink(uri) && _name(uri) == authCallbackHost;

  /// The location an `aura://` link opens (`aura://safety` or
  /// `aura:///safety`), or null for any other link.
  static String? targetOf(Uri uri) =>
      isAppLink(uri) ? targets[_name(uri)] : null;
}

/// What a deep link does now.
enum DeepLinkAction { none, push, go }

/// Decides what opening [target] does, given the [gate] and the locations
/// currently stacked on screen ([stack], bottom to top). Pure.
DeepLinkAction deepLinkAction(
  GateState gate,
  String target,
  List<String> stack,
) {
  // Not reachable in this gate state: the gate already shows the right
  // screen (the lock, or the current onboarding step).
  if (gateRedirect(gate, target) != null) return DeepLinkAction.none;
  if (DeepLinks.overlays.contains(target)) {
    return stack.contains(target) ? DeepLinkAction.none : DeepLinkAction.push;
  }
  final top = stack.isEmpty ? null : stack.last;
  if (top == target) return DeepLinkAction.none;
  if (top != null && DeepLinks.mayHoldInput(top)) return DeepLinkAction.none;
  return DeepLinkAction.go;
}

/// The locations on screen, bottom to top (a shell counts its open tab).
List<String> stackLocations(RouteMatchList list) => [
  for (final match in list.matches) ..._locationsOf(match),
];

List<String> _locationsOf(RouteMatchBase match) => switch (match) {
  ImperativeRouteMatch(:final matches) => stackLocations(matches),
  ShellRouteMatch(:final matches) => [
    for (final child in matches) ..._locationsOf(child),
  ],
  _ => [match.matchedLocation],
};

/// Performs [deepLinkAction] for [target] on [router].
void openDeepLink(GoRouter router, GateState gate, String target) {
  final stack = stackLocations(router.routerDelegate.currentConfiguration);
  switch (deepLinkAction(gate, target, stack)) {
    case DeepLinkAction.none:
      return;
    case DeepLinkAction.push:
      unawaited(router.push<void>(target));
    case DeepLinkAction.go:
      router.go(target);
  }
}

/// The router's `onEnter` for `aura://` links; every other navigation is
/// allowed as it is.
///
/// While the app is running the link never replaces the stack: it is
/// blocked and [openDeepLink] runs instead. At launch the first location is
/// the root (the gate picks the screen), and the link opens on top of it
/// once that screen is up.
OnEnterResult deepLinkOnEnter(
  GoRouter router,
  Uri uri,
  GateState Function() gate,
) {
  if (!DeepLinks.isAppLink(uri)) return const Allow();
  final running = router.routerDelegate.currentConfiguration.isNotEmpty;
  final target = DeepLinks.targetOf(uri);
  if (target == null) {
    // aura://auth-callback (Supabase finishes sign-in from it) or an unknown
    // link: stay where we are.
    return running ? const Block.stop() : const Allow();
  }
  if (!running) {
    return Allow(
      then: () => _whenRouted(router, () {
        openDeepLink(router, gate(), target);
      }),
    );
  }
  if (deepLinkAction(
        gate(),
        target,
        stackLocations(router.routerDelegate.currentConfiguration),
      ) ==
      DeepLinkAction.none) {
    return const Block.stop();
  }
  return Block.then(() => openDeepLink(router, gate(), target));
}

/// Runs [action] once the router shows its first screen.
Future<void> _whenRouted(GoRouter router, VoidCallback action) async {
  for (var frame = 0; frame < 30; frame++) {
    if (router.routerDelegate.currentConfiguration.isNotEmpty) break;
    await WidgetsBinding.instance.endOfFrame;
  }
  action();
}
