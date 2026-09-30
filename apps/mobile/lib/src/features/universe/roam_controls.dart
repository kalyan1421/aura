import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import 'roam.dart';

/// Free-roam controls (W05): a drag pad and four arrows, all producing one
/// [RoamInput]. Nothing is required: tap-to-travel and the place list do the
/// same job. The pad is a gesture shortcut and is hidden from screen readers;
/// each arrow is a real button that walks while it is held and, for a screen
/// reader's single activation, takes one small step ([onNudge]).
class RoamControls extends StatefulWidget {
  const RoamControls({
    super.key,
    required this.onInput,
    required this.onNudge,
  });

  /// The current push, or [RoamInput.zero] when nothing is held.
  final ValueChanged<RoamInput> onInput;

  /// One small fixed step (a screen reader's activation of an arrow).
  final ValueChanged<RoamInput> onNudge;

  @override
  State<RoamControls> createState() => _RoamControlsState();
}

enum _Arrow { forward, back, left, right }

class _RoamControlsState extends State<RoamControls> {
  static const double _pad = 128;
  static const double _knob = 44;
  static const double _button = 48;

  /// A press shorter than this is a tap: one small step, no walking.
  static const Duration _tapTime = Duration(milliseconds: 120);

  final Set<_Arrow> _held = {};
  final Map<_Arrow, Timer> _pressing = {};
  Offset _stick = Offset.zero; // -1..1, screen up is -dy
  int? _stickPointer;

  RoamInput get _arrows => RoamInput(
    right: (_held.contains(_Arrow.right) ? 1.0 : 0.0) -
        (_held.contains(_Arrow.left) ? 1.0 : 0.0),
    forward: (_held.contains(_Arrow.forward) ? 1.0 : 0.0) -
        (_held.contains(_Arrow.back) ? 1.0 : 0.0),
  );

  void _emit() => widget.onInput(
    RoamInput(right: _stick.dx, forward: -_stick.dy) + _arrows,
  );

  @override
  void dispose() {
    for (final t in _pressing.values) {
      t.cancel();
    }
    // Never leave the companion walking when the controls go away.
    widget.onInput(RoamInput.zero);
    super.dispose();
  }

  void _stickAt(Offset local) {
    const reach = (_pad - _knob) / 2;
    var v = (local - const Offset(_pad / 2, _pad / 2)) / reach;
    final length = v.distance;
    if (length > 1) v = v / length;
    setState(() => _stick = v);
    _emit();
  }

  void _stickEnd() {
    _stickPointer = null;
    setState(() => _stick = Offset.zero);
    _emit();
  }

  static RoamInput _nudgeFor(_Arrow a) => switch (a) {
    _Arrow.forward => const RoamInput(forward: 1),
    _Arrow.back => const RoamInput(forward: -1),
    _Arrow.left => const RoamInput(right: -1),
    _Arrow.right => const RoamInput(right: 1),
  };

  Widget _arrowButton(_Arrow a, IconData icon, String label) {
    // Walking starts once a press has lasted [_tapTime]; a shorter press is a
    // tap and takes one small step instead, so a quick tap is never a no-op.
    void down() {
      _pressing[a]?.cancel();
      _pressing[a] = Timer(_tapTime, () {
        _pressing.remove(a);
        setState(() => _held.add(a));
        _emit();
      });
    }

    void up({required bool cancelled}) {
      final wasTap = _pressing.remove(a);
      if (wasTap != null) {
        wasTap.cancel();
        if (!cancelled) widget.onNudge(_nudgeFor(a));
        return;
      }
      if (_held.contains(a)) {
        setState(() => _held.remove(a));
        _emit();
      }
    }

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: () => widget.onNudge(_nudgeFor(a)),
      excludeSemantics: true,
      child: RawGestureDetector(
        // Claim the touch at once so the page does not scroll under a hold.
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
        },
        child: Listener(
          key: ValueKey('roam-${a.name}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => down(),
          onPointerUp: (_) => up(cancelled: false),
          onPointerCancel: (_) => up(cancelled: true),
          child: SizedBox(
            width: _button,
            height: _button,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _held.contains(a)
                        ? AuraColors.starlight
                        : AuraColors.controlOutline,
                  ),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const reach = (_pad - _knob) / 2;
    // Side by side when there is room, stacked on a narrow phone (320 dp), so
    // the arrows never shrink below a touch target.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        ExcludeSemantics(
          child: RawGestureDetector(
            gestures: {
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
            },
            child: Listener(
              key: const ValueKey('roam-pad'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                _stickPointer = e.pointer;
                _stickAt(e.localPosition);
              },
              onPointerMove: (e) {
                if (e.pointer == _stickPointer) _stickAt(e.localPosition);
              },
              onPointerUp: (e) {
                if (e.pointer == _stickPointer) _stickEnd();
              },
              onPointerCancel: (e) {
                if (e.pointer == _stickPointer) _stickEnd();
              },
              child: SizedBox(
                width: _pad,
                height: _pad,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AuraColors.controlOutline),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Transform.translate(
                      offset: _stick * reach,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          border: Border.all(
                            color: _stick == Offset.zero
                                ? AuraColors.controlOutline
                                : AuraColors.starlight,
                          ),
                        ),
                        child: const SizedBox(width: _knob, height: _knob),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: _button * 3,
          height: _button * 3,
          child: Stack(
            children: [
              Positioned(
                left: _button,
                top: 0,
                child: _arrowButton(
                  _Arrow.forward,
                  Icons.keyboard_arrow_up_rounded,
                  l.universe_walkForward,
                ),
              ),
              Positioned(
                left: 0,
                top: _button,
                child: _arrowButton(
                  _Arrow.left,
                  Icons.keyboard_arrow_left_rounded,
                  l.universe_walkLeft,
                ),
              ),
              Positioned(
                left: _button * 2,
                top: _button,
                child: _arrowButton(
                  _Arrow.right,
                  Icons.keyboard_arrow_right_rounded,
                  l.universe_walkRight,
                ),
              ),
              Positioned(
                left: _button,
                top: _button * 2,
                child: _arrowButton(
                  _Arrow.back,
                  Icons.keyboard_arrow_down_rounded,
                  l.universe_walkBack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
