import 'package:aura/src/app.dart';
import 'package:aura/src/core/db/database.dart';
import 'package:aura/src/core/entitlements/billing_api.dart' show ReceivedGift;
import 'package:aura/src/core/entitlements/plus.dart';
import 'package:aura/src/core/providers.dart';
import 'package:aura/src/core/remote_config/remote_config.dart';
import 'package:aura/src/core/remote_config/remote_config_providers.dart';
import 'package:aura/src/core/router/router.dart';
import 'package:aura/src/features/home/home_screen.dart';
import 'package:aura/src/features/plus/gift_sheet.dart';
import 'package:aura/src/features/plus/paywall_gate.dart';
import 'package:aura/src/features/plus/paywall_screen.dart';
import 'package:aura/src/features/plus/plus_entry.dart';
import 'package:aura/src/features/plus/plus_home_cards.dart';
import 'package:aura/src/features/plus/purchase_controller.dart';
import 'package:aura/src/features/plus/sky_themes_screen.dart';
import 'package:aura/src/features/plus/store_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'plus_fakes.dart';

/// v1.0 launches free: the `plus_enabled` remote flag (bundled default OFF)
/// hides every purchase surface — the paywall routes, the Home Plus / gift
/// cards, "See Aura Plus" / "About Aura Plus" on every limit screen, the gift
/// entry, and the store plugin itself is never asked anything. Plus-only
/// features stay locked with their calm "Part of Aura Plus" line.

/// A store that counts every call (it must see none with purchases off).
class _CountingStore extends FakeStore {
  int calls = 0;

  @override
  Future<bool> isAvailable() async {
    calls++;
    return super.isAvailable();
  }

  @override
  Future<Map<String, StoreProduct>> products(Set<String> ids) async {
    calls++;
    return super.products(ids);
  }

  @override
  Stream<List<StorePurchase>> get purchases {
    calls++;
    return super.purchases;
  }

  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountToken,
    bool consumable = false,
    String? giftId,
  }) async {
    calls++;
    return super.buy(product, accountToken: accountToken);
  }

  @override
  Future<void> restore({required String accountToken}) async {
    calls++;
    return super.restore(accountToken: accountToken);
  }
}

class _CountingApi extends FakeBillingApi {
  _CountingApi({super.current});

  int giftReads = 0;

  @override
  Future<List<ReceivedGift>> receivedGifts() async {
    giftReads++;
    return super.receivedGifts();
  }
}

class _Flags extends RemoteFlagsNotifier {
  _Flags(this.flags);

  final RemoteFlags flags;

