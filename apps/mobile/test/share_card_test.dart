// F13 share cards (Milestone C). REQ-SHR-02: a card binds only whitelisted
// fields (stage, traits, cosmetics, milestone) — never a mood, quadrant, the
// mood-derived hue, a note, a date, a streak count, a pseudonym, a name or an
// id; adding any other field to ShareCardData fails here. REQ-SHR-01: a
// 1080×1920 PNG made on the phone. REQ-SHR-03: sharing talks to no server and
// earns nothing. REQ-SHR-04: under-18 (or unknown age) shares a plain link,
// with an identical card. The Home prompt is offered once per milestone, one
// prompt for the highest, never for glow while "hide streak number" is on.
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/avatar/aura_avatar.dart';
import 'package:aura/src/features/progress/progress_view.dart';
import 'package:aura/src/features/share/share_card.dart';
import 'package:aura/src/features/share/share_card_data.dart';
import 'package:aura/src/features/share/share_gateway.dart';
import 'package:aura/src/features/share/share_link.dart';
import 'package:aura/src/features/share/share_prompt.dart';
import 'package:aura/src/features/share/share_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'keepsakes_fakes.dart';

/// Words a card must never carry (mood names, quadrants, streak, dates…).
final RegExp _forbidden = RegExp(
  r'storm|rain\b|moonlight|sunrise|overwhelmed|anxious|drained|lonely|calm|'
  r'joyful|melancholy|numb|streak|kept on|\b20\d\d\b|'
  r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b|@|quiet comet|user-',
  caseSensitive: false,
);

