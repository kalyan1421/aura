import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/busy_button_label.dart';
import '../../core/widgets/inline_notice.dart';
import '../account/account_providers.dart';
import '../account/deletion_pending.dart';
import '../onboarding/gate_controller.dart';
import '../onboarding/onboarding_frame.dart';
import '../support/support_sheet.dart';
import 'account_closed.dart';
import 'age_signals.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'social_buttons.dart';
import 'social_sign_in.dart';

/// Sign in with an email code (Supabase OTP), the magic link in the same
/// email, or natively with Apple / Google (F8 REQ-ACC-01). No name, phone or
/// password. A social button shows only when its provider is configured for
/// this build (SocialSignInConfig); on iOS, Google only alongside Apple.
///
/// Every path finishes the same way, once: a typed code, the magic link
/// (`aura://auth-callback` → Supabase → [authUserProvider]) or an Apple /
/// Google ID token exchanged with Supabase. After any sign-in the app asks
/// the server whether the account is in its deletion grace period and, if
/// so, "Keep my account?" (contracts/api/v1.md "Account deletion").
///
/// Before any auth call, platform age signals are read (≤ 1 s, REQ-ACC-04):
/// under 13 → the device lock, and nothing is sent.
///
/// [standalone] = opened later from Home/Settings (not onboarding).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  /// The social provider whose sign-in is running (its button shows progress).
  SocialProvider? _socialBusy;

  /// Set by the first completion (code, magic link or social); later ones
  /// no-op.
  bool _completing = false;

  /// Set by the first onboarding Back; a double tap never goes back twice.
  bool _goingBack = false;
  String? _error;
  String? _info;

  /// Seconds until "Send a fresh code" is offered again.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  /// REQ-ACC-04, started as the screen opens so it's usually done by the
  /// first tap.
  late final AgeSignalCheck _ageCheck;

  static const int resendCooldownSeconds = 30;
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final source = ref.read(ageSignalSourceProvider);
    final policy = ref.read(ageSignalPolicyProvider);
    _ageCheck = AgeSignalCheck(read: source.read, apply: policy.apply)..start();
    // The magic link signs in without a typed code: finish exactly as a
    // verified code does (also covers a session restored on open).
    ref.listenManual<AsyncValue<AuthUser?>>(authUserProvider, (_, next) {
      if (next.value == null || _completing) return;
      // Never navigate from inside a build or listener callback.
      Future.microtask(() {
        if (mounted) _complete();
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  bool get _working => _busy || _completing;

  String _message(AppLocalizations l, AuthFailureKind k) => switch (k) {
    AuthFailureKind.invalidEmail => l.signin_invalidEmail,
    AuthFailureKind.invalidCode => l.signin_invalidCode,
    AuthFailureKind.expired => l.signin_codeExpired,
    _ => l.signin_error,
  };

  /// Apple / Google: a closed sheet says nothing.
  String? _socialMessage(AppLocalizations l, AuthFailureKind k) => switch (k) {
    AuthFailureKind.cancelled => null,
    AuthFailureKind.notConfigured => l.signin_socialNotReady,
    AuthFailureKind.network => l.signin_socialOffline,
    _ => l.signin_error,
  };

  /// False when a platform age signal put the under-13 lock on (the router
  /// is already on its way to the block screen): no auth call may follow.
  Future<bool> _ageAllows() async =>
      await _ageCheck.outcome() != AgeSignalOutcome.blocked;

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          t.cancel();
        }
      });
    });
  }

  /// First send ("Email me a code") and "Send a fresh code".
  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    if (!_emailRe.hasMatch(_email.text.trim())) {
      setState(() {
        _error = l.signin_invalidEmail;
        _info = null;
      });
      return;
    }
    final resend = _codeSent;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (!await _ageAllows()) return;
      await _auth.sendEmailCode(_email.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        if (resend) _info = l.signin_freshSent;
      });
      _startCooldown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = _message(l, e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_working) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _auth.verifyEmailCode(_email.text, _code.text);
      await _complete();
    } on AuthFailure catch (e) {
      if (e.kind == AuthFailureKind.expired) {
        // "We'll send a fresh one."
        try {
          await _auth.sendEmailCode(_email.text);
          if (mounted) _startCooldown();
        } on AuthFailure {
          // The expired notice still offers "Send a fresh code".
        }
      }
      if (mounted) setState(() => _error = _message(l, e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google: the native sheet returns with a Supabase session and finishes
  /// here.
  Future<void> _social(SocialProvider provider) async {
    if (_working) return;
    final service = ref.read(socialSignInProvider);
    if (service == null) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _socialBusy = provider;
      _error = null;
      _info = null;
    });
    try {
      if (!await _ageAllows()) return;
      final result = await service.signIn(provider);
      if (result == SocialSignInResult.signedIn && mounted) await _complete();
    } on AuthFailure catch (e) {
      final message = _socialMessage(l, e.kind);
      if (mounted && message != null) setState(() => _error = message);
    } on Object catch (e) {
      // A plugin failing in a way nobody mapped: still calm, never raw.
      debugPrint('auth: social ${e.runtimeType}');
      if (mounted) setState(() => _error = l.signin_error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _socialBusy = null;
        });
      }
    }
  }

  /// Signed in (code, magic link or social). Runs once. The profile POST is
  /// queued and sent by sync; nothing here waits on it. A deletion check
  /// that can't reach the server never blocks sign-in (sync asks later).
  /// Then an account closed for breaking the rules gets the calm closed
  /// screen instead of the app (account_closed.dart; same fallback: a later
  /// `403 account_closed` shows it).
  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    final hold = ref.read(deletionHoldProvider.notifier);
    final closedHold = ref.read(accountClosedProvider.notifier);
    // Both questions go out together; a scheduled deletion is asked first.
    final closedCheck = closedHold.check(show: false);
    final pending = await hold.check();
    if (!mounted) return;
    if (pending != null) {
      final kept = await showKeepAccountDialog(context, pending);
      if (kept == false) {
        // "Let it go": wipe and sign out, back to Welcome.
        await hold.letGo();
        return;
      }
      if (!mounted) return;
    }
    if (await closedCheck) {
      closedHold.report(); // the calm closed screen, above everything
      return;
    }
    if (!mounted) return;
    await _proceed();
  }

  /// Onboarding → the first check-in; standalone → back where it came from.
  Future<void> _proceed() async {
    if (widget.standalone) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.home);
      }
      return;
    }
    await ref
        .read(gateControllerProvider.notifier)
        .goTo(OnboardingStage.firstCheckIn);
  }

  /// Onboarding Back (button or system gesture) → Language, once. Ignored
  /// while a sign-in is finishing.
  Future<void> _back() async {
    if (_goingBack || _completing) return;
    final stage = ref.read(gateControllerProvider).stage;
    if (stage != OnboardingStage.signIn) return;
    _goingBack = true;
    await ref.read(gateControllerProvider.notifier).back();
  }

  /// Offline, or no sign-in in this build: carry on without an account.
  Future<void> _continueWithoutAccount() async {
    if (!await _ageAllows()) return;
    await ref
        .read(gateControllerProvider.notifier)
        .goTo(OnboardingStage.firstCheckIn);
  }

  Widget _socialButton(AppLocalizations l, SocialProvider provider) {
    final busy = _socialBusy == provider;
    final onPressed = _working ? null : () => _social(provider);
    return switch (provider) {
      SocialProvider.google => GoogleSignInButton(
        key: const ValueKey('signin-google'),
        label: l.signin_google,
        busy: busy,
        onPressed: onPressed,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final online = ref.watch(connectivityProvider).value ?? true;
    final available = _auth.isAvailable;
    final busy = _working;
    final social = ref.watch(socialSignInProvider)?.providers ?? const [];

    // Standalone: the route pops. Onboarding: back to the language step
    // (also the system back gesture, via OnboardingFrame.onBack).
    final Widget? leading = widget.standalone
        ? OnboardingBackButton(() => context.pop())
        : null;
    final VoidCallback? onBack = widget.standalone ? null : _back;
    const help = HelpNowButton(compact: true);

    if (!available || !online) {
      return OnboardingFrame(
        leading: leading,
        onBack: onBack,
        trailing: help,
        primary: widget.standalone
            ? null
            : FilledButton(
                key: const ValueKey('signin-skip'),
                onPressed: _continueWithoutAccount,
                child: Text(
                  available ? l.signin_offlineContinue : l.signin_continueLocal,
                ),
              ),
        children: [
          StepTitle(
            l.signin_title,
            body: available ? l.signin_offline : l.signin_unavailable,
          ),
        ],
      );
    }

    return OnboardingFrame(
      leading: leading,
      onBack: onBack,
      trailing: help,
      // The code step keeps Verify pinned. The email step has no pinned
      // button: "Email me a code" sits right under its field.
      primary: _codeSent
          ? FilledButton(
              key: const ValueKey('signin-verify'),
              onPressed: busy ? null : _verify,
              child: BusyButtonLabel(
                l.signin_verify,
                busy: busy && _socialBusy == null,
              ),
            )
          : null,
      secondary: _codeSent
          ? Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('signin-change-email'),
                    onPressed: busy
                        ? null
                        : () {
                            _cooldownTimer?.cancel();
                            setState(() {
                              _codeSent = false;
                              _cooldown = 0;
                              _code.clear();
                              _error = null;
                              _info = null;
                            });
                          },
                    child: Text(l.signin_changeEmail),
                  ),
                  TextButton(
                    key: const ValueKey('signin-resend'),
                    onPressed: busy || _cooldown > 0 ? null : _send,
                    child: Text(
                      _cooldown > 0
                          ? l.signin_resendIn(_cooldown)
                          : l.signin_resend,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            )
          : null,
      children: [
        StepTitle(l.signin_title, body: l.signin_body),
        if (!_codeSent) ...[
          // Two clear groups: Apple / Google first, then "or", then the
          // email field with its own button directly under it.
          if (social.isNotEmpty) ...[
            for (final (i, provider) in social.indexed) ...[
              if (i > 0) const SizedBox(height: AuraSpace.m),
              _socialButton(l, provider),
            ],
            const SizedBox(height: AuraSpace.l),
            const SignInOrDivider(),
            const SizedBox(height: AuraSpace.l),
          ],
          TextField(
            key: const ValueKey('signin-email'),
            controller: _email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => busy ? null : _send(),
            decoration: InputDecoration(labelText: l.signin_emailLabel),
          ),
          const SizedBox(height: AuraSpace.m),
          FilledButton(
            key: const ValueKey('signin-send'),
            onPressed: busy ? null : _send,
            child: BusyButtonLabel(
              l.signin_sendCode,
              busy: busy && _socialBusy == null,
            ),
          ),
        ] else ...[
          Text(l.signin_codeSent(_email.text.trim()), style: t.bodyLarge),
          const SizedBox(height: AuraSpace.l),
          TextField(
            key: const ValueKey('signin-code'),
            controller: _code,
            enabled: !busy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verify(),
            style: t.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: InputDecoration(labelText: l.signin_codeLabel),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.m),
          InlineNotice(
            _error!,
            key: const ValueKey('signin-error'),
            icon: Icons.error_outline_rounded,
          ),
        ] else if (_info != null) ...[
          const SizedBox(height: AuraSpace.m),
          InlineNotice(
            _info!,
            key: const ValueKey('signin-info'),
            icon: Icons.mark_email_read_outlined,
          ),
        ],
      ],
    );
  }
}
