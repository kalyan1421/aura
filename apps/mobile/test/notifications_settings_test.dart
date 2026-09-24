import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'voice_fakes.dart';

/// Settings › Notifications (F14): the master switch, the daily reminder
/// (on/off + time), capsule pushes, quiet hours, discreet mode — each a
/// local write + an outbox patch; a reminder inside quiet hours needs the
/// one-time confirmation; OS permission off → a calm note with a Settings
/// link (never re-asking within 30 days of a decline).

class _SignedIn implements AuthRepository {
  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser =>
      const AuthUser(id: 'user-a', email: 'a@aura.test');
  @override
  Stream<AuthUser?> watchUser() async* {
    yield currentUser;
  }

  @override
  Future<String?> accessToken() async => 'jwt';
  @override
  Future<void> sendEmailCode(String email) async {}
  @override
  Future<void> verifyEmailCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

class _Harness {
  _Harness(this.db, this.messaging, this.platform, this.container);
  final AppDatabase db;
  final FakeMessaging messaging;
  final FakePlatform platform;
  final ProviderContainer container;

  Future<List<Map<String, dynamic>>> patches(WidgetTester tester) async {
    final rows = await io(tester, () => db.select(db.outbox).get());
    return [
      for (final r in rows)
        if (r.entity == 'notification_prefs')
          jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  PushPermission permission = PushPermission.authorized,
  Map<String, dynamic>? softAsk,
  Locale locale = const Locale('en'),
}) async {
  // Tall enough for every section (five languages in the picker).
  tester.view.physicalSize = const Size(390 * 3, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final db = memoryDb();
  if (softAsk != null) {
    await io(tester, () => KvStore(db).setJson(KvKeys.pushSoftAsk, softAsk));
  }
  final messaging = FakeMessaging()..granted = permission;
  final platform = FakePlatform();
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(db: db, auth: _SignedIn()),
      clockProvider.overrideWithValue(FixedClock(testNow)),
      pushMessagingProvider.overrideWithValue(messaging),
      auraPlatformProvider.overrideWithValue(platform),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: [
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildAuraTheme(locale),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...systemLocalizationDelegates,
        ],
        routerConfig: router,
        // 24-hour times: predictable text and a picker without AM/PM.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    ),
  );
  await settleIo(tester);
  return _Harness(db, messaging, platform, container);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// Opens the time picker from [row] and enters [hh]:[mm] (24 h input mode).
Future<void> _pickTime(WidgetTester tester, String row, int hh, int mm) async {
  await tester.tap(_key(row));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hh.toString().padLeft(2, '0'));
  await tester.enterText(fields.at(1), mm.toString().padLeft(2, '0'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the section sits between Account and Help & Safety, announced '
      'as a heading, with the PRD defaults', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    final y = {
      for (final k in ['comfort', 'account', 'notifications', 'help'])
        k: tester.getTopLeft(_key('set-section-$k')).dy,
    };
    expect(y['comfort']!, lessThan(y['account']!));
    expect(y['account']!, lessThan(y['notifications']!));
    expect(y['notifications']!, lessThan(y['help']!));
    expect(
      tester.getSemantics(_key('set-section-notifications')),
      isSemantics(isHeader: true, label: 'Notifications'),
    );

    bool on(String k) => tester.widget<SwitchListTile>(_key(k)).value;
    expect(on('set-ntf-master'), isTrue);
    expect(on('set-ntf-reminder'), isFalse);
    expect(on('set-ntf-capsule'), isTrue);
    expect(on('set-ntf-discreet'), isFalse);
    expect(
      find.text('Quiet hours: nothing is sent 23:00–08:00.'),
      findsOneWidget,
    );
    expect(_key('set-ntf-off-note'), findsNothing); // permission granted
    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('each switch is a local write + a patch of just that setting; '
      'the master switch greys the rest out', (tester) async {
    final h = await _pump(tester);
    await tester.tap(_key('set-ntf-reminder'));
    await settleIo(tester);
    expect(
      find.text(
        "One gentle nudge a day, at 20:00. Skipped once you've checked in.",
      ),
      findsOneWidget,
    );
    await tester.tap(_key('set-ntf-capsule'));
    await settleIo(tester);
    await tester.tap(_key('set-ntf-discreet'));
    await settleIo(tester);
    await tester.tap(_key('set-ntf-master'));
    await settleIo(tester);

    expect(await h.patches(tester), [
      {'reminderTime': '20:00', 'reminderEnabled': true},
      {'capsuleUnlocked': false},
      {'discreet': true},
      {'enabled': false},
    ]);
    for (final k in [
      'set-ntf-reminder',
      'set-ntf-capsule',
      'set-ntf-discreet',
    ]) {
      expect(
        tester.widget<SwitchListTile>(_key(k)).onChanged,
        isNull,
        reason: k,
      );
    }
    expect(
      tester.widget<ListTile>(_key('set-ntf-quiet-start')).enabled,
      isFalse,
    );
    await _unmount(tester);
  });

  testWidgets('a reminder time inside quiet hours asks once: "Keep it quiet" '
      'changes nothing, "Send it anyway" confirms it', (tester) async {
    final h = await _pump(tester);
    await tester.tap(_key('set-ntf-reminder'));
    await settleIo(tester);

    await _pickTime(tester, 'set-ntf-reminder-time', 23, 30);
    expect(_key('set-ntf-quiet-confirm'), findsOneWidget);
    expect(
      find.text(
        'Aura stays silent 23:00–08:00. Send your reminder at 23:30 anyway?',
      ),
      findsOneWidget,
    );
    await tester.tap(_key('set-ntf-quiet-no'));
    await settleIo(tester);
    expect(await h.patches(tester), hasLength(1)); // nothing changed

    await _pickTime(tester, 'set-ntf-reminder-time', 23, 30);
    await tester.tap(_key('set-ntf-quiet-yes'));
    await settleIo(tester);
    // Back outside quiet hours: the confirmation is dropped (asked again
    // the next time).
    await _pickTime(tester, 'set-ntf-reminder-time', 21, 15);
    expect(_key('set-ntf-quiet-confirm'), findsNothing);
    await settleIo(tester);

    expect((await h.patches(tester)).skip(1), [
      {
        'reminderTime': '23:30',
        'reminderEnabled': true,
        'reminderInQuietHours': true,
      },
      {
        'reminderTime': '21:15',
        'reminderEnabled': true,
        'reminderInQuietHours': false,
      },
    ]);
    await _unmount(tester);
  });

  testWidgets('quiet hours that come to cover the reminder ask the same '
      'question; the new hours apply either way', (tester) async {
    final h = await _pump(tester);
    await tester.tap(_key('set-ntf-reminder'));
    await settleIo(tester);

    await _pickTime(tester, 'set-ntf-quiet-start', 19, 0);
    expect(_key('set-ntf-quiet-confirm'), findsOneWidget);
    await tester.tap(_key('set-ntf-quiet-yes'));
    await settleIo(tester);
    await _pickTime(tester, 'set-ntf-quiet-end', 7, 0);
    await settleIo(tester);

    expect((await h.patches(tester)).skip(1), [
      {'quietStart': '19:00', 'reminderInQuietHours': true},
      {'quietEnd': '07:00'},
    ]);
    expect(
      find.text('Quiet hours: nothing is sent 19:00–07:00.'),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('notifications off after a recent "Not now": a calm note that '
      'only links to the phone settings (no re-ask within 30 days)', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      permission: PushPermission.denied,
      softAsk: {
        'answer': 'notNow',
        'at': testNow.subtract(const Duration(days: 2)).toIso8601String(),
      },
    );
    expect(_key('set-ntf-off-note'), findsOneWidget);
    expect(
      find.text(
        "Notifications are off for Aura on this phone. Your choices here still apply once they're on.",
      ),
      findsOneWidget,
    );
    expect(_key('set-ntf-turn-on'), findsNothing);
    await tester.tap(_key('set-ntf-open-settings'));
    await settleIo(tester);
    expect(h.platform.settingsOpened, 1);
    expect(h.messaging.requests, isEmpty);
    // The settings still work (they apply once notifications are on).
    await tester.tap(_key('set-ntf-discreet'));
    await settleIo(tester);
    expect(await h.patches(tester), [
      {'discreet': true},
    ]);
    await _unmount(tester);
  });

  testWidgets('never asked: "Turn on" shows the OS prompt once and the note '
      'goes when allowed', (tester) async {
    final h = await _pump(tester, permission: PushPermission.notDetermined);
    await tester.tap(_key('set-ntf-turn-on'));
    await settleIo(tester);
    expect(h.messaging.requests, [false]);
    expect(_key('set-ntf-off-note'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('30+ days after a decline the one re-ask is offered; after it, '
      'only the phone settings link', (tester) async {
    final h = await _pump(
      tester,
      permission: PushPermission.denied,
      softAsk: {
        'answer': 'notNow',
        'at': testNow.subtract(const Duration(days: 31)).toIso8601String(),
      },
    );
    h.messaging.promptResult = PushPermission.denied;
    await tester.tap(_key('set-ntf-turn-on'));
    await settleIo(tester);
    expect(h.messaging.requests, [false]);
    expect(_key('set-ntf-turn-on'), findsNothing);
    expect(_key('set-ntf-open-settings'), findsOneWidget);
    final ask = await io(
      tester,
      () => KvStore(h.db).getJson(KvKeys.pushSoftAsk),
    );
    expect(ask?['reaskedAt'], isNotNull);
    await _unmount(tester);
  });

  testWidgets('Telugu: the section renders in the app language', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('te'));
    expect(find.text('నోటిఫికేషన్లు'), findsOneWidget);
    expect(find.text('రోజువారీ చెక్-ఇన్ రిమైండర్'), findsOneWidget);
    await _unmount(tester);
  });
}
