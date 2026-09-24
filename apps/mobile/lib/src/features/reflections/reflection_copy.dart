import '../../../l10n/app_localizations.dart';
import 'reflection_models.dart';

/// Reflections across rooms in a rolling 24 h (contracts §1.3).
const int reflectionsPerDay = 10;

/// Gentle words for a rejection, by category (PRD F6 "Rejected"; 14-states
/// "Error: rejected"). Never names a rule, never blames.
String rejectReasonText(AppLocalizations l, RejectReason? reason) =>
    switch (reason) {
      RejectReason.contactDetails => l.reflections_rejectedContact,
      RejectReason.link => l.reflections_rejectedLink,
      RejectReason.personalQuestions => l.reflections_rejectedPersonal,
      RejectReason.hurtful ||
      RejectReason.sexual ||
      RejectReason.other ||
      null => l.reflections_rejectedGeneral,
    };

/// Why the composer can't send right now, or `null` when it can: paused
/// (remote flags or the server's `composer.state`), today's limit, or a
/// memory room.
String? composerStateText(
  AppLocalizations l,
  ReflectionComposer? composer, {
  required bool allowed,
}) {
  if (!allowed) return l.reflections_paused;
  if (composer == null) return null;
  return switch (composer.stateValue) {
    ComposerState.open => null,
    ComposerState.paused => l.reflections_paused,
    ComposerState.readOnly => l.reflections_memory,
    ComposerState.limitReached => l.reflections_limit(
      composer.remainingInRoom <= 0 ? composer.perRoom : reflectionsPerDay,
    ),
  };
}

/// What only the author sees on their own reflection that isn't (or is no
/// longer) published; `null` for a published one.
String? ownStatusText(AppLocalizations l, Reflection r) =>
    switch (r.statusValue) {
      ReflectionStatus.published => null,
      ReflectionStatus.pending ||
      ReflectionStatus.unknown => l.reflections_pending,
      ReflectionStatus.held =>
        r.reviewValue == ReviewHint.overnight
            ? l.reflections_heldOvernight
            : l.reflections_heldSoon,
      ReflectionStatus.rejected => l.reflections_rejectedCard,
      ReflectionStatus.removed => l.reflections_removedCard,
      // Never listed; shown as checking if a server ever did.
      ReflectionStatus.crisisDiverted => l.reflections_pending,
    };
