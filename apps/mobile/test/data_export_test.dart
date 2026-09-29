import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/account/data_export.dart';
import 'package:aura/src/features/account/data_export_screen.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capsules_fakes.dart';
import 'helpers.dart';

/// F8 REQ-ACC-12 data export: JSON + readable HTML (+ the check-in CSV),
/// made on the phone. Own records only; deleted ones left out; sealed
/// capsules stay sealed; nothing about anyone else.

const _labels = ExportLabels(
  title: 'Your Aura data',
  exported: 'Made on 8 Oct 2026',
  checkIns: 'Check-ins',
  habits: 'Habits',
  capsules: 'Capsules',
  account: 'Account',
  reflections: 'Your reflections',
  sanctuary: 'Sanctuary',
  sealed: 'Sealed',
  voiceNote: 'voice note',
  nothing: 'Nothing here yet.',
);

Future<void> _seed(AppDatabase db) async {
  final at = testNow.subtract(const Duration(hours: 2));
  await db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          id: 'c1',
          moodId: 'anxious',
          quadrant: 'storm',
          localDay: '2026-10-08',
          deviceTs: at,
          tzOffsetMinutes: 330,
          tags: const Value(['study', 'exam "prep"']),
          note: const Value('Exam tomorrow, <b>nervous</b>, but ok'),
        ),
      );
  await db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          id: 'c-gone',
          moodId: 'calm',
          quadrant: 'moonlight',
          localDay: '2026-10-07',
          deviceTs: at.subtract(const Duration(days: 1)),
          tzOffsetMinutes: 330,
          note: const Value('deleted words'),
          deletedAt: Value(at),
        ),
      );
  await db
      .into(db.habits)
      .insert(
        HabitsCompanion.insert(
          id: 'h1',
          kind: 'preset',
          presetKey: const Value('hydrate'),
          createdAt: at,
          updatedAt: at,
          committedFrom: const Value('2026-10-01'),
          pausedThrough: const Value('2026-10-12'),
        ),
      );
  await db
      .into(db.habitLogs)
      .insert(
        HabitLogsCompanion.insert(
          id: 'l1',
          habitId: 'h1',
          localDay: '2026-10-08',
          deviceTs: at,
        ),
      );
  // A sealed date capsule and an opened one (clear payloads: no key needed).
  String payload(String title, String text) => jsonEncode({
    'title': title,
    'text': text,
    'hardMoment': false,
    'media': const [],
  });
  await db
      .into(db.capsules)
      .insert(
        CapsulesCompanion.insert(
          id: 'k-sealed',
          unlockType: 'date',
          unlockLocalDate: const Value('2027-10-08'),
          payloadClear: Value(payload('For next October', 'secret words')),
          sealedAt: at,
        ),
      );
  await db
      .into(db.capsules)
      .insert(
        CapsulesCompanion.insert(
          id: 'k-open',
          unlockType: 'mood',
          triggerQuadrant: const Value('storm'),
          payloadClear: Value(payload('You did it before', 'Breathe first.')),
          sealedAt: at.subtract(const Duration(days: 30)),
          openedAt: Value(at),
        ),
      );
}

