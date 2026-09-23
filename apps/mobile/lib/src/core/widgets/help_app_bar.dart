import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/support/support_sheet.dart';
import '../theme/aura_tokens.dart';

/// The top bar of a secondary screen (Settings, History, a check-in, Delete
/// my account): Back, the title, and "I need help now".
///
/// The help button stays in the 56 dp bar only when it truly fits there on
/// one line beside Back and the whole title, measured at the current
/// locale, text scale and width. Otherwise (a longer language such as
/// Tenglish, large text, a narrow phone) it moves to a row of its own under
/// the title, end-aligned, sized for its label at any text scale, so the
/// title keeps its row and the button keeps a proper pill (or, once its
/// label has to wrap, rounded-rectangle) shape. Either way it comes right
/// after Back and the title in focus order (REQ-A11Y-11).
PreferredSizeWidget helpAppBar(
  BuildContext context, {
  required String title,
  Widget? leading,
  bool automaticallyImplyLeading = true,
}) {
  final layout = HelpBarLayout.resolve(
    context,
    title: title,
    hasLeading:
        leading != null ||
        (automaticallyImplyLeading &&
            (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)),
  );
  const help = HelpNowButton(compact: true);
  return AppBar(
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    title: Semantics(header: true, container: true, child: Text(title)),
    backgroundColor: AuraColors.sky,
    actions: layout.inBar
        ? const [
            Padding(
              key: HelpBarLayout.actionKey,
              padding: EdgeInsetsDirectional.only(end: HelpBarLayout.endInset),
              child: help,
            ),
          ]
        : null,
    bottom: layout.inBar
        ? null
        : PreferredSize(
            preferredSize: Size.fromHeight(layout.bottomHeight),
            child: SizedBox(
              key: HelpBarLayout.bottomKey,
              height: layout.bottomHeight,
              child: const Padding(
                padding: EdgeInsetsDirectional.only(
                  start: HelpBarLayout.startInset,
                  end: HelpBarLayout.endInset,
                  bottom: HelpBarLayout.bottomInset,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: help,
                ),
              ),
            ),
          ),
  );
}

/// Where [helpAppBar] puts "I need help now", from real text measurements.
@immutable
class HelpBarLayout {
  const HelpBarLayout._({required this.inBar, required this.bottomHeight});

  /// The help button in the bar's actions.
  static const Key actionKey = ValueKey('help-bar-action');

  /// The row under the title that holds the help button.
  static const Key bottomKey = ValueKey('help-bar-bottom');

  /// Space after the button (in the bar and in the row under it).
  static const double endInset = AuraSpace.s;

  /// Space before the button in the row under the title.
  static const double startInset = AuraSpace.l;

  /// Space under the row below the title.
  static const double bottomInset = AuraSpace.s;

  // HelpNowButton's own geometry (support_sheet.dart): icon size, vertical
  // padding and visible minimum height. Its one-line width comes from
  // [HelpNowButton.oneLineWidth].
  static const double _helpIcon = 18;
  static const double _helpVPad = 10;
  static const double _helpMinHeight = 44;

  /// AppBar caps its title's text scale at this factor.
  static const double _titleMaxScale = 1.34;

  /// Whether the button sits in the 56 dp bar on one line.
  final bool inBar;

  /// Height of the row under the title (0 while [inBar]).
  final double bottomHeight;

  /// Measures the title and the help label with their real styles at this
  /// [context]'s locale, text scale and width. [hasLeading] is whether the
  /// bar shows a Back (or close) button before the title.
  static HelpBarLayout resolve(
    BuildContext context, {
    required String title,
    required bool hasLeading,
  }) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal; // the bar's SafeArea

    TextPainter paint(
      String text,
      TextStyle? style,
      TextScaler textScaler, {
      double maxWidth = double.infinity,
    }) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      locale: locale,
      maxLines: maxWidth.isFinite ? null : 1,
    )..layout(maxWidth: maxWidth);

    // The button on one line: label, icon, gap, side padding and border.
    final helpWidth = HelpNowButton.oneLineWidth(context, compact: true);

    // The bar: [Back] · spacing · title · spacing · help · end inset. The
    // title is measured the way AppBar draws it (its style, scale capped).
    final titlePainter = paint(
      title,
      bar.titleTextStyle ?? theme.textTheme.titleLarge,
      scaler.clamp(maxScaleFactor: _titleMaxScale),
    );
    final titleWidth = titlePainter.width;
    titlePainter.dispose();
    final spacing = bar.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
    final used =
        (hasLeading ? bar.leadingWidth ?? kToolbarHeight : 0) +
        2 * spacing +
        titleWidth +
        helpWidth +
        endInset;
    if (used <= width) {
      return const HelpBarLayout._(inBar: true, bottomHeight: 0);
    }

    // Its own row: as tall as the button with its label laid out at the
    // row's width (wrapping only if even the row is too narrow).
    final l = AppLocalizations.of(context);
    final labelStyle = theme.textTheme.labelLarge;
    final oneLine = paint(l.help_button, labelStyle, scaler);
    final chrome = helpWidth - oneLine.width;
    oneLine.dispose();
    final labelMax = math.max(0.0, width - startInset - endInset - chrome);
    final label = paint(l.help_button, labelStyle, scaler, maxWidth: labelMax);
    final labelHeight = label.height;
    label.dispose();
    final button = math.max(
      kMinInteractiveDimension, // padded tap target
      math.max(
        _helpMinHeight,
        math.max(_helpIcon, labelHeight) + 2 * _helpVPad,
      ),
    );
    return HelpBarLayout._(
      inBar: false,
      bottomHeight: (button + bottomInset).ceilToDouble(),
    );
  }
}
