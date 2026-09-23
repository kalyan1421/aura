import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/app.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/core/widgets/inline_notice.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/sign_in_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// Sign-in (F8 REQ-ACC-01): the magic link finishes like a typed code,
/// once; no dead social buttons; stable busy buttons and a resend cooldown;
/// calm errors; help + back; and the "Keep my account?" check after sign-in
/// (contracts/api/v1.md "Account deletion").

const _alice = AuthUser(id: 'user-a', email: 'a@aura.test');
final _purge = DateTime.utc(2026, 10, 15, 10);

class _Auth implements AuthRepository {
  AuthUser? user;
  final _users = StreamController<AuthUser?>.broadcast();
  Completer<void>? sendGate;
  int sends = 0;
  int verifies = 0;

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> watchUser() async* {
    yield user;
    yield* _users.stream;
  }

  @override
  Future<String?> accessToken() async => user == null ? null : 'jwt';

  @override
  Future<void> sendEmailCode(String email) async {
    sends++;
    await sendGate?.future;
  }

  /// Like Supabase: the session event fires before the call returns.
  @override
  Future<void> verifyEmailCode(String email, String code) async {
    verifies++;
    signIn(_alice);
  }

  @override
  Future<void> signOut() async => signIn(null);

  void signIn(AuthUser? u) {
    user = u;
    _users.add(u);
  }
}

class _Account implements AccountRepository {
  DateTime? scheduled;
  int statusCalls = 0;
  int cancels = 0;
  Object? failCancel;

  @override
  Future<DateTime> requestDeletion() async => scheduled = _purge;
  @override
  Future<DateTime?> scheduledDeletion() async {
    statusCalls++;
    return scheduled;
  }

