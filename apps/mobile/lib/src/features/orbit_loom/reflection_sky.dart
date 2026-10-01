import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../universe/universe_scene.dart';
import 'constellation_repository.dart';
import 'loom_shape.dart';
import 'loom_sky_painter.dart';
import 'orbit_loom_screen.dart' show ConstellationMeaningCopy;

/// The most recent constellations hung in the sky over the Reflection
/// landmark, newest in the middle.
const int reflectionSkyShown = 3;

/// Kept constellations in the personal universe's sky (U07), drawn over the
/// scene with the scene's own camera, so they sit above the Reflection
/// landmark and turn with the island. Decoration only: they are listed in
/// words in the Reflection card, and the scene is hidden from screen readers.
class ReflectionSkyPainter extends CustomPainter {
  const ReflectionSkyPainter({required this.camera, required this.shapes});

  final UniverseCamera camera;

  /// Newest first; only the first [reflectionSkyShown] are drawn.
  final List<LoomShape> shapes;

  static const Color _star = Color(0xFFFFE6AC);

  @override
  void paint(Canvas canvas, Size size) {
    if (shapes.isEmpty || size.isEmpty) return;
    final project = camera.projector(size);
    final right = camera.right;
    final up = camera.up;
    final base = UniverseDestination.reflection.position;
    // Newest above the landmark, the two before it a little lower beside it.
    const layout = [
      (side: 0.0, height: 1.85, size: 1.05, alpha: 0.9),
      (side: -0.95, height: 1.55, size: 0.7, alpha: 0.55),
      (side: 0.95, height: 1.55, size: 0.7, alpha: 0.55),
    ];
    for (var i = 0; i < math.min(shapes.length, reflectionSkyShown); i++) {
      final shape = shapes[i];
      final place = layout[i];
      final center = base + WorldPoint(0, place.height, 0) + right * place.side;
      ({Offset point, double depth})? at(LoomStar s) => project(
        center +
            right * ((s.x - 0.5) * place.size) +
            up * ((0.5 - s.y) * place.size),
      );
      final points = [for (final s in shape.stars) at(s)];
      final line = Paint()
        ..color = _star.withValues(alpha: place.alpha * 0.7)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (final l in shape.links) {
        if (l.a >= points.length || l.b >= points.length) continue;
        final a = points[l.a];
        final b = points[l.b];
        if (a == null || b == null) continue;
        canvas.drawLine(a.point, b.point, line);
      }
      final glow = Paint()..color = _star.withValues(alpha: place.alpha * 0.25);
      final core = Paint()..color = _star.withValues(alpha: place.alpha);
      for (final p in points) {
        if (p == null) continue;
        canvas.drawCircle(p.point, i == 0 ? 5 : 4, glow);
        canvas.drawCircle(p.point, i == 0 ? 2.2 : 1.7, core);
      }
    }
  }

  @override
  bool shouldRepaint(ReflectionSkyPainter old) =>
      old.camera != camera || old.shapes != shapes;
}

/// The Reflection card's list of kept constellations: a small picture and the
/// words for each, and a way to let one go. The pictures are decoration; the
/// words carry the meaning for everyone.
class KeptConstellations extends ConsumerWidget {
  const KeptConstellations({super.key, required this.kept});
  final List<KeptConstellation> kept;

  static String labelOf(AppLocalizations l, KeptConstellation c) =>
      l.universe_constellationLabel(
        c.meaning?.label(l) ?? l.universe_constellationPlain,
        c.shape.stars.length,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l.universe_constellationsTitle, style: t.titleSmall),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in kept)
              SizedBox(
                key: ValueKey('universe-constellation-${c.id}'),
                width: 112,
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          size: const Size.square(88),
                          painter: LoomSkyPainter(
                            shape: c.shape,
                            thumbnail: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labelOf(l, c),
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    IconButton(
                      key: ValueKey('universe-letgo-${c.id}'),
                      tooltip: '${l.universe_letGo}: ${labelOf(l, c)}',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AuraColors.textSoft,
                      ),
                      onPressed: () => _letGo(context, ref, c),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _letGo(
    BuildContext context,
    WidgetRef ref,
    KeptConstellation c,
  ) async {
    final l = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.universe_letGoTitle),
        content: Text(l.universe_letGoBody),
        actions: [
          TextButton(
            key: const ValueKey('universe-letgo-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.universe_letGoKeep),
          ),
          TextButton(
            key: const ValueKey('universe-letgo-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.universe_letGo),
          ),
        ],
      ),
    );
    if (go != true) return;
    await ref.read(constellationRepositoryProvider).letGo(c.id);
  }
}

/// Shapes for [ReflectionSkyPainter], newest first.
List<LoomShape> skyShapes(List<KeptConstellation> kept) => [
  for (final c in kept.take(reflectionSkyShown)) c.shape,
];
