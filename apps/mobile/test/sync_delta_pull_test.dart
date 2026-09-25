import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/sync/pull_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:aura_domain/aura_domain.dart' show LocalDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'helpers.dart';

/// PRD 16 "Pull: per-entity delta since a server sequence cursor" and "two
/// phones … pulls merge": after the first full pull, a phone reads only what
/// changed since its cursors — rows added or edited on another phone, and
/// deletions there (`sync_tombstones`). Its own unsent changes are never
/// overwritten; a tombstone always wins; without a cursor it re-reads
/// everything and drops synced rows the server no longer has.

class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 't');

  @override
  Future<DataKeyResponse> dataKey() =>
      throw const ApiException(code: 'x', status: 500);

  @override
  Future<Snapshot> snapshot() =>
      throw const ApiException(code: 'x', status: 500);
}

Map<String, Object?> _ci(
  String id,
  String mood,
  String quadrant,
  String updatedAt, {
  List<String> tags = const [],
}) => {
  'id': id,
  'mood_id': mood,
  'quadrant': quadrant,
  'tags': tags,
  'note_ct': null,
  'voice_path': null,
  'local_day': '2026-10-08',
  'device_ts': '2026-10-08T10:00:00Z',
  'source': 'app',
  'updated_at': updatedAt,
};

