import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/a11y/haptics.dart';
import '../../core/a11y/icon_scale.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/a11y/motion.dart';
import '../../core/widgets/inline_notice.dart';
import '../account/account_providers.dart';
import '../account/deletion_pending.dart';
import '../checkin/quadrant_glyph.dart';
import '../reflections/reflections_section.dart';
import '../ripples/ripple_entry.dart';
import '../support/support_sheet.dart';
import 'intention_copy.dart';
import 'member_sheet.dart';
import 'report_sheet.dart';
import 'room_controller.dart';
import 'room_copy.dart';
import 'room_lantern.dart';
import 'room_models.dart';
import 'room_moments.dart';
import 'room_navigation.dart';
import 'room_realtime.dart';
import 'room_status.dart';
import 'gesture_tray.dart';
import 'room_widgets.dart';
import 'rooms_repository.dart';
import 'wind_down_entry.dart';

/// One mood room (`/rooms/:id`, F5): who is here (silhouettes with mood
/// chips, real counts), the warmth sent, and the 8 gestures. Help sits in
/// the top bar in every state, a memory included; report, block and mute
/// are one tap into a member (REQ-ROOM-08). Stranger-facing data is only
/// `{memberId, pseudonym, silhouette, moodChip}` (DS-10).
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

/// A calm note under the room header (stays until closed).
@immutable
class _Notice {
  const _Notice(this.text, {this.undo});

  final String text;
  final VoidCallback? undo;
}

