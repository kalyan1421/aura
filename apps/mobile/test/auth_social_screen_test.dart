import 'dart:async';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/app.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/theme/aura_tokens.dart';
import 'package:aura/src/core/widgets/inline_notice.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/auth/age_signals.dart';
import 'package:aura/src/features/auth/auth_providers.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/auth/sign_in_screen.dart';
import 'package:aura/src/features/auth/social_buttons.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:aura/src/features/onboarding/blocked_screen.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_social_fakes.dart';
import 'helpers.dart';

/// Native Google sign-in on the sign-in screen (F8 REQ-ACC-01, REQ-ACC-04):
/// the button only when configured (never on iOS in a release build: no Sign
/// in with Apple), the official mark, the same completion path as email, calm errors, and the
/// platform age signal checked before any auth call.

final _google = find.byKey(const ValueKey('signin-google'));
final _email = find.byKey(const ValueKey('signin-email'));
final _send = find.byKey(const ValueKey('signin-send'));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

List<Override> _social({
  required FakeSocialAuth auth,
  required SocialSignInConfig config,
  FakeGoogle? google,
  FakeAgeSource? age,
  FakeAccount? account,
}) => [
  accountRepositoryProvider.overrideWithValue(account ?? FakeAccount()),
  socialSignInProvider.overrideWithValue(
    SocialSignInService(
      config: config,
      exchange: auth,
      google: google ?? FakeGoogle(),
    ),
  ),
  ageSignalSourceProvider.overrideWithValue(age ?? FakeAgeSource()),
];

