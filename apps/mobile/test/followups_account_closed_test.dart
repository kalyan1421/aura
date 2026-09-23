import 'dart:convert';

import 'package:aura/src/app.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/account/account_providers.dart';
import 'package:aura/src/features/account/delete_account_screen.dart';
import 'package:aura/src/features/auth/account_closed.dart';
import 'package:aura/src/features/auth/auth_providers.dart';
import 'package:aura/src/features/auth/social_sign_in.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/rooms/rooms_api.dart';
import 'package:aura/src/features/rooms/rooms_providers.dart';
import 'package:aura/src/features/rooms/rooms_repository.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'auth_social_fakes.dart';
import 'helpers.dart';

/// An account closed for breaking the rules (F9 / 19 admin console;
/// contracts/api/v1.md "Account closed"): after sign-in (`GET /v1/account` →
/// `accountClosed`) or on any `403 account_closed`, the app shows one calm
/// full screen — the PRD's line and nothing about why, how to ask for a
/// review, "Delete my account", "Sign out", help one tap away — instead of
/// the app.

// ---- fakes -------------------------------------------------------------------

class _Standing implements AccountStanding {
  _Standing(this.closed);

  bool closed;
  Object? fail;
  int calls = 0;

  @override
  Future<bool> isClosed() async {
    calls++;
    final f = fail;
    if (f != null) throw f;
    return closed;
  }
}

class _Presenter implements AccountClosedPresenter {
  int shows = 0;

  @override
  void show() => shows++;
}

/// The rooms / safety client (features/rooms): every call answers 403 [code].
class _RefusingRoomsApi implements RoomsApi {
  _RefusingRoomsApi(this.code);

  final String code;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(ApiException(code: code, status: 403));
}

