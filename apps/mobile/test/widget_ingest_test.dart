import 'dart:convert';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura/src/features/widget/widget_ingest.dart';
import 'package:aura/src/features/widget/widget_store.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'widget_fakes.dart';

/// F11 data path: the widget saves a mood-only record (client id + day
/// stamp) to the shared store; the app imports it into Drift exactly once,
/// keeps the widget's own stamp, and queues it for `POST /v1/sync/push`
/// (REQ-WID-02, PRD 16-offline "widget check-in: saved locally, queued in
/// outbox").
void main() {
  const owner = 'owner-1';
  const ids = Ids();
  late AppDatabase db;
  late CheckInRepository repo;
  late MemoryWidgetHost host;
  late WidgetIngestor ingestor;

  setUp(() {
    db = memoryDb();
    repo = CheckInRepository(
      db,
      OutboxRepository(db, ids),
      TimeContext(clock: FixedClock(testNow), timezone: 'Asia/Kolkata'),
    );
    host = MemoryWidgetHost();
    ingestor = WidgetIngestor(host: host, checkIns: repo);
  });
  tearDown(() => db.close());

  Future<List<OutboxRow>> outbox() =>
      (db.select(db.outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  test('imports a widget check-in once, with its own stamp and source '
      '"widget", and queues one upsert for sync', () async {
    final id = ids.v7();
    final tapped = testNow.subtract(const Duration(hours: 2)); // 13:30 IST
    host.pending = [
      widgetRecord(
        id: id,
        moodId: 'anxious',
        deviceTs: tapped,
        localDay: '2026-10-08',
        owner: owner,
      ),
    ];

    final first = await ingestor.ingest(owner: owner);
    expect(first.map((c) => c.id), [id]);
    expect(first.single.mood.id, 'anxious');

    final row = (await db.select(db.checkIns).get()).single;
    expect(row.id, id);
    expect(row.moodId, 'anxious');
    expect(row.quadrant, 'storm');
    expect(row.source, 'widget');
    expect(row.note, isNull);
    expect(row.tags, isEmpty);
    expect(row.localDay, '2026-10-08');
    expect(row.deviceTs.toUtc(), tapped);
    expect(row.tzOffsetMinutes, 330);
    expect(row.tz, 'Asia/Kolkata');

    final queued = (await outbox()).single;
    expect(queued.entity, Entities.checkIn);
    expect(queued.op, Ops.upsert);
    expect(queued.entityId, id);
    expect(queued.deviceTs.toUtc(), tapped);
    expect(queued.localDay, '2026-10-08');
    expect(queued.tz, 'Asia/Kolkata');
    expect(queued.needsNote, isFalse);
    final payload = jsonDecode(queued.payload) as Map<String, dynamic>;
    expect(payload['source'], 'widget');
    expect(payload['moodId'], 'anxious');
    expect(payload['tags'], isEmpty);
    expect(payload['noteCt'], isNull);
    expect(host.acked, [id]);

    // The app opens again before the widget pruned its store: nothing new.
    final second = await ingestor.ingest(owner: owner);
    expect(second, isEmpty);
    expect(await db.select(db.checkIns).get(), hasLength(1));
    expect(await outbox(), hasLength(1));
    expect(host.acked, [id]);

    // After the widget pruned, the store is empty.
    host.widgetPrunes();
    expect(host.pending, isEmpty);
    expect(await ingestor.ingest(owner: owner), isEmpty);
  });

  test('offline: once sync has sent it (outbox empty), a replayed record '
      'is never queued again', () async {
    final id = ids.v7();
    host.pending = [
      widgetRecord(
        id: id,
        deviceTs: testNow,
        localDay: '2026-10-08',
        owner: owner,
      ),
    ];
    await ingestor.ingest(owner: owner);
    // Sync ran (airplane mode ended): the mutation left the outbox.
    await db.delete(db.outbox).go();

    expect(await ingestor.ingest(owner: owner), isEmpty);
    expect(await outbox(), isEmpty);
    expect(await db.select(db.checkIns).get(), hasLength(1));
  });

  test(
    'Aura day across 04:00: a 01:30 tap counts for the previous day, '
    'however late the app imports it, and still earns as a live check-in',
    () async {
      // 01:30 IST on 8 Oct = 20:00 UTC on 7 Oct → Aura day 7 Oct.
      final tapped = DateTime.utc(2026, 10, 7, 20);
      final stamped = ids.v7();
      final derived = ids.v7();
      host.pending = [
        widgetRecord(
          id: stamped,
          deviceTs: tapped,
          localDay: '2026-10-07',
          owner: owner,
        ),
        // An older widget build that didn't write localDay: derived from
        // deviceTs + tz with the same 04:00 rule.
        widgetRecord(
          id: derived,
          deviceTs: tapped.add(const Duration(minutes: 5)),
          owner: owner,
        ),
      ];

      await ingestor.ingest(owner: owner); // imported at 15:30 IST on 8 Oct

      final rows = await db.select(db.checkIns).get();
      expect(
        {for (final r in rows) r.id: r.localDay},
        {stamped: '2026-10-07', derived: '2026-10-07'},
      );
      for (final o in await outbox()) {
        expect(o.localDay, '2026-10-07');
      }

      final events = await ProgressRepository(
        db,
        KvStore(db),
      ).watchEvents().first;
      final p = projectProgress(
        events: events,
        now: testNow,
        timezone: 'Asia/Kolkata',
      );
      // Live (localDay == auraDay(deviceTs)): 10 + 2, and 7 Oct is a glow day.
      expect(p.awards[stamped], 10);
      expect(p.awards[derived], 2);
      expect(p.streak.lastActiveDay, LocalDay.parse('2026-10-07'));
    },
  );

  test('a 04:00 tap is the new day', () async {
    final id = ids.v7();
    // 04:00 IST on 8 Oct = 22:30 UTC on 7 Oct.
    host.pending = [
      widgetRecord(
        id: id,
        deviceTs: DateTime.utc(2026, 10, 7, 22, 30),
        owner: owner,
      ),
    ];
    await ingestor.ingest(owner: owner);
    expect((await db.select(db.checkIns).get()).single.localDay, '2026-10-08');
  });

  test('another account, an unknown mood or an unreadable record is never '
      'imported, but is acknowledged so the widget drops it', () async {
    final mine = ids.v7();
    final theirs = ids.v7();
    final noOwner = ids.v7();
    final unknownMood = ids.v7();
    final broken = ids.v7();
    host.pending = [
      widgetRecord(id: mine, deviceTs: testNow, owner: owner),
      widgetRecord(id: theirs, deviceTs: testNow, owner: 'someone-else'),
      widgetRecord(id: noOwner, deviceTs: testNow),
      widgetRecord(
        id: unknownMood,
        moodId: 'ecstatic',
        deviceTs: testNow,
        owner: owner,
      ),
      {'id': broken, 'moodId': 'calm'}, // no stamp
      {'moodId': 'calm'}, // no id at all: ignored
    ];

    final imported = await ingestor.ingest(owner: owner);

    expect(imported.map((c) => c.id), [mine]);
    expect((await db.select(db.checkIns).get()).map((r) => r.id), [mine]);
    expect(host.acked.toSet(), {mine, theirs, noOwner, unknownMood, broken});
  });

  test('a malformed store reads as empty and never throws', () async {
    for (final raw in [null, '', 'not json', '{"a":1}', '[1,2,"x"]']) {
      expect(parsePendingWidgetCheckIns(raw).isEmpty, isTrue, reason: '$raw');
    }
  });

  test('an older record version and extra fields still import (the store '
      'is versioned)', () async {
    final id = ids.v7();
    host.pending = [
      {
        ...widgetRecord(id: id, deviceTs: testNow, owner: owner, v: 0),
        'somethingNew': true,
      },
    ];
    expect((await ingestor.ingest(owner: owner)).single.id, id);
  });

  test('a zone the tz database does not know is replaced like the app does '
      '(never sent as an invalid_tz)', () async {
    final id = ids.v7();
    host.pending = [
      widgetRecord(
        id: id,
        deviceTs: testNow,
        tz: 'Mars/Olympus',
        tzOffsetMinutes: 330,
        localDay: '2026-10-08',
        owner: owner,
      ),
    ];
    await ingestor.ingest(owner: owner);
    final row = (await db.select(db.checkIns).get()).single;
    expect(row.tz, 'Asia/Kolkata'); // +5:30 → the well-known zone
    expect((await outbox()).single.tz, 'Asia/Kolkata');
  });

  test('concurrent imports share one run', () async {
    final id = ids.v7();
    host.pending = [widgetRecord(id: id, deviceTs: testNow, owner: owner)];
    final results = await Future.wait([
      ingestor.ingest(owner: owner),
      ingestor.ingest(owner: owner),
    ]);
    expect(host.readCalls, 1);
    expect(results.expand((r) => r).map((c) => c.id), [id, id]);
    expect(await outbox(), hasLength(1));
  });
}
