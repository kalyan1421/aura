import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/net/api_models.dart';
import 'package:aura/src/core/net/aura_api.dart';
import 'package:aura/src/core/security/note_cipher.dart';
import 'package:aura/src/core/security/secure_store.dart';
import 'package:aura/src/core/sync/pull_service.dart';
import 'package:aura/src/features/progress/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'helpers.dart';

class _Api extends AuraApi {
  _Api() : super(baseUrl: 'http://test', accessToken: () async => 't');

  @override
  Future<DataKeyResponse> dataKey() async => const DataKeyResponse(
    keyId: 'k1',
    dataKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
  );

  @override
  Future<Snapshot> snapshot() =>
      throw const ApiException(code: 'x', status: 500);
}

/// A new phone pulls its check-ins (Supabase select-own): the voice note's
/// server path is kept, the recording itself is fetched only when played.
void main() {
  late HttpServer server;
  final selects = <String, String>{};

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final table = req.uri.pathSegments.last;
      selects[table] = req.uri.queryParameters['select'] ?? '';
      final rows = table == 'check_ins'
          ? [
              {
                'id': 'c1',
                'mood_id': 'calm',
                'quadrant': 'moonlight',
                'tags': <String>[],
                'note_ct': null,
                'voice_path': 'user-1/voice/c1',
                'local_day': '2026-10-08',
                'device_ts': '2026-10-08T10:00:00Z',
                'source': 'app',
              },
              {
                'id': 'c2',
                'mood_id': 'joyful',
                'quadrant': 'sunrise',
                'tags': <String>[],
                'note_ct': null,
                'voice_path': null,
                'local_day': '2026-10-08',
                'device_ts': '2026-10-08T11:00:00Z',
                'source': 'app',
              },
            ]
          : <Object>[];
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(rows));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('pulled check-ins keep voice_path (no local file yet)', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final kv = KvStore(db);
    final client = sb.SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon',
      authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);

    await PullService(
      db: db,
      kv: kv,
      progress: ProgressRepository(db, kv),
      dataKeys: DataKeyRepository(MemorySecureStore()),
    ).pullAll(client: client, userId: 'user-1', api: _Api());

    expect(selects['check_ins'], contains('voice_path'));
    final rows = {for (final r in await db.select(db.checkIns).get()) r.id: r};
    expect(rows['c1']!.voicePath, 'user-1/voice/c1');
    expect(rows['c1']!.voiceFile, isNull);
    expect(rows['c2']!.voicePath, isNull);
  });
}
