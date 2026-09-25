import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/features/auth/auth_repository.dart';
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/widget/widget_background.dart';
import 'package:aura/src/features/widget/widget_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'widget_fakes.dart';

/// F11 background refresh ("The app imports it into Drift on next launch or
/// background refresh, then syncs"): the headless run imports what the
/// widget saved through the same importer, pushes the outbox, keeps the
/// capsule step for the next app open, and does nothing signed out, before
/// onboarding, under the under-13 lock or without an owner token.
void main() {
  const ids = Ids();
  const owner = 'owner-bg';
  late AppDatabase db;
  late MemoryWidgetHost host;
  late FakeSync sync;

  setUp(() {
    db = memoryDb();
    host = MemoryWidgetHost();
    sync = FakeSync();
  });
  tearDown(() => db.close());

  ProviderContainer container({
    AuthRepository auth = const _SignedIn(),
    GateState gate = const GateState(stage: OnboardingStage.done),
  }) {
    final c = ProviderContainer(
      overrides: testOverrides(
        db: db,
        sync: sync,
        auth: auth,
        gate: gate,
        widgetHost: host,
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> setOwner() => KvStore(db).set(WidgetKvKeys.owner, owner);

  test(
    'imports once, pushes, and keeps the capsule step for the next open',
    () async {
      await setOwner();
      final id = ids.v7();
      host.pending = [
        widgetRecord(
          id: id,
          moodId: 'calm',
          deviceTs: testNow.subtract(const Duration(minutes: 5)),
          localDay: '2026-10-08',
          owner: owner,
        ),
      ];
      final c = container();

      expect(
        await WidgetBackgroundSync(c).run(),
        WidgetBackgroundOutcome.imported,
      );
      expect(await db.select(db.checkIns).get(), hasLength(1));
      // Not acknowledged (the widget keeps showing today's check-in until
      // the app republishes); marked so the OS doesn't wake Flutter again.
      expect(host.acked, isEmpty);
      expect(host.backgroundHandled, [id]);
      expect(
        sync.drainCalls,
        1,
        reason: 'the outbox is pushed in the same run',
      );
      expect(jsonDecode((await KvStore(db).get(WidgetKvKeys.followUps))!), [
        id,
      ]);

      // Run again before the widget pruned: nothing new, nothing twice.
      expect(
        await WidgetBackgroundSync(c).run(),
        WidgetBackgroundOutcome.nothingImported,
      );
      expect(await db.select(db.checkIns).get(), hasLength(1));

      // The next app open takes the follow-up once, with its mood.
      final taken = await takeWidgetFollowUps(KvStore(db), db);
      expect(taken.map((c) => '${c.id}:${c.mood.id}'), ['$id:calm']);
      expect(await takeWidgetFollowUps(KvStore(db), db), isEmpty);
    },
  );

  test('signed out, not onboarded, under-13 lock or no owner token: skipped, '
      'nothing read or pushed', () async {
    host.pending = [
      widgetRecord(id: ids.v7(), deviceTs: testNow, owner: owner),
    ];
    // No owner token yet.
    expect(
      await WidgetBackgroundSync(container()).run(),
      WidgetBackgroundOutcome.skipped,
    );
    await setOwner();
    expect(
      await WidgetBackgroundSync(
        container(auth: const UnavailableAuthRepository()),
      ).run(),
      WidgetBackgroundOutcome.skipped,
    );
    expect(
      await WidgetBackgroundSync(
        container(gate: const GateState(stage: OnboardingStage.welcome)),
      ).run(),
      WidgetBackgroundOutcome.skipped,
    );
    expect(
      await WidgetBackgroundSync(
        container(
          gate: GateState(
            stage: OnboardingStage.done,
            blockedUntil: testNow.add(const Duration(days: 30)),
          ),
        ),
      ).run(),
      WidgetBackgroundOutcome.skipped,
    );
    expect(host.readCalls, 0);
    expect(sync.drainCalls, 0);
    expect(await db.select(db.checkIns).get(), isEmpty);
  });

  test(
    'another account’s widget records are marked handled, never imported',
    () async {
      await setOwner();
      host.pending = [
        widgetRecord(id: ids.v7(), deviceTs: testNow, owner: 'someone-else'),
      ];
      expect(
        await WidgetBackgroundSync(container()).run(),
        WidgetBackgroundOutcome.nothingImported,
      );
      expect(await db.select(db.checkIns).get(), isEmpty);
      expect(host.acked, isEmpty);
      expect(host.backgroundHandled, hasLength(1));
      expect(await KvStore(db).get(WidgetKvKeys.followUps), isNull);
    },
  );

  test('follow-ups: deduplicated, capped, deleted check-ins dropped', () async {
    final kv = KvStore(db);
    await rememberWidgetFollowUps(kv, ['a', 'b']);
    await rememberWidgetFollowUps(kv, ['b', 'c']);
    expect(jsonDecode((await kv.get(WidgetKvKeys.followUps))!), [
      'a',
      'b',
      'c',
    ]);
    // None of these exist as check-ins: taken and dropped.
    expect(await takeWidgetFollowUps(kv, db), isEmpty);
    expect(await kv.get(WidgetKvKeys.followUps), isNull);

    await rememberWidgetFollowUps(kv, [for (var i = 0; i < 60; i++) 'id$i']);
    final kept = jsonDecode((await kv.get(WidgetKvKeys.followUps))!) as List;
    expect(kept, hasLength(50));
    expect(kept.first, 'id10');
  });
}

class _SignedIn implements AuthRepository {
  const _SignedIn();
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
