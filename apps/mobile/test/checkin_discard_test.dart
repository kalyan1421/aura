import 'package:aura/l10n/app_localizations.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/l10n/locale_controller.dart';
import 'package:aura/src/core/theme/app_theme.dart';
import 'package:aura/src/features/checkin/checkin_details.dart';
import 'package:aura/src/features/checkin/checkin_screen.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// Never lose input: ✕ and the system back gesture ask before discarding a
/// picked mood, tags or words; nothing to ask when empty or already saved.
void main() {
  GoRouter router({bool first = false}) => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => context.push('/checkin'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/checkin',
        builder: (_, _) => CheckInScreen(first: first),
      ),
    ],
  );

  Future<void> pumpApp(
    WidgetTester tester,
    GoRouter r, {
    AppDatabase? db,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db: db ?? memoryDb()),
        child: MaterialApp.router(
          theme: buildAuraTheme(const Locale('en')),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...systemLocalizationDelegates,
          ],
          routerConfig: r,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Future<void> tapMood(WidgetTester tester, String id) async {
    final tile = find.byKey(ValueKey('mood-$id'));
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final dialogTitle = find.text('Leave without saving?');
  final home = find.byKey(const ValueKey('open'));

  testWidgets('nothing picked: ✕ leaves at once', (tester) async {
    await pumpApp(tester, router());
    await tester.tap(find.byKey(const ValueKey('checkin-close')));
    await tester.pumpAndSettle();
    expect(dialogTitle, findsNothing);
    expect(home, findsOneWidget);
    await done(tester);
  });

  testWidgets('a picked mood: ✕ asks, "Keep editing" is focused and keeps '
      'it; back asks again and "Discard" leaves without saving', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpApp(tester, router(), db: db);
    await tapMood(tester, 'calm');

    await tester.tap(find.byKey(const ValueKey('checkin-close')));
    await tester.pumpAndSettle();
    expect(dialogTitle, findsOneWidget);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('discard-keep'),
    );

    await tester.tap(find.byKey(const ValueKey('discard-keep')));
    await tester.pumpAndSettle();
    expect(dialogTitle, findsNothing);
    expect(home, findsNothing);
    final save = find.byKey(const ValueKey('checkin-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    // The system back gesture is held too.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dialogTitle, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-confirm')));
    await tester.pumpAndSettle();
    expect(home, findsOneWidget);
    expect(await io(tester, () => db.select(db.checkIns).get()), isEmpty);
    await done(tester);
  });

  testWidgets('after saving, back leaves without asking', (tester) async {
    final db = memoryDb();
    await pumpApp(tester, router(), db: db);
    await tapMood(tester, 'joyful');
    await tester.tap(find.byKey(const ValueKey('checkin-save')));
    await settleIo(tester);
    expect(find.byKey(const ValueKey('checkin-done')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(dialogTitle, findsNothing);
    expect(home, findsOneWidget);
    expect(await io(tester, () => db.select(db.checkIns).get()), hasLength(1));
    await done(tester);
  });

  testWidgets('the onboarding check-in still has no close button', (
    tester,
  ) async {
    await pumpApp(tester, router(first: true));
    expect(find.byKey(const ValueKey('checkin-close')), findsNothing);
    await done(tester);
  });

  group('CheckInDraft.isDirty', () {
    test('a new check-in: any mood, tag, words or typed tag count', () {
      final d = CheckInDraft();
      expect(d.isDirty, isFalse);
      d.mood = moodById('calm');
      expect(d.isDirty, isTrue);
      d.mood = null;
      expect(d.isDirty, isFalse);
      d.customTag.text = 'exams';
      expect(d.isDirty, isTrue);
      d.customTag.clear();
      d.note.text = '   ';
      expect(d.isDirty, isFalse); // whitespace only
      d.note.text = 'hi';
      expect(d.isDirty, isTrue);
      d.dispose();
    });

    test('an edit: only changes count', () {
      final d = CheckInDraft(
        mood: moodById('calm'),
        tags: ['family'],
        note: 'hello',
      );
      expect(d.isDirty, isFalse);
      d.toggleTag('work');
      expect(d.isDirty, isTrue);
      d.toggleTag('work');
      expect(d.isDirty, isFalse);
      d.note.text = 'hello again';
      expect(d.isDirty, isTrue);
      expect(d.noteChanged, isTrue);
      d.dispose();
    });
  });
}
