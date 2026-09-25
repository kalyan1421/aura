import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';
import '../checkin/post_save.dart';
import '../onboarding/gate_controller.dart';
import 'widget_bridge.dart';
import 'widget_ingest.dart';

/// Runs the mood-trigger capsule step (F4) for check-ins the widget saved,
/// at the app open that imports them: PRD 12-notifications "after a widget
/// check-in it waits for the next app open", and F11 "Capsules never open
/// here" (the widget only said "Something from past you is waiting").
///
/// Only that step: a widget check-in gets no companion response, no "A
/// minute for you" and no room offer, now or later (PRD 06d "Widget
/// check-in: … nothing replays at the next app open"). There is no note, so
/// there is no crisis sheet, and the capsule is never held.
///
/// Sits above the router (`AuraApp`'s builder) and shows the card on the
/// root navigator once a screen is up and the gate allows the app.
class WidgetCheckInFollowUp extends ConsumerStatefulWidget {
  const WidgetCheckInFollowUp({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetCheckInFollowUp> createState() =>
      _WidgetCheckInFollowUpState();
}

class _WidgetCheckInFollowUpState extends ConsumerState<WidgetCheckInFollowUp> {
  ValueNotifier<List<ImportedWidgetCheckIn>>? _queue;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(widgetBridgeProvider).followUps..addListener(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    try {
      _queue?.removeListener(_drain);
    } catch (_) {
      // The bridge (and its notifier) went first.
    }
    super.dispose();
  }

  void _drain() => unawaited(_run());

  Future<void> _run() async {
    final queue = _queue;
    if (_running || !mounted || queue == null || queue.value.isEmpty) return;
    _running = true;
    var drained = false;
    try {
      final router = ref.read(routerProvider);
      for (var frame = 0; frame < 60; frame++) {
        if (router.routerDelegate.currentConfiguration.isNotEmpty) break;
        await WidgetsBinding.instance.endOfFrame;
      }
      final gate = ref.read(gateControllerProvider);
      if (!mounted || !gate.onboarded || gate.isBlocked) return;
      final batch = queue.value;
      queue.value = const [];
      drained = true;
      final step = ref.read(moodTriggerCapsuleStepProvider);
      for (final c in batch) {
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (!mounted || context == null || !context.mounted) return;
        await step(
          context,
          ref,
          checkInId: c.id,
          mood: c.mood,
          crisisShown: false,
        );
      }
    } finally {
      _running = false;
    }
    // Check-ins imported while the cards showed get their turn too.
    if (drained && mounted && queue.value.isNotEmpty) _drain();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