void main() {
  late HttpServer server;
  late sb.SupabaseClient client;
  late AppDatabase db;
  late KvStore kv;
  late PullService pull;
  final tables = <String, List<Map<String, Object?>>>{};
  final queries = <String, Map<String, String>>{};

  setUp(() async {
    tables
      ..clear()
      ..addAll({
        'check_ins': [
          _ci('c1', 'calm', 'moonlight', '2026-10-08T10:00:00.000001+00:00'),
          _ci('c2', 'joyful', 'sunrise', '2026-10-08T10:05:00+00:00'),
        ],
        'habits': [
          {
            'id': 'h1',
            'kind': 'custom',
            'preset_key': null,
            'name': 'Read',
            'active': true,
            'created_at': '2026-10-01T10:00:00+00:00',
            'updated_at': '2026-10-01T10:00:00+00:00',
          },
        ],
        'habit_logs': [],
        'sync_tombstones': [],
      });
    queries.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final table = req.uri.pathSegments.last;
      queries[table] = req.uri.queryParameters;
      var rows = List<Map<String, Object?>>.of(tables[table] ?? const []);
      // `<column>=gte.<timestamp>` (the only filter the pull uses).
      for (final e in req.uri.queryParameters.entries) {
        if (!e.value.startsWith('gte.')) continue;
        final since = DateTime.parse(e.value.substring(4));
        rows = rows
            .where((r) => !DateTime.parse(r[e.key]! as String).isBefore(since))
            .toList();
      }
      if (req.uri.queryParameters['limit'] == '1') rows = rows.take(1).toList();
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(rows));
      await req.response.close();
    });
    client = sb.SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon',
      authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    );
    db = memoryDb();
    kv = KvStore(db);
    pull = PullService(
      db: db,
      kv: kv,
      progress: ProgressRepository(db, kv),
      dataKeys: DataKeyRepository(MemorySecureStore()),
    );
    await pull.pullAll(client: client, userId: 'user-1', api: _Api());
  });

  tearDown(() async {
    client.dispose();
    await db.close();
    await server.close(force: true);
  });

  Future<Map<String, CheckInRow>> checkIns() async => {
    for (final r in await db.select(db.checkIns).get()) r.id: r,
  };

  test(
    'the first full pull leaves cursors at the newest server rows',
    () async {
      final raw = await kv.get(KvKeys.pullCursor);
      final cursor = PullCursor.fromJson(
        jsonDecode(raw!) as Map<String, dynamic>,
      );
      expect(cursor.userId, 'user-1');
      expect(cursor.checkIns, '2026-10-08T10:05:00+00:00');
      expect(cursor.habits, '2026-10-01T10:00:00+00:00');
      expect(cursor.tombstones, isNull);
    },
  );

  test('added and edited elsewhere arrive; deleted elsewhere goes; only '
      'deltas are asked for', () async {
    tables['check_ins'] = [
      _ci(
        'c1',
        'anxious',
        'storm',
        '2026-10-09T08:00:00+00:00',
        tags: ['study'],
      ),
      _ci('c3', 'hopeful', 'sunrise', '2026-10-09T09:00:00+00:00'),
    ];
    tables['habits'] = [
      {
        ...tables['habits']!.single,
        'name': 'Read 10 pages',
        'active': false,
        'updated_at': '2026-10-09T07:00:00+00:00',
      },
    ];
    tables['habit_logs'] = [
      {
        'id': 'l1',
        'habit_id': 'h1',
        'local_day': '2026-10-09',
        'device_ts': '2026-10-09T07:00:00Z',
        'server_ts': '2026-10-09T07:00:01+00:00',
      },
    ];
    tables['sync_tombstones'] = [
      {
        'entity': 'check_in',
        'entity_id': 'c2',
        'deleted_at': '2026-10-09T09:30:00+00:00',
      },
    ];

    await pull.pullDelta(client: client, userId: 'user-1', api: _Api());

    // Asked for changes since the cursors, not everything.
    expect(
      queries['check_ins']!['updated_at'],
      'gte.2026-10-08T10:05:00+00:00',
    );
    expect(queries['habits']!['updated_at'], 'gte.2026-10-01T10:00:00+00:00');

    final rows = await checkIns();
    expect(rows['c1']!.moodId, 'anxious');
    expect(rows['c1']!.tags, ['study']);
    expect(rows['c3']!.moodId, 'hopeful');
    expect(rows['c2']!.deletedAt, isNotNull);
    final habit = await db.select(db.habits).getSingle();
    expect(habit.name, 'Read 10 pages');
    expect(habit.active, isFalse);
    expect((await db.select(db.habitLogs).get()).single.id, 'l1');

    // The cursors moved on.
    await pull.pullDelta(client: client, userId: 'user-1', api: _Api());
    expect(
      queries['check_ins']!['updated_at'],
      'gte.2026-10-09T09:00:00+00:00',
    );
    expect(
      queries['sync_tombstones']!['deleted_at'],
      'gte.2026-10-09T09:30:00+00:00',
    );
  });

  test('this phone’s unsent edit is never overwritten; a tombstone wins '
      'even over it', () async {
    await OutboxRepository(db, const Ids()).enqueue(
      entity: Entities.checkIn,
      op: Ops.upsert,
      entityId: 'c1',
      deviceTs: DateTime.utc(2026, 10, 9, 8),
      localDay: LocalDay.parse('2026-10-09'),
      tz: 'Asia/Kolkata',
      payload: {'id': 'c1', 'moodId': 'calm'},
    );
    tables['check_ins'] = [
      _ci('c1', 'angry', 'storm', '2026-10-09T08:00:00+00:00'),
    ];
    await pull.pullDelta(client: client, userId: 'user-1', api: _Api());
    expect((await checkIns())['c1']!.moodId, 'calm');

    tables['sync_tombstones'] = [
      {
        'entity': 'check_in',
        'entity_id': 'c1',
        'deleted_at': '2026-10-09T09:00:00+00:00',
      },
    ];
    await pull.pullDelta(client: client, userId: 'user-1', api: _Api());
    expect((await checkIns())['c1']!.deletedAt, isNotNull);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('no cursor: re-reads everything and drops synced rows the server no '
      'longer has; unsent rows stay', () async {
    await kv.set(KvKeys.pullCursor, '');
    await db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: 'local-only',
            moodId: 'calm',
            quadrant: 'moonlight',
            localDay: '2026-10-09',
            deviceTs: DateTime.utc(2026, 10, 9),
            tzOffsetMinutes: 330,
          ),
        );
    tables['check_ins'] = [tables['check_ins']!.first]; // c2 gone long ago
    await pull.pullDelta(client: client, userId: 'user-1', api: _Api());
    expect(queries['check_ins']!.containsKey('updated_at'), isFalse);
    final rows = await checkIns();
    expect(rows['c1']!.deletedAt, isNull);
    expect(rows['c2']!.deletedAt, isNotNull);
    expect(rows['local-only']!.deletedAt, isNull);
  });

  test('another account’s cursor is never used', () async {
    await pull.pullDelta(client: client, userId: 'user-2', api: _Api());
    expect(queries['check_ins']!.containsKey('updated_at'), isFalse);
  });
}
