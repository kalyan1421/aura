import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import 'share_card.dart';
import 'share_card_data.dart';
import 'share_gateway.dart';
import 'share_link.dart';

/// Opens the preview of a share card with its Share button (PRD F13). The
/// card is made and shared on this phone; nothing is sent to Aura's server and
/// nothing is earned or recorded for sharing (REQ-SHR-03).
Future<void> showShareCardSheet(BuildContext context, ShareCardData data) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShareCardSheet(data: data),
    );

/// Renders the card behind [boundary] as a PNG, 1080 px wide (9:16 →
/// 1080×1920); on failure (e.g. low memory) retries at 720×1280.
Future<Uint8List> renderShareCardPng(GlobalKey boundary) async {
  try {
    return await _capture(boundary, 1080);
  } on Object {
    return _capture(boundary, 720);
  }
}

Future<Uint8List> _capture(GlobalKey key, int width) async {
  final render = key.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary) {
    throw StateError('share card is not on screen');
  }
  final image = await render.toImage(pixelRatio: width / render.size.width);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('no PNG bytes');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class ShareCardSheet extends ConsumerStatefulWidget {
  const ShareCardSheet({super.key, required this.data});

  final ShareCardData data;

  @override
  ConsumerState<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends ConsumerState<ShareCardSheet> {
  final GlobalKey _boundary = GlobalKey(debugLabel: 'share-card');
  final GlobalKey _button = GlobalKey(debugLabel: 'share-button');
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final png = await renderShareCardPng(_boundary);
      final time = ref.read(timeContextProvider);
      final allowed = await shareTokenAllowed(
        ref.read(kvStoreProvider),
        time.today(),
      );
      final link = shareLink(token: allowed ? newShareToken() : null);
      final box = _button.currentContext?.findRenderObject() as RenderBox?;
      await ref
          .read(shareGatewayProvider)
          .shareImage(
            png,
            text: l.share_text(link.toString()),
            origin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          );
      if (mounted) Navigator.of(context).maybePop();
    } on Object {
      messenger?.showSnackBar(SnackBar(content: Text(l.share_failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // 9:16 preview whose width divides 1080 and 720 cleanly.
    final width = MediaQuery.sizeOf(context).height < 700 ? 180.0 : 216.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.share_sheetTitle, style: t.titleLarge),
          const SizedBox(height: AuraSpace.l),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.s),
              child: RepaintBoundary(
                key: _boundary,
                child: SizedBox(
                  width: width,
                  height: width * 16 / 9,
                  child: ShareCard(data: widget.data),
                ),
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          Text(
            l.share_sheetNote,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.l),
          FilledButton.icon(
            key: _button,
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(l.share_button),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('share-not-now'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.common_notNow),
          ),
        ],
      ),
    );
  }
}
