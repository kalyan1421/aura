import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/entitlements/entitlement.dart';

/// "30 Oct 2026" in the person's language and zone (Telugu script for `te`;
/// English digits and months for Tenglish / others).
String plusDate(BuildContext context, DateTime d) {
  final locale = Localizations.localeOf(context);
  final tag = locale.languageCode == 'te' && locale.scriptCode == null
      ? 'te'
      : 'en';
  try {
    return DateFormat('d MMM y', tag).format(d.toLocal());
  } on Object {
    return DateFormat('d MMM y', 'en').format(d.toLocal());
  }
}

String storeName(AppLocalizations l, PlusStore store) =>
    store == PlusStore.apple ? l.plus_storeApple : l.plus_storeGoogle;

/// The Android package (Play subscription deep link).
const String androidPackage = 'com.akvega.aura';

/// The store's own subscription page — no retention screen or survey in
/// between (PRD 12 "One tap to cancel"). Apple: the App Store's account
/// subscriptions page; Play: the subscription's own page.
Uri manageSubscriptionUri(PlusStore store, {String? productId}) =>
    store == PlusStore.apple
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.https('play.google.com', '/store/account/subscriptions', {
        'sku': ?productId,
        'package': androidPackage,
      });

typedef PlusUrlOpener = Future<bool> Function(Uri uri);

/// Shows the store's own in-app "Manage subscriptions" sheet; `true` when it
/// was shown.
typedef NativeManageSheet = Future<bool> Function();

/// ios/Runner/AppDelegate.swift `AuraStoreChannel`.
const MethodChannel storeChannel = MethodChannel('com.akvega.aura/store');

/// iOS 15+: StoreKit's `AppStore.showManageSubscriptions(in:)` (the
/// in_app_purchase plugin doesn't expose it). `false` on Android, on the web,
/// or when StoreKit can't show it (the caller then opens the web page).
Future<bool> showNativeManageSubscriptions() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  try {
    return await storeChannel.invokeMethod<bool>('showManageSubscriptions') ??
        false;
  } on Object {
    return false;
  }
}

/// "Manage" for a subscription bought on [store] (PRD 12 "One tap to
/// cancel": the store's own page, nothing in between). An App Store
/// subscription on an iPhone opens StoreKit's sheet in the app; if that
/// can't show, or on Android (a subscription bought on iOS keeps pointing to
/// the App Store, F12 edge case), the store's web page / Play deep link.
Future<bool> openManageFor(
  PlusStore store, {
  String? productId,
  PlusUrlOpener opener = openStorePage,
  NativeManageSheet nativeSheet = showNativeManageSubscriptions,
}) async {
  if (store == PlusStore.apple && await nativeSheet()) return true;
  return opener(manageSubscriptionUri(store, productId: productId));
}

Future<bool> openStorePage(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// Gift display name.
String giftName(AppLocalizations l, String kind) => switch (kind) {
  'comfort_lantern' => l.plus_giftComfortLantern,
  'encouragement_bouquet' => l.plus_giftBouquet,
  _ => l.plus_giftWarmTea,
};

/// Opens this platform's subscription page (the trial-ending push): the
/// in-app sheet on iOS, the Play subscriptions page on Android.
Future<bool> openManageSubscriptions({String? productId}) => openManageFor(
  defaultTargetPlatform == TargetPlatform.iOS
      ? PlusStore.apple
      : PlusStore.google,
  productId: productId,
);