void main() {
  late AppDatabase db;
  late FakeShareGateway gateway;

  setUp(() {
    db = memoryDb();
    gateway = FakeShareGateway();
  });
  tearDown(() => db.close());

  void kWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  // A resting Rain-hued avatar with rings, glow and a cosmetic.
  final avatar = progressFor(
    stage: AuraStage.glow,
    hue: 175,
    resting: true,
  ).avatar;

  Widget app(
    Widget child, {
    ProgressView? view,
    String locale = 'en',
    int generation = 0,
  }) => ProviderScope(
    key: ValueKey('scope-$generation'),
    overrides: [
      ...testOverrides(db: db, locale: locale),
      progressViewProvider.overrideWithValue(view ?? progressFor()),
      shareGatewayProvider.overrideWithValue(gateway),
    ],
    child: localized(
      Scaffold(body: SingleChildScrollView(child: child)),
      locale: switch (locale) {
        'te-Latn' => const Locale.fromSubtags(
          languageCode: 'te',
          scriptCode: 'Latn',
        ),
        'hi-Latn' => const Locale.fromSubtags(
          languageCode: 'hi',
          scriptCode: 'Latn',
        ),
        _ => Locale(locale),
      },
    ),
  );

  KvStore kv(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(kvStoreProvider);

  List<String> textsIn(WidgetTester tester, Finder f) => tester
      .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .toList();

  group('REQ-SHR-02: only whitelisted fields', () {
    test(
      'ShareCardData holds exactly the whitelist (a new field fails the build)',
      () {
        expect(ShareCardData.whitelist, {
          'kind',
          'stage',
          'ringCount',
          'glowLevel',
          'constellationStars',
          'cosmetics',
          'value',
          'keepsakeKey',
        });
        for (final d in [
          ShareCardData.evolution(avatar),
          ShareCardData.glow(avatar, 30),
          ShareCardData.capsuleAnniversary(avatar, 1),
          ShareCardData.keepsake(avatar, 'capsule_opened_first'),
        ]) {
          expect(d.fields.keys.toSet(), ShareCardData.whitelist);
        }
      },
    );

    test('the card avatar uses the template palette, never the mood hue or the resting look', () {
      final d = ShareCardData.evolution(avatar);
      expect(avatar.hue, 175);
      expect(d.avatar.hue, d.templateHue);
      expect(d.avatar.isResting, isFalse);
      expect(d.avatar.stage, AuraStage.glow);
      expect(d.avatar.ringCount, 2);
      expect(d.avatar.glowLevel, 1);
      expect(d.avatar.equippedCosmetics, {'first_light'});
      // Same card for two people whose moods differ.
      final other = ShareCardData.evolution(avatar.copyWith(hue: 275));
      expect(other, d);
    });

    for (final locale in ['en', 'te', 'te-Latn', 'hi', 'hi-Latn']) {
      kWidgets('every card type in $locale shows wordmark, line and store '
          'line only', (tester) async {
        for (final d in [
          ShareCardData.evolution(avatar),
          ShareCardData.glow(avatar, 100),
          ShareCardData.capsuleAnniversary(avatar, 2),
          ShareCardData.keepsake(avatar, 'sanctuary_minutes_300'),
        ]) {
          await tester.pumpWidget(
            app(
              SizedBox(width: 360, height: 640, child: ShareCard(data: d)),
              locale: locale,
            ),
          );
          await settleIo(tester, rounds: 2);
          final card = find.byType(ShareCard);
          final texts = textsIn(tester, card);
          expect(texts, hasLength(3), reason: '$locale ${d.kind}');
          final all = texts.join(' | ');
          expect(all, isNot(matches(_forbidden)), reason: all);
          // The rendered avatar is the card's own state.
          final view = tester.widget<AuraAvatarView>(
            find.descendant(of: card, matching: find.byType(AuraAvatarView)),
          );
          expect(view.state, d.avatar);
          expect(view.tier, AvatarTier.still);
        }
      });
    }

    kWidgets('the card reads as its line and stage to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 360,
            height: 640,
            child: ShareCard(data: ShareCardData.glow(avatar, 30)),
          ),
        ),
      );
      await settleIo(tester, rounds: 2);
      expect(
        find.bySemanticsLabel(
          'Card to share: 30 days of glow. Your Aura at the Glow stage.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('REQ-SHR-01: rendered on the phone', () {
    kWidgets('a 1080×1920 PNG from the preview', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 216,
              height: 384,
              child: ShareCard(data: ShareCardData.evolution(avatar)),
            ),
          ),
        ),
      );
      await settleIo(tester, rounds: 2);
      final png = (await tester.runAsync(() => renderShareCardPng(key)))!;
      // PNG signature, then IHDR width / height (big-endian).
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(png, 16, 24);
      expect(header.getUint32(0), 1080);
      expect(header.getUint32(4), 1920);
    });
  });

  group('sharing', () {
    Future<void> shareOnce(WidgetTester tester) async {
      await tester.pumpWidget(
        app(ShareCardSheet(data: ShareCardData.evolution(avatar))),
      );
      await settleIo(tester, rounds: 2);
      await tester.runAsync(() async {
        await tester.tap(find.text('Share'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await settleIo(tester, rounds: 3);
    }

    kWidgets('an adult share carries a random token; the image is the card', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SizedBox()));
      await tester.runAsync(
        () => kv(tester).set(KvKeys.minorUntil, '2019-01-01'),
      );
      await shareOnce(tester);
      await shareOnce(tester);
      expect(gateway.shared, hasLength(2));
      final links = [
        for (final s in gateway.shared)
          RegExp(r'utm_content%3D([a-z0-9]{16})').firstMatch(s.text)?.group(1),
      ];
      expect(
        links.every((t) => t != null),
        isTrue,
        reason: gateway.shared.first.text,
      );
      expect(links[0], isNot(links[1]));
      expect(gateway.shared.first.png.sublist(1, 4), 'PNG'.codeUnits);
      expect(gateway.shared.first.text, startsWith('Aura, a quiet place'));
    });

    kWidgets(
      'REQ-SHR-04: under 18 (or unknown) shares the plain link, same card',
      (tester) async {
        await tester.pumpWidget(app(const SizedBox()));
        await tester.runAsync(
          () => kv(tester).set(KvKeys.minorUntil, '2030-06-01'),
        );
        await shareOnce(tester);
        await tester.runAsync(() => kv(tester).set(KvKeys.minorUntil, null));
        await shareOnce(tester);
        expect(gateway.shared, hasLength(2));
        for (final s in gateway.shared) {
          expect(s.text, contains(shareLink().toString()));
          expect(s.text, isNot(contains('utm_content')));
          expect(s.text, isNot(contains('s=')));
        }
      },
    );

    test('share tokens are random and never derived from anything', () {
      final a = newShareToken();
      final b = newShareToken();
      expect(a, hasLength(16));
      expect(a, isNot(b));
      expect(
        shareLink(token: 'abc').queryParameters['referrer'],
        contains('abc'),
      );
      expect(
        shareLink(
          token: 'abc',
          base: 'https://aura.example/get',
        ).queryParameters,
        {'s': 'abc'},
      );
    });

    test(
      'REQ-SHR-03: the share feature talks to no server and no analytics',
      () {
        for (final f in Directory('lib/src/features/share').listSync()) {
          final src = File(f.path).readAsStringSync();
          for (final banned in [
            'aura_api',
            'package:dio',
            'supabase',
            'analytics',
            'posthog',
            'outbox',
            'ledger',
            'stardust',
          ]) {
            expect(
              src.toLowerCase(),
              isNot(contains(banned)),
              reason: '${f.path}: $banned',
            );
          }
        }
      },
    );
  });

  group('Home share prompt', () {
    Future<Set<String>> offered(WidgetTester tester) async {
      final j = await tester.runAsync(
        () => kv(tester).getJson(sharePromptOfferedKey),
      );
      return {...((j?['ids'] as List<dynamic>?) ?? const []).cast<String>()};
    }

    kWidgets(
      'several milestones: one prompt for the highest, all offered once',
      (tester) async {
        final view = progressFor(stage: AuraStage.glow, lifetimeGlowDays: 30);
        await tester.pumpWidget(app(const SharePromptCard(), view: view));
        await settleIo(tester);
        expect(
          find.text('Your Aura reached Glow. Share a card of it?'),
          findsOneWidget,
        );
        expect(await offered(tester), {
          'evolution:ember',
          'evolution:glow',
          'glow:7',
          'glow:30',
        });
        await tester.tap(find.byKey(const ValueKey('share-prompt-share')));
        await settleIo(tester, rounds: 2);
        expect(find.byType(ShareCard), findsOneWidget);

        // A new session: nothing is offered again.
        await tester.pumpWidget(
          app(const SharePromptCard(), view: view, generation: 1),
        );
        await settleIo(tester);
        expect(find.byType(FilledButton), findsNothing);
      },
    );

    kWidgets('hide streak number: a glow milestone never prompts', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SizedBox()));
      await tester.runAsync(
        () => kv(tester).setJson(KvKeys.comfort, {'hideStreak': true}),
      );
      await tester.runAsync(
        () => kv(tester).setJson(sharePromptOfferedKey, {
          'ids': ['evolution:ember'],
        }),
      );
      await tester.pumpWidget(
        app(
          const SharePromptCard(),
          view: progressFor(stage: AuraStage.ember, lifetimeGlowDays: 7),
        ),
      );
      await settleIo(tester);
      expect(find.textContaining('days of glow'), findsNothing);
      expect(find.byKey(const ValueKey('share-prompt-share')), findsNothing);
      expect(await offered(tester), containsAll(['glow:7']));
    });

    kWidgets('a Spark with nothing new sees nothing', (tester) async {
      await tester.pumpWidget(app(const SharePromptCard()));
      await settleIo(tester);
      expect(find.byKey(const ValueKey('share-prompt-share')), findsNothing);
    });
  });
}
