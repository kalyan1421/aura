import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aura_tokens.dart';
import '../progress/progress_view.dart';

/// The four peer destinations of the app shell, in branch order.
enum ShellTab { home, sanctuary, rooms, insights }

/// The app after onboarding: the active tab above the navigation bar
/// (Home · Sanctuary · [Check in] · Rooms · Insights).
///
/// Each tab keeps its own screen stack, state and scroll position
/// (`StatefulShellRoute.indexedStack` in the router). Check in is an action,
/// not a tab: it opens the full-screen check-in above the shell, which
/// returns to the tab it came from. Settings opens from the Home and
/// Insights top bars; the Safety Center, from "I need help now" everywhere.
/// Back on another tab's first screen returns to Home.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PRD States, Home empty: the Check in action pulses once for someone
    // who has not checked in yet.
    final newUser = ref.watch(
      progressViewProvider.select((v) => v.loaded && !v.hasActivity),
    );
    final index = shell.currentIndex;
    return PopScope(
      canPop: index == ShellTab.home.index,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(ShellTab.home.index);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: AuraNavBar(
          current: ShellTab.values[index],
          // Tapping the open tab again returns it to its first screen.
          onSelect: (tab) =>
              shell.goBranch(tab.index, initialLocation: tab.index == index),
          onCheckIn: () => openCheckIn(context),
          pulseCheckIn: newUser,
        ),
      ),
    );
  }
}

/// Opens the full-screen check-in above whatever is showing (it comes back
/// there when done). Never stacks a second one.
void openCheckIn(BuildContext context) {
  final router = GoRouter.of(context);
  final open = router.routerDelegate.currentConfiguration;
  if (open.isNotEmpty && router.state.matchedLocation == Routes.checkIn) {
    return;
  }
  router.push<void>(Routes.checkIn);
}

/// Settings from a tab's top bar. Settings is never a tab (design system
/// "Navigation"): Home has its own button; Insights and other tab roots can
/// put this one in their app bar.
class ShellSettingsButton extends StatelessWidget {
  const ShellSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('shell-settings'),
    tooltip: AppLocalizations.of(context).home_settings,
    onPressed: () => context.push(Routes.settings),
    icon: const Icon(Icons.tune_rounded),
  );
}

/// Whether [context] is the first screen of a tab in the app shell, where a
/// Back button has nowhere to go.
bool isShellTabRoot(BuildContext context) =>
    StatefulNavigationShell.maybeOf(context) != null &&
    !(ModalRoute.of(context)?.canPop ?? false);

