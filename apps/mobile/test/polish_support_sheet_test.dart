import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/time/clock.dart';
import 'package:aura/src/features/support/support_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Support sheet: Childline follows the app's clock and Aura day; a device
/// that can't place calls shows the number with a Copy action.

const _launcher = MethodChannel('plugins.flutter.io/url_launcher');
const _childline = 'Childline · for under-18s';

Future<void> _open(
  WidgetTester tester,
  AppDatabase db, {
  TimeContext? time,
  String? minorUntil,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (minorUntil != null) {
    await io(tester, () => KvStore(db).set(KvKeys.minorUntil, minorUntil));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(db: db, time: time),
        deviceRegionProvider.overrideWithValue('IN'),
      ],
      child: localized(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSupportSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleIo(tester);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Answers `launch` with [result] (or throws it), recording each URL.
List<String> _dialer(WidgetTester tester, Object result) {
  final launched = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher, (
    call,
  ) async {
    if (call.method == 'launch') {
      launched.add((call.arguments as Map)['url'] as String);
    }
    if (result is Exception) throw result;
    return result;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _launcher,
      null,
    ),
  );
  return launched;
}

/// Records what goes on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// IST is UTC+5:30; the Aura day rolls over at 04:00 local time.
TimeContext _ist(int y, int m, int d, int hour, [int minute = 0]) => testTime(
  DateTime.utc(
    y,
    m,
    d,
    hour,
    minute,
  ).subtract(const Duration(hours: 5, minutes: 30)),
);

void main() {
  group(
    'Childline follows the app clock and Aura day (not the wall clock)',
    () {
      // Birthdays far from the real date in both directions, so a stray
      // DateTime.now() gives the other answer.
      for (final (name, time, until, listed) in [
        (
          'the day before an 18th birthday',
          _ist(1999, 3, 9, 20),
          '1999-03-10',
          true,
        ),
        (
          'the 18th birthday, afternoon',
          _ist(2090, 3, 10, 15),
          '2090-03-10',
          false,
        ),
        (
          'the 18th birthday, 02:00 (still the previous Aura day)',
          _ist(1999, 3, 10, 2),
          '1999-03-10',
          true,
        ),
        (
          'the 18th birthday, 04:30 (the new Aura day)',
          _ist(2090, 3, 10, 4, 30),
          '2090-03-10',
          false,
        ),
      ]) {
        testWidgets('$name: Childline ${listed ? 'listed' : 'not listed'}', (
          tester,
        ) async {
          final db = memoryDb();
          await _open(tester, db, time: time, minorUntil: until);
          expect(find.text(_childline), listed ? findsOneWidget : findsNothing);
          await _end(tester);
        });
      }
    },
  );

  group('a device that can\'t place calls', () {
    for (final (name, result) in <(String, Object)>[
      ('launch returns false', false),
      ('launch throws', PlatformException(code: 'ACTIVITY_NOT_FOUND')),
    ]) {
      testWidgets('$name: the number shows with Copy until closed', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final launched = _dialer(tester, result);
        final copied = _clipboard(tester);
        final db = memoryDb();
        await _open(tester, db);

        await tester.tap(find.byKey(const ValueKey('support-call-14416')));
        // The call is placed at once, before any frame.
        expect(launched, ['tel:14416']);
        await tester.pump();
        expect(tester.takeException(), isNull);

        const message = "This phone can't place the call. The number is 14416.";
        final note = find.byKey(const ValueKey('support-call-failed-14416'));
        expect(note, findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(
          tester.getSemantics(find.text(message)),
          isSemantics(isLiveRegion: true, label: message),
        );
        // Right under the row that was tapped.
        final row = tester.getRect(
          find.byKey(const ValueKey('support-call-14416')),
        );
        expect(tester.getRect(note).top, greaterThan(row.bottom));
        expect(
          tester.getRect(note).top,
          lessThan(
            tester
                .getRect(find.byKey(const ValueKey('support-call-18008914416')))
                .top,
          ),
        );

        // Stays past 5 s.
        await tester.pump(const Duration(seconds: 12));
        expect(find.text(message), findsOneWidget);

        await tester.tap(find.text('Copy number'));
        await tester.pump();
        expect(copied, ['14416']);
        expect(find.text('Number copied'), findsOneWidget);

        // Another helpline that fails moves the note to that row.
        await tester.tap(find.byKey(const ValueKey('support-call-112')));
        await tester.pump();
        expect(find.text(message), findsNothing);
        expect(
          find.text("This phone can't place the call. The number is 112."),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('support-call-failed-112')),
            matching: find.byTooltip('Close'),
          ),
        );
        await tester.pump();
        expect(find.textContaining("can't place the call"), findsNothing);
        handle.dispose();
        await _end(tester);
      });
    }

    testWidgets('a phone that can call: the call goes out and nothing else '
        'shows', (tester) async {
      final launched = _dialer(tester, true);
      final db = memoryDb();
      await _open(tester, db);

      await tester.tap(find.byKey(const ValueKey('support-call-14416')));
      expect(launched, ['tel:14416']);
      await tester.pump();
      expect(find.textContaining("can't place the call"), findsNothing);
      await _end(tester);
    });

    testWidgets('a screen-reader double-tap also falls back', (tester) async {
      final handle = tester.ensureSemantics();
      final launched = _dialer(tester, false);
      final db = memoryDb();
      await _open(tester, db);

      tester.semantics.tap(
        find.semantics.byLabel('Call Tele-MANAS · free, 24×7, 14416'),
      );
      await tester.pump();
      expect(launched, ['tel:14416']);
      expect(
        find.text("This phone can't place the call. The number is 14416."),
        findsOneWidget,
      );
      handle.dispose();
      await _end(tester);
    });
  });
}
