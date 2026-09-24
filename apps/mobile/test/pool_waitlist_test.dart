import 'dart:async';
import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/router/routes.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/push/push_inbox.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/rooms/pool_waitlist.dart';
import 'package:aura/src/features/rooms/rooms_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// "Tell me when they open" (Hindi + Hinglish rooms; PRD 06b F5, 14-states):
/// the tap is kept on the phone and queued for the one write path
/// (`room_pool_waitlist` upsert), and the server's one `rooms_pool_open` push
/// is handled like the others — a calm in-app notice while Aura is open
/// ("See rooms"), Rooms when tapped, its own Android channel.

class _Source implements PushInboxSource {
  final foregroundCtl = StreamController<PushEnvelope>.broadcast();
  final openedCtl = StreamController<PushEnvelope>.broadcast();

  @override
  Stream<PushEnvelope> get foreground => foregroundCtl.stream;
  @override
  Stream<PushEnvelope> get opened => openedCtl.stream;
  @override
  Future<PushEnvelope?> initial() async => null;
  @override
  Future<void> quietWhileOpen() async {}
}

class _NoCapsules implements CapsulePushBridge {
  @override
  Future<bool> shouldShow(String capsuleId) async => false;
  @override
  Future<void> open(BuildContext context, String? capsuleId) async {}
}

const _poolOpen = PushEnvelope(type: PushTypes.roomsPoolOpen);

Future<(GoRouter, _Source, PushInbox)> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('home-page')),
      ),
      GoRoute(
        path: Routes.rooms,
        builder: (_, _) => const Scaffold(body: Text('rooms-page')),
      ),
    ],
  );
  final source = _Source();
  final inbox = PushInbox(
    source: source,
    router: PushRouter(
      router: () => router,
      gate: () => const GateState(stage: OnboardingStage.done),
      capsules: _NoCapsules.new,
    ),
    capsules: _NoCapsules.new,
    checkedInToday: () async => false,
    present: (push, open) => showPushNotice(router, push, open),
  );
  addTearDown(inbox.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildAuraTheme(const Locale('en')),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...systemLocalizationDelegates,
      ],
      routerConfig: router,
    ),
  );
  inbox.start();
  await tester.pumpAndSettle();
  return (router, source, inbox);
}

void main() {
  group('the tap', () {
    test('is kept on this phone and queued as room_pool_waitlist upsert '
        '{pool: hi}, then sync is nudged', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db, const Ids());
      var nudged = 0;
      final waitlist = PoolWaitlist(
        db: db,
        kv: KvStore(db),
        outbox: outbox,
        time: testTime,
        notifySync: () => nudged++,
      );
      await waitlist.request();
      expect(await db.getValue(roomsNotifyHiPoolKey), '1');
      final rows = await outbox.due(
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(rows, hasLength(1));
      expect(rows.single.entity, 'room_pool_waitlist');
      expect(rows.single.op, 'upsert');
      expect(jsonDecode(rows.single.payload), {'pool': 'hi'});
      expect(rows.single.tz, 'Asia/Kolkata');
      expect(nudged, 1);
    });

    test('a sync nudge that fails never loses the tap', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final outbox = OutboxRepository(db, const Ids());
      await PoolWaitlist(
        db: db,
        kv: KvStore(db),
        outbox: outbox,
        time: testTime,
        notifySync: () => throw StateError('sync not ready'),
      ).request();
      expect(
        await outbox.due(DateTime.now().add(const Duration(days: 1))),
        hasLength(1),
      );
    });
  });

  group('the push', () {
    testWidgets('while Aura is open: the calm notice with "See rooms", shown '
        'once, which opens Rooms', (tester) async {
      final (_, source, inbox) = await _pump(tester);
      source.foregroundCtl.add(_poolOpen);
      await tester.pumpAndSettle();
      expect(
        find.text('Hindi and Hinglish rooms are open now.'),
        findsOneWidget,
      );
      await tester.tap(find.text('See rooms'));
      await tester.pumpAndSettle();
      expect(find.text('rooms-page'), findsOneWidget);

      await inbox.onForeground(_poolOpen); // a duplicate: nothing more
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tapped from the notification shade: Rooms', (tester) async {
      final (_, source, _) = await _pump(tester);
      source.openedCtl.add(_poolOpen);
      await tester.pumpAndSettle();
      expect(find.text('rooms-page'), findsOneWidget);
    });

    test('goes to the "Rooms & Lantern Hour" channel (the server\'s '
        'channel_id)', () {
      expect(PushChannels.rooms, 'rooms');
      final l = lookupAppLocalizations(const Locale('en'));
      expect(l.notif_channelRooms, 'Rooms & Lantern Hour');
    });
  });
}
