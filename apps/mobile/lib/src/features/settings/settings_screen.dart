import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../companion/prompts.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/a11y/motion.dart';
import '../../core/env/env.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/prefs/comfort_prefs.dart';
import '../../core/providers.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/cosmic_background.dart';
import '../../core/widgets/help_app_bar.dart';
import '../../core/widgets/inline_notice.dart';
import '../../core/widgets/legal_links.dart';
import '../account/deletion_pending.dart';
import '../insights/look_back.dart' show LookBackSettingsSwitch;
import '../keepsakes/keepsakes_screen.dart'
    show KeepsakesEntryTile, keepsakesRoute;
import '../onboarding/language_screen.dart';
import '../plus/plus_settings_section.dart';
import '../push/notifications_settings_section.dart';
import '../support/grievance_api.dart';
import '../support/grievance_screen.dart';
import '../widget/widget_settings_section.dart';
import 'corpus_consent.dart';

/// Settings, in this order: Language · Comfort (Reduce motion REQ-A11Y-08,
/// Haptics, Hide streak number F3) · Account (sign in/out, "Delete my
/// account" F8 REQ-ACC-11) · Notifications (F14) · Help & Safety (disclaimer
/// REQ-SAFE-12, legal links, Grievance Officer REQ-SAFE-11, support) · About.
///
/// A deletion that sync found pending (`403 account_deletion_pending`) is
/// surfaced at the top with "Keep my account" / "Let it go".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final auth = ref.watch(authRepositoryProvider);
    final user = ref.watch(authUserProvider).value;
    final comfort = ref.watch(comfortControllerProvider);
    final comfortCtl = ref.read(comfortControllerProvider.notifier);

    // The phone already reduces motion: `AuraApp` folds the in-app switch
    // into the same MediaQuery flag, so check the platform too.
    final osReducesMotion =
        View.of(context)
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations ||
        (reduceMotionOf(context) && !comfort.reduceMotion);

    Widget section(String title, String key) => Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.s),
      child: Semantics(
        header: true,
        child: Text(
          title,
          key: ValueKey('set-section-$key'),
          style: t.titleSmall,
        ),
      ),
    );

    Widget toggle({
      required String key,
      required String title,
      required String note,
      required bool value,
      required ValueChanged<bool>? onChanged,
    }) => SwitchListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: Text(note),
    );

    final grievanceName = Env.grievanceOfficerName;
    final grievanceEmail = Env.grievanceOfficerEmail;
    final supportEmail = Env.supportEmail;

    return Scaffold(
      // "I need help now" stays in the bar only when it fits there on one
      // line; otherwise it gets its own row under the title.
      appBar: helpAppBar(context, title: l.settings_title),
      body: CosmicBackground(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AuraSpace.gutter,
            AuraSpace.s,
            AuraSpace.gutter,
            AuraSpace.xxl,
          ),
          children: [
            const DeletionPendingCard(),

            // ---- Language -------------------------------------------------
            section(l.settings_language, 'language'),
            const LanguagePicker(),
            const LanguagePoolNotice(),

            // ---- Comfort --------------------------------------------------
            section(l.set_comfort, 'comfort'),
            toggle(
              key: 'set-reduce-motion',
              title: l.set_reduceMotion,
              note: l.set_reduceMotionNote,
              // On (and locked) while the phone's own setting reduces motion.
              value: osReducesMotion || comfort.reduceMotion,
              onChanged: osReducesMotion
                  ? null
                  : (v) =>
                        comfortCtl.update((c) => c.copyWith(reduceMotion: v)),
            ),
            toggle(
              key: 'set-haptics',
              title: l.set_haptics,
              note: l.set_hapticsNote,
              value: comfort.haptics,
              onChanged: (v) =>
                  comfortCtl.update((c) => c.copyWith(haptics: v)),
            ),
            toggle(
              key: 'set-hide-streak',
              title: l.set_hideStreak,
              note: l.set_hideStreakNote,
              value: comfort.hideStreak,
              onChanged: (v) =>
                  comfortCtl.update((c) => c.copyWith(hideStreak: v)),
            ),
            toggle(
              key: 'set-guided-prompts',
              title: l.prompt_settingsTitle,
              note: l.prompt_settingsBody,
              value: ref.watch(guidedPromptsEnabledProvider).value ?? true,
              onChanged: (v) => setGuidedPromptsEnabled(ref, enabled: v),
            ),
            // F10 Look back: it can be hidden here (PRD F10).
            const LookBackSettingsSwitch(),

            // ---- Account --------------------------------------------------
            if (auth.isAvailable) ...[
              section(l.settings_account, 'account'),
              if (user == null)
                FilledButton(
                  key: const ValueKey('set-sign-in'),
                  onPressed: () => context.push(Routes.signIn),
                  child: Text(l.settings_signIn),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
                  child: Text(
                    l.settings_signedInAs(user.email ?? ''),
                    key: const ValueKey('set-signed-in-as'),
                    style: t.bodyLarge,
                  ),
                ),
                // F13: the private keepsake box (server-awarded, so signed in).
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AuraSpace.s),
                  child: KeepsakesEntryTile(
                    onOpen: () => context.push(keepsakesRoute),
                  ),
                ),
                ListTile(
                  key: const ValueKey('set-sign-out'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(l.settings_signOut),
                  onTap: () => _signOut(context, ref),
                ),
                ListTile(
                  key: const ValueKey('set-export'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download_rounded),
                  title: Text(l.export_settingsRow),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.dataExport),
                ),
                ListTile(
                  key: const ValueKey('set-delete-account'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(l.acct_deleteTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.deleteAccount),
                ),
              ],
            ],

            // ---- Notifications (F14: reminder, capsules, quiet hours,
            // discreet mode; features/push) ---------------------------------
            const NotificationsSection(),

            // ---- Home-screen widget (F11: last mood, discreet; features/widget)
            const WidgetSettingsSection(),

            // ---- Help & Safety ------------------------------------------------
            section(l.set_helpSafety, 'help'),
            Text(
              l.help_disclaimer,
              key: const ValueKey('set-disclaimer'),
              style: t.bodyMedium,
            ),
            const SizedBox(height: AuraSpace.s),
            const LegalLinks(),
            // REQ-SAFE-16: the moderation-corpus opt-out (signed in only).
            if (auth.isAvailable && user != null) const CorpusConsentTile(),
            if (grievanceName.isNotEmpty || grievanceEmail.isNotEmpty)
              _EmailRow(
                key: const ValueKey('set-grievance'),
                icon: Icons.gavel_rounded,
                title: l.set_grievanceOfficer,
                lines: [
                  if (grievanceName.isNotEmpty) grievanceName,
                  if (grievanceEmail.isNotEmpty) grievanceEmail,
                ],
                email: grievanceEmail,
                subject: l.set_grievanceSubject,
              ),
            // The in-app form (REQ-SAFE-11): a ticket id at once, no email
            // app needed; the email row above stays as the other route.
            if (ref.watch(grievanceApiProvider) != null)
              ListTile(
                key: const ValueKey('set-grievance-form'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_rounded),
                title: Text(l.set_grievanceForm),
                subtitle: Text(l.set_grievanceFormNote),
                onTap: () =>
                    Navigator.of(context).push(GrievanceFormScreen.route()),
              ),
            if (supportEmail.isNotEmpty)
              _EmailRow(
                key: const ValueKey('set-support'),
                icon: Icons.mail_outline_rounded,
                title: l.set_contactSupport,
                lines: [supportEmail],
                email: supportEmail,
                subject: l.set_supportSubject,
              ),

            // ---- Aura Plus (F12: status, manage, Restore, sky + Stardust;
            // features/plus). Signed-in accounts only (purchases are online),
            // and only while purchases are switched on (`plus_enabled`).
            if (auth.isAvailable &&
                user != null &&
                ref.watch(plusEnabledProvider)) ...[
              section(l.plus_title, 'plus'),
              const PlusSettingsSection(),
            ],

            // ---- About ------------------------------------------------------
            section(l.settings_about, 'about'),
            Text(
              l.settings_version(Env.appVersion),
              key: const ValueKey('set-version'),
              style: t.bodySmall,
            ),
            if (Env.debugTools) ...[
              const SizedBox(height: AuraSpace.l),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('set-avatar-lab'),
                  onPressed: () => context.push(Routes.debugAvatar),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l.settings_avatarLab),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Warns when unsynced items would be lost (PRD States: Settings), then
  /// signs out and wipes this phone's personal data (shared phones).
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final pending = await ref.read(outboxRepositoryProvider).count();
    if (pending > 0 && context.mounted) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('set-sign-out-dialog'),
          title: Semantics(header: true, child: Text(l.set_signOutTitle)),
          content: Text(l.settings_signOutPending(pending)),
          actions: [
            TextButton(
              key: const ValueKey('set-stay'),
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.settings_stay),
            ),
            TextButton(
              key: const ValueKey('set-sign-out-anyway'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.settings_signOutAnyway),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await ref.read(signOutServiceProvider).signOut();
  }
}