  @override
  RemoteFlags build() => flags;
}

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
    bool plusEnabled = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db: db),
          ...plusOverrides(
            entitlement: entitlement,
            api: api,
            store: store,
            plusEnabled: plusEnabled,
          ),
        ],
        child: localized(Scaffold(body: child)),
      ),
    );
    await settleIo(tester);
  }

  group('the flag', () {
    test('bundled default is OFF: a fresh, offline install never sells', () {
      expect(RemoteFlags.defaults.plusEnabled, isFalse);
      expect(RemoteFlags.bundledDefaults[RemoteFlags.plusEnabledKey], isFalse);
      expect(
        const RemoteFlags({
          'rooms_enabled': FlagValue(enabled: true),
        }).plusEnabled,
        isFalse,
      );
    });

    test('the server turns it on (and off again)', () {
      final on = RemoteConfigDoc.fromJson({
        'configVersion': 'v1',
        'pollSeconds': 240,
        'flags': {
          'plus_enabled': {'enabled': true},
        },
      });
      expect(on.flags.plusEnabled, isTrue);
      final off = RemoteConfigDoc.fromJson({
        'configVersion': 'v2',
        'pollSeconds': 240,
        'flags': {
          'plus_enabled': {'enabled': false},
        },
      });
      expect(off.flags.plusEnabled, isFalse);
    });

    test('plusEnabledProvider follows remoteFlagsProvider', () {
      ProviderContainer container(RemoteFlags f) {
        final c = ProviderContainer(
          overrides: [remoteFlagsProvider.overrideWith(() => _Flags(f))],
        );
        addTearDown(c.dispose);
        return c;
      }

      expect(container(RemoteFlags.defaults).read(plusEnabledProvider), false);
      expect(
        container(
          const RemoteFlags({'plus_enabled': FlagValue(enabled: true)}),
        ).read(plusEnabledProvider),
        isTrue,
      );
    });
  });

  group('limit screens: the calm locked line, never a way to buy', () {
    for (final surface in [
      PaywallSurface.soundsStem,
      PaywallSurface.capsuleLongVoice,
      PaywallSurface.capsuleTriggerLimit,
      PaywallSurface.plusSky,
      PaywallSurface.insightsDepth,
    ]) {
      testWidgets('${surface.name}: "Part of Aura Plus", no "See Aura Plus"', (
        tester,
      ) async {
        await pump(
          tester,
          PlusLimitNote(surface: surface, explainer: 'Comes with Aura Plus.'),
          entitlement: freeAccount(),
        );
        expect(find.byKey(PlusLimitNote.keyFor(surface)), findsOneWidget);
        expect(find.text('Part of Aura Plus'), findsOneWidget);
        expect(find.byKey(PlusLimitNote.buttonKeyFor(surface)), findsNothing);
        expect(find.text('See Aura Plus'), findsNothing);
        expect(find.text('About Aura Plus'), findsNothing);
        expect(find.text('Comes with Aura Plus.'), findsNothing);
      });
    }

    testWidgets('Insights / capsule limit: PlusOpenButton renders nothing', (
      tester,
    ) async {
      await pump(
        tester,
        const PlusOpenButton(surface: PaywallSurface.insightsDepth),
        entitlement: freeAccount(),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('See Aura Plus'), findsNothing);
    });

    testWidgets('Sounds locked stem note: the line and "Not now" only', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () => showPlusNoteSheet(
              context,
              surface: PaywallSurface.soundsStem,
              explainer: 'This sound comes with Aura Plus.',
            ),
            child: const Text('open'),
          ),
        ),
        entitlement: freeAccount(),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await settleIo(tester);
      expect(find.text('Part of Aura Plus'), findsOneWidget);
      expect(find.byKey(const ValueKey('plus-note-close')), findsOneWidget);
      expect(find.text('See Aura Plus'), findsNothing);
      expect(find.text('About Aura Plus'), findsNothing);
    });

    testWidgets('control: the same note with the flag ON offers the way in', (
      tester,
    ) async {
      await pump(
        tester,
        const PlusLimitNote(
          surface: PaywallSurface.soundsStem,
          explainer: 'Comes with Aura Plus.',
        ),
        entitlement: freeAccount(),
        plusEnabled: true,
      );
      expect(find.text('See Aura Plus'), findsOneWidget);
    });

    testWidgets('Plus-only features stay locked (not unlocked) when off', (
      tester,
    ) async {
      late bool plus;
      await pump(
        tester,
        Consumer(
          builder: (_, ref, _) {
            plus = ref.watch(plusActiveProvider);
            return const SizedBox();
          },
        ),
        entitlement: freeAccount(),
      );
      expect(plus, isFalse);
    });
  });

  group('Home and rooms', () {
    testWidgets('no trial / billing / gift cards, and no gift lookup', (
      tester,
    ) async {
      final api = _CountingApi(
        current: plusAccount(
          notices: [
            PlusNotice(
              kind: PlusNoticeKind.trialEnding,
              key: 's:trial_ending',
              date: testNow.add(const Duration(hours: 40)),
              price: '₹49.00',
            ),
            const PlusNotice(
              kind: PlusNoticeKind.billingIssue,
              key: 's:billing_issue',
            ),
          ],
        ),
      );
      await pump(
        tester,
        const PlusHomeCards(),
        entitlement: api.current,
        api: api,
      );
      expect(find.byKey(const ValueKey('plus-card-trial-ending')), findsNothing);
      expect(
        find.byKey(const ValueKey('plus-card-billing-issue')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('plus-card-gift')), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(api.giftReads, 0);
    });

    testWidgets('the gift entry on a room member is hidden', (tester) async {
      late bool visible;
      await pump(
        tester,
        Consumer(
          builder: (_, ref, _) {
            visible = ref.watch(giftEntryVisibleProvider);
            return const SizedBox();
          },
        ),
        entitlement: freeAccount(),
        api: FakeBillingApi(current: freeAccount()),
      );
      expect(visible, isFalse);
    });
  });

  group('the store plugin is never asked anything', () {
    testWidgets('load / buy / restore make no store call', (tester) async {
      final store = _CountingStore();
      late WidgetRef r;
      await pump(
        tester,
        Consumer(
          builder: (_, ref, _) {
            r = ref;
            ref.watch(purchaseControllerProvider);
            return const SizedBox();
          },
        ),
        entitlement: freeAccount(),
        api: FakeBillingApi(current: freeAccount()),
        store: store,
      );
      final c = r.read(purchaseControllerProvider.notifier);
      await tester.runAsync(() async {
        await c.load(PlusProducts.plus);
        await c.buy(PlusProducts.monthly);
        await c.restore();
      });
      await settleIo(tester);
      expect(store.calls, 0);
      expect(store.bought, isEmpty);
      expect(store.restores, 0);
      expect(
        r.read(purchaseControllerProvider).phase,
        PurchasePhase.storeUnavailable,
      );
    });
  });

  group('routes (the real router)', () {
    Future<ProviderContainer> app(
      WidgetTester tester, {
      required bool plusEnabled,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(db: db),
          ...plusOverrides(
            entitlement: freeAccount(),
            api: FakeBillingApi(current: freeAccount()),
            store: _CountingStore(),
            plusEnabled: plusEnabled,
          ),
          deviceRegionProvider.overrideWithValue('IN'),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AuraApp(),
        ),
      );
      await settleIo(tester, rounds: 4);
      await tester.pump(const Duration(milliseconds: 600));
      return container;
    }

    Future<void> go(
      WidgetTester tester,
      ProviderContainer c,
      String location,
    ) async {
      c.read(routerProvider).go(location);
      await settleIo(tester, rounds: 4);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await settleIo(tester, rounds: 2);
    }

    testWidgets('off: /plus and /plus/skies land on Home', (tester) async {
      final c = await app(tester, plusEnabled: false);
      await go(tester, c, '$plusRoute?from=settings');
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      await go(tester, c, plusSkiesRoute);
      expect(find.byType(SkyThemesScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      await end(tester);
    });

    testWidgets('on: /plus opens the paywall', (tester) async {
      final c = await app(tester, plusEnabled: true);
      await go(tester, c, '$plusRoute?from=settings');
      expect(find.byType(PaywallScreen), findsOneWidget);
      await end(tester);
    });
  });
}
