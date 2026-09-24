import 'dart:convert';
import 'dart:io';

import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/entitlements/billing_api.dart' show ReceivedGift;
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/net/aura_api.dart' show ApiException;
import 'package:aura/src/features/onboarding/gate_controller.dart';
import 'package:aura/src/features/plus/paywall_gate.dart';
import 'package:aura/src/features/plus/paywall_screen.dart';
import 'package:aura/src/features/plus/plus_entry.dart';
import 'package:aura/src/features/plus/plus_home_cards.dart';
import 'package:aura/src/features/plus/plus_settings_section.dart';
import 'package:aura/src/features/plus/sky_themes.dart';
import 'package:aura/src/features/plus/store_gateway.dart';
import 'package:aura/src/features/plus/gift_sheet.dart';
import 'package:aura_domain/aura_domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'plus_fakes.dart';

/// F12 app surfaces: the honest paywall (REQ-PAY-02, App Review 3.1.2, no dark
/// patterns), the P0 exclusions at a real limit screen (REQ-PAY-06), the
/// Settings card states (14-states), the quiet Home notices (PRD 12) and the
/// gift sheet (REQ-PAY-04).
void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Entitlement entitlement,
    FakeBillingApi? api,
    FakeStore? store,
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ...plusOverrides(entitlement: entitlement, api: api, store: store),
        ],
        child: localized(Scaffold(body: child)),
      ),
    );
    await settleIo(tester);
  }

  Future<void> checkIn(WidgetTester tester, Quadrant q, DateTime at) => io(
    tester,
    () => db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            id: 'c-${at.millisecondsSinceEpoch}',
            moodId: q == Quadrant.storm ? 'anxious' : 'calm',
            quadrant: q.name,
            localDay: '2026-10-08',
            deviceTs: at,
            tzOffsetMinutes: 330,
            tz: const Value('Asia/Kolkata'),
          ),
        ),
  );

  group('paywall (REQ-PAY-02)', () {
    testWidgets(
      'new store account: "1 month free, then ₹49.00/month", the trial end date, how to cancel, Restore and Terms',
      (tester) async {
        await pump(
          tester,
          const PaywallScreen(),
          entitlement: freeAccount(),
          api: FakeBillingApi(current: freeAccount()),
        );
        expect(find.text('1 month free, then ₹49.00/month'), findsOneWidget);
        expect(find.text('1 month free, then ₹399.00/year'), findsOneWidget);
        // Trial started 8 Oct → ends 8 Nov 2026 (the device's zone).
        expect(
          find.textContaining('Your free month ends on 8 Nov 2026'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('paywall-cancel-steps')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Payments & subscriptions'),
          findsOneWidget,
        ); // Play (test platform)
        expect(find.text('Start free month'), findsOneWidget);
        expect(find.text('Restore purchases'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
        expect(find.byKey(const ValueKey('legal-terms')), findsOneWidget);
        // "More of", and the always-free list.
        expect(
          find.byKey(const ValueKey('paywall-always-free')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Neg: a store account that used the offer sees the plain price, no trial wording',
      (tester) async {
        final store = FakeStore(
          products: {
            PlusProducts.monthly: const StoreProduct(
              id: PlusProducts.monthly,
              price: '₹49.00',
            ),
            PlusProducts.annual: const StoreProduct(
              id: PlusProducts.annual,
              price: '₹399.00',
            ),
          },
        );
        await pump(
          tester,
          const PaywallScreen(),
          entitlement: freeAccount(),
          api: FakeBillingApi(),
          store: store,
        );
        expect(find.text('₹49.00/month'), findsOneWidget);
        expect(find.textContaining('month free'), findsNothing);
        expect(find.byKey(const ValueKey('paywall-trial-end')), findsNothing);
        expect(find.text('Subscribe'), findsOneWidget);
      },
    );

    testWidgets('store unreachable: "Nothing was charged", Retry', (
      tester,
    ) async {
      final store = FakeStore()..available = false;
      await pump(
        tester,
        const PaywallScreen(),
        entitlement: freeAccount(),
        api: FakeBillingApi(),
        store: store,
      );
      expect(
        find.text("The store isn't reachable right now. Nothing was charged."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('paywall-retry')), findsOneWidget);
    });

    testWidgets(
      'buy → the server confirms → "Aura Plus is on"; the store transaction is finished only then',
      (tester) async {
        final api = FakeBillingApi(current: freeAccount())
          ..onVerify = plusAccount();
        final store = FakeStore();
        await pump(
          tester,
          const PaywallScreen(),
          entitlement: freeAccount(),
          api: api,
          store: store,
        );
        await tester.tap(find.byKey(const ValueKey('paywall-buy')));
        await settleIo(tester);
        expect(store.bought.single.id, PlusProducts.monthly);
        expect(
          store.bought.single.token,
          freeAccount().accountToken,
        ); // appAccountToken / obfuscatedAccountId
        expect(store.completed, isEmpty);
        store.emit(purchased(PlusProducts.monthly));
        await settleIo(tester);
        expect(api.verified.single.price, '₹49.00');
        expect(store.completed, hasLength(1));
        expect(find.text('Aura Plus is on. Thank you.'), findsWidgets);
      },
    );

    testWidgets('no countdown, urgency or pressure anywhere on the paywall', (
      tester,
    ) async {
      await pump(
        tester,
        const PaywallScreen(),
        entitlement: freeAccount(),
        api: FakeBillingApi(),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ')
          .toLowerCase();
      for (final w in [
        'hurry',
        'last chance',
        'limited',
        'only today',
        'left',
        'expires in',
        "don't miss",
        'lose',
        'unlock',
        '%',
      ]) {
        expect(
          RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(texts) ||
              (w == '%' && texts.contains('%')),
          isFalse,
          reason: w,
        );
      }
      expect(
        RegExp(r'\d{1,2}:\d{2}').hasMatch(texts),
        isFalse,
        reason: 'no timer',
      );
    });

    testWidgets(
      'REQ-PAY-06: an excluded moment (install day) shows only "Part of Aura Plus": no price, no buy button',
      (tester) async {
        final installDay = freeAccount(
          allowedFrom: testNow.add(const Duration(hours: 20)),
        );
        await pump(
          tester,
          const PaywallScreen(surface: PaywallSurface.insightsDepth),
          entitlement: installDay,
          api: FakeBillingApi(),
        );
        expect(
          find.byKey(const ValueKey('paywall-locked-only')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('paywall-buy')), findsNothing);
        expect(find.textContaining('₹'), findsNothing);
      },
    );
  });

  group('limit screen note under the P0 rules (REQ-PAY-06, REQ-PAY-11)', () {
    Widget note() => const PlusLimitNote(
      surface: PaywallSurface.soundsStem,
      explainer: 'This sound comes with Aura Plus.',
    );

    testWidgets(
      'allowed: the explainer with "See Aura Plus", then only "About Aura Plus" later that day',
      (tester) async {
        await pump(tester, note(), entitlement: freeAccount());
        expect(find.text('See Aura Plus'), findsOneWidget);
        await settleIo(tester);
        // Next showing the same day (the unprompted mark was written).
        await tester.pumpWidget(const SizedBox());
        await pump(tester, note(), entitlement: freeAccount());
        expect(find.text('See Aura Plus'), findsNothing);
        expect(find.text('About Aura Plus'), findsOneWidget);
      },
    );

    testWidgets('Neg: install day → only "Part of Aura Plus"', (tester) async {
      await pump(
        tester,
        note(),
        entitlement: freeAccount(
          allowedFrom: testNow.add(const Duration(hours: 3)),
        ),
      );
      expect(find.text('Part of Aura Plus'), findsOneWidget);
      expect(find.text('See Aura Plus'), findsNothing);
      expect(find.text('About Aura Plus'), findsNothing);
    });

    testWidgets(
      'Neg: straight after a Storm check-in → only "Part of Aura Plus"',
      (tester) async {
        await checkIn(
          tester,
          Quadrant.storm,
          testNow.subtract(const Duration(minutes: 10)),
        );
        await pump(tester, note(), entitlement: freeAccount());
        expect(find.text('Part of Aura Plus'), findsOneWidget);
        expect(find.text('See Aura Plus'), findsNothing);
      },
    );

    testWidgets(
      'Neg: straight after a Rain check-in → only "Part of Aura Plus"',
      (tester) async {
        await checkIn(
          tester,
          Quadrant.rain,
          testNow.subtract(const Duration(hours: 1)),
        );
        await pump(tester, note(), entitlement: freeAccount());
        expect(find.text('See Aura Plus'), findsNothing);
      },
    );

    testWidgets(
      'Neg: after a crisis sheet today → only "Part of Aura Plus" for the rest of the day',
      (tester) async {
        await io(
          tester,
          () => db.setValue(PaywallKeys.crisisDay, '2026-10-08'),
        );
        await pump(tester, note(), entitlement: freeAccount());
        expect(find.text('See Aura Plus'), findsNothing);
        expect(find.text('About Aura Plus'), findsNothing);
      },
    );

    testWidgets('Neg: an under-13 locked device never sees an offer', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(
              db: db,
              gate: GateState(
                stage: OnboardingStage.welcome,
                blockedUntil: testNow.add(const Duration(days: 30)),
              ),
            ),
            ...plusOverrides(entitlement: freeAccount()),
          ],
          child: localized(Scaffold(body: note())),
        ),
      );
      await settleIo(tester);
      expect(find.text('See Aura Plus'), findsNothing);
    });

    testWidgets('with Plus: nothing', (tester) async {
      await pump(tester, note(), entitlement: plusAccount());
      expect(find.text('Part of Aura Plus'), findsNothing);
    });
  });

  group('Settings card (14-states)', () {
    Future<String> status(WidgetTester tester, Entitlement e) async {
      await pump(
        tester,
        const SingleChildScrollView(child: PlusSettingsSection()),
        entitlement: e,
      );
      return tester
          .widget<Text>(find.byKey(PlusSettingsSection.statusKey))
          .data!;
    }

    testWidgets('trial: days left and the first charge date', (tester) async {
      expect(
        await status(
          tester,
          plusAccount(until: testNow.add(const Duration(days: 23, hours: 2))),
        ),
        'Free month: 23 days left. First charge on 31 Oct 2026.',
      );
    });
    testWidgets('trial cancelled: on until the end, then free Aura', (
      tester,
    ) async {
      expect(
        await status(tester, plusAccount(autoRenew: false)),
        contains('Your free month stays on until 28 Oct 2026'),
      );
    });
    testWidgets('grace, billing retry, refunded, free', (tester) async {
      expect(
        await status(tester, plusAccount(status: PlusStatus.grace)),
        contains('Plus stays on while it tries again'),
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        await status(tester, plusAccount(status: PlusStatus.billingRetry)),
        contains('paused until the store can renew'),
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        await status(tester, plusAccount(status: PlusStatus.refunded)),
        contains('Your refund went through'),
      );
      await tester.pumpWidget(const SizedBox());
      expect(await status(tester, freeAccount()), "You're on free Aura.");
    });
    testWidgets(
      'bought on the App Store, now on Android: Plus stays on, "Manage" points to the App Store',
      (tester) async {
        await status(tester, plusAccount(store: PlusStore.apple));
        expect(
          find.text('Bought on App Store. Manage it there.'),
          findsOneWidget,
        );
        expect(find.text('Manage in store'), findsOneWidget);
        expect(find.text('Restore purchases'), findsOneWidget);
      },
    );
  });

  group('Home notices (PRD 12)', () {
    final ending = plusAccount(
      until: testNow.add(const Duration(hours: 40)),
      notices: [
        PlusNotice(
          kind: PlusNoticeKind.trialEnding,
          key: 's:trial_ending',
          date: testNow.add(const Duration(hours: 40)),
          price: '₹49.00',
        ),
      ],
    );

    testWidgets(
      'trial ending: date, the store price, Keep Plus / Manage in store; once a day',
      (tester) async {
        final opened = <Uri>[];
        await pump(
          tester,
          PlusHomeCards(
            opener: (u) async {
              opened.add(u);
              return true;
            },
          ),
          entitlement: ending,
        );
        expect(
          find.text(
            'Your free month ends on 10 Oct 2026. Plus then continues at ₹49.00/month unless you cancel in the store.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Manage in store'));
        await settleIo(tester);
        expect(opened.single.host, 'play.google.com');
        expect(
          find.byKey(const ValueKey('plus-card-trial-ending')),
          findsNothing,
        ); // shown today already
      },
    );

    testWidgets('Neg: never straight after a Storm or Rain check-in', (
      tester,
    ) async {
      await checkIn(
        tester,
        Quadrant.rain,
        testNow.subtract(const Duration(minutes: 30)),
      );
      await pump(tester, const PlusHomeCards(), entitlement: ending);
      expect(
        find.byKey(const ValueKey('plus-card-trial-ending')),
        findsNothing,
      );
    });

    testWidgets('Neg: never in a crisis flow that day', (tester) async {
      await io(tester, () => db.setValue(PaywallKeys.crisisDay, '2026-10-08'));
      await pump(tester, const PlusHomeCards(), entitlement: ending);
      expect(
        find.byKey(const ValueKey('plus-card-trial-ending')),
        findsNothing,
      );
    });

    testWidgets(
      'billing issue banner (in-app only) and a received gift — never who sent it',
      (tester) async {
        final api = FakeBillingApi()
          ..gifts = const [
            ReceivedGift(giftId: 'g1', kind: 'comfort_lantern', stardust: 30),
          ];
        final e = Entitlement(
          accountToken: 't',
          plusActive: true,
          status: PlusStatus.grace,
          store: PlusStore.google,
          validUntil: testNow.add(const Duration(days: 3)),
          giftsUnseen: 1,
          notices: const [
            PlusNotice(kind: PlusNoticeKind.billingIssue, key: 'b'),
          ],
        );
        await pump(tester, const PlusHomeCards(), entitlement: e, api: api);
        expect(
          find.text(
            "Your Aura Plus payment didn't go through. Everything you've made is safe.",
          ),
          findsOneWidget,
        );
        expect(
          find.text('Someone here sent you a Comfort Lantern. +30 Stardust'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('plus-card-gift')),
            matching: find.text('Dismiss'),
          ),
        );
        await settleIo(tester);
        expect(api.seen.single, ['g1']);
      },
    );
  });

  group('gift sheet (REQ-PAY-04)', () {
    testWidgets(
      'pre-checked before the store sheet; a refusal never opens the store and never says why',
      (tester) async {
        final api = FakeBillingApi(current: freeAccount())
          ..giftError = const ApiException(
            code: 'gift_unavailable',
            status: 409,
          );
        final store = FakeStore();
        await pump(
          tester,
          const GiftSheet(roomId: 'r', memberId: 'm'),
          entitlement: freeAccount(),
          api: api,
          store: store,
        );
        await tester.tap(find.byKey(const ValueKey('gift-send')));
        await settleIo(tester);
        expect(store.bought, isEmpty);
        expect(
          find.text("This gift can't be sent right now. Nothing was charged."),
          findsOneWidget,
        );
      },
    );

    testWidgets('the 6th gift in a day is refused pre-sheet', (tester) async {
      final api = FakeBillingApi(current: freeAccount())
        ..giftError = const ApiException(code: 'gift_daily_limit', status: 429);
      final store = FakeStore();
      await pump(
        tester,
        const GiftSheet(roomId: 'r', memberId: 'm'),
        entitlement: freeAccount(),
        api: api,
        store: store,
      );
      await tester.tap(find.byKey(const ValueKey('gift-send')));
      await settleIo(tester);
      expect(store.bought, isEmpty);
      expect(
        find.text("That's 5 gifts today. You can send more tomorrow."),
        findsOneWidget,
      );
    });

    testWidgets(
      'checked → the store sheet opens with the gift id; no message field anywhere',
      (tester) async {
        final api = FakeBillingApi(current: freeAccount());
        final store = FakeStore();
        await pump(
          tester,
          const GiftSheet(roomId: 'r', memberId: 'm'),
          entitlement: freeAccount(),
          api: api,
          store: store,
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('gift-kind-comfort_lantern')),
        );
        await tester.pump();
        expect(find.text('Send for ₹29.00'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('gift-send')));
        await settleIo(tester);
        expect(store.bought.single.id, 'gift_comfort_lantern');
        expect(store.bought.single.consumable, isTrue);
        expect(store.bought.single.giftId, isNotNull);
      },
    );

    testWidgets('the entry is hidden when gifting is paused', (tester) async {
      const paused = Entitlement(
        accountToken: 't',
        plusActive: false,
        status: PlusStatus.none,
        gifting: GiftingState.paused,
      );
      late bool visible;
      await pump(
        tester,
        Consumer(
          builder: (_, ref, _) {
            visible = ref.watch(giftEntryVisibleProvider);
            return const SizedBox();
          },
        ),
        entitlement: paused,
        api: FakeBillingApi(),
      );
      expect(visible, isFalse);
    });
  });

  group('catalogue and copy', () {
    test('app skies and soundscapes match the server catalogue (server/aura-api/src/billing/catalogue.ts)', () {
      final ts = File('../../server/aura-api/src/billing/catalogue.ts')
          .readAsStringSync();
      final server = {
        for (final m in RegExp(
          r"\{ id: '([a-z_]+)', tier: '(free|plus|cosmetic)'",
        ).allMatches(ts))
          m[1]!: m[2]!,
      };
      expect({for (final s in skyThemes) s.id: s.tier.name}, server);
      for (final e in soundscapes.entries) {
        expect(
          ts,
          contains("${e.key}: [${e.value.map((s) => "'$s'").join(', ')}]"),
        );
      }
    });

    test('Plus copy: honest and calm (no urgency, loss or "unlock"), Stardust never shown as money', () {
      final arb = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final plus = {
        for (final e in arb.entries)
          if (e.key.startsWith('plus_') && e.value is String)
            e.key: (e.value as String).toLowerCase(),
      };
      expect(plus.length, greaterThan(80));
      for (final e in plus.entries) {
        for (final w in [
          'hurry',
          'last chance',
          'limited time',
          'only today',
          "don't miss",
          'lose',
          'lost',
          'unlock',
          'heal',
        ]) {
          expect(
            RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(e.value),
            isFalse,
            reason: '${e.key}: $w',
          );
        }
        if (e.key.contains('stardust') || e.key == 'plus_skyStardust') {
          expect(e.value.contains('₹'), isFalse, reason: e.key);
        }
      }
      expect(plus['plus_trialLineMonthly'], '1 month free, then {price}/month');
      expect(plus['plus_lockedOnly'], 'part of aura plus');
    });
  });
}
