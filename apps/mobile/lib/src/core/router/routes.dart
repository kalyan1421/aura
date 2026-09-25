import '../../features/onboarding/gate_controller.dart';
import '../env/env.dart';

/// Route map:
///
/// - `/` resolves through [gateRedirect]; onboarding (`/welcome`,
///   `/onboarding/*`) and `/blocked` stand alone.
/// - The app shell (`StatefulShellRoute`, one stack per tab): `/home`,
///   `/sanctuary`, `/rooms`, `/insights` (Aura Sky, F10; its stack holds
///   `/insights/history` and `/insights/month`).
/// - Above the shell: `/checkin`, `/safety`, `/settings/**`,
///   `/history/:id`, `/rooms/join`, `/rooms/:id`, `/sign-in`, `/debug/**`.
///   `/history` is `/insights/history`.
abstract final class Routes {
  static const String root = '/';
  static const String welcome = '/welcome';
  static const String trust = '/onboarding/trust';
  static const String dob = '/onboarding/dob';
  static const String language = '/onboarding/language';
  static const String onboardingSignIn = '/onboarding/sign-in';
  static const String blocked = '/blocked';
  static const String home = '/home';
  static const String sanctuary = '/sanctuary';
  static const String rooms = '/rooms';

  /// Matching a room for a saved check-in; the quadrant and mood travel as
  /// the route's `extra` (never in the location).
  static const String roomJoin = '/rooms/join';

  /// One room (F5), above the shell.
  static String room(String roomId) => '/rooms/$roomId';
  static const String insights = '/insights';

  /// The full check-in list (with the 24 h edit and delete), inside the
  /// Insights tab.
  static const String insightsHistory = '/insights/history';

  /// "Your month in stars" (F10), inside the Insights tab.
  static const String insightsMonth = '/insights/month';
  static const String checkIn = '/checkin';
  static const String safety = '/safety';
  static const String settings = '/settings';
  static const String deleteAccount = '/settings/delete-account';

  /// "Download a copy of my data" (F8 REQ-ACC-12).
  static const String dataExport = '/settings/export';
  static const String history = '/history';
  static String historyEntry(String checkInId) => '/history/$checkInId';
  static const String signIn = '/sign-in';
  static const String debugAvatar = '/debug/avatar';

  /// "Please update Aura" (MASVS F-6, features/update): every other route
  /// redirects here while this install is below the server's minimum.
  static const String updateRequired = '/update-required';

  static String forStage(OnboardingStage s) => switch (s) {
    OnboardingStage.welcome => welcome,
    OnboardingStage.trust => trust,
    OnboardingStage.dob => dob,
    OnboardingStage.language => language,
    OnboardingStage.signIn => onboardingSignIn,
    OnboardingStage.firstCheckIn => checkIn,
    OnboardingStage.done => home,
  };
}

/// Forced update (MASVS F-6), a pure rule applied by the router to every
/// navigation (deep links, `go`, `push`, notification taps): while [required],
/// everything but the Safety Center lands on [Routes.updateRequired]; once the
/// minimum is lowered, that route bounces to the root (the gate takes over).
/// Null = no opinion (the gate rule decides).
String? updateRedirect({required bool required, required String location}) {
  if (location == Routes.safety) return null;
  if (required) {
    return location == Routes.updateRequired ? null : Routes.updateRequired;
  }
  return location == Routes.updateRequired ? Routes.root : null;
}

/// Pure redirect rule (unit-testable): the Safety Center opens in every
/// state (F9: help from the under-13 screen and onboarding too); otherwise
/// the under-13 lock wins over everything; onboarding steps run in order;
/// after onboarding the onboarding routes bounce to Home.
String? gateRedirect(GateState gate, String location) {
  if (location == Routes.safety) return null;
  if (gate.isBlocked) return location == Routes.blocked ? null : Routes.blocked;
  if (location == Routes.blocked) return Routes.root;
  if (location.startsWith('/debug')) return Env.debugTools ? null : Routes.root;

  final target = Routes.forStage(gate.stage);
  if (!gate.onboarded) return location == target ? null : target;

  const onboardingOnly = {
    Routes.root,
    Routes.welcome,
    Routes.trust,
    Routes.dob,
    Routes.language,
    Routes.onboardingSignIn,
  };
  return onboardingOnly.contains(location) ? Routes.home : null;
}