/// The navigation bar: four peer destinations and, in the middle, the
/// visually distinct Check in action (design system "Navigation").
///
/// A destination's active state is its filled icon, a lavender-outlined
/// container and a bolder, brighter label: never colour alone. Every item is
/// a full-height slot of at least 48 dp, one screen-reader node ("Home,
/// selected, button, tab 1 of 4"). Labels wrap between words at large text
/// and the bar grows; a single word too wide for its slot is shrunk to fit,
/// never cut or broken. On short screens (under 700 dp, e.g. an iPhone SE)
/// the icon row is slimmer, so Home keeps its room. No motion under Reduce
/// Motion.
class AuraNavBar extends StatelessWidget {
  const AuraNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onCheckIn,
    this.pulseCheckIn = false,
  });

  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback onCheckIn;

  /// Pulse the Check in action once (new user). Ignored under Reduce Motion.
  final bool pulseCheckIn;

  static const Key barKey = ValueKey('shell-nav-bar');
  static const Key checkInKey = ValueKey('shell-checkin');
  static Key tabKey(ShellTab tab) => ValueKey('shell-tab-${tab.name}');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).height < _shortScreen;
    final iconRow = compact ? _iconRowCompact : _iconRow;
    Widget tab(ShellTab tab, String label, IconData icon, IconData active) =>
        Expanded(
          child: _Destination(
            tab: tab,
            label: label,
            icon: icon,
            activeIcon: active,
            selected: tab == current,
            iconRow: iconRow,
            onTap: () => onSelect(tab),
          ),
        );

    return Material(
      key: barKey,
      color: AuraColors.skyHigh,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AuraColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AuraSpace.xs,
              vertical: compact ? AuraSpace.xs : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tab(
                  ShellTab.home,
                  l.shell_tabHome,
                  Icons.home_outlined,
                  Icons.home_rounded,
                ),
                tab(
                  ShellTab.sanctuary,
                  l.shell_tabSanctuary,
                  Icons.spa_outlined,
                  Icons.spa_rounded,
                ),
                Expanded(
                  child: _CheckInAction(
                    onTap: onCheckIn,
                    pulse: pulseCheckIn,
                    size: iconRow,
                  ),
                ),
                tab(
                  ShellTab.rooms,
                  l.shell_tabRooms,
                  Icons.groups_outlined,
                  Icons.groups_rounded,
                ),
                tab(
                  ShellTab.insights,
                  l.shell_tabInsights,
                  Icons.insights_outlined,
                  Icons.insights_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Height of the icon row in every slot (the Check in orb fills it).
const double _iconRow = 48;

/// The icon row on short screens.
const double _iconRowCompact = 40;

/// Screens shorter than this get the slimmer bar (as Home's own layout).
const double _shortScreen = 700;

class _Destination extends StatelessWidget {
  const _Destination({
    required this.tab,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.iconRow,
    required this.onTap,
  });

  final ShellTab tab;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final double iconRow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = reduceMotionOf(context) ? Duration.zero : AuraMotion.quick;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: selected ? AuraColors.text : AuraColors.textSoft,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    // One node: the InkWell's own semantics are replaced, so the tap action
    // is declared here too.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      hint: MaterialLocalizations.of(context)
          .tabLabel(tabIndex: tab.index + 1, tabCount: ShellTab.values.length),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: AuraNavBar.tabKey(tab),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: iconRow,
                  child: Center(
                    child: AnimatedContainer(
                      duration: change,
                      curve: AuraMotion.ease,
                      width: 56,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? AuraColors.accent.withValues(alpha: 0.16)
                            : AuraColors.accent.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        border: Border.all(
                          color: selected
                              ? AuraColors.lavender.withValues(alpha: 0.75)
                              : AuraColors.lavender.withValues(alpha: 0),
                        ),
                      ),
                      child: Icon(
                        selected ? activeIcon : icon,
                        size: 22,
                        color: selected
                            ? AuraColors.lavender
                            : AuraColors.textSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                _NavLabel(label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Check in action: an accent orb (a circle, unlike the destinations'
/// pill containers), never shown as selected.
class _CheckInAction extends StatelessWidget {
  const _CheckInAction({
    required this.onTap,
    required this.pulse,
    required this.size,
  });

  final VoidCallback onTap;
  final bool pulse;

  /// The orb's diameter (the icon row's height).
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget orb = Container(
      key: const ValueKey('shell-checkin-orb'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AuraColors.starlight.withValues(alpha: 0.5)),
      ),
      child: const Icon(
        Icons.auto_awesome,
        size: 24,
        color: AuraColors.onAccent,
      ),
    );
    // Pulses once for a new user; never under Reduce Motion (REQ-A11Y-08).
    if (pulse && !reduceMotionOf(context)) {
      orb = orb
          .animate(delay: 600.ms)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 450.ms,
            curve: Curves.easeInOut,
          )
          .then()
          // Effects compose: this one undoes the first, back to 1.
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1 / 1.08, 1 / 1.08),
            duration: 450.ms,
          );
    }
    return Semantics(
      container: true,
      button: true,
      label: l.shell_checkIn,
      hint: l.shell_checkInHint,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: AuraNavBar.checkInKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size,
                  child: Center(child: orb),
                ),
                const SizedBox(height: 2),
                _NavLabel(
                  l.shell_checkIn,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AuraColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A navigation label: centred, wraps between words, never cut. When one
/// word is wider than the slot at the current text scale (a long word at
/// 200%), the label is shrunk just enough for that word to fit rather than
/// broken inside it.
class _NavLabel extends StatelessWidget {
  const _NavLabel(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  /// Never smaller than this share of the base size.
  static const double _minScale = 0.75;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Text(
      text,
      textAlign: TextAlign.center,
      softWrap: true,
      style: style,
      textScaler: _fit(context, box.maxWidth),
    ),
  );

  TextScaler _fit(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    if (!width.isFinite || text.trim().isEmpty) return scaler;
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    /// The widest word at [factor] times the base size.
    double widestAt(double factor) {
      var widest = 0.0;
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: TextScaler.linear(factor),
          locale: locale,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    final base = style?.fontSize ?? 14;
    final current = scaler.scale(base) / base;
    // A hair of slack for sub-pixel rounding.
    final room = width - 1;
    final full = widestAt(current);
    if (full <= room) return scaler;
    // Width grows linearly with the scale, plus a part that doesn't (letter
    // spacing): solve for the scale where the widest word just fits.
    final half = widestAt(current / 2);
    final slope = (full - half) / (current / 2);
    var factor = slope > 0
        ? (room - (full - slope * current)) / slope
        : current * room / full;
    factor = factor.clamp(_minScale, current);
    // Rounding: step down until it fits (or reaches the floor).
    for (var i = 0; i < 8 && factor > _minScale; i++) {
      if (widestAt(factor) <= room) break;
      factor = math.max(_minScale, factor * 0.97);
    }
    return TextScaler.linear(factor);
  }
}
