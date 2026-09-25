import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/aura_tokens.dart';
import '../avatar/aura_avatar.dart';
import '../avatar/avatar_assets.dart';
import '../keepsakes/keepsake_seal.dart';
import 'share_card_data.dart';

/// Design size of a card (9:16). Exported at 1080×1920 (×3), or 720×1280
/// when memory is short (PRD F13 edge case).
const Size shareCardDesignSize = Size(360, 640);

/// The card's one line: the milestone, never anything about how the person
/// feels, and never a date.
String shareCardLine(AppLocalizations l, ShareCardData d) => switch (d.kind) {
  ShareCardKind.evolution => l.share_evolutionLine(stageName(l, d.stage)),
  ShareCardKind.glow => l.keepsake_glowDays(d.value ?? 0),
  ShareCardKind.capsuleAnniversary => l.share_anniversaryLine(d.value ?? 1),
  ShareCardKind.keepsake => keepsakeLine(l, d.keepsakeKey ?? ''),
};

/// The template's fixed palette (top, bottom, accent) — never the mood hue.
({Color top, Color bottom, Color accent}) _palette(ShareCardKind kind) =>
    switch (kind) {
      ShareCardKind.evolution => (
        top: const Color(0xFF1B1640),
        bottom: const Color(0xFF07081A),
        accent: AuraColors.lavender,
      ),
      ShareCardKind.glow => (
        top: const Color(0xFF2B1D14),
        bottom: const Color(0xFF0B0913),
        accent: AuraColors.starlight,
      ),
      ShareCardKind.capsuleAnniversary => (
        top: const Color(0xFF12213D),
        bottom: const Color(0xFF060A18),
        accent: AuraColors.moonlight,
      ),
      ShareCardKind.keepsake => (
        top: const Color(0xFF2A1633),
        bottom: const Color(0xFF0A0714),
        accent: const Color(0xFFF3C6DE),
      ),
    };

/// A share card (PRD F13): the avatar on its Still tier (stage, rings, glow,
/// stars, cosmetics) on the template's fixed palette, the milestone line, the
/// wordmark and the store line. Built only from [ShareCardData]'s whitelisted
/// fields. Static: no animation, so it looks the same under Reduce Motion and
/// in the exported image.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final line = shareCardLine(l, data);
    final p = _palette(data.kind);
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      image: true,
      label: l.share_cardSemantic(line, stageName(l, data.stage)),
      child: ExcludeSemantics(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: shareCardDesignSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.top, p.bottom],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StarfieldPainter(p.accent, data.kind.index),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                    child: Column(
                      children: [
                        Text(
                          l.appTitle,
                          key: const ValueKey('share-card-wordmark'),
                          style: t.headlineSmall?.copyWith(
                            color: AuraColors.text,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Spacer(),
                        SizedBox.square(
                          dimension: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _CardAvatar(data: data),
                              if (data.kind == ShareCardKind.keepsake &&
                                  data.keepsakeKey != null)
                                Align(
                                  alignment: const Alignment(0.78, 0.82),
                                  child: KeepsakeSeal(
                                    keepsakeKey: data.keepsakeKey!,
                                    size: 104,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          line,
                          key: const ValueKey('share-card-line'),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: t.headlineSmall?.copyWith(
                            color: AuraColors.text,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          l.share_storeLine,
                          key: const ValueKey('share-card-store'),
                          textAlign: TextAlign.center,
                          style: t.bodySmall?.copyWith(color: p.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar frozen on the Still tier (fixed time), from the card's own
/// state (template hue, never resting).
class _CardAvatar extends ConsumerWidget {
  const _CardAvatar({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuraAvatarView(
    key: const ValueKey('share-card-avatar'),
    state: data.avatar,
    assets: ref.watch(avatarAssetsProvider).value,
    size: const Size.square(280),
    tier: AvatarTier.still,
    fixedTime: 0,
  );
}

/// A few fixed stars (seeded per template, the same on every phone).
class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.accent, this.seed);

  final Color accent;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(1301 + seed);
    for (var i = 0; i < 70; i++) {
      final p = Offset(
        r.nextDouble() * size.width,
        r.nextDouble() * size.height,
      );
      final big = r.nextDouble() < 0.12;
      canvas.drawCircle(
        p,
        big ? 1.4 : 0.7,
        Paint()
          ..color = (big ? accent : Colors.white).withValues(
            alpha: 0.25 + r.nextDouble() * 0.5,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) =>
      old.seed != seed || old.accent != accent;
}