/// The whole app, in onboarding at the sign-in step.
Future<ProviderContainer> _onboarding(
  WidgetTester tester, {
  required FakeSocialAuth auth,
  SocialSignInConfig config = iosSocial,
  FakeGoogle? google,
  FakeAgeSource? age,
  FakeAccount? account,
  AppDatabase? db,
}) async {
  _phone(tester);
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(
        db: db ?? memoryDb(),
        auth: auth,
        gate: const GateState(stage: OnboardingStage.signIn),
      ),
      ..._social(
        auth: auth,
        config: config,
        google: google,
        age: age,
        account: account,
      ),
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

void main() {
  group('which buttons show', () {
    testWidgets('Google shows with its official mark in its dark theme, '
        'never a Material stand-in', (tester) async {
      await _onboarding(tester, auth: FakeSocialAuth());

      expect(_google, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('or'), findsOneWidget);

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is GoogleGMarkPainter,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.g_mobiledata_rounded), findsNothing);

      Material fill(Finder button) => tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      expect(fill(_google).color, GoogleSignInButton.fill);
      // No smaller than the email button.
      expect(tester.getSize(_google).height, greaterThanOrEqualTo(56));
      await _unmount(tester);
    });

    testWidgets('screen readers hear a button with its title (logos are '
        'decorative)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _onboarding(tester, auth: FakeSocialAuth());
      for (final (button, title) in [(_google, 'Continue with Google')]) {
        expect(
          tester.getSemantics(button),
          isSemantics(
            label: title,
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }
      await _unmount(tester);
      semantics.dispose();
    });

    testWidgets('nothing configured: no buttons, no divider', (tester) async {
      await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        config: const SocialSignInConfig(platform: SocialPlatform.ios),
      );
      expect(_google, findsNothing);
      expect(find.text('or'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('iOS release: Google is not offered without Sign in with '
        'Apple (App Store 4.8), and Aura has none', (tester) async {
      await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        config: const SocialSignInConfig(
          platform: SocialPlatform.ios,
          googleWebClientId: webClientId,
          googleIosClientId: iosClientId,
        ),
      );
      expect(_google, findsNothing);
      await _unmount(tester);
    });

    testWidgets('Android: Google alone', (tester) async {
      await _onboarding(tester, auth: FakeSocialAuth(), config: androidSocial);
      expect(_google, findsOneWidget);
      await _unmount(tester);
    });
  });

  group('signing in', () {
    testWidgets('Google finishes onboarding exactly like email: the token '
        'and raw nonce reach Supabase, the deletion check runs once, then '
        'the first check-in', (tester) async {
      final auth = FakeSocialAuth();
      final google = FakeGoogle();
      final account = FakeAccount();
      final c = await _onboarding(
        tester,
        auth: auth,
        google: google,
        account: account,
      );

      await _tap(tester, _google);
      await settleIo(tester);

      expect(google.calls, 1);
      expect(auth.idTokens, [
        (
          SocialProvider.google,
          'google-id-token',
          'google-access',
          'raw-nonce-g',
        ),
      ]);
      expect(google.forgets, 1);
      expect(account.statusCalls, 1); // one completion, not two
      expect(
        c.read(gateControllerProvider).stage,
        OnboardingStage.firstCheckIn,
      );
      expect(find.byType(SignInScreen), findsNothing);
      await _unmount(tester);
    });

    testWidgets('Google (standalone) pops back to where sign-in opened', (
      tester,
    ) async {
      _phone(tester);
      final auth = FakeSocialAuth();
      final google = FakeGoogle();
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
            ..._social(auth: auth, config: iosSocial, google: google),
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

      await _tap(tester, _google);
      await settleIo(tester);
      await tester.pumpAndSettle();

      expect(google.calls, 1);
      expect(auth.idTokens.single.$1, SocialProvider.google);
      expect(auth.idTokens.single.$4, 'raw-nonce-g');
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byKey(const ValueKey('origin')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('while one sign-in runs, every other button waits and the '
        'tapped one shows progress', (tester) async {
      final google = FakeGoogle()..hold = Completer<void>();
      await _onboarding(tester, auth: FakeSocialAuth(), google: google);

      await _tap(tester, _google);
      await tester.pump();
      expect(find.byKey(const ValueKey('social-busy')), findsOneWidget);
      expect(tester.widget<GoogleSignInButton>(_google).onPressed, isNull);
      expect(tester.widget<FilledButton>(_send).onPressed, isNull);

      google.hold!.complete();
      await settleIo(tester);
      await _unmount(tester);
    });

    testWidgets('closing the sheet says nothing and everything is usable '
        'again', (tester) async {
      final google = FakeGoogle()
        ..fail = const AuthFailure(AuthFailureKind.cancelled);
      final c = await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        google: google,
      );

      await _tap(tester, _google);
      await settleIo(tester);

      expect(find.byType(InlineNotice), findsNothing);
      expect(tester.widget<GoogleSignInButton>(_google).onPressed, isNotNull);
      expect(c.read(gateControllerProvider).stage, OnboardingStage.signIn);
      await _unmount(tester);
    });

    for (final (kind, copy) in [
      (
        AuthFailureKind.notConfigured,
        "That sign-in option isn't ready yet. Use your email for now.",
      ),
      (
        AuthFailureKind.network,
        "It looks like you're offline. Try again when you're connected.",
      ),
      (
        AuthFailureKind.other,
        "That didn't go through. Try again, or sign in another way.",
      ),
    ]) {
      testWidgets('${kind.name} → a calm inline notice, never lantern', (
        tester,
      ) async {
        final auth = FakeSocialAuth()..fail = AuthFailure(kind);
        final c = await _onboarding(tester, auth: auth);

        await _tap(tester, _google);
        await settleIo(tester);

        final notice = find.descendant(
          of: find.byType(InlineNotice),
          matching: find.text(copy),
        );
        expect(notice, findsOneWidget);
        expect(
          tester.widget<Text>(find.text(copy)).style?.color,
          isNot(AuraColors.lantern),
        );
        expect(c.read(gateControllerProvider).stage, OnboardingStage.signIn);
        expect(auth.user, isNull);
        await _unmount(tester);
      });
    }
  });

  group('platform age signals (REQ-ACC-04)', () {
    testWidgets('an under-13 signal arriving during the wait blocks before '
        'Google is even opened', (tester) async {
      final age = FakeAgeSource()..gate = Completer<AgeSignal>();
      final google = FakeGoogle();
      final c = await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        google: google,
        age: age,
      );

      await _tap(tester, _google);
      await tester.pump(const Duration(milliseconds: 300));
      age.gate!.complete(const AgeSignal(upper: 12));
      await settleIo(tester);

      expect(google.calls, 0);
      expect(c.read(gateControllerProvider).isBlocked, isTrue);
      expect(find.byType(BlockedScreen), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('…and the email code is never sent', (tester) async {
      final age = FakeAgeSource()..gate = Completer<AgeSignal>();
      final auth = FakeSocialAuth();
      final c = await _onboarding(tester, auth: auth, age: age);

      await tester.enterText(_email, 'kid@aura.test');
      await tester.tap(_send);
      await tester.pump(const Duration(milliseconds: 300));
      age.gate!.complete(const AgeSignal(lower: 0, upper: 12));
      await settleIo(tester);

      expect(auth.emailSends, 0);
      expect(c.read(gateControllerProvider).isBlocked, isTrue);
      await _unmount(tester);
    });

    testWidgets('no signal: waits at most 1 s, then signs in on the DOB '
        'alone', (tester) async {
      final age = FakeAgeSource()..gate = Completer<AgeSignal>(); // never
      final google = FakeGoogle();
      final c = await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        google: google,
        age: age,
      );

      await _tap(tester, _google);
      await tester.pump(const Duration(milliseconds: 400));
      expect(google.calls, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(google.calls, 1);
      await settleIo(tester);
      expect(
        c.read(gateControllerProvider).stage,
        OnboardingStage.firstCheckIn,
      );
      await _unmount(tester);
    });

    testWidgets('a teen signal with an adult DOB: nothing is hidden or '
        'blocked; only the invisible under-18 flag is set', (tester) async {
      final db = memoryDb();
      await io(tester, () async {
        final kv = KvStore(db);
        await kv.set(KvKeys.birthDate, '1990-05-01');
        await kv.set(KvKeys.minorUntil, '2008-05-01');
      });
      final age = FakeAgeSource(const AgeSignal(lower: 13, upper: 15));
      final c = await _onboarding(
        tester,
        auth: FakeSocialAuth(),
        age: age,
        db: db,
      );
      await settleIo(tester);

      // Every sign-in option is still offered.
      expect(_google, findsOneWidget);
      expect(_email, findsOneWidget);

      await _tap(tester, _google);
      await settleIo(tester);
      expect(c.read(gateControllerProvider).isBlocked, isFalse);
      expect(
        c.read(gateControllerProvider).stage,
        OnboardingStage.firstCheckIn,
      );
      // testNow is 8 Oct 2026: the youngest in 13–15 turns 18 in 5 years.
      expect(
        await io(tester, () => KvStore(db).get(KvKeys.minorUntil)),
        '2031-10-08',
      );
      await _unmount(tester);
    });
  });
}