/// A row that writes an email (subject only — nothing about the person is
/// pre-filled). Not tappable without an address.
class _EmailRow extends StatelessWidget {
  const _EmailRow({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.email,
    required this.subject,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String email;
  final String subject;

  Future<void> _open(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      // Encoded by hand: `queryParameters` turns spaces into '+'.
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.set_emailFailed(email)),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      link: email.isNotEmpty,
      hint: email.isNotEmpty ? l.set_opensEmail : null,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
        onTap: email.isEmpty ? null : () => _open(context),
      ),
    );
  }
}

/// PRD 14 "Language · switch mid-session": after a switch in Settings, which
/// room pool new rooms use (the pool follows the app language; a room the
/// person is in keeps its own until they leave). Nothing before a change.
class LanguagePoolNotice extends ConsumerStatefulWidget {
  const LanguagePoolNotice({super.key});

  @override
  ConsumerState<LanguagePoolNotice> createState() => _LanguagePoolNoticeState();
}

class _LanguagePoolNoticeState extends ConsumerState<LanguagePoolNotice> {
  late final String _opened = ref.read(localeControllerProvider);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tag = ref.watch(localeControllerProvider);
    if (tag == _opened) return const SizedBox.shrink();
    final hiOpen = ref.watch(remoteFlagsProvider.select((f) => f.roomsPoolHi));
    final text = switch (tag) {
      AuraLocales.te || AuraLocales.teLatn => l.settings_poolNoticeTe,
      AuraLocales.hi || AuraLocales.hiLatn =>
        hiOpen ? l.settings_poolNoticeHi : l.settings_poolNoticeHiSoon,
      _ => l.settings_poolNoticeEn,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AuraSpace.xs),
      child: InlineNotice(
        text,
        key: const ValueKey('set-pool-notice'),
        icon: Icons.forum_outlined,
      ),
    );
  }
}