  @override
  Future<void> cancelDeletion() async {
    final e = failCancel;
    if (e != null) throw e;
    cancels++;
    scheduled = null;
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The whole app, in onboarding at the sign-in step.
Future<ProviderContainer> _onboarding(
  WidgetTester tester,
  _Auth auth,
  _Account account,
) async {
  _phone(tester);
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        db: memoryDb(),
        auth: auth,
        gate: const GateState(stage: OnboardingStage.signIn),
      ),
      accountRepositoryProvider.overrideWithValue(account),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const AuraApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final _email = find.byKey(const ValueKey('signin-email'));
final _send = find.byKey(const ValueKey('signin-send'));

void main() {
  testWidgets('magic link: a session arriving while the screen shows finishes '
      'onboarding exactly like a typed code', (tester) async {
    final auth = _Auth();
    final account = _Account();
    final c = await _onboarding(tester, auth, account);
    expect(_email, findsOneWidget);

    auth.signIn(_alice); // aura://auth-callback → Supabase session
    await settleIo(tester);

    expect(c.read(gateControllerProvider).stage, OnboardingStage.firstCheckIn);
    expect(find.byType(SignInScreen), findsNothing);
    expect(account.statusCalls, 1);
    await _unmount(tester);
  });

  testWidgets('a typed code whose session event also arrives completes once', (
    tester,
  ) async {
    final auth = _Auth();
    final account = _Account();
    final c = await _onboarding(tester, auth, account);

    await tester.enterText(_email, 'a@aura.test');
    await tester.tap(_send);
    await settleIo(tester);
    await tester.enterText(find.byKey(const ValueKey('signin-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('signin-verify')));
    await settleIo(tester);

    expect(auth.verifies, 1);
    expect(account.statusCalls, 1); // one completion, not two
    expect(c.read(gateControllerProvider).stage, OnboardingStage.firstCheckIn);
    await _unmount(tester);
  });

  testWidgets('standalone: the magic link pops back to where sign-in opened', (
    tester,
  ) async {
    _phone(tester);
    final auth = _Auth();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              key: const ValueKey('origin'),
              onPressed: () => context.push('/sign-in'),
              child: const Text('origin'),
            ),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const SignInScreen(standalone: true),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: memoryDb(), auth: auth),
          accountRepositoryProvider.overrideWithValue(_Account()),
        ],
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('origin')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);

    auth.signIn(_alice);
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byKey(const ValueKey('origin')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Apple and Google are hidden unless the flag is on (no dead '
      'buttons, no stand-in logo)', (tester) async {
    await _onboarding(tester, _Auth(), _Account());
    expect(find.byKey(const ValueKey('signin-apple')), findsNothing);
    expect(find.byKey(const ValueKey('signin-google')), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byIcon(Icons.g_mobiledata_rounded), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Send shows progress inside the button without changing its '
      'size; resend waits 30 s behind a quiet label', (tester) async {
    final auth = _Auth()..sendGate = Completer<void>();
    await _onboarding(tester, auth, _Account());

    await tester.enterText(_email, 'a@aura.test');
    await tester.pump();
    final before = tester.getSize(_send);
    expect(before.height, greaterThanOrEqualTo(56));

    await tester.tap(_send);
    await tester.pump();
    expect(find.byKey(const ValueKey('busy-progress')), findsOneWidget);
    expect(tester.getSize(_send), before);
    expect(find.text('Email me a code'), findsOneWidget); // label stays
    expect(tester.widget<FilledButton>(_send).onPressed, isNull);

    auth.sendGate!.complete();
    auth.sendGate = null;
    await tester.pump();
    await tester.pump();

    final resend = find.byKey(const ValueKey('signin-resend'));
    expect(find.text('You can ask for a fresh code in 30 s'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('You can ask for a fresh code in 20 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Send a fresh code'), findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);

    await tester.tap(resend);
    await tester.pump();
    await tester.pump();
    expect(auth.sends, 2);
    expect(find.text('A fresh code is on its way.'), findsOneWidget);
    expect(find.text('You can ask for a fresh code in 30 s'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a form error is a calm inline notice, never lantern', (
    tester,
  ) async {
    await _onboarding(tester, _Auth(), _Account());
    await tester.enterText(_email, 'not-an-email');
    await tester.tap(_send);
    await tester.pump();

    const message = "That email doesn't look quite right.";
    expect(
      find.descendant(
        of: find.byType(InlineNotice),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    final text = tester.widget<Text>(find.text(message));
    expect(text.style?.color, isNot(AuraColors.lantern));
    await _unmount(tester);
  });

  testWidgets('onboarding: help is at hand and Back returns to Language', (
    tester,
  ) async {
    final c = await _onboarding(tester, _Auth(), _Account());
    expect(find.byType(HelpNowButton), findsOneWidget);

    // A double tap goes back one step only (Language, never DOB).
    final back = find.byKey(const ValueKey('onboarding-back'));
    await tester.tap(back);
    await tester.tap(back, warnIfMissed: false);
    await settleIo(tester);
    expect(c.read(gateControllerProvider).stage, OnboardingStage.language);
    await _unmount(tester);
  });

  testWidgets('deletion pending on return: "Keep my account" cancels it and '
      'onboarding carries on', (tester) async {
    final auth = _Auth();
    final account = _Account()..scheduled = _purge;
    final c = await _onboarding(tester, auth, account);

    auth.signIn(_alice);
    await settleIo(tester);
    expect(find.byKey(const ValueKey('acct-pending-dialog')), findsOneWidget);
    expect(
      find.text(
        'Your account is set to be deleted on October 15, 2026. Keep it?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('acct-keep')));
    await settleIo(tester);
    expect(account.cancels, 1);
    expect(c.read(deletionHoldProvider), isNull);
    expect(c.read(gateControllerProvider).stage, OnboardingStage.firstCheckIn);
    await _unmount(tester);
  });

  testWidgets('deletion pending on return: "Let it go" signs out and wipes '
      '(back to Welcome)', (tester) async {
    final auth = _Auth();
    final account = _Account()..scheduled = _purge;
    final c = await _onboarding(tester, auth, account);

    auth.signIn(_alice);
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('acct-let-go')));
    await settleIo(tester);

    expect(account.cancels, 0);
    expect(auth.currentUser, isNull);
    expect(c.read(gateControllerProvider).stage, OnboardingStage.welcome);
    await _unmount(tester);
  });

  testWidgets('"Keep my account" after the grace period (409 '
      'account_deletion_in_progress): explained calmly, then only Sign out', (
    tester,
  ) async {
    final auth = _Auth();
    final account = _Account()
      ..scheduled = _purge
      ..failCancel = const ApiException(
        code: 'account_deletion_in_progress',
        status: 409,
      );
    final c = await _onboarding(tester, auth, account);

    auth.signIn(_alice);
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('acct-keep')));
    await settleIo(tester);

    expect(find.byKey(const ValueKey('acct-in-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-keep')), findsNothing); // no retry
    expect(auth.currentUser, isNotNull);

    await tester.tap(find.byKey(const ValueKey('acct-in-progress-sign-out')));
    await settleIo(tester);
    expect(auth.currentUser, isNull);
    expect(c.read(gateControllerProvider).stage, OnboardingStage.welcome);
    await _unmount(tester);
  });
}
