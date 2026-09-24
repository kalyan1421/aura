import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/safety/safety_center_screen.dart';
import 'package:aura/src/features/shell/app_shell.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'shell_helpers.dart';

/// The Safety Center (`/safety`, F9): what "I need help now" opens. Help
/// first (verified helplines or the local-emergency card), when to call
/// emergency services, the 60 s grounding and the boundary; offline, signed
/// out, from any gate state; focus on the first helpline; Close returns to
/// the screen underneath.

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// A task in progress: a text field and "I need help now".
class _Task extends StatelessWidget {
  const _Task({this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text('task-page'),
          const TextField(key: ValueKey('task-field')),
          HelpNowButton(compact: true, onOpen: onOpen),
        ],
      ),
    ),
  );
}

GoRouter _router({Widget task = const _Task()}) => GoRouter(
  initialLocation: '/task',
  routes: [
    GoRoute(path: '/task', builder: (_, _) => task),
    GoRoute(path: Routes.safety, builder: (_, _) => const SafetyCenterScreen()),
    GoRoute(
      path: Routes.settings,
      builder: (_, _) => const StubPage('settings'),
    ),
  ],
);

/// The Safety Center straight away, over the task page.
Future<GoRouter> _open(
  WidgetTester tester, {
  String? region = 'IN',
  GateState gate = const GateState(stage: OnboardingStage.done),
  AuthRepository auth = const UnavailableAuthRepository(),
  AppDatabase? db,
  FakeSync? sync,
  List<Override> extra = const [],
  String tag = 'en',
}) async {
  _phone(tester);
  final router = _router();
  await tester.pumpWidget(
    shellTestApp(
      [
        // [extra] replaces the helpers' override of the same provider.
        ...testOverrides(
          db: db ?? memoryDb(),
          gate: gate,
          auth: auth,
          sync: sync,
          locale: tag,
        ).where((o) => !extra.any((e) => e.origin == o.origin)),
        deviceRegionProvider.overrideWithValue(region),
        ...extra,
      ],
      router: router,
      tag: tag,
    ),
  );
  await settleIo(tester);
  await tester.tap(find.byType(HelpNowButton));
  await settleIo(tester);
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(SafetyCenterScreen), findsOneWidget);
  return router;
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _inList(Finder f) =>
    find.descendant(of: find.byKey(const ValueKey('safety-list')), matching: f);

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: _inList(find.byType(Scrollable)).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

