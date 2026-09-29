import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/inline_notice.dart';
import 'room_copy.dart';
import 'room_models.dart';
import 'rooms_providers.dart';
import 'rooms_repository.dart';

/// A rooms failure in calm words (PRD States: warm, no blame), with "Try
/// again" when trying again can help. A suspension says until when (from
/// `GET /v1/safety/me`, which keeps working while suspended).
class RoomsFailureNotice extends ConsumerStatefulWidget {
  const RoomsFailureNotice({
    super.key,
    required this.failure,
    this.joining = false,
    this.opening = false,
    this.onRetry,
  });

  final RoomsFailure failure;

  /// After a check-in: "Your check-in is saved".
  final bool joining;

  /// Opening one room.
  final bool opening;
  final Future<void> Function()? onRetry;

  @override
  ConsumerState<RoomsFailureNotice> createState() => _RoomsFailureNoticeState();
}

class _RoomsFailureNoticeState extends ConsumerState<RoomsFailureNotice> {
  DateTime? _until;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.failure.kind == RoomsFailureKind.suspended) {
      unawaited(_loadUntil());
    }
  }

  Future<void> _loadUntil() async {
    try {
      final SafetyStanding standing = await ref
          .read(roomsRepositoryProvider)
          .standing();
      if (mounted && standing.until != null) {
        setState(() => _until = standing.until);
      }
    } on RoomsFailure {
      // The plain wording is fine.
    }
  }

  Future<void> _retry() async {
    final retry = widget.onRetry;
    if (retry == null || _busy) return;
    setState(() => _busy = true);
    try {
      await retry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = widget.failure;
    final until = _until;
    final text = f.kind == RoomsFailureKind.suspended && until != null
        ? l.rooms_suspendedUntil(roomDate(context, until))
        : roomsFailureText(
            l,
            f,
            joining: widget.joining,
            opening: widget.opening,
          );
    final canRetry =
        widget.onRetry != null &&
        (f.isTransient ||
            f.kind == RoomsFailureKind.profileRequired ||
            f.kind == RoomsFailureKind.other);
    return InlineNotice(
      text,
      key: ValueKey('rooms-failure-${f.kind.name}'),
      icon: f.kind == RoomsFailureKind.offline
          ? Icons.cloud_off_outlined
          : Icons.info_outline_rounded,
      action: canRetry
          ? TextButton(
              key: const ValueKey('rooms-retry'),
              onPressed: _busy ? null : _retry,
              child: Text(l.rooms_tryAgain),
            )
          : f.kind == RoomsFailureKind.signedOut &&
                GoRouter.maybeOf(context) != null
          ? TextButton(
              key: const ValueKey('rooms-failure-sign-in'),
              onPressed: () => context.push(Routes.signIn),
              child: Text(l.rooms_signIn),
            )
          : null,
    );
  }
}
