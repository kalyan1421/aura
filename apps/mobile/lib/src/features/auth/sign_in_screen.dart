import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';
import '../onboarding/gate_controller.dart';
import '../onboarding/onboarding_frame.dart';
import 'auth_repository.dart';

/// Sign in with an email code (Supabase OTP) or the magic link in the same
/// email. No name, phone or password. Apple and Google are shown but
/// disabled until `AURA_SOCIAL_SIGNIN` is on.
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
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  String _message(AppLocalizations l, AuthFailureKind k) => switch (k) {
    AuthFailureKind.invalidEmail => l.signin_invalidEmail,
    AuthFailureKind.invalidCode => l.signin_invalidCode,
    AuthFailureKind.expired => l.signin_codeExpired,
    _ => l.signin_error,
  };

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    if (!_emailRe.hasMatch(_email.text.trim())) {
      setState(() => _error = l.signin_invalidEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.sendEmailCode(_email.text);
      setState(() => _codeSent = true);
    } on AuthFailure catch (e) {
      setState(() => _error = _message(l, e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.verifyEmailCode(_email.text, _code.text);
      await _done();
    } on AuthFailure catch (e) {
      if (e.kind == AuthFailureKind.expired) {
        // "We'll send a fresh one."
        await _auth.sendEmailCode(_email.text).catchError((_) {});
      }
      setState(() => _error = _message(l, e.kind));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Signed in (or continuing on this phone): the profile POST is queued and
  /// sent by sync; nothing here waits on it.
  Future<void> _done() async {
    if (widget.standalone) {
      if (mounted && context.canPop()) context.pop();
      return;
    }
    await ref
        .read(gateControllerProvider.notifier)
        .goTo(OnboardingStage.firstCheckIn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final online = ref.watch(connectivityProvider).value ?? true;
    final available = _auth.isAvailable;

    final back = widget.standalone
        ? IconButton(
            tooltip: l.common_back,
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        : null;

    if (!available || !online) {
      return OnboardingFrame(
        leading: back,
        primary: widget.standalone
            ? null
            : FilledButton(
                key: const ValueKey('signin-skip'),
                onPressed: _done,
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
      leading: back,
      primary: FilledButton(
        key: ValueKey(_codeSent ? 'signin-verify' : 'signin-send'),
        onPressed: _busy ? null : (_codeSent ? _verify : _send),
        child: Text(_codeSent ? l.signin_verify : l.signin_sendCode),
      ),
      secondary: _codeSent
          ? Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeSent = false;
                              _code.clear();
                              _error = null;
                            }),
                      child: Text(l.signin_changeEmail),
                    ),
                  ),
                  Flexible(
                    child: TextButton(
                      onPressed: _busy ? null : _send,
                      child: Text(l.signin_resend),
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
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(labelText: l.signin_emailLabel),
          ),
          const SizedBox(height: AuraSpace.xl),
          _SocialButton(
            label: l.signin_apple,
            icon: Icons.apple,
            // TODO(auth): Sign in with Apple once the provider is enabled.
            enabled: Env.socialSignIn,
          ),
          const SizedBox(height: AuraSpace.s),
          _SocialButton(
            label: l.signin_google,
            icon: Icons.g_mobiledata_rounded,
            // TODO(auth): Google sign-in (email scope only) once enabled.
            enabled: Env.socialSignIn,
          ),
        ] else ...[
          Text(l.signin_codeSent(_email.text.trim()), style: t.bodyLarge),
          const SizedBox(height: AuraSpace.l),
          TextField(
            key: const ValueKey('signin-code'),
            controller: _code,
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
          Text(_error!, style: t.bodyMedium?.copyWith(color: AuraColors.lantern)),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: enabled ? () {} : null,
    icon: Icon(icon),
    label: Text(label),
  );
}