enum _MenuChoice { report, leave }

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final List<GestureMoment> _moments = [];
  _Notice? _notice;

  /// The room's list; a new notice scrolls it to the top so the notice is
  /// seen wherever the tap that caused it was (e.g. "Hold this tonight").
  final ScrollController _list = ScrollController();
  _Notice? _revealed;

  /// The last gesture you sent, shown while the tray rests.
  String? _lastSent;

  /// Asked (or answered) "Did you feel less alone?" on this visit.
  bool _surveyAsked = false;
  bool _exiting = false;

  /// Others' unnamed gestures are announced at most every 5 s (a busy
  /// room shouldn't talk over itself); yours and those to you always are.
  Timer? _roomAnnounceGate;

  RoomController get _controller =>
      ref.read(roomControllerProvider(widget.roomId).notifier);

  @override
  void dispose() {
    _roomAnnounceGate?.cancel();
    _list.dispose();
    super.dispose();
  }

  bool _asksSurvey(RoomViewState s) =>
      !_surveyAsked &&
      !s.left &&
      s.failure == null &&
      (s.detail?.me.surveyEligible ?? false);

  void _play(GestureMoment m) {
    final l = AppLocalizations.of(context);
    final text = momentText(l, m);
    switch (m.kind) {
      case GestureMomentKind.sent:
        _lastSent = text;
        announceRoom(context, text);
        AuraHaptics.light(); // restrained; off with Comfort → Haptics
      case GestureMomentKind.received:
        announceRoom(context, text);
        AuraHaptics.selection();
      case GestureMomentKind.room:
        if (_roomAnnounceGate == null) {
          announceRoom(context, text);
          _roomAnnounceGate = Timer(const Duration(seconds: 5), () {
            _roomAnnounceGate = null;
          });
        }
    }
    if (!m.animate && m.kind != GestureMomentKind.received) return;
    setState(() {
      _moments.add(m);
      if (_moments.length > 6) _moments.removeAt(0);
    });
  }

  // ---- leaving the screen -----------------------------------------------------

  Future<void> _back() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    // Opened on its own (a link): the Rooms tab, after the survey.
    if (_asksSurvey(ref.read(roomControllerProvider(widget.roomId)))) {
      await _askSurvey();
    }
    if (mounted) openRoomsTab(context);
  }

  /// Back was held for the exit survey: ask, then go.
  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    await _askSurvey();
    _exiting = false;
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _askSurvey() async {
    setState(() => _surveyAsked = true);
    final answer = await showRoomSurvey(context);
    unawaited(_controller.answerSurvey(answer ?? SurveyAnswer.skip));
  }

  // ---- actions --------------------------------------------------------------------

  Future<void> _openMember(RoomMember member) async {
    final choice = await showMemberSheet(
      context,
      roomId: widget.roomId,
      member: member,
    );
    if (!mounted || choice == null) return;
    final gesture = choice.gesture;
    if (gesture != null) {
      _controller.sendGesture(gesture, to: member);
      return;
    }
    switch (choice.action!) {
      case MemberAction.report:
        await _report(
          MemberReportTarget(widget.roomId, member.memberId),
          pseudonym: member.pseudonym,
        );
      case MemberAction.block:
        await _block(member);
      case MemberAction.mute:
        await _mute(member, muted: true);
      case MemberAction.unmute:
        await _mute(member, muted: false);
    }
  }

  Future<void> _report(ReportTarget target, {String? pseudonym}) async {
    final outcome = await showReportSheet(
      context,
      target: target,
      pseudonym: pseudonym,
    );
    if (!mounted || outcome == null) return;
    _controller.reported(target, outcome.reason);
    final l = AppLocalizations.of(context);
    setState(
      () => _notice = _Notice(
        outcome.showHelplines
            ? l.rooms_reportCrisis
            : switch (target) {
                MemberReportTarget() => l.rooms_reportHidden,
                GestureReportTarget() => l.rooms_reportGestureHidden,
                RoomReportTarget() => l.rooms_reportThanks,
                ReflectionReportTarget() => l.reflections_reportHidden,
              },
      ),
    );
    // Crisis lane: the reporter sees helplines at once (F9).
    if (outcome.showHelplines) openSafetyCenter(context);
  }

  Future<void> _block(RoomMember member) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('block-confirm'),
        title: Semantics(
          header: true,
          child: Text(l.rooms_blockTitle(member.pseudonym)),
        ),
        content: SingleChildScrollView(child: Text(l.rooms_blockBody)),
        actions: [
          TextButton(
            key: const ValueKey('block-cancel'),
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.common_cancel),
          ),
          FilledButton.icon(
            key: const ValueKey('block-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: Text(l.rooms_block),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _controller.block(member);
    if (!mounted) return;
    setState(
      () => _notice = _Notice(
        done ? l.rooms_blocked(member.pseudonym) : l.rooms_actionFailed,
      ),
    );
  }

  Future<void> _mute(RoomMember member, {required bool muted}) async {
    final l = AppLocalizations.of(context);
    final done = await _controller.setMuted(member, muted: muted);
    if (!mounted) return;
    setState(
      () => _notice = !done
          ? _Notice(l.rooms_actionFailed)
          : muted
          ? _Notice(
              l.rooms_muted(member.pseudonym),
              undo: () => unawaited(_mute(member, muted: false)),
            )
          : _Notice(l.rooms_unmuted(member.pseudonym)),
    );
  }

  Future<void> _openMenu(RoomViewState s) async {
    final l = AppLocalizations.of(context);
    final memory = s.isMemory;
    final choice = await showModalBottomSheet<_MenuChoice>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          key: const ValueKey('room-menu'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('room-menu-report'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l.rooms_reportRoom),
              onTap: () => Navigator.of(context).pop(_MenuChoice.report),
            ),
            ListTile(
              key: const ValueKey('room-menu-leave'),
              leading: const Icon(Icons.logout_rounded),
              title: Text(memory ? l.rooms_removeMemory : l.rooms_leave),
              onTap: () => Navigator.of(context).pop(_MenuChoice.leave),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _MenuChoice.report:
        await _report(RoomReportTarget(widget.roomId));
      case _MenuChoice.leave:
        await _leave(memory: memory);
    }
  }

  Future<void> _leave({required bool memory}) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('leave-confirm'),
        title: Semantics(
          header: true,
          child: Text(memory ? l.rooms_removeTitle : l.rooms_leaveTitle),
        ),
        content: SingleChildScrollView(
          child: Text(memory ? l.rooms_removeBody : l.rooms_leaveBody),
        ),
        actions: [
          TextButton(
            key: const ValueKey('leave-stay'),
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(memory ? l.rooms_keep : l.rooms_stay),
          ),
          FilledButton(
            key: const ValueKey('leave-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(memory ? l.rooms_removeConfirm : l.rooms_leaveConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final eligible = await _controller.leave();
    if (!mounted) return;
    if (eligible == null) {
      setState(() => _notice = _Notice(l.rooms_leaveFailed));
      return;
    }
    if (eligible && !_surveyAsked) {
      await _askSurvey();
      if (!mounted) return;
    }
    _surveyAsked = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      openRoomsTab(context);
    }
  }

  // ---- lanterns (Milestone B) ---------------------------------------------------------

  /// Tonight's lantern and intention (room totals only), under the header.
  /// Nothing before the room's first Lantern Hour; in the memory the
  /// lantern stays as "Tonight's lantern".
  List<Widget> _lanternSection(RoomViewState s) {
    final l = AppLocalizations.of(context);
    final room = s.detail!.room;
    final lantern = room.lantern;
    final intention = room.intention;
    // The console's words first (GET /v1/intentions), then the bundled ones.
    final text = intention == null
        ? null
        : serverIntentionText(
                ref.watch(intentionCopyProvider).value,
                intention.key,
                Localizations.localeOf(context),
              ) ??
              intentionText(l, intention.key);
    return [
      if (lantern != null) ...[
        const SizedBox(height: AuraSpace.m),
        RoomLanternCard(lantern: lantern),
      ],
      if (intention != null && text != null && !room.isMemory) ...[
        const SizedBox(height: AuraSpace.m),
        IntentionCard(
          intention: intention,
          text: text,
          holding: s.detail!.me.holdingIntention,
          canHold: s.canHoldIntention,
          onHold: () => unawaited(_holdIntention()),
        ),
      ],
    ];
  }

  Future<void> _holdIntention() async {
    final l = AppLocalizations.of(context);
    AuraHaptics.selection();
    final ok = await _controller.holdIntention();
    if (!mounted || ok) return;
    setState(() => _notice = _Notice(l.rooms_intentionFailed));
  }

  // ---- build ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = roomControllerProvider(widget.roomId);
    final s = ref.watch(provider);
    ref.listen(provider.select((s) => s.moment), (prev, next) {
      if (next != null && next.serial != prev?.serial) _play(next);
    });
    // The lantern just became fully lit while you're here: one shared
    // moment, with words for screen readers (REQ-A11Y-16).
    ref.listen(provider.select((s) => s.lanternRise), (prev, next) {
      if (next > (prev ?? 0)) announceRoom(context, l.rooms_lanternRise);
    });
    final d = s.detail;
    final title = d == null ? l.rooms_title : roomThemeName(l, d.room.theme);
    final quadrant = d?.room.quadrantValue;
    final showRoom = d != null && !s.left && s.failure == null;

    return PopScope(
      canPop: !_asksSurvey(s),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        appBar: helpAppBar(
          context,
          title: title,
          leading: BackButton(onPressed: () => unawaited(_back())),
        ),
        body: CosmicBackground(
          tint: quadrant == null ? null : AuraColors.quadrant(quadrant),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showRoom && s.lanternActive)
                const Positioned.fill(child: LanternGlow()),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(child: _body(s)),
                    if (showRoom)
                      d.room.isMemory
                          ? const _MemoryFooter()
                          : _GestureTray(
                              enabled: s.canSend,
                              status: s.coolingDown ? _lastSent : null,
                              onSend: (g) => _controller.sendGesture(g),
                            ),
                  ],
                ),
              ),
              Positioned.fill(child: LanternRiseLayer(serial: s.lanternRise)),
              Positioned.fill(
                child: RoomMomentLayer(
                  moments: _moments,
                  onDone: (m) => setState(() => _moments.remove(m)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(RoomViewState s) {
    final l = AppLocalizations.of(context);
    final d = s.detail;
    final failure = s.failure;
    final held = ref.watch(deletionHoldProvider) != null;
    if (s.left) return const SizedBox.shrink();
    if (failure != null && (d == null || failure.isTerminal)) {
      return ListView(
        padding: const EdgeInsets.all(AuraSpace.gutter),
        children: [
          if (held || failure.kind == RoomsFailureKind.deletionPending)
            const DeletionPendingCard()
          else
            RoomsFailureNotice(
              failure: failure,
              opening: true,
              onRetry: failure.isTerminal ? null : _controller.retry,
            ),
          if (failure.kind == RoomsFailureKind.notFound) ...[
            const SizedBox(height: AuraSpace.l),
            Center(
              child: FilledButton(
                key: const ValueKey('room-back-to-rooms'),
                onPressed: () => openRoomsTab(context),
                child: Text(l.rooms_backToRooms),
              ),
            ),
          ],
        ],
      );
    }
    if (d == null) return const _Opening();
    final notice = _notice;
    if (notice != null && !identical(notice, _revealed)) {
      _revealed = notice;
      final reduce = reduceMotionOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_list.hasClients || _list.offset <= 0) return;
        if (reduce) {
          _list.jumpTo(0);
        } else {
          unawaited(
            _list.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      });
    }
    return ListView(
      key: const ValueKey('room-list'),
      controller: _list,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.s,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      children: [
        if (held) ...[
          const DeletionPendingCard(),
          const SizedBox(height: AuraSpace.m),
        ],
        if (notice != null) ...[
          InlineNotice(
            notice.text,
            key: const ValueKey('room-notice'),
            action: Wrap(
              spacing: AuraSpace.s,
              children: [
                if (notice.undo != null)
                  TextButton(
                    key: const ValueKey('room-notice-undo'),
                    onPressed: () {
                      setState(() => _notice = null);
                      notice.undo!();
                    },
                    child: Text(l.rooms_undo),
                  ),
                TextButton(
                  key: const ValueKey('room-notice-close'),
                  onPressed: () => setState(() => _notice = null),
                  child: Text(l.common_close),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.m),
        ],
        _Header(state: s, onMenu: () => unawaited(_openMenu(s))),
        ..._lanternSection(s),
        // F7: "Breathe together" and the room's invite banner (entry only).
        const SizedBox(height: AuraSpace.m),
        RoomRippleEntry(roomId: widget.roomId, readOnly: d.room.isMemory),
        // F16 (Milestone C): the Lantern Hour wind-down, from 22:30.
        RoomWindDownEntry(roomId: widget.roomId, readOnly: d.room.isMemory),
        const SizedBox(height: AuraSpace.xl),
        _Members(detail: d, onOpen: (m) => unawaited(_openMember(m))),
        const SizedBox(height: AuraSpace.xl),
        _Recent(
          detail: d,
          onReport: (g) => unawaited(
            _report(GestureReportTarget(widget.roomId, g.gestureId)),
          ),
        ),
        // Reflections (F6): nothing at all in a build without the API.
        const SizedBox(height: AuraSpace.xl),
        ReflectionsSection(roomId: widget.roomId, detail: d),
      ],
    );
  }
}

/// "Did you feel less alone?" on exit (≥ 30 s in the room, at most once a
/// day; the server decides). Closing it counts as Skip.
Future<SurveyAnswer?> showRoomSurvey(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<SurveyAnswer>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      key: const ValueKey('room-survey'),
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.gutter,
        AuraSpace.l,
        AuraSpace.gutter,
        AuraSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.rooms_surveyTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AuraSpace.l),
          FilledButton(
            key: const ValueKey('survey-yes'),
            onPressed: () => Navigator.of(context).pop(SurveyAnswer.yes),
            child: Text(l.rooms_surveyYes),
          ),
          const SizedBox(height: AuraSpace.s),
          OutlinedButton(
            key: const ValueKey('survey-no'),
            onPressed: () => Navigator.of(context).pop(SurveyAnswer.no),
            child: Text(l.rooms_surveyNo),
          ),
          const SizedBox(height: AuraSpace.s),
          TextButton(
            key: const ValueKey('survey-skip'),
            onPressed: () => Navigator.of(context).pop(SurveyAnswer.skip),
            child: Text(l.rooms_surveySkip),
          ),
        ],
      ),
    ),
  );
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AuraColors.lavender,
              ),
            ),
            const SizedBox(height: AuraSpace.l),
            Semantics(
              liveRegion: true,
              child: Text(
                l.rooms_opening,
                key: const ValueKey('room-opening'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AuraColors.textSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Counts, your name here, the room's moment (Lantern Hour, closing,
/// memory, cold start), the realtime link, and the room menu.
class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onMenu});

  final RoomViewState state;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final d = state.detail!;
    final room = d.room;
    final counts = d.counts;
    final memory = room.isMemory;
    final coldStart = !memory && counts.hereNow <= 1;
    final String? line = memory
        ? l.rooms_memory
        : room.phase == RoomPhase.closing
        ? l.rooms_closing(roomTime(context, room.memoryAt))
        : coldStart
        ? l.rooms_coldStart(counts.today)
        : null;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.l),
      decoration: BoxDecoration(
        color: AuraColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AuraRadius.l),
        border: Border.all(color: AuraColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(
                  child: QuadrantGlyph(room.quadrantValue, size: 28),
                ),
              ),
              const SizedBox(width: AuraSpace.m),
              Expanded(
                child: Semantics(
                  key: const ValueKey('room-counts'),
                  container: true,
                  label: l.rooms_countsSemantic(counts.hereNow, counts.today),
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.rooms_hereNow(counts.hereNow),
                        style: t.titleMedium,
                      ),
                      Text(
                        l.rooms_today(counts.today),
                        style: t.bodyMedium?.copyWith(
                          color: AuraColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('room-menu-button'),
                tooltip: l.rooms_roomOptions,
                onPressed: onMenu,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          if (state.lanternActive) ...[
            const SizedBox(height: AuraSpace.m),
            Row(
              key: const ValueKey('room-lantern'),
              children: [
                const ExcludeSemantics(child: LanternGlyph()),
                const SizedBox(width: AuraSpace.s),
                Flexible(
                  child: Text(
                    l.rooms_lanternOn(
                      roomTime(context, room.lanternHour.endsAt),
                    ),
                    style: t.labelLarge?.copyWith(color: AuraColors.starlight),
                  ),
                ),
              ],
            ),
          ],
          if (state.link == RoomLink.reconnecting) ...[
            const SizedBox(height: AuraSpace.m),
            const ReconnectingChip(),
          ],
          const SizedBox(height: AuraSpace.m),
          Text(
            l.rooms_youAre(d.me.pseudonym),
            key: const ValueKey('room-you-are'),
            style: t.bodyMedium?.copyWith(color: AuraColors.lavender),
          ),
          if (line != null) ...[
            const SizedBox(height: AuraSpace.s),
            Text(
              line,
              key: ValueKey(
                memory
                    ? 'room-memory'
                    : room.phase == RoomPhase.closing
                    ? 'room-closing'
                    : 'room-cold-start',
              ),
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// Everyone here, you first: silhouette, pseudonym and mood chip. Tap
/// someone for gestures, report, block and mute.
class _Members extends ConsumerWidget {
  const _Members({required this.detail, required this.onOpen});

  final RoomDetail detail;
  final ValueChanged<RoomMember> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tag = ref.watch(localeControllerProvider);
    final members = [
      ...detail.members.where((m) => m.isMe),
      ...detail.members.where((m) => !m.isMe),
    ];
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l.rooms_membersTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AuraSpace.m),
        LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final perRow = (box.maxWidth / (104 * scale.clamp(1.0, 1.8)))
                .floor()
                .clamp(1, 4);
            final width = (box.maxWidth - (perRow - 1) * AuraSpace.s) / perRow;
            return Wrap(
              spacing: AuraSpace.s,
              runSpacing: AuraSpace.s,
              children: [
                for (final m in members)
                  SizedBox(
                    width: width,
                    child: _MemberTile(
                      member: m,
                      mood: moodChipName(m.moodChip, tag),
                      onTap: m.isMe ? null : () => onOpen(m),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.mood, this.onTap});

  final RoomMember member;
  final String mood;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final m = member;
    final status = m.muted
        ? l.rooms_memberMuted
        : m.live
        ? l.rooms_memberHereNow
        : l.rooms_memberAway;
    final label = m.isMe
        ? l.rooms_youLabel(m.pseudonym, mood)
        : l.rooms_memberLabel(m.pseudonym, mood, status);
    return Semantics(
      button: !m.isMe,
      label: label,
      hint: m.isMe ? null : l.rooms_memberHint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: m.isMe
            ? AuraColors.surfaceHigh.withValues(alpha: 0.9)
            : AuraColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AuraRadius.m),
        child: InkWell(
          key: ValueKey('member-${m.memberId}'),
          borderRadius: BorderRadius.circular(AuraRadius.m),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RoomSilhouette(
                        silhouette: m.silhouette,
                        dimmed: m.muted || (!m.live && !m.isMe),
                      ),
                      if (m.live && !m.muted)
                        PositionedDirectional(
                          end: 2,
                          bottom: 4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AuraColors.starlight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AuraColors.sky,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      if (m.muted)
                        const PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.volume_off_rounded,
                            size: 16,
                            color: AuraColors.textSoft,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.xs),
                  Text(
                    m.isMe ? l.rooms_you : m.pseudonym,
                    textAlign: TextAlign.center,
                    style: t.labelLarge,
                  ),
                  if (m.isMe)
                    Text(
                      m.pseudonym,
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AuraColors.lavender),
                    ),
                  if (mood.isNotEmpty)
                    Text(
                      mood,
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
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

/// Recent warmth: gestures to you (named: only you ever learn who), yours,
/// and others' (unnamed). No tallies.
class _Recent extends StatelessWidget {
  const _Recent({required this.detail, required this.onReport});

  final RoomDetail detail;
  final ValueChanged<ReceivedGesture> onReport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final g = detail.gestures;
    final names = {for (final m in detail.members) m.memberId: m.pseudonym};
    final seen = <String>{};
    final rows =
        <
          ({
            DateTime at,
            GestureType type,
            String text,
            ReceivedGesture? received,
          })
        >[];
    for (final r in g.received) {
      final type = r.gesture;
      if (type == null || !seen.add(r.gestureId)) continue;
      rows.add((
        at: r.at,
        type: type,
        text: l.rooms_receivedLine(r.fromPseudonym, gestureName(l, type)),
        received: r,
      ));
    }
    for (final s in g.sent) {
      final type = s.gesture;
      if (type == null || !seen.add(s.gestureId)) continue;
      final to = s.toMemberId == null ? null : names[s.toMemberId];
      rows.add((
        at: s.at,
        type: type,
        text: s.target == 'room' || to == null
            ? l.rooms_youSentRoom(gestureName(l, type))
            : l.rooms_youSentMember(gestureName(l, type), to),
        received: null,
      ));
    }
    for (final r in g.recent) {
      final type = r.gesture;
      if (type == null || !seen.add(r.gestureId)) continue;
      rows.add((
        at: r.at,
        type: type,
        text: r.target == 'room'
            ? l.rooms_someoneSentRoom(gestureName(l, type))
            : l.rooms_someoneSent(gestureName(l, type)),
        received: null,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l.rooms_recentTitle, style: t.titleMedium),
        ),
        const SizedBox(height: AuraSpace.s),
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    gestureIcon(row.type),
                    size: 22,
                    color: AuraColors.starlight,
                  ),
                ),
                const SizedBox(width: AuraSpace.m),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.text, style: t.bodyMedium),
                        Text(roomTime(context, row.at), style: t.bodySmall),
                      ],
                    ),
                  ),
                ),
                if (row.received != null)
                  IconButton(
                    key: ValueKey('report-gesture-${row.received!.gestureId}'),
                    tooltip: l.rooms_reportGesture,
                    onPressed: () => onReport(row.received!),
                    icon: const Icon(Icons.flag_outlined, size: 20),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The 8 gestures, to everyone here, pinned under the room: the shared
/// [GestureTray] as one scrolling row that grows with the text (never cut);
/// rests for 2 s after a send with the words of what was sent. Above 130%
/// text the row would take a quarter of the screen, so it collapses to one
/// "Send warmth" button that opens the full grid in a sheet.
class _GestureTray extends StatelessWidget {
  const _GestureTray({
    required this.enabled,
    required this.onSend,
    this.status,
  });

  final bool enabled;
  final ValueChanged<GestureType> onSend;
  final String? status;

  /// Above this text scale the tray is one button.
  static const double _collapseAbove = 1.3;

  Future<void> _openSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        key: const ValueKey('gesture-tray-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.gutter,
          0,
          AuraSpace.gutter,
          AuraSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.rooms_trayTitle,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AuraSpace.m),
            GestureTray(
              density: GestureTrayDensity.grid,
              items: presetGestureItems(
                l,
                hint: l.rooms_trayHint,
                onSend: enabled
                    ? (g) {
                        Navigator.of(sheet).pop();
                        onSend(g);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final collapsed =
        MediaQuery.textScalerOf(context).scale(100) / 100 > _collapseAbove;
    final statusText = Text(
      status ?? l.rooms_trayTitle,
      key: const ValueKey('gesture-tray-status'),
      style: t.labelLarge?.copyWith(
        color: status == null ? AuraColors.textSoft : AuraColors.starlight,
      ),
    );
    return DecoratedBox(
      key: const ValueKey('gesture-tray'),
      decoration: BoxDecoration(
        color: AuraColors.skyHigh.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AuraColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AuraSpace.m, bottom: AuraSpace.s),
        child: collapsed
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.gutter,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status != null) ...[
                      statusText,
                      const SizedBox(height: AuraSpace.s),
                    ],
                    FilledButton.icon(
                      key: const ValueKey('gesture-tray-open'),
                      onPressed: enabled
                          ? () => unawaited(_openSheet(context))
                          : null,
                      icon: Icon(
                        Icons.volunteer_activism_outlined,
                        size: scaledIconSize(context, 20),
                      ),
                      label: Text(l.rooms_trayOpen),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.gutter,
                    ),
                    child: statusText,
                  ),
                  const SizedBox(height: AuraSpace.s),
                  GestureTray(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.gutter,
                    ),
                    items: presetGestureItems(
                      l,
                      hint: l.rooms_trayHint,
                      onSend: enabled ? onSend : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A memory is read-only: gestures rest; a new room comes from a check-in.
class _MemoryFooter extends StatelessWidget {
  const _MemoryFooter();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      key: const ValueKey('room-memory-footer'),
      decoration: BoxDecoration(
        color: AuraColors.skyHigh.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AuraColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.gutter,
          AuraSpace.m,
          AuraSpace.gutter,
          AuraSpace.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.rooms_trayResting,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AuraColors.textSoft),
            ),
            const SizedBox(height: AuraSpace.s),
            OutlinedButton(
              key: const ValueKey('room-find-new'),
              onPressed: () => openRoomCheckIn(context),
              child: Text(l.rooms_findNew),
            ),
          ],
        ),
      ),
    );
  }
}
