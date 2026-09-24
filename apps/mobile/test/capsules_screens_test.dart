import 'dart:io';
import 'dart:typed_data';

import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/ids/ids.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/sync/outbox_repository.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/capsules/capsule_composer_screen.dart';
import 'package:aura/src/features/capsules/capsule_detail_screen.dart';
import 'package:aura/src/features/capsules/capsule_draft.dart';
import 'package:aura/src/features/capsules/capsule_media_store.dart';
import 'package:aura/src/features/capsules/capsule_opening.dart';
import 'package:aura/src/features/capsules/capsule_ready_card.dart';
import 'package:aura/src/features/capsules/capsule_repository.dart';
import 'package:aura/src/features/capsules/capsules_entry.dart';
import 'package:aura/src/features/capsules/capsules_list_screen.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/features/push/push_messaging.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'capsules_fakes.dart';
import 'helpers.dart';
import 'voice_fakes.dart';

/// F4 screens: the list and a capsule's page (PRD 14-states), the composer
/// (limits, the date window, the Free trigger limit, crisis → hard moment,
/// the draft guard), Home's ready card, the opening ceremony (skippable,
/// still under Reduce Motion, hard-moment first) and 200% text in Telugu.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late Directory root;
  late AppDatabase db;
  late CapsuleMediaStore store;

  /// A widget test that unmounts at the end (drift closes its streams on
  /// timers, which must run inside the test).
  void capsuleWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  /// Scrolls the screen's list until [key] is built and visible, and lets
  /// the scroll settle (a list ignores taps while it is still moving). The
  /// text fields lose focus first, so no caret keeps frames coming.
  Future<void> show(WidgetTester tester, String key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Lets real async work (isolates, files, drift) run until [f] finds
  /// something.
  Future<void> until(WidgetTester tester, Finder f, {int rounds = 60}) async {
    for (var i = 0; i < rounds && f.evaluate().isEmpty; i++) {
      await settleIo(tester, rounds: 1);
    }
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aura-capsule-screens');
    db = memoryDb();
    store = tempCapsuleStore(root);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A repository on the same database, sealing at [at].
  CapsuleRepository seeder([DateTime? at]) => CapsuleRepository(
    db,
    OutboxRepository(db, const Ids()),
    TimeContext(clock: FixedClock(at ?? testNow), timezone: 'Asia/Kolkata'),
    store: store,
    cipher: () async => testCipher(),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String locale = 'en',
    double textScale = 1,
    bool reduceMotion = true,
    FakePhotoPicker? picker,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = localeFromTag(locale);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(
            db: db,
            locale: locale,
            auth: SignedInAuth(),
            secure: secureWithKey(),
          ),
          ...capsuleOverrides(store: store, picker: picker),
          ...voiceOverrides(),
          ...extra,
        ],
        child: MaterialApp(
          theme: buildAuraTheme(l),
          locale: l,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<CapsuleRow> sealDate(
    WidgetTester tester, {
    String id = 'd1',
    String title = 'For Arjun',
    String text = 'secret words',
    String date = '2027-10-12',
    DateTime? at,
    bool hard = false,
  }) async {
    final row = await io(
      tester,
      () => seeder(at).seal(
        id: id,
        content: CapsuleContent(title: title, text: text),
        unlock: DateUnlock(LocalDay.parse(date)),
        hardMoment: hard,
      ),
    );
    // Let screens already watching the table catch up (their refetch runs
    // in the test's fake-async zone and holds drift's lock until pumped).
    await settleIo(tester, rounds: 2);
    return row;
  }

  group('list and page (PRD 14-states)', () {
    capsuleWidgets('empty: write to future you → seal your first capsule', (
      tester,
    ) async {
      await pump(tester, const CapsulesListScreen());
      expect(find.text(en.capsules_emptyBody), findsOneWidget);
      expect(find.text(en.capsules_emptyCta), findsOneWidget);
      expect(find.text(en.help_button), findsOneWidget, reason: 'help stays');
    });

    capsuleWidgets(
      'sealed: title and "Sealed until 12 Oct 2027. It\'ll keep."',
      (tester) async {
        await sealDate(tester);
        await io(
          tester,
          () => seeder().seal(
            id: 'm1',
            content: const CapsuleContent(title: 'Storm note', text: 'hidden'),
            unlock: const MoodUnlock.quadrant(Quadrant.storm),
          ),
        );
        await pump(tester, const CapsulesListScreen());
        await settleIo(tester);
        expect(find.text('For Arjun'), findsOneWidget);
        expect(
          find.text("Sealed until 12 Oct 2027. It'll keep."),
          findsOneWidget,
        );
        expect(find.text('Storm note'), findsOneWidget);
        expect(find.text(en.capsules_waitingFeeling), findsOneWidget);
        // Sealed means sealed: never the content.
        expect(find.textContaining('secret'), findsNothing);
        expect(find.textContaining('hidden'), findsNothing);
        expect(find.text(en.capsules_sectionSealed), findsOneWidget);
      },
    );

    capsuleWidgets(
      'a sealed capsule\'s page: no content, no early open; delete',
      (tester) async {
        await sealDate(tester);
        await pump(tester, const CapsuleDetailScreen(id: 'd1'));
        await settleIo(tester);
        expect(find.text('For Arjun'), findsOneWidget);
        expect(
          find.text("Sealed until 12 Oct 2027. It'll keep."),
          findsOneWidget,
        );
        expect(find.text(en.capsules_detailNoEarly), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        expect(find.byKey(const ValueKey('capsule-detail-open')), findsNothing);

        await show(tester, 'capsule-delete');
        await tester.tap(find.byKey(const ValueKey('capsule-delete')));
        await tester.pumpAndSettle();
        expect(find.text(en.capsules_deleteTitle), findsOneWidget);
        expect(find.text(en.capsules_deleteBody), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('capsule-delete-confirm')));
        await settleIo(tester);
        final row = await io(tester, () => seeder().row('d1'));
        expect(row!.deletedAt, isNotNull);
        expect(row.payloadCt, isNull);
      },
    );

    capsuleWidgets(
      'a mood capsule\'s page says what it waits for and when it arms',
      (tester) async {
        await io(
          tester,
          () => seeder().seal(
            id: 'm1',
            content: const CapsuleContent(text: 'x'),
            unlock: const MoodUnlock.mood('overwhelmed'),
          ),
        );
        await pump(tester, const CapsuleDetailScreen(id: 'm1'));
        await settleIo(tester);
        expect(
          find.text('Waiting for a feeling: Overwhelmed.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('capsule-detail-arming')),
          findsOneWidget,
        );
      },
    );

    capsuleWidgets('a refused mood capsule offers "Make it a date capsule"', (
      tester,
    ) async {
      await io(tester, () async {
        await seeder().seal(
          id: 'r1',
          content: const CapsuleContent(text: 'x'),
          unlock: const MoodUnlock.mood('calm'),
        );
        await (db.update(db.capsules)..where((t) => t.id.equals('r1'))).write(
          const CapsulesCompanion(rejected: Value('trigger_capsule_limit')),
        );
      });
      await pump(tester, const CapsuleDetailScreen(id: 'r1'));
      await settleIo(tester);
      expect(find.text(en.capsules_limitBody), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('capsule-make-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await settleIo(tester);
      final row = await io(tester, () => seeder().row('r1'));
      expect(row!.unlockType, 'date');
      expect(row.rejected, isNull);
    });
  });

  group('ready (date unlock)', () {
    capsuleWidgets('Home card when a date capsule is due, nothing otherwise', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: CapsuleReadyCard()));
      expect(find.byKey(const ValueKey('capsule-ready-card')), findsNothing);

      // Sealed on 1 Sep for 8 Oct: 10:00 IST today has passed (15:30).
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await sealDate(tester, id: 'later', date: '2026-10-20');
      await settleIo(tester);
      expect(find.text(en.capsules_readyTitle), findsOneWidget);
      expect(find.text(en.capsules_readyMore(2)), findsNothing);
    });

    capsuleWidgets('Sanctuary entry counts sealed and ready', (tester) async {
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await sealDate(tester, id: 'later', date: '2026-10-20');
      await pump(tester, const Scaffold(body: CapsulesEntryTile()));
      await settleIo(tester);
      expect(find.text(en.capsules_title), findsOneWidget);
      expect(find.text(en.capsules_entryCount(2)), findsOneWidget);
      expect(find.text(en.capsules_entryReady(1)), findsOneWidget);
    });
  });

  group('a tapped notice', () {
    Widget host() => Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => openCapsuleFromNotice(context, 'due'),
              child: const Text('due'),
            ),
            TextButton(
              onPressed: () => openCapsuleFromNotice(context, 'd1'),
              child: const Text('sealed'),
            ),
          ],
        ),
      ),
    );

    capsuleWidgets('opens a ready capsule, else Future you', (tester) async {
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await sealDate(tester);
      await pump(tester, host());
      await tester.tap(find.text('due'));
      await settleIo(tester);
      expect(find.byType(CapsuleOpeningScreen), findsOneWidget);
      await tester.pageBack();
      await settleIo(tester);
      await tester.tap(find.text('sealed'));
      await settleIo(tester);
      expect(find.byType(CapsulesListScreen), findsOneWidget);
    });
  });

  group('opening', () {
    capsuleWidgets('Reduce Motion: still, a crossfade into the note', (
      tester,
    ) async {
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await pump(tester, const CapsuleOpeningScreen(id: 'due'));
      await settleIo(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('capsule-open')), findsOneWidget);
      expect(find.text('secret words'), findsOneWidget);
      expect(find.byKey(const ValueKey('capsule-ceremony')), findsNothing);
      final row = await io(tester, () => seeder().row('due'));
      expect(row!.openedAt, isNotNull, reason: 'opening is recorded');
    });

    capsuleWidgets('the ceremony plays ~4 s and can be skipped', (
      tester,
    ) async {
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await pump(
        tester,
        const CapsuleOpeningScreen(id: 'due'),
        reduceMotion: false,
      );
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.byKey(const ValueKey('capsule-ceremony')), findsOneWidget);
      expect(find.text(en.capsules_skip), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('capsule-skip')));
      await tester.pumpAndSettle();
      expect(find.text('secret words'), findsOneWidget);
    });

    capsuleWidgets('the ceremony hands over to the note by itself', (
      tester,
    ) async {
      await sealDate(
        tester,
        id: 'due',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
      );
      await pump(
        tester,
        const CapsuleOpeningScreen(id: 'due'),
        reduceMotion: false,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('secret words'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('secret words'), findsOneWidget);
    });

    capsuleWidgets('a hard-moment capsule asks first, with help right there', (
      tester,
    ) async {
      await sealDate(
        tester,
        id: 'hard',
        date: '2026-10-08',
        at: DateTime.utc(2026, 9, 1),
        hard: true,
      );
      await pump(tester, const CapsuleOpeningScreen(id: 'hard'));
      await settleIo(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(en.capsules_hardMoment), findsOneWidget);
      expect(find.byType(HelpNowButton), findsWidgets);
      expect(find.text('secret words'), findsNothing);
      CapsuleRow? row = await io(tester, () => seeder().row('hard'));
      expect(row!.openedAt, isNull, reason: 'not opened until they choose');

      await tester.tap(find.byKey(const ValueKey('capsule-open-now')));
      await settleIo(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('secret words'), findsOneWidget);
      row = await io<CapsuleRow?>(tester, () => seeder().row('hard'));
      expect(row!.openedAt, isNotNull);
    });

    capsuleWidgets('a sealed date capsule never opens early', (tester) async {
      await sealDate(tester);
      await pump(tester, const CapsuleOpeningScreen(id: 'd1'));
      await settleIo(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('secret words'), findsNothing);
      expect(find.text(en.capsules_detailNoEarly), findsOneWidget);
      final row = await io(tester, () => seeder().row('d1'));
      expect(row!.openedAt, isNull);
    });
  });

  group('composer', () {
    Future<void> openComposer(WidgetTester tester, {FakePhotoPicker? picker}) =>
        pump(tester, const CapsuleComposerScreen(), picker: picker);

    capsuleWidgets('limits: title 60, text 2,000; a prompt as the hint', (
      tester,
    ) async {
      await openComposer(tester);
      final title = tester.widget<TextField>(
        find.byKey(const ValueKey('capsule-title-field')),
      );
      final text = tester.widget<TextField>(
        find.byKey(const ValueKey('capsule-text-field')),
      );
      expect(title.maxLength, 60);
      expect(text.maxLength, 2000);
      expect(text.decoration?.hintText, isNotNull);
      expect(
        find.byKey(const ValueKey('capsule-prompt-another')),
        findsOneWidget,
      );
      expect(find.text(en.capsules_voiceHint), findsOneWidget);
    });

    capsuleWidgets('REQ-CAP-01: the picker only offers 1 week – 5 years', (
      tester,
    ) async {
      await openComposer(tester);
      await tester.enterText(
        find.byKey(const ValueKey('capsule-text-field')),
        'Hello later',
      );
      await show(tester, 'capsule-unlock-date');
      await tester.tap(find.byKey(const ValueKey('capsule-unlock-date')));
      await tester.pump();
      await show(tester, 'capsule-pick-date');
      await tester.tap(find.byKey(const ValueKey('capsule-pick-date')));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 10, 15));
      expect(picker.lastDate, DateTime(2031, 10, 8));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capsule-date-chosen')), findsOneWidget);

      await show(tester, 'capsule-seal');
      await tester.tap(find.byKey(const ValueKey('capsule-seal')));
      await settleIo(tester, rounds: 10);
      expect(find.text("Sealed until 7 Nov 2026. It'll keep."), findsOneWidget);
      expect(
        find.byKey(const ValueKey('capsule-journal-logged')),
        findsOneWidget,
      );
      final rows = await io(tester, () => seeder().allRows());
      expect(rows.single.unlockLocalDate, '2026-11-07');
      final kept = await io(tester, () => KvDraftProbe(db).hasDraft());
      expect(kept, isFalse, reason: 'the draft is gone once sealed');
    });

    capsuleWidgets(
      'sealing a date capsule offers "Want to know when it opens?" once',
      (tester) async {
        final messaging = FakeMessaging()..granted = PushPermission.denied;
        // "Not now" 31 days ago: the one re-ask is due (PushService.mayAskAgain).
        await io(
          tester,
          () => KvStore(db).setJson(KvKeys.pushSoftAsk, {
            'answer': 'notNow',
            'at': testNow.subtract(const Duration(days: 31)).toIso8601String(),
          }),
        );
        await pump(
          tester,
          const CapsuleComposerScreen(),
          extra: [
            pushMessagingProvider.overrideWithValue(messaging),
            clockProvider.overrideWithValue(FixedClock(testNow)),
          ],
        );
        await tester.enterText(
          find.byKey(const ValueKey('capsule-text-field')),
          'See you then',
        );
        await show(tester, 'capsule-unlock-date');
        await tester.tap(find.byKey(const ValueKey('capsule-unlock-date')));
        await tester.pump();
        await show(tester, 'capsule-pick-date');
        await tester.tap(find.byKey(const ValueKey('capsule-pick-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await show(tester, 'capsule-seal');
        await tester.tap(find.byKey(const ValueKey('capsule-seal')));
        await until(tester, find.text(en.capsules_notifyAskTitle));
        expect(find.text(en.capsules_notifyAskTitle), findsOneWidget);
        expect(
          messaging.requests,
          isEmpty,
          reason: 'no OS prompt before Allow',
        );
        await tester.pump(const Duration(milliseconds: 600)); // slides in
        await tester.tap(find.byKey(const ValueKey('capsule-notify-allow')));
        await settleIo(tester);
        expect(messaging.requests, [false], reason: 'the full prompt, once');
        final offered = await io(
          tester,
          () => db.getValue('capsules.notify_offered'),
        );
        expect(offered, isNotNull, reason: 'never asked again from here');
      },
    );

    capsuleWidgets('nothing inside or no unlock: a calm note, nothing sealed', (
      tester,
    ) async {
      await openComposer(tester);
      await show(tester, 'capsule-seal');
      await tester.tap(find.byKey(const ValueKey('capsule-seal')));
      await tester.pump();
      expect(find.text(en.capsules_needContent), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('capsule-text-field')),
        'words',
      );
      await tester.pump();
      await show(tester, 'capsule-seal');
      await tester.tap(find.byKey(const ValueKey('capsule-seal')));
      await tester.pump();
      expect(find.text(en.capsules_needUnlock), findsOneWidget);
      expect(await io(tester, () => seeder().allRows()), isEmpty);
    });

    capsuleWidgets(
      'a feeling capsule; crisis words seal as a hard moment + help',
      (tester) async {
        await openComposer(tester);
        await tester.enterText(
          find.byKey(const ValueKey('capsule-text-field')),
          'Some days I want to end my life',
        );
        await show(tester, 'capsule-unlock-feeling');
        await tester.tap(find.byKey(const ValueKey('capsule-unlock-feeling')));
        await settleIo(tester, rounds: 2);
        await show(tester, 'capsule-mood-overwhelmed');
        await tester.tap(
          find.byKey(const ValueKey('capsule-mood-overwhelmed')),
        );
        await tester.pump();
        expect(find.text('Waits for: Overwhelmed'), findsOneWidget);
        await show(tester, 'capsule-seal');
        await tester.tap(find.byKey(const ValueKey('capsule-seal')));
        await settleIo(tester, rounds: 8);
        expect(find.byType(SupportSheet), findsOneWidget, reason: 'help first');
        final row = (await io(tester, () => seeder().allRows())).single;
        expect(row.triggerMoodId, 'overwhelmed');
        final payload = await io(tester, () => seeder().payloadOf(row));
        expect(payload!.hardMoment, isTrue);
      },
    );

    capsuleWidgets('REQ-CAP-04: a 4th feeling capsule → pick a date instead', (
      tester,
    ) async {
      for (var i = 0; i < 3; i++) {
        await io(
          tester,
          () => seeder().seal(
            id: 'm$i',
            content: const CapsuleContent(text: 'x'),
            unlock: const MoodUnlock.mood('calm'),
          ),
        );
      }
      await openComposer(tester);
      await show(tester, 'capsule-unlock-feeling');
      await tester.tap(find.byKey(const ValueKey('capsule-unlock-feeling')));
      await until(tester, find.byKey(const ValueKey('capsule-trigger-limit')));
      expect(find.text(en.capsules_limitBody), findsOneWidget);
      expect(find.byKey(const ValueKey('capsule-mood-calm')), findsNothing);
      await show(tester, 'capsule-limit-pick-date');
      await tester.tap(find.byKey(const ValueKey('capsule-limit-pick-date')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    capsuleWidgets('photos: picked, resized and stripped, up to 3', (
      tester,
    ) async {
      final picker = FakePhotoPicker([tinyJpeg(), tinyJpeg()]);
      await openComposer(tester, picker: picker);
      await show(tester, 'capsule-add-photo');
      await tester.tap(find.byKey(const ValueKey('capsule-add-photo')));
      await until(tester, find.byKey(const ValueKey('capsule-photo-thumb-1')));
      expect(picker.limits, [3]);
      expect(
        find.byKey(const ValueKey('capsule-photo-thumb-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('capsule-photo-thumb-1')),
        findsOneWidget,
      );
      await show(tester, 'capsule-add-photo');
      await tester.tap(find.byKey(const ValueKey('capsule-add-photo')));
      await until(tester, find.byKey(const ValueKey('capsule-photo-thumb-2')));
      expect(picker.limits.last, 1, reason: 'only one more fits');
      expect(
        find.byKey(const ValueKey('capsule-photo-thumb-2')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('capsule-add-photo')), findsNothing);
      // What was kept is the stripped copy, not the picked bytes.
      final kept = await io(tester, () async {
        final dir = Directory('${root.path}/capsules/drafts');
        return dir
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.readAsBytesSync())
            .toList();
      });
      expect(kept, hasLength(3));
      for (final bytes in kept) {
        expect(img.decodeJpg(bytes)!.exif.gpsIfd.hasGPSLatitude, isFalse);
      }
    });

    capsuleWidgets(
      'never lose a draft: leaving asks; "Keep draft" restores it',
      (tester) async {
        await pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => openCapsuleComposer(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settleIo(tester);
        await tester.enterText(
          find.byKey(const ValueKey('capsule-text-field')),
          'half a thought',
        );
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text(en.capsules_leaveTitle), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('capsule-leave-keep')));
        await settleIo(tester);
        expect(find.text('open'), findsOneWidget);

        await tester.tap(find.text('open'));
        await settleIo(tester);
        expect(find.text('half a thought'), findsOneWidget);
      },
    );
  });

  for (final locale in ['te', 'hi']) {
    group(
      '200% text in ${locale == 'te' ? 'Telugu' : 'Hindi (Devanagari)'}',
      () {
        Future<void> check(WidgetTester tester, Widget screen) async {
          await pump(tester, screen, locale: locale, textScale: 2);
          await settleIo(tester);
          await tester.pump(const Duration(milliseconds: 350));
          expect(tester.takeException(), isNull);
        }

        capsuleWidgets('the list', (tester) async {
          await sealDate(tester);
          await sealDate(
            tester,
            id: 'due',
            date: '2026-10-08',
            at: DateTime.utc(2026, 9, 1),
          );
          await io(
            tester,
            () => seeder().seal(
              id: 'm1',
              content: const CapsuleContent(text: 'x'),
              unlock: const MoodUnlock.quadrant(Quadrant.rain),
            ),
          );
          await check(tester, const CapsulesListScreen());
        });

        capsuleWidgets('the empty list', (tester) async {
          await check(tester, const CapsulesListScreen());
        });

        capsuleWidgets('the composer, with the feeling picker open', (
          tester,
        ) async {
          await check(tester, const CapsuleComposerScreen());
          await show(tester, 'capsule-unlock-feeling');
          await tester.tap(
            find.byKey(const ValueKey('capsule-unlock-feeling')),
          );
          await settleIo(tester, rounds: 3);
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -2000),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        capsuleWidgets('a sealed capsule\'s page', (tester) async {
          await sealDate(tester);
          await check(tester, const CapsuleDetailScreen(id: 'd1'));
        });

        capsuleWidgets('an opened capsule', (tester) async {
          await sealDate(
            tester,
            id: 'due',
            date: '2026-10-08',
            at: DateTime.utc(2026, 9, 1),
          );
          await check(tester, const CapsuleOpeningScreen(id: 'due'));
          expect(find.text('secret words'), findsOneWidget);
        });

        capsuleWidgets('Home card and Sanctuary entry', (tester) async {
          await sealDate(
            tester,
            id: 'due',
            date: '2026-10-08',
            at: DateTime.utc(2026, 9, 1),
          );
          await sealDate(
            tester,
            id: 'due2',
            date: '2026-10-08',
            at: DateTime.utc(2026, 9, 1),
          );
          await check(
            tester,
            const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [CapsuleReadyCard(), CapsulesEntryTile()],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

/// A small JPEG with EXIF and GPS, like the picker's output.
Uint8List tinyJpeg() {
  final src = img.Image(width: 64, height: 48);
  img.fill(src, color: img.ColorRgb8(90, 160, 200));
  src.exif.gpsIfd.setGpsLocation(latitude: 17.38, longitude: 78.48);
  return img.encodeJpg(src);
}

/// Reads whether a composer draft is kept.
class KvDraftProbe {
  KvDraftProbe(this.db);

  final AppDatabase db;

  Future<bool> hasDraft() async =>
      await db.getValue(CapsuleDraftStore.key) != null;
}
