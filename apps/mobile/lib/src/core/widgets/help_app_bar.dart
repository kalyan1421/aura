import 'package:flutter/material.dart';

import '../../features/support/support_sheet.dart';
import '../theme/aura_tokens.dart';

/// Aura's one top bar (design critique #2): Back or close (or, on a tab's
/// first screen, nothing), the title on one line, then "I need help now"
/// and any [actions] (Settings on a tab root) on the right.
///
/// The help button never wraps and never leaves the 56 dp bar. Measured at
/// the current locale, text scale and width, in this order:
///
/// 1. the whole title and the labelled pill fit: both as they are;
/// 2. the title fits at a slightly smaller size ([HelpBarLayout.minTitle]):
///    the title shrinks, the pill keeps its words;
/// 3. otherwise the title moves to its own line under the bar (a large
///    title, up to two lines, never cut) and the pill **keeps its words**:
///    Back and "I need help now" stay where they are on every screen;
/// 4. only when text is above 130%, or the labelled pill doesn't fit even
///    beside Back alone, does it collapse to a heart-only round button whose
///    label stays in the tooltip and screen-reader label.
///
/// Help comes right after Back and the title in focus order (REQ-A11Y-11).
PreferredSizeWidget helpAppBar(
  BuildContext context, {
  required String title,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  List<Widget> actions = const [],
}) {
  final layout = HelpBarLayout.resolve(
    context,
    title: title,
    hasLeading:
        leading != null ||
        (automaticallyImplyLeading &&
            (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)),
    actionCount: actions.length,
  );
  final theme = Theme.of(context);
  final titleStyle =
      theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  final below = layout.titleBelow;
  return AppBar(
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    // A large title keeps its screen-reader stop here, between Back and help
    // (REQ-A11Y-11); the visible words sit under the bar.
    title: below
        ? Semantics(
            header: true,
            container: true,
            label: title,
            // A real size: screen readers skip empty nodes.
            child: const SizedBox(width: double.infinity, height: 24),
          )
        : Semantics(
            header: true,
            container: true,
            child: Text(
              title,
              key: HelpBarLayout.titleKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: layout.titleSize == null
                  ? null
                  : titleStyle?.copyWith(fontSize: layout.titleSize),
            ),
          ),
    bottom: below ? HelpBarLayout.largeTitle(context, title) : null,
    backgroundColor: AuraColors.sky,
    actions: [
      Padding(
        key: HelpBarLayout.actionKey,
        padding: EdgeInsetsDirectional.only(
          end: actions.isEmpty ? HelpBarLayout.endInset : 0,
        ),
        child: HelpNowButton(compact: true, iconOnly: layout.iconOnly),
      ),
      ...actions,
      if (actions.isNotEmpty) const SizedBox(width: AuraSpace.xs),
    ],
  );
}

/// How [helpAppBar] fits the title and "I need help now", from real text
/// measurements.
@immutable
class HelpBarLayout {
  const HelpBarLayout._({
    required this.iconOnly,
    this.titleSize,
    this.titleBelow = false,
  });

  /// The help button in the bar's actions.
  static const Key actionKey = ValueKey('help-bar-action');

  /// The bar's title text.
  static const Key titleKey = ValueKey('help-bar-title');

  /// Space after the button when it is the last thing in the bar.
  static const double endInset = AuraSpace.s;

  /// The smallest title size used to keep the labelled pill (titleLarge is
  /// 22).
  static const double minTitle = 18;

  /// AppBar caps its title's text scale at this factor.
  static const double _titleMaxScale = 1.34;

  /// Help is the heart-only button.
  final bool iconOnly;

  /// The title's font size when it had to shrink (null: the theme's).
  final double? titleSize;

  /// The title sits on its own line under the bar (a large title).
  final bool titleBelow;

  /// The large title under the bar: the screen's headline, up to two lines,
  /// never cut, hidden from screen readers (the bar's title slot reads it).
  static PreferredSizeWidget largeTitle(BuildContext context, String title) {
    final style = Theme.of(context).textTheme.headlineSmall;
    final painter =
        TextPainter(
          text: TextSpan(text: title, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 2,
        )..layout(
          maxWidth: MediaQuery.sizeOf(context).width - 2 * AuraSpace.gutter,
        );
    final height = painter.height + AuraSpace.s;
    painter.dispose();
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AuraSpace.gutter,
            0,
            AuraSpace.gutter,
            AuraSpace.s,
          ),
          child: ExcludeSemantics(
            child: Text(
              title,
              key: titleKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ),
    );
  }

  /// Measures the title and the help label with their real styles at this
  /// [context]'s locale, text scale and width. [hasLeading] is whether the
  /// bar shows a Back (or close) button before the title; [actionCount]
  /// the 48 dp icon buttons after help.
  static HelpBarLayout resolve(
    BuildContext context, {
    required String title,
    required bool hasLeading,
    int actionCount = 0,
  }) {
    if (HelpNowButton.iconOnlyForTextScale(context)) {
      return const HelpBarLayout._(iconOnly: true);
    }
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal; // the bar's SafeArea
    final style = bar.titleTextStyle ?? theme.textTheme.titleLarge;

    double titleWidth(double? size) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: size == null ? style : style?.copyWith(fontSize: size),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler.clamp(maxScaleFactor: _titleMaxScale),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final spacing = bar.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
    final chrome =
        (hasLeading ? bar.leadingWidth ?? kToolbarHeight : 0) +
        2 * spacing +
        actionCount * kMinInteractiveDimension +
        (actionCount > 0 ? AuraSpace.xs : endInset);
    final room =
        width - chrome - HelpNowButton.oneLineWidth(context, compact: true);
    if (titleWidth(null) <= room) {
      return const HelpBarLayout._(iconOnly: false);
    }
    final full = style?.fontSize ?? 22;
    if (full > minTitle && titleWidth(minTitle) <= room) {
      // The largest size between minTitle and full that fits.
      var size = full;
      while (size > minTitle && titleWidth(size) > room) {
        size -= 0.5;
      }
      return HelpBarLayout._(iconOnly: false, titleSize: size);
    }
    // The title goes under the bar; help keeps its words if it fits beside
    // Back (and the actions) on its own.
    if (width - chrome - HelpNowButton.oneLineWidth(context, compact: true) >=
        0) {
      return const HelpBarLayout._(iconOnly: false, titleBelow: true);
    }
    return const HelpBarLayout._(iconOnly: true);
  }
}
