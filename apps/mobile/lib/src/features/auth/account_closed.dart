import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/net/aura_api.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../account/delete_account_screen.dart';
import '../onboarding/onboarding_frame.dart';
import '../support/support_sheet.dart';

part 'account_closed.g.dart';

/// An account closed for breaking the rules (F9 / 19 admin console;
/// contracts/api/v1.md "Account closed"): the server answers
/// `403 account_closed` everywhere but `/v1/account*` and the safety reads.
///
/// Handled like a scheduled deletion (features/account): asked once after
/// every sign-in (`GET /v1/account` → `accountClosed`), and noticed on any
/// later `403 account_closed` (the [AuraApi] hook, and the rooms client's
/// `RoomsRepository` hook for `/v1/rooms*` and `/v1/safety*`). Either way
/// the app shows [AccountClosedScreen] above everything: calm, no reason (no
/// tipping off), how to ask for a review, "Delete my account" and "Sign
/// out". Help is never locked. Nothing on the phone is wiped until the person
/// signs out or deletes; sync keeps the outbox and backs off.

/// Whether the signed-in account is closed (`GET /v1/account`).
abstract interface class AccountStanding {
  Future<bool> isClosed();
}

class ApiAccountStanding implements AccountStanding {
  const ApiAccountStanding(this._api);

  final AuraApi _api;

  @override
  Future<bool> isClosed() => _api.accountClosed();
}

/// `null` when this build has no API.
@Riverpod(keepAlive: true)
AccountStanding? accountStanding(Ref ref) {
  final api = ref.watch(auraApiProvider);
  return api == null ? null : ApiAccountStanding(api);
}

/// Puts [AccountClosedScreen] above everything (tests replace it).
abstract interface class AccountClosedPresenter {
  void show();
}

/// Pushes the screen on the app router's root navigator, once: a screen that
/// is still showing is never stacked twice. The route is dropped with the
/// pages under it when sign-out returns the app to Welcome.
class RouterAccountClosedPresenter implements AccountClosedPresenter {
  RouterAccountClosedPresenter(this._router);

  final GoRouter Function() _router;
  Route<void>? _route;

  @override
  void show() {
    if (_route?.isActive ?? false) return;
    final nav = _router().routerDelegate.navigatorKey.currentState;
    if (nav == null) return;
    final route = AccountClosedScreen.route();
    _route = route;
    unawaited(nav.push(route));
  }
}

@Riverpod(keepAlive: true)
AccountClosedPresenter accountClosedPresenter(Ref ref) =>
    RouterAccountClosedPresenter(() => ref.read(routerProvider));

/// The id of the signed-in account when it is closed, else `null`. Signing
/// out or switching accounts clears it.
@Riverpod(keepAlive: true)
class AccountClosed extends _$AccountClosed {
  @override
  String? build() {
    ref.listen(authUserProvider, (_, next) {
      final held = state;
      if (held != null && next.value?.id != held) state = null;
    });
    return null;
  }

  String? get _userId => ref.read(authRepositoryProvider).currentUser?.id;

  /// Any call answered `403 account_closed` ([AuraApi] hook): show the
  /// screen (again, if it was dropped meanwhile).
  void report() {
    final userId = _userId;
    if (userId == null) return;
    state = userId;
    ref.read(accountClosedPresenterProvider).show();
  }

  /// Asked after every successful sign-in. `true`: the account is closed and
  /// (with [show]) the screen is up — the caller stops there. With
  /// `show: false` the caller shows it later with [report] (sign-in asks
  /// "Keep my account?" first). Never throws; unreachable or slow → `false`
  /// (a later `403 account_closed` still shows the screen).
  Future<bool> check({
    Duration timeout = const Duration(seconds: 8),
    bool show = true,
  }) async {
    final userId = _userId;
    final standing = ref.read(accountStandingProvider);
    if (userId == null || standing == null) return false;
    try {
      final closed = await standing.isClosed().timeout(timeout);
      if (!closed || _userId != userId) return false;
    } catch (e) {
      debugPrint('account: standing ${e.runtimeType}');
      return false;
    }
    if (show) {
      report();
    } else {
      state = userId;
    }
    return true;
  }
}

/// "This account is closed." The only ways on: ask for a review (Grievance
/// Officer, from the build's legal defines), delete the account, sign out,
/// or "I need help now". Back does nothing; there is no reason code.
class AccountClosedScreen extends ConsumerStatefulWidget {
  const AccountClosedScreen({super.key, this.reviewName, this.reviewEmail});

  /// Override [Env.grievanceOfficerName] / [Env.grievanceOfficerEmail]
  /// (tests). An empty email falls back to [Env.supportEmail]; none at all
  /// hides the row.
  final String? reviewName;
  final String? reviewEmail;

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'account-closed'),
    builder: (_) => const AccountClosedScreen(),
  );

  @override
  ConsumerState<AccountClosedScreen> createState() =>
      _AccountClosedScreenState();
}

class _AccountClosedScreenState extends ConsumerState<AccountClosedScreen> {
  bool _busy = false;
  bool _mailFailed = false;

  String get _reviewEmail {
    final grievance = widget.reviewEmail ?? Env.grievanceOfficerEmail;
    return grievance.isNotEmpty ? grievance : Env.supportEmail;
  }

  String get _reviewName => widget.reviewName ?? Env.grievanceOfficerName;

  /// A subject line only: nothing about the person goes into the URL.
  Future<void> _askForReview(String email) async {
    final l = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: email,
          // Encoded by hand: `queryParameters` turns spaces into '+'.
          query: 'subject=${Uri.encodeComponent(l.closed_reviewSubject)}',
        ),
      );
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _mailFailed = !opened);
  }

  void _delete() {
    // Not a router location: the gate may still be in onboarding here.
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
        // Normally gone with the pages under it (Welcome); never left behind.
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
    return PopScope(
      canPop: false,
      child: OnboardingFrame(
        trailing: const HelpNowButton(compact: true),
        primary: FilledButton(
          key: const ValueKey('closed-sign-out'),
          onPressed: _busy ? null : _signOut,
          child: BusyButtonLabel(l.settings_signOut, busy: _busy),
        ),
        children: [
          const SizedBox(height: AuraSpace.xl),
          const ExcludeSemantics(
            child: Icon(
              Icons.nights_stay_outlined,
              size: 56,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          Semantics(
            header: true,
            child: Text(
              l.closed_title,
              key: const ValueKey('closed-title'),
              style: t.headlineMedium,
            ),
          ),
          const SizedBox(height: AuraSpace.m),
          Text(
            l.closed_body,
            key: const ValueKey('closed-body'),
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.xl),
          // A Material (not a decorated box) so the row's ink stays visible.
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
                        key: const ValueKey('closed-review'),
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
              key: const ValueKey('closed-mail-failed'),
            ),
          ],
          const SizedBox(height: AuraSpace.xl),
          Text(
            l.closed_deleteNote,
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('closed-delete'),
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
      ),
    );
  }
}
