import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/edge_fade_scroller.dart';
import 'room_copy.dart';
import 'room_models.dart';
import 'room_widgets.dart';

/// One gesture on a [GestureTray].
@immutable
class GestureTrayItem {
  const GestureTrayItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
  });

  /// A room preset ([GestureType]) with its shared icon and name.
  factory GestureTrayItem.preset(
    AppLocalizations l,
    GestureType type, {
    required String hint,
    required VoidCallback? onPressed,
    String keyPrefix = 'gesture-',
    String? label,
  }) => GestureTrayItem(
    key: ValueKey('$keyPrefix${type.wire}'),
    icon: gestureIcon(type),
    label: label ?? gestureName(l, type),
    hint: hint,
    onPressed: onPressed,
  );

  /// Key of the tappable tile.
  final Key key;
  final IconData icon;
  final String label;

  /// Screen-reader hint: who it goes to.
  final String hint;
  final VoidCallback? onPressed;
}

/// The eight room presets in their one order, for [GestureTray].
List<GestureTrayItem> presetGestureItems(
  AppLocalizations l, {
  required String hint,
  required ValueChanged<GestureType>? onSend,
  String keyPrefix = 'gesture-',
}) => [
  for (final g in GestureType.values)
    GestureTrayItem.preset(
      l,
      g,
      hint: hint,
      keyPrefix: keyPrefix,
      onPressed: onSend == null ? null : () => onSend(g),
    ),
];

/// How a [GestureTray] lays its tiles out.
enum GestureTrayDensity {
  /// One horizontally scrolling row; tiles hug their labels (a room's
  /// pinned tray, Breath Ripples).
  compact,

  /// A grid of two to four equal tiles per row whose labels may wrap,
  /// never cut (the member sheet, Quiet Together, the wind-down).
  grid,
}

/// Aura's one gesture tray (design critique #7): the same tiles, icons and
/// order on every surface that sends a preset gesture, in a [compact] row or
/// a full [grid].
class GestureTray extends StatelessWidget {
  const GestureTray({
    super.key,
    required this.items,
    this.density = GestureTrayDensity.compact,
    this.padding = EdgeInsets.zero,
  });

  final List<GestureTrayItem> items;
  final GestureTrayDensity density;

  /// Around the row (compact: scrolls under it, so a gutter keeps the first
  /// tile aligned with the page).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => switch (density) {
    GestureTrayDensity.compact => EdgeFadeScroller(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: AuraSpace.s),
            GestureTile(
              tileKey: item.key,
              icon: item.icon,
              label: item.label,
              hint: item.hint,
              onPressed: item.onPressed,
            ),
          ],
        ],
      ),
    ),
    GestureTrayDensity.grid => Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, box) {
          // Two to four per row; each label may wrap, never cut.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final perRow = (box.maxWidth / (88 * scale.clamp(1.0, 2.0)))
              .floor()
              .clamp(2, 4);
          final width = (box.maxWidth - (perRow - 1) * AuraSpace.s) / perRow;
          return Wrap(
            spacing: AuraSpace.s,
            runSpacing: AuraSpace.s,
            children: [
              for (final item in items)
                GestureTile(
                  tileKey: item.key,
                  icon: item.icon,
                  label: item.label,
                  hint: item.hint,
                  onPressed: item.onPressed,
                  width: width,
                ),
            ],
          );
        },
      ),
    ),
  };
}
