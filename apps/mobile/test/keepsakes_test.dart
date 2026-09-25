// F13 Keepsakes (Milestone C): the private box shows only the seals earned,
// each with the day it was earned — no locked slots, progress bars, "next
// seal" hints or counts (PRD F13 "Private box"); the cache keeps it working
// offline; a new seal shows once as a small card on Home; glow seals stay off
// Home while Comfort › hide streak number is on. The app never grants,
// changes or removes a keepsake: it only asks the server for its own.
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/keepsakes/keepsake_home_card.dart';
import 'package:aura/src/features/keepsakes/keepsake_seal.dart';
import 'package:aura/src/features/keepsakes/keepsakes_providers.dart';
import 'package:aura/src/features/keepsakes/keepsakes_repository.dart';
import 'package:aura/src/features/keepsakes/keepsakes_screen.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/share/share_card.dart';
import 'package:aura/src/features/share/share_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'keepsakes_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeKeepsakesApi api;

  setUp(() {
    db = memoryDb();
    api = FakeKeepsakesApi();
  });
  tearDown(() => db.close());

  /// A widget test that unmounts at the end (drift closes its streams on
  /// timers, which must run inside the test).
  void kWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  Widget app(Widget child, {int generation = 0}) => ProviderScope(
    key: ValueKey('scope-$generation'),
    overrides: [
      ...testOverrides(db: db),
      keepsakesApiProvider.overrideWithValue(api),
      progressViewProvider.overrideWithValue(progressFor()),
      shareGatewayProvider.overrideWithValue(FakeShareGateway()),
    ],
    child: localized(child),
  );

  KvStore kv(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(kvStoreProvider);

  List<String> texts(WidgetTester tester, [Finder? within]) => tester
      .widgetList<Text>(
        within == null
            ? find.byType(Text)
            : find.descendant(of: within, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .toList();

  group('the private box', () {
    kWidgets(
      'only the seals earned, each with its line and day, in catalogue order',
      (tester) async {
        api.list = [
          keep('glow_days_7', '2026-10-12'),
          keep('capsule_sealed_first', '2026-10-05'),
          keep('a_key_from_a_newer_server', '2026-10-06'),
        ];
        await tester.pumpWidget(app(const KeepsakesScreen()));
        await settleIo(tester);

        expect(find.text('Keepsakes'), findsOneWidget);
        expect(find.text('Sealed a note for future me'), findsOneWidget);
        expect(find.text('7 days of glow'), findsOneWidget);
        expect(find.text('Kept on 5 Oct 2026'), findsOneWidget);
        expect(find.text('Kept on 12 Oct 2026'), findsOneWidget);
        // An unknown key is simply not shown; nothing else is.
        expect(find.byType(KeepsakeSeal), findsNWidgets(2));
        final capsule = tester.getTopLeft(
          find.byKey(const ValueKey('keepsake-capsule_sealed_first')),
        );
        final glow = tester.getTopLeft(
          find.byKey(const ValueKey('keepsake-glow_days_7')),
        );
        expect(capsule.dx < glow.dx || capsule.dy < glow.dy, isTrue);

        // No locked slots, progress bars, "next seal" hints or counts.
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final all = texts(tester).join('\n');
        expect(
          all,
          isNot(
            matches(
              RegExp(
                r'lock|next|progress|almost|more to go|remaining|\d+\s*/\s*\d+|of 13|streak',
                caseSensitive: false,
              ),
            ),
          ),
        );
        expect(
          find.text(
            'Keepsakes are never shown to anyone else. One leaves your phone only if you share its card.',
          ),
          findsOneWidget,
        );
      },
    );

    kWidgets('a seal reads as its line and day to a screen reader', (
      tester,
    ) async {
      api.list = [keep('capsule_opened_first', '2026-10-07')];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(const KeepsakesScreen()));
      await settleIo(tester);
      expect(
        find.bySemanticsLabel(
          'Opened a capsule from past me, kept on 7 Oct 2026',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    kWidgets('empty: a calm line, no hint of what to do next', (tester) async {
      await tester.pumpWidget(app(const KeepsakesScreen()));
      await settleIo(tester);
      expect(
        find.text(
          'Nothing here yet. Keepsakes arrive on their own, from small moments along the way.',
        ),
        findsOneWidget,
      );
      expect(find.byType(KeepsakeSeal), findsNothing);
      // A Spark has no evolution card to share yet.
      expect(find.byKey(const ValueKey('keepsakes-share-aura')), findsNothing);
    });

    kWidgets('offline: the cached box still shows, new ones come later', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SizedBox()));
      await tester.runAsync(
        () => kv(tester).setJson(KeepsakeKv.cache, {
          'keepsakes': [
            {'key': 'ripples_first', 'earnedOn': '2026-10-03'},
          ],
        }),
      );
      api.offline = true;
      await tester.pumpWidget(app(const KeepsakesScreen()));
      await settleIo(tester);
      expect(find.text('Breathed together for the first time'), findsOneWidget);
      expect(find.byKey(const ValueKey('keepsakes-offline')), findsOneWidget);
    });

    kWidgets(
      'tapping a seal opens its share card: the seal and its line, never the day',
      (tester) async {
        api.list = [keep('lantern_hours_1', '2026-10-08')];
        await tester.pumpWidget(app(const KeepsakesScreen()));
        await settleIo(tester);
        await tester.tap(
          find.byKey(const ValueKey('keepsake-lantern_hours_1')),
        );
        await settleIo(tester);
        final card = find.byType(ShareCard);
        expect(card, findsOneWidget);
        final onCard = texts(tester, card);
        expect(onCard, contains('My first Lantern Hour'));
        expect(
          find.descendant(of: card, matching: find.byType(KeepsakeSeal)),
          findsOneWidget,
        );
        expect(onCard.join(' '), isNot(contains('Kept on')));
        expect(onCard.join(' '), isNot(contains('Oct')));
        expect(onCard.join(' '), isNot(contains('2026')));
      },
    );
  });

  group('Home: a new seal shows once', () {
    Widget home({int generation = 0}) => app(
      const Scaffold(body: SingleChildScrollView(child: KeepsakeHomeCards())),
      generation: generation,
    );

    kWidgets('one new keepsake: a small card with its line, then never again', (
      tester,
    ) async {
      api.list = [keep('capsule_opened_first', '2026-10-08')];
      await tester.pumpWidget(home());
      await settleIo(tester);
      expect(find.byKey(const ValueKey('keepsake-new-card')), findsOneWidget);
      expect(find.text('A new keepsake'), findsOneWidget);
      expect(find.text('Opened a capsule from past me'), findsOneWidget);
      final seen = await tester.runAsync(
        () => kv(tester).getJson(KeepsakeKv.seen),
      );
      expect(seen?['keys'], ['capsule_opened_first']);

      // It stays for this session until hidden…
      await tester.tap(find.byKey(const ValueKey('keepsake-new-hide')));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('keepsake-new-card')), findsNothing);

      // …and a new session (app restart) doesn't show it again.
      await tester.pumpWidget(home(generation: 1));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('keepsake-new-card')), findsNothing);
    });

    kWidgets('several at once: one card, no count', (tester) async {
      api.list = [
        keep('capsule_sealed_first', '2026-10-01'),
        keep('ripples_first', '2026-10-02'),
        keep('sanctuary_minutes_60', '2026-10-03'),
      ];
      await tester.pumpWidget(home());
      await settleIo(tester);
      expect(find.byKey(const ValueKey('keepsake-new-card')), findsOneWidget);
      expect(find.text('New keepsakes are in your box.'), findsOneWidget);
      expect(
        texts(tester).join(' '),
        isNot(matches(RegExp(r'\b3\b|three', caseSensitive: false))),
      );
    });

    kWidgets(
      'hide streak number: a glow seal is kept quietly, never put on Home',
      (tester) async {
        await tester.pumpWidget(app(const SizedBox()));
        await tester.runAsync(
          () => kv(tester).setJson(KvKeys.comfort, {'hideStreak': true}),
        );
        api.list = [keep('glow_days_30', '2026-10-08')];
        await tester.pumpWidget(home());
        await settleIo(tester);
        expect(find.byKey(const ValueKey('keepsake-new-card')), findsNothing);
        final seen = await tester.runAsync(
          () => kv(tester).getJson(KeepsakeKv.seen),
        );
        expect(seen?['keys'], ['glow_days_30']);
      },
    );
  });

  group('repository', () {
    test(
      'without an API (no build config / signed out) nothing is fetched',
      () async {
        final repo = KeepsakesRepository(kv: KvStore(db), api: null);
        expect(await repo.refresh(), KeepsakesRefresh.unavailable);
        expect(await repo.watch().first, isNull);
      },
    );

    test('a refresh caches the server list; offline keeps the cache', () async {
      final repo = KeepsakesRepository(kv: KvStore(db), api: api);
      api.list = [
        keep('sanctuary_minutes_300', '2026-10-09'),
        keep('capsule_sealed_first', '2026-10-01'),
      ];
      expect(await repo.refresh(), KeepsakesRefresh.updated);
      expect((await repo.watch().first)!.map((k) => k.key), [
        'capsule_sealed_first',
        'sanctuary_minutes_300',
      ]);
      api.offline = true;
      expect(await repo.refresh(), KeepsakesRefresh.offline);
      expect(await repo.watch().first, hasLength(2));
    });

    test('keepsake lines exist for every catalogue key', () {
      // (Also checked across all five languages by the copy lint.)
      for (final key in [
        'capsule_sealed_first',
        'capsule_opened_first',
        'glow_days_7',
        'glow_days_30',
        'glow_days_100',
        'glow_days_365',
        'ripples_first',
        'lantern_hours_1',
        'lantern_hours_10',
        'lantern_hours_50',
        'sanctuary_minutes_60',
        'sanctuary_minutes_300',
        'sanctuary_minutes_1000',
      ]) {
        expect(KeepsakeLook.of(key), isNotNull);
      }
    });
  });
}
