import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/features/health/health_source.dart';
import 'package:aura/src/features/health/platform_health_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// W06: the step adapter's logic over a fake platform (the real plugin needs a
/// device). Read-only, steps only, and every failure reads as "unavailable" or
/// "unknown", never as an error.

class _FakePlatform implements HealthPlatform {
  _FakePlatform({this.isIos = false});

  @override
  final bool isIos;
  bool connectAvailable = true;
  bool? access = false; // Android's answer; iOS hides it
  bool grants = true;
  int? steps = 4200;
  Object? failWith;
  int configures = 0;
  DateTime? start;
  DateTime? end;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> configure() async {
    configures++;
    _maybeFail();
  }

  @override
  Future<bool> healthConnectAvailable() async {
    _maybeFail();
    return connectAvailable;
  }

  @override
  Future<bool?> hasStepsAccess() async {
    _maybeFail();
    return isIos ? null : access;
  }

  @override
  Future<bool> requestStepsAccess() async {
    _maybeFail();
    if (grants && !isIos) access = true;
    return grants;
  }

  @override
  Future<int?> totalSteps(DateTime s, DateTime e) async {
    _maybeFail();
    start = s;
    end = e;
    return steps;
  }
}

void main() {
  group('localMidnight', () {
    test('start of the local calendar day, as an instant', () {
      // 15:30 in Kolkata (+5:30) on 8 Oct: the day began 18:30Z on the 7th.
      expect(
        localMidnight(DateTime.utc(2026, 10, 8, 10), 'Asia/Kolkata'),
        DateTime.utc(2026, 10, 7, 18, 30),
      );
      // 22:00 on 7 Oct in New York (EDT, -4): the day began 04:00Z.
      expect(
        localMidnight(DateTime.utc(2026, 10, 8, 2), 'America/New_York'),
        DateTime.utc(2026, 10, 7, 4),
      );
      // Just after local midnight it is the new day.
      expect(
        localMidnight(DateTime.utc(2026, 10, 7, 18, 31), 'Asia/Kolkata'),
        DateTime.utc(2026, 10, 7, 18, 30),
      );
    });

    test('a day the clocks change starts at the right moment', () {
      // London, 25 Oct 2026: BST ends at 02:00 local. Midnight that day was
      // still BST (+1), so it was 23:00Z on the 24th, though at noon the
      // offset is already 0.
      expect(
        localMidnight(DateTime.utc(2026, 10, 25, 12), 'Europe/London'),
        DateTime.utc(2026, 10, 24, 23),
      );
      // The other way: 29 Mar 2026, GMT until 01:00Z; midnight was +0.
      expect(
        localMidnight(DateTime.utc(2026, 3, 29, 12), 'Europe/London'),
        DateTime.utc(2026, 3, 29),
      );
    });
  });

  group('Android (Health Connect)', () {
    late _FakePlatform platform;
    late PlatformHealthSource source;
    setUp(() {
      platform = _FakePlatform();
      source = PlatformHealthSource(platform: platform, kv: KvStore(memoryDb()));
    });

    test('no Health Connect is unavailable; without access it needs '
        'permission; with access it is ready', () async {
      platform.connectAvailable = false;
      expect(await source.availability(), HealthAvailability.unavailable);
      platform.connectAvailable = true;
      expect(await source.availability(), HealthAvailability.needsPermission);
      platform.access = true;
      expect(await source.availability(), HealthAvailability.ready);
    });

    test('a granted request is confirmed by asking again; a refusal is false',
        () async {
      expect(await source.requestStepsAccess(), isTrue);
      expect(await source.availability(), HealthAvailability.ready);
      final refused = _FakePlatform()..grants = false;
      final other = PlatformHealthSource(
        platform: refused,
        kv: KvStore(memoryDb()),
      );
      expect(await other.requestStepsAccess(), isFalse);
      expect(await other.availability(), HealthAvailability.needsPermission);
    });

    test('steps are read from local midnight to now, once configured',
        () async {
      final now = DateTime.utc(2026, 10, 8, 10);
      expect(await source.stepsToday(now, 'Asia/Kolkata'), 4200);
      expect(platform.start, DateTime.utc(2026, 10, 7, 18, 30));
      expect(platform.end, now);
      await source.stepsToday(now, 'Asia/Kolkata');
      await source.availability();
      expect(platform.configures, 1);
    });

    test('a failing store never throws: unavailable, refused, unknown',
        () async {
      platform.failWith = StateError('boom');
      expect(await source.availability(), HealthAvailability.unavailable);
      expect(await source.requestStepsAccess(), isFalse);
      expect(await source.stepsToday(DateTime.utc(2026, 10, 8), 'UTC'), isNull);
    });
  });

  group('iOS (HealthKit hides whether a read was allowed)', () {
    test('needs permission until the system sheet has been shown once, then '
        'ready; a denied read simply returns no steps', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final platform = _FakePlatform(isIos: true)..steps = null;
      final source = PlatformHealthSource(platform: platform, kv: KvStore(db));
      expect(await source.availability(), HealthAvailability.needsPermission);
      expect(await source.requestStepsAccess(), isTrue);
      expect(await KvStore(db).get(KvKeys.healthAsked), '1');
      expect(await source.availability(), HealthAvailability.ready);
      expect(await source.stepsToday(DateTime.utc(2026, 10, 8), 'UTC'), isNull);
    });

    test('a failed prompt does not count as asked', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final platform = _FakePlatform(isIos: true)..failWith = StateError('x');
      final source = PlatformHealthSource(platform: platform, kv: KvStore(db));
      expect(await source.requestStepsAccess(), isFalse);
      expect(await KvStore(db).get(KvKeys.healthAsked), isNull);
    });
  });
}