void main() {
  late Directory root;
  late AppDatabase db;
  late CapsuleRepository capsules;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-export');
    db = memoryDb();
    capsules = CapsuleRepository(
      db,
      OutboxRepository(db, const Ids()),
      TimeContext(clock: FixedClock(testNow), timezone: 'Asia/Kolkata'),
      store: tempCapsuleStore(root),
    );
    await _seed(db);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('own records; deleted left out; sealed capsules stay sealed', () async {
    final b = await collectExport(
      db: db,
      capsules: capsules,
      localeTag: 'en',
      now: testNow,
      server: {
        'format': 'aura.export.server.v1',
        'profile': {'birthDate': '1999-02-14'},
      },
    );
    expect(b.checkIns, hasLength(1));
    expect(b.checkIns.single, {
      'day': '2026-10-08',
      'at': testNow.subtract(const Duration(hours: 2)).toIso8601String(),
      'mood': 'anxious',
      'moodName': 'Anxious',
      'quadrant': 'storm',
      'tags': ['study', 'exam "prep"'],
      'note': 'Exam tomorrow, <b>nervous</b>, but ok',
      'voiceNote': false,
      'from': 'app',
    });
    expect(b.habits.single['name'], 'Hydrate');
    // W02: the person's own commitment is part of their data.
    expect(b.habits.single['committedFrom'], '2026-10-01');
    expect(b.habits.single['pausedThrough'], '2026-10-12');
    expect(b.habitLogs.single, {'habit': 'Hydrate', 'day': '2026-10-08'});

    final sealed = b.capsules.firstWhere((c) => c['opened'] == false);
    expect(sealed['title'], 'For next October');
    expect(sealed.containsKey('text'), isFalse);
    final opened = b.capsules.firstWhere((c) => c['opened'] == true);
    expect(opened['text'], 'Breathe first.');

    final json = exportJson(b);
    expect(json, isNot(contains('secret words')));
    expect(json, isNot(contains('deleted words')));
    expect(jsonDecode(json)['account']['profile']['birthDate'], '1999-02-14');
  });

  test(
    'CSV quotes every cell; HTML escapes text and loads nothing remote',
    () async {
      final b = await collectExport(
        db: db,
        capsules: capsules,
        localeTag: 'en',
        now: testNow,
      );
      final csv = exportCsv(b).split('\r\n');
      expect(
        csv.first,
        '"day","time_utc","mood","mood_name","quadrant","tags","note",'
        '"voice_note","from"',
      );
      expect(csv[1], contains('"study; exam ""prep"""'));
      expect(csv[1], contains('"Exam tomorrow, <b>nervous</b>, but ok"'));

      final html = exportHtml(b, _labels);
      expect(html, contains('&lt;b&gt;nervous&lt;'));
      expect(html, isNot(contains('<b>nervous')));
      expect(html, isNot(contains('secret words')));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('http')));
      expect(html, contains('Sealed'));
      // No server part: the account sections are simply absent.
      expect(html, isNot(contains('Your reflections')));
    },
  );

  test('three files, named by the day', () async {
    final b = await collectExport(
      db: db,
      capsules: capsules,
      localeTag: 'en',
      now: testNow,
    );
    final files = exportFiles(b, _labels);
    expect(files.map((f) => f.name), [
      'aura-data-2026-10-08.html',
      'aura-data-2026-10-08.json',
      'aura-checkins-2026-10-08.csv',
    ]);
  });

  group('screen', () {
    Future<_Share> pump(
      WidgetTester tester, {
      required Future<List<ExportFile>> Function(ExportLabels, String) make,
    }) async {
      final share = _Share();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db: memoryDb()),
            dataExportProvider.overrideWithValue(make),
            exportShareProvider.overrideWithValue(share),
          ],
          child: localized(const DataExportScreen()),
        ),
      );
      await tester.pump();
      return share;
    }

    testWidgets('says what is in it and that it isn’t encrypted; makes and '
        'shares the files', (tester) async {
      final share = await pump(
        tester,
        make: (labels, locale) async => [
          ExportFile('aura-data.json', 'application/json', utf8.encode('{}')),
        ],
      );
      expect(
        find.textContaining('Sealed capsules stay sealed'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('export-private')), findsOneWidget);
      await tester.tap(find.text('Make my copy'));
      await tester.pump();
      await tester.pump();
      expect(share.calls, 1);
      expect(find.byKey(const ValueKey('export-done')), findsOneWidget);
    });

    testWidgets('offline: nothing half-made, a calm retry', (tester) async {
      var fail = true;
      final share = await pump(
        tester,
        make: (labels, locale) async {
          if (fail) throw const ApiException(code: 'x', isNetwork: true);
          return [ExportFile('a.json', 'application/json', utf8.encode('{}'))];
        },
      );
      await tester.tap(find.text('Make my copy'));
      await tester.pump();
      await tester.pump();
      expect(share.calls, 0);
      expect(find.byKey(const ValueKey('export-failed')), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('export-retry')));
      await tester.pump();
      await tester.pump();
      expect(share.calls, 1);
    });
  });
}

class _Share implements ExportShare {
  int calls = 0;

  @override
  Future<void> share(
    List<ExportFile> files, {
    required String text,
    Rect? origin,
  }) async => calls++;
}
