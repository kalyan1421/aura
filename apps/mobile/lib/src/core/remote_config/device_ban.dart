import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/account/delete_account_screen.dart';
import '../../features/onboarding/onboarding_frame.dart';
import '../../features/support/support_sheet.dart';
import '../env/env.dart';
import '../providers.dart';
import '../router/router.dart';
import '../theme/aura_tokens.dart';
import '../widgets/busy_button_label.dart';
import '../widgets/inline_notice.dart';

/// This phone was banned (PRD 19 REQ-ADM-14; contracts/api/v1.md "Device
/// bans"): the server answers `403 device_banned` on sign-in / profile, push
/// registration and room matching when the request carries a banned install
/// id (`install_id.dart`). The app then shows [DeviceBannedScreen] above
/// everything — calm, no reason (no tipping off), how to ask for a review,
/// "Delete my account", "Sign out" and "I need help now" (help is never
/// locked). The account routes stay open on the server, so deletion works.
///
/// The same pattern as the closed-account screen (features/auth/
/// account_closed.dart), with its own words: here it is the phone, not the
/// account.

/// Puts [DeviceBannedScreen] above everything (tests replace it).
abstract interface class DeviceBannedPresenter {
  void show();
}

class RouterDeviceBannedPresenter implements DeviceBannedPresenter {
  RouterDeviceBannedPresenter(this._router);

  final GoRouter Function() _router;
  Route<void>? _route;

  @override
  void show() {
    if (_route?.isActive ?? false) return;
    final nav = _router().routerDelegate.navigatorKey.currentState;
    if (nav == null) return;
    final route = DeviceBannedScreen.route();
    _route = route;
    unawaited(nav.push(route));
  }
}

final deviceBannedPresenterProvider = Provider<DeviceBannedPresenter>(
  (ref) => RouterDeviceBannedPresenter(() => ref.read(routerProvider)),
);

/// `true` once any call was answered `403 device_banned` in this session.
class DeviceBanned extends Notifier<bool> {
  @override
  bool build() => false;

  /// Shows the screen (again, if it was dropped meanwhile).
  void report() {
    state = true;
    ref.read(deviceBannedPresenterProvider).show();
  }
}

final deviceBannedProvider = NotifierProvider<DeviceBanned, bool>(
  DeviceBanned.new,
);

/// "This device can't use Aura." The only ways on: ask for a review, delete
/// the account, sign out, or "I need help now". Back does nothing.
class DeviceBannedScreen extends ConsumerStatefulWidget {
  const DeviceBannedScreen({super.key, this.reviewName, this.reviewEmail});

  /// Override [Env.grievanceOfficerName] / [Env.grievanceOfficerEmail]
  /// (tests). An empty email falls back to [Env.supportEmail].
  final String? reviewName;
  final String? reviewEmail;

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'device-banned'),
    builder: (_) => const DeviceBannedScreen(),
  );

  @override
  ConsumerState<DeviceBannedScreen> createState() => _DeviceBannedScreenState();
}

class _DeviceBannedScreenState extends ConsumerState<DeviceBannedScreen> {
  bool _busy = false;
  bool _mailFailed = false;

  String get _reviewEmail {
    final grievance = widget.reviewEmail ?? Env.grievanceOfficerEmail;
    return grievance.isNotEmpty ? grievance : Env.supportEmail;
  }

  String get _reviewName => widget.reviewName ?? Env.grievanceOfficerName;

  /// A subject line only: nothing about the person or the phone in the URL.
  Future<void> _askForReview(String email) async {
    final l = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: email,
          query: 'subject=${Uri.encodeComponent(l.device_bannedReviewSubject)}',
        ),
      );
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _mailFailed = !opened);
  }

  void _delete() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(signOutServiceProvider).signOut();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final email = _reviewEmail;
    final name = _reviewName;
    final signedIn = ref.watch(authUserProvider).value != null;
    return PopScope(
      canPop: false,
      child: OnboardingFrame(
        trailing: const HelpNowButton(compact: true),
        primary: signedIn
            ? FilledButton(
                key: const ValueKey('device-banned-sign-out'),
                onPressed: _busy ? null : _signOut,
                child: BusyButtonLabel(l.settings_signOut, busy: _busy),
              )
            : null,
        children: [
          const SizedBox(height: AuraSpace.xl),
          const ExcludeSemantics(
            child: Icon(
              Icons.phonelink_lock_outlined,
              size: 56,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          Semantics(
            header: true,
            child: Text(
              l.device_bannedTitle,
              key: const ValueKey('device-banned-title'),
              style: t.headlineMedium,
            ),
          ),
          const SizedBox(height: AuraSpace.m),
          Text(
            l.device_bannedBody,
            key: const ValueKey('device-banned-body'),
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.xl),
          Material(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(AuraRadius.m),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AuraSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.closed_review, style: t.bodyLarge),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s),
                    Semantics(
                      link: true,
                      hint: l.set_opensEmail,
                      child: ListTile(
                        key: const ValueKey('device-banned-review'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: Text(l.closed_askReview),
                        subtitle: Text(
                          [if (name.isNotEmpty) name, email].join('\n'),
                        ),
                        isThreeLine: name.isNotEmpty,
                        onTap: () => _askForReview(email),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_mailFailed) ...[
            const SizedBox(height: AuraSpace.s),
            InlineNotice(
              l.set_emailFailed(email),
              key: const ValueKey('device-banned-mail-failed'),
            ),
          ],
          if (signedIn) ...[
            const SizedBox(height: AuraSpace.xl),
            Text(
              l.closed_deleteNote,
              style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('device-banned-delete'),
                onPressed: _busy ? null : _delete,
                child: Text(l.acct_deleteTitle),
              ),
            ),
            const SizedBox(height: AuraSpace.s),
            Text(
              l.closed_signOutNote,
              style: t.bodySmall?.copyWith(color: AuraColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
