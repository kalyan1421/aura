import 'dart:async';

import 'package:aura/src/core/db/kv_store.dart';
import 'package:aura/src/features/auth/age_signals.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Platform age signals (F8 REQ-ACC-04): they only ever add protection.
/// Under 13 → the device lock; under 18 → the invisible flag (even with an
/// adult DOB); no signal → DOB alone, after waiting at most 1 s.

const _today = LocalDay(2026, 10, 8);

void main() {
  group('the rule', () {
    test('a range entirely under 13 blocks, whatever the DOB', () {
      // Apple (gates 13/16/18): lowerBound nil, upperBound 12.
      expect(
        evaluateAgeSignal(const AgeSignal(upper: 12)),
        AgeSignalOutcome.blocked,
      );
      // Play (default bands): 0–12.
      expect(
        evaluateAgeSignal(const AgeSignal(lower: 0, upper: 12)),
        AgeSignalOutcome.blocked,
      );
    });

    test('a teen range → invisible under-18 protections only', () {
      expect(
        evaluateAgeSignal(const AgeSignal(lower: 13, upper: 15)),
        AgeSignalOutcome.minor,
      );
      expect(
        evaluateAgeSignal(const AgeSignal(lower: 16, upper: 17)),
        AgeSignalOutcome.minor,
      );
    });

    test('a range that may include 13+ never blocks', () {
      // A custom Play band 0–14 can't prove "under 13".
      expect(
        evaluateAgeSignal(const AgeSignal(lower: 0, upper: 14)),
        AgeSignalOutcome.minor,
      );
    });

    test('18+ or no signal → DOB alone', () {
      expect(
        evaluateAgeSignal(const AgeSignal(lower: 18)),
        AgeSignalOutcome.none,
      );
      expect(evaluateAgeSignal(AgeSignal.none), AgeSignalOutcome.none);
    });

    test('protection lasts until the youngest possible age turns 18', () {
      expect(
        minorUntilFor(const AgeSignal(lower: 13, upper: 15), _today),
        const LocalDay(2031, 10, 8),
      );
      expect(
        minorUntilFor(const AgeSignal(lower: 16, upper: 17), _today),
        const LocalDay(2028, 10, 8),
      );
      // Unknown lower bound: assume the youngest possible (13).
      expect(
        minorUntilFor(const AgeSignal(upper: 17), _today),
        const LocalDay(2031, 10, 8),
      );
    });

    test('a signal never prints its range', () {
      expect('${const AgeSignal(lower: 13, upper: 15)}', isNot(contains('13')));
    });
  });

  group('applying it', () {
    late KvStore kv;
    late int blocks;
    late AgeSignalPolicy policy;

    setUp(() {
      kv = KvStore(memoryDb());
      blocks = 0;
      policy = AgeSignalPolicy(
        kv: kv,
        blockUnder13: () async => blocks++,
        today: () => _today,
      );
    });

    test('under 13 → the under-13 block', () async {
      expect(
        await policy.apply(const AgeSignal(upper: 12)),
        AgeSignalOutcome.blocked,
      );
      expect(blocks, 1);
    });

    test('a teen signal with an adult DOB → minorUntil set', () async {
      await kv.set(KvKeys.birthDate, '1990-05-01');
      await kv.set(KvKeys.minorUntil, '2008-05-01'); // from the adult DOB
      expect(
        await policy.apply(const AgeSignal(lower: 13, upper: 15)),
        AgeSignalOutcome.minor,
      );
      expect(await kv.get(KvKeys.minorUntil), '2031-10-08');
      expect(blocks, 0);
    });

    test('never shortens protection the DOB already gives', () async {
      // A young teen's DOB-based date, later than the signal's (2028).
      await kv.set(KvKeys.minorUntil, '2033-01-01');
      await policy.apply(const AgeSignal(lower: 16, upper: 17));
      expect(await kv.get(KvKeys.minorUntil), '2033-01-01');
    });

    test('18+ and no signal change nothing', () async {
      await kv.set(KvKeys.minorUntil, '2008-05-01');
      await policy.apply(const AgeSignal(lower: 18));
      await policy.apply(AgeSignal.none);
      expect(await kv.get(KvKeys.minorUntil), '2008-05-01');
      expect(blocks, 0);
    });
  });

  group('waiting for it', () {
    testWidgets('no answer → the auth action waits at most 1 s, then DOB '
        'alone; a late under-13 still blocks', (tester) async {
      final answer = Completer<AgeSignal>();
      final applied = <AgeSignal>[];
      final check = AgeSignalCheck(
        read: () => answer.future,
        apply: (s) async {
          applied.add(s);
          return evaluateAgeSignal(s);
        },
      )..start();

      AgeSignalOutcome? outcome;
      unawaited(check.outcome().then((o) => outcome = o));
      await tester.pump(const Duration(milliseconds: 999));
      expect(outcome, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(outcome, AgeSignalOutcome.none);

      answer.complete(const AgeSignal(upper: 12));
      await tester.pump();
      expect(applied, [const AgeSignal(upper: 12)]);
      // The next auth action sees it at once.
      expect(await check.outcome(), AgeSignalOutcome.blocked);
    });

    testWidgets('an answer that is already in costs no wait', (tester) async {
      var reads = 0;
      final check = AgeSignalCheck(
        read: () async {
          reads++;
          return const AgeSignal(lower: 18);
        },
        apply: (s) async => evaluateAgeSignal(s),
      )..start();
      await tester.pump();
      expect(await check.outcome(), AgeSignalOutcome.none);
      expect(await check.outcome(), AgeSignalOutcome.none);
      expect(reads, 1); // read once per check
    });

    testWidgets('a failing platform read is "no signal"', (tester) async {
      final check = AgeSignalCheck(
        read: () async => throw StateError('channel'),
        apply: (s) async => evaluateAgeSignal(s),
      );
      expect(await check.outcome(), AgeSignalOutcome.none);
    });

    test('off-device (tests, desktop) the channel is never called', () async {
      expect(await const ChannelAgeSignalSource().read(), AgeSignal.none);
    });
  });
}