class _SignedIn implements AuthRepository {
  static const _user = AuthUser(id: 'u1');

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> watchUser() => Stream.value(_user);
  @override
  Future<String?> accessToken() async => 'token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('"I need help now" on Home opens the Safety Center above the '
      'shell; Close returns to Home', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      shellTestApp([
        ...testOverrides(db: memoryDb()),
        deviceRegionProvider.overrideWithValue('IN'),
      ], router: shellTestRouter()),
    );
    await settleIo(tester);
    await tester.tap(find.byType(HelpNowButton));
    await settleIo(tester);
    expect(find.byType(SafetyCenterScreen), findsOneWidget);
    expect(find.byKey(AuraNavBar.barKey).hitTestable(), findsNothing);
    // No second copy on top of itself.
    openSafetyCenter(tester.element(find.byType(SafetyCenterScreen)));
    await settleIo(tester);
    expect(find.byType(SafetyCenterScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await settleIo(tester);
    expect(find.byType(SafetyCenterScreen), findsNothing);
    expect(find.byKey(const ValueKey('home-avatar')), findsOneWidget);
    await _end(tester);
  });

  testWidgets('immediate help first: helplines, when to call emergency '
      'services, the grounding minute, then the boundary', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);

    expect(
      tester.getSemantics(find.text('Help is here')),
      isSemantics(isHeader: true),
    );
    final close = find.byKey(const ValueKey('safety-close'));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('Close'), findsOneWidget);

    // Focus starts on the first helpline (REQ-A11Y-11).
    expect(
      Focus.of(tester.element(find.text('Tele-MANAS · free, 24×7'))).hasFocus,
      isTrue,
    );
    final rows = [
      find.byKey(const ValueKey('safety-call-14416')),
      find.byKey(const ValueKey('safety-call-18008914416')),
      find.byKey(const ValueKey('safety-call-112')),
    ];
    final when = find.byKey(const ValueKey('safety-when-emergency'));
    // Top in the list's own coordinates (the list is lazy and scrolls).
    double top(Finder f) =>
        tester.getRect(f).top +
        tester
            .state<ScrollableState>(_inList(find.byType(Scrollable)).first)
            .position
            .pixels;
    expect(top(rows[0]), lessThan(top(rows[1])));
    expect(top(rows[1]), lessThan(top(rows[2])));
    expect(top(rows[2]), lessThan(top(when)));
    expect(
      find.text(
        'Call emergency services right away if you or someone near you is '
        "in immediate danger, badly hurt, or can't stay safe.",
      ),
      findsOneWidget,
    );
    // Childline is for under-18s only.
    expect(find.text('Childline · for under-18s'), findsNothing);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Call Tele-MANAS · free, 24×7, 14416'),
      ),
      isSemantics(isButton: true, hasTapAction: true),
    );

    final whenTop = top(when);
    final grounding = find.byType(GroundingExercise);
    await _scrollTo(tester, grounding);
    final groundingTop = top(grounding);
    expect(groundingTop, greaterThan(whenTop));
    final disclaimer = find.byKey(const ValueKey('safety-disclaimer'));
    await _scrollTo(tester, disclaimer);
    expect(
      find.text('Aura is not a medical device or an emergency service.'),
      findsOneWidget,
    );
    expect(top(disclaimer), greaterThan(groundingTop));
    handle.dispose();
    await _end(tester);
  });

  for (final (name, region, lines) in [
    ('US', 'US', ['988']),
    ('a country with no listed helpline', 'FR', <String>[]),
    ('no region on the device', null, <String>[]),
  ]) {
    testWidgets(
      '$name: ${lines.isEmpty ? 'the local-emergency card, never '
                'an empty list' : 'its verified line'}',
      (tester) async {
        await _open(tester, region: region);
        for (final dial in lines) {
          expect(find.byKey(ValueKey('safety-call-$dial')), findsOneWidget);
        }
        expect(
          find.byKey(const ValueKey('safety-local-emergency')),
          lines.isEmpty ? findsOneWidget : findsNothing,
        );
        if (lines.isEmpty) {
          expect(
            find.text(
              "If you're in danger right now, please call your local "
              'emergency number.',
            ),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(const ValueKey('safety-when-emergency')),
          findsOneWidget,
        );
        await _end(tester);
      },
    );
  }

  testWidgets('under 18 (and behind the under-13 lock) Childline is listed', (
    tester,
  ) async {
    final db = memoryDb();
    await io(tester, () => KvStore(db).set(KvKeys.minorUntil, '2030-01-01'));
    await _open(tester, db: db);
    expect(find.text('Childline · for under-18s'), findsOneWidget);
    await _end(tester);

    await _open(
      tester,
      gate: GateState(stage: OnboardingStage.welcome, blockedUntil: testNow),
    );
    expect(find.byKey(const ValueKey('safety-call-1098')), findsOneWidget);
    expect(find.byKey(const ValueKey('safety-settings')), findsNothing);
    await _end(tester);
  });

  group('the Settings › Help & Safety link', () {
    testWidgets('signed in after onboarding: shown, and opens Settings', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester, auth: _SignedIn());
      final link = find.byKey(const ValueKey('safety-settings'));
      await _scrollTo(tester, link);
      expect(
        tester.getSemantics(link),
        isSemantics(
          label: 'Help & Safety in Settings',
          hint: 'Support contact, Grievance Officer and policies',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(link);
      await settleIo(tester);
      expect(find.text('settings-page'), findsOneWidget);
      handle.dispose();
      await _end(tester);
    });

    for (final (name, auth, gate) in <(String, AuthRepository, GateState)>[
      (
        'signed out',
        const UnavailableAuthRepository(),
        const GateState(stage: OnboardingStage.done),
      ),
      (
        'still onboarding',
        _SignedIn(),
        const GateState(stage: OnboardingStage.firstCheckIn),
      ),
    ]) {
      testWidgets('$name: hidden', (tester) async {
        await _open(tester, auth: auth, gate: gate);
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('safety-disclaimer')),
        );
        expect(find.byKey(const ValueKey('safety-settings')), findsNothing);
        await _end(tester);
      });
    }
  });

  testWidgets('offline and signed out: everything shows at once, no spinner', (
    tester,
  ) async {
    await _open(
      tester,
      extra: [connectivityProvider.overrideWith((ref) => Stream.value(false))],
    );
    expect(find.byKey(const ValueKey('safety-call-14416')), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is ProgressIndicator && w.value == null),
      findsNothing,
    );
    await _end(tester);
  });

  testWidgets('a device that can\'t dial shows the number with Copy under '
      'that row', (tester) async {
    final launched = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return false;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _launcher,
        null,
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('safety-call-112')));
    await tester.pump();
    expect(launched, ['tel:112']);
    final note = find.byKey(const ValueKey('safety-call-failed-112'));
    expect(note, findsOneWidget);
    expect(
      find.text("This phone can't place the call. The number is 112."),
      findsOneWidget,
    );
    expect(
      tester.getRect(note).top,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('safety-call-112'))).bottom,
      ),
    );
    await _end(tester);
  });

  testWidgets('Close returns to the task underneath with its input kept', (
    tester,
  ) async {
    var opened = 0;
    _phone(tester);
    await tester.pumpWidget(
      shellTestApp(
        testOverrides(db: memoryDb()),
        router: _router(task: _Task(onOpen: () => opened++)),
      ),
    );
    await settleIo(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-field')),
      'half a thought',
    );
    await tester.tap(find.byType(HelpNowButton));
    await tester.pumpAndSettle();
    expect(opened, 1); // e.g. a breathing pacer pauses (REQ-SAN-08)
    expect(find.byType(SafetyCenterScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await tester.pumpAndSettle();
    expect(find.text('task-page'), findsOneWidget);
    expect(find.text('half a thought'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('opened on its own (nothing underneath), Close hands over to '
      'the gate', (tester) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: Routes.safety,
      routes: [
        GoRoute(path: Routes.root, builder: (_, _) => const Text('root-page')),
        GoRoute(
          path: Routes.safety,
          builder: (_, _) => const SafetyCenterScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      shellTestApp(testOverrides(db: memoryDb()), router: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await tester.pumpAndSettle();
    expect(find.text('root-page'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('without the app router the button still opens the Safety '
      'Center', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: memoryDb()),
        child: localized(const Scaffold(body: Center(child: HelpNowButton()))),
      ),
    );
    await tester.tap(find.byType(HelpNowButton));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyCenterScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyCenterScreen), findsNothing);
    await _end(tester);
  });

  testWidgets('the finished minute ticks off Breathe for an onboarded '
      'person (F2)', (tester) async {
    final sync = FakeSync();
    await _open(tester, sync: sync);
    final toggle = find.byKey(const ValueKey('grounding-toggle'));
    await _scrollTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    await settleIo(tester);
    expect(find.byKey(const ValueKey('safety-breathe-logged')), findsOneWidget);
    expect(sync.writes, 1);
    await _end(tester);
  });

  testWidgets('the crisis interception keeps the support sheet, over the '
      'navigation bar too', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      shellTestApp(
        testOverrides(db: memoryDb()),
        router: shellTestRouter(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSupportSheet(context, crisis: true),
                  child: const Text('save'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleIo(tester);
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportSheet), findsOneWidget);
    expect(find.byType(SafetyCenterScreen), findsNothing);
    expect(find.text('It sounds like a lot right now.'), findsOneWidget);
    expect(find.byKey(AuraNavBar.barKey).hitTestable(), findsNothing);
    await _end(tester);
  });

  group('200% text (real fonts): nothing overflows or clips', () {
    setUpAll(loadRealFonts);

    for (final tag in const ['en', 'te', 'te-Latn', 'hi', 'hi-Latn']) {
      testWidgets(tag, (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _open(tester, tag: tag);
        expect(tester.takeException(), isNull);
        for (final key in [
          'safety-call-14416',
          'safety-when-emergency',
          'grounding-toggle',
          'safety-disclaimer',
        ]) {
          final target = find.byKey(ValueKey(key));
          await _scrollTo(tester, target);
          expect(tester.takeException(), isNull, reason: key);
          for (final p in tester.renderObjectList<RenderParagraph>(
            find.descendant(of: target, matching: find.byType(RichText)),
          )) {
            expect(p.didExceedMaxLines, isFalse, reason: key);
          }
        }
        await _end(tester);
      });
    }
  });
}
