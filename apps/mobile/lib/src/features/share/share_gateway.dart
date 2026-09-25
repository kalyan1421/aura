import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// The OS share sheet, and nothing else (PRD: no social SDKs, no pixels). Its
/// own "Save image" covers saving, so no photo-library permission exists.
abstract interface class ShareGateway {
  Future<void> shareImage(Uint8List png, {required String text, Rect? origin});
}

class SharePlusGateway implements ShareGateway {
  const SharePlusGateway();

  @override
  Future<void> shareImage(
    Uint8List png, {
    required String text,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: 'aura.png')],
        fileNameOverrides: const ['aura.png'],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }
}

final shareGatewayProvider = Provider<ShareGateway>(
  (ref) => const SharePlusGateway(),
);
