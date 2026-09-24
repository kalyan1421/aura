import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/plus.dart';
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../sanctuary/sounds/sounds_controller.dart';
import 'paywall_gate.dart';
import 'plus_entry.dart';
import 'purchase_controller.dart';
import 'sky_themes.dart';

/// "Your sky" (F12 cosmetics + soundscape pairing): the personal sky for the
/// person's own Home, Sanctuary and Insights, and the soundscape it pairs
/// with. Free sky; Plus skies while Plus is on; cosmetic skies bought once in
/// the store (restorable) or with Stardust. Never shown to strangers.
class SkyThemesScreen extends ConsumerStatefulWidget {
  const SkyThemesScreen({super.key});

  @override
  ConsumerState<SkyThemesScreen> createState() => _SkyThemesScreenState();
}

class _SkyThemesScreenState extends ConsumerState<SkyThemesScreen> {
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(purchaseControllerProvider.notifier).load({
        for (final s in skyThemes)
          if (s.tier == SkyTier.cosmetic) s.productId,
      });
    });
  }

  Future<void> _run(Future<Entitlement> Function() call) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final l = AppLocalizations.of(context);
    try {
      final e = await call();
      await ref.read(entitlementProvider.notifier).apply(e);
    } on ApiException catch (e) {
      setState(
        () => _message = e.code == 'not_enough_stardust'
            ? l.plus_skyNotEnough
            : l.plus_validationFailed,
      );
    } on Object {
      setState(() => _message = l.plus_storeUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final e = ref.watch(entitlementProvider);
    final api = ref.watch(billingApiProvider);
    final products = ref.watch(purchaseControllerProvider).products;
    final current = e.availableSkies.contains(e.sky) ? e.sky : 'night';

    Widget tile(SkyTheme s) {
      final available = e.availableSkies.contains(s.id);
      final inUse = current == s.id;
      final tag = inUse
          ? l.plus_skyInUse
          : switch (s.tier) {
              SkyTier.free => l.plus_skyFree,
              SkyTier.plus => l.plus_skyWithPlus,
              SkyTier.cosmetic when e.ownedCosmetics.contains(s.id) =>
                l.plus_skyOwned,
              SkyTier.cosmetic => '',
            };
      final store = products[s.productId];
      return Card(
        key: ValueKey('sky-${s.id}'),
        color: AuraColors.surface.withValues(alpha: 0.7),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkyPreview(palette: s.palette),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name(l), style: t.titleSmall),
                    if (tag.isNotEmpty)
                      Text(
                        tag,
                        style: t.labelSmall?.copyWith(
                          color: AuraColors.lavender,
                        ),
                      ),
                    const SizedBox(height: AuraSpace.xs),
                    if (available && !inUse)
                      TextButton(
                        key: ValueKey('sky-use-${s.id}'),
                        onPressed: _busy || api == null
                            ? null
                            : () => _run(
                                () => api.setSky(
                                  s.id,
                                  e.soundscape ?? s.soundscape,
                                ),
                              ),
                        child: Text(l.plus_skyUse),
                      ),
                    if (!available && s.tier == SkyTier.plus)
                      TextButton(
                        key: ValueKey('sky-plus-${s.id}'),
                        onPressed: () => showPlusNoteSheet(
                          context,
                          surface: PaywallSurface.plusSky,
                          explainer: l.plus_explainerSky,
                        ),
                        child: Text(l.plus_skyWithPlus),
                      ),
                    if (!available && s.tier == SkyTier.cosmetic)
                      Wrap(
                        spacing: AuraSpace.s,
                        children: [
                          if (store != null)
                            OutlinedButton(
                              key: ValueKey('sky-buy-${s.id}'),
                              onPressed: _busy
                                  ? null
                                  : () => ref
                                        .read(
                                          purchaseControllerProvider.notifier,
                                        )
                                        .buy(s.productId),
                              child: Text(l.plus_skyBuy(store.price)),
                            ),
                          if (s.stardust != null)
                            TextButton(
                              key: ValueKey('sky-stardust-${s.id}'),
                              onPressed:
                                  _busy ||
                                      api == null ||
                                      e.stardust < s.stardust!
                                  ? null
                                  : () => _run(
                                      () => api.redeem(s.id, const Uuid().v7()),
                                    ),
                              child: Text(l.plus_skyStardust(s.stardust!)),
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

    final pairing = e.soundscape;
    return Scaffold(
      appBar: helpAppBar(context, title: l.plus_skiesTitle),
      body: CosmicBackground(
        palette: ref.watch(personalSkyProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.gutter,
            AuraSpace.s,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            Text(
              l.plus_skiesIntro,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.s),
            Text(
              l.plus_stardustBalance(e.stardust),
              key: const ValueKey('sky-stardust-balance'),
              style: t.titleSmall,
            ),
            Text(
              l.plus_stardustNote,
              style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.l),
            for (final s in skyThemes) tile(s),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: AuraSpace.s),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_message!, key: const ValueKey('sky-message')),
                ),
              ),
            const SizedBox(height: AuraSpace.xl),
            Text(l.plus_soundscapeTitle, style: t.titleSmall),
            const SizedBox(height: AuraSpace.s),
            Wrap(
              spacing: AuraSpace.s,
              runSpacing: AuraSpace.s,
              children: [
                for (final id in [null, ...soundscapes.keys])
                  ChoiceChip(
                    key: ValueKey('soundscape-${id ?? 'none'}'),
                    label: Text(soundscapeName(l, id)),
                    selected: pairing == id,
                    onSelected: _busy || api == null
                        ? null
                        : (_) => _run(() => api.setSky(current, id)),
                  ),
              ],
            ),
            if (soundscapeMix(pairing) != null)
              Padding(
                padding: const EdgeInsets.only(top: AuraSpace.s),
                child: TextButton.icon(
                  key: const ValueKey('soundscape-play'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.plus_soundscapePlay),
                  onPressed: () => ref
                      .read(soundsControllerProvider.notifier)
                      .playMix(soundscapeMix(pairing)!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
