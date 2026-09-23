import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/db/kv_store.dart';
import '../../core/theme/aura_tokens.dart';

/// The community guidelines version this build's copy is (F9: versioned,
/// re-shown on material change). Bump it with the copy; the server's
/// `safety_config.guidelines_version` is raised once that release is out
/// (contracts/api/v1-rooms.md §2.4).
const int roomGuidelinesVersion = 1;

/// The version the server has on record for this account, cached on this
/// phone (per account: wiped with everything else at sign-out). Only a
/// cache that saves a round trip: the server decides, and its
/// `409 guidelines_required` brings the guidelines back (REQ-SAFE-04).
const String roomGuidelinesKey = 'rooms.guidelines_accepted';

/// Whether the cache says this build's guidelines (or newer) are on record.
Future<bool> roomGuidelinesCached(KvStore kv) async {
  try {
    final cached = int.tryParse(await kv.get(roomGuidelinesKey) ?? '');
    return cached != null && cached >= roomGuidelinesVersion;
  } on Object catch (e) {
    debugPrint('rooms: guidelines read (${e.runtimeType})');
    return false;
  }
}

/// Caches that the server recorded [version].
Future<void> cacheRoomGuidelines(KvStore kv, int version) async {
  try {
    await kv.set(roomGuidelinesKey, '$version');
  } on Object catch (e) {
    // Only the cache: the server has the acceptance either way.
    debugPrint('rooms: guidelines write (${e.runtimeType})');
  }
}

/// Drops the cache (the server asked for the guidelines again).
Future<void> forgetRoomGuidelines(KvStore kv) async {
  try {
    await kv.set(roomGuidelinesKey, null);
  } on Object catch (e) {
    debugPrint('rooms: guidelines clear (${e.runtimeType})');
  }
}

/// Shows the guidelines. `true` only for "I'll keep to these"; anything
/// else (Not now, close, back, a tap outside) never enters a room.
Future<bool> showRoomGuidelines(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => const RoomGuidelinesSheet(),
  );
  return agreed == true;
}

/// "Before your first room": what keeps rooms gentle, how to report, block
/// and mute, and that help is always one tap away.
class RoomGuidelinesSheet extends StatelessWidget {
  const RoomGuidelinesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final rules = [
      l.rooms_rule1,
      l.rooms_rule2,
      l.rooms_rule3,
      l.rooms_rule4,
      l.rooms_rule5,
      l.rooms_rule6,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('rooms-guidelines'),
              controller: controller,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AuraSpace.gutter,
                0,
                AuraSpace.gutter,
                AuraSpace.l,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AuraSpace.s),
                        child: Semantics(
                          header: true,
                          child: Text(
                            l.rooms_guidelinesTitle,
                            style: t.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.common_close,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s),
                Text(
                  l.rooms_guidelinesIntro,
                  style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
                ),
                const SizedBox(height: AuraSpace.l),
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.m),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AuraColors.lavender,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.m),
                        Expanded(child: Text(rule, style: t.bodyLarge)),
                      ],
                    ),
                  ),
                const SizedBox(height: AuraSpace.s),
                Text(
                  l.rooms_guidelinesSafety,
                  style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
                ),
              ],
            ),
          ),
          // Always in view, whatever the text size: the choice never hides
          // below the rules.
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AuraColors.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.gutter,
                  AuraSpace.m,
                  AuraSpace.gutter,
                  AuraSpace.s,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('rooms-guidelines-agree'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        l.rooms_guidelinesAgree,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('rooms-guidelines-later'),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l.common_notNow),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