/// Answers every request with [status] + [body]; records the paths.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuraApi _api(_Adapter adapter, {void Function()? onClosed}) => AuraApi(
  baseUrl: 'http://test',
  accessToken: () async => 'jwt',
  dio: Dio(
    BaseOptions(
      baseUrl: 'http://test',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter,
  onAccountClosed: onClosed,
);

const _closedBody = {
  'code': 'account_closed',
  'message': "This account was closed for breaking Aura's rules.",
};

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
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

final _screen = find.byType(AccountClosedScreen);

/// A route transition, without pumpAndSettle (the sky keeps animating).
Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

// ---- tests -------------------------------------------------------------------

void main() {
  group('AuraApi', () {
    test('a 403 account_closed from any call tells the hook once, and still '
        'throws the error to the caller', () async {
      var told = 0;
      final api = _api(_Adapter(403, _closedBody), onClosed: () => told++);
      final err = await api.snapshot().then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );
      expect(
        err,
        isA<ApiException>().having(
          (e) => e.isAccountClosed,
          'isAccountClosed',
          isTrue,
        ),
      );
      await Future<void>.delayed(Duration.zero); // the hook runs in a microtask
      expect(told, 1);

      final other = _api(
        _Adapter(403, {'code': 'account_deletion_pending', 'message': 'x'}),
        onClosed: () => told++,
      );
      await other.snapshot().then((_) {}, onError: (Object _) {});
      await Future<void>.delayed(Duration.zero);
      expect(told, 1); // only account_closed
    });

    test(
      'accountClosed() reads GET /v1/account (the key is absent when open)',
      () async {
        final closed = _Adapter(200, {
          'deletionScheduledFor': null,
          'accountClosed': true,
        });
        expect(await _api(closed).accountClosed(), isTrue);
        expect(closed.paths, ['/v1/account']);
        expect(
          await _api(_Adapter(200, {'deletionScheduledFor': null}))
              .accountClosed(),
          isFalse,
        );
      },
    );

    test('a hook that throws never changes the error', () async {
      final api = _api(
        _Adapter(403, _closedBody),
        onClosed: () => throw StateError('ui'),
      );
      await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('AccountClosed', () {
    late FakeSocialAuth auth;
    late _Standing standing;
    late _Presenter presenter;
    late ProviderContainer c;

    setUp(() {
      auth = FakeSocialAuth()..user = socialUser;
      standing = _Standing(true);
      presenter = _Presenter();
      final db = memoryDb();
      c = ProviderContainer(
        overrides: [
          ...testOverrides(db: db, auth: auth),
          accountStandingProvider.overrideWithValue(standing),
          accountClosedPresenterProvider.overrideWithValue(presenter),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
    });

    test('after sign-in: closed → held for this account and shown', () async {
      expect(await c.read(accountClosedProvider.notifier).check(), isTrue);
      expect(c.read(accountClosedProvider), socialUser.id);
      expect(presenter.shows, 1);
    });

    test('show: false keeps the answer for the caller (sign-in asks about a '
        'scheduled deletion first)', () async {
      final notifier = c.read(accountClosedProvider.notifier);
      expect(await notifier.check(show: false), isTrue);
      expect(c.read(accountClosedProvider), socialUser.id);
      expect(presenter.shows, 0);
    });

    test('open, unreachable, slow or signed out → carry on (a later 403 still '
        'shows it)', () async {
      final notifier = c.read(accountClosedProvider.notifier);
      standing.closed = false;
      expect(await notifier.check(), isFalse);
      standing.fail = const ApiException(
        code: 'connectionError',
        isNetwork: true,
      );
      expect(await notifier.check(), isFalse);
      standing
        ..fail = null
        ..closed = true;
      auth.user = null;
      expect(await notifier.check(), isFalse);
      expect(standing.calls, 2); // no call without an account
      expect(c.read(accountClosedProvider), isNull);
      expect(presenter.shows, 0);
    });

    test('a 403 from anywhere shows it (again if it was dropped); signing out '
        'clears it', () async {
      final sub = c.listen(authUserProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = c.read(accountClosedProvider.notifier);
      notifier.report();
      notifier.report();
      expect(presenter.shows, 2); // the presenter never stacks it twice
      expect(c.read(accountClosedProvider), socialUser.id);
      await Future<void>.delayed(Duration.zero);
      auth.signIn(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(accountClosedProvider), isNull);
      notifier.report(); // signed out: nothing to show
      expect(presenter.shows, 2);
    });
  });

  group('the screen', () {
    List<Override> app({
      required FakeSocialAuth auth,
      required GateState gate,
      _Standing? standing,
    }) => [
      ...testOverrides(db: memoryDb(), auth: auth, gate: gate),
      accountRepositoryProvider.overrideWithValue(FakeAccount()),
      socialSignInProvider.overrideWithValue(
        SocialSignInService(
          config: iosSocial,
          exchange: auth,
          google: FakeGoogle(),
          apple: FakeApple(),
        ),
      ),
      ageSignalSourceProvider.overrideWithValue(FakeAgeSource()),
      accountStandingProvider.overrideWithValue(standing ?? _Standing(false)),
    ];

    testWidgets('signing in to a closed account shows it instead of the app; '
        'Sign out goes back to Welcome', (tester) async {
      _phone(tester);
      final auth = FakeSocialAuth();
      final standing = _Standing(true);
      final c = ProviderContainer(
        overrides: app(
          auth: auth,
          gate: const GateState(stage: OnboardingStage.signIn),
          standing: standing,
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const AuraApp()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await _tap(tester, find.byKey(const ValueKey('signin-apple')));
      await settleIo(tester);
      await _transition(tester);

      expect(standing.calls, 1);
      expect(_screen, findsOneWidget);
      expect(find.text('This account is closed'), findsOneWidget);
      expect(
        find.text("This account was closed for breaking Aura's rules."),
        findsOneWidget,
      );
      expect(
        c.read(gateControllerProvider).stage,
        OnboardingStage.signIn,
      ); // never entered the app

      await _tap(tester, find.byKey(const ValueKey('closed-sign-out')));
      await settleIo(tester, rounds: 10);
      await _transition(tester);
      expect(auth.currentUser, isNull);
      expect(_screen, findsNothing);
      expect(c.read(gateControllerProvider).stage, OnboardingStage.welcome);
      expect(c.read(accountClosedProvider), isNull);
      await _unmount(tester);
    });

    testWidgets('an open account signs in as before (no screen)', (
      tester,
    ) async {
      _phone(tester);
      final auth = FakeSocialAuth();
      final c = ProviderContainer(
        overrides: app(
          auth: auth,
          gate: const GateState(stage: OnboardingStage.signIn),
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const AuraApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _tap(tester, find.byKey(const ValueKey('signin-apple')));
      await settleIo(tester);
      expect(_screen, findsNothing);
      expect(
        c.read(gateControllerProvider).stage,
        OnboardingStage.firstCheckIn,
      );
      await _unmount(tester);
    });

    testWidgets(
      'a 403 while using the app covers it once; Back stays; help and '
      '"Delete my account" open above it',
      (tester) async {
        _phone(tester);
        final auth = FakeSocialAuth()..user = socialUser;
        // Signed in, on the first check-in (the rest of the app is the same route stack).
        final c = ProviderContainer(
          overrides: app(
            auth: auth,
            gate: const GateState(stage: OnboardingStage.firstCheckIn),
          ),
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const AuraApp()),
        );
        await settleIo(tester);

        c.read(accountClosedProvider.notifier).report();
        await _transition(tester);
        c.read(accountClosedProvider.notifier).report(); // a second 403
        await _transition(tester);
        expect(_screen, findsOneWidget);

        final nav = tester.state<NavigatorState>(
          find.ancestor(of: _screen, matching: find.byType(Navigator)).first,
        );
        await nav.maybePop();
        await _transition(tester);
        expect(_screen, findsOneWidget); // Back does nothing

        // Help is never locked.
        await _tap(tester, find.text('I need help now'));
        await _transition(tester);
        expect(find.byType(SafetyCenterScreen), findsOneWidget);
        await nav.maybePop();
        await _transition(tester);
        expect(find.byType(SafetyCenterScreen), findsNothing);
        expect(_screen, findsOneWidget);

        await _tap(tester, find.byKey(const ValueKey('closed-delete')));
        await _transition(tester);
        expect(find.byType(DeleteAccountScreen), findsOneWidget);
        await _unmount(tester);
      },
    );

    testWidgets('asking for a review writes to the Grievance Officer (subject '
        'only); a phone without mail shows the address', (tester) async {
      _phone(tester);
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return false; // no mail app
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db: memoryDb(), auth: FakeSocialAuth()),
          child: localized(
            const AccountClosedScreen(
              reviewName: 'Grievance Officer AK',
              reviewEmail: 'grievance@aura.test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ask for a review'), findsOneWidget);
      expect(find.textContaining('grievance@aura.test'), findsOneWidget);
      expect(find.textContaining('Grievance Officer AK'), findsOneWidget);
      // No reason code, category or report detail anywhere (no tipping off).
      for (final word in [
        'grooming',
        'harassment',
        'report',
        'strike',
        'ban',
      ]) {
        expect(
          find.textContaining(RegExp(word, caseSensitive: false)),
          findsNothing,
        );
      }
      await _tap(tester, find.byKey(const ValueKey('closed-review')));
      await tester.pumpAndSettle();
      final uri = Uri.parse(launched.single);
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'grievance@aura.test');
      expect(uri.queryParameters, {
        'subject': 'Review of a closed account',
      }); // nothing about the person
      // No mail app: the calm fallback names the address.
      expect(find.byKey(const ValueKey('closed-mail-failed')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('Telugu and Tenglish copy is present', (tester) async {
      for (final locale in const [
        Locale('te'),
        Locale.fromSubtags(languageCode: 'te', scriptCode: 'Latn'),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: testOverrides(db: memoryDb(), auth: FakeSocialAuth()),
            child: localized(
              const AccountClosedScreen(reviewEmail: 'g@aura.test'),
              locale: locale,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('This account is closed'), findsNothing);
        expect(find.byKey(const ValueKey('closed-title')), findsOneWidget);
      }
      await _unmount(tester);
    });
  });

  group('the rooms client lands on the same screen', () {
    test('a 403 account_closed from any rooms / safety call runs the hook; '
        'other refusals do not', () async {
      var closed = 0;
      var pending = 0;
      RoomsRepository repo(String code) => RoomsRepository(
        api: _RefusingRoomsApi(code),
        isOnline: () => true,
        timezone: () => 'Asia/Kolkata',
        onDeletionPending: () => pending++,
        onAccountClosed: () => closed++,
      );
      await expectLater(
        repo('account_closed').standing(),
        throwsA(
          isA<RoomsFailure>().having(
            (f) => f.kind,
            'kind',
            RoomsFailureKind.closed,
          ),
        ),
      );
      expect((closed, pending), (1, 0));
      await expectLater(
        repo('account_deletion_pending').standing(),
        throwsA(isA<RoomsFailure>()),
      );
      await expectLater(
        repo('rooms_suspended').standing(),
        throwsA(isA<RoomsFailure>()),
      );
      expect((closed, pending), (1, 1));
    });

    test('wired in the app: the rooms 403 shows the closed screen', () async {
      final presenter = _Presenter();
      final db = memoryDb();
      final c = ProviderContainer(
        overrides: [
          ...testOverrides(db: db, auth: FakeSocialAuth()..user = socialUser),
          roomsApiProvider.overrideWithValue(
            _RefusingRoomsApi('account_closed'),
          ),
          accountClosedPresenterProvider.overrideWithValue(presenter),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      await expectLater(
        c.read(roomsRepositoryProvider).standing(),
        throwsA(isA<RoomsFailure>()),
      );
      expect(presenter.shows, 1);
      expect(c.read(accountClosedProvider), socialUser.id);
    });
  });

  test('the screen is a full page, not a dismissible dialog', () {
    final route = AccountClosedScreen.route();
    expect(route, isA<MaterialPageRoute<void>>());
    expect((route as MaterialPageRoute<void>).fullscreenDialog, isFalse);
    expect(route.barrierDismissible, isFalse);
  });
}
