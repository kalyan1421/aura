// Hidden developer screen (/debug/avatar). Not user-facing, so its labels
// are plain English rather than localized copy.
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import 'aura_avatar.dart';
import 'aura_avatar_painter.dart';
import 'avatar_assets.dart';

class AvatarDebugScreen extends ConsumerStatefulWidget {
  const AvatarDebugScreen({super.key});

  @override
  ConsumerState<AvatarDebugScreen> createState() => _AvatarDebugScreenState();
}

class _AvatarDebugScreenState extends ConsumerState<AvatarDebugScreen> {
  AuraAvatarState _s = AuraAvatarState(
    stage: AuraStage.glow,
    hue: 250,
    ringCount: 2,
    glowLevel: 1,
  );
  AvatarTier? _tier;
  bool _shaders = true;
  AvatarMoment? _moment;
  int _momentSeq = 0;
  static const _cosmetics = ['halo', 'comet_tail', 'stardust_veil'];

  void _play(AvatarMomentKind kind) => setState(
    () => _moment = AvatarMoment('debug-${_momentSeq++}', kind),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final assets = ref.watch(avatarAssetsProvider).value;

    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> onChanged, {
      int? divisions,
      String? display,
    }) => Row(
      children: [
        SizedBox(width: 118, child: Text(label, style: t.bodySmall)),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(display ?? value.toStringAsFixed(0), style: t.bodySmall),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Avatar lab'), backgroundColor: AuraColors.sky),
      body: CosmicBackground(
        tint: glowColorForHue(_s.hue),
        child: Column(
          children: [
            SizedBox(
              height: 380,
              child: Center(
                child: AuraAvatarView(
                  key: const ValueKey('debug-avatar'),
                  state: _s,
                  assets: assets,
                  size: const Size(360, 370),
                  tier: _tier,
                  useShaders: _shaders,
                  moment: _moment,
                  onMomentDone: (_) => setState(() => _moment = null),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  Text(
                    'base: ${assets?.base == null ? 'missing' : '${assets!.base!.width}x${assets.base!.height}'}'
                    '  shaders: ${assets?.hasShaders ?? false}'
                    '  fallback: ${AuraAvatarPainter.lastFallback ?? 'none'}',
                    style: t.labelSmall,
                  ),
                  slider(
                    'stage',
                    _s.stage.index.toDouble(),
                    4,
                    (v) => setState(
                      () => _s = _s.copyWith(stage: AuraStage.values[v.round()]),
                    ),
                    divisions: 4,
                    display: _s.stage.name,
                  ),
                  slider(
                    'hue',
                    _s.hue,
                    359,
                    (v) => setState(() => _s = _s.copyWith(hue: v)),
                    display: '${_s.hue.toStringAsFixed(0)}°',
                  ),
                  Row(
                    children: [
                      for (final q in Quadrant.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(q.name),
                            onPressed: () => setState(
                              () => _s = _s.copyWith(hue: q.hueDeg),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('isResting'),
                    value: _s.isResting,
                    onChanged: (v) => setState(() => _s = _s.copyWith(isResting: v)),
                  ),
                  slider(
                    'ringCount',
                    _s.ringCount.toDouble(),
                    3,
                    (v) => setState(() => _s = _s.copyWith(ringCount: v.round())),
                    divisions: 3,
                  ),
                  slider(
                    'glowLevel',
                    _s.glowLevel.toDouble(),
                    3,
                    (v) => setState(() => _s = _s.copyWith(glowLevel: v.round())),
                    divisions: 3,
                  ),
                  slider(
                    'constellationStars',
                    _s.constellationStars.toDouble(),
                    12,
                    (v) => setState(
                      () => _s = _s.copyWith(constellationStars: v.round()),
                    ),
                    divisions: 12,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      const Text('cosmetics (visual only, none drawn in v1):'),
                      for (final c in _cosmetics)
                        FilterChip(
                          label: Text(c),
                          selected: _s.equippedCosmetics.contains(c),
                          onSelected: (on) => setState(() {
                            final next = {..._s.equippedCosmetics};
                            on ? next.add(c) : next.remove(c);
                            _s = _s.copyWith(equippedCosmetics: next);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AvatarTier?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('auto')),
                      ButtonSegment(value: AvatarTier.high, label: Text('High')),
                      ButtonSegment(value: AvatarTier.low, label: Text('Low')),
                      ButtonSegment(value: AvatarTier.still, label: Text('Still')),
                    ],
                    selected: {_tier},
                    onSelectionChanged: (s) => setState(() => _tier = s.first),
                  ),
                  SwitchListTile(
                    title: const Text('fragment shaders'),
                    subtitle: const Text('off = painter-only fallback'),
                    value: _shaders,
                    onChanged: (v) => setState(() => _shaders = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _play(AvatarMomentKind.evolve),
                        child: const Text('play evolve'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => _s = _s.copyWith(isResting: false));
                          _play(AvatarMomentKind.wakeUp);
                        },
                        child: const Text('play wakeUp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
