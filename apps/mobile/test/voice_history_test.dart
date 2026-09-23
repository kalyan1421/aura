import 'dart:convert';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/checkin/checkin_repository.dart';
import 'package:aura/src/features/history/checkin_detail_screen.dart';
import 'package:aura/src/features/history/history_screen.dart';
import 'package:aura/src/features/voice/voice_loader.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';
import 'voice_fakes.dart';

/// Voice notes in the private history: a discreet marker in the list, a
/// labelled play/pause row on the entry with loading, offline and failed
/// states, and the 24 h edit can remove it.
void main() {
  late AppDatabase db;
  late String id;
  late FakePlayer player;
  late FakeVoiceStore store;
  late FakeLoader loader;

  setUp(() {
    db = memoryDb();
    player = FakePlayer();
    store = FakeVoiceStore();
    loader = FakeLoader(
      (id, file, path) async =>
          const VoiceSource('/tmp/voice.m4a', isTemp: true),
    );
  });

  /// A check-in made at [testNow] whose voice note is only on the server
  /// (pulled on a new phone), 9 s long.
  Future<void> seed(WidgetTester tester, {bool local = false}) async {
    final repo = CheckInRepository(
      db,
      OutboxRepository(db, const Ids()),
      testTime(),
    );
    id = const Ids().v7();
    await io(tester, () async {
      await repo.save(id: id, mood: moodById('calm')!);
      await (db.update(db.checkIns)..where((t) => t.id.equals(id))).write(
        CheckInsCompanion(
          voicePath: Value('user-1/voice/$id'),
          voiceFile: Value(local ? 'rec.enc' : null),
          voiceMs: const Value(9000),
        ),
      );
      await db.delete(db.outbox).go();
    });
  }

  Future<void> open(WidgetTester tester, {bool entry = true}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ...voiceOverrides(player: player, store: store, loader: loader),
        ],
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: GoRouter(
            initialLocation: '/history',
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
              GoRoute(
                path: '/history/:id',
                builder: (_, s) =>
                    CheckInDetailScreen(id: s.pathParameters['id']!),
              ),
            ],
          ),
        ),
      ),
    );
    await settleIo(tester);
    if (entry) {
      await tester.tap(find.byKey(ValueKey('history-$id')));
      await settleIo(tester);
    }
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  final play = find.byKey(const ValueKey('voice-play'));

  testWidgets('the list shows a discreet, labelled voice marker', (
    tester,
  ) async {
    await seed(tester);
    await open(tester, entry: false);
    final icon = find.byKey(const ValueKey('history-voice-icon'));
    expect(icon, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Has a voice note')), findsOneWidget);
    await done(tester);
  });

  testWidgets('play/pause on the entry: fetched lazily on the first play, '
      'length shown, the decrypted temp copy is deleted on leaving', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    expect(find.byKey(const ValueKey('history-voice')), findsOneWidget);
    expect(find.text('0:09'), findsOneWidget);
    expect(find.byTooltip('Play voice note'), findsOneWidget);
    expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
    expect(loader.loads, 0); // nothing downloaded until played

    await tapVisible(tester, play);
    await settleIo(tester, rounds: 2);
    expect(loader.loads, 1);
    expect(player.played, ['/tmp/voice.m4a']);
    expect(find.byTooltip('Pause voice note'), findsOneWidget);
    player.positionCtrl.add(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('0:04 / 0:09'), findsOneWidget);

    await tapVisible(tester, play);
    expect(player.pauses, 1);
    expect(find.byTooltip('Play voice note'), findsOneWidget);
    await tapVisible(tester, play);
    expect(player.resumes, 1);

    player.completedCtrl.add(null);
    await tester.pump();
    expect(find.byTooltip('Play voice note'), findsOneWidget);

    await done(tester);
    expect(store.tempsDeleted, ['/tmp/voice.m4a']);
    expect(player.disposed, isTrue);
  });

  testWidgets('offline, a note only on the server says it plays when back '
      'online; the next tap tries again', (tester) async {
    loader.answer = (_, _, _) async =>
        throw const VoiceUnavailable(offline: true);
    await seed(tester);
    await open(tester);
    await tapVisible(tester, play);
    await settleIo(tester, rounds: 2);
    expect(
      find.text("The voice note plays when you're back online."),
      findsOneWidget,
    );
    expect(player.played, isEmpty);

    loader.answer = (_, _, _) async => const VoiceSource('/tmp/v2.m4a');
    await tapVisible(tester, play);
    await settleIo(tester, rounds: 2);
    expect(player.played, ['/tmp/v2.m4a']);
    expect(
      find.text("The voice note plays when you're back online."),
      findsNothing,
    );
    await done(tester);
  });

  testWidgets('a note that fails to load says so calmly and can be retried', (
    tester,
  ) async {
    loader.answer = (_, _, _) async => throw const VoiceUnavailable();
    await seed(tester);
    await open(tester);
    await tapVisible(tester, play);
    await settleIo(tester, rounds: 2);
    expect(
      find.text(
        "This voice note couldn't be played just now. Try again in a moment.",
      ),
      findsOneWidget,
    );
    expect(play, findsOneWidget); // retry is the same button
    await done(tester);
  });

  testWidgets('edit within 24 h: remove the voice note → the edit sends '
      'voicePath null', (tester) async {
    await seed(tester, local: true);
    await open(tester);
    await tapVisible(tester, find.byKey(const ValueKey('history-edit')));
    await settleIo(tester, rounds: 2);
    // The saved voice note shows in the editor with its actions (at the end
    // of the lazily built list).
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('voice-remove')),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('voice-remove')), findsOneWidget);
    expect(find.text('0:09'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('voice-remove')));
    expect(find.byKey(const ValueKey('voice-record')), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('history-edit-save')));
    await settleIo(tester);

    final rows = await io(
      tester,
      () => (db.select(
        db.outbox,
      )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get(),
    );
    final payload = jsonDecode(rows.single.payload) as Map<String, dynamic>;
    expect(payload.containsKey('voicePath'), isTrue);
    expect(payload['voicePath'], isNull);
    final row = await io(
      tester,
      () => (db.select(db.checkIns)..where((t) => t.id.equals(id))).getSingle(),
    );
    expect(row.voiceFile, isNull);
    expect(row.voicePath, isNull);
    expect(find.byKey(const ValueKey('history-voice')), findsNothing);
    await done(tester);
  });

  testWidgets('edit without touching the voice keeps it (voicePath left out)', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await tapVisible(tester, find.byKey(const ValueKey('history-edit')));
    await settleIo(tester, rounds: 2);
    await tapVisible(tester, find.byKey(const ValueKey('mood-joyful')));
    await tapVisible(tester, find.byKey(const ValueKey('history-edit-save')));
    await settleIo(tester);
    final m = await io(tester, () => db.select(db.outbox).getSingle());
    expect(jsonDecode(m.payload), isNot(contains('voicePath')));
    expect(m.needsMedia, isFalse);
    expect(find.byKey(const ValueKey('history-voice')), findsOneWidget);
    await done(tester);
  });
}
