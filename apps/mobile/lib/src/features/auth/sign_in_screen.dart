import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
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
import 'auth_repository.dart';

/// Sign in with an email code (Supabase OTP) or the magic link in the same
/// email (F8 REQ-ACC-01). No name, phone or password. Apple and Google are
/// hidden unless `AURA_SOCIAL_SIGNIN` is on.
///
/// Either path finishes the same way, once: a typed code, or the magic link
/// (`aura://auth-callback` → Supabase → [authUserProvider]) while this screen
/// is showing. After any sign-in the app asks the server whether the account
/// is in its deletion grace period and, if so, "Keep my account?"
/// (contracts/api/v1.md "Account deletion").
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

  /// Set by the first completion (code or magic link); later ones no-op.
  bool _completing = false;

  /// Set by the first onboarding Back; a double tap never goes back twice.
  bool _goingBack = false;
  String? _error;
  String? _info;

  /// Seconds until "Send a fresh code" is offered again.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  static const int resendCooldownSeconds = 30;
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
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

  Future<void> _social(SocialProvider provider) async {
    final auth = _auth;
    if (auth is! SupabaseAuthRepository) return;
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      // Returns through aura://auth-callback → the listener finishes.
      await auth.signInWithProvider(provider);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = _message(l, e.kind));
    }
  }

  /// Signed in (typed code or magic link). Runs once. The profile POST is
  /// queued and sent by sync; nothing here waits on it. A deletion check
  /// that can't reach the server never blocks sign-in (sync asks later).
  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    final hold = ref.read(deletionHoldProvider.notifier);
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
  Future<void> _continueWithoutAccount() => ref
      .read(gateControllerProvider.notifier)
      .goTo(OnboardingStage.firstCheckIn);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final online = ref.watch(connectivityProvider).value ?? true;
    final available = _auth.isAvailable;
    final busy = _working;

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
      primary: FilledButton(
        key: ValueKey(_codeSent ? 'signin-verify' : 'signin-send'),
        onPressed: busy ? null : (_codeSent ? _verify : _send),
        child: BusyButtonLabel(
          _codeSent ? l.signin_verify : l.signin_sendCode,
          busy: busy,
        ),
      ),
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
          if (Env.socialSignIn) ...[
            // TODO(auth): official brand assets are required before this
            // flag ships — Apple's "Sign in with Apple" button (HIG) and
            // Google's "G" mark per Google's sign-in branding guidelines. A
            // Material icon stand-in breaks both, so none is shown.
            const SizedBox(height: AuraSpace.xl),
            OutlinedButton(
              key: const ValueKey('signin-apple'),
              onPressed: busy ? null : () => _social(SocialProvider.apple),
              child: Text(l.signin_apple),
            ),
            const SizedBox(height: AuraSpace.s),
            OutlinedButton(
              key: const ValueKey('signin-google'),
              onPressed: busy ? null : () => _social(SocialProvider.google),
              child: Text(l.signin_google),
            ),
          ],
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
