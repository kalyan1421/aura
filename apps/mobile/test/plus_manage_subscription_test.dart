import 'package:aura/src/core/entitlements/entitlement.dart';
import 'package:aura/src/features/plus/plus_format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// F12 "Manage" (PRD 12 "One tap to cancel": the store's own subscription
/// page, nothing in between): StoreKit's in-app sheet on iOS
/// (`AppStore.showManageSubscriptions(in:)` over the AppDelegate channel),
/// the App Store web page when it can't show, the Play deep link on Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openManageFor', () {
    late List<Uri> opened;
    Future<bool> opener(Uri u) async {
      opened.add(u);
      return true;
    }

    setUp(() => opened = []);

    test('App Store: the in-app sheet, no web page when it shows', () async {
      var sheets = 0;
      final ok = await openManageFor(
        PlusStore.apple,
        productId: 'aura_plus_monthly',
        opener: opener,
        nativeSheet: () async {
          sheets++;
          return true;
        },
      );
      expect(ok, isTrue);
      expect(sheets, 1);
      expect(opened, isEmpty);
    });

    test('App Store: falls back to the web page when the sheet can\'t show '
        '(older iOS, StoreKit error, Android)', () async {
      final ok = await openManageFor(
        PlusStore.apple,
        opener: opener,
        nativeSheet: () async => false,
      );
      expect(ok, isTrue);
      expect(opened, [
        Uri.parse('https://apps.apple.com/account/subscriptions'),
      ]);
    });

    test(
      'Google Play: always the Play subscription deep link, never StoreKit',
      () async {
        var sheets = 0;
        await openManageFor(
          PlusStore.google,
          productId: 'aura_plus_annual',
          opener: opener,
          nativeSheet: () async {
            sheets++;
            return true;
          },
        );
        expect(sheets, 0);
        expect(
          opened.single.toString(),
          'https://play.google.com/store/account/subscriptions?sku=aura_plus_annual&package=com.akvega.aura',
        );
      },
    );
  });

  group('showNativeManageSubscriptions (channel com.akvega.aura/store)', () {
    final calls = <String>[];
    Object? answer;

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storeChannel, (call) async {
            calls.add(call.method);
            if (answer is PlatformException) throw answer!;
            return answer;
          });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storeChannel, null);
    });

    test('iOS: asks StoreKit and reports whether the sheet showed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer = true;
      expect(await showNativeManageSubscriptions(), isTrue);
      answer = false;
      expect(await showNativeManageSubscriptions(), isFalse);
      expect(calls, ['showManageSubscriptions', 'showManageSubscriptions']);
    });

    test(
      'iOS: a channel error or no answer → false (the web page opens)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        answer = PlatformException(code: 'x');
        expect(await showNativeManageSubscriptions(), isFalse);
        answer = null;
        expect(await showNativeManageSubscriptions(), isFalse);
      },
    );

    test('Android: never calls the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer = true;
      expect(await showNativeManageSubscriptions(), isFalse);
      expect(calls, isEmpty);
    });
  });
}
