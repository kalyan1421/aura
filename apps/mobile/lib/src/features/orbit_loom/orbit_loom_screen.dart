import 'dart:math' as math;

import 'package:aura_domain/aura_domain.dart'
    show ConstellationMeaning, maxLoomConstellationsPerDay, maxLoomStars;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/widgets/help_app_bar.dart';
import 'constellation_repository.dart';
import 'loom_shape.dart';
import 'loom_sky_painter.dart';

/// Opens Orbit Loom above the tab bar, like the other care flows. Completes
/// with `true` when a constellation was kept.
Future<bool?> openOrbitLoom(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<bool>(MaterialPageRoute<bool>(builder: (_) => const OrbitLoomScreen()));

extension ConstellationMeaningCopy on ConstellationMeaning {
  String label(AppLocalizations l) => switch (this) {
    ConstellationMeaning.noticed => l.loom_meaning_noticed,
    ConstellationMeaning.carrying => l.loom_meaning_carrying,
    ConstellationMeaning.ahead => l.loom_meaning_ahead,
    ConstellationMeaning.thankful => l.loom_meaning_thankful,
    ConstellationMeaning.justBecause => l.loom_meaning_just_because,
  };
}

/// Orbit Loom (U07): place a few stars and join them however you like. There
/// is no right shape, score or timer, and leaving at any point is fine. The
/// buttons alone can finish a shape (no precise dragging, colour or typing),
/// every star is a screen-reader button, and nothing moves on its own.
/// Keeping one is cosmetic: it awards nothing (RULES.md section 14).
class OrbitLoomScreen extends ConsumerStatefulWidget {
  const OrbitLoomScreen({super.key, this.random});

  /// For tests: where "Add a star" and "Scatter for me" put stars.
  final math.Random? random;

  @override
  ConsumerState<OrbitLoomScreen> createState() => _OrbitLoomScreenState();
}

class _OrbitLoomScreenState extends ConsumerState<OrbitLoomScreen> {
  LoomShape _shape = LoomShape.empty;
  final List<LoomShape> _history = [];
  late final math.Random _random = widget.random ?? math.Random();

  /// Drag mode joins by dragging; tap mode by tapping two stars.
  bool _dragMode = false;

  /// Tap mode: the star chosen first, waiting for a second.
  int? _chosen;

  /// Drag mode: the star being dragged and where the finger is (unit sky).
  int? _dragFrom;
  LoomStar? _dragAt;

  ConstellationMeaning? _meaning;
  bool _keeping = false;

  void _change(LoomShape next) {
    if (next == _shape) return;
    setState(() {
      _history.add(_shape);
      _shape = next;
      if (_chosen != null && _chosen! >= next.stars.length) _chosen = null;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _shape = _history.removeLast();
      _chosen = null;
    });
  }

  void _clear() {
    _change(LoomShape.empty);
    setState(() => _chosen = null);
  }

  /// Tap mode, and a screen reader activating a star: the first star chosen
  /// waits for a second; choosing it again lets it go. Joining keeps the
  /// second star chosen, so a path can be drawn star by star.
  void _tapStar(int i) {
    final first = _chosen;
    if (first == null) {
      setState(() => _chosen = i);
    } else if (first == i) {
      setState(() => _chosen = null);
    } else {
      _change(_shape.toggleLink(first, i));
      setState(() => _chosen = i);
    }
  }

  void _tapSky(LoomStar at) {
    final near = _shape.starNear(at.x, at.y);
    if (near != null) return _tapStar(near);
    if (_dragMode) return;
    _change(_shape.addStar(at.x, at.y));
  }

  void _dragStart(LoomStar at) {
    final near = _shape.starNear(at.x, at.y);
    if (near == null) return;
    setState(() {
      _dragFrom = near;
      _dragAt = at;
    });
  }

  void _dragUpdate(LoomStar at) {
    if (_dragFrom == null) return;
    setState(() => _dragAt = at);
  }

  /// Let go on another star: join (or unjoin) them. Let go on open sky: the
  /// star moves there, keeping its lines.
  void _dragEnd() {
    final from = _dragFrom;
    final at = _dragAt;
    setState(() {
      _dragFrom = null;
      _dragAt = null;
    });
    if (from == null || at == null) return;
    final target = _shape.starNear(at.x, at.y);
    if (target == from) return;
    _change(
      target != null
          ? _shape.toggleLink(from, target)
          : _shape.moveStar(from, at.x, at.y),
    );
  }

  Future<void> _keep() async {
    if (!_shape.canKeep || _keeping) return;
    setState(() => _keeping = true);
    await ref
        .read(constellationRepositoryProvider)
        .keep(_shape, meaning: _meaning);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final keptToday = ref.watch(keptTodayProvider).value ?? 0;
    final dayFull = keptToday >= maxLoomConstellationsPerDay;
    return Scaffold(
      appBar: helpAppBar(
        context,
        title: l.loom_title,
        leading: IconButton(
          key: const ValueKey('loom-close'),
          tooltip: l.loom_close,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(l.loom_intro, style: t.bodyLarge),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  key: const ValueKey('loom-mode'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.touch_app_outlined),
                      label: Text(l.loom_modeTap),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.gesture),
                      label: Text(l.loom_modeDrag),
                    ),
                  ],
                  selected: {_dragMode},
                  onSelectionChanged: (v) => setState(() {
                    _dragMode = v.first;
                    _chosen = null;
                  }),
                ),
                const SizedBox(height: 12),
                AspectRatio(aspectRatio: 1, child: _sky(l)),
                const SizedBox(height: 8),
                Text(
                  _dragMode ? l.loom_hintDrag : l.loom_hintTap,
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (_shape.stars.length >= maxLoomStars) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l.loom_full,
                      key: const ValueKey('loom-full'),
                      style: t.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _button(
                      'loom-add',
                      Icons.add,
                      l.loom_addStar,
                      _shape.isFull
                          ? null
                          : () => _change(_shape.addSomewhere(_random)),
                    ),
                    _button(
                      'loom-scatter',
                      Icons.auto_awesome_outlined,
                      l.loom_scatter,
                      _shape.stars.length >= 5
                          ? null
                          : () => _change(_shape.scatter(_random)),
                    ),
                    _button(
                      'loom-join',
                      Icons.timeline,
                      l.loom_joinForMe,
                      _shape.stars.length < 2
                          ? null
                          : () => _change(_shape.joinForMe()),
                    ),
                    _button(
                      'loom-undo',
                      Icons.undo,
                      l.loom_undo,
                      _history.isEmpty ? null : _undo,
                    ),
                    _button(
                      'loom-clear',
                      Icons.restart_alt,
                      l.loom_clear,
                      _shape.stars.isEmpty ? null : _clear,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(l.loom_meaningTitle, style: t.titleSmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in ConstellationMeaning.values)
                      ChoiceChip(
                        key: ValueKey('loom-meaning-${m.key}'),
                        label: Text(m.label(l)),
                        selected: _meaning == m,
                        onSelected: (on) =>
                            setState(() => _meaning = on ? m : null),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (dayFull)
                  Text(
                    l.loom_dayFull,
                    key: const ValueKey('loom-day-full'),
                    style: t.bodyMedium,
                  )
                else ...[
                  FilledButton.icon(
                    key: const ValueKey('loom-keep'),
                    onPressed: _shape.canKeep && !_keeping ? _keep : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l.loom_keep),
                  ),
                  if (!_shape.hasEnoughStars) ...[
                    const SizedBox(height: 8),
                    Text(
                      l.loom_keepNeedsStars,
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String key,
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) => OutlinedButton.icon(
    key: ValueKey(key),
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
  );

  /// The sky: one gesture surface for tapping and dragging, and, over it,
  /// one invisible screen-reader button per star (they never take a touch).
  Widget _sky(AppLocalizations l) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      LoomStar unit(Offset p) => LoomStar(
        (p.dx / size.width).clamp(0.0, 1.0),
        (p.dy / size.height).clamp(0.0, 1.0),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: l.loom_skyLabel(
                  _shape.stars.length,
                  _shape.links.length,
                ),
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: const ValueKey('loom-sky'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tapSky(unit(d.localPosition)),
                    onPanStart: _dragMode
                        ? (d) => _dragStart(unit(d.localPosition))
                        : null,
                    onPanUpdate: _dragMode
                        ? (d) => _dragUpdate(unit(d.localPosition))
                        : null,
                    onPanEnd: _dragMode ? (_) => _dragEnd() : null,
                    onPanCancel: _dragMode ? _dragEnd : null,
                    child: CustomPaint(
                      size: size,
                      painter: LoomSkyPainter(
                        shape: _shape,
                        chosen: _dragMode ? _dragFrom : _chosen,
                        dragFrom: _dragFrom,
                        dragTo: _dragAt,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < _shape.stars.length; i++)
              Positioned(
                left: _shape.stars[i].x * size.width - 24,
                top: _shape.stars[i].y * size.height - 24,
                width: 48,
                height: 48,
                child: Semantics(
                  key: ValueKey('loom-star-$i'),
                  container: true,
                  button: true,
                  selected: _chosen == i,
                  label: l.loom_starLabel(
                    i + 1,
                    _shape.stars.length,
                    _shape.linksOf(i),
                  ),
                  hint: _chosen == i ? l.loom_starChosen : null,
                  onTap: () => _tapStar(i),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      );
    },
  );
}
